// Reel «Registro por voz»: misma toma, frases y tiempos que el reel v3 del 13-oct.
kit.scene('toma', {
  init(kit) {
    this.r = window.YALA.toma(kit, {
      clip: 'cfr-voz.mp4',
      // [desde, hasta, velocidad] en segundos de la grabación: 1x en los gestos, acelerada en las esperas.
      tramos: [[6.3, 9.6, 1], [9.6, 20.8, 2.5], [20.8, 23.2, 1], [23.2, 32.4, 4], [32.4, 35.5, 1]],
      frases: [[-0.7, 5.5, '¿Sin tiempo para anotar?', 'anotar'], [5.95, 9.8, 'Díselo como siempre', 'siempre'], [10.25, 15.3, 'Revisa y listo', 'listo']],
      cam: [[0, 5, -1, 1], [5.9, -5, 1, 1.02], [10.2, 3, 0, 1.03]],
      toques: [[2.95, 0.5, 0.331], [12.98, 0.724, 0.91]],
      fin: kit.dur,
      entrada: 'fondo',
    });
  },
  render(t) { this.r(t); },
});
