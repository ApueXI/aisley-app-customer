# Stitch revision 2 — navigation and purchase quantity

Requested 2026-10-28. Scope: update the remote AISLEY Customer Stitch references and this reference bundle only. No Flutter UI/UX, frontend code, navigation implementation, APK or backend change is authorized by this task.

This request supersedes the initial Stitch brief where navigation and quantity placement differ. [Buyer design](../design-buyer.md) and the feature specs still describe the unchanged application; they are not revised to claim these designs are implemented.

## Requested navigation

| Position | Revised reference |
| --- | --- |
| Bottom navigation | Home, Notifications, Account, in that order |
| Former Shops bottom item | Removed; Shops remains reachable through Home's Browse Shops action |
| Former Cart bottom item | Replaced by Notifications |
| Former header Notifications button | Replaced by Cart, preserving its position beside Messages and Terms/Privacy |
| Cart and Shops directory | Utility subpages with predictable Back; no old four-item bottom bar |

The Notifications tab opens the existing inbox. It does not imply native push, background delivery, a global unread-count API or Mark all read. Notification rows keep textual read/unread state and existing pagination/filter behavior. Product Shop links and Shop messaging remain available.

## Requested purchase flow

- Home Product cards and every Home Product rail have no Add to Cart or quick-add controls. Tapping a Product opens its detail.
- Product detail has no inline Quantity label/stepper/input, selected quantity or preselected SKU. Add to Cart and Buy Now remain its deliberate purchase actions.
- Every Add to Cart or Buy Now entry asks for quantity in a bounded, scrollable purchase sheet before proceeding, including simple Products without options/SKU.
- Variant Products use that same sheet with valid server-listed option choices and quantity. Simple Products show quantity without invented option groups or SKU fields.
- Add to Cart entry: sheet confirmation is Add to Cart. Buy Now entry: sheet confirmation is Continue to checkout; it preserves Buy Now's separate intent and leaves Cart unchanged.
- Both sheets have Close and Cancel. Opening, selecting or cancelling performs no commerce write and creates no Order. Quantity remains a positive integer bounded by the current stock projection; Laravel rechecks actual eligibility.
- Retained Add to Cart actions outside Home also use this global design rule. Cart line editing and Checkout item quantity summaries are separate existing flows; their displayed quantities are not removed by this request.

## Contract and implementation boundary

[Home](../features/customer/customer-homepage/spec.md), [Product](../features/customer/view-product/spec.md), [Cart](../features/customer/view-cart/spec.md), [Browse Shop](../features/customer/browse-shop/spec.md) and [Notifications](../features/customer/notifications/spec.md) supply the existing API/ownership boundaries. The present Product implementation opens a sheet for variant Products while simple Product quantity can appear inline or use one-unit listing adds. This revision is the user's intended design change, not evidence that the current source already does it.

Retain session/consent gates, stock/visibility checks, uncertain Cart reconciliation, explicit Checkout quote/review/confirmation and separate message channels. No API endpoint, payload, dependency or authority changes are introduced by moving controls in these references. Synthetic catalogue data and masked personal information remain required.

## Reference coverage

Revise 01 Home, 02 Product Details, 03 Quantity and SKU Selection, 04 Cart, 08 Shops and 10 Account. Add representative simple Product detail, simple Add-to-Cart quantity sheet, simple Buy-Now quantity sheet and Notifications references. These extra references illustrate existing destinations and modal states; modal states are not new routes.

Exact MCP requests, resource IDs and local screenshot paths are recorded in [requests.json](requests.json) and [manifest.json](manifest.json). Initial resource IDs remain available as superseded entries. The initial [review](review.md) describes the first pass; its navigation and simple-Product purchase observations do not override this revision.

Simple-Product examples use Stoneware mug, Studio Clay, PHP 229.00 and an illustrative current stock of 12. The Add to Cart sheet shows quantity 1; the Buy Now sheet shows quantity 2 to demonstrate the separate confirmation step. These are modal-state examples, not changes to the existing two-Shop Checkout sample or its PHP 688.00 COD total.

## Verification boundary

### Screenshot review result

| Reference | Observed final image |
| --- | --- |
| 01 Home | Three bottom items Home/Notifications/Account; header Cart replaces bell; no quick-add controls in rails/grid; body Shops shortcut remains |
| 02 / 19 Product Details | No inline quantity or selected SKU; Add to Cart and Buy Now remain; existing Wishlist heart and Cart utility preserved |
| 03 Quantity/SKU | Variant choices and quantity live inside the sheet; Clear choices/Close/Cancel present; backdrop uses Product Details/heart/Cart without the old bell |
| 04 Cart / 08 Shops | Back subpages without the old bottom navigation; existing Cart line actions and Shop browsing retained |
| 10 Account / 22 Notifications | Correct three-item bottom navigation and Messages/Cart/Terms-Privacy header; relevant selected tab shown |
| 20 Simple Add to Cart | Quantity 1, no option/SKU rows, Cancel/Close and one Add to Cart confirmation |
| 21 Simple Buy Now | Quantity 2, no option/SKU rows, Cancel/Close and one Continue to checkout confirmation |

The first revised Home PNG still contained six Add to Cart buttons despite the service's summary. A targeted correction removed all six button rows and collapsed the cards. Review also caught and corrected an old header bell behind the variant sheet, lost Wishlist actions, unsupported Share/price/rating/sold metadata and serif font drift in the simple sheets, and the wrong Shop attribution in a synthetic notification. Raw service descriptions remain in the service notes; they are not verification claims.

All 22 selected resource IDs resolve through direct MCP reads. Ten selected images are new/revised in this pass; the other twelve retain their first-pass references. Superseded IDs are retained in the manifest, and earlier committed PNGs remain in Git history. The latest image bytes were retrieved with `download_file`; no generated source package was downloaded.

Remaining first-pass visual caveats still apply to unmodified screens, and muted canvas/border tint, repeated stock labels and decorative details in generated images are not exact Flutter tokens. Some generic Search helper wording still describes SKU selection broadly; revision 2's quantity-first rule takes precedence for simple Products. Numeric dimensions, text scale, focus, hit targets and prototype links are not verified by static PNG review. No tap wiring or app functionality is claimed.

Review returned screenshots for the three-item navigation, header Cart placement, absent Home purchase buttons, absence of inline Product quantity and explicit confirmation sheets for both simple-Product purchase actions. Verify resource retrieval, MOBILE format, PNG integrity/dimensions/checksums, JSON, local links and unchanged application paths. Static design references do not prove working taps, accessibility, API behavior or installed-device acceptance. Flutter tests/builds are not rerun for reference-only changes.

Executed verification: direct MCP `get_screen` reads for all 22 IDs; an inline Python check for JSON, unique numbered IDs, MOBILE format, exact PNG signature/chunk CRC/dimensions/terminal chunk, SHA-256, gallery inventory, requested revision metadata and synthetic arithmetic; `PYTHONDONTWRITEBYTECODE=1 python3 tool/verify_bundle.py`; `git diff --check`; and `git diff --exit-code HEAD -- lib test assets pubspec.yaml pubspec.lock android web`. All pass. Progress stays below 150 physical lines; no archive is required for this entry.
