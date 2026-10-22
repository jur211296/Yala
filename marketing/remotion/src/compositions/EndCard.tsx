import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import { FONT_STACK } from "../brand/font";
import { yala } from "../brand/tokens";
import { titleMotion } from "../lib/timing";

/**
 * Cierre de pieza: fondo #060612, wordmark y UNA línea. Nada más.
 *
 * El wordmark se dibuja con tipografía, no con un PNG: es la misma
 * construcción que `Web/public/logo.svg` (Yala + punto + subrayado), pero con
 * los tokens 2.1. OJO: la web usa cian neón #00F3FF y el pack 2.1 usa teal
 * #00C2CB — la divergencia es real y está anotada en SHOT-CONTRACT.md.
 */
export const EndCard: React.FC<{ line: string; wide?: boolean }> = ({
  line,
  wide = false,
}) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();
  const { opacity, translateY, scale } = titleMotion({
    frame,
    fps,
    durationInFrames,
    travelPx: 22,
  });

  const markSize = wide ? 190 : 210;

  return (
    <AbsoluteFill
      style={{
        background: yala.color.bg,
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <AbsoluteFill
        style={{
          background: `radial-gradient(60% 40% at 50% 42%, ${yala.color.indigo}33, transparent 70%)`,
        }}
      />
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          gap: 60,
          opacity,
          transform: `translateY(${translateY}px) scale(${scale})`,
        }}
      >
        <Wordmark sizePx={markSize} />
        <div
          style={{
            fontFamily: FONT_STACK,
            fontWeight: 600,
            fontSize: wide ? 52 : 58,
            letterSpacing: "-0.01em",
            color: yala.color.textSecondary,
            textAlign: "center",
            maxWidth: wide ? 1200 : 900,
          }}
        >
          {line}
        </div>
      </div>
    </AbsoluteFill>
  );
};

const Wordmark: React.FC<{ sizePx: number }> = ({ sizePx }) => (
  <div style={{ position: "relative", display: "inline-block" }}>
    <span
      style={{
        fontFamily: FONT_STACK,
        fontWeight: 700,
        fontSize: sizePx,
        letterSpacing: "-0.04em",
        color: yala.color.white,
        lineHeight: 1,
      }}
    >
      Yala
    </span>
    <span
      style={{
        position: "absolute",
        top: -sizePx * 0.06,
        right: -sizePx * 0.22,
        width: sizePx * 0.19,
        height: sizePx * 0.19,
        borderRadius: 999,
        background: yala.color.teal,
        boxShadow: `0 0 ${sizePx * 0.3}px ${yala.color.teal}`,
      }}
    />
    <span
      style={{
        position: "absolute",
        left: sizePx * 0.22,
        bottom: -sizePx * 0.17,
        width: sizePx * 0.44,
        height: sizePx * 0.055,
        borderRadius: 999,
        background: yala.color.pink,
      }}
    />
  </div>
);
