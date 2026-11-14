/**
 * Presupuestos (lote 2b), en lectura. Las cifras son las de la pantalla de Presupuestos del iPhone: las calcula
 * `estado_presupuestos` del núcleo compartido (`shared-core/src/logic/budgets.ts`, paridad en `mcp/test/golden.test.ts`).
 * Como en el iPhone, en tres bloques: Excedidos, Activos e Inactivos. Crear y cambiar sigue en el iPhone.
 */
import { useCallback, useEffect, useState } from "react";
import { locale, texts } from "../i18n";
import { getJson, type Presupuesto, type Presupuestos as Data } from "./api";
import { money, named, todayKey } from "./format";

const t = texts();

function pct(v: number): string {
  return `${new Intl.NumberFormat(locale(), { maximumFractionDigits: 0 }).format(v)} %`;
}

/** «Cerrado», «Último día» o «3 días restantes». */
function daysLabel(p: Presupuesto): string {
  const today = todayKey();
  if (p.periodo.hasta < today) return t.pre.cerrado;
  if (p.periodo.hasta === today) return t.pre.ultimoDia;
  return t.pre.diasRestantes(p.dias_restantes);
}

export function BudgetCard({ p }: { p: Presupuesto }) {
  const width = p.porcentaje === null ? 0 : Math.min(100, Math.max(0, p.porcentaje));
  const over = p.restante < 0;
  const meta = [t.pre.periodos[p.periodo.tipo] ?? p.periodo.tipo, p.activo ? daysLabel(p) : null].filter(Boolean).join(" · ");
  return (
    <div className="bud" data-estado={p.estado}>
      <div className="bud-h">
        <b>{named(p.nombre)}</b>
        <span className={`bud-st st-${p.estado}`}>{t.pre.estados[p.estado] ?? p.estado}</span>
      </div>
      <div className="bud-amt">
        <span className="amt">
          {p.aproximado ? "≈ " : ""}
          {money(p.gastado, p.divisa)}
        </span>
        {p.limite > 0 ? <span className="fade"> {t.pre.de(money(p.limite, p.divisa))}</span> : null}
      </div>
      {p.limite > 0 ? (
        <div
          className="bar"
          role="meter"
          aria-label={named(p.nombre)}
          aria-valuemin={0}
          aria-valuemax={100}
          aria-valuenow={Math.round(p.porcentaje ?? 0)}
          aria-valuetext={t.pre.gastado(pct(p.porcentaje ?? 0))}
        >
          <i style={{ width: `${width}%` }} />
        </div>
      ) : null}
      <div className="bud-f">
        <span>{meta}</span>
        {p.limite > 0 ? <span className="amt-s">{over ? t.pre.tePasaste(money(-p.restante, p.divisa)) : t.pre.quedan(money(p.restante, p.divisa))}</span> : null}
      </div>
    </div>
  );
}

export function Presupuestos() {
  const [data, setData] = useState<Data | null>(null);
  const [error, setError] = useState(false);

  const load = useCallback(() => {
    setError(false);
    getJson<Data>("/api/presupuestos").then(setData, () => setError(true));
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
        <div className="skel" />
        <div className="skel" />
      </div>
    );
  }
  if (data.presupuestos.length === 0) {
    return (
      <div className="cd">
        <h2>{t.pre.vacio}</h2>
        <p className="empty">{t.pre.vacioCuerpo}</p>
      </div>
    );
  }

  // Los bloques del iPhone (`budgets.status.*`): excedidos, el resto de activos y los inactivos.
  const sections: { title: string; items: Presupuesto[] }[] = [
    { title: t.pre.excedidos, items: data.presupuestos.filter((p) => p.activo && p.estado === "excedido") },
    { title: t.pre.activos, items: data.presupuestos.filter((p) => p.activo && p.estado !== "excedido") },
    { title: t.pre.inactivos, items: data.presupuestos.filter((p) => !p.activo) },
  ].filter((s) => s.items.length > 0);

  return (
    <>
      {sections.map((s) => (
        <section className="cd" key={s.title} aria-label={s.title}>
          <h2>{s.title}</h2>
          <div className="buds">
            {s.items.map((p) => (
              <BudgetCard key={p.id} p={p} />
            ))}
          </div>
        </section>
      ))}
      {data.presupuestos.some((p) => p.aproximado) ? <p className="note-y">{t.pre.aproximado}</p> : null}
      <p className="fade small">{t.pre.nota}</p>
    </>
  );
}
