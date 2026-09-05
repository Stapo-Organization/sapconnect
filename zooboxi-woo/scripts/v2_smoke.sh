#!/usr/bin/env bash
#
# v2_smoke.sh — curl smoke suite for the zooboxi/v2 mobile API.
#
#   BASE=https://store.zooboxi.com/wp-json/zooboxi/v2 ./scripts/v2_smoke.sh
#
# Read-only + one guest cart line. It never sends an OTP and never places an order, so
# it is safe against production. Authenticated checks run ONLY when TOKEN_USER3 carries
# a bearer token (they are read-only too), and are skipped otherwise.
#
#   TOKEN_USER3=zbat_… BASE=… ./scripts/v2_smoke.sh
#
# Requires: curl, jq.

set -uo pipefail

BASE="${BASE:-https://store.zooboxi.com/wp-json/zooboxi/v2}"
GUEST="${GUEST:-smoke-$(date +%s)-$$}"
LAT="${LAT:-24.7136}"
LNG="${LNG:-46.6753}"
CITY="${CITY:-الرياض}"
LANG_PARAM="${LANG_PARAM:-ar}"
# Bearer token for a real customer (user 3 on prod) — enables the authed feed check.
TOKEN_USER3="${TOKEN_USER3:-${TOKEN:-}}"

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

# call_auth <METHOD> <PATH> [json-body] — same as call() plus the bearer token.
call_auth() {
  local method="$1" path="$2" body="${3:-}"
  local args=(-sS -o "$BODY_FILE" -w '%{http_code}' -X "$method"
    -H 'Accept: application/json'
    -H "Authorization: Bearer ${TOKEN_USER3}"
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

# headers <PATH> — the response headers of a guest GET, lowercased.
headers() {
  curl -sS -o /dev/null -D - -X GET \
    -H 'Accept: application/json' \
    -H "X-ZB-Guest: ${GUEST}" -H "X-ZB-Lat: ${LAT}" -H "X-ZB-Lng: ${LNG}" -H "X-ZB-City: ${CITY}" \
    "${BASE}${1}" 2>/dev/null | tr -d '\r' | tr 'A-Z' 'a-z'
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
expect_jq '.data.features | has("loyalty") and has("pets")' "loyalty feature flags present"
# The program's constants must be present whenever it is on — the app never hardcodes them.
expect_jq '.data.features.loyalty == false or (.data.loyalty | has("program_name_ar") and has("points_per_riyal") and has("paw_value_sar"))' "loyalty meta block shaped when enabled"

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
expect_jq '.data | has("hero") and has("campaigns") and has("animal_nav") and has("rails") and has("brands") and has("layout")' "home sections present"
expect_jq '.data.rails | type == "array"' "rails is an array"
expect_jq '(.data.rails | length) == 0 or (.data.rails[0].products | type == "array")' "rails carry product cards"

# The app renders sections in the order the server dictates.
expect_jq '.data.layout | type == "array" and length >= 10' "layout is an array of 10+ sections"
expect_jq '[.data.layout[] | has("type")] | all' "every layout entry names a type"
expect_jq '[.data.layout[].type] | index("family") != null and index("missions") != null' "layout carries the family + missions slots"
expect_jq '[.data.layout[].type] | index("family") == 1' "family sits directly after the hero"
expect_jq '[.data.layout[].type] | index("missions") == (index("personal") + 1)' "missions sits directly after personal"

# Never show the same product twice across the home rails.
expect_jq '[.data.rails[].products[].id] | length == (unique | length)' "no duplicate products across rails"

# Hero is never empty and every slide declares how it should be drawn.
expect_jq '.data.hero | type == "array" and length > 0' "hero is never empty"
expect_jq '[.data.hero[] | .kind == "manual" or .kind == "auto"] | all' "hero slides declare a kind"
expect_jq '[.data.hero[] | select(.kind == "auto") | has("theme") and has("title") and has("product_images")] | all' "auto slides carry theme + copy + artwork"

# Campaigns are owner-gated: an empty set is a legitimate production state.
CAMPAIGNS=$(jq -r '.data.campaigns | length' "$BODY_FILE" 2>/dev/null || echo 0)
if [ "${CAMPAIGNS:-0}" -gt 0 ]; then
  expect_jq '[.data.campaigns[] | has("creatives") and has("ends_at") and has("zones") and has("ab_variant")] | all' "campaign rows carry creatives + ends_at"
  expect_jq '[.data.campaigns[] | .creatives | type == "object"] | all' "creatives is an object per campaign"
  expect_jq '[.data.campaigns[] | .creatives | length > 0] | all' "every campaign has at least one creative"
else
  c_ok "no live campaigns right now — campaign shape checks skipped"
fi

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
PID2=$(jq -r '.data.products[1].id // empty' "$BODY_FILE")

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

# ────────────────────────────────────── rail-scoped listings
# The app's "عرض الكل" on a home rail must keep the rail's filter, with real paging.
c_head "GET /catalog/products?rail=…"
code=$(call GET "/catalog/products?rail=trending&per_page=6&lang=${LANG_PARAM}")
expect_status "$code" 200 "rail=trending responds"
expect_jq '.data.rail == "trending"' "rail echoed back"
expect_jq '.data.products | type == "array"' "rail listing returns an array"
expect_jq '.data | has("total") and has("pages") and has("page")' "rail listing paginates"
RAIL_N=$(jq -r '.data.products | length' "$BODY_FILE" 2>/dev/null || echo 0)
if [ "${RAIL_N:-0}" -gt 0 ]; then
  c_ok "rail=trending returned ${RAIL_N} products"
else
  c_ok "rail=trending is empty right now (no fast movers) — count check skipped"
fi

code=$(call GET "/catalog/products?rail=clearance&page=2&per_page=6&lang=${LANG_PARAM}")
expect_status "$code" 200 "rail=clearance page 2 responds"
expect_jq '.ok == true' "page 2 envelope ok"
expect_jq '.data.page == 2 and .data.rail == "clearance"' "page + rail echoed on page 2"

code=$(call GET "/catalog/products?rail=not-a-rail&per_page=6")
expect_status "$code" 200 "unknown rail still responds"
expect_jq '.data.rail == null' "unknown rail value is ignored"

# ─────────────────────────────────────────── home feed (guest)
c_head "GET /home/feed (guest)"
RECENT=""
[ -n "$PID" ] && RECENT="$PID"
[ -n "${PID2:-}" ] && RECENT="${RECENT:+${RECENT},}${PID2}"
code=$(call GET "/home/feed?recent_ids=${RECENT}&lang=${LANG_PARAM}")
expect_status "$code" 200 "home feed responds"
expect_jq '.ok == true' "envelope ok"
expect_jq '.data | has("personal") and has("foryou") and has("incity") and has("login_nudge")' "feed slots present"
expect_jq '.data.personal | has("kind") and has("title") and has("products")' "personal slot shaped"
expect_jq '.data.personal.kind | . == "buyagain" or . == "recent" or . == "none"' "personal.kind is a known kind"
expect_jq '.data.personal.kind != "buyagain"' "a guest never gets buy-again"
expect_jq '.data.login_nudge == true' "guest gets the login nudge"
expect_jq '.data.foryou == null or (.data.foryou | has("title") and (.products | type == "array"))' "foryou is null or a rail"
expect_jq '.data.incity == null or (.data.incity | has("title") and (.products | type == "array"))' "incity is null or a rail"
expect_jq '[.data.personal.products[], (.data.foryou.products // [])[], (.data.incity.products // [])[] | .id] | length == (unique | length)' "no product repeats across feed slots"
expect_jq '(.data.personal.products | length) == 0 or ([.data.personal.products[] | keys[]] | index("cost_price") | not)' "no cost/wholesale fields in the feed"

CC=$(headers "/home/feed?recent_ids=${RECENT}" | awk '/^cache-control:/{ $1=""; print }')
case "$CC" in
  *no-store*) c_ok "feed is private, no-store" ;;
  *)          c_bad "feed Cache-Control is missing no-store (got:${CC:-<none>})" ;;
esac

# ─────────────────────────────────── home feed (authenticated)
c_head "GET /home/feed (bearer)"
if [ -n "$TOKEN_USER3" ]; then
  code=$(call_auth GET "/home/feed?recent_ids=${RECENT}&lang=${LANG_PARAM}")
  expect_status "$code" 200 "authenticated feed responds"
  expect_jq '.ok == true' "authenticated envelope ok"
  expect_jq '.data.login_nudge == false' "no login nudge for a signed-in customer"
  expect_jq '.data.personal.kind | . == "buyagain" or . == "recent" or . == "none"' "personal.kind is a known kind"
  expect_jq '.data.personal.kind != "buyagain" or ([.data.personal.products[] | has("last_ordered_days") and has("due")] | all)' "buy-again cards carry the reorder signal"
else
  c_ok "TOKEN_USER3 not set — authenticated feed checks skipped"
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
    # Loyalty rides along only when the module is on; a gift line is flagged per item.
    expect_jq '(.data | has("loyalty") | not) or (.data.loyalty | has("paws_to_earn") and has("claims") and has("free_delivery_reason") and has("express_free_reason"))' "cart loyalty block shaped"
    expect_jq '(.data.items | length) == 0 or ([.data.items[] | has("is_gift") and has("locked_qty")] | all)' "cart lines declare gift status"
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

# ────────────────────────────────────── loyalty (عائلة زوبوكسي)
c_head "Loyalty routes reject a guest"
code=$(call GET "/loyalty/summary")
if [ "$code" = "503" ]; then
  c_ok "loyalty module is switched off on this store (503) — guard checks skipped"
  expect_jq '.error.code == "loyalty_disabled"' "disabled envelope"
  LOYALTY_ON=0
else
  LOYALTY_ON=1
  expect_status "$code" 401 "/loyalty/summary is 401 for a guest"
  expect_jq '.error.code == "unauthorized"' "401 envelope"

  code=$(call GET "/pets")
  expect_status "$code" 401 "/pets is 401 for a guest"

  code=$(call GET "/loyalty/rewards")
  expect_status "$code" 401 "/loyalty/rewards is 401 for a guest"

  code=$(call GET "/loyalty/ledger")
  expect_status "$code" 401 "/loyalty/ledger is 401 for a guest"

  code=$(call GET "/loyalty/scratch")
  expect_status "$code" 401 "/loyalty/scratch is 401 for a guest"

  # A balance and a pet's birth date must never sit in a shared cache.
  CC=$(headers "/loyalty/summary" | awk '/^cache-control:/{ $1=""; print }')
  case "$CC" in
    *no-store*) c_ok "loyalty is private, no-store" ;;
    *)          c_bad "loyalty Cache-Control is missing no-store (got:${CC:-<none>})" ;;
  esac
fi

c_head "Loyalty (bearer)"
if [ -n "$TOKEN_USER3" ] && [ "${LOYALTY_ON:-0}" = "1" ]; then
  code=$(call_auth GET "/loyalty/summary")
  expect_status "$code" 200 "summary responds"
  expect_jq '.data | has("member") and has("paws") and has("tier") and has("missions") and has("rewards") and has("pets") and has("counters")' "summary sections present"
  expect_jq '.data.paws | has("balance") and has("pending")' "paws block shaped"
  expect_jq '.data.tier | has("key") and has("orders_12m") and has("progress") and has("perks")' "tier block shaped"
  expect_jq '[.data.tier.perks[] | has("key") and has("active") and has("from_tier")] | all' "every perk declares its tier"
  expect_jq '.data.missions | has("period") and has("items")' "missions block shaped"
  # The holdout group plays nothing — that is the whole point of the group.
  expect_jq '.data.member.holdout == false or ((.data.missions.items | length) == 0 and (.data.rewards.sealed_scratch | length) == 0)' "a holdout member gets no game"

  code=$(call_auth GET "/loyalty/rewards")
  expect_status "$code" 200 "rewards respond"
  expect_jq '.data | has("catalog") and has("grants")' "catalogue + grants present"
  expect_jq '(.data.catalog | length) == 0 or ([.data.catalog[] | has("kind") and has("paws_cost") and has("redeemable")] | all)' "reward DTO shape"

  code=$(call_auth GET "/loyalty/ledger?page=1")
  expect_status "$code" 200 "ledger responds"
  expect_jq '.data | has("items") and has("page") and has("has_more")' "ledger paginates"

  code=$(call_auth GET "/loyalty/missions")
  expect_status "$code" 200 "missions respond"
  expect_jq '.data | has("period") and has("items")' "missions listing shaped"

  code=$(call_auth GET "/loyalty/scratch")
  expect_status "$code" 200 "scratch cards respond"
  expect_jq '.data.cards | type == "array"' "cards is an array"

  code=$(call_auth GET "/pets")
  expect_status "$code" 200 "pets respond"
  expect_jq '.data | has("pets") and has("max")' "pets listing shaped"
  expect_jq '.data.max >= 1' "a pet limit is published"
  expect_jq '(.data.pets | length) == 0 or ([.data.pets[] | has("age_label") and has("is_complete") and has("birthday_in_days")] | all)' "pet DTO shape"

  # Read-only suite: a bad pet body must be refused, not stored.
  code=$(call_auth POST "/pets" '{"name":"","species":"dragon"}')
  expect_status "$code" 422 "an invalid pet is refused"
  expect_jq '.error.code == "pet_invalid"' "pet_invalid envelope"
  expect_jq '.data.fields | type == "object"' "field errors returned"
elif [ "${LOYALTY_ON:-0}" != "1" ]; then
  c_ok "loyalty module off — authenticated loyalty checks skipped"
else
  c_ok "TOKEN_USER3 not set — authenticated loyalty checks skipped"
fi

# ─────────────────────────────────────────────────────── summary
c_head "Summary"
printf '  passed: %d\n  failed: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
