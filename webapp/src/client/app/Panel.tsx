/**
 * El Panel, como la pestaña Panel de la app (lote 4 de «Yala web como la app»): «Tu saldo hoy» en grande sobre el fondo,
 * con el «?» que explica la cifra y las entradas y salidas del mes; «Tus finanzas» con las cuentas (cápsulas de cristal en
 * el celular, tarjetas en escritorio); «Últimos registros» con la fila de la app; y, como en la app, Distribución y
 * Planificación (decisión «panel-widgets» de la maqueta aprobada).
 *
 * Las cifras vienen calculadas por el núcleo compartido: aquí solo se pintan. Distribución usa las categorías de gasto del
 * mes de `/api/panel` con su ícono y color de `/api/categorias`; Planificación, lo que muestran Pagos planificados y
 * Presupuestos (`/api/pagos`, `/api/presupuestos`). Si una de esas llamadas falla, su bloque no sale: el Panel no se cae.
 */
import { useEffect, useId, useState, type ReactNode } from "react";
import { ChevronRight, CircleHelp } from "lucide-react";
import { locale, texts } from "../i18n";
import { getJson, type Categoria, type Pagos, type Panel as PanelData, type Presupuesto, type Presupuestos } from "./api";
import { money, named } from "./format";
import { FilaRegistro } from "./FilaRegistro";
import { Monto } from "./Monto";
import { COLOR_POR_DEFECTO, colorSeguro, iconoLucide } from "./simbolos";

const t = texts();

/** A dónde llevan los títulos de sección del Panel. */
export type DestinoPanel = "registros" | "estadisticas" | "presupuestos" | "pagos";

function Skeleton() {
  return (
    <div className="cd" aria-busy="true">
      <div className="skel" style={{ width: "30%" }} />
      <div className="skel" style={{ width: "55%", height: 30 }} />
      <div className="skel" style={{ width: "70%" }} />
    </div>
  );
}

/** Título de sección de la app: grande, con la flecha de cristal que lleva a su pantalla. */
function Seccion({ titulo, href, onGo }: { titulo: string; href?: string; onGo?: () => void }) {
  return (
    <h2 className="sec">
      {titulo}
      {href && onGo ? (
        <a
          className="sec-ir"
          href={href}
          aria-label={titulo}
          onClick={(e) => {
            if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || e.button !== 0) return;
            e.preventDefault();
            onGo();
          }}
        >
          <ChevronRight aria-hidden={true} focusable={false} />
        </a>
      ) : null}
    </h2>
  );
}

/** Una llamada que, si falla, deja su bloque fuera (`null`) en vez de tumbar el Panel. */
function useOpcional<T>(path: string): T | null {
  const [data, setData] = useState<T | null>(null);
  useEffect(() => {
    let vivo = true;
    getJson<T>(path).then(
      (d) => vivo && setData(d),
      () => undefined,
    );
    return () => {
      vivo = false;
    };
  }, [path]);
  return data;
}

/** El color de una barra de presupuesto, como `BudgetProgressBar`: el de la categoría; ámbar en riesgo, rosa al pasarse. */
function colorPresupuesto(p: Presupuesto): string {
  if (p.estado === "excedido") return "var(--owe)";
  if (p.estado === "en_riesgo") return "var(--risk-fill)";
  return "var(--fill)";
}

export function Panel({
  data,
  error,
  retry,
  onGo,
  accion,
}: {
  data: PanelData | null;
  error: boolean;
  retry: () => void;
  onGo: (s: DestinoPanel) => void;
  /** «+ Nuevo registro» del celular: va debajo del saldo, como en la app. */
  accion?: ReactNode;
}) {
  const [ayuda, setAyuda] = useState(false);
  const ayudaId = useId();
  const cats = useOpcional<{ categorias: Categoria[] }>("/api/categorias");
  const pagos = useOpcional<Pagos>("/api/pagos");
  const presupuestos = useOpcional<Presupuestos>("/api/presupuestos");

  if (error) {
    return (
      <div className="cd">
        <p className="empty">{t.app.noCargo}</p>
        <button className="btn-s" type="button" onClick={retry}>
          {t.app.reintentar}
        </button>
      </div>
    );
  }
  if (!data) return <Skeleton />;

  const { total, cuentas } = data.cuentas;
  const visibles = cuentas.filter((c) => !c.archivada);
  const mes = data.mes;
  const top = mes.top_categorias_gasto;
  const max = Math.max(1, ...top.map((x) => x.importe));
  const porNombre = new Map((cats?.categorias ?? []).filter((c) => !c.es_ingreso).map((c) => [c.nombre, c]));
  const aproximado = total.aproximado || mes.aproximado;
  const activos = (presupuestos?.presupuestos ?? [])
    .filter((p) => p.activo && p.porcentaje !== null)
    .sort((a, b) => (b.porcentaje ?? 0) - (a.porcentaje ?? 0))
    .slice(0, 2);

  return (
    <div className="panel">
      <section className="saldo" aria-labelledby={`${ayudaId}-t`}>
        <div className="saldo-l">
          <span className="cap" id={`${ayudaId}-t`}>
            {t.app.saldoHoy}
          </span>
          <button
            type="button"
            className="ayuda"
            aria-expanded={ayuda}
            aria-controls={ayudaId}
            aria-label={t.app.porQueMonto}
            title={t.app.porQueMonto}
            onClick={() => setAyuda((v) => !v)}
          >
            <CircleHelp aria-hidden={true} focusable={false} />
          </button>
        </div>
        <span className="big">
          {total.aproximado ? "≈ " : ""}
          <Monto importe={total.importe} divisa={total.divisa} tam="hero" />
        </span>
        {ayuda ? (
          <div className="ayuda-t" id={ayudaId} role="note">
            <p>{t.app.saldoExplica}</p>
            {aproximado ? <p>{t.app.aproximado}</p> : null}
          </div>
        ) : null}
        <div className="inout">
          <span>
            ↗ {t.app.entradas} {t.app.delMes} <b className="amt in">{money(mes.ingresos, mes.divisa)}</b>
          </span>
          <span>
            ↘ {t.app.salidas} {t.app.delMes} <b>{money(mes.gastos, mes.divisa)}</b>
          </span>
        </div>
      </section>
      {accion}

      <section className="finanzas" aria-label={t.app.tusFinanzas}>
        <Seccion titulo={t.app.tusFinanzas} />
        {visibles.length > 0 ? (
          <div className="cuentas" role="list">
            {visibles.map((c) => {
              // El ícono de la cuenta en las listas de la app (`displayIconName`) y su color, oscurecido en la tarjeta
              // para que el texto blanco se lea con cualquier color guardado.
              const Icono = iconoLucide(c.icono, "building.columns.fill");
              const color = colorSeguro(c.color, COLOR_POR_DEFECTO);
              return (
                <div className="cuenta" role="listitem" key={c.id} style={{ ["--c" as string]: color }}>
                  <span className="cuenta-n">
                    <span className="cuenta-ic" aria-hidden="true">
                      <Icono size={16} strokeWidth={2.2} aria-hidden={true} focusable={false} />
                    </span>
                    <b>{c.nombre}</b>
                  </span>
                  <Monto importe={c.saldo} divisa={c.divisa} className="amt cuenta-amt" />
                </div>
              );
            })}
          </div>
        ) : (
          <p className="note-y">{t.app.sinCuentas}</p>
        )}
      </section>

      <div className="panel-grid">
        <section className="panel-ult" aria-label={t.app.ultimos}>
          <Seccion titulo={t.app.ultimos} href="/registros" onGo={() => onGo("registros")} />
          {data.ultimos.movimientos.length === 0 ? <p className="empty">{t.app.sinRegistros}</p> : null}
          <div className="filas">
            {data.ultimos.movimientos.map((m) => (
              <FilaRegistro key={m.id} m={m} />
            ))}
          </div>
        </section>

        <div className="panel-lado">
          <section aria-label={t.est.distribucion}>
            <Seccion titulo={t.est.distribucion} href="/estadisticas" onGo={() => onGo("estadisticas")} />
            <div className="cd dist-p">
              {top.length === 0 ? <p className="empty">{t.app.sinGastos}</p> : null}
              {top.map((c) => {
                const cat = porNombre.get(c.categoria);
                const color = colorSeguro(cat?.color, COLOR_POR_DEFECTO);
                const Icono = iconoLucide(cat?.icono);
                return (
                  <div key={c.categoria} className="dist-f">
                    <div className="dist-h">
                      <span className="dist-n">
                        <span className="dist-ic" style={{ background: color }} aria-hidden="true">
                          <Icono size={14} strokeWidth={2.4} aria-hidden={true} focusable={false} />
                        </span>
                        {c.categoria}
                      </span>
                      <span className="amt">{money(c.importe, mes.divisa)}</span>
                    </div>
                    <div className="bar">
                      <i style={{ width: `${Math.max(3, (c.importe / max) * 100)}%`, background: color }} />
                    </div>
                  </div>
                );
              })}
            </div>
          </section>

          {pagos || activos.length > 0 ? (
            <section aria-label={t.app.planificacion}>
              <Seccion titulo={t.app.planificacion} href="/planificacion" onGo={() => onGo("presupuestos")} />
              <div className="plan-p">
                {pagos ? (
                  <a
                    className="cd plan-c"
                    href="/pagos"
                    onClick={(e) => {
                      if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || e.button !== 0) return;
                      e.preventDefault();
                      onGo("pagos");
                    }}
                  >
                    <span className="cap">{t.app.pagos}</span>
                    <Monto importe={pagos.total_gastos} divisa={pagos.divisa} className="amt plan-amt" />
                    <span className="sub">{t.pag.porPagar}</span>
                  </a>
                ) : null}
                {activos.length > 0 ? (
                  <a
                    className="cd plan-c"
                    href="/presupuestos"
                    onClick={(e) => {
                      if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || e.button !== 0) return;
                      e.preventDefault();
                      onGo("presupuestos");
                    }}
                  >
                    <span className="cap">{t.app.presupuestos}</span>
                    {activos.map((p) => (
                      <span key={p.id} className="plan-b">
                        <span className="plan-bn">
                          <b>{named(p.nombre)}</b>
                          <span className="amt-s">{t.pre.gastado(`${new Intl.NumberFormat(locale(), { maximumFractionDigits: 0 }).format(p.porcentaje ?? 0)} %`)}</span>
                        </span>
                        <span className="bar">
                          <i style={{ width: `${Math.min(100, Math.max(3, p.porcentaje ?? 0))}%`, background: colorPresupuesto(p) }} />
                        </span>
                      </span>
                    ))}
                  </a>
                ) : null}
              </div>
            </section>
          ) : null}
        </div>
      </div>
    </div>
  );
}
