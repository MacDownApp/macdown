(function () {

MathJax.Hub.Config({
	'showProcessingMessages': false,
	'messageStyle': 'none'
});

if (typeof MathJaxListener !== 'undefined') {
	MathJax.Hub.Register.StartupHook('End', function () {
		MathJaxListener.invokeCallbackForKey_('End');
	});
}

})();
