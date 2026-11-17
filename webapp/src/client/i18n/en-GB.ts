/**
 * Variante de inglés británico: un parche sobre `en.ts` con solo las claves que cambian, como `en-GB.lproj` en la app.
 * Cambia la ortografía británica (labelled, uncategorised, any more) y las comillas simples ‘ ’ que usa la app.
 */
import type { TextsPatch } from "../i18n";
import type { Texts } from "./es";

export const EN_GB: TextsPatch<Texts> = {
  sinNubeComo: "To use it, choose ‘Move to your Yala account’ in Yala's settings on your iPhone. Your records are copied and you can come back here.",
  app: {
    descripcionEj: "E.g. lunch with Emma",
    bandejaNota: "In the beta, your Inbox shows here and you approve it on your iPhone. What you add on the web arrives labelled ‘Yala web’.",
    descartarPregunta: "Your iPhone won't receive it any more.",
    soloGruposCuerpo: "Your account uses Yala only for Groups. To see your accounts, records and statistics here, choose ‘Activate full Yala’ in the Yala app on your iPhone.",
  },
  est: {
    sinCategoriaAviso: (n: number) => (n === 1 ? "1 uncategorised transaction counts by its sign, as on your iPhone." : `${n} uncategorised transactions count by their sign, as on your iPhone.`),
  },
  bus: {
    sinResultados: (q: string) => `Nothing matches ‘${q}’.`,
    verTodos: (q: string) => `See all records with ‘${q}’`,
  },
};
