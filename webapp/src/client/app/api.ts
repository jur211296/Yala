/**
 * Lo que la página le pide al Worker. Todo va con la cookie (que la página no puede leer) y sin caché. Un 401 en
 * cualquier llamada significa que la sesión se cerró (desde el iPhone, desde otra pestaña o porque caducó): la página
 * vuelve a la pantalla de entrar con el aviso de sesión cerrada.
 */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly body: Record<string, unknown>,
  ) {
    super(`api ${status}`);
  }
}

function signedOut(): never {
  window.location.replace("/?aviso=cerrada");
  throw new ApiError(401, {});
}

export async function getJson<T>(path: string): Promise<T> {
  const res = await fetch(path, { credentials: "same-origin", cache: "no-store" });
  if (res.status === 401) signedOut();
  if (!res.ok) throw new ApiError(res.status, ((await res.json().catch(() => ({}))) as Record<string, unknown>) ?? {});
  return (await res.json()) as T;
}

export async function postJson<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(path, {
    method: "POST",
    credentials: "same-origin",
    cache: "no-store",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (res.status === 401) signedOut();
  const data = ((await res.json().catch(() => ({}))) as Record<string, unknown>) ?? {};
  if (!res.ok) throw new ApiError(res.status, data);
  return data as T;
}

// ─── Formas de las respuestas (las del núcleo compartido, `shared-core/src/toolCore.ts`) ──────────────────────

export interface Cuenta {
  id: string;
  nombre: string;
  tipo: string | null;
  divisa: string | null;
  saldo: number;
  archivada: boolean;
  excluida_de_estadisticas: boolean;
  /** SF Symbol de la cuenta, ya con la regla de la app (`displayIconName`): nunca vacío. Se pinta con `simbolos.ts`. */
  icono: string;
  /** «#RRGGBB» o `null` (la app usa su índigo). */
  color: string | null;
}

/** Necesidad de un registro, con los valores de la app (`SubcategoryNeed`). */
export type Necesidad = "esencial" | "prioritaria" | "opcional" | "sin_clasificacion";

export interface Movimiento {
  id: string;
  fecha: string | null;
  importe: number | null;
  divisa: string | null;
  importe_en_divisa_preferida: number | null;
  nota: string | null;
  tipo: "gasto" | "ingreso" | "transferencia" | "ajuste_de_saldo";
  categoria: string | null;
  subcategoria: string | null;
  cuenta: string | null;
  etiquetas: string[];
  gasto_de_grupo: boolean;
  categoria_id: string | null;
  subcategoria_id: string | null;
  cuenta_id: string | null;
  /** SF Symbol del círculo de la fila (el de la subcategoría o el de la categoría); `null`: el respaldo de la app. */
  icono: string | null;
  /** Color de la categoría, «#RRGGBB»; `null`: el índigo de la app. */
  color: string | null;
  /** `effectiveNeed` de la app. La fila de la app solo enseña la píldora si el registro tiene subcategoría. */
  necesidad: Necesidad;
}

export interface Panel {
  cuentas: { cuentas: Cuenta[]; total: { divisa: string; importe: number; aproximado: boolean } };
  mes: {
    divisa: string;
    ingresos: number;
    gastos: number;
    aproximado: boolean;
    top_categorias_gasto: { categoria: string; importe: number; movimientos: number }[];
  };
  ultimos: { movimientos: Movimiento[] };
}

export interface PaginaRegistros {
  movimientos: Movimiento[];
  siguiente_cursor: string | null;
  avisos: string[];
}

export interface Categoria {
  id: string;
  nombre: string;
  es_ingreso: boolean;
  oculta: boolean;
  /** SF Symbol y color guardados, crudos (`null` si no hay): cada pantalla de la app elige su respaldo. */
  icono: string | null;
  color: string | null;
  subcategorias: { id: string; nombre: string; oculta: boolean; icono: string | null; color: string | null }[];
}

export interface Pendiente {
  sync_id: string;
  note: string | null;
  amount: number | string | null;
  date: string | null;
  cached_currency_code: string | null;
  cached_account_name: string | null;
  cached_subcategory_name: string | null;
  source_type_raw: string | null;
  evidence: string | null;
  created_at: string | null;
  needs_user_input: string[] | null;
}

export interface Enviado {
  id: string;
  enviado: number;
  tipo: "gasto" | "ingreso";
  importe: number;
  divisa: string;
  descripcion: string | null;
  fecha: string | null;
  cuenta: string | null;
  subcategoria: string | null;
}

export interface Bandeja {
  pendientes: Pendiente[];
  enviados: Enviado[];
}

export interface Sesion {
  id: string;
  navegador: string;
  sistema: string;
  ciudad: string | null;
  creada: number;
  ultimoUso: number;
  equipoCompartido: boolean;
  esta: boolean;
}

// ─── Lote 2: Estadísticas y Pagos planificados ─────────────────────────────────────────────────────────────────

export type PeriodoEst = "mes_actual" | "mes_pasado" | "anio_actual";

export interface Trozo {
  id: string | null;
  categoria: string | null;
  importe: number;
  porcentaje: number;
  movimientos: number;
}

export interface Estadisticas {
  periodo: PeriodoEst;
  resumen: {
    divisa: string;
    periodo: { desde: string; hasta: string };
    ingresos: number;
    gastos: number;
    neto: number;
    movimientos: number;
    variacion: { ingresos: number | null; gastos: number | null; neto: number | null; gasto_medio_diario: number | null };
    gasto_medio_diario: number;
    dias: number;
    top_categorias: Trozo[];
    gasto_mas_alto: { importe: number; nota: string | null; categoria: string | null; dia: string } | null;
    aproximado: { ingresos: boolean; gastos: boolean; neto: boolean };
    sin_categoria: number;
  };
  distribucion: { divisa: string; total: number; categorias: Trozo[] };
  tendencias: { mes: string; desde: string; hasta: string; ingresos: number; gastos: number; neto: number }[];
  incompleto: boolean;
}

export interface Cobro {
  id: string;
  nombre: string;
  dia: string;
  en_dias: number;
  importe: number;
  divisa: string;
  importe_en_divisa_preferida: number | null;
  movimiento: "gasto" | "ingreso";
  tipo: "suscripcion" | "recurrente" | "unico";
  frecuencia: string;
  cada: number;
  categoria: string | null;
  /** Lote 2b: ya pagado, con la regla de la lista del iPhone (`webapp/src/worker/paid.ts`). */
  pagado: boolean;
}

export interface Suscripcion {
  id: string;
  nombre: string;
  importe: number;
  divisa: string;
  frecuencia: string;
  cada: number;
  proximo_cobro: string | null;
  equivalente_mensual_en_divisa_preferida: number | null;
  categoria: string | null;
}

export interface Pagos {
  divisa: string;
  proximos: Cobro[];
  /** Lo que queda por pagar: los gastos de la lista que no están pagados. */
  total_gastos: number;
  pagados: number;
  suscripciones: Suscripcion[];
  suscripciones_mensual: number;
  aproximado: boolean;
  incompleto: boolean;
}

// ─── Grupos (lote 3, lectura): `webapp/src/worker/groups.ts` ────────────────────────────────────────────────────

export interface Dinero {
  divisa: string;
  importe: number;
}

export interface Banda {
  estado: "theyOweMe" | "iOwe" | "mixed" | "settled";
  teDeben: Dinero[];
  debes: Dinero[];
}

export interface GrupoTarjeta {
  id: string;
  nombre: string;
  icono: string | null;
  color: string | null;
  divisa: string | null;
  archivado: boolean;
  miembros: number;
  gastos: number;
  banda: Banda;
  personas: { nombre: string; sentido: "debes" | "teDebe"; importe: number; divisa: string }[];
}

export interface GruposLista {
  resumen: { teDeben: Dinero[]; debes: Dinero[]; pagosPorConfirmar: number };
  grupos: GrupoTarjeta[];
  incompleto: boolean;
}

export interface GrupoDetalle {
  id: string;
  nombre: string;
  divisa: string | null;
  archivado: boolean;
  incompleto: boolean;
  menosPagos: boolean;
  unaSolaMoneda: string | null;
  miembros: { clave: string; nombre: string; rol: string; esTu: boolean }[];
  banda: Banda;
  /** Lote 3, opción A: si la web deja añadir, saldar e invitar aquí, y con qué divisas. */
  puedeEscribir: boolean;
  puedeInvitar: boolean;
  divisas: string[];
  deudas: { de: string; a: string; deClave: string; aClave: string; deTi: boolean; aTi: boolean; importe: number; divisa: string }[];
  saldos: { nombre: string; esTu: boolean; divisa: string; pago: number; leToca: number; neto: number }[];
  gastos: {
    id: string;
    descripcion: string;
    nota: string | null;
    importe: number;
    divisa: string;
    fecha: string | null;
    pagadoPor: string;
    pagasteTu: boolean;
    tuParte: number | null;
    categoria: string | null;
    saldoInicial: boolean;
    saldado: boolean;
  }[];
  pagos: { id: string; de: string; a: string; deTi: boolean; aTi: boolean; importe: number; divisa: string; fecha: string | null; confirmado: boolean; nota: string | null }[];
}

// ─── Lote 2b: Presupuestos (`estado_presupuestos` del núcleo) ──────────────────────────────────────────────────

export interface Presupuesto {
  id: string;
  nombre: string;
  divisa: string;
  limite: number;
  gastado: number;
  porcentaje: number | null;
  restante: number;
  periodo: { tipo: "semanal" | "mensual" | "anual" | "unico"; desde: string; hasta: string };
  dias_restantes: number;
  estado: "sin_limite" | "excedido" | "en_riesgo" | "en_camino" | "inactivo";
  activo: boolean;
  movimientos: number;
  aproximado: boolean;
}

export interface Presupuestos {
  presupuestos: Presupuesto[];
  avisos: string[];
}
