// The exception class, message and backtrace are already on the row — the
// backtrace column is hidden but always included — so this needs no request.
WulinMaster.actions.ShowError = $.extend({}, WulinMaster.actions.BaseAction, {
  name: 'show_error',

  handler: function () {
    var grid = this.getGrid();
    var rows = grid.getSelectedRows();

    if (rows.length !== 1) {
      displayErrorMessage('Please select just one failed job.');
      return;
    }

    var row = grid.getData()[rows[0]];
    var backtrace = row.backtrace || [];

    Ui.headerModal(row.exception_class || 'Error', {
      onOpenStart: function (modal) {
        $(modal)
          .find('.modal-content')
          .html(
            '<p>' + escapeHtml(row.message || '') + '</p>' +
              '<pre style="overflow: auto; white-space: pre-wrap">' +
              escapeHtml(backtrace.join('\n')) +
              '</pre>'
          );
      }
    });
  }
});

WulinMaster.ActionManager.register(WulinMaster.actions.ShowError);
