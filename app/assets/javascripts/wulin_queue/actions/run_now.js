// Blocked jobs (dispatched past their concurrency limit), scheduled jobs
// (brought forward) and recurring tasks (enqueued immediately) all share this
// button; the grid's action url decides which.
WulinMaster.actions.RunNow = $.extend({}, WulinMaster.actions.BaseAction, {
  name: 'run_now',

  handler: function () {
    var ids = WulinQueue.selectedIds(this, 'row');
    if (ids) WulinQueue.submit(this, ids);
  }
});

WulinMaster.ActionManager.register(WulinMaster.actions.RunNow);
