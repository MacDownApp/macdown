(function () {

MathJax.Hub.Config({
	'showProcessingMessages': false,
	'messageStyle': 'none'
});

MathJax.Hub.Register.StartupHook('End', function () {
	if (window.webkit && window.webkit.messageHandlers
			&& window.webkit.messageHandlers.mathJaxListener) {
		window.webkit.messageHandlers.mathJaxListener.postMessage('End');
	}
});

})();
