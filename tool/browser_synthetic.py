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


def check_shopping(call, prefix, script, wait_text, resize, *, matrix=True, shipping_selection=False, list_recovery=False, upload_recovery=False, accessibility=False, accessibility_route=None):
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
    responses['/api/v1/customer/checkout/logistics-options'] = fixture('checkout-order', 'op-096')
    if shipping_selection:
        scenarios = json.loads((ROOT / 'docs/api/examples/shipping-selection-scenarios.json').read_text())['scenarios']
        responses['/api/v1/customer/checkout/logistics-options'] = next(s['expected']['body'] for s in scenarios if s['name'] == 'multiple-provider-options')
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
          const requestBody = options?.body && typeof options.body === 'string' ? JSON.parse(options.body) : {};
          window.buyerSyntheticCalls.push({path, method: options?.method ?? 'GET', selections:requestBody.logistics_selections ?? null});
          let body = window.buyerSyntheticResponses[path];
          if (path.endsWith('/checkout/logistics-options')) {
            body.data.address.id = JSON.parse(options.body).address_id;
          }
          if (path.endsWith('/checkout/quote')) {
            const input = JSON.parse(options.body);
            body = structuredClone(body);
            body.data.expiresAt = new Date(Date.now() + 900000).toISOString();
            body.data.mode = input.mode;
            body.data.address.id = input.address_id;
            const selection = input.logistics_selections?.[0];
            if (selection) {
              const provider = window.buyerSyntheticResponses['/api/v1/customer/checkout/logistics-options'].data.groups[0].options.find(o => o.organizationId === selection.logistics_organization_id);
              body.data.groups[0].shippingQuote = {serviceable:true,logisticsOrganizationId:provider.organizationId,logisticsBusinessName:provider.businessName,routeStatus:provider.routeStatus,shippingFee:provider.shippingFee};
              for (const totals of [body.data.groups[0].totals, body.data.summary]) {
                totals.shippingFee = provider.shippingFee;
                totals.payable = provider.shippingFee === '120.00' ? '220.00' : '200.00';
              }
            }
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
    routes = [
        ('/', 'Search Products or Shops'),
        ('/shops', 'Search Shops'),
        ('/search?q=sample&mode=products', 'Search'),
        ('/shops/' + slug, 'Apply filters'),
        ('/products/' + ID, 'Add to Cart'),
        ('/cart', 'Your Cart'),
        ('/checkout', 'Choose Buy Now from a Product or select Cart items to start checkout.'),
        ('/orders', 'Orders'),
        ('/orders/' + ID, 'Order'),
        ('/account', 'Your account'),
        ('/account/profile', 'Email, role and account status are managed by AISLEY.'),
        ('/account/password', 'Change password'),
        ('/account/preferences', 'Promotional messages'),
        ('/account/addresses', 'Address book'),
        ('/account/addresses/new', 'Add address'),
        ('/account/wishlist', 'Wishlist'),
        ('/account/recently-viewed', 'Recently viewed'),
        ('/products/' + ID + '/questions', 'Product questions'),
        ('/products/' + ID + '/reviews', 'Product reviews'),
        ('/messages/shops/' + ID, 'Refresh conversation'),
        ('/messages/logistics/' + ID, 'Refresh conversation'),
        ('/messages/courier/' + ID, 'Refresh conversation'),
        ('/notifications', 'Notifications'),
        ('/notifications/' + ID, 'Notification'),
        ('/support-tickets', 'Support tickets'),
        ('/support-tickets/new', 'New support ticket'),
        ('/support-tickets/' + ID, 'Refresh conversation'),
    ]
    matrix_routes = [
        item for item in routes
        if item[0] in {
            '/', '/shops', '/search?q=sample&mode=products', '/shops/' + slug,
            '/products/' + ID, '/cart', '/orders', '/orders/' + ID,
            '/account', '/account/profile', '/products/' + ID + '/questions',
            '/products/' + ID + '/reviews', '/messages/shops/' + ID,
            '/messages/logistics/' + ID, '/messages/courier/' + ID,
            '/notifications', '/support-tickets/' + ID,
        }
    ]
    if matrix:
        for route, expected in matrix_routes:
            print('CHECK: synthetic ' + route, flush=True)
            script('window.location.hash = ' + json.dumps(route) + ';')
            wait_text(expected)
            for width, height in [(320, 640), (390, 844), (600, 960), (800, 1280), (640, 320), (960, 600), (1024, 768), (1440, 900)]:
                resize(width, height)
                wait_text(expected)
                assert script('return document.documentElement.scrollWidth <= window.innerWidth;')

    def click(label):
        for _ in range(20):
            if script("const b = Array.from(document.querySelectorAll('[role=button],[role=link],button,a')).find(e => {const name = e.getAttribute('aria-label') || e.innerText || e.title || ''; const lines = name.split(/[\\n,]/).map(value => value.trim()); const wanted = " + json.dumps(label) + "; return lines.includes(wanted) || name.trim() === wanted || name.trim().startsWith(wanted + ',') || name.trim().startsWith(wanted + ' ');}); if (b && b.getAttribute('aria-disabled') !== 'true') {b.click(); return true;} return false;"):
                return
            dimensions = script('return {width:window.innerWidth,height:window.innerHeight};')
            call(prefix + '/actions', {'actions': [{'type':'wheel','id':'journey-scroll','actions':[
                {'type':'scroll','origin':'viewport','x':dimensions['width']//2,'y':dimensions['height']//2,
                 'deltaX':0,'deltaY':400,'duration':150}]}]})
        if accessibility:
            candidates = script("""
              const wanted = """ + json.dumps(label) + """;
              return Array.from(document.querySelectorAll('[role],[aria-label],button,a')).map(e => {
                const r = e.getBoundingClientRect();
                return {role:e.getAttribute('role'),label:e.getAttribute('aria-label'),text:(e.innerText || '').slice(0,120),
                  size:[r.width,r.height]};
              }).filter(e => ((e.label || '') + ' ' + e.text).includes(wanted)).slice(0,8);
            """)
            body = script('return document.body.innerText.slice(0,500);')
            raise AssertionError('Shopper action must be reachable: ' + label + '; candidates: ' + json.dumps(candidates) + '; page: ' + json.dumps(body))
        raise AssertionError('Shopper action must be reachable: ' + label)

    def choose_shipping(name):
        for _ in range(20):
            found = script("const r = Array.from(document.querySelectorAll('[role=radio]')).find(e => (e.innerText || e.getAttribute('aria-label') || '').includes(" + json.dumps(name) + ")); if (r) {r.click(); return true;} return false;")
            if found:
                time.sleep(.2)
                return
            dimensions = script('return {width:window.innerWidth,height:window.innerHeight};')
            call(prefix + '/actions', {'actions': [{'type':'wheel','id':'provider-scroll','actions':[
                {'type':'scroll','origin':'viewport','x':dimensions['width']//2,'y':dimensions['height']//2,
                 'deltaX':0,'deltaY':300,'duration':100}]}]})
            time.sleep(.1)
        raise AssertionError('Shipping provider radio is unavailable: ' + name)

    def capture(name):
        directory = os.environ.get('BUYER_SCREENSHOT_DIR')
        if directory:
            destination = Path(directory)
            destination.mkdir(parents=True, exist_ok=True)
            time.sleep(.5)
            (destination / (name + '.png')).write_bytes(base64.b64decode(call(prefix + '/screenshot')))

    def back_to_account():
        for _ in range(3):
            current = script('return location.hash.slice(1);')
            if current == '/account' or not current.startswith('/account/'):
                break
            action = 'Cancel' if current in {
                '/account/profile', '/account/password', '/account/preferences',
                '/account/addresses/new',
            } else 'Back'
            click(action)
            time.sleep(.2)
        current = script('return location.hash.slice(1);')
        if current != '/account':
            raise AssertionError('Account Back/Cancel did not return to /account: ' + current)
        wait_text('Your account')

    def open_accessibility_route(route, expected):
        if route.startswith('/account/'):
            current = script('return location.hash.slice(1);')
            if current.startswith('/account/'):
                back_to_account()
            elif current != '/account':
                script("window.location.hash = '/account';")
                wait_text('Your account')
            destinations = {
                '/account/profile': 'Profile',
                '/account/password': 'Password',
                '/account/preferences': 'Promotional messages',
                '/account/addresses': 'Address book',
                '/account/addresses/new': 'Address book',
                '/account/wishlist': 'Wishlist',
                '/account/recently-viewed': 'Recently viewed',
            }
            destination = destinations.get(route)
            if destination:
                click(destination)
                if route == '/account/addresses/new':
                    wait_text('Address book')
                    click('Add address')
        else:
            script('window.location.hash = ' + json.dumps(route) + ';')
            wait_text(expected)

    accessibility_report = None
    if accessibility:
        failures = []
        journeys = []
        viewports = (
            [(320, 640), (390, 844), (640, 320), (1440, 900)]
            if accessibility_route is not None
            else [(320, 640), (390, 844), (640, 320), (1440, 900)]
        )
        accessibility_routes = matrix_routes
        if accessibility_route is not None:
            accessibility_routes = [item for item in routes if item[0] == accessibility_route]
            if not accessibility_routes:
                raise ValueError('Unknown accessibility route: ' + accessibility_route)
        for route, expected in accessibility_routes:
            print('CHECK: browser accessibility ' + route, flush=True)
            open_accessibility_route(route, expected)
            journey = {'route': route, 'viewports': []}
            for width, height in viewports:
                stable = 0
                previous = -1
                for _ in range(20):
                    count = script('return window.buyerSyntheticCalls.length;')
                    stable = stable + 1 if count == previous else 0
                    if stable >= 3:
                        break
                    previous = count
                    time.sleep(.2)
                before = script('return window.buyerSyntheticCalls.length;')
                resize(width, height)
                stable = 0
                previous = -1
                for _ in range(20):
                    count = script('return window.buyerSyntheticCalls.length;')
                    stable = stable + 1 if count == previous else 0
                    if stable >= 3:
                        break
                    previous = count
                    time.sleep(.2)
                after = script('return window.buyerSyntheticCalls.length;')
                if after != before:
                    failures.append({'route': route, 'viewport': [width, height], 'type': 'request-on-resize',
                                     'requestsBefore': before, 'requestsAfter': after,
                                     'requests': script('return window.buyerSyntheticCalls.slice(' + str(before) + ');')})
                if (width, height) == (640, 320):
                    capture('accessibility-landscape-before-scroll-' + (route.strip('/').replace('/', '-') or 'home'))
                call(prefix + '/actions', {'actions': [{'type':'wheel','id':'accessibility-scroll','actions':[
                    {'type':'scroll','origin':'viewport','x':width//2,'y':height//2,
                     'deltaX':0,'deltaY':-4000,'duration':100}]}]})
                time.sleep(.15)
                wait_text(expected)
                target_signatures = set()
                stable_scrolls = 0
                previous_signature = None
                unique_controls = set()
                target_sizes = {}
                for scroll_step in range(40):
                    metrics = script("""
                  const selector = '[role=button],[role=checkbox],[role=radio],[role=switch],[role=tab],[role=link],[role=textbox],[role=combobox],button,input,textarea,select';
                  const controls = Array.from(document.querySelectorAll(selector)).map(el => {
                    const wrapper = el.closest('flt-semantics');
                    const rect = (el.tagName.toLowerCase() === 'textarea' && wrapper ? wrapper : el).getBoundingClientRect();
                    const labelledBy = (el.getAttribute('aria-labelledby') || '').split(/\\s+/).filter(Boolean)
                      .map(id => document.getElementById(id)?.innerText || '').join(' ');
                    const wrapperLabel = wrapper?.getAttribute('aria-label') ||
                      (wrapper?.getAttribute('aria-labelledby') || '').split(/\\s+/).filter(Boolean)
                        .map(id => document.getElementById(id)?.innerText || '').join(' ') || wrapper?.innerText || '';
                    const label = el.getAttribute('aria-label') || labelledBy || wrapperLabel ||
                      (el.labels ? Array.from(el.labels).map(node => node.innerText).join(' ') : '') ||
                      el.innerText || el.title || el.placeholder || el.value || '';
                    const style = getComputedStyle(el);
                    return {role: el.getAttribute('role') || el.tagName.toLowerCase(), label: label.trim(),
                      tag: el.tagName.toLowerCase(), className: String(el.className || ''),
                      id: el.id || '',
                      disabled: !!el.disabled, semanticsProxy: !!el.closest('flt-semantics'),
                      parent: el.parentElement ? el.parentElement.tagName.toLowerCase() + '.' + String(el.parentElement.className || '') : '',
                      html: el.outerHTML.slice(0,500),
                      wrapper: wrapper ? {role:wrapper.getAttribute('role'),label:wrapper.getAttribute('aria-label'),
                        text:wrapper.innerText,html:wrapper.outerHTML.slice(0,500)} : null,
                      width: rect.width, height: rect.height, top: rect.top, bottom: rect.bottom,
                      visible: style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0};
                  }).filter(item => item.visible && !(
                    item.tag === 'textarea' && item.disabled && item.semanticsProxy
                  ));
                  return {controls, scrollWidth: document.documentElement.scrollWidth, viewportWidth: innerWidth};
                """)
                    if metrics['scrollWidth'] > metrics['viewportWidth']:
                        signature = ('horizontal-overflow',)
                        if signature not in target_signatures:
                            failures.append({'route': route, 'viewport': [width, height], 'type': signature[0],
                                             'scrollWidth': metrics['scrollWidth']})
                            target_signatures.add(signature)
                    for item in metrics['controls']:
                        unique_controls.add((item['role'], item['label']))
                        if item['top'] < 0 or item['bottom'] > height:
                            continue
                        identity = item['role'] + ':' + item['tag'] + ':' + item['label']
                        previous_size = target_sizes.get(identity)
                        if previous_size is None or (
                            item['width'] >= previous_size['width'] and
                            item['height'] >= previous_size['height']
                        ):
                            target_sizes[identity] = item
                        elif item['width'] > previous_size['width'] or item['height'] > previous_size['height']:
                            target_sizes[identity] = {
                                **previous_size,
                                'width': max(item['width'], previous_size['width']),
                                'height': max(item['height'], previous_size['height']),
                            }
                    signature = tuple((item['label'], round(item['top']), round(item['bottom']))
                                      for item in metrics['controls'])
                    stable_scrolls = stable_scrolls + 1 if signature == previous_signature else 0
                    if stable_scrolls >= 2:
                        break
                    previous_signature = signature
                    call(prefix + '/actions', {'actions': [{'type':'wheel','id':'accessibility-scroll','actions':[
                        {'type':'scroll','origin':'viewport','x':width//2,'y':height//2,
                         'deltaX':0,'deltaY':64,'duration':80}]}]})
                    time.sleep(.06)
                for item in target_sizes.values():
                    if not item['label']:
                        signature = ('unnamed-control', item['role'], item['tag'], item['id'])
                        if signature not in target_signatures:
                            failures.append({'route': route, 'viewport': [width, height], 'type': signature[0],
                                             'role': item['role'], 'tag': item['tag'],
                                             'id': item['id'], 'className': item['className'],
                                             'parent': item['parent'], 'wrapper': item['wrapper']})
                            target_signatures.add(signature)
                    if item['width'] < 48 or item['height'] < 48:
                        signature = ('undersized-target', item['role'], item['label'], item['id'])
                        if signature not in target_signatures:
                            failures.append({'route': route, 'viewport': [width, height], 'type': signature[0],
                                             'role': item['role'], 'label': item['label'][:100],
                                             'size': [round(item['width'], 1), round(item['height'], 1)],
                                             'top': round(item['top'], 1), 'bottom': round(item['bottom'], 1),
                                             'id': item['id'], 'tag': item['tag'],
                                             'className': item['className'], 'parent': item['parent'],
                                             'html': item['html']})
                            target_signatures.add(signature)
                journey['viewports'].append({
                    'size': [width, height],
                    'interactiveControls': len(unique_controls),
                })
                if route.endswith('/questions'):
                    tree = call(prefix + '/goog/cdp/execute', {
                        'cmd': 'Accessibility.getFullAXTree', 'params': {}})
                    journey['browserSemantics'] = [
                        {
                            'role': node.get('role', {}).get('value'),
                            'name': node.get('name', {}).get('value'),
                            'ignored': node.get('ignored', False),
                            'properties': {
                                prop.get('name'): prop.get('value', {}).get('value')
                                for prop in node.get('properties', [])
                                if prop.get('name')
                            },
                        }
                        for node in tree.get('nodes', [])
                        if node.get('role', {}).get('value') in {
                            'button', 'textbox', 'checkbox', 'radio', 'combobox',
                        }
                        and not node.get('ignored', False)
                        and any(
                            prop.get('name') == 'focusable' and
                            prop.get('value', {}).get('value') is True
                            for prop in node.get('properties', [])
                        )
                    ]
                    if not any(
                        item['role'] == 'textbox' and item['name'] == 'Question'
                        for item in journey['browserSemantics']
                    ):
                        failures.append({
                            'route': route,
                            'type': 'missing-question-semantic-label',
                            'browserSemantics': journey['browserSemantics'],
                        })
                if (width, height) == (390, 844):
                    capture('accessibility-' + (route.strip('/').replace('/', '-') or 'home'))
                if (width, height) == (640, 320):
                    capture('accessibility-landscape-' + (route.strip('/').replace('/', '-') or 'home'))
            journeys.append(journey)

        keyboard = {'routeFilter': accessibility_route}
        if accessibility_route is None or accessibility_route == '/account/profile':
            if accessibility_route is None:
                script("window.location.hash = '/account';")
                wait_text('Your account')
                click('Profile')
                wait_text('Email, role and account status are managed by AISLEY.')
            field = call(prefix + '/elements', {
                'using': 'css selector', 'value': 'input[aria-label="First name"]'})
            if not field:
                failures.append({'route': '/account/profile', 'type': 'missing-keyboard-field'})
                keyboard.update({'tabFocusAdvanced': False, 'draftSurvivedResize': False})
            else:
                element = next(iter(field[0].values()))
                call(prefix + '/element/' + element + '/click', {})
                call(prefix + '/element/' + element + '/clear', {})
                call(prefix + '/element/' + element + '/value', {'text': 'Synthetic accessibility draft'})
                before_focus = script("""
                  const e = document.activeElement, r = e.getBoundingClientRect();
                  return {label: e.getAttribute('aria-label') || e.innerText || '', role: e.getAttribute('role'),
                    width: r.width, height: r.height, focusVisible: e.matches(':focus-visible')};
                """)
                call(prefix + '/actions', {'actions': [{'type': 'key', 'id': 'buyer-accessibility', 'actions': [
                    {'type': 'keyDown', 'value': '\ue004'}, {'type': 'keyUp', 'value': '\ue004'}]}]})
                after_focus = script("""
                  const e = document.activeElement, r = e.getBoundingClientRect();
                  return {label: e.getAttribute('aria-label') || e.innerText || '', role: e.getAttribute('role'),
                    width: r.width, height: r.height, focusVisible: e.matches(':focus-visible')};
                """)
                tab_advanced = bool(after_focus['width'] and after_focus['height']) and (
                    after_focus['label'] != before_focus['label'] or
                    after_focus['role'] != before_focus['role'])
                resize(640, 320)
                wait_text('Email, role and account status are managed by AISLEY.')
                draft_survived = script("return document.querySelector('input[aria-label=\"First name\"]')?.value === 'Synthetic accessibility draft';")
                if not tab_advanced:
                    failures.append({'route': '/account/profile', 'type': 'tab-focus-did-not-advance',
                                     'before': before_focus, 'after': after_focus})
                if not draft_survived:
                    failures.append({'route': '/account/profile', 'type': 'draft-lost-on-resize'})
                keyboard.update({
                    'tabFocusAdvanced': tab_advanced,
                    'before': before_focus,
                    'after': after_focus,
                    'draftSurvivedResize': bool(draft_survived),
                    'focusVisible': bool(after_focus['focusVisible']),
                })
                capture('accessibility-profile-keyboard-landscape')

                click('Cancel')
                wait_text('Leave this screen?')
                click('Stay')
                wait_text('Email, role and account status are managed by AISLEY.')
                first_name = call(prefix + '/elements', {
                    'using': 'css selector', 'value': 'input[aria-label="First name"]'})
                if first_name:
                    call(prefix + '/element/' + next(iter(first_name[0].values())) + '/click', {})
                retained = script("return document.querySelector('input[aria-label=\"First name\"]')?.value === 'Synthetic accessibility draft';")
                if not retained:
                    failures.append({'route': '/account/profile', 'type': 'cancel-lost-draft',
                                     'after': script("return {url:location.hash, value:document.querySelector('input[aria-label=\"First name\"]')?.value, page:document.body.innerText.slice(0,240)};")})

                call(prefix + '/back', {})
                wait_text('Leave this screen?')
                if not script("return document.body.innerText.includes('Discard the information entered in this form?');"):
                    failures.append({'route': '/account/profile', 'type': 'back-missing-discard-warning'})
                click('Stay')
                wait_text('Email, role and account status are managed by AISLEY.')
                first_name = call(prefix + '/elements', {
                    'using': 'css selector', 'value': 'input[aria-label="First name"]'})
                if first_name:
                    call(prefix + '/element/' + next(iter(first_name[0].values())) + '/click', {})
                retained = script("return document.querySelector('input[aria-label=\"First name\"]')?.value === 'Synthetic accessibility draft';")
                if not retained:
                    failures.append({'route': '/account/profile', 'type': 'cancel-lost-draft',
                                     'after': script("return {url:location.hash, value:document.querySelector('input[aria-label=\"First name\"]')?.value, page:document.body.innerText.slice(0,240)};")})
                call(prefix + '/back', {})
                wait_text('Leave this screen?')
                click('Leave')
                wait_text('Your account')

        accessibility_report = {
            'origin': 'http://localhost:8766',
            'viewports': [list(size) for size in viewports],
            'journeys': journeys,
            'routeFilter': accessibility_route,
            'keyboardAndBack': keyboard,
            'failures': failures,
            'writes': [
                item for item in script('return window.buyerSyntheticCalls;')
                if item['method'] != 'GET'
            ],
            'screenshotsDirectory': os.environ.get('BUYER_SCREENSHOT_DIR'),
        }

    if upload_recovery:
        from browser_upload_recovery import check_uploads
        check_uploads(call, prefix, script, wait_text, resize, click)
        return

    if list_recovery:
        from browser_list_recovery import check_lists
        check_lists(script, wait_text, resize, click)
        return

    for width, height in [(390,844),(1440,900)]:
        resize(width, height)
        script("window.location.hash = '/';")
        wait_text('Search Products or Shops')
        wait_text('Explore Categories')
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
        if shipping_selection:
            wait_text('Shipping provider')
            choose_shipping('Synthetic Logistics')
        click('Review order')
        wait_text('Review your COD order')
        wait_text('Place COD order')
        if shipping_selection:
            wait_text('Shipping provider: Synthetic Logistics')
            choose_shipping('Synthetic Alternate Logistics')
            assert 'Review your COD order' not in script('return document.body.innerText;'), 'Changing provider must clear the reviewed quote.'
            assert script("return !Array.from(document.querySelectorAll('[role=button]')).some(e => (e.innerText || '').trim() === 'Place COD order' && e.getAttribute('aria-disabled') !== 'true');"), 'Placement must be disabled until renewed review.'
            click('Review order')
            wait_text('Shipping provider: Synthetic Alternate Logistics')
            wait_text('Shipping fee: PHP 120.00')
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
            # Re-resolve the current semantic element; Flutter can rebuild its
            # DOM after the accessibility-tree snapshot above.
            assert script("const checkbox = Array.from(document.querySelectorAll('[role=checkbox]')).find(e => (e.innerText || e.getAttribute('aria-label') || '').startsWith('Select ')); if (!checkbox) return false; checkbox.click(); return true;"), 'Cart checkbox must remain actionable.'
        wait_text('Checkout selected (1)')
        capture('cart-' + str(width))
        click('Checkout selected (1)')
        wait_text('Review order')
        if shipping_selection:
            wait_text('Shipping provider')
            choose_shipping('Synthetic Logistics')
        click('Review order')
        wait_text('Review your COD order')
        wait_text('Place COD order')
        script("window.location.hash = '/messages/shops/" + ID + "';")
        wait_text('Refresh conversation')
        capture('messages-' + str(width))
    calls = script('return window.buyerSyntheticCalls;')
    assert sum(item['path'].endswith('/cart/items') for item in calls) == 2
    assert sum(item['path'].endswith('/checkout/quote') for item in calls) == (6 if shipping_selection else 4)
    if shipping_selection:
        selections = [item['selections'] for item in calls if item['path'].endswith('/checkout/quote')]
        assert all(len(items) == 1 for items in selections)
        assert all(item['selections'] is None for item in calls if item['path'].endswith('/logistics-options')), 'Discovery must omit selections.'
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
    return accessibility_report
