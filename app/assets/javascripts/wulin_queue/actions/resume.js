WulinMaster.actions.Resume = $.extend({}, WulinMaster.actions.BaseAction, {
  name: 'resume',

  handler: function () {
    var ids = WulinQueue.selectedIds(this, 'queue');
    if (ids) WulinQueue.submit(this, ids);
  }
});

WulinMaster.ActionManager.register(WulinMaster.actions.Resume);
