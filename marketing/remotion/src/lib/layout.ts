import { Easing, interpolate } from "remotion";
import type { Shot } from "../brand/copy";
import { yala } from "../brand/tokens";

/**
 * Encuadre y CÁMARA.
 *
 * Va aparte de tokens.ts a propósito: tokens es la MARCA (lo que no cambia
 * entre piezas) y esto es el ENCUADRE (lo que se recalcula con el lienzo).
 */

/**
 * Zonas que Instagram tapa con su propia UI en Reels, medidas sobre 1080×1920.
 * El footage va a sangre por debajo; lo que se respeta es que **ningún texto y
 * ningún gesto clave** caiga dentro.
 */
export const REELS_SAFE = { top: 220, bottom: 400, side: 64 } as const;

export type Crop = { top?: number; bottom?: number };

/** Alto visible del origen una vez aplicado el recorte, en fracción (0–1). */
export const visibleFraction = (crop?: Crop) =>
  1 - (crop?.top ?? 0) - (crop?.bottom ?? 0);

/**
 * Cuánto tarda la cámara en viajar de un plano al siguiente, en segundos.
 * Lo que sobra del tramo, el plano se SOSTIENE.
 */
export const CAMERA_MOVE_SEC = 0.65;

/**
 * Interpola la lista de planos en el frame actual.
 *
 * Dos cosas, y la primera costó una versión entera:
 *
 * 1. **La cámara se sostiene y luego viaja.** Interpolar de un `atSec` al
 *    siguiente sin parar suena razonable y es justo lo que rompe la pieza:
 *    la cámara está SIEMPRE en tránsito, así que ningún encuadre llega a
 *    leerse. Medido — a 0,9 s la vista ya iba por la mitad del camino al plano
 *    de 1,7 s y de los tres chips solo se veía uno. Aquí cada plano se queda
 *    quieto y el viaje ocupa solo los últimos `CAMERA_MOVE_SEC`.
 * 2. **`inOut(cubic)`**, no lineal: una cámara que arranca y para en seco se
 *    lee como un salto de vídeo roto, no como un movimiento.
 */
export const cameraAt = (shots: Shot[], frame: number) => {
  if (shots.length === 0) return { focusY: 0.5, scale: 1, tiltDeg: 0 };
  if (shots.length === 1) {
    return { focusY: shots[0].focusY, scale: shots[0].scale, tiltDeg: 0 };
  }

  const fps = yala.motion.fps;
  const move = Math.round(CAMERA_MOVE_SEC * fps);

  const times: number[] = [];
  const focus: number[] = [];
  const scale: number[] = [];

  shots.forEach((shot, i) => {
    const at = Math.round(shot.atSec * fps);
    if (i === 0) {
      times.push(at);
      focus.push(shot.focusY);
      scale.push(shot.scale);
      return;
    }
    // El plano anterior se sostiene hasta `move` frames antes de este.
    const holdUntil = Math.max(at - move, times[times.length - 1] + 1);
    times.push(holdUntil);
    focus.push(shots[i - 1].focusY);
    scale.push(shots[i - 1].scale);

    times.push(Math.max(at, holdUntil + 1));
    focus.push(shot.focusY);
    scale.push(shot.scale);
  });

  const opts = {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.cubic),
  } as const;

  const focusY = interpolate(frame, times, focus, opts);
  const sc = interpolate(frame, times, scale, opts);

  // Un balanceo lento y continuo, como si el teléfono estuviera en una mano
  // y no atornillado al fondo. Amplitud pequeña: se nota, no se ve.
  const tiltDeg = Math.sin(frame / 38) * 3.2;

  return { focusY, scale: sc, tiltDeg };
};

/**
 * El iPhone en 9:16.
 *
 * Ya no hay caja que recorte la pantalla: el teléfono se dibuja ENTERO, con su
 * marco, y la cámara lo escala y lo desplaza como un objeto. Cuando la cámara
 * se acerca, el iPhone crece y se sale por arriba y por abajo — que es lo que
 * hace una cámara de verdad — pero nunca deja de tener forma de iPhone.
 *
 * La versión anterior recortaba la pantalla en una caja de 940×1000 y Jürgen
 * la tumbó: sin el marco, un trozo de UI no se lee como «un teléfono», se lee
 * como una captura pegada.
 */
export const PHONE = {
  /** Ancho de la pantalla a escala 1. El marco suma `bezel` a cada lado. */
  screenWidth: 690,
  bezel: 16,
  /** Radio exterior; el de la pantalla es `radius - bezel`. */
  radius: 108,
  /** Dynamic Island. */
  island: { width: 190, height: 54, top: 22 },
} as const;

/**
 * Dónde mira la cámara en el lienzo. No es el centro: está más abajo para que
 * el texto tenga su banda arriba, siempre sobre fondo oscuro.
 */
export const REELS_CAMERA = { centerY: 1210, phoneTop: 520 } as const;

/** Dónde se sienta el texto en 9:16. */
export const REELS_TEXT = { top: 230, bottom: 420 } as const;

/** Alto total del teléfono (marco incluido) para un ancho de pantalla dado. */
export const phoneHeight = (
  screenWidth: number,
  source: { w: number; h: number },
  crop?: Crop,
) => (screenWidth * source.h * visibleFraction(crop)) / source.w + PHONE.bezel * 2;

/**
 * Transform de la cámara sobre el teléfono entero.
 *
 * `focusY` es la fracción del alto del teléfono que debe quedar en
 * `REELS_CAMERA.centerY`. Se escala desde el centro del teléfono y se traslada
 * lo que haga falta para llevar ese punto al centro de la cámara.
 */
export const phoneTransform = ({
  focusY,
  scale,
  phoneH,
  phoneTop,
  centerY,
  tiltDeg,
}: {
  focusY: number;
  scale: number;
  phoneH: number;
  phoneTop: number;
  centerY: number;
  tiltDeg: number;
}) => {
  // Punto de foco en coordenadas del lienzo, a escala 1.
  const focusCanvasY = phoneTop + focusY * phoneH;
  const phoneCenterY = phoneTop + phoneH / 2;
  // Tras escalar desde el centro, el punto de foco queda aquí:
  const focusAfterScale = phoneCenterY + (focusCanvasY - phoneCenterY) * scale;
  const translateY = centerY - focusAfterScale;

  return `perspective(2400px) translateY(${translateY}px) scale(${scale}) rotateY(${tiltDeg}deg)`;
};

/** Encuadre 16:9: el teléfono a la izquierda, la columna de texto a la derecha. */
export const WIDE_COPY = { left: 760, right: 110 } as const;

export const canvasOf = (aspect: "9x16" | "16x9") =>
  aspect === "9x16" ? yala.canvas.reels : yala.canvas.youtube;
