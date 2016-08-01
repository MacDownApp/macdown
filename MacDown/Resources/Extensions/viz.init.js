// graphviz init
(function () {
 var graphviz_engines = ["circo",
                         "dot",
                         "fdp",
                         "neato",
                         "osage",
                         "twopi"];
 
  function doGraphviz(engine) {
    var domAllDot = document.querySelectorAll(".language-" + engine);
    for (var i = 0; i < domAllDot.length; i++) {
      var dom = domAllDot[i];
      var graphSource = dom.innerText || dom.textContent;

 
      dom = dom.parentElement;
      if (dom.tagName === "PRE") {
        dom = dom.parentElement;
      }
      dom.innerHTML = Viz(graphSource, { engine: engine});
    }
  }
 
  var init = function() {
    for (var i = 0; i < graphviz_engines.length; i++) {
      doGraphviz(graphviz_engines[i]);
    }
  };
  if (typeof window.addEventListener != "undefined") {
    window.addEventListener("load", init, false);
  } else {
    window.attachEvent("onload", init);
  }
})();