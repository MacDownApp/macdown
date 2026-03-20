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
    var domAll = document.querySelectorAll(".language-mermaid");
    for (var i = 0; i < domAll.length; i++) {
      var dom = domAll[i];
      var graphSource = dom.innerText || dom.textContent;

      dom = dom.parentElement;
      if (dom.tagName === "PRE") {
        dom = dom.parentElement;
      }

      try {
        var insertSvg = function(svgCode, bindFunctions){
          this.innerHTML = svgCode;
        };
        mermaid.render('graphDiv' + i, graphSource, insertSvg.bind(dom));
      } catch(e) {
        console.log("Mermaid error: " + e);
      }
    }
  };

  // Run on load and also after a short delay for loadHTMLString
  if (typeof window.addEventListener != "undefined") {
    window.addEventListener("load", init, false);
  } else {
    window.attachEvent("onload", init);
  }

  // Also run after DOM is ready and after a delay as fallback
  if (document.readyState === "complete" || document.readyState === "interactive") {
    setTimeout(init, 100);
  } else {
    document.addEventListener("DOMContentLoaded", function() {
      setTimeout(init, 100);
    });
  }
})();
