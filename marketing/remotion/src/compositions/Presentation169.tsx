import { Composition, type CalculateMetadataFunction } from "remotion";
import { presentationBySlug, presentationDurationInFrames } from "../brand/copy";
import { yala } from "../brand/tokens";
import { Presentation, type PresentationProps } from "./Presentation";

/** La pieza de presentación horizontal, por escenas. */
const calculateMetadata: CalculateMetadataFunction<PresentationProps> = ({ props }) => ({
  durationInFrames: presentationDurationInFrames(presentationBySlug(props.slug)),
});

export const Presentation169: React.FC = () => (
  <Composition
    id="Presentation-16x9"
    component={Presentation}
    fps={yala.motion.fps}
    width={yala.canvas.youtube.w}
    height={yala.canvas.youtube.h}
    durationInFrames={1}
    calculateMetadata={calculateMetadata}
    defaultProps={{ slug: "presentacion-yala-ia", locale: "es" }}
  />
);
