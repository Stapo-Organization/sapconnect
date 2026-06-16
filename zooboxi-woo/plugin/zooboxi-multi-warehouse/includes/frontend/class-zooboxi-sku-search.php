<?php
/**
 * Zooboxi SKU / Item-Code Search — make the storefront search match products by
 * barcode (the WooCommerce SKU) and by SAP item code (_zooboxi_item_code meta).
 *
 * WooCommerce's default front-end search only matches the post title/excerpt/content.
 * Our products carry an ARABIC title and store the barcode as the SKU and the SAP
 * code only in meta — so a search for "P12600221" or the barcode "664533287903"
 * returned nothing even though the product is live. This filter ORs those two
 * identifiers into the existing search so a code/barcode lookup finds the product,
 * without weakening the normal Arabic title search (it only ADDS matches).
 *
 * Toggle from Settings → "بحث المتجر بالباركود ورمز الصنف" (option zooboxi_sku_search,
 * default on).
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Sku_Search
{
    public function __construct()
    {
        if (get_option('zooboxi_sku_search', 'yes') !== 'yes') {
            return; // disabled from the settings page
        }
        add_filter('posts_search', [$this, 'include_identifiers_in_search'], 10, 2);
    }

    /**
     * OR a "product matches this barcode / SAP code" condition into the main
     * storefront search query.
     *
     * @param  string    $search   the SQL search clause WP built (" AND (<group>) [AND (pwd)]")
     * @param  \WP_Query  $query
     * @return string
     */
    public function include_identifiers_in_search($search, $query): string
    {
        if ($search === '' || !$this->applies($query)) {
            return $search;
        }

        global $wpdb;

        $term = trim((string) $query->get('s'));
        if ($term === '') {
            return $search;
        }

        // Find products whose SKU (barcode) or SAP item code contains the term.
        $like = '%' . $wpdb->esc_like($term) . '%';
        $ids = $wpdb->get_col($wpdb->prepare(
            "SELECT DISTINCT post_id FROM {$wpdb->postmeta}
             WHERE meta_key IN ('_sku', '_zooboxi_item_code') AND meta_value LIKE %s",
            $like
        ));

        if (empty($ids)) {
            return $search; // no code/barcode hit — leave the normal title search untouched
        }

        $idList   = implode(',', array_map('absint', $ids));
        $idClause = "{$wpdb->posts}.ID IN ({$idList})";

        // WP's $search is " AND (<title group>) [AND (post_password='')]". Inject our OR
        // into the FIRST group only (limit 1) so operator precedence and the password
        // clause stay intact: " AND ( <ids> OR (<title group>) ) AND (pwd)". The query's
        // own post_type/post_status ANDs still constrain the id list to live products.
        $search = preg_replace('/ AND \(/', " AND ( {$idClause} OR ", $search, 1);

        return $search;
    }

    /**
     * Only the main front-end product search-results query.
     */
    private function applies($query): bool
    {
        if (is_admin() || !($query instanceof \WP_Query)) {
            return false;
        }
        if (!$query->is_main_query() || !$query->is_search()) {
            return false;
        }

        // Limit to product (or unscoped/any) searches; never touch a post/page search.
        $pt = $query->get('post_type');
        return $pt === '' || $pt === 'any' || $pt === 'product'
            || (is_array($pt) && in_array('product', $pt, true));
    }
}
