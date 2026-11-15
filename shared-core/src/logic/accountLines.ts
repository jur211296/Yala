/**
 * Tarjeta con varias divisas (entrega 4 del ticket `multi-currency-accounts-4-reports-and-export`): una tarjeta que cobra
 * en soles y en dólares es una cuenta PRINCIPAL y una LÍNEA por cada divisa extra, otra cuenta de una sola divisa con
 * `parent_account_id` = el `sync_id` de la principal.
 *
 * Port de `AccountLineLogic.resolve` (Yala/App/Logic/AccountLineLogic.swift:117) y de `AccountCardLogic.linesByHead` /
 * `includingLines` (Yala/App/Logic/AccountCardLogic.swift). Lo que decide qué es cada cuenta tiene que ser lo mismo aquí
 * y en la app: un enlace que la app lee roto (huérfano, en la misma divisa, a una cuenta de sistema, de dos niveles…) es
 * aquí también una cuenta suelta, y su gasto no entra en el presupuesto de la tarjeta.
 *
 * Diferencia de forma, no de regla: la app compara `UUID`, aquí `sync_id` en texto. Se comparan en minúsculas (la app
 * ordena por `uuidString`, en mayúsculas; el orden entre dos UUID no cambia con la caja porque los dígitos van antes que
 * las letras en los dos alfabetos).
 */
import type { AccountRow } from "./types";

/** Lo que la regla necesita de una cuenta. */
export interface AccountLineNode {
  id: string;
  parentId: string | null;
  currencyCode: string;
  isArchived: boolean;
  isSystem: boolean;
}

export type AccountLineRole =
  | { kind: "standalone" }
  | { kind: "principal"; lineIds: string[] }
  | { kind: "line"; principalId: string }
  | { kind: "broken"; reason: string };

function norm(id: string): string {
  return id.trim().toLowerCase();
}

/** `AccountLineNode(account)`: un campo nulo vale lo que vale por defecto en el modelo (`Account.swift`). */
export function lineNode(a: AccountRow): AccountLineNode {
  const parent = a.parent_account_id ?? null;
  return {
    id: norm(a.sync_id),
    parentId: parent && parent.trim() ? norm(parent) : null,
    currencyCode: a.currency_code ?? "USD",
    isArchived: a.is_archived === true,
    isSystem: a.is_system_account === true,
  };
}

function structuralIssue(
  node: AccountLineNode,
  parentId: string,
  counts: Map<string, number>,
  byId: Map<string, AccountLineNode>,
): string | null {
  if (parentId === node.id) return "selfLink";
  if ((counts.get(parentId) ?? 0) > 1) return "ambiguousIdentity";
  const parent = byId.get(parentId);
  if (!parent) return "orphan";
  if (node.isSystem || parent.isSystem) return "systemAccount";
  if (parent.parentId !== null) return "principalIsLine";
  if (parent.isArchived) return "principalArchived";
  if (parent.currencyCode === node.currencyCode) return "sameCurrencyAsPrincipal";
  return null;
}

/** El rol de cada cuenta por `sync_id` (en minúsculas). Determinista: no depende del orden de entrada. */
export function resolveLines(nodes: AccountLineNode[]): Map<string, AccountLineRole> {
  const counts = new Map<string, number>();
  for (const n of nodes) counts.set(n.id, (counts.get(n.id) ?? 0) + 1);
  const byId = new Map<string, AccountLineNode>();
  for (const n of nodes) if (counts.get(n.id) === 1) byId.set(n.id, n);

  const roles = new Map<string, AccountLineRole>();
  for (const n of nodes) roles.set(n.id, { kind: "standalone" });
  for (const n of nodes) {
    if ((counts.get(n.id) ?? 0) > 1 && n.parentId !== null) roles.set(n.id, { kind: "broken", reason: "ambiguousIdentity" });
  }

  const candidates: AccountLineNode[] = [];
  for (const n of byId.values()) {
    if (n.parentId === null) continue;
    const issue = structuralIssue(n, n.parentId, counts, byId);
    if (issue) roles.set(n.id, { kind: "broken", reason: issue });
    else candidates.push(n);
  }

  // Una línea viva por (principal, divisa): gana el menor id. Las archivadas no compiten.
  const linesByPrincipal = new Map<string, string[]>();
  const liveBySlot = new Map<string, AccountLineNode[]>();
  const addLine = (principalId: string, id: string) => {
    roles.set(id, { kind: "line", principalId });
    linesByPrincipal.set(principalId, [...(linesByPrincipal.get(principalId) ?? []), id]);
  };
  for (const n of candidates) {
    const parentId = n.parentId as string;
    if (n.isArchived) addLine(parentId, n.id);
    else {
      const key = `${parentId}|${n.currencyCode}`;
      liveBySlot.set(key, [...(liveBySlot.get(key) ?? []), n]);
    }
  }
  for (const slot of liveBySlot.values()) {
    const sorted = [...slot].sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
    const kept = sorted[0];
    if (!kept || kept.parentId === null) continue;
    addLine(kept.parentId, kept.id);
    for (const loser of sorted.slice(1)) roles.set(loser.id, { kind: "broken", reason: "duplicateCurrency" });
  }
  for (const [principalId, lineIds] of linesByPrincipal) {
    roles.set(principalId, { kind: "principal", lineIds: [...lineIds].sort() });
  }
  return roles;
}

/**
 * Las líneas de cada principal que tiene alguna, por `sync_id` en minúsculas. Incluye las archivadas, como
 * `AccountCardLogic.linesByHead`: archivar una línea no le quita su gasto al presupuesto de la tarjeta.
 */
export function linesByHead(accounts: Iterable<AccountRow>): Map<string, Set<string>> {
  const roles = resolveLines([...accounts].map(lineNode));
  const out = new Map<string, Set<string>>();
  for (const [id, role] of roles) {
    if (role.kind !== "line") continue;
    const set = out.get(role.principalId) ?? new Set<string>();
    set.add(id);
    out.set(role.principalId, set);
  }
  return out;
}

/**
 * Las cuentas cuyo gasto cuenta un presupuesto (`Budget.spendingAccountIDs`): las que guarda y las líneas de las
 * tarjetas que guarda. Lo guardado no cambia; solo se calcula con más cuentas. Devuelve ids en minúsculas.
 */
export function spendingAccountIds(stored: Iterable<string>, lines: Map<string, Set<string>>): Set<string> {
  const out = new Set<string>();
  for (const raw of stored) {
    const id = norm(raw);
    out.add(id);
    for (const line of lines.get(id) ?? []) out.add(line);
  }
  return out;
}
