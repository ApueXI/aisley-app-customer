"""Synthetic identities/catalog for browser layout checks; no auth reaches Laravel."""
import base64
import json
import os
import time
from pathlib import Path

ID = '11111111-1111-4111-8111-111111111111'
ROOT = Path(__file__).resolve().parents[1]


def fixture(feature, operation):
    data = json.loads((ROOT / 'docs/api/examples' / (feature + '.json')).read_text())
    return next(op['response_example'] for op in data['operations'] if op['id'] == operation)


def bootstrap_script():
    policies = {}
    for kind in ['terms_of_service', 'privacy_policy']:
        body = fixture('policy-viewing-consent', 'op-084')
        body['data']['type'] = kind
        policies['/api/v1/platform/policies/' + kind] = body
    # Installed before Flutter starts, including after reload. Unknown API calls
    # fail locally; no synthetic identity/credential can reach a real backend.
    return """
      window.buyerInitialResponses = %s;
      const startupFetch = window.fetch;
      window.fetch = function(url, options) {
        const path = new URL(String(url), window.location.href).pathname;
        if (path.startsWith('/api/v1/')) {
          const body = window.buyerInitialResponses[path];
          return Promise.resolve(new Response(JSON.stringify(body ?? {message:'Synthetic unavailable'}),
            {status:body ? 200 : 404,headers:{'Content-Type':'application/json'}}));
        }
        return startupFetch.apply(this, arguments);
      };
    """ % json.dumps(policies)


def check_shopping(call, prefix, script, wait_text, resize, *, matrix=True):
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
    for feature in ['logistics-messaging', 'courier-messaging', 'notifications']:
        for op in json.loads((ROOT / 'docs/api/examples' / (feature + '.json')).read_text())['operations']:
            if op['method'] == 'GET' or op['path'].endswith('/read'):
                path = op['path']
                for parameter in ['conversation', 'notification', 'order']:
                    path = path.replace('{' + parameter + '}', ID)
                responses[path] = op['response_example']
    responses['/api/v1/customer/cart/items'] = fixture('view-cart', 'op-026')
    responses['/api/v1/customer/checkout/quote'] = fixture('checkout-order', 'op-029')
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
          let body = window.buyerSyntheticResponses[path];
          if (path.endsWith('/checkout/quote')) {
            const input = JSON.parse(options.body);
            body = structuredClone(body);
            body.data.expiresAt = new Date(Date.now() + 900000).toISOString();
            body.data.mode = input.mode;
            body.data.address.id = input.address_id;
            const item = body.data.groups[0].items[0];
            if (input.mode === 'cart') {
              body.data.groups[0].items = input.cart_item_ids.map(id => ({...item, cartItemId:id}));
            } else {
              item.productId = input.buy_now.product_id;
              item.variantId = input.buy_now.variant_id;
              item.quantity = input.buy_now.quantity;
            }
          }
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
    wait_text('Search Products or Shops')
    if matrix:
        for route, expected in [('/', 'Search Products or Shops'), ('/shops', 'Search Shops'),
                                ('/search?q=sample&mode=products', 'Search'),
                                ('/shops/' + slug, 'Apply filters'), ('/products/' + ID, 'Add to Cart'),
                                ('/cart', 'Your Cart'), ('/orders', 'Orders'),
                                ('/orders/' + ID, 'Order'), ('/account', 'Your account'),
                                ('/account/profile', 'Profile'),
                                ('/products/' + ID + '/questions', 'Product questions'),
                                ('/products/' + ID + '/reviews', 'Product reviews'),
                                ('/messages/shops/' + ID, 'Refresh conversation'),
                                ('/messages/logistics/' + ID, 'Refresh conversation'),
                                ('/messages/courier/' + ID, 'Refresh conversation'),
                                ('/notifications', 'Notifications'),
                                ('/support-tickets/' + ID, 'Refresh conversation')]:
            print('CHECK: synthetic ' + route, flush=True)
            script('window.location.hash = ' + json.dumps(route) + ';')
            wait_text(expected)
            for width, height in [(320, 640), (390, 844), (600, 960), (800, 1280), (640, 320), (960, 600), (1024, 768), (1440, 900)]:
                resize(width, height)
                wait_text(expected)
                assert script('return document.documentElement.scrollWidth <= window.innerWidth;')

    def click(label):
        for _ in range(20):
            if script("const b = Array.from(document.querySelectorAll('[role=button]')).find(e => (e.innerText || e.getAttribute('aria-label') || '').trim() === " + json.dumps(label) + "); if (b) {b.click(); return true;} return false;"):
                return
            dimensions = script('return {width:window.innerWidth,height:window.innerHeight};')
            call(prefix + '/actions', {'actions': [{'type':'wheel','id':'journey-scroll','actions':[
                {'type':'scroll','origin':'viewport','x':dimensions['width']//2,'y':dimensions['height']//2,
                 'deltaX':0,'deltaY':400,'duration':150}]}]})
        raise AssertionError('Shopper action must be reachable: ' + label)

    def capture(name):
        directory = os.environ.get('BUYER_SCREENSHOT_DIR')
        if directory:
            destination = Path(directory)
            destination.mkdir(parents=True, exist_ok=True)
            time.sleep(.5)
            (destination / (name + '.png')).write_bytes(base64.b64decode(call(prefix + '/screenshot')))

    for width, height in [(390,844),(1440,900)]:
        resize(width, height)
        script("window.location.hash = '/';")
        wait_text('Search Products or Shops')
        wait_text('Explore categories')
        capture('home-' + str(width))
        # Web Enter submits the exact search query into route history.
        field = call(prefix + '/elements', {'using':'css selector','value':'input[aria-label="Search Products or Shops"]'})
        assert field, 'Marketplace search must be labeled.'
        element = next(iter(field[0].values()))
        call(prefix + '/element/' + element + '/click', {})
        call(prefix + '/element/' + element + '/value', {'text':'sample\ue007'})
        wait_text('for “sample”')
        call(prefix + '/back', {})
        wait_text('Search Products or Shops')
        script("window.location.hash = '/products/" + ID + "';")
        wait_text('Add to Cart')
        capture('product-' + str(width))
        click('Add to Cart')
        wait_text('Added to Cart')
        click('Buy Now')
        wait_text('Review order')
        click('Review order')
        wait_text('Review your COD order')
        wait_text('Place COD order')
        capture('checkout-' + str(width))
        click('Place COD order')
        wait_text('Place COD order?')
        click('Cancel')
        script("window.location.hash = '/cart';")
        wait_text('Your Cart')
        capture('cart-' + str(width))
        # Require a distinct labeled checkbox in Chromium's accessibility tree.
        # Keep a selection that was already made in the earlier journey.
        nodes = call(prefix + '/goog/cdp/execute', {'cmd':'Accessibility.getFullAXTree','params':{}})['nodes']
        checkbox = next((node for node in nodes if node.get('role',{}).get('value','').lower() == 'checkbox'
                         and node.get('name',{}).get('value','').startswith('Select ')), None)
        assert checkbox, 'Cart selection must remain accessible.'
        checked = next((p['value']['value'] for p in checkbox.get('properties',[]) if p['name'] == 'checked'), False)
        if checked not in [True, 'true']:
            model = call(prefix + '/goog/cdp/execute', {'cmd':'DOM.getBoxModel',
                         'params':{'backendNodeId':checkbox['backendDOMNodeId']}})['model']['border']
            x, y = round((model[0]+model[4])/2), round((model[1]+model[5])/2)
            call(prefix + '/actions', {'actions':[{'type':'pointer','id':'cart-selection','parameters':{'pointerType':'mouse'},
                 'actions':[{'type':'pointerMove','origin':'viewport','x':x,'y':y},
                            {'type':'pointerDown','button':0},{'type':'pointerUp','button':0}]}]})
        wait_text('Checkout selected (1)')
        capture('cart-' + str(width))
        click('Checkout selected (1)')
        wait_text('Review order')
        click('Review order')
        wait_text('Review your COD order')
        wait_text('Place COD order')
        script("window.location.hash = '/messages/shops/" + ID + "';")
        wait_text('Refresh conversation')
        capture('messages-' + str(width))
    calls = script('return window.buyerSyntheticCalls;')
    assert sum(item['path'].endswith('/cart/items') for item in calls) == 2
    assert sum(item['path'].endswith('/checkout/quote') for item in calls) == 4
    assert not any(item['path'].endswith('/checkout/place') for item in calls)
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
    coverage = 'phone/tablet/desktop layouts and shopping' if matrix else 'mobile/desktop purchase journeys'
    print('PASS: synthetic browser identity, ' + coverage + ', Enter/search history, Add to Cart, accessible selected Cart, explicit quote and cancelled placement, sign-out; all API traffic intercepted.')
