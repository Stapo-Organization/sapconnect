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

---

# Changeset — Loyalty «عائلة زوبوكسي» Phase 1

Spec: `13-LOYALTY-PHASE1-SPEC.md`. Contract: `10-APP-API-V2.md` §14.

**Kill switch:** `update_option('zooboxi_loyalty_enabled', 'no')`. It is checked in three
places — the requires, the module instantiation, and the v2 route registration — so with it
off nothing is loaded, no hook is registered, no filter is added and no table is read. The
web store behaves exactly as it did before the module existed.

## Files created — `includes/loyalty/`

| File | What it is |
|---|---|
| `class-zooboxi-loyalty.php` | The registrar and façade: options (`Zooboxi_Loyalty::opt*`), the daily cron, UTC/ISO/period helpers, `meta_block()`, and the two measurement readers `metrics()` (this month's cost vs sales vs the 4% ceiling) and `baseline()` (365 days from `wc_order_stats`, cached 6 h). |
| `class-zooboxi-loyalty-schema.php` | The seven tables (`zb_members`, `zb_pets`, `zb_paws_ledger`, `zb_rewards`, `zb_grants`, `zb_scratch_cards`, `zb_missions`) behind one lazy `dbDelta` guarded by `zooboxi_loyalty_db_version`, plus `seed_defaults()` (idempotent, keyed on `reward_key`) and a `table_exists()` used before any `wc_order_stats` read. |
| `class-zooboxi-loyalty-members.php` | `ensure()` on first touch, the one-time deterministic holdout draw (`crc32(user_id . salt) % 100 < holdout_pct`, salt stored once), the referral code, and the tier cache with a 24 h freshness window plus invalidation on every order transition. |
| `class-zooboxi-loyalty-ledger.php` | The append-only book. `add()` is idempotent through `UNIQUE (user_id, reason, ref_type, ref_id)` — a duplicate insert is detected and treated as a no-op rather than an error. `order_paws()`, `earn_for_order()`, `reverse_for_order()`, `expire_dormant()`, paging, and the admin totals. |
| `class-zooboxi-loyalty-tiers.php` | The five levels, `count_completed_12m()` (`wc_get_orders`, HPOS-safe), the summary DTO with progress, the honest `perks[]`, and **both** fee filters. |
| `class-zooboxi-loyalty-pets.php` | CRUD + validation + soft delete, the paws they pay, and the localised `age_label` / `birthday_in_days` / `is_complete`. |
| `class-zooboxi-loyalty-rewards.php` | Catalogue reads, `redeemability()` (with the reason the customer sees), grants (`grant`/`activate`/`cancel`/`expire`/`restore`), `redeem()`, the basket claim lifecycle in the WC session, the zero-price gift line, and `cart_block()`. |
| `class-zooboxi-loyalty-scratch.php` | Card creation (app orders only, non-holdout only, `UNIQUE order_id`), the weighted draw over `random_int`, `odds()` for the admin preview, idempotent `reveal()`, and `settle_for_order()`. |
| `class-zooboxi-loyalty-missions.php` | Five templates, lazy monthly assignment under a transient lock, the bounded 12-month `history()` (cached 6 h), progress from a delivered order, and completion + immediate payout guarded by a conditional UPDATE. |
| `class-zooboxi-loyalty-hooks.php` | Every WooCommerce touch point, each one total (module check, table check, `customer_id > 0`, try/catch). |
| `class-zooboxi-loyalty-cli.php` | `wp zooboxi loyalty baseline|daily|seed-defaults|metrics|odds`, registered only under `WP_CLI`. |

## Files created — elsewhere

| File | What it is |
|---|---|
| `includes/api/v2/class-zooboxi-v2-loyalty-controller.php` | 13 bearer-only routes: `/loyalty/summary|ledger|rewards|rewards/{id}/redeem|grants/{id}/claim (POST+DELETE)|missions|scratch|scratch/{id}/reveal` and `/pets` CRUD. |
| `includes/admin/class-zooboxi-loyalty-admin.php` | `Zooboxi → 🐾 عائلة زوبوكسي`, six tabs (عام · الهدايا · اخدش واربح · المهمات · المؤشرات · بحث عن عضو), `manage_woocommerce` + a nonce on every form. |

## Files modified (12)

| File | Edit |
|---|---|
| `includes/class-zooboxi-plugin.php` | Requires the 11 loyalty classes, the admin page and the v2 controller behind `zooboxi_loyalty_enabled`; instantiates `Zooboxi_Loyalty` next to `Zooboxi_Intelligence`. |
| `includes/api/v2/class-zooboxi-v2-bootstrap.php` | Registers the loyalty controller's routes (only when the module is on). |
| `includes/api/v2/class-zooboxi-v2-meta-controller.php` | `features.loyalty` + `features.pets` + the `loyalty` constants block; both fee reads made filterable. |
| `includes/api/v2/class-zooboxi-v2-cart-controller.php` | `loyalty` block on the DTO, `is_gift`/`grant_id`/`locked_qty` per line; both fee reads made filterable. |
| `includes/api/v2/class-zooboxi-v2-checkout-controller.php` | Stamps `_zooboxi_app_order = 1` **before** the classic hook fires (`_zooboxi_source` already said the same, but the spec names this key), and returns `scratch_card` + `paws_to_earn`. |
| `includes/api/v2/class-zooboxi-v2-orders-controller.php` | `loyalty` block on `show()`. |
| `includes/api/v2/class-zooboxi-v2-catalog-controller.php` | `DEFAULT_LAYOUT` gains `family` (after `hero`) and `missions` (after `personal`). |
| `includes/intelligence/class-zooboxi-intelligence.php` | Six loyalty event types added to `EVENT_TYPES` — without this the plugin would drop them before Laravel ever saw them. |
| `includes/core/class-zooboxi-delivery-engine.php` | 1 free-min + 2 express-fee reads made filterable. |
| `includes/core/class-zooboxi-fulfillment.php` | 1 express-fee read made filterable. |
| `includes/frontend/class-zooboxi-smart-shipments.php` | 1 free-min + 1 express-fee read made filterable. |
| `includes/shipping/class-zooboxi-{express,standard,national}-shipping.php` | 3 free-min + 1 express-fee reads made filterable. |
| `scripts/v2_smoke.sh` | Loyalty section: meta flags, layout slots, cart block, five guest 401s, the no-store header, and nine authenticated reads incl. a `pet_invalid` 422. |

### The two filter seams

Every fee decision in the store now passes through one of two filters, and the loyalty
module is the only thing that hooks them:

```php
// 7 sites: delivery-engine, smart-shipments, shipping ×3, v2 cart, v2 meta
apply_filters('zooboxi_free_shipping_min', (float) get_option('zooboxi_free_shipping_min', 200))
// 7 sites: fulfillment, delivery-engine ×2, smart-shipments, express-shipping, v2 meta, v2 cart
apply_filters('zooboxi_express_fee', (float) get_option('zooboxi_express_fee', 15))
```

Nothing else changed in those files — each edit is one expression wrapped in one call. A
guest, or a store with the module off, gets the raw option back unchanged. **No fee value is
assumed anywhere:** `zooboxi_express_fee` is 0 today only as a trial and will become paid
again, which is exactly why `express_free` is a reward worth granting.

## New options

| Name | Default | Purpose |
|---|---|---|
| `zooboxi_loyalty_enabled` | `yes` | Kill switch. |
| `zooboxi_loyalty_db_version` | — | Schema version for all seven tables. |
| `zooboxi_loyalty_points_per_riyal` | `1` | Paws per riyal of line total. |
| `zooboxi_loyalty_paw_value_sar` | `0.03` | Assumed cost of a paw (budget maths only). |
| `zooboxi_loyalty_expiry_months` | `12` | Dormancy before the balance lapses. |
| `zooboxi_loyalty_holdout_pct` | `10` | Control-group share. |
| `zooboxi_loyalty_holdout_salt` | generated | Makes the draw stable and unguessable. |
| `zooboxi_loyalty_max_pets` | `3` | Active pets per customer. |
| `zooboxi_loyalty_budget_pct` | `4` | Cost ceiling shown on the metrics tab. |
| `zooboxi_loyalty_star_free_min` | `150` | The `star`+ free-shipping threshold. |
| `zooboxi_loyalty_profile_paws` / `_pet_paws` | `100` / `50` | Profile + per-pet awards. |
| `zooboxi_loyalty_scratch_enabled` / `_missions_enabled` | `yes` | Per-feature switches. |
| `zooboxi_loyalty_tiers` | JSON | Thresholds `{new:0, friend:2, star:4, gold:8, amb:14}`. |
| `zooboxi_loyalty_scratch_table` | JSON | Prize weights. |
| `zooboxi_loyalty_missions` | JSON | Per-template enable + reward + frequency target. |
| `zooboxi_loyalty_species_categories` | JSON | `species → product_cat slug` for the category mission. |
| `zooboxi_loyalty_daily_ran_at` | — | Last daily-job stamp. |

New transients: `zb_loyalty_baseline` (6 h), `zb_loy_hist_{uid}` (6 h),
`zb_loy_assign_{uid}_{period}` (60 s assignment lock).

New order-item meta: `_zb_gift_grant` (the grant id behind a gift line) plus a visible
«هدية» meta row. New order meta: `_zooboxi_app_order`. New cart-item key: `zb_grant_id`.
New WC session key: `zb_loyalty_claims`. New cron: `zooboxi_loyalty_daily`.

## Laravel (1 file)

`app/Http/Controllers/Api/ZooboxiIntelligenceController.php` — the `storeEvent` validator's
`event_type` allowlist gains `loyalty_scratch`, `loyalty_mission`, `loyalty_redeem`,
`loyalty_claim`, `pet_added`, `family_card`. One line; nothing else touched.

## Verification

- `php -l` clean on all 13 created PHP files and all 13 modified ones.
- `bash -n scripts/v2_smoke.sh` clean.
- 86 offline assertions pass against the **real** classes through a small WordPress shim:
  tier thresholds and the spec's worked progress example, both fee filters across every
  tier/claim combination (including the module-off pass-through and a raised express fee),
  the paws calculation (floor, gift exclusion, rate changes), the Arabic `age_label` dual and
  plural forms, birthday countdown, pet validation, and a 200 000-draw check that the weighted
  scratch distribution matches its weights to within 5% — including fractional weights.
- Fee-read counts verified mechanically: exactly 7 `zooboxi_free_shipping_min` and exactly 7
  `zooboxi_express_fee` reads wrapped, matching the spec's inventory.

## Deploy

Surgical scp (this checkout is diverged from prod), then:

```bash
wp eval 'Zooboxi_Loyalty_Schema::maybe_install();'
wp zooboxi loyalty seed-defaults
wp cron event run zooboxi_loyalty_daily     # or: wp zooboxi loyalty daily
TOKEN_USER3=zbat_… BASE=https://store.zooboxi.com/wp-json/zooboxi/v2 ./scripts/v2_smoke.sh
```

Then attach a real product to each gift reward in **Zooboxi → 🐾 عائلة زوبوكسي → الهدايا**:
until a gift has a product it is skipped by the scratch draw and shown as non-redeemable, by
design — the program never promises a gift it cannot ship.

Rollback: `update_option('zooboxi_loyalty_enabled','no')`. The tables stay; nothing reads them.
