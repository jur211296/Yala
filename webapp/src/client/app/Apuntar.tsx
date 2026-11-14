/**
 * Apuntar un gasto (o un ingreso) desde la web: va a la Bandeja del iPhone, que lo confirma con un toque. La cuenta y la
 * subcategoría son opcionales: lo que falte se elige en el iPhone. La divisa es la de la cuenta elegida, o la preferida.
 *
 * Con `editar` (lote 3) cambia un borrador que la web dejó y el iPhone aún no recogió: llega con sus datos y guarda en
 * `/api/borradores/editar`. Si el iPhone ya lo recogió, lo dice.
 */
import { useEffect, useMemo, useRef, useState } from "react";
import { texts } from "../i18n";
import { ApiError, postJson, type Categoria, type Cuenta, type Enviado } from "./api";
import { todayKey } from "./format";

const t = texts();

function parseAmount(raw: string): number | null {
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
}: {
  cuentas: Cuenta[];
  divisaPreferida: string;
  categorias: Categoria[] | null;
  onClose: () => void;
  onSent: () => void;
  editar?: Enviado;
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

  useEffect(() => {
    amountRef.current?.focus();
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  const divisa = visibles.find((c) => c.id === cuenta)?.divisa ?? (editar?.divisa || divisaPreferida);
  const titulo = editar ? t.app.editarTitulo : t.app.apuntarTitulo;
  const grupos = useMemo(
    () => (categorias ?? []).filter((c) => !c.oculta && c.es_ingreso === (tipo === "ingreso") && c.subcategorias.some((s) => !s.oculta)),
    [categorias, tipo],
  );

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

  return (
    <div className="modal" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <form
        className="sheet"
        role="dialog"
        aria-modal="true"
        aria-label={titulo}
        onSubmit={(e) => {
          e.preventDefault();
          void send();
        }}
      >
        <h2>
          {titulo}
          <button className="btn-s" type="button" onClick={onClose}>
            {t.app.cancelar}
          </button>
        </h2>
        <div className="seg" role="group" aria-label={t.app.tipo}>
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
        <label className="amt-in">
          <span>{divisa}</span>
          <input
            ref={amountRef}
            inputMode="decimal"
            autoComplete="off"
            aria-label={t.app.importe}
            placeholder="0.00"
            value={importe}
            onChange={(e) => setImporte(e.target.value)}
            maxLength={16}
          />
        </label>
        <label className="fld">
          <span>{t.app.descripcion}</span>
          <input value={descripcion} onChange={(e) => setDescripcion(e.target.value)} placeholder={t.app.descripcionPh} maxLength={120} />
        </label>
        <label className="fld">
          <span>{t.app.categoria}</span>
          <select value={subcategoria} onChange={(e) => setSubcategoria(e.target.value)} disabled={categorias === null}>
            <option value="">{t.app.eligeCategoria}</option>
            {grupos.map((c) => (
              <optgroup key={c.id} label={c.nombre}>
                {c.subcategorias
                  .filter((s) => !s.oculta)
                  .map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.nombre}
                    </option>
                  ))}
              </optgroup>
            ))}
          </select>
        </label>
        <label className="fld">
          <span>{t.app.cuenta}</span>
          <select value={cuenta} onChange={(e) => setCuenta(e.target.value)}>
            <option value="">{t.app.eligeCuenta}</option>
            {visibles.map((c) => (
              <option key={c.id} value={c.id}>
                {c.nombre} · {c.divisa}
              </option>
            ))}
          </select>
        </label>
        <label className="fld">
          <span>{t.app.fecha}</span>
          <input type="date" value={fecha} max={todayKey()} onChange={(e) => setFecha(e.target.value)} required />
        </label>
        <p className="note-y">{t.app.apuntarNota}</p>
        {error ? (
          <p className="err" role="alert">
            {error}
          </p>
        ) : null}
        <button className="btn-p" type="submit" disabled={sending}>
          {sending ? t.app.enviando : editar ? t.app.guardar : t.app.enviar}
        </button>
      </form>
    </div>
  );
}
