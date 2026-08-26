function JsonFormatter(row, cell, value, columnDef, dataContext) {
  if (value === null || value === undefined || value === '') return '';

  var compact;
  if (typeof value === 'object') {
    compact = JSON.stringify(value);
  } else {
    compact = String(value);
  }

  var span = document.createElement('span');
  span.setAttribute('class', 'wq-json-cell');
  span.setAttribute('style', 'cursor: pointer; text-decoration: underline dotted;');
  span.textContent = compact;
  return span.outerHTML;
}

$(document).on('click', '.wq-json-cell', function () {
  var text = $(this).text();
  var pretty;
  try { pretty = JSON.stringify(JSON.parse(text), null, 2); } catch (e) { pretty = text; }

  Ui.headerModal('JSON', {
    onOpenStart: function (modal) {
      $(modal).find('.modal-content').html(
        '<pre style="overflow: auto; white-space: pre-wrap; max-height: 70vh;">' +
        escapeHtml(pretty) + '</pre>'
      );
    }
  });
});
