// init mermaid

(function () {

  mermaid.initialize({
    startOnLoad:false,
    flowchart:{
      htmlLabels: false,
      useMaxWidth: true
    }
  });

  var init = function() {
    var domAll = document.querySelectorAll("code.language-mermaid");
    for (var i = 0; i < domAll.length; i++) {
      var dom = domAll[i];
      var graphSource = dom.textContent;

      dom = dom.parentElement;
      if (dom.tagName === "PRE") {
        dom = dom.parentElement;
      }

      mermaid.render('graphDiv' + i, graphSource).then(
        (function (target) {
          return function (result) {
            target.innerHTML = result.svg;
            if (result.bindFunctions) {
              result.bindFunctions(target);
            }
          };
        })(dom)
      ).catch(function (e) {
        console.error("Error when rendering mermaid:", e);
      });
    }
  };

  if (typeof window.addEventListener != "undefined") {
    window.addEventListener("DOMContentLoaded", init, false);
  } else {
    window.attachEvent("onload", init);
  }
})();
