/* «قصة المنتج» — feeding calculator, tile → section, phone-first folding. */
(function () {
  'use strict';
  var root = document.getElementById('zbs');
  if (!root) return;

  // Phones: every section starts folded except the feeding guide (the
  // question that decides the purchase). Desktop keeps them all open.
  if (window.matchMedia('(max-width: 768px)').matches) {
    root.querySelectorAll('details.zbs-sec').forEach(function (d) {
      if (!d.classList.contains('zbs-feeding')) d.removeAttribute('open');
    });
  }

  // A tile opens its section and glides to it.
  root.querySelectorAll('a.zbs-tile').forEach(function (a) {
    a.addEventListener('click', function (e) {
      var target = document.getElementById(a.getAttribute('href').slice(1));
      if (!target) return;
      e.preventDefault();
      target.setAttribute('open', '');
      var smooth = !window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      target.scrollIntoView({ behavior: smooth ? 'smooth' : 'auto', block: 'start' });
      if (history.replaceState) history.replaceState(null, '', '#' + target.id);
    });
  });

  // The «كل التفاصيل» link beside the price.
  document.querySelectorAll('a.zbs-jump').forEach(function (a) {
    a.addEventListener('click', function (e) {
      e.preventDefault();
      root.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  });

  // Calculator: one weight at a time.
  root.querySelectorAll('[data-zbs-calc]').forEach(function (calc) {
    var buttons = calc.querySelectorAll('.zbs-calc-w button');
    var rows = calc.querySelectorAll('.zbs-calc-r');
    buttons.forEach(function (b) {
      b.addEventListener('click', function () {
        var i = b.getAttribute('data-i');
        buttons.forEach(function (x) { x.setAttribute('aria-pressed', x === b ? 'true' : 'false'); });
        rows.forEach(function (r) { r.hidden = r.getAttribute('data-i') !== i; });
      });
    });
  });

  // Arriving on #zbs-… opens that section.
  if (location.hash.indexOf('#zbs-') === 0) {
    var t = document.getElementById(location.hash.slice(1));
    if (t && t.tagName === 'DETAILS') t.setAttribute('open', '');
  }
})();
