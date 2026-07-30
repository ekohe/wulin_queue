WulinMaster.actions.Clear = $.extend({}, WulinMaster.actions.BaseAction, {
  name: 'clear',

  handler: function () {
    var self = this;
    var ids = WulinQueue.selectedIds(this, 'queue');
    if (!ids) return;

    WulinQueue.confirm(
      '<p>This will permanently delete every pending job on ' + escapeHtml(ids.join(', ')) +
        '. None of them will run.</p>' +
        '<p>Are you sure you want to proceed?</p>',
      'Clear',
      function () {
        WulinQueue.submit(self, ids);
      }
    );
  }
});

WulinMaster.ActionManager.register(WulinMaster.actions.Clear);
