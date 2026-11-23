// For exported HTML: KaTeX comes from a CDN (loaded before this script).
document.addEventListener('DOMContentLoaded', function () {
  if (typeof renderMathInElement === 'undefined') { return; }
  renderMathInElement(document.body, {
    delimiters: [
      {left: '\\[', right: '\\]', display: true},
      {left: '\\(', right: '\\)', display: false}
    ],
    ignoredTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code'],
    throwOnError: false, strict: 'ignore', trust: false
  });
});
