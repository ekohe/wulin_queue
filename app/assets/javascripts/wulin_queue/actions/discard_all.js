WulinMaster.actions.DiscardAll = $.extend({}, WulinMaster.actions.BaseAction, {
  name: 'discard_all',

  handler: function () {
    var self = this;

    WulinQueue.confirm(
      '<p>This will permanently delete <strong>every</strong> failed job, not just the ' +
        'selected rows, up to a limit of 3000. None of them will run.</p>' +
        '<p>Are you sure you want to proceed?</p>',
      'Discard All',
      function () {
        WulinQueue.submit(self, []);
      }
    );
  }
});

WulinMaster.ActionManager.register(WulinMaster.actions.DiscardAll);
