# 11 — `zooboxi/v2` changeset

Everything the mobile API added to the live store, file by file. The web store's behaviour is
unchanged: new code lives in new files, and the four edits to existing files are extract-method
refactors plus one opt-in query flag that no web query ever sets.

**Kill switch:** `update_option('zooboxi_v2_enabled', 'no')` unloads the entire namespace
(the requires and the bootstrap are both inside that guard). Default is `yes`.

---

## Files created — `plugin/zooboxi-multi-warehouse/includes/api/v2/`

| File | What it is |
|---|---|
| `class-zooboxi-v2-bootstrap.php` | Request pipeline: bearer auth via `determine_current_user` (priority 99, v2 requests only), X-ZB-* location headers seeded into `$_COOKIE` before any store logic runs, WC-session mirroring, Polylang language switch + `lang_fallback`, the `{ok,data,error}` envelope, ETag/Cache-Control helpers, route registration, and the additive `woocommerce_order_status_changed` hook that stamps `_zb_status_{status}_at` and calls the new status mirror. |
| `class-zooboxi-app-tokens.php` | `wp_zooboxi_app_tokens` table (lazy `dbDelta` on `zooboxi_v2_db_version`, since scp deploys never fire activation). Issues `zbat_` tokens, stores only their SHA-256, verifies, slides expiry once a day, revokes. |
| `class-zooboxi-product-dto.php` | The single product serializer (card + PDP). Explicit field allowlists, location-aware stock capped at 99, badges from `Zooboxi_Dynamic_Badges`, delivery chip/plan from `Zooboxi_Fulfillment`, the canonical emoji-swatch map, the shared `_zbx_wishlist` read, and the cached FBT/substitutes proxy. |
| `class-zooboxi-v2-auth-controller.php` | `/auth/otp/send`, `/auth/otp/verify` (token instead of cookie + guest→user cart merge), `/auth/logout`, `GET /me`, `PATCH /me`. Adds a per-IP burst throttle on top of the shared OTP limits. |
| `class-zooboxi-v2-location-controller.php` | `/location/cities`, `/location/resolve` (pure — writes no session/cookie), `/location/pickup-points`. |
| `class-zooboxi-v2-catalog-controller.php` | `/home`, `/catalog/categories`, `/catalog/products` (facets + sort parity), `/catalog/products/{id}`, `/catalog/search/suggest`, `/catalog/barcode/{code}`, `/brands`, `/brands/{slug}`, `/clearance`. |
| `class-zooboxi-v2-cart-controller.php` | The real `WC()->cart` over REST: deterministic guest session (WooCommerce-shaped `t_…` customer id + signed session cookie seeded into `$_COOKIE`), the full cart DTO with per-line fulfilment, shipments, free-shipping progress and drained notices, plus the guest→user merge helpers. |
| `class-zooboxi-v2-checkout-controller.php` | `GET /checkout`, `POST /checkout` (address-wins location re-seed, per-package shipping auto-pick, `WC_Checkout::create_order` + the classic `woocommerce_checkout_order_processed` hook), `POST /orders/{id}/pay`, `GET /orders/{id}/status`. |
| `class-zooboxi-v2-orders-controller.php` | `GET /orders`, `GET /orders/{id}` (timeline + ShipGo tracking), `POST /orders/{id}/reorder`. |
| `class-zooboxi-v2-account-controller.php` | `/wishlist`, `/wishlist/toggle`, addresses CRUD + default, `/account/buy-again`. |
| `class-zooboxi-v2-events-controller.php` | `POST /events` — single or batched (≤ 50), forwarded through the shared intelligence path. |
| `class-zooboxi-v2-meta-controller.php` | `GET /meta` — force-update gate, fees, thresholds, feature flags. |

## Files created — repo

| File | What it is |
|---|---|
| `docs/10-APP-API-V2.md` | The implemented contract; the Flutter app's source of truth. |
| `docs/11-V2-CHANGESET.md` | This file. |
| `scripts/v2_smoke.sh` | Read-only curl smoke suite (`BASE=… ./scripts/v2_smoke.sh`). Not run from here — no network calls were made. |

---

## Files modified (6)

| File | Change |
|---|---|
| `includes/class-zooboxi-plugin.php` | **(a)** requires for the 12 v2 files + `new Zooboxi_V2_Bootstrap()`, both inside `if (get_option('zooboxi_v2_enabled','yes') === 'yes')`. **(b)** `sort_products_by_stock()` now also runs for a query carrying the `zooboxi_v2_listing` flag. |
| `includes/intelligence/class-zooboxi-intelligence.php` | `prioritize_express_availability()` honours the same `zooboxi_v2_listing` flag; `ajax_track()` became a thin wrapper over the new `public static forward_event()` + `post_events()` (same allowlist, same fields, same non-blocking POST). |
| `includes/auth/class-zooboxi-otp-auth.php` | `ajax_send_otp()` / `ajax_verify_otp()` became thin wrappers (nonce, auth cookie, JSON payload and new nonce all still here) over the new `public static send_otp()` / `verify_otp()`. Added `public static client_ip()` alias. |
| `includes/frontend/class-zooboxi-smart-shipments.php` | `build_tier_groups()` promoted from `private function` to `public static function` (it was already a pure function); its two call sites now use `self::`. |
| `includes/homepage/class-zooboxi-home-feed.php` | Extracted `public static buyagain_ids()` out of `buyagain_html()`; the HTML method still caches into the same `zbhome_buyagain_{uid}` transient. |
| `includes/sync/class-zooboxi-sync-engine.php` | Added `public function push_order_status(int $orderId, string $newStatus)` — the status/payment mirror that was missing after `push_order()`. Purely additive; no existing method touched. |

*No theme file was modified — the emoji-swatch map was **copied** into the DTO rather than
moved out of `theme/functions.php`, so the web quick-view keeps its own working copy.*

---

## The exact loader diff

`includes/class-zooboxi-plugin.php`, end of `load_dependencies()`:

```diff
         // Brand boutique pages (/brand/<slug>/): backend sync + themed archive takeover.
         require_once ZOOBOXI_PLUGIN_DIR . 'includes/intelligence/class-zooboxi-brand-sync.php';
         require_once ZOOBOXI_PLUGIN_DIR . 'includes/frontend/class-zooboxi-brand-page.php';
+
+        // Mobile app API (namespace zooboxi/v2). Purely additive; kill switch:
+        // set option `zooboxi_v2_enabled` to anything but 'yes' to unload it entirely.
+        if (get_option('zooboxi_v2_enabled', 'yes') === 'yes') {
+            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-app-tokens.php';
+            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-v2-bootstrap.php';
+            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-product-dto.php';
+            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-v2-auth-controller.php';
+            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-v2-location-controller.php';
+            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-v2-catalog-controller.php';
+            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-v2-cart-controller.php';
+            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-v2-checkout-controller.php';
+            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-v2-orders-controller.php';
+            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-v2-account-controller.php';
+            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-v2-events-controller.php';
+            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-v2-meta-controller.php';
+        }
     }
```

`includes/class-zooboxi-plugin.php`, inside `register_hooks()`:

```diff
         // Smart hero slider (front render is static; instance registers the admin panel).
         new Zooboxi_Hero_Slider();
+
+        // Mobile app API (zooboxi/v2) — same kill switch as its requires above.
+        if (get_option('zooboxi_v2_enabled', 'yes') === 'yes' && class_exists('Zooboxi_V2_Bootstrap')) {
+            new Zooboxi_V2_Bootstrap();
+        }
```

The two sort-parity edits:

```diff
-        if (is_admin() || !$query->is_main_query()) return $clauses;
+        if (is_admin() || (!$query->is_main_query() && !$query->get('zooboxi_v2_listing'))) return $clauses;
```

(`Zooboxi_Plugin::sort_products_by_stock`, and the same one-line change in
`Zooboxi_Intelligence::prioritize_express_availability`.)

---

## Verification

- `php -l` passes on all 12 created files and all 6 modified files.
- `bash -n scripts/v2_smoke.sh` passes.
- Hook registrations verified intact after the refactors: the six `wp_ajax_*` OTP actions,
  both `wp_ajax_zooboxi_track` actions, all six Smart-Shipments filters/actions, and the
  `posts_clauses` registrations.
- Nonce checks verified intact: `check_ajax_referer('zooboxi_nonce','nonce')` still guards both
  OTP AJAX handlers, `wp_verify_nonce` still guards `ajax_complete_profile`, and
  `wp_set_auth_cookie` + `wp_create_nonce` still run in the verify wrapper.

## New options / tables

| Name | Default | Purpose |
|---|---|---|
| `zooboxi_v2_enabled` | `yes` | Kill switch. |
| `zooboxi_v2_db_version` | — | Schema version for the token table. |
| `zooboxi_min_app_ios`, `zooboxi_min_app_android` | `0.0.0` | Force-update gate. |
| `zooboxi_v2_maintenance` | `no` | App-only maintenance banner. |
| `wp_zooboxi_app_tokens` | — | Bearer tokens (SHA-256 hashes only). |

New transients: `zb_v2_recs_{md5}` (30 min), `zb_v2_price_bounds` (1 h), `zb_v2_buyagain_{uid}`
(15 min), `zb_v2_otp_ip_{md5}` (10 min). The home rails reuse the website's existing
`zbhome_ids_{key}_{locale}` transients.

New order meta: `_zb_status_{status}_at`, `_zooboxi_source`, `_zooboxi_status_pushed_at`
(plus the existing `_zooboxi_checkout_lat/lng`).

## Deploy note

Deploy by surgical scp (this checkout is diverged from prod). Copy the new
`includes/api/v2/` directory and the six modified files, then hit
`/wp-json/zooboxi/v2/meta` once to trigger the lazy table creation, then run
`scripts/v2_smoke.sh`. Allowlist `/wp-json/zooboxi/v2/*` in Wordfence before the burst test.
Rollback = `update_option('zooboxi_v2_enabled','no')`.
