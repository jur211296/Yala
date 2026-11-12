kit.score(function (S, T) {
  const BPM = 100;
  S.tempo(BPM, { t0: 0 });
  S.program('pad', 'pad', { rev: 0.6, gain: -4 });
  S.program('keys', 'ep', { gain: -3 });
  S.program('bass', 'bass');
  S.program('mallet', 'marimba', { pan: 0.2 });
  S.note('pad', 'D3', { beat: 0, beats: 4, vel: 34 });
  S.note('mallet', 'A5', { t: 0, dur: 0.6, vel: 40 });
  const prog = [['D3', 'A3', 'D4', 'F#4'], ['B2', 'F#3', 'B3', 'D4'], ['G2', 'D3', 'G3', 'B3'], ['A2', 'E3', 'A3', 'C#4'], ['D3', 'A3', 'D4', 'F#4']];
  prog.forEach((c, i) => {
    S.chord('keys', c, { beat: 4 + i * 4, beats: 3.5, vel: 46 });
    S.note('bass', c[0].replace(/\d/, (n) => String(Number(n) - 1)), { beat: 4 + i * 4, beats: 1.5, vel: 70 });
    S.note('bass', c[1].replace(/\d/, (n) => String(Number(n) - 1)), { beat: 6 + i * 4, beats: 1, vel: 60 });
  });
  S.pattern('mallet', 'x.x.X.x.', { from: 8, repeat: 4, pitch: ['D5', 'A4', 'F#5', 'A4'], vel: 52 });
  S.drums({ kick: 'x...x...', sidestick: '..x...x.', hat: 'oxoxoxox' }, { from: 8, repeat: 4, vel: 70 });
  S.drums({ shaker: 'xxxxxxxx' }, { from: 4, repeat: 1, vel: 40 });
  S.fx('pop', T.toma + 2.45, { vel: 70 });
  S.fx('pop', T.toma + 4.2, { vel: 64 });
  S.fx('click', T.toma + 10.25, { vel: 70 });
  S.fx('chime', T.toma + 10.45, { vel: 60 });
  S.fx('revswell', T.cierre, { dur: 1.0, vel: 50 });
  S.chord('keys', ['D3', 'A3', 'D4', 'F#4', 'A4'], { t: T.cierre, dur: 3.2, vel: 60 });
  S.note('bass', 'D2', { t: T.cierre, dur: 2.5, vel: 76 });
  S.drum('kick', { t: T.cierre, vel: 90 });
  S.run('mallet', ['D5', 'F#5', 'A5', 'D6'], { t: T.cierre + 0.55, step: 0.14, vel: 50, cresc: 6 });
  S.master({ gain: -6, fadeOut: 1.4 });
});
