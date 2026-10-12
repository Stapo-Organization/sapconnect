<?php
/**
 * Zooboxi_Catalog_Onboarding — how a product the backend just activated
 * becomes a PROPER store product, not a bare post.
 *
 * The backend's catalog gate (sapconnect `zooboxi:catalog-gate`) decides WHO
 * goes live and ships, per product, the pictures it verified, the copy it
 * wrote and the SEO fields. This class turns that into WooCommerce reality:
 *
 *   • pictures are sideloaded into the media library (featured + gallery) and
 *     de-duplicated by source URL, so a re-sync never re-downloads;
 *   • Arabic title + English meta, SKU = barcode, item code in meta, weight,
 *     categories from the tree path, brand as a category, Yoast title/desc;
 *   • the product PUBLISHES only when at least one picture landed — otherwise
 *     it stays a draft with `_zooboxi_hold_reason = no_image` and is retried
 *     on every product sync (the store never shows a broken card);
 *   • on creation the SKU is announced to ShipGo (`/v1/channel/catalog/link`)
 *     which files a listing and answers with today's ATP, written straight into
 *     the RUH003 slot — so a product with 1,795 units in the hub is buyable in
 *     the same minute, not after the next stock movement.
 *
 * Products that were hidden at launch for a broken picture
 * (`_zooboxi_hidden_no_image`) are un-hidden the first time a verified
 * picture arrives for them.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Catalog_Onboarding
{
    public const META_IMAGE_SRC  = '_zooboxi_image_src';   // on the attachment: where it came from
    public const META_HOLD       = '_zooboxi_hold_reason';  // on the product: why it is a draft
    public const META_GATE       = '_zooboxi_gate';         // on the product: backend gate snapshot

    /* ── create ─────────────────────────────────────── */

    /**
     * Create the store product for a feed row. Returns the new product id.
     * Never throws for a missing picture — that is a draft, not an error.
     */
    public static function create(array $data): int
    {
        $itemCode = (string) ($data['item_code'] ?? '');
        $nameAr = trim((string) ($data['name_ar'] ?? ''));
        $nameEn = trim((string) ($data['name_en'] ?? ''));
        $name = $nameAr !== '' ? $nameAr : ($nameEn !== '' ? $nameEn : (string) ($data['item_name'] ?? $itemCode));

        $product = new \WC_Product_Simple();
        $product->set_props([
            'name'               => $name,
            'status'             => 'draft', // publish() decides once the pictures are in
            'regular_price'      => (string) (self::price($data) ?? ''),
            'manage_stock'       => true,
            'stock_quantity'     => 0,
            'stock_status'       => 'outofstock', // the stock writers flip it
            'catalog_visibility' => 'visible',
            'description'        => self::first_nonempty($data, ['description_ar', 'description_en']),
            'short_description'  => self::first_nonempty($data, ['short_description_ar', 'short_description_en', 'foreign_name']),
        ]);
        if (!empty($data['weight'])) {
            $product->set_weight((string) $data['weight']);
        }
        if (!empty($data['barcode'])) {
            try {
                $product->set_sku((string) $data['barcode']);
            } catch (\Exception $e) {
                // SKU taken by another post — keep going; ShipGo matching will report it
                error_log("Zooboxi onboarding: SKU {$data['barcode']} already used ({$itemCode})");
            }
        }
        $productId = $product->save();
        if (!$productId) {
            throw new \RuntimeException("could not create product for {$itemCode}");
        }

        update_post_meta($productId, '_zooboxi_item_code', $itemCode);
        // دفتر الأسعار: VAT-inclusive shelf prices (+ express meta) replace the raw list price.
        if (class_exists('Zooboxi_Price_Book')) {
            Zooboxi_Price_Book::apply($productId, $data);
        }
        self::stamp_meta($productId, $data);
        self::assign_categories($productId, (string) ($data['categories_ar'] ?? ''), (string) ($data['brand_name'] ?? ''));
        self::stamp_seo($productId, $data);

        $pictures = self::sideload_pictures($productId, self::picture_urls($data));
        self::link_shipgo($productId, (string) ($data['barcode'] ?? ''));
        self::publish_or_hold($productId, $pictures);

        do_action('zooboxi_catalog_product_created', $productId, $data, $pictures);
        return (int) $productId;
    }

    /* ── refresh (existing products) ────────────────── */

    /**
     * For a product that already exists: fetch pictures it does not have yet,
     * publish it if we were holding it for that, un-hide it if launch hid it.
     */
    public static function refresh(int $productId, array $data): void
    {
        // Only products that are missing a picture are worth the download: a
        // product that already has its featured image is left exactly as the
        // owner arranged it (the hourly sync touches ~6,000 products).
        $had = (int) get_post_thumbnail_id($productId) > 0;
        $held = get_post_meta($productId, self::META_HOLD, true) === 'no_image';
        $hidden = (bool) get_post_meta($productId, '_zooboxi_hidden_no_image', true);
        if ($had && !$held && !$hidden) {
            return;
        }
        $urls = self::picture_urls($data);
        if (empty($urls)) {
            return;
        }
        $count = self::sideload_pictures($productId, $urls);
        if ($count === 0 && !$had) {
            return;
        }
        if ($held && get_post_status($productId) === 'draft') {
            self::publish_or_hold($productId, max($count, $had ? 1 : 0));
        }
        if ($hidden) {
            self::unhide($productId);
        }
    }

    /* ── pictures ───────────────────────────────────── */

    /** @return string[] verified picture URLs from the backend gate, else the legacy Zid list. */
    public static function picture_urls(array $data): array
    {
        $urls = $data['gate']['pictures'] ?? [];
        if (empty($urls)) {
            $urls = $data['images'] ?? [];
        }
        return array_values(array_unique(array_filter(array_map('strval', (array) $urls), static fn ($u) => preg_match('#^https?://#i', $u) === 1)));
    }

    /**
     * Sideload each URL once (dedupe on the attachment's source meta). The first
     * becomes the featured image when the product has none; the rest join the
     * gallery. Returns how many pictures the product now has from this list.
     */
    public static function sideload_pictures(int $productId, array $urls, int $max = 6): int
    {
        if (empty($urls)) {
            return 0;
        }
        require_once ABSPATH . 'wp-admin/includes/media.php';
        require_once ABSPATH . 'wp-admin/includes/file.php';
        require_once ABSPATH . 'wp-admin/includes/image.php';

        $product = wc_get_product($productId);
        if (!$product) {
            return 0;
        }
        $gallery = array_map('intval', $product->get_gallery_image_ids());
        $featured = (int) $product->get_image_id();
        $have = 0;

        foreach (array_slice($urls, 0, $max) as $url) {
            $attachmentId = self::find_attachment($url);
            if (!$attachmentId) {
                $res = media_sideload_image($url, $productId, null, 'id');
                if (is_wp_error($res)) {
                    error_log("Zooboxi onboarding: picture failed {$url}: " . $res->get_error_message());
                    continue;
                }
                $attachmentId = (int) $res;
                update_post_meta($attachmentId, self::META_IMAGE_SRC, $url);
            }
            $have++;
            if ($featured === 0) {
                $featured = $attachmentId;
                set_post_thumbnail($productId, $attachmentId);
            } elseif ($attachmentId !== $featured && !in_array($attachmentId, $gallery, true)) {
                $gallery[] = $attachmentId;
            }
        }
        if ($gallery !== array_map('intval', $product->get_gallery_image_ids())) {
            $product->set_gallery_image_ids($gallery);
            $product->save();
        }
        return $have;
    }

    private static function find_attachment(string $url): int
    {
        global $wpdb;
        $id = $wpdb->get_var($wpdb->prepare(
            "SELECT post_id FROM {$wpdb->postmeta} WHERE meta_key = %s AND meta_value = %s LIMIT 1",
            self::META_IMAGE_SRC, $url
        ));
        return $id && get_post_status((int) $id) ? (int) $id : 0;
    }

    /* ── publish / hold ─────────────────────────────── */

    private static function publish_or_hold(int $productId, int $pictures): void
    {
        if ($pictures > 0 || (int) get_post_thumbnail_id($productId) > 0) {
            delete_post_meta($productId, self::META_HOLD);
            if (get_post_status($productId) !== 'publish') {
                wp_update_post(['ID' => $productId, 'post_status' => 'publish']);
                do_action('zooboxi_catalog_product_published', $productId);
            }
            return;
        }
        update_post_meta($productId, self::META_HOLD, 'no_image');
        if (get_post_status($productId) !== 'draft') {
            wp_update_post(['ID' => $productId, 'post_status' => 'draft']);
        }
    }

    /** Reverse the launch-day hide: visibility terms + Yoast noindex + our flag. */
    private static function unhide(int $productId): void
    {
        wp_remove_object_terms($productId, ['exclude-from-catalog', 'exclude-from-search'], 'product_visibility');
        delete_post_meta($productId, '_yoast_wpseo_meta-robots-noindex');
        delete_post_meta($productId, '_zooboxi_hidden_no_image');
        if (function_exists('wc_delete_product_transients')) {
            wc_delete_product_transients($productId);
        }
    }

    /* ── ShipGo ─────────────────────────────────────── */

    /**
     * Announce the SKU to ShipGo: files the listing there and returns today's
     * ATP, which we write into the ShipGo slot right away. Silent when the
     * shipgo-connect plugin is absent or the SKU is unknown to ShipGo (that
     * product is an express-only item — the SAP feed owns its stock).
     */
    public static function link_shipgo(int $productId, string $sku): void
    {
        if ($sku === '' || !class_exists('ShipGo_Client')) {
            return;
        }
        $res = \ShipGo_Client::post('/v1/channel/catalog/link', ['skus' => [$sku]]);
        if (!$res['ok'] || empty($res['data']['results'][0])) {
            if (!$res['ok']) {
                error_log("Zooboxi onboarding: ShipGo link failed for {$sku}: " . ($res['error'] ?? 'HTTP ' . $res['status']));
            }
            return;
        }
        $row = $res['data']['results'][0];
        update_post_meta($productId, '_zooboxi_shipgo_linked', $row['linked'] ? current_time('mysql') : 'unmatched');
        if (!empty($row['linked']) && isset($row['atp']) && class_exists('Zooboxi_Stock_Manager')) {
            $codes = \Zooboxi_Stock_Manager::shipgo_codes();
            if (!empty($codes)) {
                \Zooboxi_Stock_Manager::set_warehouse_stock($productId, (string) $codes[0], (float) $row['atp']);
            }
        }
    }

    /* ── metadata, taxonomy, SEO ────────────────────── */

    public static function stamp_meta(int $productId, array $data): void
    {
        update_post_meta($productId, '_zooboxi_sap_name', $data['item_name'] ?? '');
        update_post_meta($productId, '_zooboxi_sap_foreign_name', $data['foreign_name'] ?? '');
        update_post_meta($productId, '_zooboxi_brand_code', $data['brand_code'] ?? '');
        update_post_meta($productId, '_zooboxi_barcode', $data['barcode'] ?? '');
        update_post_meta($productId, '_zooboxi_uom', $data['uom'] ?? '');
        if (isset($data['sales_items_per_unit']) && (float) $data['sales_items_per_unit'] > 0) {
            update_post_meta($productId, '_zooboxi_sales_items_per_unit', (string) round((float) $data['sales_items_per_unit']));
        }
        update_post_meta($productId, '_zooboxi_price_lists', wp_json_encode($data['prices'] ?? []));
        update_post_meta($productId, '_zooboxi_last_sync', current_time('mysql'));
        if (!empty($data['keywords'])) {
            update_post_meta($productId, '_zooboxi_keywords', $data['keywords']);
        }
        foreach (['_zooboxi_name_en' => 'name_en', '_zooboxi_description_en' => 'description_en', '_zooboxi_short_description_en' => 'short_description_en'] as $meta => $key) {
            $v = trim((string) ($data[$key] ?? ''));
            if ($v !== '') {
                update_post_meta($productId, $meta, $v);
            }
        }
        if (!empty($data['gate'])) {
            update_post_meta($productId, self::META_GATE, wp_json_encode([
                'status' => $data['gate']['status'] ?? null,
                'content_source' => $data['gate']['content_source'] ?? null,
                'activated_at' => $data['gate']['activated_at'] ?? null,
            ]));
        }
    }

    /**
     * "قطط > طعام رطب, هدايا" → nested terms, created only when the path is new.
     * The brand is filed as a category too (that is how the store browses brands).
     */
    public static function assign_categories(int $productId, string $catAr, string $brandName = ''): void
    {
        $termIds = [];
        foreach (array_filter(array_map('trim', explode(',', $catAr))) as $catPath) {
            $parentId = 0;
            foreach (array_filter(array_map('trim', explode('>', $catPath))) as $seg) {
                $term = term_exists($seg, 'product_cat', $parentId ?: null);
                if (!$term) {
                    $term = wp_insert_term($seg, 'product_cat', $parentId ? ['parent' => $parentId] : []);
                }
                if (is_wp_error($term)) {
                    break;
                }
                $parentId = is_array($term) ? (int) $term['term_id'] : (int) $term;
            }
            if ($parentId) {
                $termIds[] = $parentId;
            }
        }
        if ($brandName !== '') {
            $brand = term_exists($brandName, 'product_cat') ?: wp_insert_term($brandName, 'product_cat');
            if (!is_wp_error($brand)) {
                $termIds[] = is_array($brand) ? (int) $brand['term_id'] : (int) $brand;
            }
        }
        if (!empty($termIds)) {
            wp_set_object_terms($productId, array_values(array_unique($termIds)), 'product_cat');
        }
    }

    private static function stamp_seo(int $productId, array $data): void
    {
        $title = trim((string) ($data['gate']['seo_title_ar'] ?? ''));
        $desc = trim((string) ($data['gate']['seo_description_ar'] ?? ''));
        if ($title !== '' && !get_post_meta($productId, '_yoast_wpseo_title', true)) {
            update_post_meta($productId, '_yoast_wpseo_title', $title);
        }
        if ($desc !== '' && !get_post_meta($productId, '_yoast_wpseo_metadesc', true)) {
            update_post_meta($productId, '_yoast_wpseo_metadesc', $desc);
        }
    }

    /* ── helpers ────────────────────────────────────── */

    private static function price(array $data): ?float
    {
        $list = (int) get_option('zooboxi_default_price_list', 1);
        foreach ((array) ($data['prices'] ?? []) as $key => $row) {
            if (!is_array($row)) continue;
            $pl = $row['PriceList'] ?? $row['priceList'] ?? $row['price_list'] ?? (is_numeric($key) ? (int) $key : null);
            if ($pl !== null && (int) $pl === $list) {
                $p = (float) ($row['Price'] ?? $row['price'] ?? 0);
                return $p > 0 ? $p : null;
            }
        }
        return null;
    }

    private static function first_nonempty(array $data, array $keys): string
    {
        foreach ($keys as $k) {
            $v = trim((string) ($data[$k] ?? ''));
            if ($v !== '') return $v;
        }
        return '';
    }
}
