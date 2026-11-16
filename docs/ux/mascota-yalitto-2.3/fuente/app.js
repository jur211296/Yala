(function () {
  var body = document.body;
  if (/quieto/.test(location.search + location.hash)) { body.classList.add('rm'); }
  // ?solo=<sección> deja solo esa sección (para revisar el documento por partes).
  var solo = /solo=(\w+)/.exec(location.search);
  if (solo) { document.querySelectorAll('body > section, body > header').forEach(function (s) { if (s.id !== solo[1]) { s.style.display = 'none'; } }); }
  // Selector de dirección: cambia qué Yalitto se ve en maquetas y prototipos.
  document.querySelectorAll('.sel-dirs button').forEach(function (b) {
    b.addEventListener('click', function () {
      body.className = body.className.replace(/dir-\w+/, 'dir-' + b.dataset.dir);
      document.querySelectorAll('.sel-dirs button').forEach(function (x) { x.classList.toggle('on', x === b); });
    });
  });
  document.getElementById('rm').addEventListener('change', function (e) { body.classList.toggle('rm', e.target.checked); });
  document.getElementById('slow').addEventListener('change', function (e) { body.classList.toggle('slow', e.target.checked); });
  // Configurador: forma × color de la dirección A.
  var forma = null, color = null;
  function pinta() {
    document.querySelectorAll('.cfg-y').forEach(function (y) {
      y.classList.toggle('on', y.dataset.f === forma && y.dataset.c === color);
    });
  }
  var fb = document.querySelectorAll('.cfg-forms button'), cb = document.querySelectorAll('.cfg-colors button');
  if (fb.length && cb.length) {
    forma = fb[0].dataset.f; color = cb[0].dataset.c; pinta();
    fb.forEach(function (b) { b.addEventListener('click', function () { forma = b.dataset.f; fb.forEach(function (x) { x.classList.toggle('on', x === b); }); pinta(); }); });
    cb.forEach(function (b) { b.addEventListener('click', function () { color = b.dataset.c; cb.forEach(function (x) { x.classList.toggle('on', x === b); }); pinta(); }); });
  }
})();
