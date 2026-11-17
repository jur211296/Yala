/**
 * El ícono y el color de una categoría a partir de su NOMBRE (lote 5 de «Yala web como la app», decisión D1).
 *
 * Presupuestos, Pagos planificados, Estadísticas, la Bandeja y los gastos de un grupo solo reciben el nombre de la
 * categoría o de la subcategoría, no su `icon_name` ni su color. Para pintarlos como la app se buscan en
 * `/api/categorias`, que se pide una sola vez por visita (`useCategorias`). Sin coincidencia, el respaldo de la app.
 *
 * La búsqueda (`simboloPorNombre`) vive en `pantallas.ts`, pura, para probarla sin navegador (`test/lote5.test.ts`).
 */
import { useEffect, useState } from "react";
import { getJson, type Categoria } from "./api";

export { simboloPorNombre, type Simbolo } from "./pantallas";

let pedido: Promise<Categoria[]> | null = null;

/** `/api/categorias`, una sola vez por visita; si falla, la siguiente llamada lo vuelve a pedir. */
export function cargarCategorias(): Promise<Categoria[]> {
  if (!pedido) {
    pedido = getJson<{ categorias: Categoria[] }>("/api/categorias").then(
      (r) => r.categorias,
      (err: unknown) => {
        pedido = null;
        throw err;
      },
    );
  }
  return pedido;
}

/** Las categorías de la cuenta, o `null` mientras llegan (o si no llegaron: se pinta el respaldo). */
export function useCategorias(): Categoria[] | null {
  const [cats, setCats] = useState<Categoria[] | null>(null);
  useEffect(() => {
    let vivo = true;
    cargarCategorias().then(
      (c) => vivo && setCats(c),
      () => undefined,
    );
    return () => {
      vivo = false;
    };
  }, []);
  return cats;
}

