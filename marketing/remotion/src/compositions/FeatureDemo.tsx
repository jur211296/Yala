import {
  AbsoluteFill,
  interpolate,
  Sequence,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { AppleTitle } from "../components/AppleTitle";
import { Callout } from "../components/Callout";
import { DeviceFrame } from "../components/DeviceFrame";
import { FloatBadge } from "../components/FloatBadge";
import { SafeAreas } from "../components/SafeAreas";
import { pieceBySlug, type Beat, type Locale, type Piece } from "../brand/copy";
import { FONT_STACK } from "../brand/font";
import { yala } from "../brand/tokens";
import { cue, sec } from "../lib/timing";
import {
  cameraAt,
  PHONE,
  phoneHeight,
  phoneTransform,
  REELS_CAMERA,
  REELS_SAFE,
  REELS_TEXT,
  WIDE_COPY,
} from "../lib/layout";
import { EndCard } from "./EndCard";

export type Aspect = "9x16" | "16x9";

export type FeatureDemoProps = {
  /** Clave de la pieza en `src/brand/copy.ts`. Es el único dato que se pasa a mano. */
  slug: string;
  locale: Locale;
  aspect: Aspect;
  /** Guías de Reels. Se encienden en Studio; en render van apagadas. */
  showSafeAreas: boolean;
};

/**
 * La plantilla. UNA sola para todas las piezas y los dos lienzos.
 *
 * Capa A (verdad del producto) = un iPhone con el footage real, intacto, que
 * la cámara mueve como un objeto.
 * Capa B (motion) = fondo con profundidad, hilo de beats, la tarjeta que sale
 * de la pantalla en el golpe, end card.
 *
 * Las dos capas no se mezclan nunca: la app no se redibuja, se filma.
 */
export const FeatureDemo: React.FC<FeatureDemoProps> = ({
  slug,
  locale,
  aspect,
  showSafeAreas,
}) => {
  const piece = pieceBySlug(slug);

  const bodyFrames = sec(piece.footageSec);
  const endFrames = sec(piece.endCard?.durationSec ?? 0);
  const fade = yala.motion.fadeFrames;

  return (
    <AbsoluteFill style={{ background: yala.color.bg, fontFamily: FONT_STACK }}>
      <Backdrop aspect={aspect} />

      <Sequence durationInFrames={bodyFrames} name="Cuerpo">
        {aspect === "9x16" ? (
          <Reels piece={piece} locale={locale} />
        ) : (
          <Wide piece={piece} locale={locale} />
        )}
      </Sequence>

      {piece.endCard ? (
        <Sequence
          from={Math.max(0, bodyFrames - fade)}
          durationInFrames={endFrames + fade}
          name="End card"
        >
          <FadeIn frames={fade}>
            <EndCard line={piece.endCard.line[locale]} wide={aspect === "16x9"} />
          </FadeIn>
        </Sequence>
      ) : null}

      {aspect === "9x16" ? <SafeAreas visible={showSafeAreas} /> : null}
    </AbsoluteFill>
  );
};

// --------------------------------------------------------------------------

type SideProps = { piece: Piece; locale: Locale };

/**
 * El teléfono con su cámara. Se dibuja a escala 1 en `phoneTop` y el
 * transform lo escala y desplaza para llevar `focusY` a `centerY`.
 */
const PhoneStage: React.FC<{
  piece: Piece;
  screenWidth: number;
  phoneTop: number;
  centerY: number;
  canvasW: number;
}> = ({ piece, screenWidth, phoneTop, centerY, canvasW }) => {
  const frame = useCurrentFrame();
  const cam = cameraAt(piece.shots, frame);
  const phoneH = phoneHeight(screenWidth, piece.source, piece.crop);
  const outerW = screenWidth + PHONE.bezel * 2;

  return (
    <div
      style={{
        position: "absolute",
        left: (canvasW - outerW) / 2,
        top: phoneTop,
        width: outerW,
        height: phoneH,
        transformOrigin: "center center",
        transform: phoneTransform({
          focusY: cam.focusY,
          scale: cam.scale,
          phoneH,
          phoneTop,
          centerY,
          tiltDeg: cam.tiltDeg,
        }),
      }}
    >
      <DeviceFrame piece={piece} screenWidth={screenWidth} />
    </div>
  );
};

/** 9:16 — el lienzo de Reels. */
const Reels: React.FC<SideProps> = ({ piece, locale }) => {
  const { width } = useVideoConfig();
  return (
    <AbsoluteFill>
      <PhoneStage
        piece={piece}
        screenWidth={PHONE.screenWidth}
        phoneTop={REELS_CAMERA.phoneTop}
        centerY={REELS_CAMERA.centerY}
        canvasW={width}
      />

      {piece.beats.map((beat, i) => (
        <Sequence
          key={`${beat.fromSec}-${i}`}
          {...cue(beat.fromSec, beat.toSec)}
          name={`${i + 1}· ${beat.text.es}`}
        >
          <BeatSlot beat={beat} locale={locale} />
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};

/** Dónde cae cada beat en 9:16 según su `place`. */
const BeatSlot: React.FC<{ beat: Beat; locale: Locale }> = ({ beat, locale }) => {
  if (beat.place === "float") {
    return (
      <div style={{ position: "absolute", left: 400, top: 1250 }}>
        <FloatBadge text={beat.text[locale]} sub={beat.sub?.[locale]} tone={beat.tone} />
      </div>
    );
  }
  return (
    <div
      style={{
        position: "absolute",
        left: REELS_SAFE.side,
        right: REELS_SAFE.side,
        ...(beat.place === "top" ? { top: REELS_TEXT.top } : { bottom: REELS_TEXT.bottom }),
        display: "flex",
        justifyContent: "center",
      }}
    >
      <BeatText beat={beat} locale={locale} />
    </div>
  );
};

/** 16:9 — teléfono a la izquierda, columna de texto a la derecha. */
const Wide: React.FC<SideProps> = ({ piece, locale }) => {
  const { height } = useVideoConfig();
  const screenWidth = 430;
  return (
    <AbsoluteFill>
      <div style={{ position: "absolute", left: 0, top: 0, width: 760, height }}>
        <PhoneStage
          piece={piece}
          screenWidth={screenWidth}
          phoneTop={70}
          centerY={height / 2}
          canvasW={760}
        />
      </div>

      {piece.beats.map((beat, i) => (
        <Sequence
          key={`${beat.fromSec}-${i}`}
          {...cue(beat.fromSec, beat.toSec)}
          name={`${i + 1}· ${beat.text.es}`}
        >
          {beat.place === "float" ? (
            <div style={{ position: "absolute", left: 540, top: 600 }}>
              <FloatBadge text={beat.text[locale]} sub={beat.sub?.[locale]} tone={beat.tone} />
            </div>
          ) : (
            <div
              style={{
                position: "absolute",
                left: WIDE_COPY.left,
                right: WIDE_COPY.right,
                ...(beat.place === "top" ? { top: 190 } : { bottom: 190 }),
                display: "flex",
                justifyContent: "flex-start",
              }}
            >
              <BeatText beat={beat} locale={locale} typeScale={0.9} align="left" />
            </div>
          )}
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};

const BeatText: React.FC<{
  beat: Beat;
  locale: Locale;
  typeScale?: number;
  align?: "center" | "left";
}> = ({ beat, locale, typeScale = 1, align = "center" }) =>
  beat.style === "pill" ? (
    <Callout text={beat.text[locale]} tone={beat.tone} typeScale={typeScale} />
  ) : (
    <AppleTitle
      text={beat.text[locale]}
      style={beat.style === "badge" ? "hero" : beat.style}
      place={beat.place === "float" ? "top" : beat.place}
      tone={beat.tone}
      typeScale={typeScale}
      align={align}
    />
  );

/**
 * Fondo con profundidad: tres orbes de luz que derivan despacio, más grano.
 *
 * Un negro plano se lee como plantilla vacía. Los orbes dan atmósfera y, al
 * moverse, hacen que el fondo también esté vivo aunque la cámara pare.
 */
const Backdrop: React.FC<{ aspect: Aspect }> = ({ aspect }) => {
  const frame = useCurrentFrame();
  const { width, height } = useVideoConfig();
  const t = frame / 30;
  const orb = (color: string, x: number, y: number, r: number, phase: number) => (
    <div
      style={{
        position: "absolute",
        left: x * width + Math.sin(t * 0.35 + phase) * width * 0.06 - r,
        top: y * height + Math.cos(t * 0.28 + phase) * height * 0.05 - r,
        width: r * 2,
        height: r * 2,
        borderRadius: "50%",
        background: color,
        opacity: 0.42,
        filter: "blur(120px)",
      }}
    />
  );
  const wide = aspect === "16x9";
  return (
    <AbsoluteFill style={{ overflow: "hidden" }}>
      {orb(yala.color.indigo, wide ? 0.25 : 0.5, wide ? 0.4 : 0.16, wide ? 520 : 560, 0)}
      {orb(yala.color.pink, wide ? 0.85 : 0.92, wide ? 0.9 : 0.62, wide ? 380 : 420, 2.1)}
      {orb(yala.color.teal, wide ? 0.6 : 0.06, wide ? 0.1 : 0.92, wide ? 340 : 380, 4.2)}
      {/* Grano fino: quita el aspecto de render digital limpio. */}
      <svg style={{ position: "absolute", inset: 0, opacity: 0.07 }} width="100%" height="100%">
        <filter id="grain">
          <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed={frame % 7} />
          <feColorMatrix type="saturate" values="0" />
        </filter>
        <rect width="100%" height="100%" filter="url(#grain)" />
      </svg>
      {/* Viñeta. */}
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(120% 80% at 50% 45%, transparent 55%, rgba(6,6,18,0.7) 100%)",
        }}
      />
    </AbsoluteFill>
  );
};

const FadeIn: React.FC<{ frames: number; children: React.ReactNode }> = ({
  frames,
  children,
}) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, frames], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return <AbsoluteFill style={{ opacity }}>{children}</AbsoluteFill>;
};
