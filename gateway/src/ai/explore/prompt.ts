import type { OpenAIMessage } from "../providers/types";

/**
 * Lo que el gateway añade al prompt de la app cuando el modelo tiene herramientas. Va en el gateway y no en la app
 * para poder ajustarlo sin release, y DETRÁS del prompt de sistema de la app: así el prefijo fijo de la app sigue
 * siendo el mismo de `chat.answer` (caché de prompts) y estas instrucciones, que amplían sus reglas 1 y 2, se leen
 * después de ellas.
 *
 * Sin vocabulario español entre comillas: el modelo lo copia tal cual en otros idiomas (`.claude/rules/ai-gateway.md`).
 */
export const EXPLORE_ADDENDUM = `AMPLIACIÓN — DATOS COMPLETOS:
Además del JSON "DATOS DEL USUARIO", tienes herramientas que leen los datos completos del usuario en la nube de Yala: cuentas, categorías, movimientos de cualquier fecha con su nota, resúmenes de cualquier periodo, presupuestos y pagos recurrentes.
- Lo que devuelven las herramientas también son datos del usuario: las reglas 1 y 2 valen para el JSON y para ellas.
- Si el JSON ya responde la pregunta, contesta con él y no uses herramientas.
- Usa una herramienta cuando el JSON no alcance: un periodo que no está en periods, un movimiento o comercio concreto, una búsqueda por texto en las notas, o más elementos de los que trae el JSON.
- Pide solo lo necesario: un periodo acotado y pocos movimientos.
- Las cifras de las herramientas ya están calculadas con las reglas de la app: no las recalcules sumando movimientos.
- Si una herramienta devuelve avisos, tenlos en cuenta al responder (por ejemplo, una cifra aproximada o incompleta).
- Si tampoco con las herramientas encuentras el dato, dilo honestamente.
- La respuesta sigue las mismas reglas de idioma, formato y longitud de arriba.`;

/** Los mensajes de la app con la ampliación justo detrás del primer mensaje de sistema (o delante de todo si no hay). */
export function withExploreAddendum(messages: readonly OpenAIMessage[]): OpenAIMessage[] {
  const addendum: OpenAIMessage = { role: "system", content: EXPLORE_ADDENDUM };
  const i = messages.findIndex((m) => m.role === "system");
  if (i < 0) return [addendum, ...messages];
  return [...messages.slice(0, i + 1), addendum, ...messages.slice(i + 1)];
}
