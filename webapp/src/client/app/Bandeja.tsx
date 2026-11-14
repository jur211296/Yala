/**
 * La Bandeja en la beta: se ve aquí y se aprueba en el iPhone. Arriba, lo apuntado en la web que el iPhone aún no
 * recogió; debajo, lo que espera en la Bandeja del iPhone (de cualquier origen).
 */
import { useEffect } from "react";
import { texts } from "../i18n";
import type { Bandeja as BandejaData, Pendiente } from "./api";
import { ago, badge, money, shortDate } from "./format";

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

export function Bandeja({ data, reload }: { data: BandejaData | null; reload: () => void }) {
  useEffect(() => {
    reload();
  }, [reload]);

  if (!data) {
    return (
      <div className="cd" aria-busy="true">
        <div className="skel" style={{ width: "40%" }} />
        <div className="skel" />
      </div>
    );
  }
  const { pendientes, enviados } = data;
  return (
    <>
      <p className="note-y">{t.app.bandejaNota}</p>

      {enviados.length > 0 ? (
        <section className="cd">
          <h2>
            {t.app.esperando}
            <small>{enviados.length}</small>
          </h2>
          {enviados.map((d) => {
            const b = badge(d.descripcion);
            return (
              <div className="row" key={d.id}>
                <span className="ic" style={{ background: b.color }} aria-hidden="true">
                  {b.letter}
                </span>
                <span className="t">
                  <b>{d.descripcion || (d.tipo === "ingreso" ? t.app.ingreso : t.app.gasto)}</b>
                  <span>{t.app.enviado(ago(d.enviado / 1000))}</span>
                </span>
                <span className="src">{t.app.origen.web}</span>
                <span className={`amt${d.tipo === "ingreso" ? " in" : ""}`}>{money(d.tipo === "ingreso" ? d.importe : -d.importe, d.divisa, { sign: d.tipo === "ingreso" })}</span>
              </div>
            );
          })}
          <p className="empty">{t.app.esperandoNota}</p>
        </section>
      ) : null}

      <section className="cd">
        <h2>{pendientes.length > 0 ? t.app.porRevisar(pendientes.length) : t.app.todoRevisado}</h2>
        {pendientes.length === 0 ? <p className="empty">{t.app.nadaPendiente}</p> : null}
        {pendientes.map((p) => {
          const n = amount(p.amount);
          const b = badge(p.cached_subcategory_name ?? p.note);
          const falta = (p.needs_user_input ?? []).length > 0;
          return (
            <div className="row" key={p.sync_id}>
              <span className="ic" style={{ background: b.color }} aria-hidden="true">
                {b.letter}
              </span>
              <span className="t">
                <b>{p.note || p.cached_subcategory_name || t.app.gasto}</b>
                <span>{[p.cached_subcategory_name, p.cached_account_name, shortDate(p.date), falta ? t.app.falta : null].filter(Boolean).join(" · ")}</span>
              </span>
              <span className="src">{sourceLabel(p)}</span>
              <span className={`amt${n !== null && n > 0 ? " in" : ""}`}>{money(n, p.cached_currency_code, { sign: true })}</span>
            </div>
          );
        })}
      </section>
    </>
  );
}
