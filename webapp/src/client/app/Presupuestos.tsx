/**
 * Presupuestos (lote 2b), en lectura. Las cifras son las de la pantalla de Presupuestos del iPhone: las calcula
 * `estado_presupuestos` del núcleo compartido (`shared-core/src/logic/budgets.ts`, paridad en `mcp/test/golden.test.ts`).
 * Crear y cambiar sigue en el iPhone.
 *
 * Lote 5 de «Yala web como la app»: la tarjeta es la de la app (`BudgetRowView`): círculo con el ícono y el color de la
 * categoría, el nombre, «S/ 1,461.00 de S/ 1,800.00 · 15 días», a la derecha «Te quedan» y la cifra (o «Te pasaste por»
 * en rosa), y la barra del color de la categoría, ámbar en riesgo y rosa al pasarse, con «En el límite» o «Te pasaste»
 * debajo. Las secciones (Excedidos, Activos, Inactivos) son títulos sueltos, y en escritorio las tarjetas van de dos en
 * dos. El ícono y el color se buscan por el nombre del presupuesto (`categorias.ts`, decisión D1).
 */
import { useCallback, useEffect, useState } from "react";
import { TriangleAlert } from "lucide-react";
import { locale, texts } from "../i18n";
import { getJson, type Presupuesto, type Presupuestos as Data } from "./api";
import { money, named, todayKey } from "./format";
import { Monto } from "./Monto";
import { simboloPorNombre, useCategorias } from "./categorias";
import { colorBarra } from "./pantallas";

const t = texts();

function pct(v: number): string {
  return `${new Intl.NumberFormat(locale(), { maximumFractionDigits: 0 }).format(v)} %`;
}

/** «Cerrado», «Último día» o «15 días», como la línea gris de la app. */
function daysLabel(p: Presupuesto): string {
  const today = todayKey();
  if (p.periodo.hasta < today) return t.pre.cerrado;
  if (p.periodo.hasta === today) return t.pre.ultimoDia;
  return t.pre.dias(p.dias_restantes);
}

export function BudgetCard({ p, cats }: { p: Presupuesto; cats: ReturnType<typeof useCategorias> }) {
  const width = p.porcentaje === null ? 0 : Math.min(100, Math.max(0, p.porcentaje));
  const over = p.restante < 0;
  const sim = simboloPorNombre(cats, p.nombre, { sf: "chart.pie.fill", color: "var(--fill)" });
  const linea = [
    p.limite > 0 ? t.pre.deLimite(money(p.gastado, p.divisa), money(p.limite, p.divisa)) : money(p.gastado, p.divisa),
    p.activo ? daysLabel(p) : t.pre.estados.inactivo,
  ].join(" · ");
  const estado = p.estado === "excedido" ? t.pre.tePasasteEstado : p.estado === "en_riesgo" ? t.pre.enElLimite : null;
  return (
    <div className="bud" data-estado={p.estado}>
      <div className="bud-h">
        <span className="circ" style={{ background: sim.color }} aria-hidden="true">
          <sim.Icono size={20} strokeWidth={2.2} aria-hidden={true} focusable={false} />
        </span>
        <span className="bud-t">
          <b>{named(p.nombre)}</b>
          <span className="bud-l">
            {p.aproximado ? "≈ " : ""}
            {linea}
          </span>
        </span>
        {p.limite > 0 ? (
          <span className={`bud-r${over ? " over" : ""}`}>
            <span className="bud-rl">{over ? t.pre.tePasastePor : t.pre.teQuedan}</span>
            <span className="bud-ra">
              {over ? <TriangleAlert aria-hidden={true} focusable={false} /> : null}
              <Monto importe={Math.abs(p.restante)} divisa={p.divisa} className="amt" />
            </span>
          </span>
        ) : null}
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
          <i style={{ width: `${width}%`, background: colorBarra(p, sim.color) }} />
        </div>
      ) : null}
      {estado ? <span className={`bud-st st-${p.estado}`}>{estado}</span> : null}
    </div>
  );
}

export function Presupuestos() {
  const [data, setData] = useState<Data | null>(null);
  const [error, setError] = useState(false);
  const cats = useCategorias();

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
        <section className="bud-sec" key={s.title} aria-label={s.title}>
          <h2 className="bud-sh">{s.title}</h2>
          <div className="buds">
            {s.items.map((p) => (
              <BudgetCard key={p.id} p={p} cats={cats} />
            ))}
          </div>
        </section>
      ))}
      {data.presupuestos.some((p) => p.aproximado) ? <p className="note-y">{t.pre.aproximado}</p> : null}
      <p className="fade small">{t.pre.nota}</p>
    </>
  );
}
