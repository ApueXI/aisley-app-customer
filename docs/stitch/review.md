# Stitch reference review — 2026-10-28

These are reviewed design drafts, not approved implementation specifications. Review used returned PNGs, current Flutter presentation source and the linked feature contracts. Static images cannot establish implemented behavior or measured accessibility.

## Work completed

- Inspected project rules, progress, Buyer design, Customer rules and the feature specs mapped in [screen-map.md](screen-map.md), including session/consent prerequisites and all three messaging channels.
- Inspected Flutter theme/router/header, Home, Product detail/purchase flow and SKU picker, Cart, Checkout, Account, combined Messages, voucher cards, sign-in and consent presentation.
- Viewed the repository's dated sanitized Home/Product/Checkout screenshots. Current source supersedes their older global-search placement.
- Listed owned and shared Stitch projects. No matching AISLEY Customer project existed; created the private project recorded in [manifest.json](manifest.json).
- Generated Home first and reused its design-system resource for subsequent screens. Retrieved screenshot bytes through Stitch MCP rather than directly fetching credentialed file URLs.
- Reviewed initial commerce/supporting images and requested ten specific screen refinements. Original and replacement IDs remain in the manifest; only selected reference screenshots are stored locally.
- The final six supporting references initially returned DESKTOP 2560×2048 exports despite a MOBILE request. A second targeted refinement returned MOBILE 780-pixel-wide portrait screens, removed invented policy wording and removed unsupported price data from Shop message context. Their corrected PNGs replaced the desktop exports locally.

## Corrected generation drift

| Initial problem | Refinement result observed |
| --- | --- |
| Invented Official Store/Verified/Free Shipping badges, sold counts, old prices and sample reviews | Removed from revised Product, Cart and Checkout; Product retains links to separately owned Q&A/review screens |
| SKU chips instead of current picker dropdowns; missing Cancel | Revised picker uses Color/Size dropdowns and explicit Cancel/Close |
| Unsupported bulk Cart deletion | Removed header trash action; retained item-level text actions and selected checkout |
| Invented mug variants inconsistent across screens | Removed from revised Cart, Checkout and Orders |
| Delivery-day estimates and exact-cash rule | Removed from revised Checkout; COD remains the sole payment method |
| Recovery text promising automatic network verification or exposing handshake/fingerprint/idempotency jargon | Revised to manual exact placement retry and Check Orders, with honest session-memory limitation |
| Shop directory verification/Fair Trade claims | Removed; directory keeps category selection and View Shop |
| Storefront dispatch timing, verification and unsupported quick-add | Removed; revised cards open Product detail; voucher section is a supported link |
| Account missing Messages utility and implying broad security controls | Header utilities restored; Password is named narrowly |
| Orders count 11 with only two sample orders; receipt/tracking-ID promises | Removed count and unsupported footer |
| Fabricated tracking number and handshake status | Revised Order timeline has one numbered Order placed event and map-unavailable text |

## Remaining visual and contract review notes

The refinement service described all conflicts as corrected. PNG review supports the changes above, with these remaining exceptions. Do not treat service descriptions as acceptance evidence.

- **02 Product Details:** still prints `TOTE-NAT-STD` beside “Select options to check availability.” Remove this preselection-dependent SKU in a later refinement/implementation until a valid choice exists. The numbered screen title is a reference label, not product UI copy.
- **03 Quantity/SKU:** dropdowns/Cancel are improved, but stock is repeated, Clear choices is absent and the underlying backdrop still appears blurred. Restore the existing reset affordance and plain dim overlay. The full-height screenshot is not proof the sheet fits a short viewport or keyboard.
- **04 Cart, 09 Shop and 11 Orders:** some overall canvas areas and borders remain pink/purple despite the neutral token request. Keep the existing Flutter neutral canvas/borders in any implementation. Cart actions appear on one line in the export; they must wrap with 48px targets at actual phone width/large text.
- **07 Search / 09 Shop:** generated Product-card sublines show selected-looking option descriptions. Listing DTOs do not establish a preselected variant; do not infer selection from those sublines. Search's global “opens SKU and quantity options” hint is only applicable to Products that require options; simple listing adds use the existing current-detail flow. One generated product photo includes a stray mini search-bar artifact.
- **09 Shop:** “Shop open” is duplicated and must come from the scoped Shop availability read; it is not a field inferred from directory data. Clear search is shown as an icon, requiring an accessible label. “View Shop vouchers” must open the existing supported Shop voucher surface, not invent a new route.
- **10 Account:** decorative avatar/section treatments differ from the current Flutter identity card, and body headers use all caps. Treat them as exploration, retaining source behavior and actual theme tokens.
- **11 / 12 Orders:** generated shipping labels are illustrative; render the returned provider/quote facts. Synthetic dates are not live events. Missing IDs/images remain nullable. Server actions govern actual contact/cancel/correction availability.
- **All screenshots:** export raster widths differ from the requested 390 logical px. Exact dimensions are recorded from PNG headers; no device-pixel-ratio or measured logical sizing is assumed. No target-size, contrast, text-scaling, focus, screen-reader, keyboard or device interaction verification is claimed.
- **13–18 supporting references:** final mobile images preserve collection actions, channel-specific stale/read-only feedback, blank sign-in fields, unchecked/disabled consent and masked addresses. Voucher definitions and policy version 1 are synthetic; policy preview text is not legal content. Conversation attachment controls still need labels/permissions/media states in any later implementation. Generated bubble radii and other decoration do not override the Flutter theme.
- **Remote indexing:** `list_screens` returned only the original Home/commerce six-screen set and `get_project` exposed that older canvas. Direct `get_screen` reads succeeded for all 18 reference IDs. The manifest is the complete retrieval index; no claim is made that the current Stitch canvas visibly lists every generation/revision.
- **Design system:** the generated snapshot includes derived palette/type choices and badge examples that conflict with the explicit brief. An MCP `update_design_system` request returned `Request contains an invalid argument.`; no successful system update is claimed. Screen-specific refinement prompts applied the corrections. Use [DESIGN.md](DESIGN.md) and the existing Flutter theme as authority, not the raw generated snapshot.

## Scope and acceptance

Verification completed for the documentation bundle:

- An inline Python check parsed every saved JSON file; verified 18 unique numbered, directly retrieved MOBILE IDs; checked every PNG signature, chunk CRC, dimensions and terminal chunk; recorded SHA-256 hashes; matched the screenshot inventory exactly; and checked the illustrative totals.
- `PYTHONDONTWRITEBYTECODE=1 python3 tool/verify_bundle.py` passes local links, all 22 Customer spec bounds, all 19 PSGC checksums/registrations and Android boundaries.
- `git diff --check` passes. A scoped `git diff --exit-code HEAD -- lib test assets pubspec.yaml pubspec.lock android web` confirms those application paths are unchanged before the documentation commit.
- Flutter formatting/analyzer/tests/builds and live/device checks were not rerun because this task changes design documentation and reference images only.

No Flutter code, application assets, routes, dependencies, tests, backend or configuration files were changed. No `.env` file was inspected/copied/modified, no live private data was retrieved and no current authenticated app was launched. Only synthetic brief text was sent to Stitch. No generated HTML/CSS/source package was downloaded or installed.

Unillustrated routes and remaining states are explicitly listed in [screen-map.md](screen-map.md). Further design refinement or future implementation must preserve those contracts. Controlled live/deployed API, installed Android/GPS/TalkBack, provider/private-media and production signing gates remain open. Documentation and image validation do not close them.
