/**
 * Tokens de marca Yala 2.1 (look Liquid Glass, CONGELADO).
 *
 * Esta es la ÚNICA fuente de la marca en el estudio de vídeo. Ningún componente
 * escribe un hex a mano ni una clase de Tailwind con color: todo sale de aquí.
 * Si el índigo vive en dos sitios, en tres meses hay dos índigos.
 *
 * Light / Rosa / Teal / Minimalist son temas DE LA APP, no el look de las
 * piezas 2.1. El marco de las piezas es siempre el glass oscuro.
 */
export const yala = {
  color: {
    bg: "#060612",
    indigo: "#6366F1",
    pink: "#FF0080",
    teal: "#00C2CB",
    white: "#FFFFFF",
    textSecondary: "rgba(255,255,255,0.72)",
  },
  type: {
    family: "Inter",
    // ⚠️ Subidos respecto al brief del encargo (hero 64 → 104, callout 28 → 40)
    // y `linePx` es nuevo. El motivo: a 64 px sobre un lienzo de 1080 el texto
    // ocupa un 6 % del alto y en un feed no se lee — se ve, que no es lo mismo.
    // Los hex NO se tocaron; esto es escala tipográfica, no marca.
    heroPx: 104,
    linePx: 62,
    heroPx169: 92,
    calloutPx: 40,
  },
  motion: {
    fps: 30,
    springTitle: { damping: 13, mass: 0.4, stiffness: 150 },
    fadeFrames: 10,
    titleIn: 8,
    titleHold: 50,
    // Salida corta: el beat tiene que irse antes de que entre el siguiente.
    titleOut: 7,
  },
  canvas: {
    reels: { w: 1080, h: 1920, id: "FeatureDemo-9x16" },
    youtube: { w: 1920, h: 1080, id: "FeatureDemo-16x9" },
  },
} as const;

/**
 * Cristal del marco. No es color de marca: es el material que sostiene el
 * footage y la tipografía. Vive aquí para que los componentes no lo inventen.
 */
export const glass = {
  panel: "rgba(255,255,255,0.06)",
  panelStrong: "rgba(10,10,26,0.72)",
  stroke: "rgba(255,255,255,0.14)",
  strokeStrong: "rgba(255,255,255,0.22)",
  shadow: "0 32px 80px rgba(0,0,0,0.55)",
} as const;

export type Theme = "dark" | "light";

/** El marco cambia con el theme. El footage NUNCA se recolorea. */
export const frameTheme = (theme: Theme) =>
  theme === "dark"
    ? {
        bg: yala.color.bg,
        text: yala.color.white,
        textSecondary: yala.color.textSecondary,
        panel: glass.panel,
        stroke: glass.stroke,
      }
    : {
        bg: "#F4F5FB",
        text: "#0B0B18",
        textSecondary: "rgba(11,11,24,0.66)",
        panel: "rgba(11,11,24,0.05)",
        stroke: "rgba(11,11,24,0.12)",
      };
