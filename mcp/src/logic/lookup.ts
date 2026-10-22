/**
 * Índices de las entidades de referencia de un usuario, para resolver los `*_ref` de los movimientos.
 * Una referencia que no resuelve (entidad borrada o aún sin sincronizar) cuenta como ausente, igual que una
 * relación `nil` en SwiftData.
 */
import type { AccountRow, CategoryRow, SubcategoryRow, TagRow } from "./types";

export interface Lookup {
  accounts: Map<string, AccountRow>;
  categories: Map<string, CategoryRow>;
  subcategories: Map<string, SubcategoryRow>;
  tags: Map<string, TagRow>;
}

export function buildLookup(input: {
  accounts?: AccountRow[];
  categories?: CategoryRow[];
  subcategories?: SubcategoryRow[];
  tags?: TagRow[];
}): Lookup {
  const index = <T extends { sync_id: string }>(rows: T[] | undefined) => new Map((rows ?? []).map((r) => [r.sync_id, r]));
  return {
    accounts: index(input.accounts),
    categories: index(input.categories),
    subcategories: index(input.subcategories),
    tags: index(input.tags),
  };
}

/**
 * Categoría de un movimiento: SOLO su `category_ref`. No se deduce de la subcategoría aunque sería tentador: en la
 * app `TransactionItem.category` es una relación propia y, si es `nil`, el movimiento no entra en ingresos ni
 * gastos (`CashFlowCalculator`: «Must have a category»). Deducirla haría que las cifras no cuadren con la app.
 */
export function categoryOf(lookup: Lookup, tx: { category_ref: string | null }): CategoryRow | null {
  return tx.category_ref ? (lookup.categories.get(tx.category_ref) ?? null) : null;
}
