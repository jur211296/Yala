import { Composition, type CalculateMetadataFunction } from "remotion";
import { pieceBySlug, pieceDurationInFrames } from "../brand/copy";
import { yala } from "../brand/tokens";
import { FeatureDemo, type FeatureDemoProps } from "./FeatureDemo";

/**
 * Reels / TikTok / Shorts. Es el lienzo por defecto del pack 2.1.
 *
 * La duración NO se escribe aquí: sale de `footageSec` + end card en copy.ts.
 * Cambiar el mp4 por uno más largo actualiza la línea de tiempo sola.
 */
const calculateMetadata: CalculateMetadataFunction<FeatureDemoProps> = ({ props }) => ({
  durationInFrames: pieceDurationInFrames(pieceBySlug(props.slug)),
});

export const FeatureDemo916: React.FC = () => (
  <Composition
    id={yala.canvas.reels.id}
    component={FeatureDemo}
    fps={yala.motion.fps}
    width={yala.canvas.reels.w}
    height={yala.canvas.reels.h}
    durationInFrames={1}
    calculateMetadata={calculateMetadata}
    defaultProps={{
      slug: "ia-gasto-pizza",
      locale: "es",
      aspect: "9x16",
      showSafeAreas: false,
    }}
  />
);
