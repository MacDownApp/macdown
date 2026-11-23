// Draws ```vega-lite (and ```vega) blocks. The libraries are loaded only if the page has one.
// The spec can be JSON or YAML. Data from the web is blocked unless the config allows it.
(function () {
  var D = window.MacDownDiagrams;
  if (!D) { return; }
  var MAX_INLINE_ROWS = 100000;

  function chartConfig() {
    var text = D.textColor();
    var c = D.rgb(text) || [0, 0, 0];
    var grid = 'rgba(' + c[0] + ',' + c[1] + ',' + c[2] + ',0.2)';
    return {
      background: 'transparent',
      view: { stroke: 'transparent' },
      title: { color: text, subtitleColor: text },
      axis: { labelColor: text, titleColor: text, domainColor: text, tickColor: text, gridColor: grid },
      legend: { labelColor: text, titleColor: text },
      header: { labelColor: text, titleColor: text }
    };
  }

  // Vega does not stop when data cannot be loaded: it draws an empty chart. So every
  // failure is written down, and the caller turns it into a message.
  function makeLoader(failures) {
    var loader = vega.loader();
    var sanitize = loader.sanitize.bind(loader);
    var load = loader.load.bind(loader);
    loader.sanitize = function (uri, options) {
      if (/^(https?:)?\/\//i.test(uri) && !D.settings.vegaRemoteData) {
        return Promise.reject(new Error('Data from the web is turned off (set charts.vega-lite-remote-data in config.yaml): ' + uri));
      }
      return sanitize(uri, options);
    };
    loader.load = function (uri, options) {
      return load(uri, options).catch(function (error) {
        failures.push(String((error && error.message) || error));
        throw error;
      });
    };
    return loader;
  }

  function check(spec) {
    if (!spec || typeof spec !== 'object' || Array.isArray(spec)) { throw new Error('The chart must be a mapping (JSON or YAML).'); }
    var datasets = [];
    if (spec.data && Array.isArray(spec.data.values)) { datasets.push(spec.data.values); }
    if (Array.isArray(spec.data)) { spec.data.forEach(function (d) { if (d && Array.isArray(d.values)) { datasets.push(d.values); } }); }
    datasets.forEach(function (values) {
      if (values.length > MAX_INLINE_ROWS) { throw new Error('Too much inline data (' + values.length + ' rows; the limit is ' + MAX_INLINE_ROWS + ').'); }
    });
  }

  function render(block) {
    var spec;
    try { spec = jsyaml.load(block.source); check(spec); }
    catch (e) { D.showError(block, 'Chart: ' + String(e.message || e).split('\n')[0]); return Promise.resolve(); }

    var target = document.createElement('div');
    var failures = [];
    var mode = block.language === 'vega' ? 'vega' : 'vega-lite';
    return D.withTimeout(vegaEmbed(target, spec, {
      mode: mode, actions: false, renderer: 'svg', loader: makeLoader(failures), config: chartConfig()
    }), 10000, 'The chart').then(function (result) {
      if (failures.length) {   // An empty chart would only confuse. Show the reason instead.
        if (result && result.view) { result.view.finalize(); }
        throw new Error(failures[0]);
      }
      D.show(block, target, 'vega');
    }).catch(function (e) {
      D.showError(block, 'Chart: ' + String((e && e.message) || e).split('\n')[0]);
    });
  }

  function start() {
    var found = D.blocks(['vega-lite', 'vega']);
    if (!found.length) { return; }
    D.track(D.load(['yaml', 'vega', 'vegalite', 'vegaembed']).then(function () {
      return found.reduce(function (p, block) { return p.then(function () { return render(block); }); }, Promise.resolve());
    }).catch(function (error) {
      found.forEach(function (block) { D.showError(block, 'Chart libraries could not be loaded: ' + error.message); });
    }));
  }

  D.ready(start);
})();
