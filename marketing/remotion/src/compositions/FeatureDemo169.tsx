import { Composition, type CalculateMetadataFunction } from "remotion";
import { pieceBySlug, pieceDurationInFrames } from "../brand/copy";
import { yala } from "../brand/tokens";
import { FeatureDemo, type FeatureDemoProps } from "./FeatureDemo";

/** YouTube / web / keynote. Mismo footage, mismo guion, otro encuadre. */
const calculateMetadata: CalculateMetadataFunction<FeatureDemoProps> = ({ props }) => ({
  durationInFrames: pieceDurationInFrames(pieceBySlug(props.slug)),
});

export const FeatureDemo169: React.FC = () => (
  <Composition
    id={yala.canvas.youtube.id}
    component={FeatureDemo}
    fps={yala.motion.fps}
    width={yala.canvas.youtube.w}
    height={yala.canvas.youtube.h}
    durationInFrames={1}
    calculateMetadata={calculateMetadata}
    defaultProps={{
      slug: "ia-gasto-pizza",
      locale: "es",
      aspect: "16x9",
      showSafeAreas: false,
    }}
  />
);
