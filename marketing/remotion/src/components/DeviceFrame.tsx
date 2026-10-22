import { OffthreadVideo, staticFile } from "remotion";
import type { Piece } from "../brand/copy";
import { FONT_STACK } from "../brand/font";
import { yala } from "../brand/tokens";
import { PHONE, phoneHeight } from "../lib/layout";

/**
 * Un iPhone. Entero, con marco, isla y botones — no una ventana recortada.
 *
 * Reglas duras:
 *  1. `OffthreadVideo`, no `<Video>`: muestrea el frame exacto al renderizar,
 *     y el origen va a 60 fps contra una composition de 30.
 *  2. El footage NO se recolorea, NO se estira y NO se reconstruye. Si la UI
 *     de la toma está mal, se vuelve a grabar; no se retoca aquí.
 *  3. Este componente NO sabe de cámara. Se dibuja a escala 1 y quien lo monta
 *     lo mueve como un objeto (`phoneTransform`). Así el zoom conserva la
 *     forma de teléfono en vez de convertirlo en una captura.
 *
 * Los píxeles que el `crop` quita del origen (status bar sucia, pie de página)
 * quedan bajo la isla y bajo el marco inferior: no se echan en falta.
 */
export const DeviceFrame: React.FC<{ piece: Piece; screenWidth?: number }> = ({
  piece,
  screenWidth = PHONE.screenWidth,
}) => (
  <PhoneShell screenWidth={screenWidth} source={piece.source} crop={piece.crop}>
    {piece.footage ? (
      <ScreenVideo
        src={piece.footage}
        screenWidth={screenWidth}
        source={piece.source}
        crop={piece.crop}
      />
    ) : (
      <MissingFootage slug={piece.slug} />
    )}
  </PhoneShell>
);

/**
 * El footage dentro de la pantalla. El recorte se hace estirando el vídeo
 * COMPLETO y desplazándolo hacia arriba bajo un contenedor con overflow: así
 * `crop` quita píxeles sin tocar la proporción.
 */
export const ScreenVideo: React.FC<{
  src: string;
  screenWidth: number;
  source: { w: number; h: number };
  crop?: { top?: number; bottom?: number };
  startFromSec?: number;
}> = ({ src, screenWidth, source, crop, startFromSec = 0 }) => {
  const fullVideoH = (screenWidth * source.h) / source.w;
  const cropTopPx = fullVideoH * (crop?.top ?? 0);
  return (
    <OffthreadVideo
      src={staticFile(src)}
      startFrom={Math.round(startFromSec * yala.motion.fps)}
      style={{
        position: "absolute",
        left: 0,
        top: -cropTopPx,
        width: screenWidth,
        height: fullVideoH,
        objectFit: "fill",
      }}
    />
  );
};

/**
 * La carcasa: marco, isla, botones, reflejo y sombra. La pantalla es lo que le
 * pases como hijo; así la presentación mete una escena distinta en cada tramo
 * sin que el teléfono deje de ser el mismo objeto.
 */
export const PhoneShell: React.FC<{
  screenWidth: number;
  source: { w: number; h: number };
  crop?: { top?: number; bottom?: number };
  children: React.ReactNode;
}> = ({ screenWidth, source, crop, children }) => {
  const bezel = PHONE.bezel;
  const outerW = screenWidth + bezel * 2;
  const outerH = phoneHeight(screenWidth, source, crop);
  const screenH = outerH - bezel * 2;
  const radius = (PHONE.radius * screenWidth) / PHONE.screenWidth;

  return (
    <div style={{ position: "relative", width: outerW, height: outerH }}>
      {/* Sombra en el suelo: separa el teléfono del fondo. */}
      <div
        style={{
          position: "absolute",
          left: outerW * 0.08,
          right: outerW * 0.08,
          bottom: -outerH * 0.04,
          height: outerH * 0.18,
          borderRadius: "50%",
          background: "rgba(0,0,0,0.75)",
          filter: "blur(70px)",
        }}
      />

      <SideButton side="left" top={outerH * 0.16} height={outerH * 0.028} />
      <SideButton side="left" top={outerH * 0.235} height={outerH * 0.05} />
      <SideButton side="left" top={outerH * 0.3} height={outerH * 0.05} />
      <SideButton side="right" top={outerH * 0.25} height={outerH * 0.085} />

      {/* Marco. Titanio: gris muy oscuro con una arista clara arriba-izquierda. */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          borderRadius: radius,
          background:
            "linear-gradient(150deg, #3a3a44 0%, #16161c 22%, #0c0c11 55%, #1d1d24 100%)",
          boxShadow: `0 0 0 1.5px rgba(255,255,255,0.22), 0 60px 140px rgba(0,0,0,0.75), 0 0 180px ${yala.color.indigo}2E`,
        }}
      />

      {/* Pantalla. */}
      <div
        style={{
          position: "absolute",
          left: bezel,
          top: bezel,
          width: screenWidth,
          height: screenH,
          borderRadius: radius - bezel,
          overflow: "hidden",
          background: "#000",
        }}
      >
        {children}

        {/* Reflejo del cristal: una diagonal muy tenue. Es lo que hace que
            la pantalla se lea como vidrio y no como un PNG plano. */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            background:
              "linear-gradient(115deg, rgba(255,255,255,0.13) 0%, rgba(255,255,255,0.04) 28%, transparent 46%)",
            pointerEvents: "none",
          }}
        />

        {/* Dynamic Island. */}
        <div
          style={{
            position: "absolute",
            top: (PHONE.island.top * screenWidth) / PHONE.screenWidth,
            left: "50%",
            transform: "translateX(-50%)",
            width: (PHONE.island.width * screenWidth) / PHONE.screenWidth,
            height: (PHONE.island.height * screenWidth) / PHONE.screenWidth,
            borderRadius: 999,
            background: "#000",
            boxShadow: "0 0 0 1px rgba(255,255,255,0.05)",
          }}
        />
      </div>
    </div>
  );
};

const SideButton: React.FC<{ side: "left" | "right"; top: number; height: number }> = ({
  side,
  top,
  height,
}) => (
  <div
    style={{
      position: "absolute",
      top,
      height,
      width: 5,
      [side]: -4,
      borderRadius: 3,
      background: "linear-gradient(90deg, #2a2a33, #111116)",
      boxShadow: "0 0 0 1px rgba(255,255,255,0.12)",
    }}
  />
);

/** Un slug del pack sin toma todavía: enseña el hueco en vez de reventar. */
const MissingFootage: React.FC<{ slug: string }> = ({ slug }) => (
  <div
    style={{
      position: "absolute",
      inset: 0,
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      justifyContent: "center",
      gap: 18,
      background: `linear-gradient(160deg, ${yala.color.indigo}33, ${yala.color.bg})`,
      fontFamily: FONT_STACK,
      textAlign: "center",
      padding: 48,
    }}
  >
    <div style={{ fontSize: 44, fontWeight: 800, color: yala.color.white }}>Falta la toma</div>
    <div style={{ fontSize: 28, color: yala.color.textSecondary }}>{slug}</div>
    <div style={{ fontSize: 22, color: yala.color.textSecondary, maxWidth: 480 }}>
      Graba la pantalla del iPhone, copia el mp4 a <code>public/footage/</code> y apúntalo
      en <code>src/brand/copy.ts</code>.
    </div>
  </div>
);
