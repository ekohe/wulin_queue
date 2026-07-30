WulinMaster.actions.Pause = $.extend({}, WulinMaster.actions.BaseAction, {
  name: 'pause',

  handler: function () {
    var ids = WulinQueue.selectedIds(this, 'queue');
    if (ids) WulinQueue.submit(this, ids);
  }
});

WulinMaster.ActionManager.register(WulinMaster.actions.Pause);
