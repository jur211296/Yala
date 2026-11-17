/**
 * La Bandeja en la beta: se ve aquí y se aprueba en el iPhone. Arriba, lo apuntado en la web que el iPhone aún no
 * recogió; debajo, lo que espera en la Bandeja del iPhone (de cualquier origen).
 *
 * Lote 3: lo apuntado en la web que el iPhone aún no recogió se puede editar o descartar. Descartar pide un segundo toque
 * en la misma fila (sin diálogos del navegador). Si el iPhone ya lo recogió, se dice y la lista se recarga.
 *
 * Lote 5 de «Yala web como la app» (decisión D7): la Bandeja de Entrada se abre ENCIMA de la pantalla en la que estás,
 * como la hoja de la app: panel lateral de cristal en escritorio y hoja que sube desde abajo en el celular. Cada fila es
 * la de Registros, con el ícono de su subcategoría y la píldora del origen. Se cierra con la ✕, con Esc o tocando fuera.
 * Sin segmento «Archivados»: la web no los lee.
 */
import { useEffect, useRef, useState } from "react";
import { X } from "lucide-react";
import { texts } from "../i18n";
import { ApiError, postJson, type Bandeja as BandejaData, type Categoria, type Enviado, type Pendiente } from "./api";
import { ago, shortDate } from "./format";
import { Monto } from "./Monto";
import { Pildora } from "./FilaRegistro";
import { simboloPorNombre, useCategorias, type Simbolo } from "./categorias";
import { COLOR_POR_DEFECTO, colorSeguro, iconoLucide, SIMBOLO_POR_DEFECTO } from "./simbolos";

const t = texts();

function sourceLabel(p: Pendiente): string {
  // Lo de la web entra en el iPhone como «automatización» con la evidencia «Yala web» (lote 1, decisión P4).
  if (p.evidence === "Yala web") return t.app.origen.web!;
  return (p.source_type_raw && t.app.origen[p.source_type_raw]) || t.app.origen.manual!;
}

function amount(raw: number | string | null): number | null {
  const n = typeof raw === "string" ? Number(raw) : raw;
  return n == null || !Number.isFinite(n) ? null : n;
}

/** El ícono de un borrador de la web: guarda el id de la subcategoría, no su nombre. */
function simboloDeSubcategoria(cats: readonly Categoria[] | null, id: string | null): Simbolo {
  for (const c of cats ?? []) {
    const s = c.subcategorias.find((x) => x.id === id);
    if (s) {
      const sf = s.icono ?? c.icono ?? SIMBOLO_POR_DEFECTO;
      return { sf, Icono: iconoLucide(sf), color: colorSeguro(s.color ?? c.color, COLOR_POR_DEFECTO) };
    }
  }
  return simboloPorNombre(null, null);
}

function Circulo({ sim }: { sim: Simbolo }) {
  return (
    <span className="circ" style={{ background: sim.color }} aria-hidden="true">
      <sim.Icono size={20} strokeWidth={2.2} aria-hidden={true} focusable={false} />
    </span>
  );
}

export function Bandeja({
  data,
  reload,
  onEdit,
  onToast,
  onClose,
  tapada,
}: {
  data: BandejaData | null;
  reload: () => void;
  onEdit: (d: Enviado) => void;
  onToast: (msg: string) => void;
  onClose: () => void;
  /** Hay otra hoja encima (editar un borrador): Esc es de esa hoja, no de la Bandeja. */
  tapada?: boolean;
}) {
  const [confirming, setConfirming] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const cats = useCategorias();
  const cerrar = useRef<HTMLButtonElement>(null);
  useEffect(() => {
    reload();
  }, [reload]);
  useEffect(() => {
    cerrar.current?.focus();
  }, []);
  useEffect(() => {
    if (tapada) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose, tapada]);

  const discard = async (id: string) => {
    setBusy(id);
    try {
      await postJson("/api/borradores/descartar", { id });
      onToast(t.app.descartadoToast);
    } catch (err) {
      onToast(err instanceof ApiError && err.status === 409 ? t.app.recogidoToast : t.app.noCargo);
    } finally {
      setBusy(null);
      setConfirming(null);
      reload();
    }
  };

  const total = data ? data.pendientes.length + data.enviados.length : 0;

  return (
    <div className="modal band-m" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <section className="sheet band" role="dialog" aria-modal="true" aria-labelledby="band-titulo">
        <div className="band-h">
          <h2 id="band-titulo">
            {t.app.bandejaTitulo}
            {total > 0 ? <span className="badge">{total}</span> : null}
          </h2>
          <button ref={cerrar} className="ib cerrar" type="button" aria-label={t.app.cerrar} title={t.app.cerrar} onClick={onClose}>
            <X aria-hidden={true} focusable={false} />
          </button>
        </div>
        <p className="band-nota">{t.app.bandejaNota}</p>

        {!data ? (
          <div aria-busy="true">
            <div className="skel" style={{ width: "40%" }} />
            <div className="skel" />
          </div>
        ) : (
          <>
            {data.enviados.length > 0 ? (
              <section aria-label={t.app.esperando}>
                <div className="dia">
                  <span>{t.app.esperando}</span>
                  <span>{data.enviados.length}</span>
                </div>
                <div className="filas">
                  {data.enviados.map((d) => {
                    const ingreso = d.tipo === "ingreso";
                    return (
                      <div className="fila band-f" key={d.id}>
                        <div className="band-fila">
                          <Circulo sim={simboloDeSubcategoria(cats, d.subcategoria)} />
                          <span className="fila-t">
                            <b>{d.descripcion || (ingreso ? t.app.ingreso : t.app.gasto)}</b>
                            <span>{t.app.enviado(ago(d.enviado / 1000))}</span>
                          </span>
                          <span className="fila-a">
                            <Monto importe={ingreso ? d.importe : -d.importe} divisa={d.divisa} signo={ingreso} className={`amt${ingreso ? " in" : ""}`} />
                            <Pildora color="var(--acc)">{t.app.origen.web}</Pildora>
                          </span>
                        </div>
                        <span className="row-acts">
                          {confirming === d.id ? (
                            <>
                              <span className="confirm-q">{t.app.descartarPregunta}</span>
                              <button className="btn-s" type="button" onClick={() => setConfirming(null)}>
                                {t.app.cancelar}
                              </button>
                              <button className="btn-s danger" type="button" disabled={busy === d.id} onClick={() => void discard(d.id)}>
                                {t.app.descartarSeguro}
                              </button>
                            </>
                          ) : (
                            <>
                              <button className="btn-s" type="button" onClick={() => onEdit(d)}>
                                {t.app.editar}
                              </button>
                              <button className="btn-s" type="button" onClick={() => setConfirming(d.id)}>
                                {t.app.descartar}
                              </button>
                            </>
                          )}
                        </span>
                      </div>
                    );
                  })}
                </div>
                <p className="empty">{t.app.esperandoNota}</p>
              </section>
            ) : null}

            <section aria-label={data.pendientes.length > 0 ? t.app.porRevisar(data.pendientes.length) : t.app.todoRevisado}>
              <div className="dia">
                <span>{data.pendientes.length > 0 ? t.app.porRevisar(data.pendientes.length) : t.app.todoRevisado}</span>
              </div>
              {data.pendientes.length === 0 ? <p className="empty">{t.app.nadaPendiente}</p> : null}
              <div className="filas">
                {data.pendientes.map((p) => {
                  const n = amount(p.amount);
                  const falta = (p.needs_user_input ?? []).length > 0;
                  return (
                    <div className="fila" key={p.sync_id}>
                      <Circulo sim={simboloPorNombre(cats, p.cached_subcategory_name, { primero: "subcategoria" })} />
                      <span className="fila-t">
                        <b>{p.note || p.cached_subcategory_name || t.app.gasto}</b>
                        <span>{[p.cached_subcategory_name, p.cached_account_name, shortDate(p.date)].filter(Boolean).join(" · ")}</span>
                        {falta ? <span className="band-falta">{t.app.falta}</span> : null}
                      </span>
                      <span className="fila-a">
                        <Monto importe={n} divisa={p.cached_currency_code} signo className={`amt${n !== null && n > 0 ? " in" : ""}`} />
                        <Pildora color="var(--acc)">{sourceLabel(p)}</Pildora>
                      </span>
                    </div>
                  );
                })}
              </div>
            </section>
          </>
        )}
      </section>
    </div>
  );
}
