WulinMaster.actions.Retry = $.extend({}, WulinMaster.actions.BaseAction, {
  name: 'retry',

  handler: function () {
    var ids = WulinQueue.selectedIds(this, 'failed job');
    if (ids) WulinQueue.submit(this, ids);
  }
});

WulinMaster.ActionManager.register(WulinMaster.actions.Retry);
