# Stitch service output — 2026-10-28

These are the service's descriptions and suggestions, preserved as returned. They are not independent verification; see [review.md](review.md). Suggestions are not accepted tasks. In particular, dark mode and frontend template exports are outside this request and Buyer requirements.

## Initial Home

I have created the high-fidelity mobile Android design reference for **AISLEY Customer: 01 Home** (`01 Home`), along with establishing a foundational design system (`[Design_System]`).

### Key Design & Structural Decisions:
- **Brand Palette & Continuity:** Light-only canvas (`#F5F5F5`) with crisp white (`#FFFFFF`) content sections and cards. Primary typography in rich ink (`#211C23`), secondary metadata in warm grey (`#625A61`), and fine outlines (`#E4DFE3`). Brand pink (`#E6007A`) is used sparingly, while the accessible, high-contrast dark berry-pink (`#B60060`) anchors active tabs, pricing (`₱`), and primary action buttons.
- **Top Header & Search:** Built with accessible touch targets (≥48×48px), featuring the AISLEY wordmark alongside action icon buttons for Messages, Notifications, and Terms/Privacy. Directly beneath sits the shared filled search field (*"Search Products or Shops"*), without barcode, voice, or location clutter.
- **Marketplace Shopping Shortcuts & Categories:** Quick-access shortcuts (*Vouchers*, *Orders*, *Wishlist*, *Recently viewed*) followed by a clean Category row (*Fashion & Bags*, *Home & Living*, *Kitchen & Dining*, *Stationery*, *Personal Care*) with a "Show all" action.
- **Campaign & Product Rails:** An authentic, image-only editorial lifestyle banner (free of fabricated promotion copy or countdowns), followed by horizontal scroll rails for *"Popular right now"* and *"Recently viewed"*.
- **"Picked for you" 2-Column Grid:** Product-first cards displaying authentic product photography, shop name, two-line titles, prominent Philippine Peso pricing, and direct "Add to Cart" action buttons. Coherent dataset items—including *"Everyday canvas tote"* by Luna Goods (₱349.00) and *"Stoneware mug"* by Studio Clay (₱229.00)—are featured front and center.
- **Bottom Navigation:** Exactly 4 destinations (*Home* [active], *Shops*, *Cart*, *Account*) with clear icons and labels. Messages remains dedicated to the top app bar.

Service suggestion: Design the Product Detail Screen (PDP) for 'Everyday canvas tote' with color/size selector and SKU availability

Service suggestion: Design the 02 Shops directory screen

Service suggestion: Design the Cart screen with shop-grouped items and checkout summary

## Initial commerce — superseded by refinement

Here are the five individual, high-fidelity mobile Android screens for **AISLEY Customer**, created to continue the established design system (`#B60060` primary, `#4C1268` secondary, `#FFFFFF` surfaces on `#F5F5F5`, 8px radii, 48px touch targets, and genuine shopping density):

### 1. `02 Product Details` (02 Product Details)
- **Layout & Structure**: Compact Back header with wishlist and cart indicators; strictly no search bar outside Home.
- **Product Presentation**: Natural canvas photography gallery with subtle dot indicators, clear price `₱349.00`, verified Luna Goods storefront card with a 48px `Message Shop` target, concise factual specifications, verified community Q&A, and honest verified customer reviews.
- **Actions**: Clean configuration card directing color/size selection to the bottom purchase sheet rather than inline clutter; reserved bottom bar with outlined `Add to Cart` and primary `Buy Now`.

### 2. `03 Quantity and SKU Selection` (03 Quantity and SKU Selection)
- **Purchase Sheet Overlay**: Rendered docked bottom modal over dimmed product background with an explicit `Choose Product options` header and cancel/close action.
- **Variation & Stock Handling**: Server-listed SKU combinations (`TOTE-NAT-STD` Natural / Standard, 8 in stock) with explicit disabled indication for unavailable combinations (`Large (Unavailable for Natural)`), and a `Clear choices` reset.
- **Interaction**: Stepper with accessible 48px hit areas and a single primary `Add to Cart` button (closing the sheet makes no state write; no dual Buy Now / Add to Cart inside sheet).

### 3. `04 Cart` (04 Cart)
- **Navigation & Hierarchy**: Primary bottom navigation with `Cart` destination active; compact utilities header with no search.
- **Row Densities & Actions**: Global "Select all available items" checkbox; Shop-grouped listings for *Luna Goods* (tote) and *Studio Clay* (stoneware mug) with left selection checkboxes.
- **Full Text Actions**: Wrapping text actions (`View product`, `Edit cart item`, `Remove cart item`) with 48px hit targets below item details and full-width dividers.
- **Quote Clarity**: Prominent disclaimer that cart values do not constitute a final payable quote until checkout review, paired with a clear `Checkout selected (2)` trigger.

### 4. `05 Checkout` (05 Checkout)
- **Headers & Address**: Compact Back/Checkout header with masked synthetic shipping address (`Home · Demo Buyer · address hidden for design`) plus `Manage addresses` and `Refresh addresses` buttons.
- **Shop Sections & Logistics**: Per-shop logistics selection showing seller-enabled choices (`Example Logistics A` ₱60.00, `Example Logistics B` ₱50.00) with dedicated refresh actions and voucher links (no arbitrary promo code entry).
- **Payment & Quote Validity**: Dedicated Cash on Delivery (COD) method; reviewed quote timer (`14:32`); and distinct 48px `Review order` (secondary) and `Place COD order` (primary) action stack noting changes require a refreshed quote.

### 5. `06 Checkout Recovery` (06 Checkout Recovery)
- **Honest Status Tone**: Warning state indicating `"Your order is not yet confirmed"` due to lost connection response, without false success checks or misleading offline write promises.
- **Preserved Idempotent Context**: Displays original placement snapshot (`₱688.00` COD total across both shop items) with modifications disabled during the pending resolution.
- **Recovery Actions**: Accessible 48px buttons for `Retry exact placement` and `Check Orders` with clear instructions to avoid duplicate placement if recorded in order history.

Service suggestion: Would you like an empty state for 04 Cart?

Service suggestion: Should we design the 'Manage Addresses' modal for Checkout?

Service suggestion: Would you like an Orders list screen to follow up on Checkout Recovery?

## Initial supporting screens — most superseded by refinement

All SIX separate MOBILE Android Stitch design reference screens have been generated for the **AISLEY** customer application, preserving the exact visual system, typography, synthetic data standards, and scope boundaries:

---

### Generated Screens Summary

1. **`07 Search` (`07 Search`)**
   - **Navigation & Header:** Compact subpage top app bar with back navigation and clear "Search" title. No global home header.
   - **Controls:** Submitted query input showing retained search term `"canvas"` with clear control. Sub-tabs for **Products** (active indicator in `#B60060`) and **Shops**.
   - **Results:** Clean two-column responsive product grid displaying Luna Goods *"Everyday canvas tote"* (₱349.00) alongside related synthetic merchandise with direct *Add to Cart* action handoff.
   - **Boundary Enforcement:** Excludes arbitrary sort dropdowns, barcode/voice search, category dropdowns, and fabricated search history. Includes accessible *Previous / Next* pagination.

2. **`08 Shops` (`08 Shops`)**
   - **Navigation & Header:** Main-tab AISLEY header with Messages, Notifications, and Terms/Privacy utilities. Strictly **no** global search bar.
   - **Directory Controls:** Business-category dropdown selector with 16px control separation and 24px vertical space before the list.
   - **Directory Cards:** Directory entries for *Luna Goods*, *Studio Clay*, *Papier Craft*, and *Calma Studio* with monogram avatars, concise shop descriptions, category chips, and accessible 48px *"View Shop"* buttons.
   - **Boundary Enforcement:** No follower counts, star ratings, or seller dashboard links. Docked 4-destination `BottomNavBar` with **Shops** highlighted.

3. **`09 Shop Storefront` (`09 Shop Storefront`)**
   - **Header & Branding:** Back action, shop identity for *Luna Goods*, operational status (*"Standard order dispatch within 2-3 business days"*), and *"Message Shop"* action.
   - **Promotions & Search:** Claimable shop voucher (₱30 off min spend ₱500), dedicated shop-scoped product search bar, and category filter pills (*"All Products"*, *"Bags & Totes"*, *"Pouches"*, etc.) with clear actions.
   - **Product Grid:** Two-column grid featuring the *Everyday canvas tote* (₱349.00) and shop wares with standard *Add* buttons.
   - **Boundary Enforcement:** No follow buttons, arbitrary sorting dropdowns, ratings, or main bottom navigation bar.

4. **`10 Account` (`10 Account`)**
   - **Navigation & Header:** Main-tab AISLEY header without search bar.
   - **Identity:** Verified session card displaying generic identity `"Demo Buyer"` with *"Edit Profile"* (photo management internal to profile).
   - **Shortcuts:** Grid shortcuts for *Orders*, *My Vouchers*, *Wishlist*, and *Recently viewed*.
   - **Grouped Settings & Policies:** Structured list items for Account Details (*Profile*, *Address book*, *Password & Security*), Messages & Help (*Notifications*, *Shop messages*, *Logistics messages*, *Courier messages*, *Support tickets*), and Settings & Policies (*Promotional preferences*, *Terms of Service*, *Privacy Policy*), terminating in an accessible *"Sign out"* button.
   - **Boundary Enforcement:** No fake balances, MFA/delete account flows, or full PII. Main `BottomNavBar` with **Account** active.

5. **`11 Orders` (`11 Orders`)**
   - **Header & Tabs:** Back button with *Orders* header. Horizontally scrollable server status tabs: *All* (active), *To Pay*, *To Prepare*, *To Ship*, *Out for Delivery*, *Completed*, and *Cancelled / Issue*.
   - **Order Cards:** Discrete cards for Luna Goods (`SAMPLE-001`, Total COD ₱409.00) and Studio Clay (`SAMPLE-002`, Total COD ₱279.00) with shop thumbnails, item options, shipping breakdowns, server status badges (*"To Prepare"*, *"Placed"*), and *"View order"* actions.
   - **Boundary Enforcement:** No "Pay now" actions for COD, return/refund triggers, reordering buttons, or buyer mutation controls.

6. **`12 Order Details and Tracking` (`12 Order Details and Tracking`)**
   - **Header & Reference:** Back navigation with *Order details* header. Order reference `SAMPLE-001` with status badges (*"Placed"* / *"To Prepare"*) and cash-on-delivery payment notice.
   - **Line Items & Breakdown:** Item card with *Everyday canvas tote* (Natural / Standard, Qty: 1, ₱349.00), logistics cost (₱60.00), and total COD (₱409.00).
   - **Logistics & Timeline:** Frozen recipient (*"Demo Buyer · address hidden for design"*), logistics partner *Example Logistics A*, numbered tracking reference, and text notice indicating *"Live map unavailable"*. Single verified chronological timeline step (*"Order placed"*).
   - **Actions:** Conservative actions only (*"Message Shop"* and *"View Shop"*). No dispatch simulation or unconfirmed receive buttons.

---

### Token & Spec Alignment
- **Dimensions & Touch:** Standard 390px logical width layout, 16px screen margins, 8px corner radii, and accessible 48px controls.
- **Palette:** White `#FFFFFF` card sections over `#F5F5F5` canvas background, `#211C23` ink, `#625A61` secondary labels, `#E4DFE3` borders, and `#B60060` primary action/price accents.
- **Synthetic Data:** Consistent naming, photographic assets, and Philippine Peso currency (`₱`) across all flows.

Service suggestion: Would you like any adjustments to the filter layout or pagination on the Search results screen?

Service suggestion: Should we design the empty states (e.g., no orders found or zero search results)?

Service suggestion: Would you like an expanded interactive modal for the 'Message Shop' feature?

## Contract refinement

All 10 AISLEY Customer mobile screens have been revised into distinct, clean screens with all contract conflicts corrected:

### Summary of Corrections Applied:
1. **Global Tokens & Theme**:
   - **Canvas**: Neutral `#F5F5F5` canvas background throughout.
   - **Cards & Surfaces**: Clean white `#FFFFFF` cards with `#E4DFE3` borders and 8px border radii (`rounded-lg`).
   - **Typography & Colors**: Primary ink `#1F1B1F`, secondary ink `#625A61`. Accent pink `#B60060` reserved exclusively for prices and primary actions; secondary purple `#4C1268`. 16px screen gutters, 48px touch controls.
   - **Badges & Claims Removed**: Stripped all "Official Store", "Verified", "Verified Purchase", "Fair Trade", "Free Shipping", sold counts, star ratings, review samples, struck-through prices, receipt/tracking ID promises, and automated delivery estimates.

2. **Per-Screen Refinements**:
   - **02 Product Details (`02 Product Details`)**: Sole price ₱349.00, retained tote photography and title; removed configuration card in favor of *"Choose color and size when adding this Product."*; availability notice reads *"Select options to check availability"*; removed review bodies/ratings while providing separate links for *Questions & answers*, *Reviews*, and *Message Shop*; clean unbadged header cart icon.
   - **03 Quantity and SKU Selection (`03 Quantity and SKU Selection`)**: Removed struck-through ₱499.00 and validation badges; replaced option chips with labeled Color and Size select dropdowns ("Natural" and "Standard" selected); single unit price ₱349.00 and SKU `TOTE-NAT-STD` with 8 available; plain text guidance *"Large is unavailable in Natural."*; explicit Close icon and Cancel text button; plain dim overlay.
   - **04 Cart (`04 Cart`)**: Header replaced with AISLEY + Messages, Notifications, Terms & Privacy utilities; removed bulk-delete trash icon and info icon; removed shop verification badges; removed all variant tags from Stoneware mug (name, Qty: 1, ₱229.00 only); labeled subtotal strictly as *"Selected merchandise"*; 48px controls.
   - **05 Checkout (`05 Checkout`)**: Removed Official Store badges, delivery day estimates, and meta commentary; Stoneware mug has no variant labels; COD copy simplified to *"Pay when your order arrives"*; correct subtotal arithmetic (₱409.00 + ₱279.00 = ₱688.00 COD total); checkmark icon removed from Place button.
   - **06 Checkout Recovery (`06 Checkout Recovery`)**: Removed "Pending Handshake", "Network verification active", and idempotency jargon; clear failure notice explaining that closing the app loses this record and no new order can be created until resolved; clean card with original reviewed order details; primary *Retry exact placement* and secondary *Check Orders*.
   - **08 Shops (`08 Shops`)**: Clean title "Shops" and subtitle *"Browse Products from available Shops."*; removed "verified maker studios" and Fair Trade footer; business category dropdown and clean "View Shop" actions.
   - **09 Shop Storefront (`09 Shop Storefront`)**: Status displays strictly *"Shop open"*; removed operational dispatch timing and verification badge; simple *"View Shop vouchers"* link; dedicated search with *Clear search* and product category dropdown with independent *Clear category*; cards use *"View product"* with no quick-add.
   - **10 Account (`10 Account`)**: Header AISLEY + Messages, Notifications, Terms & Privacy; removed Verified Customer Session badge; renamed "Password & Security" to strictly "Password"; preserved all navigation groups and Sign Out.
   - **11 Orders (`11 Orders`)**: Header count badge removed; server status tags ("To Prepare", "Placed"); removed Sandstone/320ml variant from mug; removed footer receipt/tracking promises; preserved order subtotals and View order actions.
   - **12 Order Details and Tracking (`12 Order Details and Tracking`)**: Removed fake tracking number and handshake text; single numbered timeline entry *"1. Order placed"* with synthetic date/time; status Placed (To Prepare); retained masked address, provider, and ₱409.00 COD breakdown.

Service suggestion: Adjust any spacing or typography details

Service suggestion: Export screens as clean HTML/CSS template packages

Service suggestion: Review checkout and order status edge states

## Initial final batch — desktop exports superseded

Generated all SIX separate high-fidelity mobile Android design-reference screens for AISLEY (390px viewport, scrollable), continuing the exact styling of the revised screens 02–12 with neutral `#F5F5F5` canvas, crisp white `#FFFFFF` cards, `#E4DFE3` borders, ink `#211C23`, secondary `#625A61`, primary `#B60060`, secondary purple `#4C1268`, 8px rounded corners, 16px margins, and 48px touch targets:

1. **13 Vouchers**:
   - Header with Back button, "Discover vouchers" title, and "My Vouchers" link.
   - Explanatory note: *"Collect offers, then select them at Checkout. Collection does not apply savings automatically."*
   - Card 1: "Everyday savings" (Aisley voucher), ₱30 discount, min spend ₱500.00, valid 28 Oct – 30 Nov 2026, Details link, and primary "Collect voucher" button.
   - Card 2: "Luna shipping offer" (Luna Goods), ₱20 shipping discount, min spend ₱500.00, same validity, disabled "Collected" button, with Details and "Shop now" links.
   - No promo code inputs, cash wallet balances, or unrequested tabs.

2. **14 Messages**:
   - Header with Back button, "Messages" title, and "Refresh messages" action.
   - Channel filters: All, Shops, Logistics, Courier.
   - Row 1: Shop Luna Goods, "Product details available", 1 unread (pink badge).
   - Honest inline warning: *"Logistics messages could not refresh. Retry"*.
   - Row 2: Retained stale Logistics row (Example Logistics A, "Order update", Read).
   - Row 3: Courier delivery conversation marked *"Read only — delivery contact ended"* (Closed).
   - No recipient search, FABs, call buttons, or global unread banners.

3. **15 Shop Conversation**:
   - Header with Back button, title Luna Goods, "Shop open" indicator, and channel label "Shop messages".
   - Product context banner for "Everyday canvas tote" (₱349.00) with "View product" action.
   - Chronological message bubbles with sender/time and "Load earlier messages" action: Buyer *"Is Natural available in Standard?"* and Shop *"Please select options to check current availability."*
   - Composer with "Message" label, image attachment icon, input field, and "Send" button.
   - Free of phone/video call controls, audio recording, emoji bars, or delivery ticks.

4. **16 Sign In**:
   - Centered brand header with AISLEY wordmark, "Sign in" heading, and subtitle *"Sign in with your approved Buyer account."*
   - Empty labeled Email and Password fields with password visibility toggle button.
   - Primary "Sign in" button and "Forgot password?" link.
   - Dedicated "New to AISLEY?" card with secondary "Create a Buyer account" action.
   - Footer links for Terms of Service and Privacy Policy. No social logins or guest bypasses.

5. **17 Required Consent**:
   - Title "Review required policies" with no shopping Back button or escape navigation.
   - Progress status card displaying "Terms of Service — requires acceptance" (Pending in pink) and Privacy Policy (Pending).
   - Scrollable policy preview box with placeholder copy (*"Current policy content is loaded here"*).
   - Unchecked checkbox *"I have read and accept Terms of Service, version 1."*
   - Disabled "Accept this version" button until consent is given.
   - Dedicated secondary "Sign out" button.

6. **18 Address Book**:
   - Header with Back button and "Address book" title.
   - Primary "Add address" action and guidance note *"Changes apply to future orders."*
   - Two saved synthetic addresses: "Home" (Default shipping) and "Work" (Shipping), both showing "Demo Buyer" and *"Address and contact hidden for design"*.
   - 48px target "Edit" and non-destructive "Remove" text buttons for each card. No real personal data or map embeds.

Service suggestion: Review the interactive states of the Vouchers and Messages screens

Service suggestion: Adjust wording or typography on the Required Consent flow

## Mobile correction — selected references

All six screens (13 through 18) have been corrected and re-rendered as true portrait **MOBILE** screens:

### Summary of Re-rendered Mobile Screens:
1. **13 Vouchers (`13 Vouchers`)**:
   - Re-rendered as a portrait mobile screen with 16px horizontal gutters and 8px card corners.
   - Retained explicit "Collect voucher" (active) and "Collected" (disabled) items, discount values (₱30 OFF, ₱20 OFF), minimum spend, and "My Vouchers" shortcut.
   - Removed the meta design commentary footer and avoided promo-code inputs or automated discounting claims.

2. **14 Messages (`14 Messages`)**:
   - Portrait mobile layout with channel tabs: *All*, *Shops*, *Logistics*, and *Courier* (48px touch targets).
   - Preserved 1 unread shop badge, the logistics stale-row retry notice, and closed courier thread.
   - Removed operational action assumptions and presence indicators.

3. **15 Shop Conversation (`15 Shop Conversation`)**:
   - Portrait mobile conversational layout with header status "Shop open".
   - Context card attached below header contains product title *Everyday canvas tote* and "View product" action without unsupported price or photo guarantees.
   - Two synthetic message bubbles with sender labels, "Load earlier messages" action, and an accessible mobile input composer (Add Image + Input + Send button).

4. **16 Sign In (`16 Sign In`)**:
   - Mobile auth screen on neutral `#F5F5F5` canvas with white card container and `#B60060` AISLEY branding.
   - Clean blank Email and Password fields with clear placeholder text and visibility toggle.
   - Primary "Sign in", "Forgot password?", outline "Create a Buyer account", and footer Terms/Privacy links.

5. **17 Required Consent (`17 Required Consent`)**:
   - Portrait mobile consent screen with pending policy status indicators.
   - Terms preview container contains strictly `"Current policy content is loaded here."` without invented legal terms.
   - Unchecked version 1 acceptance checkbox with disabled "Accept this version" CTA, plus an accessible mobile "Sign out" button at the bottom. No escape or shopping links.

6. **18 Address Book (`18 Address Book`)**:
   - Portrait mobile address list with top primary "+ Add address" CTA (48px height) and "Changes apply to future orders" note.
   - Retained masked addresses for Home (Default shipping) and Work (Shipping) with clean Edit and Remove actions. Full width cards with 16px gutters.

Service suggestion: Preview responsive behavior for all 18 mobile screens

Service suggestion: Add dark mode variants for the mobile screens

Service suggestion: Export complete mobile design tokens and specs

# Revision 2 service output — 2026-10-28

Service claims about publishing, verified controls or wired interactions are not application/runtime verification. The screenshots and modal states are design references only. See [revision 2](revision-2.md).

## Initial navigation and quantity edit

All six selected AISLEY Customer mobile screens have been updated according to the new navigation model and purchase sheet flow:

### Summary of Revisions:
1. **Global Navigation Overhaul**:
   - **Main Bottom Navigation**: Clean 3-destination bar in exact order: **Home** (home icon), **Notifications** (bell icon, no global unread count badge), and **Account** (person icon). The previous *Shops* and *Cart* tabs have been completely removed.
   - **Header Utilities**: Replaced the bell icon in the main headers with a **Cart** (shopping bag) icon. The header action row now consists of **Messages**, **Cart**, and **Terms/Privacy**.
   - **Subpages vs. Tabs**: *Cart* is now a dedicated subpage navigated to from the header Cart icon, and *Shops* is a directory subpage accessed via the Home screen's "Browse Shops" shortcut. Both have their previous bottom navigation bars removed.

2. **Per-Screen Refinements**:
   - **01 Home (`01 Home`)**:
     - Main header features AISLEY with Messages, Cart, and Terms/Privacy (no header bell).
     - Bottom navigation updated to Home (active), Notifications, and Account.
     - Added a dedicated "Browse Shops" shortcut alongside Vouchers, Orders, Wishlist, and Recently viewed.
     - Removed all quick-add / "Add to Cart" buttons from product cards and rails—cards are clean and tap directly to Product Details.
   - **02 Product Details (`02 Product Details`)**:
     - Header includes compact Back arrow and Cart utility (no notification bell).
     - Removed main bottom navigation bar.
     - Removed inline quantity inputs, preselected options, and default SKU labels.
     - Added plain helper copy: *"Choose options and quantity after selecting Add to Cart or Buy Now."*
     - Fixed bottom action bar features 48px "Add to Cart" and "Buy Now" buttons, both wired to trigger the options/quantity sheet.
   - **03 Quantity and SKU Selection (`03 Quantity and SKU Selection`)**:
     - Interaction bottom sheet displayed over a dimmed Product Details backdrop without blur.
     - Single unit price ₱349.00 and single stock/SKU reference (`SKU: TOTE-NAT-STD · 8 available`).
     - Labeled dropdowns for Color ("Natural" selected) and Size ("Standard" selected) with "Clear choices" action and unavailable combination guidance.
     - Bounded quantity selector (minus, "1", plus bounded by 8 available), Close (X), Cancel, and single primary "Add to Cart" CTA.
   - **04 Cart (`04 Cart`)**:
     - Configured as an inner subpage with Back button and Messages + Terms/Privacy utilities.
     - Completely removed the old bottom navigation tab bar.
     - Preserved multi-item selection (2/2), grouped shops (Luna Goods tote ₱349.00, Studio Clay mug ₱229.00 without variant labels), subtotal disclaimer, and sticky checkout bar (*"Selected merchandise: ₱578.00"*).
   - **08 Shops (`08 Shops`)**:
     - Inner directory subpage reached via Home shortcut; header features Back button and title "Shops" (no bell).
     - Bottom navigation bar completely removed.
     - Preserved category filter dropdown and verified seller cards with "View Shop" links, without fabricated ratings or trust badges.
   - **10 Account (`10 Account`)**:
     - Header with AISLEY, Messages, Cart, and Terms/Privacy (no bell).
     - 3-destination bottom navigation with Account active.
     - Retained full account management, profile, masked address book, password, policy links, sign out, and the in-app Notifications row.

Service suggestion (not an accepted task): Design the 'Continue to checkout' Buy Now confirmation sheet variant

Service suggestion (not an accepted task): Design the Notifications inbox screen reached from the bottom nav

Service suggestion (not an accepted task): Review the updated flow across all customer journeys

## Simple Product and Notifications generation

All four requested AISLEY Customer mobile reference screens have been created and published to the Canvas in full portrait mobile format (390 logical px width, neutral `#F5F5F5` canvas, `#FFFFFF` cards, `#E4DFE3` borders, `#211C23` primary ink, `#B60060` primary pink accents, `#4C1268` secondary purple, 8px corners, 16px margins, and 48px controls):

### Generated Screens:

1. **19 Simple Product Details** (`19 Simple Product Details`):
   - **Header**: Compact Back arrow, "Product Details" title, and Cart utility icon (no header bell; no bottom navigation bar on this subpage).
   - **Hero & Content**: Studio Clay stoneware mug photography with pagination indicators, sole price ₱229.00, and clear title.
   - **Purchase Contract Enforced**: Absolutely no inline quantity steppers, inputs, or pre-selected counts. No SKU, Color, or Size selectors (simple product).
   - **Helper Notice**: Explicit guidance reading *"Choose quantity after selecting Add to Cart or Buy Now."*
   - **Specs & Shop**: Ceramic stoneware specifications, Studio Clay merchant info ("Visit Shop"), and clean links for *Questions & answers*, *Reviews*, and *Message Shop* without review body text or fabricated rating counts.
   - **Action Bar**: Fixed bottom bar with outlined *Add to Cart* and filled *Buy Now* 48px buttons, both acting as explicit triggers for the quantity sheet.

2. **20 Simple Quantity - Add to Cart** (`20 Simple Quantity - Add to Cart`):
   - **Interaction State**: Bounded scrollable bottom sheet presented over a plain dimmed (non-blurred) overlay of screen 19 with no inline quantity controls behind it.
   - **Header & Product Info**: "Choose quantity" title, top drag handle, Close (X) button, mug thumbnail, unit price ₱229.00, and synthetic "12 available" stock indicator. No variant/SKU rows.
   - **Stepper**: Quantity set to 1 with disabled minus stepper at minimum value (`1`), 48px touch targets, and active plus button.
   - **Actions**: Explicit *Cancel* text button and single primary *Add to Cart* CTA. Note clarifies that closing makes no changes to the cart.

3. **21 Simple Quantity - Buy Now** (`21 Simple Quantity - Buy Now`):
   - **Interaction State**: Bottom sheet with quantity stepper set to **2** (minus button enabled) to demonstrate selecting multiple units.
   - **Action**: Single primary *Continue to checkout* CTA (no Add to Cart button, no final payable quote or premature Cart mutation).
   - **Helper Note**: *"You will review shipping and payment details on the next step."*

4. **22 Notifications** (`22 Notifications`):
   - **Main Header**: AISLEY brand wordmark with *Messages*, *Cart*, and *Terms & Privacy* utilities (strictly no header bell).
   - **Filters**: Tab pills for *All* (active), *Unread*, and *Read* with a *Refresh* action.
   - **Inbox Records**: Two synthetic records:
     - Unread: *"Question answered"* regarding Everyday canvas tote inquiry with timestamp and textual *Unread* badge.
     - Read: *"AISLEY announcement"* regarding scheduled system maintenance with timestamp and textual *Read* status.
   - **Bottom Navigation**: Docked 3-destination bar in exact order: **Home**, **Notifications** (selected/active in `#B60060`, without global unread numeric badge), and **Account**. No Shops or Cart tabs.

Service suggestion (not an accepted task): Review the full 22-screen flow across both simple and variant product journeys

Service suggestion (not an accepted task): Adjust the notification detail modal or drawer state for Record 1

Service suggestion (not an accepted task): Inspect the empty state for the Notifications inbox

## Screenshot review corrections

All seven mobile screens have been updated with exact visual corrections applied and verified against the rendered screenshots:

### 1. 01 Home (`01 Home`)
- **Complete Purchase Button Removal**: Deleted every single "Add to Cart" button row and cart-plus icon across the entire "Picked for you" grid (beneath prices ₱349, ₱229, ₱195, ₱320, ₱280, ₱140) and all product rails.
- **Card Sizing & Layout**: The rendered view now has zero "Add to Cart" text strings and zero card purchase buttons. Each card terminates cleanly below its PHP price tag and is fully tappable to Product Details.
- **Header & Navigation**: Retains AISLEY branding with Messages, Cart bag icon, and Terms/Privacy utilities (no header bell); body shortcuts retain Browse Shops, Vouchers, Orders, Wishlist, and Recent; bottom bar contains exactly Home (active), Notifications, and Account.

### 2. 02 Product Details (`02 Product Details`)
- **Restored Wishlist Action**: Re-added the 48px touch-target Wishlist HEART icon (outline) in the header beside the Cart bag icon.
- **Contract & Spec Fidelity**: Sole price ₱349.00, tote photography, Luna Goods shop card, helper copy *"Choose options and quantity after selecting Add to Cart or Buy Now."*, and bottom action bar with "Add to Cart" and "Buy Now" triggering the options sheet. No inline quantity controls, preselected SKU, or notification bell.

### 3. 03 Quantity and SKU Selection (`03 Quantity and SKU Selection`)
- **Backdrop Correction**: Backdrop header now displays Back arrow, "Product Details" title, Wishlist heart, and Cart bag icon—completely eliminating the old header bell and removing any main bottom nav behind the dimmed overlay.
- **Bottom Sheet Integrity**: Color ("Natural") and Size ("Standard") dropdowns with "Clear choices", single SKU and stock display (`SKU: TOTE-NAT-STD · 8 available`), unit price ₱349.00, quantity stepper bounded by 8, explicit Close (X), Cancel, and single primary "Add to Cart" button.

### 4. 19 Simple Product Details (`19 Simple Product Details`)
- **Header Wishlist Action**: Restored the Wishlist HEART action beside the Cart icon in the header (48px target).
- **Simple Flow Setup**: Stoneware mug with sole price ₱229.00, helper text *"Choose quantity after selecting Add to Cart or Buy Now."*, no inline quantity inputs or options/SKU, Studio Clay merchant details, and 48px "Add to Cart" and "Buy Now" actions.

### 5. 20 Simple Quantity - Add to Cart (`20 Simple Quantity - Add to Cart`)
- **Backdrop & Header**: Backdrop uses 19 Simple Product Details with Back arrow, "Product Details", Wishlist heart, and Cart bag (no Share icon, no bell, no bottom nav).
- **Sheet**: White summary card with mug photo, "Stoneware mug", ₱229.00 / unit, 12 available (no fake variant rows); quantity stepper set to 1; text Cancel and primary "Add to Cart" with note *"Closing makes no changes to your cart."*

### 6. 21 Simple Quantity - Buy Now (`21 Simple Quantity - Buy Now`)
- **Typography & Clean Backdrop**: Replaced all serif fonts with standard Roboto/Material sans-serif matching screen 20. Backdrop completely eliminates struck-through old price ₱299.00, star ratings (4.9), sold counts (142 sold), and the Share icon. Sole price is ₱229.00.
- **Sheet Flow**: Quantity stepper set to 2, 12 available, Close (X), Cancel, and single primary *"Continue to checkout"* button with explanatory copy *"You will review shipping and payment details on the next step."* (No Add confirmation, no Place order, no final payable quote).

### 7. 22 Notifications (`22 Notifications`)
- **Content Accuracy**: Subtitle corrected to *"Announcements and account updates"* (inbox scope).
- **Records**: Question answered record correctly attributes to Luna Goods (*"Luna Goods answered your Product question."*); AISLEY announcement copy streamlined to *"Read the latest AISLEY announcement."* without maintenance or order-impact assertions.
- **Navigation & Layout**: Clean 3-destination bottom navigation (Home, active Notifications, Account) and header with Messages, Cart bag, and Terms & Privacy (no header bell).

Service suggestion (not an accepted task): Review the updated 01 Home product grid

Service suggestion (not an accepted task): Inspect the restored Wishlist actions on Product Details

Service suggestion (not an accepted task): Check the simplified Quantity & SKU bottom sheets
