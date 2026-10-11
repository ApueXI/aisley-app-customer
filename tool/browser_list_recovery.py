"""Synthetic list recovery checks; requires the fully intercepted shopping harness."""
import json
import time
from browser_synthetic import fixture


def check_lists(script, wait_text, resize, click):
    def wait_for(source):
        for _ in range(100):
            if script(source):
                return
            time.sleep(.1)
        raise AssertionError('List request or recovery action did not settle.')

    entries = [
        ('/account/wishlist', 'customer/wishlist', 'wishlist', 'op-037', 'Products'),
        ('/account/recently-viewed', 'customer/recently-viewed', 'recently-viewed-items', 'op-041', 'Products'),
        ('/orders', 'customer/orders', 'order-status', 'op-032', 'Orders'),
        ('/notifications', 'customer/notifications', 'notifications', 'op-054', 'notifications'),
        ('/messages/shops', 'customer/conversations', 'chat-messaging', 'op-057', 'conversations'),
        ('/messages/logistics', 'customer/logistics-conversations', 'logistics-messaging', 'op-064', 'conversations'),
        ('/messages/courier', 'customer/courier-conversations', 'courier-messaging', 'op-070', 'conversations'),
        ('/support-tickets', 'customer/support-tickets', 'support-tickets', 'op-077', 'tickets'),
    ]
    bodies = {}
    retained_labels = {
        'customer/orders': 'ASL-SYNTHETIC',
        'customer/logistics-conversations': 'Synthetic Logistics',
        'customer/courier-conversations': 'Courier',
    }
    for _, path, feature, op, _ in entries:
        body = fixture(feature, op)
        if feature in ['notifications', 'order-status']:
            body['meta']['last_page'] = 3
        elif 'meta' in body:
            body['meta']['next_cursor'] = 'next-page'
        else:
            body['next_cursor'] = 'next-page'
        bodies['/api/v1/' + path] = body
    search = fixture('search', 'op-019')
    search['pagination']['lastPage'] = 3
    bodies['/api/v1/customer/products/search'] = search
    script('window.listRecoveryPaths = ' + json.dumps(list(bodies)) + ';')
    script('Object.assign(window.buyerSyntheticResponses, ' + json.dumps(bodies) + ');')
    script("""
      window.listFailures = {};
      window.listRequests = [];
      const listFetch = window.fetch;
      window.fetch = function(url, options) {
        const u = new URL(String(url));
        const path = u.pathname;
        const original = window.buyerSyntheticResponses[path];
        if (original && window.listRecoveryPaths.includes(path)) {
          window.listRequests.push({path, query:u.search});
          if (window.listFailures[path]) return Promise.resolve(new Response('{}',
            {status:503,headers:{'Content-Type':'application/json'}}));
          const body = structuredClone(original);
          const page = Number(u.searchParams.get('page') || 1);
          if (body.pagination) {
            body.pagination.currentPage = page;
            body.items[0].title = 'Recovery product page ' + page;
          }
          if (body.meta?.current_page) body.meta.current_page = page;
          return Promise.resolve(new Response(JSON.stringify(body),
            {status:200,headers:{'Content-Type':'application/json'}}));
        }
        return listFetch.apply(this, arguments);
      };
    """)
    for width, height in [(390, 844), (1440, 900)]:
        resize(width, height)
        # Use a separate query so a previous viewport's successful page is not
        # served from the permitted catalog cache during failure injection.
        script("window.location.hash = '/search?q=recovery" + str(width) + "&mode=products';")
        wait_text('Recovery product page 1')
        script("window.listFailures['/api/v1/customer/products/search'] = true;")
        click('Next page')
        wait_text('Showing page 1. Could not load page 2.')
        assert script("return window.location.hash.includes('page=2');")
        wait_text('Recovery product page 1')
        script("window.listFailures['/api/v1/customer/products/search'] = false;")
        click('Retry page 2')
        wait_text('Recovery product page 2')
        for route, path, _, _, label in entries:
            print('CHECK: list recovery ' + route + ' at ' + str(width), flush=True)
            target = json.dumps('/api/v1/' + path)
            count = script('return window.listRequests.filter(r => r.path === ' + target + ').length;')
            script('window.location.hash = ' + json.dumps(route) + ';')
            wait_for('return window.listRequests.filter(r => r.path === ' + target + ').length > ' + str(count) + ';')
            wait_text('Load more ' + label)
            script('window.listFailures[' + json.dumps('/api/v1/' + path) + '] = true;')
            click('Load more ' + label)
            try:
                wait_text('Retry loading more')
            except AssertionError:
                print('Recovery diagnostics:', script("return {requests:window.listRequests.slice(-4),labels:Array.from(document.querySelectorAll('[aria-label]')).map(e=>e.getAttribute('aria-label')).filter(t=>/Retry|Showing|more/.test(t))};"), flush=True)
                raise
            failed_query = script('return window.listRequests.filter(r => r.path === ' + target + ').at(-1).query;')
            count = script('return window.listRequests.filter(r => r.path === ' + target + ').length;')
            script('window.listFailures[' + json.dumps('/api/v1/' + path) + '] = false;')
            click('Retry loading more')
            wait_for('return window.listRequests.filter(r => r.path === ' + target + ').length > ' + str(count) + ';')
            wait_for("return !Array.from(document.querySelectorAll('[role=button]')).some(e => ['Retry loading more', 'Loading…'].includes((e.innerText || e.getAttribute('aria-label') || '').trim()));")
            wait_text(retained_labels.get(path, 'Synthetic example'))
            assert script('return window.listRequests.filter(r => r.path === ' + target + ').at(-1).query;') == failed_query
            refresh = ('Refresh list' if label == 'Products' else 'Refresh Orders' if label == 'Orders'
                       else 'Refresh notifications' if label == 'notifications' else 'Refresh tickets'
                       if label == 'tickets' else 'Refresh inbox')
            script('window.listFailures[' + json.dumps('/api/v1/' + path) + '] = true;')
            click(refresh)
            wait_text('out of date' if label != 'Orders' else 'Saved Orders are stale')
            wait_text(retained_labels.get(path, 'Synthetic example'))
            script('window.listFailures[' + json.dumps('/api/v1/' + path) + '] = false;')
            click('Retry / refresh Orders' if label == 'Orders' else 'Retry')
            wait_text('Load more ' + label)
            assert script('return document.documentElement.scrollWidth <= window.innerWidth;')
        script("window.location.hash = '/';")
        wait_text('Explore Categories')
    print('PASS: numbered page retention/exact Retry and all eight private collection page retries at phone and desktop widths; all API traffic intercepted.')
