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
