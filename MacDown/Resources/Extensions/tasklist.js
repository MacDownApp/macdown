(function () {
  onClickCallback = function () {
    for (var id in checkboxes) {
      if (checkboxes[id] === this) {
        break;
      }
    }
    MPJSHandler.checkboxDidChangeValue(id, this.checked);
  };
  var items = document.getElementsByClassName('task-list-item');
  var checkboxes = {};
  for (var i = 0; i < items.length; i++) {
    var checkbox = items[i].getElementsByTagName('input')[0];
    if (!checkbox)
      continue;
    checkboxes[i] = checkbox;
    checkbox.addEventListener('click', onClickCallback);
  }
})();
