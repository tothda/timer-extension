Ember Data Local Storage Adapter
================================

Store your ember application data in localStorage.

Currently tested against ember-data revision 11.

Usage
-----

Include `localstorage_adapter.js` in your app and then like all adapters:

```js
App.store = DS.Store.create({
  revision: 11,
  adapter: DS.LSAdapter.create()
});

```

### Local Storage Namespace

All of your application data lives on a single `localStorage` key, it defaults to `DS.LSAdapter` but if you supply a `namespace` option it will store it there:

```js
DS.LSAdapter.create({
  namespace: 'my app'
});
```

### Model "url"

If your model definition has a `url` property, the adapter will store the data on that namespace. URL is a weird term in this context, but it makes swapping out adapters simpler by not requiring additional properties on your models.

```js
var List = DS.Model.extend({
  // ...
});
List.reopen({
  url: '/some/url'
});
```

### Quota Exceeded Handler

Browser's `localStorage` has limited space, if you try to commit application data and the browser is out of space, then the adapter will trigger the `QUOTA_EXCEEDED_ERR` event.

```js
App.store.adapter.on('QUOTA_EXCEEDED_ERR', function(records){
  // do stuff
});

App.store.commit();
```

Todo
----

- Figure out how to save a record once its transitioned to the error state.
- Make the repo nicer to work with long-term (do something more intelligent with dependencies found in `vendor`, etc.)
- Add some examples

Tests
-----

Open `tests/index.html` in a browser.

License & Copyright
-------------------

Copyright (c) 2012 Ryan Florence
MIT Style license. http://opensource.org/licenses/MIT
