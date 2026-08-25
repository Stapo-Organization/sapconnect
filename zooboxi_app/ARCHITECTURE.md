# Zooboxi customer app — architecture

Flutter storefront for the Zooboxi pet store (store.zooboxi.com). Arabic-first
(RTL), English second, iOS + Android.

---

## How to run

```bash
# Defaults point at production; both defines are optional.
flutter run \
  --dart-define=ZB_BASE_URL=https://store.zooboxi.com/wp-json/zooboxi/v2 \
  --dart-define=ZB_STORE_URL=https://store.zooboxi.com

# CI can stamp the version reported in the X-ZB-App header:
flutter run --dart-define=ZB_APP_VERSION=1.0.3
```

| Define | Default | Purpose |
| --- | --- | --- |
| `ZB_BASE_URL` | `https://store.zooboxi.com/wp-json/zooboxi/v2` | API root. Trailing slashes are stripped. |
| `ZB_STORE_URL` | `https://store.zooboxi.com` | Storefront origin, for share links. |
| `ZB_APP_VERSION` | `1.0.0` | Reported in `X-ZB-App`, shown in Account → About. |

Checks: `flutter analyze` (must be clean — the lint config below treats unused
code and un-awaited futures as errors) and `flutter build bundle` (compiles the
Dart and resolves every asset without needing a platform toolchain).

Localizations are generated from `lib/l10n/*.arb` on `flutter pub get` /
`flutter gen-l10n`, into `lib/l10n/app_localizations*.dart` (class `L`).

---

## The contract

The app talks to exactly one backend: the additive `zooboxi/v2` REST namespace
inside the `zooboxi-multi-warehouse` WordPress plugin. It never holds the
Laravel token, and never holds a payment credential.

The full endpoint list, DTO shapes and header pipeline live in the plan at
`~/.claude/plans/crispy-painting-spindle.md` (§ "Server API design"). Every
response uses the envelope `{ok, data, error:{code, message_ar, message_en}}`,
unwrapped once in `core/network/envelope.dart`.

**Headers on every request** (`core/network/api_client.dart`):

| Header | Source |
| --- | --- |
| `Authorization: Bearer zbat_…` | `SessionController.token` |
| `X-ZB-Guest` | per-install UUID in the keychain |
| `X-ZB-Lat` / `Lng` / `City` / `District` / `Delivery-Type` | `ZbLocation.headersMap()` |
| `X-ZB-App` | `ios/1.0.0` |
| `?lang=ar\|en` | `AppSettings.languageCode` |

The location headers are the linchpin. The store's 44 location-aware PHP
classes normally read a WooCommerce session and seven cookies; the server
re-seeds those from these headers, so **the app is the cookie jar**. Everything
downstream — stock counts, badges, delivery chips, cart caps — is scoped to
whatever location the app last sent.

---

## Layout

```
lib/
  main.dart                    ProviderScope + SharedPreferences warm-up

  app/
    app.dart                   MaterialApp.router, locale, theme, lifecycle flush
    router.dart                go_router: shell + root routes
    shell/main_shell.dart      4-tab NavigationBar with the cart badge
    settings/app_settings.dart locale + themeMode, persisted
    theme/
      zooboxi_tokens.dart      raw brand values (teal/coral + graphite dark)
      zb_colors.dart           ThemeExtension: tiers, badges, shimmer, gradient
      app_theme.dart           M3 light/dark, Tajawal(ar)/Manrope(en)

  core/
    config/env.dart            dart-define reader
    network/                   api_client · api_exception · envelope + coercers
    session/                   SessionController (unknown → guest → authed)
    location/                  LocationController + ZbLocation
    storage/                   LocalStore (prefs) · SecureStore (keychain)
    analytics/events_buffer.dart
    motion/motion.dart         durations, curves, page transitions
    utils/                     formatters · haptics · debouncer · error_text
    widgets/                   the shared kit (product card + metrics, chips,
                               steppers, skeletons, images)

  features/<feature>/
    data/                      models + repository, providers at the file bottom
    presentation/              screens + widgets/
```

Features: `onboarding` · `location` · `home` · `catalog` · `search` ·
`product` · `cart` · `checkout` · `orders` · `account` · `auth` · `wishlist` ·
`payment` · `meta`.

Conventions:
- Riverpod providers live at the **bottom** of the repository/controller file
  they belong to. There is no `providers.dart` per feature.
- No screen file exceeds ~400 lines; anything larger is split into
  `presentation/widgets/`.
- Models are hand-written `fromJson` — no codegen, no build_runner.
- Every user-visible string goes through `L.of(context)`. There are no Arabic
  or English literals in widget code.
- Padding is `EdgeInsetsDirectional` / `PositionedDirectional` throughout.
- **Nothing guesses a `childAspectRatio`.** `core/widgets/product_card_metrics.dart`
  is the product card's size contract: the card is built from fixed slots —
  brand, a name that is *always* two lines tall, price, one info line, one
  control — and every grid, rail and skeleton asks that same class for the
  `mainAxisExtent` it should hand a card. The guess is what used to clip the
  add button off the bottom of the tile. The OS text scale is honoured up to
  1.3× and clamped there in both the arithmetic and the card itself, so the
  number computed and the pixels painted can never disagree.

---

## State

| Controller | Type | Notes |
| --- | --- | --- |
| `sessionProvider` | `Notifier<SessionState>` | `unknown → guest(guestId) → authenticated`. Guest is a first-class state. |
| `locationProvider` | `Notifier<LocationState>` | Persisted; changing it clears the HTTP cache and bumps `catalogRevisionProvider`. |
| `cartControllerProvider` | `AsyncNotifier<CartData>` | Server-authoritative. Optimistic qty with a 400 ms debounce, rollback on failure, notices drained by the cart screen. |
| `addressesControllerProvider` | `AsyncNotifier<List<Address>>` | Server-authoritative. Every write returns the whole book, so "exactly one default" stays the server's rule. Empties on sign-out. |
| `wishlistControllerProvider` | `Notifier<Set<int>>` | One shared id set so a heart tapped on Home is filled in Search too. |
| `appSettingsProvider` | `Notifier<AppSettings>` | Language + theme. |
| `catalogRevisionProvider` | `Notifier<int>` | Bumped on language/location change; every catalog provider watches it. |

**Why the cart is server-authoritative.** Only the server knows how many units
actually reach a given customer. The app applies a tap immediately so the
number moves, then posts once and lets the server's answer replace the guess.
If it disagrees, the optimistic state rolls back *and its notice is surfaced* —
silently reverting a number is worse than an error.

**Why paging is imperative.** `PaginatedProductGrid` owns its pages in
`State`, not in a provider family: a listing's pages are append-only scroll
state, and modelling them as derived data makes page 4 vanish when page 1
refreshes. Changing `resetKey` (the `ListingQuery`) hard-resets paging.

---

## Caching

`ApiClient` keeps a conditional-GET cache for catalog reads only
(`/home`, `/catalog/*`, `/brands*`, `/clearance`, `/meta`,
`/location/cities`). It stores the `ETag` plus the body in memory and in
SharedPreferences, sends `If-None-Match`, and serves the cached body on a 304.

The cache key is **path + query + city + delivery type** — the same URL means
different things in two cities. Cart, checkout, orders and account are never
cached.

---

## Money and numerals

`core/utils/formatters.dart` is the only place that formats a price.

- Digits are **always Western** (1234, never ١٢٣٤). Only separators follow the
  language: `٬`/`٫` in Arabic, `,`/`.` in English. Mixing numeral families
  inside one screen is what makes an Arabic UI look cheap.
- The currency mark is the official Saudi Riyal glyph at **U+E900**, carried by
  the bundled one-glyph `SaudiRiyal.otf`. Every text style in `AppTheme` — and
  `ThemeData.fontFamilyFallback` as a backstop — lists `SaudiRiyal` in its
  fallback chain, so any `Text` containing that character renders ﷼ inline.
  Never hardcode `ر.س` or `SAR`.
- `PriceText` is the one price widget: it handles the glyph, the struck-through
  original on sale, and the "يبدأ من" prefix for variable products.

---

## Auth

There is no login screen, and `router.dart` has **no auth redirect**. Guests
browse, search, and fill a basket exactly like customers. `showAuthSheet()` is
the only entry point: it is raised at the moment auth becomes necessary
(hearting a product, opening orders), and the interrupted action resumes after
sign-in. Flow: phone (05x) → 4-digit OTP with a 60 s resend countdown → profile
completion on first sign-in only.

`SecureStore.clearOnFreshInstall()` handles the iOS keychain outliving an app
delete: a marker file in the app sandbox (which reinstalling *does* wipe)
distinguishes a reinstall from a launch, and drops any token that outlived its
install.

---

## Built vs. stubbed

**Fully built:** splash + location primer · home (hero carousel, animal nav,
rails, brand strip, pull-to-refresh, skeletons) · categories · listing
(infinite grid, facet sheet with price range, sort sheet, empty states) ·
search (debounced suggest, recent chips, barcode scanner) · product page
(gallery with pinch-zoom, variation chips, delivery promise card, per-warehouse
panel, FBT + substitutes rails, pinned add-to-cart bar) · cart (steppers,
swipe-delete, shipment cards, animated free-shipping bar, coupon, totals) ·
**checkout** (address → review → payment on one screen, map-pin address
editor, `cart_changed` review moment) · **payment** (native MyFatoorah card
form with in-app 3-D Secure, plus the hosted page in a custom tab for the
wallets) · **order success** · **orders** (list + detail with the
fulfilment timeline, tracking and reorder) · **address book** · **buy-again** ·
wishlist · auth sheet · account settings (language + theme switch both live).

**Stubbed but navigable:** support.

**Not started (later phases):** push notifications, brand boutique pages,
personal home slots.

Checkout is **auth-gated at the cart's CTA**, exactly like the web store: the
sheet is raised there rather than mid-flow, because discovering you need an
account three steps in — with an address half typed — is the worst place to
learn it.

`features/payment/data/payment_service.dart` is transport only. Two routes,
one authority:

- **Card** — `POST /payments/config` returns the SDK token, the amount and the
  `reference` the payment must carry. `MFCardPaymentView` draws the fields as a
  native platform view and runs 3-D Secure in-app, then hands back an invoice
  id, which `POST /payments/verify` checks against the order the server priced.
- **Hosted** — the gateway's page in a custom tab (not a WebView: Apple Pay and
  mada's challenge need the real browser context), watched via
  `GET /orders/{id}/status`.

An invoice id is a *claim*. Until the server says paid, nothing is paid — which
is why the card route ends in a verification loop rather than in a success
screen, and why `already_paid` is treated as success wherever it appears.

`NativePaymentFlow` owns the SDK bring-up (once per credential set — `MFSDK.init`
is process-wide) and the verification retry, and is disposed by the screen. The
hosted *waiting* — its timer, its 40-poll budget, its cancellation — belongs to
`PaymentScreen` for the same reason: a poll that outlives the widget that
started it is a leak with a network bill attached. Polling starts the instant
the tab launches (a wallet can settle while it is still on screen) and again
immediately on app resume.

---

## Deliberate omissions

- **No card data in Dart.** The card fields belong to MyFatoorah's own native
  view; the app never sees a PAN, and holds no merchant key — the per-payment
  token comes from the server and opens one session against one invoice. That
  is what keeps PCI scope off the mobile build while still looking native.
  Wallets stay on the hosted page, because Apple Pay needs the real browser.
- **No Firebase.** Push lands in phase 2.
- **HTML descriptions are stripped, not rendered.** `_Description` on the
  product page decodes entities and drops tags. A real renderer can drop in
  later; a wall of markup was the worse option today.
- **Bundle ids are the generated ones** (`com.zooboxi.zooboxi_app`). The plan
  names `com.zooboxi.store`; change both platforms *before* the first store
  upload, since an application id cannot be changed once published.

---

## Platform configuration

**iOS** — deployment target 13.0 (Podfile pinned). `CFBundleDisplayName` is
`Zooboxi`, overridden to `زوبوكسي` via `Runner/ar.lproj/InfoPlist.strings`
(wired into the Xcode project as a variant group, with `ar` added to
`knownRegions`). Portrait only on iPhone. Usage strings for camera (scanner)
and location, both in Arabic.

**Android** — `minSdk 26` (MyFatoorah's Android SDK declares 26, and a lower
value fails the manifest merge outright; it also clears Flutter's own floor of
24 and mobile_scanner's 23), label from
`@string/app_name` with `values-ar/strings.xml` supplying `زوبوكسي`.
Permissions: `INTERNET` (needed in the main manifest for release builds),
coarse + fine location. `CAMERA` comes from the mobile_scanner plugin's own
manifest. A `<queries>` entry for `https` `VIEW` intents keeps Custom Tabs
resolvable under API 30+ package visibility.

---

## Lint policy

`analysis_options.yaml` extends `flutter_lints` and promotes four things to
**errors**: `unused_import`, `unused_local_variable`, `unused_element` and
`unawaited_futures`. The last one matters most — a missing `await` on a cart or
checkout call is a bug that only surfaces on a slow network, which is exactly
when it hurts.

`avoid_redundant_argument_values` is deliberately *not* enabled: spelling out a
default (`fallback: 0`, `min: 1`) documents intent at the call site, and the
model layer does that on purpose.
