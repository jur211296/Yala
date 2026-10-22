import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import type { Beat } from "../brand/copy";
import { FONT_STACK } from "../brand/font";
import { yala } from "../brand/tokens";

/**
 * El texto de la pieza. Es lo que se LEE sin sonido, así que manda.
 *
 * Tres cosas que lo separan de un rótulo normal y que son justo las que hacen
 * que pare el scroll:
 *  1. **Entra por palabras**, con la siguiente medio paso por detrás. Un
 *     bloque que aparece entero se lee como una diapositiva.
 *  2. **Barra de acento** que crece debajo. Da dirección y ocupa espacio.
 *  3. **Scrim propio** detrás. El footage de la app es claro; sin scrim el
 *     texto blanco se pierde en cuanto la pantalla enseña una tarjeta blanca.
 */
export const AppleTitle: React.FC<{
  text: string;
  style: Beat["style"];
  place: Beat["place"];
  tone?: Beat["tone"];
  /** Escala tipográfica del lienzo; 1 = 9:16, ~1,1 = 16:9. */
  typeScale?: number;
  align?: "center" | "left";
}> = ({ text, style, place, tone = "neutral", typeScale = 1, align = "center" }) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  const accent = tone === "gasto" ? yala.color.pink : yala.color.indigo;
  const words = text.split(" ");

  const size =
    style === "hero"
      ? yala.type.heroPx * typeScale
      : style === "line"
        ? yala.type.linePx * typeScale
        : yala.type.calloutPx * typeScale;

  // Salida rápida: el texto se va antes de que el siguiente entre, para que
  // nunca haya dos beats peleando por el mismo sitio.
  const out = interpolate(
    frame,
    [durationInFrames - yala.motion.titleOut, durationInFrames],
    [1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );

  // La barra de acento arranca cuando ya entró la primera palabra.
  const bar = spring({
    frame: frame - 3,
    fps,
    config: { damping: 16, mass: 0.5, stiffness: 110 },
  });

  return (
    <div
      style={{
        position: "relative",
        display: "flex",
        flexDirection: "column",
        alignItems: align === "center" ? "center" : "flex-start",
        gap: size * 0.26,
        padding: `${size * 0.5}px ${size * 0.45}px`,
        opacity: out,
      }}
    >
      <Scrim place={place} accent={accent} intense={style === "hero"} />

      <div
        style={{
          position: "relative",
          display: "flex",
          flexWrap: "wrap",
          justifyContent: align === "center" ? "center" : "flex-start",
          columnGap: size * 0.26,
          rowGap: size * 0.06,
        }}
      >
        {words.map((word, i) => (
          <Word
            key={`${word}-${i}`}
            word={word}
            delay={i * 2}
            size={size}
            bold={style === "hero"}
            fps={fps}
          />
        ))}
      </div>

      {style !== "pill" ? (
        <div
          style={{
            position: "relative",
            height: Math.max(6, size * 0.075),
            width: bar * size * (style === "hero" ? 2.6 : 1.8),
            borderRadius: 999,
            background: accent,
            boxShadow: `0 0 ${size * 0.5}px ${accent}`,
          }}
        />
      ) : null}
    </div>
  );
};

const Word: React.FC<{
  word: string;
  delay: number;
  size: number;
  bold: boolean;
  fps: number;
}> = ({ word, delay, size, bold, fps }) => {
  const frame = useCurrentFrame();
  const enter = spring({
    frame: frame - delay,
    fps,
    config: yala.motion.springTitle,
  });

  return (
    <span
      style={{
        display: "inline-block",
        fontFamily: FONT_STACK,
        fontWeight: bold ? 800 : 700,
        fontSize: size,
        lineHeight: 1.02,
        letterSpacing: bold ? "-0.045em" : "-0.03em",
        color: yala.color.white,
        textShadow: "0 4px 40px rgba(0,0,0,0.65)",
        opacity: enter,
        transform: `translateY(${(1 - enter) * size * 0.5}px) scale(${interpolate(
          enter,
          [0, 1],
          [0.88, 1],
        )})`,
      }}
    >
      {word}
    </span>
  );
};

/**
 * Mancha oscura local detrás del texto.
 *
 * No es un degradado desde el borde: el texto se sienta tanto sobre el fondo
 * negro (arriba) como sobre el teléfono (abajo, como lower third), y una banda
 * anclada al borde solo sirve para uno de los dos. Una elipse centrada en el
 * texto es invisible sobre negro y lo rescata sobre una tarjeta blanca.
 */
const Scrim: React.FC<{
  place: Beat["place"];
  accent: string;
  intense: boolean;
}> = ({ accent, intense }) => (
  <div
    style={{
      position: "absolute",
      left: -260,
      right: -260,
      top: -120,
      bottom: -120,
      background: `radial-gradient(ellipse at center, ${yala.color.bg}${
        intense ? "F5" : "EB"
      } 0%, ${yala.color.bg}D9 42%, ${accent}0F 66%, transparent 80%)`,
      pointerEvents: "none",
    }}
  />
);
