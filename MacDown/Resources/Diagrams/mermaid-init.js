// Draws ```mermaid blocks. Mermaid (3.5 MB) is loaded only if the page has one.
(function () {
  var D = window.MacDownDiagrams;
  if (!D) { return; }

  function render(block, index, dark) {
    var key = D.hash((dark ? 'dark:' : 'light:') + block.source);
    var cached = D.cacheGet(key);
    if (cached) {
      var holder = document.createElement('div');
      holder.innerHTML = cached;
      D.show(block, holder, 'mermaid');
      return Promise.resolve();
    }
    var id = 'mmd' + Date.now().toString(36) + '_' + index;
    return D.withTimeout(mermaid.render(id, block.source), 10000, 'Mermaid').then(function (result) {
      D.cacheSet(key, result.svg);
      var holder = document.createElement('div');
      holder.innerHTML = result.svg;
      D.show(block, holder, 'mermaid');
    }).catch(function (error) {
      // Mermaid leaves its own error picture in the page. Ours is plainer.
      var leftover = document.getElementById('d' + id);
      if (leftover && leftover.parentNode) { leftover.parentNode.removeChild(leftover); }
      D.showError(block, 'Mermaid: ' + String((error && error.message) || error).split('\n')[0]);
    });
  }

  function start() {
    var found = D.blocks(['mermaid']);
    if (!found.length) { return; }
    D.track(D.load(['mermaid']).then(function () {
      var dark = D.isDark();
      mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: dark ? 'dark' : 'default',
                           flowchart: { useMaxWidth: true } });
      // One after the other: Mermaid uses shared page elements while it draws.
      return found.reduce(function (p, block, i) { return p.then(function () { return render(block, i, dark); }); },
                          Promise.resolve());
    }).catch(function (error) {
      found.forEach(function (block) { D.showError(block, 'Mermaid could not be loaded: ' + error.message); });
    }));
  }

  D.ready(start);
})();
