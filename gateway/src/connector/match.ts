/**
 * ¿Lo que la IA va a apuntar ya está en Yala? La regla de coincidencia de «Bandeja sin duplicados»
 * (`docs/propuestas/bandeja-sin-duplicados/README.md`, opción B, lote 5), adaptada a lo que trae la IA: solo el día (sin
 * hora) y sin los últimos 4 de la tarjeta.
 *
 * | Campo   | Fuerte                                   | Dudosa                                   | No casa                     |
 * |---------|------------------------------------------|------------------------------------------|-----------------------------|
 * | Tipo    | el mismo                                 | —                                        | gasto contra ingreso        |
 * | Divisa  | la misma, o una sin divisa               | —                                        | dos divisas distintas (*)   |
 * | Cuenta  | la misma                                 | una de las dos sin cuenta                | dos cuentas distintas       |
 * | Importe | ±0,01                                    | ±3 % (propinas, preautorizaciones)       | más                         |
 * | Día     | el mismo o ±1                            | hasta ±3 (cargos que se asientan tarde)  | más                         |
 * | Comercio| parecido, o uno vacío                    | distinto                                 | —                           |
 * | Fuente  | distintas                                | —                                        | la misma                    |
 *
 * Fuerte exige todo en su columna; cualquier campo en «dudosa» la hace dudosa. Las dos se devuelven: la IA pregunta en
 * los dos casos, y el nivel solo le dice cuánto se parecen.
 *
 * (*) La propuesta compara otra divisa convertida ±4 %. El gateway no tiene aquí tipos de cambio, así que no lo hace: el
 * caso queda para el emparejador de la app (lote 1).
 *
 * **Dos borradores de la misma fuente nunca se juntan**: cada fuente cuenta cada pago una sola vez, así que dos cafés
 * iguales por Apple Pay son dos cafés. La fuente de lo que apunta la IA es `ai:<IA>`: otra IA cuenta como otra fuente. Que
 * la misma IA lea dos veces el mismo correo lo resuelve la `referencia`, no esta regla. Y nada se fusiona: esto solo avisa.
 *
 * Lógica pura, sin E/S: la prueban `test/connector.match.test.ts` y los escenarios de `test/connector.test.ts`.
 */

export type MatchPlace = "cola" | "bandeja" | "guardado";
export type MatchLevel = "fuerte" | "dudosa";

/** Un movimiento con el que comparar: lo que espera en la cola, un pendiente de la Bandeja o uno ya guardado. */
export interface MatchCandidate {
  donde: MatchPlace;
  /** De dónde vino («ai:Claude», «correo», «web», «applePay», «guardado»…). Misma fuente que lo nuevo ⇒ no casa. */
  fuente: string;
  kind: "expense" | "income";
  /** Siempre positivo. */
  amount: number;
  currency: string | null;
  /** AAAA-MM-DD en el día de la persona, o `null` si no se sabe. */
  day: string | null;
  account_id: string | null;
  account_name: string | null;
  merchant: string | null;
}

/** Lo que la IA va a apuntar, en la misma forma. */
export type IncomingDraft = Omit<MatchCandidate, "donde">;

export interface DuplicateMatch extends MatchCandidate {
  nivel: MatchLevel;
}

/** Cuántos se devuelven como mucho: la IA los enseña al usuario, y con cinco ya sabe que algo pasa. */
export const MAX_MATCHES = 5;
export const AMOUNT_EXACT = 0.01;
export const AMOUNT_RELATIVE = 0.03;
export const DAYS_CLOSE = 1;
export const DAYS_FAR = 3;

/** Minúsculas, sin tildes ni signos: «Café Tostado» y «CAFE TOSTADO» son el mismo comercio. */
export function foldText(text: string): string {
  return text
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .toLocaleLowerCase("es")
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim();
}

function tokens(text: string): string[] {
  return foldText(text)
    .split(" ")
    .filter((t) => t.length >= 3);
}

/** Parecidos: uno vacío (no resta), uno contiene al otro, o comparten una palabra de 3 letras o más. */
export function similarMerchant(a: string | null, b: string | null): boolean {
  const fa = foldText(a ?? "");
  const fb = foldText(b ?? "");
  if (fa === "" || fb === "") return true;
  const sa = fa.replace(/ /g, "");
  const sb = fb.replace(/ /g, "");
  if (sa.includes(sb) || sb.includes(sa)) return true;
  const tb = new Set(tokens(fb));
  return tokens(fa).some((t) => tb.has(t));
}

const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;

/** Días entre dos AAAA-MM-DD, en valor absoluto; `null` si alguno no es un día. */
export function dayDistance(a: string | null, b: string | null): number | null {
  if (!a || !b || !DAY_RE.test(a) || !DAY_RE.test(b)) return null;
  const ms = Math.abs(Date.parse(`${a}T00:00:00Z`) - Date.parse(`${b}T00:00:00Z`));
  return Number.isFinite(ms) ? Math.round(ms / 86_400_000) : null;
}

type AccountFit = "misma" | "abierta" | "distinta";

function accountFit(a: IncomingDraft, c: MatchCandidate): AccountFit {
  if (a.account_id && c.account_id) return a.account_id.toLowerCase() === c.account_id.toLowerCase() ? "misma" : "distinta";
  if (a.account_name && c.account_name) return foldText(a.account_name) === foldText(c.account_name) ? "misma" : "distinta";
  return "abierta";
}

/** El nivel de coincidencia de un candidato, o `null` si no casa. */
export function matchLevel(incoming: IncomingDraft, c: MatchCandidate): MatchLevel | null {
  if (c.fuente === incoming.fuente) return null;
  if (c.kind !== incoming.kind) return null;
  if (incoming.currency && c.currency && incoming.currency.toUpperCase() !== c.currency.toUpperCase()) return null;

  const account = accountFit(incoming, c);
  if (account === "distinta") return null;

  const diff = Math.abs(incoming.amount - c.amount);
  const exact = diff <= AMOUNT_EXACT + 1e-9;
  const near = diff <= Math.max(incoming.amount, c.amount) * AMOUNT_RELATIVE + 1e-9;
  if (!exact && !near) return null;

  const days = dayDistance(incoming.day, c.day);
  if (days === null || days > DAYS_FAR) return null;

  const strong = exact && days <= DAYS_CLOSE && account === "misma" && similarMerchant(incoming.merchant, c.merchant);
  return strong ? "fuerte" : "dudosa";
}

/** Los candidatos que casan, los fuertes primero y luego los más cercanos en día e importe. Como mucho `MAX_MATCHES`. */
export function findPossibleDuplicates(incoming: IncomingDraft, candidates: Iterable<MatchCandidate>): DuplicateMatch[] {
  const found: DuplicateMatch[] = [];
  for (const c of candidates) {
    const nivel = matchLevel(incoming, c);
    if (nivel) found.push({ ...c, nivel });
  }
  found.sort((x, y) => {
    if (x.nivel !== y.nivel) return x.nivel === "fuerte" ? -1 : 1;
    const dx = dayDistance(incoming.day, x.day) ?? 99;
    const dy = dayDistance(incoming.day, y.day) ?? 99;
    if (dx !== dy) return dx - dy;
    return Math.abs(incoming.amount - x.amount) - Math.abs(incoming.amount - y.amount);
  });
  return found.slice(0, MAX_MATCHES);
}
