import { AbsoluteFill } from "remotion";
import { REELS_SAFE } from "../lib/layout";

/**
 * GUÍA DE STUDIO, no un recorte.
 *
 * Dibuja en punteado las bandas que Instagram tapa con su propia UI en Reels,
 * para comprobar de un vistazo que nada importante cae debajo. Va apagada en
 * render: `showSafeAreas` es `false` por defecto y los scripts no lo encienden.
 */
export const SafeAreas: React.FC<{ visible: boolean }> = ({ visible }) => {
  if (!visible) return null;

  const band: React.CSSProperties = {
    position: "absolute",
    left: 0,
    right: 0,
    background: "rgba(255,0,128,0.12)",
    borderColor: "rgba(255,0,128,0.55)",
    borderStyle: "dashed",
    borderWidth: 0,
  };

  return (
    <AbsoluteFill style={{ pointerEvents: "none" }}>
      <div style={{ ...band, top: 0, height: REELS_SAFE.top, borderBottomWidth: 3 }} />
      <div style={{ ...band, bottom: 0, height: REELS_SAFE.bottom, borderTopWidth: 3 }} />
      <div
        style={{
          position: "absolute",
          top: 0,
          bottom: 0,
          left: 0,
          width: REELS_SAFE.side,
          background: "rgba(255,0,128,0.08)",
        }}
      />
      <div
        style={{
          position: "absolute",
          top: 0,
          bottom: 0,
          right: 0,
          width: REELS_SAFE.side,
          background: "rgba(255,0,128,0.08)",
        }}
      />
    </AbsoluteFill>
  );
};
