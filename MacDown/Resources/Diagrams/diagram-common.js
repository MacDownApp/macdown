// Shared helpers for diagram blocks (Mermaid, Vega-Lite).
//
// Libraries are loaded only when a page has a block that needs them. In the
// app they come from this folder; in exported HTML (an inline script, no `src`)
// they come from a CDN with pinned versions.
(function () {
  var script = document.currentScript;
  var src = script && script.src ? script.src : '';
  var local = src ? src.replace(/[^\/]*$/, '') : '';
  var CDN = 'https://cdn.jsdelivr.net/npm/';
  var FILES = {
    mermaid:   ['mermaid.min.js',    'mermaid@11.17.2/dist/mermaid.min.js'],
    vega:      ['vega.min.js',       'vega@5.33.1/build/vega.min.js'],
    vegalite:  ['vega-lite.min.js',  'vega-lite@5.23.0/build/vega-lite.min.js'],
    vegaembed: ['vega-embed.min.js', 'vega-embed@6.29.0/build/vega-embed.min.js'],
    yaml:      ['js-yaml.min.js',    'js-yaml@4.3.2/dist/js-yaml.min.js']
  };
  var loading = {};

  function loadScript(name) {
    if (!loading[name]) {
      loading[name] = new Promise(function (resolve, reject) {
        var el = document.createElement('script');
        el.src = (local ? local + FILES[name][0] : CDN + FILES[name][1]);
        el.onload = resolve;
        el.onerror = function () { reject(new Error('Could not load ' + name)); };
        document.head.appendChild(el);
      });
    }
    return loading[name];
  }

  // Scripts run in order: each library needs the one before it.
  function load(names) {
    return names.reduce(function (p, n) { return p.then(function () { return loadScript(n); }); }, Promise.resolve());
  }

  function withTimeout(promise, ms, what) {
    return new Promise(function (resolve, reject) {
      var timer = setTimeout(function () { reject(new Error(what + ' took longer than ' + (ms / 1000) + ' seconds')); }, ms);
      promise.then(function (v) { clearTimeout(timer); resolve(v); }, function (e) { clearTimeout(timer); reject(e); });
    });
  }

  function textColor() {
    var cs = getComputedStyle(document.body);
    return cs.color;
  }

  function backgroundColor() {
    function c(e) { return e ? getComputedStyle(e).backgroundColor : ''; }
    var b = c(document.body);
    if (!b || b === 'rgba(0, 0, 0, 0)' || b === 'transparent') { b = c(document.documentElement); }
    return b;
  }

  function rgb(text) {
    var m = /rgba?\(\s*([\d.]+)[,\s]+([\d.]+)[,\s]+([\d.]+)/.exec(text || '');
    return m ? [parseFloat(m[1]), parseFloat(m[2]), parseFloat(m[3])] : null;
  }

  // Dark if the page background is dark; a missing background counts as light.
  function isDark() {
    var c = rgb(backgroundColor());
    return !!c && (0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]) / 255 < 0.5;
  }

  // Blocks: <pre><code class="language-NAME"> inside a wrapper <div>.
  function blocks(languages) {
    var found = [];
    var selector = languages.map(function (l) { return 'code.language-' + l; }).join(',');
    var nodes = document.querySelectorAll(selector);
    for (var i = 0; i < nodes.length; i++) {
      var code = nodes[i];
      var holder = code.parentElement;
      if (holder && holder.tagName === 'PRE' && holder.parentElement && holder.parentElement !== document.body) {
        holder = holder.parentElement;
      }
      found.push({
        language: code.className.replace(/^.*language-/, '').split(/\s/)[0],
        source: code.textContent || '',
        holder: holder
      });
    }
    return found;
  }

  function show(block, node, kind) {
    var box = document.createElement('div');
    box.className = 'macdown-diagram macdown-diagram-' + kind;
    box.appendChild(node);
    block.holder.parentNode.replaceChild(box, block.holder);
    return box;
  }

  // Keep the source visible and say what is wrong under it.
  function showError(block, message) {
    var note = document.createElement('div');
    note.className = 'macdown-diagram-error';
    note.textContent = message;
    block.holder.parentNode.insertBefore(note, block.holder.nextSibling);
  }

  // Finished SVG, kept while the app runs, so unchanged diagrams do not render again.
  function cacheGet(key) { try { return window.localStorage.getItem('md:' + key); } catch (e) { return null; } }
  function cacheSet(key, value) {
    try {
      var count = parseInt(window.localStorage.getItem('md:count') || '0', 10);
      if (count > 80) { window.localStorage.clear(); count = 0; }
      window.localStorage.setItem('md:' + key, value);
      window.localStorage.setItem('md:count', String(count + 1));
    } catch (e) { /* No storage: render every time. */ }
  }
  function hash(text) {
    var h = 5381;
    for (var i = 0; i < text.length; i++) { h = ((h << 5) + h + text.charCodeAt(i)) | 0; }
    return (h >>> 0).toString(36) + ':' + text.length;
  }

  var pending = 0;
  function track(promise) {
    pending++;
    var done = function () { pending--; };
    promise.then(done, done);
    return promise;
  }

  function ready(fn) {
    if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', fn); } else { fn(); }
  }

  var style = document.createElement('style');
  style.textContent =
    '.macdown-diagram { text-align: center; margin: 1em 0; overflow-x: auto; }' +
    '.macdown-diagram svg { max-width: 100%; height: auto; }' +
    '.macdown-diagram-error { color: #cc0000; font: 12px/1.4 -apple-system, sans-serif; margin: -0.5em 0 1em; white-space: pre-wrap; }';
  document.head.appendChild(style);

  window.MacDownDiagrams = {
    settings: window.MacDownSettings || {},
    load: load, withTimeout: withTimeout, blocks: blocks, show: show, showError: showError,
    cacheGet: cacheGet, cacheSet: cacheSet, hash: hash, track: track, ready: ready,
    isDark: isDark, textColor: textColor, rgb: rgb,
    get pending() { return pending; }
  };
})();
