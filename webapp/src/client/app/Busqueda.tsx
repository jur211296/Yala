/**
 * Buscar en todo (⌘K, lote 2b): una paleta que abre ⌘K o Ctrl+K desde cualquier sección, el campo «Buscar» de la barra
 * lateral en escritorio o la lupa redonda junto a las pestañas en el celular, como en la app (lote 3 de «Yala web como
 * la app»). Al cerrarla, el foco vuelve a donde estaba. Busca en:
 *
 * - las secciones (ir a), Planificación y sus dos segmentos incluidos;
 * - las cuentas y las categorías (abren Registros con ese filtro, en el mes);
 * - los presupuestos (abren Presupuestos);
 * - las notas de los registros, en el servidor (`/api/registros?texto=`, la misma búsqueda que Registros); uno abre su
 *   detalle, y la última fila abre Registros con ese texto en todo el tiempo.
 *
 * Lo de la propia página (secciones, cuentas) se filtra aquí, sin tildes ni mayúsculas. Una cuenta «solo Grupos» solo
 * busca secciones: lo demás vive en la nube completa.
 *
 * Accesible como un combobox con lista: flechas para moverse, Intro para abrir, Esc para cerrar.
 */
import { useEffect, useMemo, useRef, useState, type KeyboardEvent, type ReactNode } from "react";
import { texts } from "../i18n";
import { getJson, type Categoria, type Cuenta, type Movimiento, type PaginaRegistros, type Presupuestos } from "./api";
import { dayLabel, money, named } from "./format";
import { Icons } from "./icons";
import { Detalle, type FiltroInicial } from "./Registros";

const t = texts();

export interface Destino {
  key: string;
  label: string;
  icon: ReactNode;
}

interface Item {
  id: string;
  group: string;
  label: string;
  hint?: string;
  amount?: ReactNode;
  icon?: ReactNode;
  run: () => void;
}

/** Sin tildes ni mayúsculas: «cafe» encuentra «Café». */
export function fold(s: string): string {
  return s.normalize("NFD").replace(/\p{Diacritic}/gu, "").toLocaleLowerCase();
}

export function matches(name: string, q: string): boolean {
  const n = fold(q.trim());
  return n.length > 0 && fold(name).includes(n);
}

const MAX_PER_GROUP = 5;

export function Busqueda({
  solo,
  destinos,
  cuentas,
  onClose,
  onGo,
  onRegistros,
}: {
  solo: boolean;
  destinos: Destino[];
  cuentas: Cuenta[];
  onClose: () => void;
  onGo: (key: string) => void;
  onRegistros: (f: FiltroInicial) => void;
}) {
  const [q, setQ] = useState("");
  const [active, setActive] = useState(0);
  const [cats, setCats] = useState<Categoria[]>([]);
  const [budgets, setBudgets] = useState<{ id: string; nombre: string }[]>([]);
  const [records, setRecords] = useState<Movimiento[] | null>(null);
  const [searching, setSearching] = useState(false);
  const [detail, setDetail] = useState<Movimiento | null>(null);
  const input = useRef<HTMLInputElement>(null);
  const seq = useRef(0);

  // Lo que no trae el Panel se pide al abrir, una vez.
  useEffect(() => {
    if (solo) return;
    getJson<{ categorias: Categoria[] }>("/api/categorias").then((r) => setCats(r.categorias), () => undefined);
    getJson<Presupuestos>("/api/presupuestos").then((r) => setBudgets(r.presupuestos.map((b) => ({ id: b.id, nombre: named(b.nombre) }))), () => undefined);
  }, [solo]);

  // Las notas se buscan en el servidor al dejar de escribir.
  useEffect(() => {
    const text = q.trim();
    const mine = ++seq.current;
    if (solo || text.length < 2) {
      setRecords(null);
      setSearching(false);
      return;
    }
    setSearching(true);
    const id = window.setTimeout(() => {
      getJson<PaginaRegistros>(`/api/registros?${new URLSearchParams({ texto: text })}`).then(
        (p) => mine === seq.current && setRecords(p.movimientos),
        () => mine === seq.current && setRecords([]),
      ).finally(() => mine === seq.current && setSearching(false));
    }, 250);
    return () => window.clearTimeout(id);
  }, [q, solo]);

  const items = useMemo<Item[]>(() => {
    const text = q.trim();
    const out: Item[] = [];
    const shownDest = text ? destinos.filter((d) => matches(d.label, text)) : destinos;
    for (const d of shownDest) out.push({ id: `s-${d.key}`, group: t.bus.secciones, label: d.label, icon: d.icon, run: () => onGo(d.key) });
    if (!text || solo) return out;

    const names = new Set<string>();
    for (const c of cuentas) {
      if (c.archivada || names.has(c.nombre) || !matches(c.nombre, text)) continue;
      names.add(c.nombre);
      if (names.size > MAX_PER_GROUP) break;
      out.push({ id: `c-${c.id}`, group: t.bus.cuentas, label: c.nombre, run: () => onRegistros({ cuenta: c.nombre }) });
    }
    let n = 0;
    for (const c of cats) {
      if (c.oculta || n >= MAX_PER_GROUP) continue;
      if (matches(c.nombre, text)) {
        out.push({ id: `k-${c.id}`, group: t.bus.categorias, label: c.nombre, run: () => onRegistros({ categoria: c.nombre }) });
        n += 1;
        continue;
      }
      const sub = c.subcategorias.find((s) => !s.oculta && matches(s.nombre, text));
      if (sub) {
        out.push({ id: `k-${sub.id}`, group: t.bus.categorias, label: sub.nombre, hint: c.nombre, run: () => onRegistros({ categoria: sub.nombre }) });
        n += 1;
      }
    }
    for (const b of budgets.filter((x) => matches(x.nombre, text)).slice(0, MAX_PER_GROUP)) {
      out.push({ id: `p-${b.id}`, group: t.bus.presupuestos, label: b.nombre, run: () => onGo("presupuestos") });
    }
    for (const m of (records ?? []).slice(0, MAX_PER_GROUP)) {
      out.push({
        id: `r-${m.id}`,
        group: t.bus.registros,
        label: m.nota || t.app.detalle,
        hint: [dayLabel(m.fecha), m.categoria].filter(Boolean).join(" · "),
        amount: <span className={`amt${m.tipo === "ingreso" ? " in" : ""}`}>{money(m.importe, m.divisa, { sign: m.tipo === "ingreso" })}</span>,
        run: () => setDetail(m),
      });
    }
    if (text.length >= 2) {
      out.push({ id: "r-all", group: t.bus.registros, label: t.bus.verTodos(text), icon: Icons.registros, run: () => onRegistros({ texto: text }) });
    }
    return out;
  }, [q, destinos, cuentas, cats, budgets, records, solo, onGo, onRegistros]);

  useEffect(() => setActive(0), [q]);
  useEffect(() => input.current?.focus(), []);
  useEffect(() => {
    document.getElementById(`kopt-${active}`)?.scrollIntoView({ block: "nearest" });
  }, [active]);

  if (detail) return <Detalle m={detail} onClose={onClose} />;

  const onKey = (e: KeyboardEvent) => {
    if (e.key === "Escape") {
      e.preventDefault();
      onClose();
    } else if (e.key === "ArrowDown") {
      e.preventDefault();
      setActive((a) => (items.length ? (a + 1) % items.length : 0));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setActive((a) => (items.length ? (a - 1 + items.length) % items.length : 0));
    } else if (e.key === "Enter") {
      e.preventDefault();
      items[active]?.run();
    }
  };

  let lastGroup = "";
  return (
    <div className="modal kmodal" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="sheet kpal" role="dialog" aria-modal="true" aria-label={t.bus.abrir}>
        <div className="kin">
          {Icons.search}
          <input
            ref={input}
            type="search"
            role="combobox"
            aria-expanded="true"
            aria-controls="klist"
            aria-autocomplete="list"
            aria-activedescendant={items.length ? `kopt-${active}` : undefined}
            aria-label={t.bus.campo}
            placeholder={t.bus.campo}
            value={q}
            maxLength={60}
            onChange={(e) => setQ(e.target.value)}
            onKeyDown={onKey}
          />
          <kbd>Esc</kbd>
        </div>
        <div className="klist" id="klist" role="listbox" aria-label={t.bus.abrir}>
          {items.map((it, i) => {
            const head = it.group !== lastGroup ? it.group : null;
            lastGroup = it.group;
            return (
              <div key={it.id} role="presentation">
                {head ? (
                  <div className="kgrp" role="presentation">
                    {head}
                  </div>
                ) : null}
                <div
                  id={`kopt-${i}`}
                  role="option"
                  aria-selected={i === active}
                  className="kopt"
                  onMouseMove={() => setActive(i)}
                  onClick={() => it.run()}
                >
                  {it.icon ?? <span className="kdot" aria-hidden="true" />}
                  <span className="t">
                    <b>{it.label}</b>
                    {it.hint ? <span>{it.hint}</span> : null}
                  </span>
                  {it.amount ?? null}
                </div>
              </div>
            );
          })}
          {q.trim() && !solo && searching ? <p className="kstate">{t.bus.buscando}</p> : null}
          {q.trim() && !searching && items.length === 0 ? <p className="kstate">{t.bus.sinResultados(q.trim())}</p> : null}
        </div>
        <p className="khelp">{t.bus.ayuda}</p>
      </div>
    </div>
  );
}
