import "./index.css";
import { FeatureDemo169 } from "./compositions/FeatureDemo169";
import { FeatureDemo916 } from "./compositions/FeatureDemo916";
import { Presentation169 } from "./compositions/Presentation169";

/**
 * Tres compositions, no veinte: dos lienzos del clip de función y la
 * presentación por escenas.
 * La pieza se elige por `slug` en los props, no creando una composition nueva.
 */
export const RemotionRoot: React.FC = () => (
  <>
    <FeatureDemo916 />
    <FeatureDemo169 />
    <Presentation169 />
  </>
);
