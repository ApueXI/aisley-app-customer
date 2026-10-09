"""Profile/Review recovery with actual browser file inputs and intercepted API writes."""
import json
import time
from browser_synthetic import ID, fixture

PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII='


def check_uploads(call, prefix, script, wait_text, resize, click):
    call(prefix + '/goog/cdp/execute', {'cmd': 'Page.setInterceptFileChooserDialog', 'params': {'enabled': True}})
    def wait_for(source):
        for _ in range(100):
            if script(source):
                return
            time.sleep(.1)
        raise AssertionError('Upload action did not settle: ' + source)

    def pick(label, *, cancel=False, corrupt=False):
        wait_for("return Array.from(document.querySelectorAll('[role=button]')).some(e=>(e.innerText||'').trim()===" + json.dumps(label) + " && e.getAttribute('aria-disabled')!=='true');")
        button = script("return Array.from(document.querySelectorAll('[role=button]')).find(e=>(e.innerText||'').trim()===" + json.dumps(label) + ");")
        call(prefix + '/element/' + next(iter(button.values())) + '/click', {})
        wait_for("return !!document.querySelector('input[type=file]');")
        if cancel:
            script("document.querySelector('input[type=file]').dispatchEvent(new Event('cancel'));")
        else:
            script("const input=document.querySelector('input[type=file]'); const dt=new DataTransfer(); dt.items.add(new File([" + ("new Uint8Array([1,2,3])" if corrupt else "Uint8Array.from(atob(" + json.dumps(PNG) + "),c=>c.charCodeAt(0))") + "], 'synthetic.png',{type:'image/png'})); input.files=dt.files; input.dispatchEvent(new Event('change',{bubbles:true}));")
        wait_for("return !document.querySelector('input[type=file]');")

    mutation = fixture('account-management', 'op-011')
    review = fixture('product-review-ratings', 'op-052')
    photo = fixture('product-review-ratings', 'op-053')
    script('window.uploadMutation=' + json.dumps(mutation) + '; window.reviewMutation=' + json.dumps(review) + '; window.reviewPhoto=' + json.dumps(photo) + '; window.uploadPng=' + json.dumps(PNG) + ';')
    script("""
      window.uploadEvents=[]; window.uploadMode='pending'; window.uploadReadFails=false;
      window.profileExists=false; window.uploadVersion=0;
      const uploadFetch=window.fetch;
      window.fetch=async function(url,options={}) {
        const path=new URL(String(url)).pathname, method=options.method||'GET';
        const profile=path.endsWith('/customer/account/profile-photo');
        const review=path.endsWith('/reviews/11111111-1111-4111-8111-111111111111/images');
        const json=(body,status=200)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json'}});
        if(method==='POST' && (profile||review)) {
          const form=await new Request(url,{method,headers:options.headers,body:options.body}).formData();
          const field=profile?'photo':'image', file=form.get(field);
          if(!file || file.name!=='synthetic.png' || file.type!=='image/png' || (await file.arrayBuffer()).byteLength<50 || options.headers['Idempotency-Key']) throw new Error('Incorrect multipart');
          uploadEvents.push({path,field,method});
          if(uploadMode==='validation') return json({errors:{[field]:['Synthetic invalid image']}},422);
          uploadVersion++;
          if(profile) {
            profileExists=true;
            buyerSyntheticResponses['/api/v1/customer/account'].account.profile.profilePhotoUrl='/api/v1/customer/account/profile-photo?v='+uploadVersion;
          } else {
            const photo=structuredClone(reviewPhoto.data);
            photo.id=String(uploadVersion).padStart(8,'0')+'-1111-4111-8111-111111111111';
            buyerSyntheticResponses['/api/v1/products/11111111-1111-4111-8111-111111111111/reviews'].data[0].photos.push(photo);
          }
          if(uploadMode==='pending') return new Promise((resolve,reject)=>options.signal.addEventListener('abort',()=>reject(new DOMException('Aborted','AbortError'))));
          if(uploadMode==='lost') throw new TypeError('Synthetic lost response');
          if(profile) {
            const body=structuredClone(uploadMutation);
            body.account=structuredClone(buyerSyntheticResponses['/api/v1/customer/account'].account);
            return json(body,201);
          }
          return json({data:buyerSyntheticResponses['/api/v1/products/11111111-1111-4111-8111-111111111111/reviews'].data[0].photos.at(-1)},201);
        }
        if(profile && method==='GET') return profileExists
          ? new Response(Uint8Array.from(atob(uploadPng),c=>c.charCodeAt(0)),{status:200,headers:{'Content-Type':'image/png'}})
          : json({},404);
        if(method==='GET' && (path.endsWith('/customer/account') || path.endsWith('/reviews')) && uploadReadFails) return json({},503);
        if(method==='POST' && path.endsWith('/review')) {
          uploadEvents.push({path,method});
          return json(reviewMutation,201);
        }
        return uploadFetch.apply(this,arguments);
      };
    """)
    for width, height in [(390, 844), (1440, 900)]:
        print('CHECK: browser upload recovery at '+str(width)+'px.', flush=True)
        resize(width, height)
        script("window.location.hash='/account/profile'; window.uploadMode='pending';")
        wait_text('Choose a photo')
        pick('Choose a photo', cancel=True)
        assert script("return !document.body.innerText.includes('Upload selected photo');")
        pick('Choose a photo', corrupt=True)
        wait_text('contents do not match')
        pick('Choose a photo')
        wait_text('Upload selected photo')
        click('Upload selected photo')
        wait_text('Upload this photo?')
        click('Upload')
        wait_for("return uploadEvents.filter(e=>e.field==='photo').length>0;")
        wait_text('Cancel upload')
        before = script("return uploadEvents.filter(e=>e.field==='photo').length;")
        click('Cancel upload')
        wait_text('Refresh current photo')
        wait_for("return !document.body.innerText.includes('Cancel upload');")
        script("window.uploadReadFails=true; window.location.hash='/account';")
        wait_text('Your account')
        script("window.location.hash='/account/profile';")
        wait_text('Your profile could not be loaded.')
        assert script("return uploadEvents.filter(e=>e.field==='photo').length;") == before
        script("window.uploadReadFails=false;")
        click('Retry')
        wait_text('Choose a photo')
        wait_for("return Array.from(document.querySelectorAll('[role=button]')).some(e=>(e.innerText||'').trim()==='Choose a photo' && e.getAttribute('aria-disabled')!=='true');")
        assert script("return uploadEvents.filter(e=>e.field==='photo').length;") == before

        script("window.uploadMode='success'; window.location.hash='/order-items/" + ID + "/review/" + ID + "';")
        wait_text('Verified purchase review')
        if script("return document.body.innerText.includes('Submit Review');"):
            fields = call(prefix + '/elements', {'using':'css selector', 'value':'textarea[aria-label="Review"], input[aria-label="Review"]'})
            assert fields, 'Review input must be accessible.'
            element = next(iter(fields[0].values()))
            call(prefix + '/element/' + element + '/click', {})
            call(prefix + '/element/' + element + '/value', {'text':'Synthetic confirmed Review'})
            click('Submit Review')
        wait_text('Review text is confirmed.')
        print('CHECK: Profile recovery and Review text confirmed at '+str(width)+'px.', flush=True)
        pick('Choose photo')
        wait_text('synthetic.png')
        uploads = script("return uploadEvents.filter(e=>e.field==='image').length;")
        click('Upload selected photo')
        wait_for("return uploadEvents.filter(e=>e.field==='image').length===" + str(uploads+1) + ";")
        wait_for("return !document.body.innerText.includes('Uploading photo') && !document.body.innerText.includes('synthetic.png');")
        script("window.uploadMode='lost';")
        pick('Choose photo')
        wait_text('synthetic.png')
        click('Upload selected photo')
        wait_text('Check the published Review')
        before = script("return uploadEvents.filter(e=>e.field==='image').length;")
        script("window.uploadReadFails=true;")
        click('Check published Review / photos')
        wait_text('The service is unavailable.')
        assert script("return uploadEvents.filter(e=>e.field==='image').length;") == before
        script("window.uploadReadFails=false;")
        click('Check published Review / photos')
        wait_for("return Array.from(document.querySelectorAll('[role=button]')).some(e=>(e.innerText||'').trim()==='Choose photo' && e.getAttribute('aria-disabled')!=='true');")
        assert script("return uploadEvents.filter(e=>e.field==='image').length;") == before
        assert script('return document.documentElement.scrollWidth<=window.innerWidth;')
        print('PASS: Profile/Review browser picker, validation, cancellation, partial success and uncertainty at '+str(width)+'px.', flush=True)
