/**
 * Estadísticas (lote 2): Resumen, Distribución y Tendencias, con las cifras que calcula el núcleo compartido con las
 * reglas del iPhone (`shared-core/src/logic/stats.ts`, paridad en `mcp/test/golden.test.ts`). Aquí solo se pintan.
 *
 * Lote 5 de «Yala web como la app»: segmentos con ícono y texto en el orden de la app (Resumen, Tendencias,
 * Distribución) y el período en una cápsula; «Te queda» (o «Te quedó») es la cifra principal sobre el fondo, con el «?» y
 * las entradas y salidas debajo; Gasto medio diario y Gasto más alto en tarjetas, en la misma fila en escritorio; y cada
 * categoría con su ícono y su color (`categorias.ts`). «Sin categoría» va en el gris de la app.
 */
import { useCallback, useEffect, useState, type ReactNode } from "react";
import { Calendar, ChartLine, ChartPie, ChevronDown, Sparkles } from "lucide-react";
import { locale, texts } from "../i18n";
import { getJson, type Estadisticas as Data, type PeriodoEst, type Trozo } from "./api";
import { dayLabel, money } from "./format";
import { Monto } from "./Monto";
import { CifraPrincipal } from "./Cifra";
import { simboloPorNombre, useCategorias } from "./categorias";

const t = texts();
const PERIODS: PeriodoEst[] = ["mes_actual", "mes_pasado", "anio_actual"];
type Tab = "resumen" | "distribucion" | "tendencias";
/** El orden de la app: Resumen, Tendencias, Distribución. */
const TABS: Tab[] = ["resumen", "tendencias", "distribucion"];
const TAB_ICON: Record<Tab, ReactNode> = {
  resumen: <Sparkles aria-hidden={true} focusable={false} />,
  tendencias: <ChartLine aria-hidden={true} focusable={false} />,
  distribucion: <ChartPie aria-hidden={true} focusable={false} />,
};
/** El gris con que la app pinta «Sin categoría» (`AppConstants.uncategorizedColorHex`). */
const GRIS_SIN_CATEGORIA = "#9CA3AF";
type Cats = ReturnType<typeof useCategorias>;

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

function Slices({ list, divisa, cats }: { list: Trozo[]; divisa: string; cats: Cats }) {
  const max = Math.max(1, ...list.map((x) => x.importe));
  return (
    <>
      {list.map((c) => {
        const sim = c.categoria === null ? null : simboloPorNombre(cats, c.categoria);
        const color = sim?.color ?? GRIS_SIN_CATEGORIA;
        return (
          <div className="slice" key={c.id ?? "sin"}>
            <span className="circ chico" style={{ background: color }} aria-hidden="true">
              {sim ? <sim.Icono size={16} strokeWidth={2.4} aria-hidden={true} focusable={false} /> : "?"}
            </span>
            <div className="t">
              <div className="slice-h">
                <b>{sliceName(c)}</b>
                <Monto importe={c.importe} divisa={divisa} className="amt" />
              </div>
              <div className="bar" aria-hidden="true">
                <i style={{ width: `${Math.max(2, (c.importe / max) * 100)}%`, background: color }} />
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

function Resumen({ d, periodo, cats }: { d: Data; periodo: PeriodoEst; cats: Cats }) {
  const r = d.resumen;
  const contra = t.est.contra[periodo];
  const approx = r.aproximado.ingresos || r.aproximado.gastos || r.aproximado.neto;
  return (
    <>
      <div className="est-top">
        <CifraPrincipal
          rotulo={periodo === "mes_pasado" ? t.app.teQuedo : t.app.teQueda}
          explica={[t.est.netoExplica, ...(approx ? [t.est.aproximado] : [])]}
          debajo={
            <>
              <div className="inout">
                <span>
                  ↗ {t.est.entradas} <b className="amt in">{money(r.ingresos, r.divisa)}</b> <Variation value={r.variacion.ingresos} />
                </span>
                <span>
                  ↘ {t.est.salidas} <b>{money(r.gastos, r.divisa)}</b> <Variation value={r.variacion.gastos} worseUp />
                </span>
              </div>
              <p className="fade small">
                {[t.est.movimientos(r.movimientos), r.variacion.ingresos === null && r.variacion.gastos === null ? t.est.sinVariacion : contra].join(" · ")}
              </p>
            </>
          }
        >
          {r.aproximado.neto ? "≈ " : ""}
          <Monto importe={r.neto} divisa={r.divisa} tam="hero" />
        </CifraPrincipal>
        <section className="cd kpi-c" aria-label={t.est.gastoMedio}>
          <span className="cap">{t.est.gastoMedio}</span>
          <Monto importe={r.gasto_medio_diario} divisa={r.divisa} className="amt kpi" />
          <span className="sub">
            {t.est.dias(r.dias)} <Variation value={r.variacion.gasto_medio_diario} worseUp />
          </span>
        </section>
        <section className="cd kpi-c" aria-label={t.est.gastoMasAlto}>
          <span className="cap">{t.est.gastoMasAlto}</span>
          {r.gasto_mas_alto ? (
            <>
              <Monto importe={r.gasto_mas_alto.importe} divisa={r.divisa} className="amt kpi" />
              <span className="sub">{[r.gasto_mas_alto.nota ?? r.gasto_mas_alto.categoria ?? t.app.sinCategoria, dayLabel(r.gasto_mas_alto.dia)].join(" · ")}</span>
            </>
          ) : (
            <span className="sub">{t.est.sinGastosPeriodo}</span>
          )}
        </section>
      </div>
      <section aria-label={t.est.topCategorias}>
        <h2 className="sec">{t.est.topCategorias}</h2>
        <div className="cd">
          {r.top_categorias.length === 0 ? <p className="empty">{t.est.sinGastosPeriodo}</p> : <Slices list={r.top_categorias} divisa={r.divisa} cats={cats} />}
        </div>
      </section>
      {r.sin_categoria > 0 ? <p className="note-y">{t.est.sinCategoriaAviso(r.sin_categoria)}</p> : null}
    </>
  );
}

function Donut({ list, cats }: { list: Trozo[]; cats: Cats }) {
  let acc = 0;
  const stops = list.map((c) => {
    const from = acc;
    acc += c.porcentaje;
    const color = c.categoria === null ? GRIS_SIN_CATEGORIA : simboloPorNombre(cats, c.categoria).color;
    return `${color} ${from}% ${Math.min(100, acc)}%`;
  });
  const bg = stops.length ? `conic-gradient(${stops.join(", ")})` : "color-mix(in srgb, var(--ink2) 18%, transparent)";
  return <div className="donut" style={{ background: bg }} aria-hidden="true" />;
}

function Distribucion({ d, periodo, cats }: { d: Data; periodo: PeriodoEst; cats: Cats }) {
  const dist = d.distribucion;
  return (
    <>
      <CifraPrincipal rotulo={t.est.gastadoEn[periodo] ?? t.est.distribucion} debajo={<p className="fade small">{t.est.nCategorias(dist.categorias.length)}</p>}>
        <Monto importe={dist.total} divisa={dist.divisa} tam="hero" />
      </CifraPrincipal>
      <section className="cd">
        <h2>{t.est.porCategoria}</h2>
        {dist.categorias.length === 0 ? (
          <p className="empty">{t.est.sinGastosPeriodo}</p>
        ) : (
          <div className="dist">
            <Donut list={dist.categorias} cats={cats} />
            <div className="dist-list">
              <Slices list={dist.categorias} divisa={dist.divisa} cats={cats} />
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
  const cats = useCategorias();

  const load = useCallback((p: PeriodoEst) => {
    setError(false);
    setData(null);
    getJson<Data>(`/api/estadisticas?periodo=${p}`).then(setData, () => setError(true));
  }, []);

  useEffect(() => load(periodo), [periodo, load]);

  const approx = data && (data.resumen.aproximado.ingresos || data.resumen.aproximado.gastos || data.resumen.aproximado.neto);

  return (
    <>
      <div className="est-bar">
        <div className="psegs" role="tablist" aria-label={t.app.estadisticas}>
          {TABS.map((x) => (
            <button key={x} type="button" role="tab" aria-selected={tab === x} aria-label={t.est[x]} className="pseg" onClick={() => setTab(x)}>
              {TAB_ICON[x]}
              <span className="pseg-l">{t.est[x]}</span>
            </button>
          ))}
        </div>
        {tab !== "tendencias" ? (
          <label className="cap-sel on est-per">
            <Calendar aria-hidden={true} focusable={false} />
            <select aria-label={t.app.fecha} value={periodo} onChange={(e) => setPeriodo(e.target.value as PeriodoEst)}>
              {PERIODS.map((p) => (
                <option key={p} value={p}>
                  {t.est.periodos[p]}
                </option>
              ))}
            </select>
            <ChevronDown aria-hidden={true} focusable={false} />
          </label>
        ) : null}
      </div>
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
        <Resumen d={data} periodo={periodo} cats={cats} />
      ) : tab === "distribucion" ? (
        <Distribucion d={data} periodo={periodo} cats={cats} />
      ) : (
        <Tendencias d={data} />
      )}
      {approx && tab !== "resumen" ? <p className="note-y">{t.est.aproximado}</p> : null}
      {data?.incompleto ? <p className="note-y">{t.est.incompleto}</p> : null}
      <p className="fade small">{t.est.nota}</p>
    </>
  );
}
