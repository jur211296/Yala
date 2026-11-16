// Reel «Foto a la boleta»: misma toma, frases y tiempos que el reel v3 del 13-oct.
kit.scene('toma', {
  init(kit) {
    this.r = window.YALA.toma(kit, {
      clip: 'toma-foto.mp4',
      tramos: [[0.8, 3.6, 1], [3.6, 5.7, 2], [5.7, 9.7, 1], [9.7, 12.4, 1.5], [12.4, 17.2, 1]],
      frases: [[-0.7, 4.4, '¿Boletas para después?', 'después'], [4.8, 9.3, 'Yala la lee por ti', 'lee'], [9.7, 14.2, 'Tu saldo, ya al día', 'al día']],
      cam: [[0, -5, 1, 1], [4.75, 5, 0, 1.02], [9.65, -3, -1, 1.03]],
      toques: [[2.45, 0.598, 0.331], [4.2, 0.27, 0.69], [10.25, 0.725, 0.905]],
      fin: kit.dur,
      entrada: 'abajo',
    });
  },
  render(t) { this.r(t); },
});
