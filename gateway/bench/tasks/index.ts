import { intentTask } from "./chat.intent";
import { suggestionsTask } from "./chat.suggestions";
import { photoTask } from "./photo.read";
import type { BenchTask } from "./types";

/**
 * Registro de tareas del banco. Añadir una tarea = su fichero en `tasks/` + una línea aquí, en su bloque.
 * El orden es el de `--task all`.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const TASK_REGISTRY: readonly BenchTask<any>[] = [
  // --- sesión 1: las tres de gpt-4.1-nano ---
  intentTask,
  suggestionsTask,
  photoTask,
  // --- sesión 2 · chat y nota (trabajador A): añade aquí ---
  // --- sesión 2 · Insights y Tendencias (trabajador B): añade aquí ---
];

export function taskByName(name: string): BenchTask {
  const t = TASK_REGISTRY.find((x) => x.name === name);
  if (!t) throw new Error(`banco: tarea desconocida «${name}». Registradas: ${TASK_REGISTRY.map((x) => x.name).join(", ")}`);
  return t;
}
