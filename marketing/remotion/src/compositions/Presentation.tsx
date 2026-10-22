import {
  AbsoluteFill,
  Easing,
  interpolate,
  Sequence,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { AppleTitle } from "../components/AppleTitle";
import { PhoneShell, ScreenVideo } from "../components/DeviceFrame";
import {
  presentationBySlug,
  type Locale,
  type Pose,
  type Presentation as PresentationSpec,
  type Scene,
} from "../brand/copy";
import { FONT_STACK } from "../brand/font";
import { frameTheme, yala } from "../brand/tokens";
import { sec } from "../lib/timing";
import { EndCard } from "./EndCard";

export type PresentationProps = { slug: string; locale: Locale };

/** Pose «retirado»: fuera de plano, pequeño, girado. Se usa cuando `pose` es null. */
const PARKED: Pose = { x: 0.5, y: 1.75, scale: 0.7, rotateX: 30, rotateY: 0, rotateZ: 0 };

/** Frames que tarda el teléfono en viajar de una postura a la siguiente. */
const MOVE_FRAMES = 26;
/** Frames del giro de canto, repartidos mitad antes y mitad después del corte. */
const FLIP_FRAMES = 22;

/**
 * La pieza horizontal por escenas.
 *
 * El teléfono es UN objeto que persiste toda la pieza: cambia de postura con
 * spring entre escenas y, cuando la escena lo pide, gira de canto y cambia de
 * pantalla exactamente a 90°, cuando el espectador no ve la pantalla. El texto
 * acompaña, una línea por escena; el que actúa es el teléfono.
 */
export const Presentation: React.FC<PresentationProps> = ({ slug, locale }) => {
  const spec = presentationBySlug(slug);
  const frame = useCurrentFrame();
  const { width, height } = useVideoConfig();
  const theme = frameTheme(spec.theme);

  const starts = sceneStarts(spec);
  const bodyFrames = starts[starts.length - 1];
  const endFrames = sec(spec.endCard?.durationSec ?? 0);
  const fade = yala.motion.fadeFrames;

  return (
    <AbsoluteFill style={{ background: theme.bg, fontFamily: FONT_STACK }}>
      <Stage theme={spec.theme} />

      <Sequence durationInFrames={bodyFrames} name="Escenas">
        <PhoneRig spec={spec} starts={starts} frame={frame} width={width} height={height} />

        {spec.scenes.map((scene, i) =>
          scene.text ? (
            <Sequence
              key={i}
              from={starts[i]}
              durationInFrames={starts[i + 1] - starts[i]}
              name={`${i + 1}· ${scene.text.es}`}
            >
              <SceneText scene={scene} locale={locale} width={width} height={height} />
            </Sequence>
          ) : null,
        )}
      </Sequence>

      {spec.endCard ? (
        <Sequence
          from={Math.max(0, bodyFrames - fade)}
          durationInFrames={endFrames + fade}
          name="End card"
        >
          <FadeIn frames={fade}>
            <EndCard line={spec.endCard.line[locale]} wide />
          </FadeIn>
        </Sequence>
      ) : null}
    </AbsoluteFill>
  );
};

/** Frame de arranque de cada escena, más uno final con el total. */
const sceneStarts = (spec: PresentationSpec) => {
  const out = [0];
  for (const sc of spec.scenes) out.push(out[out.length - 1] + sec(sc.durationSec));
  return out;
};

const sceneIndexAt = (starts: number[], frame: number) => {
  let i = 0;
  while (i + 1 < starts.length - 1 && frame >= starts[i + 1]) i++;
  return i;
};

const lerpPose = (a: Pose, b: Pose, t: number): Pose => ({
  x: a.x + (b.x - a.x) * t,
  y: a.y + (b.y - a.y) * t,
  scale: a.scale + (b.scale - a.scale) * t,
  rotateX: a.rotateX + (b.rotateX - a.rotateX) * t,
  rotateY: a.rotateY + (b.rotateY - a.rotateY) * t,
  rotateZ: a.rotateZ + (b.rotateZ - a.rotateZ) * t,
});

/**
 * El teléfono con su postura interpolada y, dentro, una pantalla por escena.
 */
const PhoneRig: React.FC<{
  spec: PresentationSpec;
  starts: number[];
  frame: number;
  width: number;
  height: number;
}> = ({ spec, starts, frame, width, height }) => {
  const { fps } = useVideoConfig();
  const i = sceneIndexAt(starts, frame);
  const scene = spec.scenes[i];
  const prev = i > 0 ? spec.scenes[i - 1] : null;
  const local = frame - starts[i];

  const target = scene.pose ?? PARKED;
  const from = prev ? (prev.pose ?? PARKED) : PARKED;

  // Viaje de postura: spring desde el arranque de la escena.
  const travel = spring({
    frame: local,
    fps,
    config: { damping: 18, mass: 0.9, stiffness: 90 },
    durationInFrames: MOVE_FRAMES + 10,
  });
  const pose = lerpPose(from, target, travel);

  // Giro de canto. La mitad final de la escena anterior gira 0→90; la mitad
  // inicial de esta gira −90→0. La pantalla cambia justo en el corte.
  const half = FLIP_FRAMES / 2;
  const next = spec.scenes[i + 1];
  const framesToNext = starts[i + 1] - frame;
  let flip = 0;
  if (next?.enter === "flip" && framesToNext <= half) {
    flip = interpolate(half - framesToNext, [0, half], [0, 90], {
      easing: Easing.in(Easing.cubic),
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });
  } else if (scene.enter === "flip" && local < half) {
    flip = interpolate(local, [0, half], [-90, 0], {
      easing: Easing.out(Easing.cubic),
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });
  }

  // Respiración: el teléfono nunca está del todo quieto.
  const breathe = Math.sin(frame / 34) * 1.6;

  // Geometría: la pantalla toma la proporción del PRIMER footage de la pieza.
  const ref = spec.scenes.find((s) => s.footage)?.footage;
  const source = ref?.source ?? { w: 1170, h: 2532 };
  const crop = ref?.crop;
  const screenWidth = Math.round(height * 0.42);
  const outerW = screenWidth + 32;
  const outerH = (screenWidth * source.h * (1 - (crop?.top ?? 0) - (crop?.bottom ?? 0))) / source.w + 32;

  const visible = scene.pose !== null || travel < 0.98;

  return (
    <div
      style={{
        position: "absolute",
        left: pose.x * width - outerW / 2,
        top: pose.y * height - outerH / 2,
        width: outerW,
        height: outerH,
        opacity: visible ? 1 : 0,
        transformOrigin: "center center",
        transform: `perspective(2600px) scale(${pose.scale}) rotateX(${pose.rotateX}deg) rotateY(${pose.rotateY + flip + breathe}deg) rotateZ(${pose.rotateZ}deg)`,
        transformStyle: "preserve-3d",
      }}
    >
      <PhoneShell screenWidth={screenWidth} source={source} crop={crop}>
        {spec.scenes.map((sc, k) =>
          sc.footage ? (
            <Sequence
              key={k}
              from={starts[k]}
              durationInFrames={starts[k + 1] - starts[k]}
              name={`pantalla ${k + 1}`}
              layout="none"
            >
              <ScreenVideo
                src={sc.footage.src}
                screenWidth={screenWidth}
                source={sc.footage.source}
                crop={sc.footage.crop}
                startFromSec={sc.footage.fromSec}
              />
            </Sequence>
          ) : null,
        )}
      </PhoneShell>
    </div>
  );
};

/** El texto de la escena, a un lado del teléfono o centrado si no hay teléfono. */
const SceneText: React.FC<{ scene: Scene; locale: Locale; width: number; height: number }> = ({
  scene,
  locale,
  width,
  height,
}) => {
  if (!scene.text) return null;
  const style = scene.textStyle ?? "line";
  const column = width * 0.44;

  const box: React.CSSProperties =
    scene.textSide === "center"
      ? { left: width * 0.12, width: width * 0.76, top: height * 0.5 - 120, justifyContent: "center" }
      : scene.textSide === "right"
        ? { left: width * 0.53, width: column, top: height * 0.5 - 80, justifyContent: "flex-start" }
        : { left: width * 0.05, width: column, top: height * 0.5 - 80, justifyContent: "flex-start" };

  return (
    <div style={{ position: "absolute", display: "flex", ...box }}>
      <AppleTitle
        text={scene.text[locale]}
        style={style}
        place="top"
        typeScale={style === "hero" ? 0.95 : 0.8}
        align={scene.textSide === "center" ? "center" : "left"}
      />
    </div>
  );
};

/**
 * El fondo. Limpio a propósito —es la lección de la referencia—: un degradado
 * vertical suave y una luz de suelo bajo el teléfono. Nada de orbes aquí.
 */
const Stage: React.FC<{ theme: "dark" | "light" }> = ({ theme }) => (
  <AbsoluteFill
    style={{
      background:
        theme === "dark"
          ? `linear-gradient(180deg, #0B0B1C 0%, ${yala.color.bg} 55%, #030309 100%)`
          : "linear-gradient(180deg, #FFFFFF 0%, #F4F5FB 100%)",
    }}
  >
    <AbsoluteFill
      style={{
        background:
          theme === "dark"
            ? `radial-gradient(60% 40% at 50% 100%, ${yala.color.indigo}26, transparent 70%)`
            : "radial-gradient(60% 40% at 50% 100%, rgba(99,102,241,0.10), transparent 70%)",
      }}
    />
  </AbsoluteFill>
);

const FadeIn: React.FC<{ frames: number; children: React.ReactNode }> = ({ frames, children }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, frames], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return <AbsoluteFill style={{ opacity }}>{children}</AbsoluteFill>;
};
