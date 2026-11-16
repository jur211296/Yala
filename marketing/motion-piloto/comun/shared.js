window.YALA = {
  // Estrellas planas de cuatro puntas, las de siempre: sin halo ni brillo. Giran unos grados.
  stars(kit) {
    const P = 'M50 0 C54 36 64 46 100 50 C64 54 54 64 50 100 C46 64 36 54 0 50 C36 46 46 36 50 0 Z';
    const S = [[64,92,46,-8,'main'],[968,470,40,12,'accent'],[70,980,58,6,'second'],[960,1240,66,-14,'main'],[96,1640,40,10,'accent'],[940,1800,46,-6,'second']];
    const els = S.map(([x,y,s,r,c]) => {
      const col = c === 'second' ? 'color-mix(in srgb, var(--second) 70%, var(--ground))' : 'var(--' + c + ')';
      const e = kit.h('<svg class="estrella" viewBox="0 0 100 100" style="left:' + x + 'px;top:' + y + 'px;width:' + s + 'px;height:' + s + 'px;color:' + col + '"><path d="' + P + '"/></svg>');
      kit.stage.append(e);
      return { e, r };
    });
    return (t) => { els.forEach((o, i) => { o.e.style.transform = 'rotate(' + (o.r + (i % 2 ? -1 : 1) * t * 1.6) + 'deg)'; }); };
  },
  // Parte una línea en palabras (line.split) y marca la que va subrayada.
  split(kit, el, accent) {
    // Un acento de dos palabras («al día») viaja como una sola, unido con un espacio de no separación.
    const acc = accent.replace(/ /g, ' ');
    accent = acc;
    const words = el.textContent.replace(accent.replace(/ /g, ' '), acc).split(' ');
    el.textContent = '';
    const spans = words.map((w) => {
      const [, pre, core, post] = w.match(/^([¿¡]*)(.*?)([?.,!]*)$/);
      const s = kit.el('span', { class: 'pal' });
      if (core === accent) {
        // Solo la palabra va subrayada y en color; los signos quedan fuera, en blanco.
        const u = kit.el('span', { class: 'pal u', text: core });
        const b = kit.el('span', { class: 'barra' });
        u.append(b);
        s.append(document.createTextNode(pre), u, document.createTextNode(post));
        s._bar = b;
      } else {
        s.textContent = w;
      }
      el.append(s, document.createTextNode(' '));
      return s;
    });
    return spans;
  },
  // La escena de toma de la serie: iPhone entero con la grabación real, frases que se relevan, cámara de pocos
  // grados y toques. c = { clip, tramos: [[desde, hasta, velocidad]], frases: [[entra, sale, texto, acento]],
  // cam: [[t, ry, rz, escala]], toques: [[t, fx, fy]], fin, entrada: 'fondo' | 'abajo' | 'derecha' }.
  toma(kit, c) {
    const { seg, eo, ei, eio, lerp } = kit;
    const fuente = (t) => {
      let acc = 0;
      for (const [a, b, v] of c.tramos) {
        const d = (b - a) / v;
        if (t <= acc + d) return a + Math.max(0, t - acc) * v;
        acc += d;
      }
      return c.tramos[c.tramos.length - 1][1] - 0.05;
    };
    const estrellas = window.YALA.stars(kit);
    const frase = kit.el('div', { class: 'words frase' });
    const lineas = c.frases.map(([, , texto, acento]) => {
      const h = kit.el('h2', { class: 'line', text: texto });
      frase.append(h);
      return window.YALA.split(kit, h, acento);
    });
    kit.stage.append(frase);
    const movil = kit.h('<div class="movil"><div class="pantalla"></div></div>');
    kit.stage.append(movil);
    const pantalla = movil.querySelector('.pantalla');
    const video = kit.video(c.clip, { start: 0 });
    pantalla.append(video);
    const toques = c.toques.map(([tt, fx, fy]) => {
      const e = kit.el('div', { class: 'toque', style: 'left:' + (fx * 620) + 'px;top:' + (fy * 1348) + 'px;opacity:0' });
      pantalla.append(e);
      return { e, tt };
    });
    return (t) => {
      estrellas(t);
      kit.seek(video, fuente(t));
      c.frases.forEach(([a, b], i) => window.YALA.words(kit, lineas[i], t, a, b));
      // Cámara: giros de pocos grados y transiciones lentas de 1,8 s.
      let ry = c.cam[0][1], rz = c.cam[0][2], s = c.cam[0][3];
      for (let i = 1; i < c.cam.length; i++) {
        const p = eio(seg(t, c.cam[i][0] - 0.9, c.cam[i][0] + 0.9));
        ry = lerp(ry, c.cam[i][1], p); rz = lerp(rz, c.cam[i][2], p); s = lerp(s, c.cam[i][3], p);
      }
      const pin = eo(seg(t, -0.8, 1.2));
      const pout = ei(seg(t, c.fin - 0.75, c.fin - 0.05));
      let tx = 0, ty = pout * 70;
      if (c.entrada === 'abajo') ty += (1 - pin) * 160;
      else if (c.entrada === 'derecha') tx = (1 - pin) * 220;
      else s *= lerp(0.9, 1, pin);
      s *= lerp(1, 0.86, pout);
      const drift = Math.sin(t * 2 * Math.PI / 6) * 0.6;
      movil.style.opacity = lerp(0.6, 1, pin) * (1 - pout);
      movil.style.transform = 'perspective(2400px) translate(' + tx + 'px,' + ty + 'px) rotateY(' + (ry + drift) + 'deg) rotateZ(' + rz + 'deg) scale(' + s + ')';
      toques.forEach(({ e, tt }) => {
        const p = seg(t, tt - 0.12, tt + 0.6);
        e.style.opacity = p <= 0 || p >= 1 ? 0 : (p < 0.25 ? p / 0.25 : 1 - eo((p - 0.25) / 0.75));
        e.style.transform = 'scale(' + lerp(0.7, 1.15, eo(p)) + ')';
      });
    };
  },
  // El cierre fijo de la serie: logo, lema con «esfuerzo» subrayado y la línea del App Store.
  cierre(kit) {
    const { seg, eo, eob, lerp } = kit;
    const estrellas = window.YALA.stars(kit);
    const logo = kit.el('img', { attrs: { src: kit.assets.url('logo.png'), alt: 'yala' }, style: 'position:absolute;left:330px;top:560px;width:420px;height:auto;transform-origin:50% 50%' });
    kit.stage.append(logo);
    const w = kit.h('<div class="words" style="left:60px;right:60px;top:1000px;align-items:center">' +
      '<p class="lema">Tus finanzas, sin esfuerzo.</p>' +
      '<p class="tienda">Disponible en el App Store</p></div>');
    kit.stage.append(w);
    const lema = window.YALA.split(kit, w.querySelector('.lema'), 'esfuerzo');
    const tienda = w.querySelector('.tienda').style;
    return (t) => {
      estrellas(t + kit.start);
      logo.style.opacity = eo(seg(t, 0.05, 0.3));
      logo.style.transform = 'scale(' + lerp(0.2, 1, eob(seg(t, 0.05, 0.75), 1.6)) * kit.breathe(t, 0.008, 3.2) + ')';
      window.YALA.words(kit, lema, t, 0.55, null);
      tienda.opacity = eo(seg(t, 1.3, 1.8));
      tienda.transform = 'translateY(' + lerp(20, 0, eo(seg(t, 1.3, 1.8))) + 'px)';
    };
  },
  // Entrada palabra a palabra desde abajo, salida rápida hacia arriba; la barra se dibuja al final.
  words(kit, spans, t, t0, tOut) {
    const { seg, eo, ei } = kit;
    spans.forEach((s, i) => {
      const pin = eo(seg(t, t0 + i * 0.11, t0 + i * 0.11 + 0.55));
      const pout = tOut == null ? 0 : ei(seg(t, tOut, tOut + 0.4));
      s.style.opacity = pin * (1 - pout);
      s.style.transform = 'translateY(' + ((1 - pin) * 28 - pout * 22) + 'px)';
      if (s._bar) s._bar.style.transform = 'scaleX(' + eo(seg(t, t0 + spans.length * 0.11 + 0.35, t0 + spans.length * 0.11 + 0.85)) + ')';
    });
  },
};
