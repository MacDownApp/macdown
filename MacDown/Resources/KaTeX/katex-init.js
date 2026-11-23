// Loads KaTeX only if the page contains math, renders it, and tells the app when
// it is done (the app waits for this before it syncs scrolling).
// Everything is read from the folder this script is in, so it works offline.
(function () {
  var script = document.currentScript;
  var base = script ? script.src.replace(/[^\/]*$/, '') : '';
  var finished = false;

  function finish() {
    if (finished) { return; }
    finished = true;
    if (typeof MathJaxListener !== 'undefined') { MathJaxListener.invokeCallbackForKey_('End'); }
  }

  function load(tag, attrs, onload) {
    var el = document.createElement(tag);
    for (var k in attrs) { el[k] = attrs[k]; }
    el.onload = onload;
    el.onerror = finish;   // A missing file must not block the page.
    document.head.appendChild(el);
  }

  function render() {
    try {
      renderMathInElement(document.body, {
        delimiters: [
          {left: '\\[', right: '\\]', display: true},
          {left: '\\(', right: '\\)', display: false}
        ],
        ignoredTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code'],
        throwOnError: false,
        strict: 'ignore',
        trust: false
      });
    } catch (e) { window.__mathError = String(e); }   // Show the page with the unrendered text.
    finish();
  }

  // True if some text outside code, scripts and styles contains a math delimiter.
  function hasMath() {
    if (!document.body) { return false; }
    var skip = /^(PRE|CODE|SCRIPT|STYLE|TEXTAREA|NOSCRIPT)$/;
    var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
      acceptNode: function (node) {
        for (var p = node.parentNode; p && p !== document.body; p = p.parentNode) {
          if (skip.test(p.nodeName)) { return NodeFilter.FILTER_REJECT; }
        }
        return NodeFilter.FILTER_ACCEPT;
      }
    });
    while (walker.nextNode()) {
      var t = walker.currentNode.nodeValue;
      if (t.indexOf('\\(') >= 0 || t.indexOf('\\[') >= 0) { return true; }
    }
    return false;
  }

  function start() {
    if (!hasMath()) { return finish(); }
    load('link', {rel: 'stylesheet', href: base + 'katex.min.css'}, function () {});
    load('script', {src: base + 'katex.min.js'}, function () {
      load('script', {src: base + 'auto-render.min.js'}, render);
    });
  }

  if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', start); }
  else { start(); }
})();
