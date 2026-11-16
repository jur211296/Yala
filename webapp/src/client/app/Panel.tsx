/**
 * El Panel de la beta: saldo total y entradas y salidas del mes, las cuentas, los últimos registros y en qué se gastó el
 * mes. Las cifras vienen calculadas por el núcleo compartido: aquí solo se pintan.
 */
import { texts } from "../i18n";
import type { Movimiento, Panel as PanelData } from "./api";
import { accountColor, badge, money } from "./format";

const t = texts();

export function MovimientoRow({ m, onOpen }: { m: Movimiento; onOpen?: (m: Movimiento) => void }) {
  const b = badge(m.categoria ?? m.nota);
  const inner = (
    <>
      <span className="ic" style={{ background: b.color }} aria-hidden="true">
        {b.letter}
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
          {money(total.importe, total.divisa)}
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
          {visibles.map((c, i) => (
            <div className="ac" role="listitem" key={c.id} style={{ background: accountColor(i) }}>
              <span>{c.nombre}</span>
              <b>{money(c.saldo, c.divisa)}</b>
            </div>
          ))}
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
