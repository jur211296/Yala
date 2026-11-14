/**
 * Pagos planificados (lote 2): los próximos cobros de 30 días con el calendario del iPhone y las suscripciones activas.
 * Las fechas y los totales los calcula el núcleo compartido (`shared-core/src/logic/schedule.ts`). En lectura: crear,
 * editar o marcar como pagado sigue en el iPhone.
 */
import { useCallback, useEffect, useState } from "react";
import { texts } from "../i18n";
import { getJson, type Cobro, type Pagos as Data, type Suscripcion } from "./api";
import { badge, money, shortDate } from "./format";

const t = texts();

function when(days: number): string {
  if (days <= 0) return t.pag.hoy;
  if (days === 1) return t.pag.manana;
  return t.pag.enDias(days);
}

function freq(f: string, every: number): string {
  if (every > 1 && t.pag.unidades[f]) return t.pag.cada(every, t.pag.unidades[f]!);
  return t.pag.frecuencia[f] ?? f;
}

function dayIso(day: string): string {
  return `${day}T12:00:00`;
}

function CobroRow({ c }: { c: Cobro }) {
  const b = badge(c.nombre);
  const income = c.movimiento === "ingreso";
  return (
    <div className="row">
      <span className="ic" style={{ background: b.color }} aria-hidden="true">
        {b.letter}
      </span>
      <span className="t">
        <b>{c.nombre}</b>
        <span>{[freq(c.frecuencia, c.cada), c.categoria, income ? t.pag.ingreso : null].filter(Boolean).join(" · ")}</span>
      </span>
      <span className={`amt${income ? " in" : ""}`}>{money(c.importe, c.divisa, { sign: income })}</span>
    </div>
  );
}

function SubRow({ s, divisa }: { s: Suscripcion; divisa: string }) {
  const b = badge(s.nombre);
  return (
    <div className="row">
      <span className="ic" style={{ background: b.color }} aria-hidden="true">
        {b.letter}
      </span>
      <span className="t">
        <b>{s.nombre}</b>
        <span>
          {[freq(s.frecuencia, s.cada), s.proximo_cobro ? t.pag.proximo(shortDate(dayIso(s.proximo_cobro))) : null].filter(Boolean).join(" · ")}
        </span>
      </span>
      <span className="amt">
        {money(s.importe, s.divisa)}
        {s.divisa !== divisa && s.equivalente_mensual_en_divisa_preferida !== null ? <small className="sub"> ≈ {money(s.equivalente_mensual_en_divisa_preferida, divisa)}</small> : null}
      </span>
    </div>
  );
}

export function Pagos() {
  const [data, setData] = useState<Data | null>(null);
  const [error, setError] = useState(false);

  const load = useCallback(() => {
    setError(false);
    getJson<Data>("/api/pagos").then(setData, () => setError(true));
  }, []);
  useEffect(load, [load]);

  if (error) {
    return (
      <div className="cd">
        <p className="empty">{t.app.noCargo}</p>
        <button className="btn-s" type="button" onClick={load}>
          {t.app.reintentar}
        </button>
      </div>
    );
  }
  if (!data) {
    return (
      <div className="cd" aria-busy="true">
        <div className="skel" style={{ width: "30%" }} />
        <div className="skel" style={{ width: "55%", height: 30 }} />
      </div>
    );
  }

  // Agrupados por día, como la lista del iPhone.
  const groups: { day: string; en: number; items: Cobro[] }[] = [];
  for (const c of data.proximos) {
    const last = groups[groups.length - 1];
    if (last && last.day === c.dia) last.items.push(c);
    else groups.push({ day: c.dia, en: c.en_dias, items: [c] });
  }

  return (
    <>
      <section className="cd hero" aria-label={t.pag.porPagar}>
        <span className="cap">{t.pag.porPagar}</span>
        <span className="big">
          {data.aproximado ? "≈ " : ""}
          {money(data.total_gastos, data.divisa)}
        </span>
      </section>
      <div className="grid2">
        <section className="cd">
          <h2>{t.pag.proximos}</h2>
          {groups.length === 0 ? <p className="empty">{t.pag.sinProximos}</p> : null}
          {groups.map((g) => (
            <div key={g.day}>
              <div className="day">
                {when(g.en)} · {shortDate(dayIso(g.day))}
              </div>
              {g.items.map((c) => (
                <CobroRow key={`${c.id}-${c.dia}`} c={c} />
              ))}
            </div>
          ))}
        </section>
        <section className="cd">
          <h2>
            {t.pag.suscripciones}
            {data.suscripciones.length > 0 ? <small>{t.pag.alMes(money(data.suscripciones_mensual, data.divisa))}</small> : null}
          </h2>
          {data.suscripciones.length === 0 ? <p className="empty">{t.pag.sinSuscripciones}</p> : null}
          {data.suscripciones.map((s) => (
            <SubRow key={s.id} s={s} divisa={data.divisa} />
          ))}
        </section>
      </div>
      {data.aproximado ? <p className="note-y">{t.pag.aproximado}</p> : null}
      <p className="fade small">{t.pag.nota}</p>
    </>
  );
}
