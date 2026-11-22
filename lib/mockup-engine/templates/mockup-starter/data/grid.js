// gridMove: where the active cell of an ARIA grid goes for a key (the WAI-ARIA grid pattern's
// keyboard model). A data helper (skills/mockup/references/mockup-conventions.md, "Data helpers"): a pure
// function on window, no DOM. The grid component renders tabindex="0" on the active cell and "-1"
// on the others (roving tabindex, so the grid is one Tab stop); the page keeps the active cell in
// state and its keydown action calls this, then moves focus with ctx.focus.
//
// window.gridMove({ row, col }, { key, ctrlKey, metaKey }, { rows, cols }) -> { row, col } or null
//   ArrowRight, ArrowLeft, ArrowDown, ArrowUp   one cell, stopping at the edges (no wrap)
//   Home, End                                   first or last cell of the row
//   Ctrl+Home, Ctrl+End (Cmd on a Mac)          first cell of the first row, last of the last
//   PageDown, PageUp                            last or first row, same column
// null for any other key, so the action returns false and the page does not re-render.
// In the app this is a util the grid component's keydown handler calls.
(function () {
  'use strict';

  function gridMove(cell, event, size) {
    const last = { row: size.rows - 1, col: size.cols - 1 };
    const clamp = (row, col) => ({ row: Math.min(Math.max(row, 0), last.row), col: Math.min(Math.max(col, 0), last.col) });
    const { row, col } = cell;
    const ctrl = event.ctrlKey || event.metaKey;
    switch (event.key) {
      case 'ArrowRight': return clamp(row, col + 1);
      case 'ArrowLeft': return clamp(row, col - 1);
      case 'ArrowDown': return clamp(row + 1, col);
      case 'ArrowUp': return clamp(row - 1, col);
      case 'Home': return ctrl ? clamp(0, 0) : clamp(row, 0);
      case 'End': return ctrl ? clamp(last.row, last.col) : clamp(row, last.col);
      case 'PageDown': return clamp(last.row, col);
      case 'PageUp': return clamp(0, col);
      default: return null;
    }
  }

  window.gridMove = gridMove;
}());
