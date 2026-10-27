# AISLEY Customer — Stitch design context

Recorded 2026-10-28 (Asia/Manila). This is a mobile design-reference exercise.
It does not implement, approve or replace the Flutter UI or feature contracts.

## Authority

- [Project rules](../../AGENTS.md), [progress](../PROGRESS.md), [Buyer design](../design-buyer.md) and [Customer specification rules](../features/customer/rule.md) govern this work.
- Source inspected: Buyer `8c04148b5ff00841b75b1794137f25599abcc4bc`.
- Latest recorded platform adoption is `1858785e` (2026-10-26), alongside historical per-feature slices. The deployed backend revision remains unidentified.
- Android is primary; the same Flutter app supports local web. Stitch screenshots do not certify Flutter, API, accessibility, device or release acceptance.
- Laravel owns identity, consent, visibility, stock, prices, shipping, vouchers, checkout and conversation permissions.

## Product and tasks

1. Verified active Customers discover Products and Shops; shopping is closed until identity and required consent resolve.
2. Home is the only main tab with shared-header Search. Dedicated Search and Shop search remain available.
3. Main navigation has Home, Shops, Cart and Account. Messages, Notifications and Terms/Privacy are header utilities.
4. Products show gallery, title, Shop and authoritative price/availability; missing ratings or discounts stay absent.
5. Quantity/SKU selection uses one current server-listed combination, not a generated Cartesian product.
6. Add to Cart increments owned server state; uncertain adds require checking Cart before another action.
7. Buy Now leaves Cart unchanged. Selected Cart checkout passes selected eligible lines only.
8. Checkout selects an owned address and one Seller-enabled shipping provider per Shop; COD is the only payment method.
9. Review order explicitly requests a quote. Changed intent or expiry requires refresh and review before placement confirmation.
10. Unconfirmed placement preserves the exact original request in session memory; it is never a success screen or an offline queue.
11. Messages combine previews while retaining separate Shop, Logistics and Courier permissions and histories.
12. Account, saved Products, Orders and vouchers remain account-scoped and clear on identity loss.

## Existing Flutter presentation

Inspected [theme](../../lib/app/theme.dart), [router](../../lib/app/router.dart), [communication routes](../../lib/app/communication_routes.dart), [shell](../../lib/app/shell_screen.dart), [header](../../lib/core/ui/marketplace_chrome.dart) and feature presentation sources.

| Token | Existing value / instruction |
| --- | --- |
| Theme | Light Material 3 only |
| Brand | `#E6007A` |
| Control/text pink | `#B60060` |
| Secondary | `#4C1268` |
| Canvas / surface | `#F5F5F5` / white |
| Ink / secondary ink | `#211C23` / `#625A61` |
| Borders / tint | `#E4DFE3` / `#FFF0F6` |
| Error / warning | `#B42318` / `#FF8800` |
| Corners | 8 logical px; minimal shadows |
| Type | Existing Material default; Stitch uses Roboto Flex as a reference approximation, not an approved dependency |
| Targets | At least 48 × 48 logical px; visible focus and text labels/semantics |
| Margins | Phone 16; tablet 24; desktop 32 |
| Widths | Forms at most 560; shopping at most 1200 logical px |

Product grids use square images, two-line preview titles, full prices and wrapping actions. Normal phone grids usually have two columns; narrow/large-text layouts reduce columns. Use natural content heights and safe-area/keyboard-aware scrolling. Purchase/composer actions must not cover content. The existing Flutter variant picker uses dropdowns and a quantity stepper inside a mobile sheet; Cart editing is a separate flow.

The inspected [historical synthetic screenshots](../reports/buyer-ui-overhaul-2026-10-17.md) show Home, Product, Checkout, Account and messaging. They predate the Home-only header-search/combined-Messages update: current source takes precedence. No current live app was launched and no private catalogue, credential or account payload was uploaded to Stitch.

## Synthetic reference data

All names, photographs, amounts and status examples in generated designs are illustrative, not live records or promises. Never copy generated catalogue metadata into production as server truth.

| Product | Shop | Quantity | Unit / line amount |
| --- | --- | --- | --- |
| Everyday canvas tote, Natural / Standard | Luna Goods | 1 | PHP 349.00 |
| Stoneware mug | Studio Clay | 1 | PHP 229.00 |

Synthetic shipping is PHP 60.00 for Luna Goods and PHP 50.00 for Studio Clay. Group totals are PHP 409.00 and PHP 279.00; merchandise PHP 578.00 + shipping PHP 110.00 − discounts PHP 0.00 = COD PHP 688.00. These are static reference numbers, never a client pricing algorithm. Selected tote SKU `TOTE-NAT-STD` has a synthetic current stock projection of 8. Address/contact information is hidden; use no complete personal address in screenshots.

## Mandatory states and boundaries

- Loading preserves layout; absent optional rails disappear. A failed request has Retry and never looks like a successful empty list.
- Show empty, unavailable, forbidden, partial, stale, offline, throttled, validation and uncertain outcomes as applicable. Preserve safe input after recoverable failures.
- Consent begins unchecked, shows exact current policy/version and offers explicit acceptance and Sign out; no shopping escape.
- Quote changes, expiry, coverage loss and voucher conflicts require refreshed reviewed intent. No automatic Place order.
- Vouchers are server candidates/collections with issuer, benefit, terms and eligibility reasons. No arbitrary code entry, best-voucher auto-application or cash balance.
- Orders render server labels and actual events. Direct assigned → delivered is allowed; invent no intermediate events, live GPS or ETA.
- Messaging has no presence, calls, task acceptance, POD, hub selection or COD collection. Business availability is not personal online presence.
- Exclude Bazaar, MoneyFest, online payments, returns/refunds, account deletion/export, session registry and unsupported attachment uploads.
- Generated design-system defaults can drift from Flutter tokens or invent badge examples. The source contract and this brief take precedence; raw Stitch metadata is evidence, not an adopted design contract.

## Review scope

Use Stitch screenshots for composition and visual review. Static image review cannot prove touch dimensions, contrast, focus order, text scaling, keyboard behavior, Back handling or API correctness. Those checks remain for a separately authorized implementation. The design-taste-frontend app-screen guidance informed hierarchy and honest data; its generic style palette, typography selection and web implementation workflow do not replace the established Buyer theme or this design-only scope.
