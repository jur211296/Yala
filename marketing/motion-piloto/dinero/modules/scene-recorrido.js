// «¿A dónde va tu dinero?»: solo capturas reales de 2.2 (semilla de la ficha), sin grabación.
const { seg, eo, ei, eio, lerp } = kit;
const FRASES = [[-0.7, 4.4, '¿A dónde se fue tu dinero?', 'dinero'], [4.8, 9.4, 'Tu balance, de un vistazo', 'vistazo'], [10.0, 14.7, 'Ves a dónde va cada sol', 'sol']];
const CAM = [[0, -4, 1, 1], [4.8, 4, 0, 1.02], [10.0, -3, -1, 1.03]];
const K = 620 / 1206; // escala de la captura dentro de la pantalla del teléfono
// Recortes de la captura (px de la captura) que salen ampliados: [imagen, x, y, w, h, entra, sale, top destino].
const RECORTES = [['panel.jpg', 30, 400, 1146, 380, 5.5, 9.0, 760], ['estadisticas.jpg', 44, 510, 1121, 1005, 10.9, 14.4, 690]];
const CAMBIO = 9.7; // el Panel da paso a Estadísticas
const TOQUE = [9.45, 0.326, 0.955];
kit.scene('recorrido', {
  init(kit) {
    this.estrellas = window.YALA.stars(kit);
    const frase = kit.el('div', { class: 'words frase' });
    this.lineas = FRASES.map(([, , texto, acento]) => {
      const h = kit.el('h2', { class: 'line', text: texto });
      frase.append(h);
      return window.YALA.split(kit, h, acento);
    });
    kit.stage.append(frase);
    this.movil = kit.h('<div class="movil"><div class="pantalla"></div></div>');
    kit.stage.append(this.movil);
    const pantalla = this.movil.querySelector('.pantalla');
    this.panel = kit.el('img', { attrs: { src: kit.assets.url('panel.jpg'), alt: '' } });
    this.estad = kit.el('img', { attrs: { src: kit.assets.url('estadisticas.jpg'), alt: '' } });
    this.toque = kit.el('div', { class: 'toque', style: 'left:' + (TOQUE[1] * 620) + 'px;top:' + (TOQUE[2] * 1348) + 'px;opacity:0' });
    pantalla.append(this.panel, this.estad, this.toque);
    this.recortes = RECORTES.map(([img, x, y, w, h, a, b, top]) => {
      const W = 960, k = W / w;
      const el = kit.el('div', { class: 'recorte', style: 'left:60px;top:' + top + 'px;width:' + W + 'px;height:' + Math.round(h * k) + 'px;opacity:0' });
      el.append(kit.el('img', { attrs: { src: kit.assets.url(img), alt: '' }, style: 'left:' + (-x * k) + 'px;top:' + (-y * k) + 'px;width:' + (1206 * k) + 'px' }));
      kit.stage.append(el);
      // De dónde sale: el mismo trozo dentro de la pantalla del teléfono, sin girar.
      return { el, a, b, dx: 230 + x * K - 60, dy: 536 + y * K - top, s0: (w * K) / W };
    });
  },
  render(t) {
    this.estrellas(t);
    FRASES.forEach(([a, b], i) => window.YALA.words(kit, this.lineas[i], t, a, b));
    let ry = CAM[0][1], rz = CAM[0][2], s = CAM[0][3];
    for (let i = 1; i < CAM.length; i++) {
      const p = eio(seg(t, CAM[i][0] - 0.9, CAM[i][0] + 0.9));
      ry = lerp(ry, CAM[i][1], p); rz = lerp(rz, CAM[i][2], p); s = lerp(s, CAM[i][3], p);
    }
    const pin = eo(seg(t, -0.8, 1.2)), pout = ei(seg(t, kit.dur - 0.75, kit.dur - 0.05));
    // Mientras un recorte está fuera, el teléfono se aparta un poco para que se lea el recorte.
    let foco = 0;
    const recs = this.recortes.map((r) => {
      const pi = eo(seg(t, r.a, r.a + 0.8)), po = ei(seg(t, r.b, r.b + 0.6));
      foco = Math.max(foco, pi * (1 - po));
      return [r, pi, po];
    });
    const drift = Math.sin(t * 2 * Math.PI / 6) * 0.6;
    s *= lerp(1, 0.86, pout);
    this.movil.style.opacity = lerp(0.6, 1, pin) * (1 - pout) * lerp(1, 0.45, foco);
    this.movil.style.transform = 'perspective(2400px) translate(' + ((1 - pin) * 220) + 'px,' + (pout * 70) + 'px) rotateY(' + (ry + drift) + 'deg) rotateZ(' + rz + 'deg) scale(' + s + ')';
    recs.forEach(([r, pi, po]) => {
      // Sale del teléfono y crece hasta su sitio; al volver, se encoge hacia el mismo punto.
      const p = pi * (1 - po);
      const sc = lerp(r.s0, 1, p) * kit.breathe(t, 0.004, 3.4);
      r.el.style.opacity = Math.min(1, p * 2.5);
      r.el.style.transform = 'translate(' + lerp(r.dx, 0, p) + 'px,' + lerp(r.dy, 0, p) + 'px) scale(' + sc + ')';
    });
    const pc = eio(seg(t, CAMBIO, CAMBIO + 0.6));
    this.estad.style.opacity = pc;
    this.estad.style.transform = 'translateY(' + lerp(40, 0, pc) + 'px)';
    const pt = seg(t, TOQUE[0] - 0.12, TOQUE[0] + 0.6);
    this.toque.style.opacity = pt <= 0 || pt >= 1 ? 0 : (pt < 0.25 ? pt / 0.25 : 1 - eo((pt - 0.25) / 0.75));
    this.toque.style.transform = 'scale(' + lerp(0.7, 1.15, eo(pt)) + ')';
  },
});
