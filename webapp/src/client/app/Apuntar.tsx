/**
 * Apuntar un gasto (o un ingreso) desde la web: va a la Bandeja del iPhone, que lo confirma con un toque. La cuenta y la
 * subcategoría son opcionales: lo que falte se elige en el iPhone. La divisa es la de la cuenta elegida, o la preferida.
 *
 * Con `editar` (lote 3) cambia un borrador que la web dejó y el iPhone aún no recogió: llega con sus datos y guarda en
 * `/api/borradores/editar`. Si el iPhone ya lo recogió, lo dice.
 *
 * Lote 4 de «Yala web como la app»: la hoja «Nuevo registro» de la app, centrada en el monto (decisión D7). Arriba el día
 * en cápsula («Hoy»), Gasto o Ingreso y la descripción; al medio «¿Cuánto gastaste?» y el monto grande; debajo, hasta tres
 * categorías sugeridas (las subcategorías de tus últimos registros) y Cuenta y Categoría en cápsulas. Sin Mi parte,
 * Favorito, Recurrente ni Etiquetas: el borrador de la web no los guarda. El foco abre en el monto e Intro envía.
 */
import { useEffect, useMemo, useRef, useState } from "react";
import { Calendar, ChevronDown, CreditCard, Send, Tag, X } from "lucide-react";
import { texts } from "../i18n";
import { ApiError, postJson, type Categoria, type Cuenta, type Enviado, type Movimiento } from "./api";
import { dayLabel, moneyParts, todayKey } from "./format";
import { COLOR_POR_DEFECTO, colorSeguro, iconoLucide } from "./simbolos";

const t = texts();

export function parseAmount(raw: string): number | null {
  const clean = raw.replace(/\s/g, "").replace(/[^\d.,]/g, "");
  if (!clean) return null;
  // «1.234,50» y «1,234.50»: el último separador es el decimal.
  const lastSep = Math.max(clean.lastIndexOf(","), clean.lastIndexOf("."));
  const normalized = lastSep >= 0 && clean.length - lastSep - 1 <= 2 ? `${clean.slice(0, lastSep).replace(/[.,]/g, "")}.${clean.slice(lastSep + 1)}` : clean.replace(/[.,]/g, "");
  const n = Number(normalized);
  return Number.isFinite(n) ? n : null;
}

export function Apuntar({
  cuentas,
  divisaPreferida,
  categorias,
  onClose,
  onSent,
  editar,
  recientes,
}: {
  cuentas: Cuenta[];
  divisaPreferida: string;
  categorias: Categoria[] | null;
  onClose: () => void;
  onSent: () => void;
  editar?: Enviado;
  /** Los últimos registros (los del Panel): de ellos salen las categorías sugeridas. */
  recientes?: Movimiento[];
}) {
  const visibles = cuentas.filter((c) => !c.archivada);
  const [tipo, setTipo] = useState<"gasto" | "ingreso">(editar?.tipo ?? "gasto");
  const [importe, setImporte] = useState(editar ? editar.importe.toFixed(2) : "");
  const [descripcion, setDescripcion] = useState(editar?.descripcion ?? "");
  const [subcategoria, setSubcategoria] = useState(editar?.subcategoria ?? "");
  const [cuenta, setCuenta] = useState(editar ? (editar.cuenta ?? "") : (visibles[0]?.id ?? ""));
  const [fecha, setFecha] = useState(editar?.fecha ?? todayKey());
  const [error, setError] = useState<string | null>(null);
  const [sending, setSending] = useState(false);
  const amountRef = useRef<HTMLInputElement>(null);
  const dateRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    amountRef.current?.focus();
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  const divisa = visibles.find((c) => c.id === cuenta)?.divisa ?? (editar?.divisa || divisaPreferida);
  const titulo = editar ? t.app.editarTitulo : t.app.nuevoRegistro;
  // El símbolo de la divisa, como lo escribe la app junto al monto («S/», «$», «€»); sin símbolo conocido, el código.
  const simbolo = useMemo(() => {
    const p = moneyParts(1, divisa);
    return (p?.antes || p?.despues || divisa).trim();
  }, [divisa]);
  const grupos = useMemo(
    () => (categorias ?? []).filter((c) => !c.oculta && c.es_ingreso === (tipo === "ingreso") && c.subcategorias.some((s) => !s.oculta)),
    [categorias, tipo],
  );

  // Hasta tres subcategorías sugeridas: las de tus últimos registros del mismo tipo, sin repetir y que sigan visibles.
  const sugeridas = useMemo(() => {
    const visibles = new Map<string, { id: string; nombre: string; icono: string | null; color: string | null }>();
    for (const c of grupos) for (const sc of c.subcategorias) if (!sc.oculta) visibles.set(sc.id, { id: sc.id, nombre: sc.nombre, icono: sc.icono ?? c.icono, color: c.color });
    const out: { id: string; nombre: string; icono: string | null; color: string | null }[] = [];
    for (const m of recientes ?? []) {
      const sc = m.subcategoria_id ? visibles.get(m.subcategoria_id) : undefined;
      if (sc && m.tipo === tipo && !out.some((o) => o.id === sc.id)) out.push(sc);
      if (out.length === 3) break;
    }
    return out;
  }, [grupos, recientes, tipo]);

  const abrirCalendario = () => {
    const el = dateRef.current;
    if (!el) return;
    try {
      el.showPicker();
    } catch {
      el.focus();
    }
  };

  const send = async () => {
    const n = parseAmount(importe);
    if (n === null || n <= 0) {
      setError(t.app.errores.importe!);
      amountRef.current?.focus();
      return;
    }
    setSending(true);
    setError(null);
    try {
      const datos = { tipo, importe: n, divisa, descripcion: descripcion.trim(), fecha, cuenta: cuenta || null, subcategoria: subcategoria || null };
      await postJson(editar ? "/api/borradores/editar" : "/api/borradores", editar ? { id: editar.id, ...datos } : datos);
      onSent();
    } catch (err) {
      const body = err instanceof ApiError ? err.body : {};
      const key =
        body.error === "tope_diario" || body.error === "recogido" ? String(body.error) : typeof body.campo === "string" ? body.campo : "otro";
      setError(t.app.errores[key] ?? t.app.errores.otro!);
    } finally {
      setSending(false);
    }
  };

  const nombreCuenta = visibles.find((c) => c.id === cuenta)?.nombre;
  const nombreSub = grupos.flatMap((c) => c.subcategorias).find((x) => x.id === subcategoria)?.nombre;

  return (
    <div className="modal" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <form
        className="sheet nr"
        role="dialog"
        aria-modal="true"
        aria-label={titulo}
        onSubmit={(e) => {
          e.preventDefault();
          void send();
        }}
      >
        <div className="nr-h">
          <button className="ib" type="button" onClick={onClose} aria-label={t.app.cancelar}>
            <X aria-hidden={true} focusable={false} />
          </button>
          <h2>{titulo}</h2>
          <span aria-hidden="true" />
        </div>

        <label className="nr-dia">
          <Calendar aria-hidden={true} focusable={false} />
          <span aria-hidden="true">{dayLabel(fecha)}</span>
          <input
            ref={dateRef}
            type="date"
            aria-label={t.app.fecha}
            value={fecha}
            max={todayKey()}
            onChange={(e) => setFecha(e.target.value || todayKey())}
            onClick={abrirCalendario}
            required
          />
        </label>

        <div className="nr-tipo" role="group" aria-label={t.app.tipo}>
          {(["gasto", "ingreso"] as const).map((x) => (
            <button
              key={x}
              type="button"
              aria-pressed={tipo === x}
              onClick={() => {
                setTipo(x);
                setSubcategoria("");
              }}
            >
              {x === "gasto" ? t.app.gasto : t.app.ingreso}
            </button>
          ))}
        </div>

        <input
          className="nr-desc"
          aria-label={t.app.descripcion}
          value={descripcion}
          onChange={(e) => setDescripcion(e.target.value)}
          placeholder={t.app.descripcionEj}
          maxLength={120}
        />

        <label className={`nr-amt${tipo === "ingreso" ? " in" : ""}`}>
          <span className="nr-q">{tipo === "ingreso" ? t.app.cuantoRecibiste : t.app.cuantoGastaste}</span>
          <span className="nr-cifra">
            <span className="nr-cur" aria-hidden="true">
              {simbolo}
            </span>
            <input
              ref={amountRef}
              inputMode="decimal"
              autoComplete="off"
              aria-label={t.app.importe}
              placeholder="0.00"
              value={importe}
              onChange={(e) => setImporte(e.target.value)}
              maxLength={16}
              // El ancho sigue a lo escrito, para que la cifra quede centrada con su divisa (como en la app).
              style={{ width: `${Math.max(4, importe.length) + 0.4}ch` }}
            />
          </span>
        </label>

        {sugeridas.length > 0 ? (
          <div className="nr-sug" role="group" aria-label={t.app.categoria}>
            {sugeridas.map((sc) => {
              const Icono = iconoLucide(sc.icono);
              return (
                <button key={sc.id} type="button" className="nr-chip" aria-pressed={subcategoria === sc.id} onClick={() => setSubcategoria(subcategoria === sc.id ? "" : sc.id)}>
                  <span className="nr-chip-ic" style={{ background: colorSeguro(sc.color, COLOR_POR_DEFECTO) }} aria-hidden="true">
                    <Icono size={13} strokeWidth={2.4} aria-hidden={true} focusable={false} />
                  </span>
                  {sc.nombre}
                </button>
              );
            })}
          </div>
        ) : null}

        <div className="nr-sel">
          <label className={`cap-sel${cuenta ? " on" : ""}`}>
            <CreditCard aria-hidden={true} focusable={false} />
            <select aria-label={t.app.cuenta} value={cuenta} onChange={(e) => setCuenta(e.target.value)} title={nombreCuenta}>
              <option value="">{t.app.cuenta}</option>
              {visibles.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.nombre} · {c.divisa}
                </option>
              ))}
            </select>
            <ChevronDown aria-hidden={true} focusable={false} />
          </label>
          <label className={`cap-sel${subcategoria ? " on" : ""}`}>
            <Tag aria-hidden={true} focusable={false} />
            <select aria-label={t.app.categoria} value={subcategoria} onChange={(e) => setSubcategoria(e.target.value)} disabled={categorias === null} title={nombreSub}>
              <option value="">{t.app.categoria}</option>
              {grupos.map((c) => (
                <optgroup key={c.id} label={c.nombre}>
                  {c.subcategorias
                    .filter((x) => !x.oculta)
                    .map((x) => (
                      <option key={x.id} value={x.id}>
                        {x.nombre}
                      </option>
                    ))}
                </optgroup>
              ))}
            </select>
            <ChevronDown aria-hidden={true} focusable={false} />
          </label>
        </div>

        <p className="nr-nota">{t.app.apuntarNota}</p>
        {error ? (
          <p className="err" role="alert">
            {error}
          </p>
        ) : null}
        <button className="btn-p nr-enviar" type="submit" disabled={sending}>
          <Send aria-hidden={true} focusable={false} />
          {sending ? t.app.enviando : editar ? t.app.guardar : t.app.enviar}
        </button>
      </form>
    </div>
  );
}
