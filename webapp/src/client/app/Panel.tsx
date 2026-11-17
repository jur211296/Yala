/**
 * El Panel de la beta: saldo total y entradas y salidas del mes, las cuentas, los últimos registros y en qué se gastó el
 * mes. Las cifras vienen calculadas por el núcleo compartido: aquí solo se pintan.
 */
import { texts } from "../i18n";
import type { Movimiento, Panel as PanelData } from "./api";
import { accountColor, money } from "./format";
import { Monto } from "./Monto";
import { COLOR_POR_DEFECTO, colorSeguro, iconoLucide } from "./simbolos";

const t = texts();

/** El rosa de marca con que la app marca un gasto de grupo que aún no tiene subcategoría (`Color.hotPink`). */
const ROSA_SIN_CLASIFICAR = "#FF0080";

/**
 * Fila de un registro. El círculo es el de la fila de la app (`RecordRowView.subcategoryIcon`): el ícono y el color que la
 * persona eligió para la categoría (lote 2), con sus respaldos (la etiqueta y el índigo), y el «!» rosa en un gasto de
 * grupo que aún no tiene subcategoría. La forma de la fila es de la base: el lote 4 la rehace.
 */
export function MovimientoRow({ m, onOpen }: { m: Movimiento; onOpen?: (m: Movimiento) => void }) {
  const sinClasificar = m.gasto_de_grupo && !m.subcategoria_id;
  const Icono = iconoLucide(m.icono);
  const inner = (
    <>
      <span className="ic" style={{ background: sinClasificar ? ROSA_SIN_CLASIFICAR : colorSeguro(m.color, COLOR_POR_DEFECTO) }} aria-hidden="true">
        {sinClasificar ? "!" : <Icono size={18} strokeWidth={2.2} aria-hidden={true} focusable={false} />}
      </span>
      <span className="t">
        <b>{m.nota || m.subcategoria || m.categoria || t.app.tipos[m.tipo]}</b>
        <span>{[m.subcategoria ?? m.categoria ?? t.app.sinCategoria, m.cuenta ?? t.app.sinCuenta].join(" · ")}</span>
      </span>
      <span className={`amt${m.tipo === "ingreso" ? " in" : ""}`}>{money(m.importe, m.divisa, { sign: m.tipo === "ingreso" })}</span>
    </>
  );
  if (!onOpen) return <div className="row">{inner}</div>;
  return (
    <button type="button" className="row row-btn" onClick={() => onOpen(m)}>
      {inner}
    </button>
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

export function Panel({ data, error, retry, onSeeAll }: { data: PanelData | null; error: boolean; retry: () => void; onSeeAll: () => void }) {
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

  return (
    <>
      <section className="cd hero" aria-label={t.app.saldoTotal}>
        <span className="cap">{t.app.saldoTotal}</span>
        <span className="big">
          {total.aproximado ? "≈ " : ""}
          <Monto importe={total.importe} divisa={total.divisa} tam="hero" />
        </span>
        <div className="inout">
          <span>
            {t.app.entradas} {t.app.delMes} <b className="amt in">{money(mes.ingresos, mes.divisa)}</b>
          </span>
          <span>
            {t.app.salidas} {t.app.delMes} <b>{money(mes.gastos, mes.divisa)}</b>
          </span>
        </div>
        {total.aproximado || mes.aproximado ? <p className="empty">{t.app.aproximado}</p> : null}
      </section>

      {visibles.length > 0 ? (
        <div className="accs" role="list" aria-label={t.app.cuenta}>
          {visibles.map((c, i) => {
            // El ícono de la cuenta en las listas de la app (`displayIconName`). El carrusel del Panel de la app usa además
            // el diseño de tarjeta; eso y el color de la cuenta llegan con las tarjetas del lote 4 (con el color de la
            // cuenta de fondo, el texto blanco no siempre se lee).
            const Icono = iconoLucide(c.icono, "building.columns.fill");
            return (
              <div className="ac" role="listitem" key={c.id} style={{ background: accountColor(i) }}>
                <span style={{ display: "flex", alignItems: "center", gap: 6 }}>
                  <Icono size={16} strokeWidth={2.2} aria-hidden={true} focusable={false} />
                  {c.nombre}
                </span>
                <b>{money(c.saldo, c.divisa)}</b>
              </div>
            );
          })}
        </div>
      ) : (
        <p className="note-y">{t.app.sinCuentas}</p>
      )}

      <div className="grid2">
        <section className="cd">
          <h2>
            {t.app.ultimos}
            <a
              href="/registros"
              onClick={(e) => {
                e.preventDefault();
                onSeeAll();
              }}
            >
              {t.app.verTodos}
            </a>
          </h2>
          {data.ultimos.movimientos.length === 0 ? <p className="empty">{t.app.sinRegistros}</p> : null}
          {data.ultimos.movimientos.map((m) => (
            <MovimientoRow key={m.id} m={m} />
          ))}
        </section>
        <section className="cd">
          <h2>{t.app.enQueGastaste}</h2>
          {top.length === 0 ? <p className="empty">{t.app.sinGastos}</p> : null}
          {top.map((c) => (
            <div key={c.categoria} style={{ margin: "10px 0" }}>
              <div style={{ display: "flex", justifyContent: "space-between", fontSize: 13, gap: 8 }}>
                <span>{c.categoria}</span>
                <span className="amt" style={{ fontSize: 13 }}>
                  {money(c.importe, mes.divisa)}
                </span>
              </div>
              <div className="bar">
                <i style={{ width: `${Math.max(3, (c.importe / max) * 100)}%` }} />
              </div>
            </div>
          ))}
        </section>
      </div>
    </>
  );
}
