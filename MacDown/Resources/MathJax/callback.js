if (typeof MathJaxListener !== 'undefined') {
  MathJax.Hub.Register.StartupHook('End', function () {
    MathJaxListener.invokeCallbackForKey_('End');
  });
}
