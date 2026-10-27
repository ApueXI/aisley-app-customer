# Screen coverage and contract map

Stitch screen IDs, file resource names and local screenshots are recorded in [manifest.json](manifest.json). Numbered names are reference labels, not new Flutter routes. Each generated design is a draft for review; it grants no new API capability.

| Reference | Existing route / flow | Feature authority |
| --- | --- | --- |
| 01 Home | `/` | [Homepage](../features/customer/customer-homepage/spec.md) |
| 02 Product Details | `/products/:id` | [Product](../features/customer/view-product/spec.md) |
| 03 Quantity and SKU Selection | Purchase sheet from Product/listing; no independent route | [Product](../features/customer/view-product/spec.md), [Cart](../features/customer/view-cart/spec.md) |
| 04 Cart | `/cart`; separate Cart item editor | [Cart](../features/customer/view-cart/spec.md) |
| 05 Checkout | `/checkout` with current reviewed quote | [Checkout](../features/customer/checkout-order/spec.md), [Vouchers](../features/customer/voucher-usage/spec.md) |
| 06 Checkout Recovery | `/checkout` with an unresolved placement | [Checkout](../features/customer/checkout-order/spec.md), [G12](../references/integration-gaps.md) |
| 07 Search | `/search` with mode/query/page | [Search](../features/customer/search/spec.md) |
| 08 Shops | `/shops` | [Browse Shop](../features/customer/browse-shop/spec.md) |
| 09 Shop Storefront | `/shops/:slug` | [Browse Shop](../features/customer/browse-shop/spec.md), [Shop context](../features/customer/chat-messaging/spec.md) |
| 10 Account | `/account` | [Account](../features/customer/account-management/spec.md) |
| 11 Orders | `/orders` | [Order status](../features/customer/order-status/spec.md) |
| 12 Order Details and Tracking | `/orders/:order` | [Order status](../features/customer/order-status/spec.md) |
| 13 Vouchers | `/vouchers`, with link to `/account/vouchers` | [Vouchers](../features/customer/voucher-usage/spec.md), [collection contract](../api/voucher-collection.md) |
| 14 Messages | `/messages` | [Shop](../features/customer/chat-messaging/spec.md), [Logistics](../features/customer/logistics-messaging/spec.md), [Courier](../features/customer/courier-messaging/spec.md) |
| 15 Shop Conversation | `/messages/shops/:id` or eligible first-message flow | [Shop messages](../features/customer/chat-messaging/spec.md) |
| 16 Sign In | `/login` | [Authentication](../features/customer/customer-auth/spec.md), [navigation gate](../features/customer/customer_verify_auth/spec.md) |
| 17 Required Consent | `/consent` | [Shared policies](../features/shared/policy-viewing-consent/spec.md) |
| 18 Address Book | `/account/addresses` | [Address Book](../features/customer/address-book/spec.md) |

## Related screens not separately illustrated in this pass

Existing routes also include registration/email OTP, approval, session retry, recovery, policy current/history, profile/photo, password/email-code confirmation, promotional preferences, address create/edit/pin, Wishlist/history, voucher detail/wallet, committed checkout result, separate channel inboxes/Logistics/Courier threads, notifications/detail, Q&A, reviews/composer and support tickets/create/thread. They retain their contracts and existing Flutter implementation. A representative Account or Messages screenshot does not constitute a design for each of these routes or each error state.

No new screen, navigation destination, endpoint, dependency or capability is adopted by this inventory. For eventual work, read each owning specification and actual controller before refining an unillustrated route. In particular, Order modification/cancellation must retain server capabilities; a generic action in a generated image cannot authorize either.

## States to carry into any later implementation

| Area | Required treatment beyond the happy-path image |
| --- | --- |
| Session | Checking, recoverable storage/network retry, signed out, pending/rejected/suspended/inactive denial, renewed consent; no shopping flash |
| Discovery | Loading, valid empty, malformed/unavailable, image fallback, missing campaign title/link, stale refresh and separate page retry |
| Options / Cart | Incomplete/impossible/out-of-stock choice, stock changes, variant merge, pending edits, removal confirmation, uncertain additive write and Check Cart |
| Checkout | No address, no shipping option, multiple-provider choice, quote loading/expiry/input change/coverage loss, voucher conflict, placement confirmation and exact unresolved recovery |
| Orders | Missing historical thumbnail, terminal/action change, direct assigned-to-delivered event projection, stale detail, unavailable map, scoped denial |
| Vouchers | Collecting, collected, automatic availability, ineligible reason, expired/capacity/customer limit, uncertain collection and reviewed savings |
| Messages | Channel-specific partial failure/retry, unknown or stale unread total, read-only relation, older history/new-message cue, interrupted send/media cleanup |
| Consent | Unchecked exact-version confirmation, disabled acceptance, stale publication, partial acceptance, failure/retry and explicit sign-out |
| Addresses | Empty, loading/retry, destructive confirmation; edits do not change placed Orders; map permission/provider failure preserves valid manual address entry |

Static screenshots do not verify these states. [Buyer verification](../verification.md) and [integration gaps](../references/integration-gaps.md) retain their existing open gates.
