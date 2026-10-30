# Public catalogue image delivery — 2026-10-29

The Buyer loads returned public catalogue image URLs as bytes. The source inspection
at Laravel `850a73b43b3c28b058fd1502269e4ed125ca31ed` confirms that
`ProductSummaryResource`, `ProductDetailResource` and `ProductImageUrl` return the
visibility-gated `/api/v1/product-media/{media}` URL for scanned uploaded images.
Legacy media with no MIME instead uses `MediaUrl::from`; the current
`DemoProductCatalog` explicitly supplies HTTPS `images.unsplash.com` photos through
that projection. Source inspection is separate from deployed API acceptance.

Buyer previously rejected those supplied legacy photographs before requesting them,
so the Product cards and gallery showed placeholders. The public loader now accepts:

- Existing allow-listed media paths at the exact configured API origin:
  `/api/v1/product-media/`, `/api/v1/product-description-assets/`,
  `/api/v1/product-review-images/`, `/api/v1/homepage-advertisement-images/`.
- Returned HTTPS photos at the exact `images.unsplash.com` host, port 443, with no
  user information or fragment. This host is supported by inspected catalogue data;
  arbitrary remote hosts, plain HTTP, raw storage paths and constructed URLs remain
  unavailable and use the accessible image fallback.

External photos use only the credential-free public client. Browser Fetch omits
cookies and rejects redirects; native transport also disables redirect following.
No bearer or private-media lease is supplied. The loader requires an image MIME
response, keeps bounded short-lived public memory caching, and uses existing read
deadlines/backoff. Private media retains its existing trusted API origin/path policy.
Images stay within the existing card/gallery bounds and preserve the selected fit.
Changing an image URL or repository replaces its pending image state; loading,
failure and corrupt-image states retain an accessible fallback.

This change requires no Laravel endpoint, schema, provider configuration or seed.
Any other legacy storage/provider URL remains a separate backend delivery decision.
Controlled deployed catalogue/image exchange, installed Android and TalkBack gates
remain open; regression and screenshot results belong to the dated task reports.
