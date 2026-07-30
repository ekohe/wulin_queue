$.namespace('WulinQueue');

// Every wulin_queue toolbar action has the same shape: take the ids of the
// selected rows, POST them to the url the grid declared on the action, reload.
// `action.url` arrives via WulinMaster.ActionManager.dispatchActions, which
// extends the registered action object with the grid's action config.
WulinQueue.submit = function (action, ids) {
  var grid = action.getGrid();

  $.post(action.url, { ids: ids, screen: grid.screen })
    .done(function (response) {
      if (response && response.success === false) {
        displayErrorMessage(response.error_message);
      }
      grid.loader.reloadData();
    })
    .fail(function (xhr) {
      displayErrorMessage('Request failed with status ' + xhr.status + '.');
    });
};

// Ids of the selected rows, or null (having told the user why) when nothing is
// selected.
WulinQueue.selectedIds = function (action, noun) {
  var ids = action.getGrid().getSelectedIds();

  if (ids.length < 1) {
    displayErrorMessage('Please select at least one ' + noun + '.');
    return null;
  }

  return ids;
};

// Confirmation modal for the destructive actions.
WulinQueue.confirm = function (message, buttonName, onConfirm) {
  var modal = Ui.baseModal({
    onOpenStart: function (modal) {
      $(modal).find('.modal-content').html(message);
    }
  })
    .width('600px')
    .height('auto');

  Ui.modalFooter(buttonName)
    .appendTo(modal)
    .find('.confirm-btn')
    .on('click', function () {
      modal.modal('close');
      onConfirm();
    });
};
