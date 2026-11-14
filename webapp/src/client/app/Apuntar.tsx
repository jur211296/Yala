/**
 * Apuntar un gasto (o un ingreso) desde la web: va a la Bandeja del iPhone, que lo confirma con un toque. La cuenta y la
 * subcategoría son opcionales: lo que falte se elige en el iPhone. La divisa es la de la cuenta elegida, o la preferida.
 */
import { useEffect, useMemo, useRef, useState } from "react";
import { texts } from "../i18n";
import { ApiError, postJson, type Categoria, type Cuenta } from "./api";
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
}: {
  cuentas: Cuenta[];
  divisaPreferida: string;
  categorias: Categoria[] | null;
  onClose: () => void;
  onSent: () => void;
}) {
  const visibles = cuentas.filter((c) => !c.archivada);
  const [tipo, setTipo] = useState<"gasto" | "ingreso">("gasto");
  const [importe, setImporte] = useState("");
  const [descripcion, setDescripcion] = useState("");
  const [subcategoria, setSubcategoria] = useState("");
  const [cuenta, setCuenta] = useState(visibles[0]?.id ?? "");
  const [fecha, setFecha] = useState(todayKey());
  const [error, setError] = useState<string | null>(null);
  const [sending, setSending] = useState(false);
  const amountRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    amountRef.current?.focus();
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  const divisa = visibles.find((c) => c.id === cuenta)?.divisa ?? divisaPreferida;
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
      await postJson("/api/borradores", { tipo, importe: n, divisa, descripcion: descripcion.trim(), fecha, cuenta: cuenta || null, subcategoria: subcategoria || null });
      onSent();
    } catch (err) {
      const body = err instanceof ApiError ? err.body : {};
      const key = typeof body.error === "string" && body.error === "tope_diario" ? "tope_diario" : typeof body.campo === "string" ? body.campo : "otro";
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
        aria-label={t.app.apuntarTitulo}
        onSubmit={(e) => {
          e.preventDefault();
          void send();
        }}
      >
        <h2>
          {t.app.apuntarTitulo}
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
          {sending ? t.app.enviando : t.app.enviar}
        </button>
      </form>
    </div>
  );
}
