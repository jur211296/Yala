import type { ChatParams, ImageDetail, ReasoningEffort } from "../../src/ai/routes";
import type { Candidate } from "../candidates";
import type { Grade } from "../lib/grading";

/**
 * Una tarea del banco. Cada tarea vive en su fichero (`tasks/<tarea>.ts`) y se registra en `tasks/index.ts`:
 * así varias personas pueden añadir tareas a la vez sin tocar `run.ts`.
 */

/** Una variante de candidato: modelo + esfuerzo, y en la foto también `detail` y lado mayor. */
export interface Variant {
  candidate: Candidate;
  effort?: ReasoningEffort;
  detail?: ImageDetail;
  edge?: number;
}

export interface BenchCase {
  id: string;
}

export interface BenchTask<C extends BenchCase = BenchCase> {
  /** Igual que la clave de `TASKS` del gateway (`src/ai/tasks.ts`). */
  readonly name: string;
  /** Parámetros de hoy en la app (la fila base). La temperatura se quita sola a los candidatos que no la admiten. */
  readonly baseParams: ChatParams;
  /** Solo candidatos con visión; y la variante lleva `detail` y lado mayor. */
  readonly image?: boolean;
  /** Fichero de casos en `bench/cases/` (por defecto `<name>.json`). */
  readonly casesFile?: string;
  /** El cuerpo de Chat Completions EXACTO que manda la app para este caso. */
  body(c: C, v: Variant): Record<string, unknown>;
  /**
   * Puntúa la respuesta: primero replica lo que hace la app con ella (si la rechaza, `appParsed: false`), después
   * compara con la verdad del caso. Puede ser asíncrona (p. ej. un juez).
   */
  grade(content: string, c: C, v: Variant): Grade | Promise<Grade>;
}
