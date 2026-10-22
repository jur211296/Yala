import { interpolate, spring } from "remotion";
import { yala } from "../brand/tokens";

export const FPS = yala.motion.fps;

/** Segundos → frames. Los guiones se escriben en segundos; el motor cuenta frames. */
export const sec = (s: number) => Math.round(s * FPS);

/** Tramo del guion en segundos → `{ from, durationInFrames }` para un <Sequence>. */
export const cue = (fromSec: number, toSec: number) => ({
  from: sec(fromSec),
  durationInFrames: Math.max(1, sec(toSec) - sec(fromSec)),
});

/**
 * Entrada tipo Apple: spring de posición + opacidad, y salida por fade.
 * Devuelve 0→1 de presencia y el desplazamiento en px que le acompaña.
 *
 * `frame` es LOCAL a la secuencia (el que da useCurrentFrame dentro de ella).
 */
export const titleMotion = ({
  frame,
  fps,
  durationInFrames,
  travelPx = 28,
}: {
  frame: number;
  fps: number;
  durationInFrames: number;
  travelPx?: number;
}) => {
  const enter = spring({
    frame,
    fps,
    config: yala.motion.springTitle,
    durationInFrames: Math.min(durationInFrames, yala.motion.titleIn + 12),
  });

  const exit = interpolate(
    frame,
    [durationInFrames - yala.motion.titleOut, durationInFrames],
    [1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );

  return {
    opacity: enter * exit,
    translateY: (1 - enter) * travelPx,
    scale: interpolate(enter, [0, 1], [0.96, 1]),
  };
};

/** Fade simétrico de `fadeFrames` en los dos extremos de una secuencia. */
export const edgeFade = (frame: number, durationInFrames: number) => {
  const f = yala.motion.fadeFrames;
  return interpolate(
    frame,
    [0, f, Math.max(f + 1, durationInFrames - f), durationInFrames],
    [0, 1, 1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );
};
