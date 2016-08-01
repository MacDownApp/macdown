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
 
    var insertSvg = function(svgCode, bindFunctions){
      dom.innerHTML = svgCode;
    };
    var graph = mermaidAPI.render('graphDiv' + i, graphSource, insertSvg)
    }
  };
 
  if (typeof window.addEventListener != "undefined") {
    window.addEventListener("load", init, false);
  } else {
    window.attachEvent("onload", init);
  }
})();