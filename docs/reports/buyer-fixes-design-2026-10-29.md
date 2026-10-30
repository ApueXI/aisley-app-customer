---
report_type: buyer-ui-audit
recorded_at: "2026-10-29T10:38:03+08:00"
timezone: Asia/Manila
branch: fix/buyer-products-vouchers-live-chat
commit: aa28c4f13fbe7c63caf00b735682be92ca92df33
working_tree: "Implementation and QA changes in progress; designer owns only this report and its evidence."
scope: "Home discount prices, Product imagery, Shop voucher navigation/page, and Shop conversation presentation"
backend_baseline: "Buyer adoption 1858785e plus recorded feature slices; deployed revision unidentified"
---

# Buyer requested fixes — independent design review

The comparison uses the selected local Stitch references [01 Home](../stitch/screenshots/01-home.png), [02 Product Details](../stitch/screenshots/02-product-details.png), [09 Shop Storefront](../stitch/screenshots/09-shop-storefront.png), [13 Vouchers](../stitch/screenshots/13-vouchers.png), and [15 Shop Conversation](../stitch/screenshots/15-shop-conversation.png). The [manifest](../stitch/manifest.json) identifies revision 2; superseded versions are excluded.

The source review follows [Buyer design](../design-buyer.md), the owning Homepage, Browse Shop, Product, voucher and chat specifications, the API messaging/collection contracts, and the session/consent prerequisite. Buyer feature contracts and documented neutral Material theme take precedence over generated decorative colors or unsupported reference metadata. The user-requested discount text removal and dedicated Shop voucher page are authorized changes to the comparison content.

The designer used `buyer-review-ui` audit instructions and the `design-taste-frontend` app-screen review/critique. This is a scoped Flutter review, with the existing Stitch direction retained; no alternative style was dealt and no design-system migration was attempted. Product code, tests and backend files are outside the designer's ownership.

## Evidence method

The synthetic browser run completed successfully. Evidence, coverage, scores and remaining reference differences follow. The fixture has no pinned Product context; long pinned-context/keyboard behavior needs its separately recorded focused QA checks.

- Browser target: isolated headless Chromium/ChromeDriver at `http://localhost:8766`.
- `/tmp/buyer-design-capture.py` installs API interception before Flutter startup, including synthetic login, `/me`, consent, Products/Shops/vouchers and conversation responses; unknown API calls fail locally. No real account or Laravel write is used.
- Test imagery is a valid, locally generated asymmetric PNG, used to make image decoding, fit and bounds visible. It is not production photography or a substitute for Stitch's product photographs. Pixel equality of different fixtures is not a meaningful parity metric.
- An initial workspace `build/web` was found to contain obsolete four-tab navigation and inline Shop vouchers. Those preliminary captures are excluded from current implementation conclusions because they do not match current source.
- The skill's DOM/CSS inspector cannot measure Flutter CanvasKit inner widgets or their actual text/touch bounds. Screenshot inspection and Flutter QA evidence are reported separately; no DOM inspector success is claimed.
- No installed Android, TalkBack, real soft keyboard, doubled-text browser run, controlled live API/CORS, provider delivery, signing or release acceptance is established by this review.

## Review disposition

The requested changes are visible in the scoped candidate: discounted cards retain the crossed-out original amount without “Was”; catalog images render; the Shop shows one voucher navigation row and vouchers load on a separate page; a received chat reply appears without manual refresh. The chat presentation now uses purple outgoing bubbles, white incoming bubbles, sender labels above them, and an inline image/message/Send composer at ordinary phone widths. At 320px the composer stacks its controls to preserve touch targets.

Pixel identity is **not established**. Remaining visual differences described below are confined to reference fidelity; this review does not classify them as newly reproduced shopping failures. Fixture-dependent omissions, the established neutral theme and accessibility adaptations are identified separately.

## Remaining reference differences

### BUI-001 — Product sections differ from the selected full-width composition

- Classification: confirmed visual fidelity difference; low severity; high confidence from synthetic screenshots and selected reference 02.
- Area/source: `/products/:id`; `ProductGallery` and Product detail composition in `lib/features/discovery/presentation/`.
- Reproduction: load the synthetic visible Product at 390×844, text scale 1, portrait, zero keyboard inset; compare Product screenshot with reference 02 at 390 logical pixels wide.
- Observed/expected/impact: the gallery is inset 16px and the Product information is grouped in a bordered card; reference 02 has a full-width image and separate white price, guidance, specifications and Shop sections. The available Product identity, image, price and purchase actions remain clear, but the composition is visibly different from the user's identity target.
- Proposed correction: a later scoped composition pass could separate the existing typed sections and adjust their surfaces/gutters without changing purchase controllers, image fitting or server authority.
- Acceptance: compare equivalent Product/media/options states at 390px; then retest 320px, doubled text, desktop reflow, gallery-page retention and purchase-sheet Cancel. Device and enlarged-text visual acceptance remain open.
- Dependencies: no missing endpoint is identified. Different source-image aspect ratio and absent fixture specifications must not be “fixed” by stretching images or fabricating data. No further Product code change was requested by the designer after the lead froze the candidate.

### BUI-002 — Shop header and filters retain existing presentation

- Classification: confirmed visual fidelity difference; low severity; high confidence from synthetic screenshots and reference 09.
- Area/source: `/shops/:slug`; `ShopScreen` in `lib/features/discovery/presentation/shop_screen.dart`.
- Reproduction: open the synthetic Luna Goods storefront at 390×844, text scale 1, portrait, zero keyboard inset, then compare reference 09.
- Observed/expected/impact: the Shop header remains “Shop”, Message Shop is a text action, and the category selector is followed by a filled Apply filters button. Reference 09 leads with the Shop name, a wider outlined Message Shop control, and a more compact category/clear arrangement. The new single View Shop vouchers row is correctly positioned between Shop details and Product search; the remaining differences affect visual matching.
- Proposed correction: reuse the existing Shop name and filter callbacks in a future Shop composition pass; retain explicit filter behavior and accessible wrapping rather than inventing new server controls.
- Acceptance: compare the same visible Shop/filter state at 390px; verify filter intersection, independent clears, Back retaining filters, 320px/doubled text and unavailable-Shop handling.
- Dependencies: nullable branding has no right to become an invented Shop logo; missing business-availability data must not be fabricated for parity. The reference's pink-tinted canvas is intentionally subordinate to the current neutral Buyer theme.

### BUI-003 — Voucher cards retain additional factual detail and action placement

- Classification: confirmed visual fidelity difference; low severity; high confidence from runtime and reference 13.
- Area/source: `/shops/:slug/vouchers`, `/vouchers`; `VoucherCard` and `VoucherListView` in `lib/features/vouchers/presentation/`.
- Reproduction: open vouchers at 390×844, text scale 1, portrait, zero keyboard inset; compare supplied benefit, issuer, name and actions with reference 13.
- Observed/expected/impact: benefit filters, explicit maximum savings, Manila date/time and remaining-use details remain visible; Collect voucher precedes Details instead of occupying the trailing position in the reference. This is useful contract-backed information, with a different card density and action arrangement. The dedicated Shop page and My Vouchers link match the intended journey.
- Proposed correction: retain all required factual fields while considering a future wide-card trailing collection action; keep wrapping below 360px and at enlarged text.
- Acceptance: compare normal, collected, uncertain, automatic and unavailable states without hiding eligibility or changing collection semantics; verify 320px and doubled-text actions remain reachable.
- Dependencies: reference 13 is global voucher discovery, not a separately authored Shop-voucher design. Different offer counts/benefits and schedule data are fixture differences; no unsupported offer or date should be added for a visual match.

### BUI-004 — Conversation participant caption differs from reference

- Classification: confirmed minor visual/copy fidelity difference; low severity; high confidence from runtime.
- Area/source: `/messages/shops/:id`; message-row labels supplied by `shop_screens.dart` and rendered by `MessageBubble`.
- Reproduction: view the synthetic received Shop reply at 390×844, text scale 1, zero keyboard inset; compare reference 15.
- Observed/expected/impact: incoming captions show the server role label “seller”, while reference 15 shows the Shop's public name. The corrected bubble colors, caption position and compact composer are visually much closer. Channel identity is still shown in the header.
- Proposed correction: a future presentation-only caption mapping could use the already-authorized Shop identity for this channel while retaining distinct Logistics/Courier identities.
- Acceptance: verify outgoing/incoming captions, nullable timestamps, read-only relation, attachments, narrowed/large-text layouts and channel separation; live counterpart/device checks remain open.
- Dependencies: absent timestamps and Product context in this fixture are valid nullable states, not reference regressions. The draft field's explicit Message label is retained for accessibility. No new presence or typing state is implied.

## Final screenshot coverage and verification

The final capture used `/tmp/buyer-qa-web-source/build/web`, built successfully in 180.2 seconds with the existing Flutter SDK and dependencies. Its Dart sources exactly matched the workspace when provenance was recorded: source SHA-256 `fdcff497299ec9644826e74cf8b6b9eace2b5b40f2ec26e01581c22a1fb54040`. The [provenance](buyer-fixes-design-2026-10-29/provenance.json) also records the compiled-JavaScript hash and verifies all five selected reference PNG hashes against the unchanged Stitch manifest.

A later correction to bounds for exceptionally long pinned conversation context is outside the fixture's context-null branch. These captures do not verify that branch; refer to the independent QA report for its regression and keyboard/text-scale result.

All six routes were captured at **320×640, 390×844, 600×960, 800×1280, 1024×768, 1440×900 and landscape 844×390**; text scale 1, device scale 1, zero keyboard/safe-area insets. [Coverage JSON](buyer-fixes-design-2026-10-29/coverage.json) records all 42 combinations. The browser document-width assertion passed 42/42; CanvasKit can conceal inner-widget overflow from that assertion, so it does not replace screenshot or Flutter layout tests. Forty-three PNGs, including the automatic reply, are preserved with [checksums](buyer-fixes-design-2026-10-29/screenshots.sha256.json).

| Surface and fixture | Source review | Fresh synthetic runtime and evidence | Result and limits |
| --- | --- | --- | --- |
| Home, two supplied Products and one real discount projection | Home, card information, shortcuts and image loader | [390](buyer-fixes-design-2026-10-29/home-390.png), [320](buyer-fixes-design-2026-10-29/home-320.png), [desktop](buyer-fixes-design-2026-10-29/home-1440.png); all seven sizes captured | Original amount is crossed out without “Was”; both API and allow-listed external-image fixtures render. Vouchers/Recent labels and Categories heading match the selected wording; Stationery no longer splits inside the word. At 320 the shortcut row wraps deliberately. |
| Shop, synthetic visible Luna Goods | Shop screen and voucher entry row | [390](buyer-fixes-design-2026-10-29/shop-390.png); all seven sizes captured | Exactly one View Shop vouchers row; no inline voucher listing. The row was tapped to reach the dedicated page. Remaining header/filter differences are BUI-002. |
| Shop vouchers, one uncollected offer | Dedicated list routing, scope and cards | [390 with Back](buyer-fixes-design-2026-10-29/shop-vouchers-390.png), [320](buyer-fixes-design-2026-10-29/shop-vouchers-320.png); all seven sizes captured | The actual navigation row opens this page. An actual pointer tap on the header Back control returns to the same Shop. Filters and wrapping remain visible. No collection write was exercised. |
| Global vouchers, one supplied offer | Shared voucher list/card | [390](buyer-fixes-design-2026-10-29/vouchers-390.png); all seven sizes captured | Discover vouchers and My Vouchers remain distinct. The fixture count and factual details differ from reference 13; BUI-003 records presentation differences. |
| Product, one 3:2 test image and no options | Gallery, image loader and detail composition | [390](buyer-fixes-design-2026-10-29/product-390.png), [desktop](buyer-fixes-design-2026-10-29/product-1440.png); all seven sizes captured | Image decodes, retains aspect ratio in the gallery and fills card image slots using their fit rule. Detail purchase buttons remain visible. Different image aspect ratios are not stretched to match the reference photograph. |
| Shop conversation, two initial messages followed by a new incoming reply | Thread view/composer, bubble and header | [390](buyer-fixes-design-2026-10-29/chat-390.png), [320](buyer-fixes-design-2026-10-29/chat-320.png), [landscape](buyer-fixes-design-2026-10-29/chat-844.png), [new reply](buyer-fixes-design-2026-10-29/chat-live-390.png); all seven sizes captured | Purple outgoing/white incoming bubbles, captions above, and compact composer match the reference direction. The third reply appeared after updating only intercepted server responses, without clicking refresh or reloading. This proves synthetic foreground delivery, not deployed realtime or background push. |

All 43 final screenshots were visually inspected: ten at their original individual size and the other 33 in nine labeled contact sheets generated with the already-installed ImageMagick. This includes every captured tablet/intermediate and landscape viewport. No new visible clipping or overlap was found in the photographed fixture states; scrollable content below the fold is not treated as missing. The [visual-review ledger](buyer-fixes-design-2026-10-29/visual-review.json) records the inspection method for every original screenshot. Fine text, focus, internal scroll reachability and unpictured states still require their dedicated checks. Browser screenshots do not certify TalkBack order, measured contrast, native keyboard behavior, or every 48px target. Doubled-text, failure/read-only/uncertain-media states, real participant exchange and installed Android remain outside this designer runtime run. QA's independent unit/widget/analyzer/build results are recorded separately in [the verification report](buyer-fixes-verification-2026-10-29.md).

The initial live-reply text assertion was unsuitable for Flutter's `SelectableText`: the message body was visibly rendered but absent from the harness's document-text enumeration. The corrected harness waits for the new message's sender node, then captures the rendered third bubble; the final run passes. This limitation is recorded rather than presented as a chat-delivery failure or full browser-screen-reader certification.

## Scores and final critique

**Stitch visual fidelity: 7.7/10.** This is a designer's structural/style assessment of equivalent surfaces, not a measured pixel-similarity percentage. Photo subjects, fixture counts, nullable timestamps/context, deliberate neutral-brand tokens and accessible narrow-screen wrapping are excluded from the comparison. Exact identity is not claimed.

| Surface | Fidelity / 10 | Assessment |
| --- | --- | --- |
| Home | 8.5 | Requested price text and image rendering are corrected; shortcut wording/spacing and category labels are closer. Search treatment, iconography and card/section spacing still differ. |
| Product | 6.5 | Product image, price and purchase actions are clear; section composition differs visibly from reference 02 (BUI-001). |
| Shop | 7.5 | Voucher entry matches the reference's location and journey; header/filter controls remain different (BUI-002). |
| Vouchers | 7.5 | Issuer, benefit, white card and collection journey match the direction; filter/detail density and action position differ (BUI-003). |
| Shop conversation | 8.5 | Compact composer, purple/white bubbles and caption position closely follow reference 15; participant wording and spacing retain differences (BUI-004). |

ROUND — final candidate

Seen in one second: identifiable shopping Products/prices and a clear Shop chat composer.

Idea (one sentence): retain familiar AISLEY shopping patterns while moving Shop offers into their own page and receiving replies without manual refresh.

Live thing: actual Shop-voucher navigation/Back and an incoming synthetic chat reply without refresh.

Layout words by section: Home=shortcuts/category row/Product rail; Shop=summary/navigation/filter/grid; vouchers=offer list; Product=gallery/details/purchase bar; chat=transcript/composer.

Scores: design **7.5** · usability **8.0** · creativity **6.0** · content **7.0** → weighted overall **7.4/10** (`0.4D + 0.3U + 0.2C + 0.1Content`, rounded from 7.35).

Caps applied: the design-taste app-screen rules apply; marketing-page photograph-count, entrance-motion and live-element caps do not. No Flutter-capable DOM/CSS inspector result is asserted. Content scoring assesses truthful structure/copy rather than treating the deliberately geometric image fixture as production photography. Creativity reflects faithful familiar shopping conventions rather than an unrequested new visual concept.

Top three remaining reference gaps, in visible order:

1. Product gallery/section composition differs from the full-width reference: [Product at 390](buyer-fixes-design-2026-10-29/product-390.png), BUI-001.
2. Shop summary and filter controls differ from the compact reference arrangement: [Shop at 390](buyer-fixes-design-2026-10-29/shop-390.png), BUI-002.
3. Voucher factual detail and action order differ from the reference's trailing Collect action: [Shop vouchers at 390](buyer-fixes-design-2026-10-29/shop-vouchers-390.png), BUI-003.

The designer requests no further application edits after the lead's scope freeze. These differences remain explicit review results; no critical/high defect or new backend contract conflict was established by the designer. Controlled live/deployed API, installed Android/TalkBack, production configuration/signing, private-media runtime and exact pixel parity remain unverified.
