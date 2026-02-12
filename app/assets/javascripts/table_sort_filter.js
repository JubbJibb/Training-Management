// Table sort and filter - applies to tables with class .table-sortable-filterable
(function() {
  function initTable(table) {
    if (table.getAttribute('data-table-sort-filter-inited')) return;
    var thead = table.querySelector('thead');
    var tbody = table.querySelector('tbody');
    if (!thead || !tbody) return;

    table.setAttribute('data-table-sort-filter-inited', '1');
    var headerRow = thead.querySelector('tr');
    if (!headerRow) return;
    var ths = headerRow.querySelectorAll('th');
    var colCount = ths.length;
    if (colCount === 0) return;

    // Skip last column for filter (usually Actions)
    var filterColCount = colCount;
    var lastTh = ths[colCount - 1];
    if (lastTh && (lastTh.textContent || '').trim().toLowerCase().indexOf('action') !== -1) {
      filterColCount = colCount - 1;
    }

    // Insert filter row
    var filterRow = document.createElement('tr');
    filterRow.className = 'table-sort-filter-row';
    for (var c = 0; c < colCount; c++) {
      var cell = document.createElement('th');
      cell.className = 'align-middle';
      cell.style.verticalAlign = 'middle';
      if (c < filterColCount) {
        var input = document.createElement('input');
        input.type = 'text';
        input.className = 'form-control form-control-sm';
        input.placeholder = 'Filter...';
        input.setAttribute('data-col', c);
        input.addEventListener('input', function() { applyFilter(table); });
        input.addEventListener('keyup', function() { applyFilter(table); });
        cell.appendChild(input);
      }
      filterRow.appendChild(cell);
    }
    headerRow.parentNode.insertBefore(filterRow, headerRow.nextSibling);

    // Sort on header click (first row only)
    for (var i = 0; i < ths.length; i++) {
      (function(colIndex) {
        var th = ths[colIndex];
        th.style.cursor = 'pointer';
        th.style.userSelect = 'none';
        th.setAttribute('title', 'Click to sort');
        var sortDir = 0; // 0 = none, 1 = asc, -1 = desc
        th.addEventListener('click', function() {
          sortDir = sortDir === 1 ? -1 : 1;
          sortTable(table, colIndex, sortDir);
          updateSortIndicator(table, colIndex, sortDir);
        });
      })(i);
    }
  }

  function getSortValue(cell) {
    if (!cell) return '';
    var text = (cell.textContent || '').trim();
    var num = text.replace(/[^\d.-]/g, '');
    if (num && !isNaN(parseFloat(num))) return parseFloat(num);
    return text.toLowerCase();
  }

  function sortTable(table, colIndex, dir) {
    var thead = table.querySelector('thead');
    var tbody = table.querySelector('tbody');
    var headerRow = thead.querySelector('tr');
    var thCount = headerRow.querySelectorAll('th').length;
    var rows = Array.prototype.slice.call(tbody.querySelectorAll('tr'));
    var sortable = [];
    var nonSortable = [];
    rows.forEach(function(tr, i) {
      var tds = tr.querySelectorAll('td');
      if (tds.length === thCount) {
        sortable.push({ tr: tr, index: i, value: getSortValue(tds[colIndex]) });
      } else {
        nonSortable.push({ tr: tr, index: i });
      }
    });
    sortable.sort(function(a, b) {
      var va = a.value;
      var vb = b.value;
      if (typeof va === 'number' && typeof vb === 'number') {
        return dir * (va - vb);
      }
      var sa = String(va);
      var sb = String(vb);
      if (sa < sb) return -dir;
      if (sa > sb) return dir;
      return 0;
    });
    var newOrder = [];
    var nextSortable = 0;
    for (var i = 0; i < rows.length; i++) {
      if (nonSortable.some(function(n) { return n.index === i; })) {
        newOrder.push(nonSortable.filter(function(n) { return n.index === i; })[0].tr);
      } else {
        newOrder.push(sortable[nextSortable++].tr);
      }
    }
    newOrder.forEach(function(tr) { tbody.appendChild(tr); });
  }

  function updateSortIndicator(table, colIndex, dir) {
    var headerRow = table.querySelector('thead tr');
    var ths = headerRow.querySelectorAll('th');
    ths.forEach(function(th, i) {
      th.classList.remove('sort-asc', 'sort-desc');
      if (i === colIndex) {
        th.classList.add(dir === 1 ? 'sort-asc' : 'sort-desc');
      }
    });
  }

  function applyFilter(table) {
    var filterRow = table.querySelector('tr.table-sort-filter-row');
    if (!filterRow) return;
    var inputs = filterRow.querySelectorAll('input[data-col]');
    var filters = [];
    inputs.forEach(function(inp) {
      var col = parseInt(inp.getAttribute('data-col'), 10);
      var val = (inp.value || '').trim().toLowerCase();
      filters.push({ col: col, val: val });
    });
    var tbody = table.querySelector('tbody');
    var headerRow = table.querySelector('thead tr');
    var thCount = headerRow.querySelectorAll('th').length;
    tbody.querySelectorAll('tr').forEach(function(tr) {
      var tds = tr.querySelectorAll('td');
      if (tds.length !== thCount) {
        tr.style.display = '';
        return;
      }
      var show = true;
      filters.forEach(function(f) {
        if (f.val && (getSortValue(tds[f.col]) + '').toLowerCase().indexOf(f.val) === -1) {
          show = false;
        }
      });
      tr.style.display = show ? '' : 'none';
    });
  }

  function run() {
    document.querySelectorAll('table.table-sortable-filterable').forEach(initTable);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', run);
  } else {
    run();
  }
  document.addEventListener('turbo:load', run);
})();
