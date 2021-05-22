// init wavedrom
(function () {
	var init = function() {
		console.log("Wavedrom init");
		var domAll = document.querySelectorAll(".language-wavedrom");
		console.log("Wavedrom: " + domAll);
		for (var i = 0; i < domAll.length; i++) {
			var dom = domAll[i];
			console.log("Wavedrom: " + dom);
			var graphSource = dom.innerText || dom.textContent;
			console.log("Dom object:")
			console.log(dom)
			dom.outerHTML = '<script type="WaveDrom">' + graphSource + '</sc' + 'ript>';
		}
		WaveDrom.ProcessAll();
	};

	if (typeof window.addEventListener != "undefined") {
		window.addEventListener("load", init, false);
	} else {
		window.attachEvent("onload", init);
	}
})();
