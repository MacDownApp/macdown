// graphviz init
(function () {
  var graphviz_engines = ["dot"];
 
  function doGraphviz(engine) {
    var domAllDot = document.querySelectorAll(".language-" + engine);
    for (var i = 0; i < domAllDot.length; i++) {
      var dom = domAllDot[i];
      var graphSource = dom.innerText || dom.textContent;

 
      dom = dom.parentElement;
      if (dom.tagName === "PRE") {
        dom = dom.parentElement;
      }
      dom.innerHTML = Viz(graphSource);
    }
  }
 
  for (var i = 0; i < graphviz_engines.length; i++) {
    doGraphviz(graphviz_engines[i]);
  }
})();