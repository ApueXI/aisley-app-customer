"""Synthetic identities/catalog for browser layout checks; no auth reaches Laravel."""
import json
from pathlib import Path

ID = '11111111-1111-4111-8111-111111111111'
ROOT = Path(__file__).resolve().parents[1]


def fixture(feature, operation):
    data = json.loads((ROOT / 'docs/api/examples' / (feature + '.json')).read_text())
    return next(op['response_example'] for op in data['operations'] if op['id'] == operation)


def check_shopping(call, prefix, script, wait_text):
    identity = {'id': ID, 'displayName': 'Synthetic browser Buyer', 'avatarUrl': None,
                'role': 'customer', 'status': 'active'}
    responses = {
        '/api/v1/customer/auth/login': {'message': 'Synthetic sign-in', 'customer': identity,
                                       'token': 'synthetic-browser-session'},
        '/api/v1/customer/auth/me': {'customer': identity},
        '/api/v1/policy-consent/status': {'data': {'policies': [], 'all_required_accepted': True}},
        '/api/v1/customer/auth/logout': {'message': 'Synthetic sign-out'},
    }
    for path, feature, op in [
        ('customer/home', 'customer-homepage', 'op-047'),
        ('customer/shops', 'browse-shop', 'op-021'),
        ('customer/products/search', 'search', 'op-019'),
        ('customer/cart', 'view-cart', 'op-025'),
        ('customer/orders', 'order-status', 'op-032'),
        ('customer/orders/' + ID, 'order-status', 'op-033'),
        ('customer/orders/' + ID + '/tracking', 'order-status', 'op-034'),
        ('customer/account', 'account-management', 'op-007'),
        ('customer/addresses', 'address-book', 'op-015'),
        ('customer/wishlist', 'wishlist', 'op-039'),
        ('customer/recently-viewed', 'recently-viewed-items', 'op-042'),
        ('customer/conversations', 'chat-messaging', 'op-057'),
        ('customer/conversations/' + ID, 'chat-messaging', 'op-059'),
        ('customer/conversations/' + ID + '/messages', 'chat-messaging', 'op-060'),
        ('customer/conversations/' + ID + '/read', 'chat-messaging', 'op-062'),
        ('customer/support-tickets', 'support-tickets', 'op-077'),
        ('customer/support-tickets/' + ID, 'support-tickets', 'op-079'),
        ('customer/support-tickets/' + ID + '/read', 'support-tickets', 'op-081'),
        ('products/' + ID, 'view-product', 'op-024'),
        ('products/' + ID + '/questions', 'product-qa', 'op-049'),
        ('products/' + ID + '/reviews', 'product-review-ratings', 'op-051'),
    ]:
        responses['/api/v1/' + path] = fixture(feature, op)
    shop = responses['/api/v1/customer/shops']['items'][0]
    slug = shop['slug'] = 'synthetic-shop'
    responses['/api/v1/customer/shops/' + slug] = fixture('browse-shop', 'op-023')
    responses['/api/v1/customer/shops/' + slug]['data']['slug'] = slug
    responses['/api/v1/customer/shops/' + slug + '/products'] = fixture('browse-shop', 'op-022')
    responses['/api/v1/customer/wishlist/status'] = {'data': {ID: False}}
    responses['/api/v1/customer/recently-viewed/' + ID] = {
        'data': {'productId': ID, 'lastViewedAt': '2026-10-04T00:00:00Z'}}
    # All API paths are intercepted once the synthetic identity is introduced.
    script('window.buyerSyntheticResponses = ' + json.dumps(responses) + ';')
    script("""
      window.buyerSyntheticCalls = [];
      const previousFetch = window.fetch;
      window.fetch = function(url, options) {
        const location = new URL(String(url));
        if (location.pathname.startsWith('/api/v1/')) {
          const path = location.pathname;
          window.buyerSyntheticCalls.push({path, method: options?.method ?? 'GET'});
          const body = window.buyerSyntheticResponses[path];
          return Promise.resolve(new Response(JSON.stringify(body ?? {message:'Synthetic unavailable'}),
            {status: body ? 200 : 404, headers:{'Content-Type':'application/json'}}));
        }
        return previousFetch.apply(this, arguments);
      };
    """)
    script("window.location.hash = '/login';")
    wait_text('Sign in with your approved Buyer account.')
    for label, value in [('Email', 'synthetic@example.invalid'), ('Password', 'Synthetic123')]:
        elements = call(prefix + '/elements', {'using': 'css selector', 'value': 'input[aria-label="' + label + '"]'})
        assert elements, 'Synthetic sign-in input must be accessible: ' + label
        element = next(iter(elements[0].values()))
        call(prefix + '/element/' + element + '/click', {})
        call(prefix + '/element/' + element + '/value', {'text': value})
    script("Array.from(document.querySelectorAll('[role=button]')).find(e => e.innerText.trim() === 'Sign in')?.click();")
    wait_text('Search Products and Shops')
    for route, expected in [('/', 'Search Products and Shops'), ('/shops', 'Search Shops'),
                            ('/search?q=sample&mode=products', 'Search'),
                            ('/shops/' + slug, 'Apply filters'), ('/products/' + ID, 'Add to Cart'),
                            ('/cart', 'Your Cart'), ('/orders', 'Orders'),
                            ('/orders/' + ID, 'Order'), ('/account', 'Your account'),
                            ('/account/profile', 'Profile'),
                            ('/products/' + ID + '/questions', 'Product questions'),
                            ('/products/' + ID + '/reviews', 'Product reviews'),
                            ('/messages/shops/' + ID, 'Refresh conversation'),
                            ('/support-tickets/' + ID, 'Refresh conversation')]:
        print('CHECK: synthetic ' + route, flush=True)
        script('window.location.hash = ' + json.dumps(route) + ';')
        wait_text(expected)
        for width, height in [(320, 640), (600, 960), (800, 1280), (640, 320), (960, 600), (1280, 800)]:
            call(prefix + '/window/rect', {'width': width, 'height': height})
            wait_text(expected)
            assert script('return document.documentElement.scrollWidth <= window.innerWidth;')
    calls = script('return window.buyerSyntheticCalls;')
    assert all(not item['path'].endswith('/merge') for item in calls)
    script("window.location.hash = '/account';")
    wait_text('Your account')
    # Scroll the actual Flutter viewport to the deliberate sign-out control.
    for _ in range(12):
        if script("return Array.from(document.querySelectorAll('[role=button]')).some(e => (e.innerText || e.getAttribute('aria-label') || '').trim() === 'Sign out');"):
            break
        dimensions = script('return {width:window.innerWidth,height:window.innerHeight};')
        call(prefix + '/actions', {'actions': [{'type': 'wheel', 'id': 'buyer-scroll',
             'actions': [{'type': 'scroll', 'origin': 'viewport', 'x': dimensions['width'] // 2,
                          'y': dimensions['height'] // 2, 'deltaX': 0, 'deltaY': 600, 'duration': 150}]}]})
    # Deliberate sign-out uses only the intercepted synthetic logout.
    assert script("const button = Array.from(document.querySelectorAll('[role=button]')).find(e => (e.innerText || e.getAttribute('aria-label') || '').trim() === 'Sign out'); if (button) button.click(); return !!button;"), 'Sign-out control must remain reachable.'
    wait_text('Sign out?')
    script("Array.from(document.querySelectorAll('[role=button]')).filter(e => e.innerText.trim() === 'Sign out').at(-1)?.click();")
    wait_text('Sign in with your approved Buyer account.')
    print('PASS: synthetic browser identity, authenticated shopping phone/tablet/landscape layouts, account forms, Q&A/reviews, message/support composers and sign-out; all API traffic intercepted.')
