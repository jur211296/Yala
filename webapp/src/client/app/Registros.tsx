/**
 * Registros: lista por días, de 50 en 50, con buscar (en la nota), filtrar por mes, cuenta y categoría, y el detalle de
 * cada uno. En la beta solo se mira: editar llega cuando la web sea un aparato más (lote 4).
 */
import { useEffect, useMemo, useRef, useState } from "react";
import { texts } from "../i18n";
import { getJson, type Categoria, type Cuenta, type Movimiento, type PaginaRegistros } from "./api";
import { dayLabel, money, todayKey } from "./format";
import { MovimientoRow } from "./Panel";

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

export function Registros({ cuentas }: { cuentas: Cuenta[] }) {
  const [periodo, setPeriodo] = useState<Periodo>("mes");
  const [cuenta, setCuenta] = useState("");
  const [categoria, setCategoria] = useState("");
  const [texto, setTexto] = useState("");
  const [buscar, setBuscar] = useState("");
  const [cats, setCats] = useState<Categoria[]>([]);
  const [items, setItems] = useState<Movimiento[] | null>(null);
  const [cursor, setCursor] = useState<string | null>(null);
  const [error, setError] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [open, setOpen] = useState<Movimiento | null>(null);
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
      },
      () => mine === seq.current && setError(true),
    );
  }, [query]);

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

  return (
    <>
      <div className="chips" role="group" aria-label={t.app.registros}>
        {(["mes", "pasado", "todo"] as const).map((p) => (
          <button key={p} type="button" className={`chip${periodo === p ? " on" : ""}`} aria-pressed={periodo === p} onClick={() => setPeriodo(p)}>
            {p === "mes" ? t.app.esteMes : p === "pasado" ? t.app.mesPasado : t.app.todo}
          </button>
        ))}
        <select aria-label={t.app.cuenta} value={cuenta} onChange={(e) => setCuenta(e.target.value)}>
          <option value="">{t.app.todasLasCuentas}</option>
          {accountNames.map((n) => (
            <option key={n} value={n}>
              {n}
            </option>
          ))}
        </select>
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
        <input type="search" aria-label={t.app.buscar} placeholder={t.app.buscar} value={texto} onChange={(e) => setTexto(e.target.value)} maxLength={60} />
      </div>

      <section className="cd" aria-busy={items === null}>
        {error ? <p className="empty">{t.app.noCargo}</p> : null}
        {items === null && !error ? (
          <>
            <div className="skel" style={{ width: "40%" }} />
            <div className="skel" />
            <div className="skel" />
          </>
        ) : null}
        {items && items.length === 0 ? <p className="empty">{t.app.sinRegistros}</p> : null}
        {groups.map((g, i) => (
          <div key={`${g.day}-${i}`}>
            <div className="day">{dayLabel(g.day)}</div>
            {g.rows.map((m) => (
              <MovimientoRow key={m.id} m={m} onOpen={setOpen} />
            ))}
          </div>
        ))}
      </section>
      {cursor ? (
        <button className="more" type="button" onClick={more} disabled={loadingMore}>
          {t.app.cargarMas}
        </button>
      ) : null}
      <p className="note-y">{t.app.registrosNota}</p>

      {open ? <Detalle m={open} onClose={() => setOpen(null)} /> : null}
    </>
  );
}

function Detalle({ m, onClose }: { m: Movimiento; onClose: () => void }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);
  const rows: [string, string][] = [
    [t.app.tipo, t.app.tipos[m.tipo] ?? m.tipo],
    [t.app.fecha, dayLabel(m.fecha)],
    [t.app.cuenta, m.cuenta ?? t.app.sinCuenta],
    [t.app.categoria, m.categoria ?? t.app.sinCategoria],
  ];
  if (m.subcategoria) rows.push([t.app.subcategoria, m.subcategoria]);
  if (m.etiquetas.length) rows.push([t.app.etiquetas, m.etiquetas.join(", ")]);
  return (
    <div className="modal" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="sheet" role="dialog" aria-modal="true" aria-label={t.app.detalle}>
        <h2>
          {m.nota || t.app.detalle}
          <button className="btn-s" type="button" onClick={onClose} autoFocus>
            {t.app.cerrar}
          </button>
        </h2>
        <div className="amt-in">
          <b className={`amt${m.tipo === "ingreso" ? " in" : ""}`} style={{ fontSize: 30 }}>
            {money(m.importe, m.divisa, { sign: m.tipo === "ingreso" })}
          </b>
        </div>
        {rows.map(([k, v]) => (
          <div className="fld" key={k}>
            <span>{k}</span>
            <span>{v}</span>
          </div>
        ))}
        {m.gasto_de_grupo ? <p className="note-y">{t.app.gastoDeGrupo}</p> : null}
        <p className="note-y">{t.app.registrosNota}</p>
      </div>
    </div>
  );
}
