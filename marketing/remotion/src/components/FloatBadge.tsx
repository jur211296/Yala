import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import type { Beat } from "../brand/copy";
import { FONT_STACK } from "../brand/font";
import { glass, yala } from "../brand/tokens";

/**
 * Una tarjeta que SALE de la pantalla del teléfono en el momento clave.
 *
 * Repite un dato que la app ya está enseñando —el monto, la categoría— y lo
 * saca al primer plano, grande, con volumen. No inventa nada: si no está en el
 * footage, no va aquí. Es el recurso que separa «una captura con rótulos» de
 * «una pieza», y por eso se usa UNA vez por pieza, en el golpe, no en cada beat.
 */
export const FloatBadge: React.FC<{
  text: string;
  sub?: string;
  tone?: Beat["tone"];
}> = ({ text, sub, tone = "gasto" }) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  const enter = spring({ frame, fps, config: { damping: 12, mass: 0.6, stiffness: 140 } });
  const out = interpolate(
    frame,
    [durationInFrames - yala.motion.titleOut, durationInFrames],
    [1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );
  const hover = Math.sin(frame / 14) * 6;
  const accent = tone === "gasto" ? yala.color.pink : yala.color.teal;

  return (
    <div
      style={{
        opacity: enter * out,
        transform: `perspective(1600px) translateY(${(1 - enter) * 120 + hover}px) translateX(${(1 - enter) * -60}px) rotateY(-14deg) rotateX(${6 - enter * 4}deg) rotate(-4deg) scale(${interpolate(enter, [0, 1], [0.7, 1])})`,
        transformOrigin: "left center",
      }}
    >
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          gap: 10,
          padding: "34px 44px 30px",
          borderRadius: 40,
          background: `linear-gradient(160deg, rgba(20,20,40,0.94), rgba(8,8,20,0.92))`,
          border: `2px solid ${accent}AA`,
          boxShadow: `${glass.shadow}, 0 0 90px ${accent}55, inset 0 1px 0 rgba(255,255,255,0.18)`,
          backdropFilter: "blur(30px) saturate(160%)",
          WebkitBackdropFilter: "blur(30px) saturate(160%)",
        }}
      >
        <div
          style={{
            fontFamily: FONT_STACK,
            fontWeight: 800,
            fontSize: 96,
            lineHeight: 1,
            letterSpacing: "-0.045em",
            color: accent,
            textShadow: `0 0 40px ${accent}88`,
            whiteSpace: "nowrap",
          }}
        >
          {text}
        </div>
        {sub ? (
          <div
            style={{
              fontFamily: FONT_STACK,
              fontWeight: 600,
              fontSize: 34,
              letterSpacing: "-0.01em",
              color: yala.color.textSecondary,
              whiteSpace: "nowrap",
            }}
          >
            {sub}
          </div>
        ) : null}
      </div>
    </div>
  );
};
