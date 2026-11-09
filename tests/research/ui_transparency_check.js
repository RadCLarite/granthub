(function () {
  var root = document.getElementById('v-research');
  if (!root) throw new Error('#v-research not found');
  var offenders = [];
  var sel = '#v-research, #v-research *, #tour-next, #tour-next *, .tour-card, .tour-card *, .receipt, .receipt *, .rip-toast, .rip-toast *';
  var nodes = document.querySelectorAll(sel);
  function alphaOf(c) {
    var m = /^rgba?\(([^)]+)\)$/.exec(c);
    if (!m) return c === 'transparent' ? 0 : 1;
    var p = m[1].split(/[ ,\/]+/).filter(Boolean);
    return p.length > 3 ? parseFloat(p[3]) : 1;
  }
  function visible(el) {
    var r = el.getBoundingClientRect();
    if (r.width === 0 || r.height === 0) return false;
    for (var e = el; e && e.nodeType === 1; e = e.parentElement) {
      var s = getComputedStyle(e);
      if (s.display === 'none' || s.visibility === 'hidden' || e.hidden) return false;
    }
    return true;
  }
  function describe(el) {
    return el.tagName.toLowerCase() + (el.id ? '#' + el.id : '') + (el.className && typeof el.className === 'string' ? '.' + el.className.trim().split(/\s+/).join('.') : '');
  }
  for (var i = 0; i < nodes.length; i++) {
    var el = nodes[i];
    if (!visible(el)) continue;
    var cs = getComputedStyle(el);
    if (alphaOf(cs.backgroundColor) !== 0) continue;
    var floating = cs.position === 'fixed' || cs.position === 'absolute' || cs.position === 'sticky';
    var container = /(^|\s)(rt-card|rt-panel|rt-filters|rt-empty)(\s|$)/.test(el.className || '') || el.classList.contains('tour-card') || el.classList.contains('receipt') || el.classList.contains('rip-toast') || el.id === 'tour-next';
    var hasText = false;
    if (container) hasText = /\S/.test(el.textContent);
    else for (var c = el.firstChild; c; c = c.nextSibling) if (c.nodeType === 3 && /\S/.test(c.nodeValue)) { hasText = true; break; }
    if (!hasText) continue;
    if (floating || container) offenders.push(describe(el) + ' [' + cs.position + '] "' + el.textContent.trim().slice(0, 40) + '"');
  }
  return offenders;
})()
