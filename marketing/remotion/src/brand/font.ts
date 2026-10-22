import { loadFont } from "@remotion/google-fonts/Inter";
import { yala } from "./tokens";

/**
 * La referencia real de Yala es SF Pro Rounded, y NO se puede empaquetar.
 * Inter es el sustituto que sí se puede: cargarlo aquí, una sola vez, evita que
 * cada componente elija su propia familia y que las piezas salgan desparejas.
 */
const { fontFamily } = loadFont("normal", {
  weights: ["400", "600", "700"],
  subsets: ["latin"],
});

/** Inter con caída al sistema por si la fuente no llega a tiempo. */
export const FONT_STACK = `${fontFamily}, ${yala.type.family}, -apple-system, system-ui, sans-serif`;
