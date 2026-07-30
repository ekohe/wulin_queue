WulinMaster.actions.RetryAll = $.extend({}, WulinMaster.actions.BaseAction, {
  name: 'retry_all',

  handler: function () {
    var self = this;

    WulinQueue.confirm(
      '<p>This will retry <strong>every</strong> failed job, not just the selected rows, ' +
        'up to a limit of 3000.</p>' +
        '<p>Are you sure you want to proceed?</p>',
      'Retry All',
      function () {
        WulinQueue.submit(self, []);
      }
    );
  }
});

WulinMaster.ActionManager.register(WulinMaster.actions.RetryAll);
