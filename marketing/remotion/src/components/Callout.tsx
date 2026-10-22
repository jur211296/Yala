import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import type { Beat } from "../brand/copy";
import { FONT_STACK } from "../brand/font";
import { glass, yala } from "../brand/tokens";

/**
 * Píldora de cristal que etiqueta lo que el producto ACABA de enseñar.
 *
 * Nunca se adelanta al resultado: si la píldora dice «ya está» antes de que la
 * pantalla lo muestre, la pieza promete en vez de demostrar.
 *
 * Entra con rebote (`overshootClamping: false`) y no con un fade. En un feed un
 * fade de medio segundo es medio segundo en el que no pasa nada.
 */
export const Callout: React.FC<{
  text: string;
  tone?: Beat["tone"];
  typeScale?: number;
}> = ({ text, tone = "neutral", typeScale = 1 }) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  const enter = spring({
    frame,
    fps,
    config: { damping: 11, mass: 0.45, stiffness: 170 },
  });
  const out = interpolate(
    frame,
    [durationInFrames - yala.motion.titleOut, durationInFrames],
    [1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );

  const accent = tone === "gasto" ? yala.color.pink : yala.color.teal;
  const size = yala.type.calloutPx * typeScale;

  // Pulso lento del halo: mantiene vivo el elemento mientras se lee.
  const pulse = 0.5 + 0.5 * Math.sin((frame / fps) * 3.4);

  return (
    <div
      style={{
        display: "flex",
        justifyContent: "center",
        opacity: out,
        transform: `translateY(${(1 - enter) * 46}px) scale(${interpolate(
          enter,
          [0, 1],
          [0.82, 1],
        )})`,
      }}
    >
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: size * 0.55,
          padding: `${size * 0.55}px ${size * 0.95}px`,
          borderRadius: 999,
          background: glass.panelStrong,
          border: `2px solid ${accent}80`,
          boxShadow: `${glass.shadow}, 0 0 ${60 + pulse * 40}px ${accent}44`,
          backdropFilter: "blur(24px) saturate(150%)",
          WebkitBackdropFilter: "blur(24px) saturate(150%)",
        }}
      >
        <span
          style={{
            width: size * 0.4,
            height: size * 0.4,
            borderRadius: 999,
            background: accent,
            boxShadow: `0 0 ${size * (0.5 + pulse * 0.5)}px ${accent}`,
            flexShrink: 0,
          }}
        />
        <span
          style={{
            fontFamily: FONT_STACK,
            fontWeight: 700,
            fontSize: size,
            letterSpacing: "-0.02em",
            color: yala.color.white,
            whiteSpace: "nowrap",
          }}
        >
          {text}
        </span>
      </div>
    </div>
  );
};
