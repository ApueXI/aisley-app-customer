# AISLEY Customer — Google Stitch references

Recorded 2026-10-28. Design exploration only: no Flutter source, frontend implementation, backend, dependency or production configuration changes.

- Stitch project: [AISLEY Customer](https://stitch.withgoogle.com/projects/3960147693568073492)
- Project resource: `projects/3960147693568073492` (private).
- Initial reusable design-system resource: `assets/209b92e003bd4111b4e38fd6ede0e1ce`.
- Inspected Buyer source: `8c04148b5ff00841b75b1794137f25599abcc4bc`.

## Start here

| File | Purpose |
| --- | --- |
| [DESIGN.md](DESIGN.md) | Buyer brand, source inspection, synthetic data, boundaries and state requirements |
| [screen-map.md](screen-map.md) | References mapped to existing routes/specs; unillustrated routes explicitly identified |
| [manifest.json](manifest.json) | Project/screen/file IDs, tool-returned references, screenshot dimensions and checksums |
| [requests.json](requests.json) | Exact generation/refinement requests for reproducibility |
| [review.md](review.md) | Screenshot review, corrected generation drift and remaining limitations |
| [service-notes.md](service-notes.md) | Stitch's returned descriptions/suggestions, preserved as service output |
| [design-system.stitch.json](design-system.stitch.json) | Initial raw generated design-system snapshot; not an adopted Flutter theme |

## Screenshots

The manifest and gallery below identify the selected local PNG for each reference. Downloaded screenshots use Stitch's returned file resource through MCP `download_file`; protected download URLs were not fetched directly. Images contain synthetic examples and masked address information. No application HTML, CSS or generated frontend code is imported.

| Reference | Screenshot | Stitch screen ID |
| --- | --- | --- |
| 01 Home | [PNG](screenshots/01-home.png) | `5f4992cd856746368cd242d54aeb0e24` |
| 02 Product Details | [PNG](screenshots/02-product-details.png) | `1b09e7f670a242afb5cfa8c63b9260c9` |
| 03 Quantity and SKU Selection | [PNG](screenshots/03-quantity-and-sku-selection.png) | `4889189d79d74815a197813134d73052` |
| 04 Cart | [PNG](screenshots/04-cart.png) | `735ac03b78db4307bc3264d537bd6789` |
| 05 Checkout | [PNG](screenshots/05-checkout.png) | `f83961bc1f834506859a2b322c4eddb9` |
| 06 Checkout Recovery | [PNG](screenshots/06-checkout-recovery.png) | `63121b93171643f29205bdb38abd1239` |
| 07 Search | [PNG](screenshots/07-search.png) | `24c2ad0947474511b2906663c19b3d48` |
| 08 Shops | [PNG](screenshots/08-shops.png) | `484abba3fcf8463495aa9b0b2b26031a` |
| 09 Shop Storefront | [PNG](screenshots/09-shop-storefront.png) | `1463794dc9064f65bc406e338874f442` |
| 10 Account | [PNG](screenshots/10-account.png) | `6b5efc71f28343d8bca9744e55ae3f66` |
| 11 Orders | [PNG](screenshots/11-orders.png) | `6f7f56cfd0e84812a13a2ff48c1362cd` |
| 12 Order Details and Tracking | [PNG](screenshots/12-order-details-and-tracking.png) | `cd160c3efe4c4485a2c17b0763b087f3` |
| 13 Vouchers | [PNG](screenshots/13-vouchers.png) | `896b978baee2431abef1d5656b5efc20` |
| 14 Messages | [PNG](screenshots/14-messages.png) | `80ffda80b4bb4cbb804a81cfd4ce5341` |
| 15 Shop Conversation | [PNG](screenshots/15-shop-conversation.png) | `df35b726ad624541809f4f39c6a6e6ac` |
| 16 Sign In | [PNG](screenshots/16-sign-in.png) | `300655e5b8334b6da7c5ac090f27b139` |
| 17 Required Consent | [PNG](screenshots/17-required-consent.png) | `ab77df59915b4ddda6e6b4915a975de2` |
| 18 Address Book | [PNG](screenshots/18-address-book.png) | `7e074497047645d1afbc793f1a879c9c` |

## Interpretation

The repository's [Buyer design](../design-buyer.md), owning feature specs and actual controllers take precedence over generated imagery and service claims. Remote output can invent badges, pricing metadata, guarantees or controls; review notes identify the corrections and any unresolved drift. A pictured state is not verified API behavior or a completed feature acceptance criterion.

These references cover the main commerce journey and representative supporting screens. They do not claim a separate design for every existing route, error state or responsive size. Local PNGs remain usable if remote file URLs expire; use the recorded project/screen IDs to retrieve fresh metadata. The project link is a convenience URL constructed from the returned project ID.
