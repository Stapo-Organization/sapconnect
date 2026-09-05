# 10 — Mobile App API (`zooboxi/v2`)

The contract the Zooboxi customer app is built against. Implemented additively inside
`plugin/zooboxi-multi-warehouse/includes/api/v2/`; the website is untouched.

- **Base URL:** `https://store.zooboxi.com/wp-json/zooboxi/v2`
- **Kill switch:** option `zooboxi_v2_enabled` — anything other than `yes` unloads the whole namespace.
- **Content type:** `application/json` in and out.
- **Everything is Arabic-first.** `?lang=en` switches the locale and Polylang mapping; when a
  translation is missing the Arabic value is served and `lang_fallback: true` appears in the payload.

---

## 1. Envelope

Every response — success or failure — has the same shape.

```json
{ "ok": true,  "data": { }, "error": null }
```

```json
{
  "ok": false,
  "data": null,
  "error": {
    "code": "cart_empty",
    "message_ar": "سلتك فارغة",
    "message_en": "Your cart is empty.",
    "message": "سلتك فارغة"
  }
}
```

`error.message` is already resolved to the request's language. Some failures carry context in
`data` (e.g. `cart_changed` returns `data.cart`, a full cart DTO).

HTTP status codes are meaningful: `401` unauthenticated, `404` missing, `409` conflict
(empty cart, coupon already used, unavailable gateway), `422` validation, `429` rate limited,
`503` WooCommerce/session unavailable.

---

## 2. Request headers

| Header | Required | Purpose |
|---|---|---|
| `Authorization: Bearer zbat_…` | for account/orders/wishlist | Token from `/auth/otp/verify`. Invalid ⇒ treated as guest. |
| `X-ZB-Guest: <uuid>` | for guest cart + events | Stable per-install device id (`[A-Za-z0-9._-]{8,64}`). Keys the guest cart and the anon event id. |
| `X-ZB-Lat`, `X-ZB-Lng` | strongly recommended | Customer coordinates. **This is what makes stock, badges, promises, shipping and the cart cap location-aware.** |
| `X-ZB-City`, `X-ZB-District` | recommended | Resolved place names. |
| `X-ZB-Delivery-Type` | optional | `express` \| `same_day` \| `shipping`. |
| `X-ZB-App` | optional | `ios/1.2.0` — for logs. |

The server seeds these into the in-request cookie jar before any store logic runs, so the app
behaves exactly like a browser that has set the location popup. **Send them on every request.**

## 3. Caching

Catalogue GETs return `Cache-Control: public, max-age=N` plus a strong `ETag`; send
`If-None-Match` to get a `304`.

| Endpoint | max-age |
|---|---|
| `/home` | 300 |
| `/catalog/categories`, `/location/cities`, `/brands` | 3600 |
| `/catalog/products`, `/catalog/search/suggest`, `/clearance`, `/brands/{slug}` | 120 |
| `/catalog/products/{id}` | 60 |
| `/meta` | 300 |

Everything personal (cart, checkout, orders, account, auth) is `private, no-store`.
The ETag varies by payload **+ language + city**, so changing location busts it.

---

## 4. Meta

### `GET /meta`

```json
{ "ok": true, "data": {
  "min_app_version": { "ios": "0.0.0", "android": "0.0.0" },
  "free_shipping_min": 200,
  "fees": { "express": 0, "standard": 10, "shipping": 25 },
  "currency": "SAR",
  "features": { "smart_shipments": true, "wishlist": true, "clearance": true, "badges": true },
  "maintenance": false,
  "lang": "ar"
}}
```

Call on launch. If the running build is below `min_app_version`, show the force-update gate.

---

## 5. Auth

### `POST /auth/otp/send`
Body: `{ "phone": "0500141072" }` · no nonce; protected by the shared per-phone (3/15 min) and
per-IP (10/hour) limits plus an app-side burst limit (5 per IP per 10 min).

```json
{ "ok": true, "data": { "display_phone": "05XX XXX XX72", "resend_after": 60, "expires_in": 180 } }
```
Errors: `phone_required` (422), `rate_limited` (429).

### `POST /auth/otp/verify`
Body: `{ "phone": "0500141072", "otp": "1234", "platform": "ios", "device_name": "iPhone 15" }`
Send `X-ZB-Guest` to merge the guest basket into the account (quantities **sum**).

```json
{ "ok": true, "data": {
  "token": "zbat_x9f…",
  "is_new": false,
  "user": { "id": 42, "name": "محمد", "phone": "0500141072", "email": "" },
  "cart_merged": true,
  "merged_lines": 2,
  "needs_profile": false
}}
```
The token is returned **once** — store it in the keychain. Valid 365 days, slid on use.
Errors: `no_otp`, `expired`, `wrong_otp` (with `data.remaining`), `blocked` (429).

### `POST /auth/logout` (bearer) → `{ "revoked": true }`

### `GET /me` (bearer) → `{ "id", "name", "phone", "email" }`
### `PATCH /me` (bearer) — body `{ "name"?: string, "email"?: string }` → the same user object.
Errors: `invalid_email`, `email_taken` (409), `nothing_to_update`.

---

## 6. Location

### `GET /location/cities`
```json
{ "cities": [ { "city": "الرياض", "has_central": true,
  "central": { "code": "RUH003", "name": "شحن الرياض", "lat": 24.71, "lng": 46.67 } } ] }
```

### `POST /location/resolve`
Body: `{ "lat": 24.7136, "lng": 46.6753 }` — pure, writes nothing.
```json
{
  "city": "الرياض", "district": "الملز",
  "options": {
    "express":  { "delivery_type": "express", "warehouse_code": "RUH004", "warehouse_name": "فرع الربيع", "estimated_time": "خلال ساعتين", "fee": 0, "distance_km": 3.4 },
    "standard": { "…": "…" }, "shipping": { "…": "…" },
    "pickup":   [ { "warehouse_code": "RUH002", "warehouse_name": "فرع النصر", "address": "…", "distance_km": 5.1, "phone": "", "fee": 0 } ]
  },
  "best": { "delivery_type": "express", "warehouse_code": "RUH004", "warehouse_name": "فرع الربيع", "promise_label": "خلال ساعتين", "fee": 0 }
}
```
Errors: `invalid_coordinates` (422).

### `GET /location/pickup-points?lat=&lng=` → `{ "pickup_points": [ … ] }` (nearest 10)

---

## 7. Catalogue

### Card DTO
Every list, rail and search result returns this shape.

```json
{
  "id": 1234, "item_code": "P12600221", "sku": "664533287903",
  "name": "طعام قطط…", "slug": "…",
  "brand": { "name": "Applaws", "slug": "applaws" },
  "image": "https://…", "gallery_thumb": "https://…",
  "price": 72.9, "regular_price": 89.0, "sale_price": 72.9,
  "on_sale": true, "price_from": false, "discount_pct": 18, "currency": "SAR",
  "stock_status": "instock", "stock_qty": 12, "is_variable": false,
  "badge": { "type": "hot", "label": "الأكثر طلباً", "icon": "🔥" },
  "delivery_chip": { "tier": "express", "label": "توصيل خلال ساعتين", "icon": "⚡" },
  "wishlisted": false
}
```

- `stock_qty` is **location-aware** and capped at 99; `null` when stock isn't managed.
- `price_from` = true ⇒ render "يبدأ من {price}" (variable product with a price range).
- `badge` is the single highest-priority badge; `delivery_chip` is `null` with no location.
- SAP costs, wholesale price lists and intelligence scores are **never** serialized.

### `GET /home`
```json
{
  "hero": [ { "image", "image_mobile", "link", "headline", "subheadline", "cta_label", "order" } ],
  "campaigns": [ { "campaign_id": 12, "ab_variant": "A", "zones": ["hero"], "image", "headline", "item_code", "product_id", "link" } ],
  "animal_nav": [ { "id", "slug", "name", "image", "count", "children": [] } ],
  "rails": [ { "key": "trending", "title": "رائج الآن", "products": [ Card ] } ],
  "brands": [ { "code": "176", "slug": "applaws", "name": "Applaws", "logo", "count", "boutique": true } ],
  "lang_fallback": false
}
```
Rail keys: `trending`, `bestsellers`, `new`, `clearance` (a rail is omitted when empty).

### `GET /catalog/categories?parent=0`
`{ "parent": 0, "categories": [ { "id", "slug", "name", "image", "count", "children": [ … ] } ] }`
One level of children is inlined; drill deeper with `?parent={id}`.

### `GET /catalog/products`

| Param | Notes |
|---|---|
| `category` | slug **or** term id; includes children |
| `brand` | `product_brand` slug |
| `q` | free text — also matches barcode / SAP item code |
| `sku` | exact `_sku` or `_zooboxi_item_code` |
| `pa_brand`, `pa_age`, `pa_flavor`, `pa_food_type`, `pa_health`, `pa_litter_type`, `pa_color`, `pa_material`, `pa_product_type`, `pa_size_opt`, `pa_weight_opt` | comma-separated term slugs (dashes in the taxonomy become underscores in the param) |
| `min_price`, `max_price` | numeric |
| `orderby` | `recommended` (default) · `price` · `price-desc` · `date` · `popularity` |
| `page`, `per_page` | `per_page` ≤ 48, default 24 |
| `lang` | `ar` (default) · `en` |

```json
{
  "products": [ Card ], "total": 412, "pages": 18, "page": 1, "per_page": 24,
  "orderby": "recommended",
  "facets": {
    "groups": [ { "taxonomy": "pa_brand", "label": "العلامة التجارية",
                  "terms": [ { "slug": "applaws", "name": "Applaws", "count": 62 } ] } ],
    "price": { "min": 5, "max": 890 }
  },
  "sort_options": [ { "key": "recommended", "label": "موصى به" } ],
  "lang_fallback": false
}
```

**Ordering matches the website exactly**: express-available first, then in-stock, then the
chosen sort, then a final location-aware out-of-stock sink. Facet groups follow the same
per-category relevance rules the web filter sidebar uses.

### `GET /catalog/products/{id}` — PDP
Card **plus**:
```json
{
  "gallery": [ "https://…" ],
  "description_html": "<p>…</p>", "short_description": "<p>…</p>",
  "brand_detail": { "name", "slug", "code", "accent": "#0d9488", "logo" },
  "categories": [ { "id", "name", "slug" } ],
  "attributes": [ { "label": "الوزن", "value": "2 كجم" } ],
  "variations": {
    "attributes": [ { "slug": "pa_flavor", "name": "pa_flavor", "label": "النكهة",
                      "options": [ { "slug": "chicken", "label": "دجاج", "emoji": "🍗" } ] } ],
    "list": [ { "variation_id": 991, "attributes": { "attribute_pa_flavor": "chicken" },
                "price": 72.9, "regular_price": 89.0, "image", "in_stock": true, "max_qty": 8, "sku" } ]
  },
  "delivery": {
    "headline": "⚡ خلال ساعتين",
    "tiers": [ { "tier": "express", "warehouse_name": "فرع الربيع", "stock": 8, "fee": 0,
                 "label": "توصيل سريع", "date_label": "اليوم", "relative_label": "خلال ساعتين",
                 "color": "#d9480f", "icon": "⚡" } ],
    "reachable_total": 14, "fastest": "express", "is_split": false
  },
  "per_warehouse": [ { "warehouse_name": "فرع الربيع", "tier": "express", "stock": 8 } ],
  "badges": [ { "type", "label", "icon" } ],
  "fbt": [ Card ], "substitutes": [ Card ],
  "lang_fallback": false
}
```
`variations.list[].max_qty` is the quantity cap the cart will enforce — bind the stepper to it.
`per_warehouse` lists only warehouses the customer can actually be served from.

### `GET /catalog/search/suggest?q=`
`{ "suggestions": [ { "id", "name", "image", "sku", "item_code", "price" } ] }` — up to 8; ≥ 2 characters.

### `GET /catalog/barcode/{code}`
Exact `_sku` / `_zooboxi_item_code`; a variation resolves to its parent.
`{ "product": Card }` · `404 product_not_found`.

### `GET /brands` · `GET /brands/{slug}`
```json
{ "code", "slug", "name", "boutique": true, "hero", "logo",
  "kit": { "accent", "accent_dark", "gold", "tagline" },
  "story": { "lead", "country", "founded", "mood" },
  "tiles": [ { "image", "headline" } ],
  "products": [ Card ] }
```

### `GET /clearance?page=&per_page=`
`{ "products": [ Card ], "total", "pages", "page", "per_page" }`

---

## 8. Cart

Guests **must** send `X-ZB-Guest` for any mutation (`guest_id_required`, 400). The server keeps a
real WooCommerce cart keyed off that id, so all the store rules apply — including the reachable
cap, whose adjustments arrive in `notices`.

| Method | Path |
|---|---|
| `GET` | `/cart` |
| `POST` | `/cart/items` — `{ product_id, variation_id?, quantity, attributes? }` |
| `PATCH` | `/cart/items/{key}` — `{ quantity }` (0 removes) |
| `DELETE` | `/cart/items/{key}` |
| `POST` | `/cart/coupon` — `{ code }` |
| `DELETE` | `/cart/coupon/{code}` |

`attributes` accepts either `{ "pa_flavor": "chicken" }` or `{ "attribute_pa_flavor": "chicken" }`.

Every call returns the full cart:

```json
{
  "items": [ {
    "key": "a1b2…", "product_id": 1234, "variation_id": 0,
    "name": "…", "image": "…", "attributes_label": "النكهة: دجاج",
    "qty": 2, "max_reachable": 14,
    "unit_price": 72.9, "line_subtotal": 145.8, "line_total": 145.8,
    "fulfillment": { "headline": "⚡ خلال ساعتين", "tier": "express", "is_split": false, "shortfall": 0 }
  } ],
  "count": 2,
  "shipments": [ { "tier": "express", "label": "توصيل سريع", "icon": "⚡", "color": "#d9480f",
                   "date_label": "اليوم", "relative_label": "خلال ساعتين",
                   "fee": 0, "free": true, "lines": [ { "name": "…", "qty": 2 } ] } ],
  "totals": { "subtotal": 145.8, "discount": 0, "shipping": 0, "tax": 0, "total": 145.8, "currency": "SAR" },
  "free_shipping": { "min": 200, "remaining": 54.2, "qualified": false },
  "coupons": [ { "code": "welcome10", "amount": 10 } ],
  "notices": [ { "type": "notice", "text": "عدّلنا كمية «…» إلى 3 …" } ]
}
```

`shipments` is always computed (the app shows split cards even when the web splitter flag is off).
`notices` is drained on read — surface it once and drop it.

Errors: `add_failed` (409, with the fresh cart in `data`), `item_not_found` (404),
`coupon_invalid` (422), `cart_session_unavailable` (503).

---

## 9. Checkout & payment

### `GET /checkout`
Requires a non-empty cart. Shipping methods are auto-selected per package by tier.

```json
{
  "shipments": [ … ], "items": [ … ], "totals": { … }, "free_shipping": { … },
  "coupons": [ … ], "notices": [ … ],
  "payment_methods": [ { "id": "cod", "label": "الدفع عند الاستلام", "sub": "…" },
                       { "id": "myfatoorah", "label": "البطاقات ومدى و Apple Pay", "sub": "…" } ],
  "addresses": [ { "id": "uuid", "label", "name", "phone", "city", "district",
                   "address_line", "lat", "lng", "is_default", "created_at" } ],
  "promise": { "is_split": false, "lines": [ { "tier", "label", "when" } ] }
}
```
Only gateways WooCommerce actually reports as available are listed.

### `POST /checkout`
```json
{
  "address_id": "uuid",
  "address": { "label": "المنزل", "name": "محمد", "phone": "0500141072",
               "city": "الرياض", "district": "الملز", "address_line": "شارع …",
               "lat": 24.7136, "lng": 46.6753, "save": true },
  "payment_method": "cod",
  "notes": "اتصل قبل الوصول"
}
```
Pass **either** `address_id` (bearer required) **or** `address`. The address coordinates win over
the header location: the cart is re-evaluated at the delivery point before anything is charged.

```json
{ "order_id": 32579, "order_number": "32579", "order_key": "wc_order_…",
  "total": 145.8, "currency": "SAR", "status": "processing",
  "payment_method": "cod", "payment_required": false, "shipping_chosen": { "0": "zooboxi_express" } }
```

- COD ⇒ status `processing`, `payment_required: false`, cart emptied.
- MyFatoorah ⇒ status `pending`, `payment_required: true` — go to `/orders/{id}/pay`.
- The classic `woocommerce_checkout_order_processed` hook fires, so the sapconnect mirror →
  staff app → SAP pipeline runs exactly as it does for a web order.

Errors: `cart_empty` (409), **`cart_changed` (409, `data.cart` = fresh cart — re-show the review
screen)**, `gateway_unavailable` (409), validation codes `name_required`, `phone_invalid`,
`coordinates_required`, `address_line_required`, `city_required`, `address_not_found`.

### `POST /orders/{id}/pay?key={order_key}`
`{ "payment_url": "https://…", "order_id": 32579 }` — open in a custom tab, then poll status.
Errors: `already_paid` (409), `gateway_unavailable` (502/503).

### `GET /orders/{id}/status?key={order_key}`
`{ "order_id": 32579, "status": "processing", "is_paid": true }` — public, key-gated, no-store.
Poll this after the payment tab closes.

---

## 10. Orders (bearer)

### `GET /orders?page=`
```json
{ "orders": [ {
    "id": 32579, "number": "32579", "order_key": "wc_order_…",
    "date": "2026-08-25T10:14:00+03:00",
    "status": "zb-ready", "status_label": "جاهز للتسليم",
    "total": 145.8, "currency": "SAR", "is_paid": true,
    "payment_method": "cod", "delivery_type": "express",
    "items_preview": [ { "name", "image", "qty" } ], "items_count": 3, "can_reorder": true
  } ], "page": 1, "pages": 4, "total": 37 }
```

### `GET /orders/{id}`
List DTO **plus** `items[]`, `address`, `totals`, `notes` and:
```json
{
  "timeline": [
    { "key": "placed",    "label": "تم استلام الطلب",  "at": "2026-08-25T10:14:00+03:00", "done": true },
    { "key": "paid",      "label": "تم الدفع",          "at": null, "done": false },
    { "key": "preparing", "label": "قيد التجهيز",       "at": "…", "done": true },
    { "key": "ready",     "label": "جاهز للتسليم",      "at": "…", "done": true },
    { "key": "completed", "label": "تم التسليم",        "at": null, "done": false }
  ],
  "tracking": { "number": "SG123…", "carrier": "…", "url": null, "status": "dispatched" }
}
```
`tracking` is `null` until the ShipGo connector stamps it.

### `POST /orders/{id}/reorder`
Adds every still-purchasable line to the cart and returns the **cart DTO** with `added` and
`missing[]`. `409 reorder_unavailable` when nothing could be added.

---

## 11. Account (bearer)

| Method | Path | Body / Notes |
|---|---|---|
| `GET` | `/wishlist` | `{ "products": [ Card ], "count": 7 }` |
| `POST` | `/wishlist/toggle` | `{ product_id, force? }` → `{ "wishlisted": true, "count": 8 }` |
| `GET` | `/addresses` | `{ "addresses": [ … ] }` |
| `POST` | `/addresses` | `{ label, name, phone, city, district, address_line, lat, lng, is_default? }` |
| `PATCH` | `/addresses/{uuid}` | partial update |
| `DELETE` | `/addresses/{uuid}` | |
| `POST` | `/addresses/{uuid}/default` | |
| `GET` | `/account/buy-again` | `{ "products": [ Card ] }` |

The wishlist is the **same list as the website** (user meta `_zbx_wishlist`). Guests get `401` —
open the OTP sheet, exactly like the web heart does. The default address is mirrored into the
WooCommerce billing/shipping user fields.

---

## 12. Events

### `POST /events`
Single `{ "event_type": "view", "item_code": "P12600221" }` or batched
`{ "events": [ … ] }` (max 50). Responds `202` with `{ "accepted": 3, "received": 3 }`.

Allowed `event_type`: `view`, `search`, `add_to_cart`, `begin_checkout`, `purchase`,
`impression`, `click`. Optional: `item_code`, `query`, `zone`, `ab_variant`, `payload` (object).

`anon_id` is taken from `X-ZB-Guest`; an authenticated request also carries `customer_ref: "wp_{id}"`.
Fire-and-forget: never block a screen on this.

---

## 13. Notes for the client

1. **Always** send the location headers — without them stock, badges and promises fall back to a
   generic national view.
2. Persist the guest uuid across launches; it *is* the guest cart.
3. On `401` from any account route, clear the token and reopen the OTP sheet.
4. Treat `notices` as one-shot toasts.
5. Handle `cart_changed` at checkout by re-rendering the review screen from `data.cart`.
6. Respect `ETag` — it makes catalogue browsing nearly free on repeat visits.

---

## 14. Loyalty (عائلة زوبوكسي)

The program is **«عائلة زوبوكسي» / "Zooboxi Family"**, its currency is **«بصمات» / "Paws"**
(internal key `paws`). Every route below is **bearer-only** and answers
`Cache-Control: private, no-store` — a balance, a pet's birth date and a sealed prize are
personal.

When the module is switched off (`zooboxi_loyalty_enabled` ≠ `yes`) these routes are not
registered at all; `/meta` then reports `features.loyalty: false` and `loyalty: null`, and
the app hides the whole surface. If the app calls a loyalty route on a store where the
module was disabled after boot it gets `503 loyalty_disabled`.

### Never assume a fee

`fees.express` is **0 today only as a trial** and will become a paid tier again. The app
must render whatever `/meta` and the cart DTO say — there are two reward kinds precisely
because a waived express fee is worth something:

| kind | what it does |
|---|---|
| `gift_product` | adds a real cart line priced at zero |
| `express_free` | zeroes the **express fee only**, on the next order |
| `free_delivery` | zeroes the fee of **any** delivery tier, with no minimum |
| `paws` | pure paws (catalogue placeholder; not used by Phase 1 grants) |

### `GET /meta` — additions

```json
"features": { "…": true, "loyalty": true, "pets": true },
"loyalty": {
  "program_name_ar": "عائلة زوبوكسي", "program_name_en": "Zooboxi Family",
  "currency_ar": "بصمات", "currency_en": "Paws",
  "points_per_riyal": 1, "paw_value_sar": 0.03,
  "max_pets": 3, "scratch_enabled": true, "missions_enabled": true
}
```

### `GET /loyalty/summary`

The family hub in one call.

```json
{ "member": { "joined_at": "2026-09-05T10:00:00Z", "holdout": false, "referral_code": "ZB7K2QX" },
  "paws": { "balance": 1240, "pending": 120, "expires_at": "2027-09-01T00:00:00Z" },
  "tier": { "key": "star", "name": "مميّز", "name_en": "Star", "icon": "⭐",
            "c1": "#e8a765", "c2": "#d48644",
            "orders_12m": 5, "min": 4,
            "next": { "key": "gold", "name": "ذهبي", "name_en": "Gold", "icon": "🏅",
                      "min": 8, "orders_needed": 3 },
            "progress": 25,
            "perks": [ { "key": "free_min_150", "text": "الشحن المجاني من 150 ﷼ بدل 200", "active": true,  "from_tier": "star" },
                       { "key": "express_free_always",  "text": "توصيل سريع مجاني دائماً",   "active": false, "from_tier": "gold" },
                       { "key": "free_delivery_always", "text": "توصيل مجاني بلا حد أدنى",  "active": false, "from_tier": "amb"  },
                       { "key": "priority_support", … }, { "key": "samples", … }, { "key": "whatsapp", … } ] },
  "missions": { "period": "2026-09", "active": 3, "completed": 1, "items": [ Mission ] },
  "rewards":  { "active_count": 2, "sealed_scratch": [ { "id": 88, "order_id": 32579, "order_number": "32579" } ] },
  "pets":     [ Pet ],
  "counters": { "orders_total": 17, "orders_app": 3 } }
```

- `paws.pending` — paws on revealed cards whose order has not been delivered yet. They are
  **not** in `balance`; show them as "on the way".
- `paws.expires_at` — when the current balance lapses if the customer never earns again
  (`expiry_months`, default 12, from the last earn).
- `tier.progress` — percent of the way to `tier.next`; `next` is `null` at the top.
- `perks[].active` is per-tier truth; `from_tier` is where the perk starts.
- Missions here carry **no** `suggested_products` (the summary stays light) — call
  `/loyalty/missions` for those.
- **Holdout members** (the 10% control group) get `member.holdout: true`,
  `missions.items: []`, `rewards.sealed_scratch: []` and `paws.pending: 0`. They still earn
  paws and hold a tier — hide the game, never the currency.

### `GET /loyalty/ledger?page=1`

```json
{ "items": [ { "id": 991, "delta": 199, "balance_after": 1240,
               "reason": "order_earn", "reason_label": "بصمات طلب",
               "ref_type": "order", "ref_id": 32579, "note": "",
               "created_at": "2026-09-05T10:00:00Z" } ],
  "page": 1, "has_more": true }
```

25 per page, newest first. `reason` ∈ `order_earn`, `profile_complete`, `pet_added`,
`mission`, `scratch`, `redeem`, `reverse`, `expire`, `adjust`, `welcome`. The book is
append-only: a cancelled order shows as a **second** `reverse` row, never as an edit.

### `GET /loyalty/rewards`

```json
{ "catalog": [ Reward ], "grants": [ Grant ], "paws_balance": 1240 }
```

**Reward**
```json
{ "id": 3, "key": "small_gift", "kind": "gift_product",
  "title": "هدية صغيرة", "title_en": "Small gift", "description": "…",
  "product": Card | null, "paws_cost": 600, "value_sar": 25,
  "validity_days": 21, "min_tier": "",
  "redeemable": false, "reason_ar": "بصماتك لا تكفي بعد", "reason_en": "You do not have enough paws yet." }
```
`reason_ar`/`reason_en` say **why not** — show it on a disabled button rather than hiding
the reward. `redeemable` is false with reason code `not_redeemable` when `paws_cost` is 0
(a grant-only reward), `reward_unavailable` when a gift has no product attached or its
monthly cap is spent, `tier_required` when the customer is below `min_tier`, and
`insufficient_paws` when the balance is short.

**Grant**
```json
{ "id": 77, "reward": Reward, "source": "scratch", "state": "pending",
  "expires_at": null,
  "activates_on_order": { "id": 32579, "number": "32579" },
  "claimed": false }
```
`state` ∈ `pending` (waiting on a delivery), `active`, `claimed` (in the basket),
`redeemed`, `expired`, `cancelled`. `source` ∈ `scratch`, `mission`, `redeem`, `welcome`,
`admin`. `expires_at` is set the moment the grant becomes `active`.

### `POST /loyalty/rewards/{id}/redeem`

→ `{ "grant": Grant, "paws_balance": 640 }`

Errors: `insufficient_paws` 409 · `tier_required` **403** · `reward_unavailable` 409 ·
`not_redeemable` 409. Paws are deducted only after the grant row exists.

### `POST /loyalty/grants/{id}/claim` · `DELETE /loyalty/grants/{id}/claim`

→ `{ "cart": Cart, "grant": Grant }`

Claiming puts the grant in the **basket session**, not on the order:

- `gift_product` → a real cart line appears, price 0, quantity locked at 1. Removing that
  line releases the claim (the grant goes back to `active`).
- `free_delivery` → no line; `free_shipping.min` becomes 0 for this basket.
- `express_free` → no line; the express shipment's fee becomes 0. If this basket cannot go
  express the claim still succeeds and the grant carries
  `notice_ar`/`notice_en`/`notice` explaining that the waiver has nothing to waive here.

Errors: `grant_not_active` 409 · `already_claimed` 409 · `gift_unavailable` 409 (the gift
cannot reach the customer's location, or has no purchasable product) · `cart_unavailable`
503. Abandoning the basket never costs the customer the reward; placing the order turns
every claim into `redeemed` bound to that order, and cancelling the order returns them.

### `GET /loyalty/missions`

```json
{ "period": "2026-09", "items": [ Mission ] }
```

**Mission**
```json
{ "id": 12, "key": "try_new_brand", "kind": "trial",
  "title": "جرّب ماركة جديدة", "body": "اطلب صنفاً من ماركة لم يجرّبها لولو من قبل.",
  "target": 1, "progress": 0, "state": "active",
  "reward": { "kind": "paws", "paws": 150 },
  "suggested_products": [ Card ],
  "completed_at": null }
```
`reward` is either `{ "kind": "paws", "paws": 150 }` or
`{ "kind": "reward", "reward": Reward }`. `kind` ∈ `profile`, `welcome`, `frequency`,
`trial`, `category`. `state` ∈ `active`, `completed`, `rewarded`, `expired` — the payout is
immediate, so a finished mission is normally seen as `rewarded`. Up to four missions are
assigned per calendar month, lazily on the first read; last month's roll over to `expired`.
`suggested_products` (max 6) is populated for `trial` and `category` only, and is empty on
the copies embedded in `/loyalty/summary`.

### `GET /loyalty/scratch` · `POST /loyalty/scratch/{id}/reveal`

```json
{ "cards": [ Scratch ] }
```

**Scratch**
```json
{ "id": 88, "order": { "id": 32579, "number": "32579" },
  "state": "revealed",
  "prize": { "kind": "paws", "paws": 50 },
  "settled": false,
  "revealed_at": "2026-09-05T10:02:00Z", "created_at": "2026-09-05T10:00:00Z",
  "activation_hint_ar": "تُفعَّل عند تسليم الطلب",
  "activation_hint_en": "Activates when your order is delivered" }
```
`prize` is `null` while `state` is `sealed` — the outcome is drawn server-side at creation
but is not sent until the customer rubs the card, so the animation cannot be spoiled by a
network log. A reward prize reads
`{ "kind": "reward", "reward": Reward, "grant_id": 77 }`.

`reveal` is idempotent: calling it twice returns the same card, never a second prize.
`settled` flips to `true` when the order is delivered — that is the moment paws hit the
ledger and a reward grant becomes `active`. Cancelling the order before delivery cancels
the prize. `GET` returns sealed cards plus anything created in the last 30 days.
Errors: `scratch_not_found` 404.

One card per app order (`_zooboxi_app_order`), never for a holdout member, never for a web
order.

### Pets

| Method | Path | Body / notes |
|---|---|---|
| `GET` | `/pets` | `{ "pets": [ Pet ], "max": 3 }` |
| `POST` | `/pets` | `{ name, species, breed?, sex?, weight_kg?, birth_date?, neutered?, avatar?, notes?, photo_id? }` → `{ "pet": Pet, "pets": [ … ], "paws_earned": 50 }` |
| `PATCH` | `/pets/{id}` | same body, partial → `{ "pet", "pets", "paws_earned": 0 \| 100 }` |
| `DELETE` | `/pets/{id}` | soft delete → `{ "pets": [ … ] }` |

**Pet**
```json
{ "id": 5, "name": "لولو", "species": "cat", "breed": "شيرازي", "sex": "f",
  "weight_kg": 4.25, "birth_date": "2024-03-01",
  "age_label": "سنتان و3 أشهر", "neutered": true, "avatar": "cat_cream",
  "photo_url": null, "is_complete": true, "birthday_in_days": 177 }
```
`species` ∈ `cat`, `dog`, `bird`, `fish`, `small`, `reptile`, `other`. `sex` ∈ `m`, `f`,
`""`. `age_label` is localised (`"2y 3m"` under `?lang=en`). `is_complete` means the pet
has both a weight and a birth date — that is what pays the one-off 100 paws, so
`paws_earned` is 50 on a create and 100 on the edit that first completes a profile.

Errors: `pets_limit` 409 (at `max`) · `pet_invalid` 422 with
`data.fields: { "name": "…", "weight_kg": "…" }` · `pet_not_found` 404.

### Changes to existing endpoints

**`GET /cart` and every cart mutation** — the DTO gains:
```json
"loyalty": { "paws_to_earn": 240, "holdout": false,
             "claims": [ Grant ],
             "free_delivery_reason": null | "tier" | "reward",
             "express_free_reason":  null | "tier" | "reward" }
```
and every line gains `"is_gift": bool, "grant_id": int|null, "locked_qty": bool`. A gift
line renders with no stepper, the price as «مجاناً», and delete = release the reward.
`paws_to_earn` excludes gift lines. `free_delivery_reason` / `express_free_reason` say why
the badge is showing: `"tier"` (a level perk) or `"reward"` (a claimed grant). The
`loyalty` key is absent entirely when the module is off.

**`POST /checkout`** — the response gains `"scratch_card": Scratch | null` (always sealed)
and `"paws_to_earn": 240`. Show the card on the success screen; if the customer leaves
without rubbing it, it is waiting in `/loyalty/scratch`.

**`GET /orders/{id}`** — gains:
```json
"loyalty": { "paws_earned": 240 | null, "scratch_card_id": 88 | null, "gift_lines": ["🎁 هدية · …"] }
```
`paws_earned` is `null` until the order is delivered. `null` for the whole block when the
module is off.

**`GET /home`** — `layout` gains `{ "type": "family" }` immediately after `hero` and
`{ "type": "missions" }` immediately after `personal`. **Neither slot carries data** — the
home payload stays cacheable, and the app hydrates both from `/loyalty/summary` exactly the
way it hydrates `personal` from `/home/feed`. Guests render the family slot as an
invitation, not an error.

**`POST /events`** — six new `event_type` values:
`loyalty_scratch` (`payload: {card_id, prize_kind}`, zone `checkout`),
`loyalty_mission` (`{mission_id, state}`), `loyalty_redeem` (`{reward_id}`),
`loyalty_claim` (`{grant_id}`), `pet_added` (`{species}`), `family_card` (`{variant}`).

### Error codes introduced

`loyalty_disabled` 503 · `pets_limit` 409 · `pet_invalid` 422 · `pet_not_found` 404 ·
`pet_failed` 500 · `insufficient_paws` 409 · `tier_required` 403 · `reward_unavailable` 409 ·
`not_redeemable` 409 · `grant_not_active` 409 · `already_claimed` 409 · `gift_unavailable` 409 ·
`scratch_not_found` 404.

## 15. Loyalty — Phase 2 «العادة» (habit)

Contract: `14-LOYALTY-PHASE2-SPEC.md` §8. Every route below is bearer-only and
`private, no-store`, exactly like §14. Feature flags land in `/meta`:

```json
"features": { "…": true, "supply": true, "subscriptions": true, "referral": true, "stamps": false },
"loyalty":  { "…": 1, "referral_paws": 300, "on_time_pct": 20, "on_time_before": 7, "on_time_after": 3,
              "sub_bonus_pct": 10, "sub_gift_every": 3, "max_subscriptions": 6 }
```
`stamps` is true only once the owner has switched a brand program on.

### `GET /loyalty/summary` — additions

```json
"supply":        { "items": [ Supply ×3 ], "due_count": 1, "total": 5, "window": { "before": 7, "after": 3 } },
"subscriptions": { "active": 2, "next": Subscription | null },
"moments":       { "birthday": { "pet": Pet, "days": 3, "grant": Grant | null, "grant_id": 71 | null, "paws": null, "eligible": true } | null },
"referral":      { "code": "ZBUCNBN", "url": "https://store.zooboxi.com/?ref=ZBUCNBN", "reward_paws": 300, "rewarded": 2 } | null,
"stamps":        [ StampCard ],
"nudges":        [ Nudge ],
"tier": { "…": 1, "at_risk": { "in_days": 12, "orders_dropping": 1, "would_drop_to": "star", "would_drop_to_name": "مميّز" } | null }
```

**Supply** (the food gauge line):
`{ "product": Card, "variation_id", "kind": "dry|wet|litter|treat|other", "pet": {"id","name","species"} | null,
"qty_last", "last_ordered_at", "cycle_days", "days_left", "runs_out_at", "status": "ok|soon|due|overdue",
"confidence": "low|medium|high", "on_time": bool, "pack_kg": 2.5 | null, "buys", "subscription_id": 12 | null }`.
`days_left` is the server's; the app never recomputes it. `on_time` = ordering now earns the bonus.

**Subscription**:
`{ "id", "product": Card, "variation_id", "variation_label", "qty", "interval_days", "next_at": "2026-09-19",
"days_until": 14, "state": "active|paused|cancelled", "deliveries", "next_gift_in": 2 | null, "pet": {…} | null,
"perks": { "free_delivery": true, "bonus_pct": 10, "gift_every": 3 } }`.

**Nudge** (dated, soonest first; future ones become local notifications on the phone):
`{ "kind": "birthday|supply|subscription|winback|tier_risk", "title", "body", "at": ISO, "route": "/family/supply",
"product_id"?, "subscription_id"?, "pet_id"? }`.

**StampCard**:
`{ "program": { "id", "title", "brand": {"name","slug"} | null, "units_required", "min_pack_kg", "reward": Reward | null },
"units", "cycles_done", "remaining" }`.

### The gauge
- `GET /loyalty/supply` → `{ "items": [Supply], "window": {"before","after"}, "on_time_pct": 20, "enabled": true }`
  (`?fresh=1` rebuilds instead of reading the 15-minute cache)
- `POST /loyalty/supply/{product_id}/out` body `{ "variation_id"? }` → `{ "item": Supply }` — «خلص»
- `POST /loyalty/supply/{product_id}/snooze` body `{ "days": 7, "variation_id"? }` → `{ "item": Supply }` — «عندي كفاية»
- Errors: `supply_not_found` 404.

### Subscriptions
- `GET /loyalty/subscriptions` → `{ "items": [Subscription], "max": 6, "perks": {…}, "enabled": true }`
- `POST /loyalty/subscriptions` body `{ "product_id", "variation_id"?, "qty"?, "interval_days"?, "next_at"?, "pet_id"? }`
  → the same payload plus `"subscription": Subscription`. Defaults come from the gauge when it knows the product.
- `PATCH /loyalty/subscriptions/{id}` body `{ "qty"?, "interval_days"?, "next_at"?, "state"?: "active|paused", "pet_id"? }`
- `POST /loyalty/subscriptions/{id}/skip` — `next_at += interval`
- `POST /loyalty/subscriptions/{id}/order-now` → `{ "cart": Cart, "subscription": Subscription }` — the line is in the
  basket and the session is flagged: delivery is free for that basket (`loyalty.free_delivery_reason: "subscription"`).
- `DELETE /loyalty/subscriptions/{id}` → `{ "items": [...] }`
- Errors: `subscription_limit` 409 · `subscription_exists` 409 · `subscription_invalid` 422 · `subscription_not_found` 404 · `add_failed` 409.

### Referral
- `GET /loyalty/referral` → `{ "code", "url", "share_text", "reward_paws", "welcome", "cap", "this_month",
  "stats": {"invited","qualified","rewarded"}, "items": [{ "name": "م…", "state", "created_at" }],
  "applied": { "code", "state" } | null, "enabled" }`
- `POST /loyalty/referral/apply` body `{ "code" }` → `{ "applied": {…}, "paws_earned", "paws_balance", "grant": Grant | null }`
- Errors: `referral_invalid` 404 · `referral_self` 409 · `referral_used` 409 · `referral_not_new` 409 · `referral_cap` 409.
- The website captures `?ref=CODE` into a 30-day cookie and applies it on registration.

### Brand stamps
- `GET /loyalty/stamps` → `{ "items": [StampCard] }` (active programs only — empty hides the section).

### Changes to existing endpoints
- **Cart DTO** `loyalty.free_delivery_reason` now also takes `"subscription"`; `loyalty.subscription_ids: [12]` lists the
  subscriptions this basket delivers.
- **`POST /checkout`** gains `"subscription_order": true|false`.
- **`POST /events`** — three new `event_type` values: `supply_action` (`{product_id, action: out|snooze|order|subscribe}`),
  `subscription` (`{subscription_id, action}`), `referral_share`.
- **Ledger reasons** added: `on_time` (+20% on lines ordered inside their window), `sub_bonus` (+10% on a subscription
  delivery, and the every-Nth gift fallback), `referral` (the referrer's reward), `birthday` (the gift fallback).
- **Missions** — new kinds: `regular` (`on_time`), `growth` (`refer_friend`), `winback` (minted by the daily sweep only).
