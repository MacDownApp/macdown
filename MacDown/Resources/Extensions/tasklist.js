(function () {
  var taskListItems = document.getElementsByClassName('task-list-item');
  for (var i = 0; i < taskListItems.length; i++) {
    var inputs = taskListItems[i].getElementsByTagName('input');
    for (var j = 0; j < inputs.length; j++) {
      inputs[j].disabled = true;
      break;
    }
  }
})();
