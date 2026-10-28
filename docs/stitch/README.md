# AISLEY Customer — Google Stitch references

Initial reference-generation record, 2026-10-28: design exploration only; at generation time there were no Flutter source or frontend changes. The selected revision-2 presentation was later implemented in the existing Buyer Flutter routes and screens. No backend, dependency or production configuration change accompanied the implementation.

Current direction: [revision 2 — navigation and purchase quantity](revision-2.md). It supersedes the original bottom navigation and makes purchase-sheet quantity selection apply to simple and variant Products. The screenshot gallery/manifest identify the latest selected references; prior IDs remain in the superseded manifest entries.

Canvas cleanup is pending browser access. The remote project currently contains 51 versions: keep the 22 current references and remove the 29 superseded instances listed in [canvas-cleanup.json](canvas-cleanup.json). No remote deletion has been performed. The connected Stitch MCP has no individual screen-delete/hide operation; its project-delete operation would also delete the current designs.

- Stitch project: [AISLEY Customer](https://stitch.withgoogle.com/projects/3960147693568073492)
- Project resource: `projects/3960147693568073492` (private).
- Initial reusable design-system resource: `assets/209b92e003bd4111b4e38fd6ede0e1ce`.
- Inspected Buyer source: `8c04148b5ff00841b75b1794137f25599abcc4bc`.

## Start here

| File | Purpose |
| --- | --- |
| [DESIGN.md](DESIGN.md) | Buyer brand, source inspection, synthetic data, boundaries and state requirements |
| [revision-2.md](revision-2.md) | Latest user-requested navigation and global quantity-sheet direction |
| [canvas-cleanup.json](canvas-cleanup.json) | Verified keep/remove inventory and pending remote cleanup status |
| [screen-map.md](screen-map.md) | References mapped to existing routes/specs; unillustrated routes explicitly identified |
| [manifest.json](manifest.json) | Project/screen/file IDs, tool-returned references, screenshot dimensions and checksums |
| [Stitch implementation report](../reports/stitch-implementation-2026-10-28.md) | Current Flutter source coverage, implementation evidence and pending acceptance |
| [requests.json](requests.json) | Exact generation/refinement requests for reproducibility |
| [review.md](review.md) | Screenshot review, corrected generation drift and remaining limitations |
| [service-notes.md](service-notes.md) | Stitch's returned descriptions/suggestions, preserved as service output |
| [design-system.stitch.json](design-system.stitch.json) | Initial raw generated design-system snapshot; not an adopted Flutter theme |

## Screenshots

The manifest and gallery below identify the selected local PNG for each reference. Downloaded screenshots use Stitch's returned file resource through MCP `download_file`; protected download URLs were not fetched directly. Images contain synthetic examples and masked address information. No application HTML, CSS or generated frontend code is imported.

| Reference | Screenshot | Stitch screen ID |
| --- | --- | --- |
| 01 Home | [PNG](screenshots/01-home.png) | `146d3cfafee646faa02ce82f31f05565` |
| 02 Product Details | [PNG](screenshots/02-product-details.png) | `3de32680e48a428d8121176312f3e834` |
| 03 Quantity and SKU Selection | [PNG](screenshots/03-quantity-and-sku-selection.png) | `95ce65c217504cceb937442fb7ef986c` |
| 04 Cart | [PNG](screenshots/04-cart.png) | `0e7b92c42be544ea8bdd8efb24983cf8` |
| 05 Checkout | [PNG](screenshots/05-checkout.png) | `f83961bc1f834506859a2b322c4eddb9` |
| 06 Checkout Recovery | [PNG](screenshots/06-checkout-recovery.png) | `63121b93171643f29205bdb38abd1239` |
| 07 Search | [PNG](screenshots/07-search.png) | `24c2ad0947474511b2906663c19b3d48` |
| 08 Shops | [PNG](screenshots/08-shops.png) | `d11949191d9d44c2a4fc2b883a6122dc` |
| 09 Shop Storefront | [PNG](screenshots/09-shop-storefront.png) | `1463794dc9064f65bc406e338874f442` |
| 10 Account | [PNG](screenshots/10-account.png) | `60dbc31d98774e3d8d25e330ae71eef7` |
| 11 Orders | [PNG](screenshots/11-orders.png) | `6f7f56cfd0e84812a13a2ff48c1362cd` |
| 12 Order Details and Tracking | [PNG](screenshots/12-order-details-and-tracking.png) | `cd160c3efe4c4485a2c17b0763b087f3` |
| 13 Vouchers | [PNG](screenshots/13-vouchers.png) | `896b978baee2431abef1d5656b5efc20` |
| 14 Messages | [PNG](screenshots/14-messages.png) | `80ffda80b4bb4cbb804a81cfd4ce5341` |
| 15 Shop Conversation | [PNG](screenshots/15-shop-conversation.png) | `df35b726ad624541809f4f39c6a6e6ac` |
| 16 Sign In | [PNG](screenshots/16-sign-in.png) | `300655e5b8334b6da7c5ac090f27b139` |
| 17 Required Consent | [PNG](screenshots/17-required-consent.png) | `ab77df59915b4ddda6e6b4915a975de2` |
| 18 Address Book | [PNG](screenshots/18-address-book.png) | `7e074497047645d1afbc793f1a879c9c` |
| 19 Simple Product Details | [PNG](screenshots/19-simple-product-details.png) | `75a9fa14124e46ee91c5daf7609950e5` |
| 20 Simple Quantity - Add to Cart | [PNG](screenshots/20-simple-quantity-add-to-cart.png) | `1659b32d3f304cb5aa7bf2c0e3d8c433` |
| 21 Simple Quantity - Buy Now | [PNG](screenshots/21-simple-quantity-buy-now.png) | `412d3e0b4ec54d2abb61026adfa418cd` |
| 22 Notifications | [PNG](screenshots/22-notifications.png) | `f41d9a02ec57464d8900345ac66cca3d` |

## Interpretation

The repository's [Buyer design](../design-buyer.md), owning feature specs and actual controllers take precedence over generated imagery and service claims. Remote output can invent badges, pricing metadata, guarantees or controls; review notes identify the corrections and any unresolved drift. A pictured state is not verified API behavior or a completed feature acceptance criterion.

## Flutter implementation adoption — 2026-10-28

The 22 selected references now inform the current Buyer presentation: Home/Notifications/Account shell navigation, Messages/Cart/Terms utilities, stacked Cart/Shops pages, no Home Product quick-add, and a quantity-first sheet for simple and variant Product purchases. Existing page flows, API contracts and server authorities remain. Cart/Checkout/Order/voucher and account/communication screens were updated within their existing routes. Raw `design-system.stitch.json` remains unadopted; existing Buyer tokens and Material typography govern. Final independent tests, visual review, accessibility and device acceptance remain pending. See the linked implementation report for the reference-to-source map.

These references cover the main commerce journey and representative supporting screens. They do not claim a separate design for every existing route, error state or responsive size. Local PNGs remain usable if remote file URLs expire; use the recorded project/screen IDs to retrieve fresh metadata. The project link is a convenience URL constructed from the returned project ID.
