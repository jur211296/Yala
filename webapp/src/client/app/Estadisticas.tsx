/**
 * Estadísticas (lote 2): Resumen, Distribución y Tendencias, con las cifras que calcula el núcleo compartido con las
 * reglas del iPhone (`shared-core/src/logic/stats.ts`, paridad en `mcp/test/golden.test.ts`). Aquí solo se pintan.
 */
import { useCallback, useEffect, useState } from "react";
import { locale, texts } from "../i18n";
import { getJson, type Estadisticas as Data, type PeriodoEst, type Trozo } from "./api";
import { badge, dayLabel, money } from "./format";

const t = texts();
const PERIODS: PeriodoEst[] = ["mes_actual", "mes_pasado", "anio_actual"];
type Tab = "resumen" | "distribucion" | "tendencias";
const TABS: Tab[] = ["resumen", "distribucion", "tendencias"];

function pct(v: number): string {
  return `${new Intl.NumberFormat(locale(), { maximumFractionDigits: 1 }).format(v)} %`;
}

function Variation({ value, worseUp }: { value: number | null; worseUp?: boolean }) {
  if (value === null) return null;
  const up = value > 0;
  const tone = value === 0 ? "" : up === !!worseUp ? " bad" : " good";
  return (
    <span className={`var${tone}`}>
      {value > 0 ? "▲" : value < 0 ? "▼" : "="} {pct(Math.abs(value))}
    </span>
  );
}

function Skeleton() {
  return (
    <div className="cd" aria-busy="true">
      <div className="skel" style={{ width: "30%" }} />
      <div className="skel" style={{ width: "55%", height: 30 }} />
      <div className="skel" style={{ width: "70%" }} />
    </div>
  );
}

function sliceName(s: Trozo): string {
  return s.categoria ?? t.app.sinCategoria;
}

function Slices({ list, divisa }: { list: Trozo[]; divisa: string }) {
  const max = Math.max(1, ...list.map((x) => x.importe));
  return (
    <>
      {list.map((c) => {
        const b = badge(c.categoria);
        return (
          <div className="slice" key={c.id ?? "sin"}>
            <span className="ic" style={{ background: b.color }} aria-hidden="true">
              {b.letter}
            </span>
            <div className="t">
              <div className="slice-h">
                <b>{sliceName(c)}</b>
                <span className="amt">{money(c.importe, divisa)}</span>
              </div>
              <div className="bar" aria-hidden="true">
                <i style={{ width: `${Math.max(2, (c.importe / max) * 100)}%`, background: b.color }} />
              </div>
              <span className="sub">
                {pct(c.porcentaje)} · {t.est.movimientos(c.movimientos)}
              </span>
            </div>
          </div>
        );
      })}
    </>
  );
}

function Resumen({ d, periodo }: { d: Data; periodo: PeriodoEst }) {
  const r = d.resumen;
  const contra = t.est.contra[periodo];
  return (
    <>
      <section className="cd hero" aria-label={t.est.neto}>
        <span className="cap">{t.est.neto}</span>
        <span className="big">
          {r.aproximado.neto ? "≈ " : ""}
          {money(r.neto, r.divisa, { sign: true })}
        </span>
        <div className="inout">
          <span>
            {t.est.entradas} <b className="amt in">{money(r.ingresos, r.divisa)}</b> <Variation value={r.variacion.ingresos} />
          </span>
          <span>
            {t.est.salidas} <b>{money(r.gastos, r.divisa)}</b> <Variation value={r.variacion.gastos} worseUp />
          </span>
        </div>
        <p className="fade small">{r.variacion.ingresos === null && r.variacion.gastos === null ? t.est.sinVariacion : contra}</p>
      </section>
      <div className="grid2">
        <section className="cd">
          <h2>{t.est.gastoMedio}</h2>
          <p className="kpi">
            {money(r.gasto_medio_diario, r.divisa)} <Variation value={r.variacion.gasto_medio_diario} worseUp />
          </p>
          <p className="fade small">{t.est.dias(r.dias)}</p>
        </section>
        <section className="cd">
          <h2>{t.est.gastoMasAlto}</h2>
          {r.gasto_mas_alto ? (
            <>
              <p className="kpi">{money(r.gasto_mas_alto.importe, r.divisa)}</p>
              <p className="fade small">
                {[r.gasto_mas_alto.nota ?? r.gasto_mas_alto.categoria ?? t.app.sinCategoria, dayLabel(r.gasto_mas_alto.dia)].join(" · ")}
              </p>
            </>
          ) : (
            <p className="empty">{t.est.sinGastosPeriodo}</p>
          )}
        </section>
      </div>
      <section className="cd">
        <h2>{t.est.topCategorias}</h2>
        {r.top_categorias.length === 0 ? <p className="empty">{t.est.sinGastosPeriodo}</p> : <Slices list={r.top_categorias} divisa={r.divisa} />}
      </section>
      {r.sin_categoria > 0 ? <p className="note-y">{t.est.sinCategoriaAviso(r.sin_categoria)}</p> : null}
    </>
  );
}

function Donut({ list }: { list: Trozo[] }) {
  let acc = 0;
  const stops = list.map((c) => {
    const from = acc;
    acc += c.porcentaje;
    return `${badge(c.categoria).color} ${from}% ${Math.min(100, acc)}%`;
  });
  const bg = stops.length ? `conic-gradient(${stops.join(", ")})` : "color-mix(in srgb, var(--ink2) 18%, transparent)";
  return <div className="donut" style={{ background: bg }} aria-hidden="true" />;
}

function Distribucion({ d, periodo }: { d: Data; periodo: PeriodoEst }) {
  const dist = d.distribucion;
  return (
    <>
      <section className="cd hero">
        <span className="cap">{t.est.gastadoEn[periodo]}</span>
        <span className="big">{money(dist.total, dist.divisa)}</span>
        <p className="fade small">{t.est.nCategorias(dist.categorias.length)}</p>
      </section>
      <section className="cd">
        <h2>{t.est.porCategoria}</h2>
        {dist.categorias.length === 0 ? (
          <p className="empty">{t.est.sinGastosPeriodo}</p>
        ) : (
          <div className="dist">
            <Donut list={dist.categorias} />
            <div className="dist-list">
              <Slices list={dist.categorias} divisa={dist.divisa} />
            </div>
          </div>
        )}
      </section>
    </>
  );
}

function monthName(ym: string): string {
  const [y, m] = ym.split("-").map(Number);
  return new Intl.DateTimeFormat(locale(), { month: "short" }).format(new Date(y!, (m ?? 1) - 1, 1)).replace(".", "");
}

function Tendencias({ d }: { d: Data }) {
  const months = d.tendencias;
  const divisa = d.resumen.divisa;
  const max = Math.max(1, ...months.flatMap((m) => [Math.abs(m.ingresos), Math.abs(m.gastos)]));
  return (
    <>
      <section className="cd">
        <h2>{t.est.ultimosSeisMeses}</h2>
        <div className="trend" role="img" aria-label={t.est.ultimosSeisMeses}>
          {months.map((m) => (
            <div className="tcol" key={m.mes}>
              <div className="tbars">
                <i className="in" style={{ height: `${Math.max(1, (Math.max(0, m.ingresos) / max) * 100)}%` }} />
                <i className="out" style={{ height: `${Math.max(1, (Math.max(0, m.gastos) / max) * 100)}%` }} />
              </div>
              <span>{monthName(m.mes)}</span>
            </div>
          ))}
        </div>
        <div className="legend">
          <span>
            <i className="in" /> {t.est.entradas}
          </span>
          <span>
            <i className="out" /> {t.est.salidas}
          </span>
        </div>
      </section>
      <section className="cd">
        {[...months].reverse().map((m, i) => (
          <div className="row" key={m.mes}>
            <div className="t">
              <b>
                {new Intl.DateTimeFormat(locale(), { month: "long", year: "numeric" }).format(new Date(Number(m.mes.slice(0, 4)), Number(m.mes.slice(5, 7)) - 1, 1))}
              </b>
              <span>
                {t.est.entradas} {money(m.ingresos, divisa)} · {t.est.salidas} {money(m.gastos, divisa)}
                {i === 0 ? ` · ${t.est.mesEnCurso}` : ""}
              </span>
            </div>
            <span className={`amt${m.neto > 0 ? " in" : ""}`}>{money(m.neto, divisa, { sign: true })}</span>
          </div>
        ))}
      </section>
    </>
  );
}

export function Estadisticas() {
  const [periodo, setPeriodo] = useState<PeriodoEst>("mes_actual");
  const [tab, setTab] = useState<Tab>("resumen");
  const [data, setData] = useState<Data | null>(null);
  const [error, setError] = useState(false);

  const load = useCallback((p: PeriodoEst) => {
    setError(false);
    setData(null);
    getJson<Data>(`/api/estadisticas?periodo=${p}`).then(setData, () => setError(true));
  }, []);

  useEffect(() => load(periodo), [periodo, load]);

  const approx = data && (data.resumen.aproximado.ingresos || data.resumen.aproximado.gastos || data.resumen.aproximado.neto);

  return (
    <>
      <div className="chips" role="tablist" aria-label={t.app.estadisticas}>
        {TABS.map((x) => (
          <button key={x} type="button" role="tab" aria-selected={tab === x} className={`chip${tab === x ? " on" : ""}`} onClick={() => setTab(x)}>
            {t.est[x]}
          </button>
        ))}
      </div>
      {tab !== "tendencias" ? (
        <div className="seg seg3" role="group" aria-label={t.est.resumen}>
          {PERIODS.map((p) => (
            <button key={p} type="button" aria-pressed={periodo === p} onClick={() => setPeriodo(p)}>
              {t.est.periodos[p]}
            </button>
          ))}
        </div>
      ) : null}
      {error ? (
        <div className="cd">
          <p className="empty">{t.app.noCargo}</p>
          <button className="btn-s" type="button" onClick={() => load(periodo)}>
            {t.app.reintentar}
          </button>
        </div>
      ) : !data ? (
        <Skeleton />
      ) : tab === "resumen" ? (
        <Resumen d={data} periodo={periodo} />
      ) : tab === "distribucion" ? (
        <Distribucion d={data} periodo={periodo} />
      ) : (
        <Tendencias d={data} />
      )}
      {approx ? <p className="note-y">{t.est.aproximado}</p> : null}
      {data?.incompleto ? <p className="note-y">{t.est.incompleto}</p> : null}
      <p className="fade small">{t.est.nota}</p>
    </>
  );
}
