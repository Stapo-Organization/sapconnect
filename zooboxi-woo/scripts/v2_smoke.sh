#!/usr/bin/env bash
#
# v2_smoke.sh — curl smoke suite for the zooboxi/v2 mobile API.
#
#   BASE=https://store.zooboxi.com/wp-json/zooboxi/v2 ./scripts/v2_smoke.sh
#
# Read-only + one guest cart line. It never sends an OTP, never places an order and
# never touches an authenticated route, so it is safe against production.
#
# Requires: curl, jq.

set -uo pipefail

BASE="${BASE:-https://store.zooboxi.com/wp-json/zooboxi/v2}"
GUEST="${GUEST:-smoke-$(date +%s)-$$}"
LAT="${LAT:-24.7136}"
LNG="${LNG:-46.6753}"
CITY="${CITY:-الرياض}"
LANG_PARAM="${LANG_PARAM:-ar}"

PASS=0
FAIL=0
BODY_FILE="$(mktemp)"
trap 'rm -f "$BODY_FILE"' EXIT

c_ok()   { printf '\033[32m  ✓ %s\033[0m\n' "$1"; PASS=$((PASS + 1)); }
c_bad()  { printf '\033[31m  ✗ %s\033[0m\n' "$1"; FAIL=$((FAIL + 1)); }
c_head() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# call <METHOD> <PATH> [json-body]
# Writes the response body to $BODY_FILE and echoes the HTTP status code.
call() {
  local method="$1" path="$2" body="${3:-}"
  local args=(-sS -o "$BODY_FILE" -w '%{http_code}' -X "$method"
    -H 'Accept: application/json'
    -H "X-ZB-Guest: ${GUEST}"
    -H "X-ZB-Lat: ${LAT}"
    -H "X-ZB-Lng: ${LNG}"
    -H "X-ZB-City: ${CITY}"
    -H 'X-ZB-App: smoke/1.0')
  if [ -n "$body" ]; then
    args+=(-H 'Content-Type: application/json' -d "$body")
  fi
  curl "${args[@]}" "${BASE}${path}" 2>/dev/null || echo "000"
}

expect_status() {
  local got="$1" want="$2" label="$3"
  if [ "$got" = "$want" ]; then c_ok "$label (HTTP $got)"; return 0; fi
  c_bad "$label — expected HTTP $want, got $got"
  head -c 400 "$BODY_FILE"; echo
  return 1
}

expect_jq() {
  local filter="$1" label="$2"
  if jq -e "$filter" "$BODY_FILE" >/dev/null 2>&1; then c_ok "$label"; return 0; fi
  c_bad "$label — jq filter failed: $filter"
  head -c 400 "$BODY_FILE"; echo
  return 1
}

command -v jq >/dev/null 2>&1 || { echo "jq is required"; exit 2; }

echo "BASE  = $BASE"
echo "GUEST = $GUEST"
echo "GEO   = $LAT,$LNG ($CITY)"

# ─────────────────────────────────────────────────────────── meta
c_head "GET /meta"
code=$(call GET "/meta")
expect_status "$code" 200 "meta responds"
expect_jq '.ok == true' "envelope ok"
expect_jq '.data.currency == "SAR"' "currency is SAR"
expect_jq '.data.min_app_version.ios and .data.min_app_version.android' "min_app_version present"
expect_jq '.data.free_shipping_min | numbers' "free_shipping_min is numeric"
expect_jq '.data.features | has("smart_shipments") and has("wishlist")' "feature flags present"

# ─────────────────────────────────────────────────────── cities
c_head "GET /location/cities"
code=$(call GET "/location/cities")
expect_status "$code" 200 "cities respond"
expect_jq '.data.cities | type == "array" and length > 0' "cities is a non-empty array"
expect_jq '.data.cities[0] | has("city") and has("has_central")' "city rows shaped"

# ────────────────────────────────────────────────── resolve GPS
c_head "POST /location/resolve (Riyadh)"
code=$(call POST "/location/resolve" "{\"lat\":${LAT},\"lng\":${LNG}}")
expect_status "$code" 200 "resolve responds"
expect_jq '.data.city | strings' "city resolved"
expect_jq '.data | has("options") and has("best")' "options + best present"
expect_jq '.data.options | has("express") and has("standard") and has("shipping")' "all tiers keyed"

# ──────────────────────────────────────────────────────── home
c_head "GET /home"
code=$(call GET "/home?lang=${LANG_PARAM}")
expect_status "$code" 200 "home responds"
expect_jq '.data | has("hero") and has("campaigns") and has("animal_nav") and has("rails") and has("brands")' "home sections present"
expect_jq '.data.rails | type == "array"' "rails is an array"
expect_jq '(.data.rails | length) == 0 or (.data.rails[0].products | type == "array")' "rails carry product cards"

# ────────────────────────────────────────────────── categories
c_head "GET /catalog/categories"
code=$(call GET "/catalog/categories?lang=${LANG_PARAM}")
expect_status "$code" 200 "categories respond"
expect_jq '.data.categories | type == "array" and length > 0' "categories non-empty"
expect_jq '.data.categories[0] | has("id") and has("slug") and has("name") and has("count") and has("children")' "category shape"
CAT_SLUG=$(jq -r '.data.categories[0].slug // empty' "$BODY_FILE")

# ───────────────────────────────────────── listing + facets
c_head "GET /catalog/products (category=${CAT_SLUG:-<none>})"
if [ -n "$CAT_SLUG" ]; then
  code=$(call GET "/catalog/products?category=${CAT_SLUG}&per_page=6&lang=${LANG_PARAM}")
else
  code=$(call GET "/catalog/products?per_page=6&lang=${LANG_PARAM}")
fi
expect_status "$code" 200 "listing responds"
expect_jq '.data.products | type == "array"' "products array"
expect_jq '.data | has("total") and has("pages") and has("page") and has("per_page")' "pagination present"
expect_jq '.data.facets | has("groups") and has("price")' "facets present"
expect_jq '.data.facets.price | has("min") and has("max")' "price bounds present"
expect_jq '.data.sort_options | type == "array" and length > 0' "sort options present"
expect_jq '(.data.products | length) == 0 or (.data.products[0] | has("id") and has("name") and has("price") and has("stock_qty") and has("delivery_chip"))' "card DTO shape"
expect_jq '(.data.products | length) == 0 or ([.data.products[] | keys[]] | index("cost_price") | not)' "no cost/wholesale fields leaked"
PID=$(jq -r '.data.products[0].id // empty' "$BODY_FILE")

# ──────────────────────────────────────── listing ETag → 304
c_head "GET /catalog/products (If-None-Match)"
ETAG=$(curl -sSI -X GET \
  -H "X-ZB-Guest: ${GUEST}" -H "X-ZB-Lat: ${LAT}" -H "X-ZB-Lng: ${LNG}" -H "X-ZB-City: ${CITY}" \
  "${BASE}/catalog/products?per_page=6&lang=${LANG_PARAM}" 2>/dev/null | tr -d '\r' | awk 'tolower($1)=="etag:"{print $2}')
if [ -n "$ETAG" ]; then
  code=$(curl -sS -o /dev/null -w '%{http_code}' -X GET \
    -H "If-None-Match: ${ETAG}" \
    -H "X-ZB-Guest: ${GUEST}" -H "X-ZB-Lat: ${LAT}" -H "X-ZB-Lng: ${LNG}" -H "X-ZB-City: ${CITY}" \
    "${BASE}/catalog/products?per_page=6&lang=${LANG_PARAM}" 2>/dev/null)
  expect_status "$code" 304 "conditional GET returns 304"
else
  c_bad "no ETag header on the listing response"
fi

# ───────────────────────────────────────────────────────── PDP
c_head "GET /catalog/products/{id}"
if [ -n "$PID" ]; then
  code=$(call GET "/catalog/products/${PID}?lang=${LANG_PARAM}")
  expect_status "$code" 200 "PDP responds"
  expect_jq '.data | has("gallery") and has("delivery") and has("per_warehouse") and has("badges")' "PDP sections present"
  expect_jq '.data.delivery | has("headline") and has("tiers") and has("reachable_total")' "delivery plan shape"
  expect_jq '.data | has("fbt") and has("substitutes")' "recommendation slots present"
else
  c_bad "no product id from the listing — PDP skipped"
fi

# ───────────────────────────────────────────────────── suggest
c_head "GET /catalog/search/suggest"
code=$(call GET "/catalog/search/suggest?q=%D8%B7%D8%B9%D8%A7%D9%85")
expect_status "$code" 200 "suggest responds"
expect_jq '.data.suggestions | type == "array"' "suggestions array"
expect_jq '(.data.suggestions | length) <= 8' "suggest capped at 8"

# ───────────────────────────────────────────── guest cart flow
c_head "Guest cart (add → get)"
if [ -n "$PID" ]; then
  code=$(call POST "/cart/items" "{\"product_id\":${PID},\"quantity\":1}")
  if [ "$code" = "200" ]; then
    c_ok "cart add (HTTP 200)"
    expect_jq '.data | has("items") and has("totals") and has("shipments") and has("free_shipping")' "cart DTO shape"
    expect_jq '.data.count >= 1' "cart count incremented"
  elif [ "$code" = "409" ]; then
    # A variable product or an out-of-area item legitimately refuses.
    c_ok "cart add refused with a clean envelope (HTTP 409)"
    expect_jq '.error.code | strings' "error code present"
  else
    c_bad "cart add — unexpected HTTP $code"
    head -c 400 "$BODY_FILE"; echo
  fi

  code=$(call GET "/cart")
  expect_status "$code" 200 "cart get"
  expect_jq '.data | has("items") and has("notices")' "cart get shape"
  expect_jq '.data.totals | has("subtotal") and has("total")' "totals present"

  # Mutations MUST be exercised: WC defers loading cart contents to wp_loaded
  # (long gone in REST), so update/remove can 404 with "item_not_found" while
  # add and get look perfectly healthy. This block is what catches that.
  ITEM_KEY=$(jq -r '.data.items[0].key // empty' "$BODY_FILE")
  if [ -n "$ITEM_KEY" ]; then
    c_head "Guest cart (update → remove)"
    code=$(call PATCH "/cart/items/${ITEM_KEY}" '{"quantity":2}')
    expect_status "$code" 200 "cart qty update"
    expect_jq ".data.items[] | select(.key == \"$ITEM_KEY\") | .qty == 2" "quantity actually changed"

    code=$(call DELETE "/cart/items/${ITEM_KEY}")
    expect_status "$code" 200 "cart item remove"
    expect_jq "[.data.items[] | select(.key == \"$ITEM_KEY\")] | length == 0" "line actually gone"
  else
    c_head "Guest cart (update → remove)"
    c_ok "no purchasable line to mutate (add was refused) — skipped"
  fi
else
  c_bad "no product id — cart flow skipped"
fi

# ─────────────────────────────────────── auth guards (no token)
c_head "Bearer-only routes reject a guest"
code=$(call GET "/orders")
expect_status "$code" 401 "/orders is 401 for a guest"
expect_jq '.error.code == "unauthorized"' "401 envelope"

code=$(call GET "/wishlist")
expect_status "$code" 401 "/wishlist is 401 for a guest"

# ─────────────────────────────────────────────────────── summary
c_head "Summary"
printf '  passed: %d\n  failed: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
