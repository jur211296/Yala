/**
 * Registros: lista por días, de 50 en 50, con buscar (en la nota), filtrar por mes, cuenta y categoría, y el detalle de
 * cada uno. En la beta solo se mira: editar llega cuando la web sea un aparato más.
 *
 * Lote 2b: «Exportar CSV» baja lo que se está viendo (mismos filtros) con el formato del iPhone (`csv.ts`), y la búsqueda
 * ⌘K abre Registros ya filtrado (`inicial`).
 *
 * Lote 4 de «Yala web como la app»: arriba, lo que te queda en el período («Te queda», con entradas y salidas), las mismas
 * cifras que Estadísticas (decisión D3: solo sin filtro de cuenta, categoría ni texto). Los filtros son cápsulas de
 * cristal; cada registro, una tarjeta (`FilaRegistro`); cada día, su cabecera con lo gastado. En escritorio ancho el
 * detalle se abre a la derecha, sin tapar la lista; en el celular, en una hoja.
 */
import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { Calendar, ChevronDown, CreditCard, Download, Search, Tag, X } from "lucide-react";
import { texts } from "../i18n";
import { getJson, type Categoria, type Cuenta, type Estadisticas, type Movimiento, type PaginaRegistros } from "./api";
import { buildCsv, CSV_MAX_ROWS } from "./csv";
import { money, todayKey } from "./format";
import { DetalleRegistro, DiaRegistros, FilaRegistro } from "./FilaRegistro";
import { gastadoDelDia } from "./registro";
import { Monto } from "./Monto";

const t = texts();
type Periodo = "mes" | "pasado" | "todo";

function range(p: Periodo): { desde?: string; hasta?: string } {
  if (p === "todo") return {};
  const [y, m] = todayKey().split("-").map(Number);
  const year = p === "mes" ? y! : m === 1 ? y! - 1 : y!;
  const month = p === "mes" ? m! : m === 1 ? 12 : m! - 1;
  const last = new Date(year, month, 0).getDate();
  const mm = String(month).padStart(2, "0");
  return { desde: `${year}-${mm}-01`, hasta: `${year}-${mm}-${String(last).padStart(2, "0")}` };
}

/** El filtro con el que abre Registros la búsqueda ⌘K. Un texto busca en todo el tiempo; una cuenta o una categoría, en el mes. */
export interface FiltroInicial {
  cuenta?: string;
  categoria?: string;
  texto?: string;
}

/** Descarga un texto como archivo, sin pasar por el servidor. */
function download(name: string, content: string): void {
  const url = URL.createObjectURL(new Blob([content], { type: "text/csv;charset=utf-8" }));
  const a = document.createElement("a");
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 1_000);
}

/** Desde qué ancho de ventana el detalle va a la derecha de la lista (decisión D5). */
const ANCHO_DETALLE = "(min-width: 1100px)";

/** ¿La ventana es lo bastante ancha para lista y detalle lado a lado? Sigue a la ventana si cambia de tamaño. */
function useAncho(query: string): boolean {
  const [ok, setOk] = useState(() => typeof window.matchMedia === "function" && window.matchMedia(query).matches);
  useEffect(() => {
    if (typeof window.matchMedia !== "function") return;
    const mq = window.matchMedia(query);
    const on = () => setOk(mq.matches);
    on();
    mq.addEventListener("change", on);
    return () => mq.removeEventListener("change", on);
  }, [query]);
  return ok;
}

export function Registros({
  cuentas,
  inicial,
  onToast,
  accion,
}: {
  cuentas: Cuenta[];
  inicial?: FiltroInicial;
  onToast?: (s: string) => void;
  /** «+ Nuevo registro» del celular: va debajo del resumen, como en la app. */
  accion?: ReactNode;
}) {
  const [periodo, setPeriodo] = useState<Periodo>(inicial?.texto ? "todo" : "mes");
  const [cuenta, setCuenta] = useState(inicial?.cuenta ?? "");
  const [categoria, setCategoria] = useState(inicial?.categoria ?? "");
  const [texto, setTexto] = useState(inicial?.texto ?? "");
  const [buscar, setBuscar] = useState(inicial?.texto?.trim() ?? "");
  const [exportando, setExportando] = useState<number | null>(null);
  const [cats, setCats] = useState<Categoria[]>([]);
  const [items, setItems] = useState<Movimiento[] | null>(null);
  const [cursor, setCursor] = useState<string | null>(null);
  const [error, setError] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [open, setOpen] = useState<Movimiento | null>(null);
  const [divisaDia, setDivisaDia] = useState<string | null>(null);
  const [resumen, setResumen] = useState<Estadisticas["resumen"] | null>(null);
  const [resumenFallo, setResumenFallo] = useState(false);
  const ancho = useAncho(ANCHO_DETALLE);
  const seq = useRef(0);

  useEffect(() => {
    getJson<{ categorias: Categoria[] }>("/api/categorias").then((r) => setCats(r.categorias), () => undefined);
  }, []);

  // El texto se busca al dejar de escribir.
  useEffect(() => {
    const id = window.setTimeout(() => setBuscar(texto.trim()), 350);
    return () => window.clearTimeout(id);
  }, [texto]);

  const query = useMemo(() => {
    const q = new URLSearchParams();
    const r = range(periodo);
    if (r.desde) q.set("desde", r.desde);
    if (r.hasta) q.set("hasta", r.hasta);
    if (cuenta) q.set("cuenta", cuenta);
    if (categoria) q.set("categoria", categoria);
    if (buscar) q.set("texto", buscar);
    return q;
  }, [periodo, cuenta, categoria, buscar]);

  useEffect(() => {
    const mine = ++seq.current;
    setItems(null);
    setError(false);
    getJson<PaginaRegistros>(`/api/registros?${query}`).then(
      (p) => {
        if (mine !== seq.current) return;
        setItems(p.movimientos);
        setCursor(p.siguiente_cursor);
        setDivisaDia(p.divisa_preferida ?? null);
      },
      () => mine === seq.current && setError(true),
    );
  }, [query]);

  // El resumen del período: el de Estadísticas, que cuenta como la app. Solo sin filtros que la cifra no recogería.
  const conResumen = periodo !== "todo" && !cuenta && !categoria && !buscar;
  useEffect(() => {
    setResumen(null);
    setResumenFallo(false);
    if (!conResumen) return;
    let vivo = true;
    getJson<Estadisticas>(`/api/estadisticas?periodo=${periodo === "mes" ? "mes_actual" : "mes_pasado"}`).then(
      (e) => vivo && setResumen(e.resumen),
      () => vivo && setResumenFallo(true),
    );
    return () => {
      vivo = false;
    };
  }, [conResumen, periodo]);

  const more = () => {
    if (!cursor) return;
    const mine = seq.current;
    setLoadingMore(true);
    const q = new URLSearchParams(query);
    q.set("cursor", cursor);
    getJson<PaginaRegistros>(`/api/registros?${q}`)
      .then((p) => {
        if (mine !== seq.current) return;
        setItems((prev) => [...(prev ?? []), ...p.movimientos]);
        setCursor(p.siguiente_cursor);
      }, () => setError(true))
      .finally(() => setLoadingMore(false));
  };

  // Exportar: de 200 en 200 con los filtros que se ven, hasta el tope. El archivo se arma aquí.
  const exportCsv = async () => {
    if (exportando !== null) return;
    setExportando(0);
    const rows: Movimiento[] = [];
    let next: string | null = null;
    let cut = false;
    try {
      do {
        const q = new URLSearchParams(query);
        q.set("limite", "200");
        if (next) q.set("cursor", next);
        const p: PaginaRegistros = await getJson<PaginaRegistros>(`/api/registros?${q}`);
        rows.push(...p.movimientos);
        next = p.siguiente_cursor;
        setExportando(rows.length);
        if (next && rows.length >= CSV_MAX_ROWS) cut = true;
      } while (next && !cut);
      if (rows.length === 0) {
        onToast?.(t.csv.vacio);
        return;
      }
      download(`${t.csv.archivo}-${todayKey()}.csv`, buildCsv(rows.slice(0, CSV_MAX_ROWS)));
      onToast?.(cut ? t.csv.cortado(Math.min(rows.length, CSV_MAX_ROWS)) : t.csv.listo(rows.length));
    } catch {
      onToast?.(t.csv.error);
    } finally {
      setExportando(null);
    }
  };

  
  const groups = useMemo(() => {
    const out: { day: string | null; rows: Movimiento[] }[] = [];
    for (const m of items ?? []) {
      const last = out[out.length - 1];
      if (last && last.day === m.fecha) last.rows.push(m);
      else out.push({ day: m.fecha, rows: [m] });
    }
    return out;
  }, [items]);

  const accountNames = [...new Set(cuentas.filter((c) => !c.archivada).map((c) => c.nombre))];
  // En escritorio ancho siempre hay un registro abierto a la derecha: el elegido o, si no, el primero.
  const abierto = ancho ? (open && items?.some((m) => m.id === open.id) ? open : (items?.[0] ?? null)) : null;

  const lista = (
    <section className="reg-lista" aria-busy={items === null} aria-label={t.app.registros}>
      {error ? <p className="empty">{t.app.noCargo}</p> : null}
      {items === null && !error ? (
        <div className="cd">
          <div className="skel" style={{ width: "40%" }} />
          <div className="skel" />
          <div className="skel" />
        </div>
      ) : null}
      {items && items.length === 0 ? <p className="empty">{t.app.sinRegistros}</p> : null}
      {groups.map((g, i) => (
        <div key={`${g.day}-${i}`} className="reg-dia">
          {/* El último día de la página puede seguir en la siguiente: su total, cuando ya esté entero. */}
          <DiaRegistros dia={g.day} gastado={cursor && i === groups.length - 1 ? null : gastadoDelDia(g.rows)} divisa={divisaDia} />
          <div className="filas">
            {g.rows.map((m) => (
              <FilaRegistro key={m.id} m={m} onOpen={setOpen} abierta={abierto?.id === m.id} />
            ))}
          </div>
        </div>
      ))}
      {cursor ? (
        <button className="more" type="button" onClick={more} disabled={loadingMore}>
          {t.app.cargarMas}
        </button>
      ) : null}
      <p className="note-y">{t.app.registrosNota}</p>
    </section>
  );

  return (
    <>
      {resumen ? (
        <section className="resumen" aria-label={periodo === "mes" ? t.app.teQueda : t.app.teQuedo}>
          <span className="cap">{periodo === "mes" ? t.app.teQueda : t.app.teQuedo}</span>
          <span className="big">
            {resumen.aproximado.neto ? "≈ " : ""}
            <Monto importe={resumen.neto} divisa={resumen.divisa} tam="hero" />
          </span>
          <span className="inout">
            <span>
              ↗ {t.app.entradas} <b className="amt in">{money(resumen.ingresos, resumen.divisa)}</b>
            </span>
            <span>
              ↘ {t.app.salidas} <b>{money(resumen.gastos, resumen.divisa)}</b>
            </span>
            <span>{t.est.movimientos(resumen.movimientos)}</span>
          </span>
        </section>
      ) : conResumen && !resumenFallo ? (
        // Mientras llega la cifra, su hueco: si no, la lista salta hacia abajo al llegar (medido en el iPhone: 1,4 s).
        <div className="resumen" aria-busy="true">
          <div className="skel" style={{ width: 90 }} />
          <div className="skel" style={{ width: 200, height: 44 }} />
          <div className="skel" style={{ width: "60%" }} />
        </div>
      ) : null}
      {accion}

      <div className="filtros" role="group" aria-label={t.app.registros}>
        <label className="cap-sel on">
          <Calendar aria-hidden={true} focusable={false} />
          <select aria-label={t.app.fecha} value={periodo} onChange={(e) => setPeriodo(e.target.value as Periodo)}>
            <option value="mes">{t.app.esteMes}</option>
            <option value="pasado">{t.app.mesPasado}</option>
            <option value="todo">{t.app.todo}</option>
          </select>
          <ChevronDown aria-hidden={true} focusable={false} />
        </label>
        <label className={`cap-sel${cuenta ? " on" : ""}`}>
          <CreditCard aria-hidden={true} focusable={false} />
          <select aria-label={t.app.cuenta} value={cuenta} onChange={(e) => setCuenta(e.target.value)}>
            <option value="">{t.app.todasLasCuentas}</option>
            {accountNames.map((n) => (
              <option key={n} value={n}>
                {n}
              </option>
            ))}
          </select>
          <ChevronDown aria-hidden={true} focusable={false} />
        </label>
        <label className={`cap-sel${categoria ? " on" : ""}`}>
          <Tag aria-hidden={true} focusable={false} />
          <select aria-label={t.app.categoria} value={categoria} onChange={(e) => setCategoria(e.target.value)}>
            <option value="">{t.app.todasLasCategorias}</option>
            {cats
              .filter((c) => !c.oculta)
              .map((c) => (
                <option key={c.id} value={c.nombre}>
                  {c.nombre}
                </option>
              ))}
          </select>
          <ChevronDown aria-hidden={true} focusable={false} />
        </label>
        <label className="cap-buscar">
          <Search aria-hidden={true} focusable={false} />
          <input type="search" aria-label={t.app.buscar} placeholder={t.app.buscar} value={texto} onChange={(e) => setTexto(e.target.value)} maxLength={60} />
        </label>
        <button className="cap-btn exp" type="button" onClick={() => void exportCsv()} disabled={exportando !== null} aria-live="polite">
          <Download aria-hidden={true} focusable={false} />
          {exportando === null ? t.csv.exportar : t.csv.exportando(exportando)}
        </button>
      </div>

      {ancho ? (
        <div className="reg-split">
          {lista}
          {abierto ? (
            <aside className="reg-det" aria-label={t.app.detalle}>
              <DetalleRegistro m={abierto} />
            </aside>
          ) : null}
        </div>
      ) : (
        lista
      )}

      {!ancho && open ? <Detalle m={open} onClose={() => setOpen(null)} /> : null}
    </>
  );
}

/** El detalle en una hoja: en el celular, en una ventana estrecha y desde la búsqueda ⌘K. */
export function Detalle({ m, onClose }: { m: Movimiento; onClose: () => void }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);
  return (
    <div className="modal" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="sheet det-sheet" role="dialog" aria-modal="true" aria-label={t.app.detalle}>
        <DetalleRegistro
          m={m}
          acciones={
            <button className="ib cerrar" type="button" onClick={onClose} aria-label={t.app.cerrar} autoFocus>
              <X aria-hidden={true} focusable={false} />
            </button>
          }
        />
      </div>
    </div>
  );
}
