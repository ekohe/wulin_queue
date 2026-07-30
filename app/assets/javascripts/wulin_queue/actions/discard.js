WulinMaster.actions.Discard = $.extend({}, WulinMaster.actions.BaseAction, {
  name: 'discard',

  handler: function () {
    var self = this;
    var ids = WulinQueue.selectedIds(this, 'job');
    if (!ids) return;

    WulinQueue.confirm(
      '<p>This will permanently delete ' + ids.length + ' job(s). They will not run.</p>' +
        '<p>Are you sure you want to proceed?</p>',
      'Discard',
      function () {
        WulinQueue.submit(self, ids);
      }
    );
  }
});

WulinMaster.ActionManager.register(WulinMaster.actions.Discard);
