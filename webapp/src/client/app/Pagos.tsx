/**
 * Pagos planificados (lote 2): los próximos cobros de 30 días con el calendario del iPhone y las suscripciones activas.
 * Las fechas y los totales los calcula el núcleo compartido (`shared-core/src/logic/schedule.ts`). Lote 2b: lo que ya
 * está pagado lleva la marca «Pagado» (la palabra de la app) y no suma en «Por pagar» (`webapp/src/worker/paid.ts`).
 * En lectura: crear, editar o marcar como pagado sigue en el iPhone.
 *
 * Lote 5 de «Yala web como la app»: «Por pagar» es la cifra principal sobre el fondo, con el «?» que dice de dónde sale;
 * cada cobro es la fila de Registros con el ícono y el color de su categoría (`categorias.ts`), agrupados por día; en
 * escritorio, Próximos cobros a la izquierda y Suscripciones a la derecha.
 */
import { useCallback, useEffect, useState } from "react";
import { texts } from "../i18n";
import { getJson, type Cobro, type Pagos as Data, type Suscripcion } from "./api";
import { money, named, shortDate } from "./format";
import { Monto } from "./Monto";
import { CifraPrincipal } from "./Cifra";
import { simboloPorNombre, useCategorias, type Simbolo } from "./categorias";

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

function Circulo({ sim }: { sim: Simbolo }) {
  return (
    <span className="circ" style={{ background: sim.color }} aria-hidden="true">
      <sim.Icono size={20} strokeWidth={2.2} aria-hidden={true} focusable={false} />
    </span>
  );
}

function CobroRow({ c, cats }: { c: Cobro; cats: ReturnType<typeof useCategorias> }) {
  const income = c.movimiento === "ingreso";
  return (
    <div className={`fila${c.pagado ? " paid" : ""}`}>
      <Circulo sim={simboloPorNombre(cats, c.categoria, { primero: "subcategoria" })} />
      <span className="fila-t">
        <b>{named(c.nombre)}</b>
        <span>{[freq(c.frecuencia, c.cada), c.categoria, income ? t.pag.ingreso : null].filter(Boolean).join(" · ")}</span>
      </span>
      <span className="fila-a">
        <Monto importe={income ? c.importe : -c.importe} divisa={c.divisa} signo={income} className={`amt${income ? " in" : ""}`} />
        {c.pagado ? <span className="paid-tag">{t.pag.pagado}</span> : null}
      </span>
    </div>
  );
}

function SubRow({ s, divisa, cats }: { s: Suscripcion; divisa: string; cats: ReturnType<typeof useCategorias> }) {
  return (
    <div className="fila">
      <Circulo sim={simboloPorNombre(cats, s.categoria, { primero: "subcategoria" })} />
      <span className="fila-t">
        <b>{named(s.nombre)}</b>
        <span>
          {[freq(s.frecuencia, s.cada), s.proximo_cobro ? t.pag.proximo(shortDate(dayIso(s.proximo_cobro))) : null].filter(Boolean).join(" · ")}
        </span>
      </span>
      <span className="fila-a">
        <Monto importe={-s.importe} divisa={s.divisa} className="amt" />
        {s.divisa !== divisa && s.equivalente_mensual_en_divisa_preferida !== null ? (
          <small className="sub">≈ {money(s.equivalente_mensual_en_divisa_preferida, divisa)}</small>
        ) : null}
      </span>
    </div>
  );
}

export function Pagos() {
  const [data, setData] = useState<Data | null>(null);
  const [error, setError] = useState(false);
  const cats = useCategorias();

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
      <CifraPrincipal
        rotulo={t.pag.porPagar}
        explica={[t.pag.porPagarExplica, ...(data.aproximado ? [t.pag.aproximado] : [])]}
        debajo={data.pagados > 0 ? <span className="inout">{t.pag.pagados(data.pagados)}</span> : null}
      >
        {data.aproximado ? "≈ " : ""}
        <Monto importe={data.total_gastos} divisa={data.divisa} tam="hero" />
      </CifraPrincipal>
      <div className="pag-cols">
        <section aria-label={t.pag.proximos}>
          <h2 className="sec">{t.pag.proximos}</h2>
          {groups.length === 0 ? <p className="empty">{t.pag.sinProximos}</p> : null}
          {groups.map((g) => (
            <div className="reg-dia" key={g.day}>
              <div className="dia">
                <span>
                  {when(g.en)} · {shortDate(dayIso(g.day))}
                </span>
              </div>
              <div className="filas">
                {g.items.map((c) => (
                  <CobroRow key={`${c.id}-${c.dia}`} c={c} cats={cats} />
                ))}
              </div>
            </div>
          ))}
        </section>
        <section aria-label={t.pag.suscripciones}>
          <h2 className="sec">{t.pag.suscripciones}</h2>
          {data.suscripciones.length > 0 ? <p className="pag-sub">{t.pag.alMes(money(data.suscripciones_mensual, data.divisa))}</p> : null}
          {data.suscripciones.length === 0 ? <p className="empty">{t.pag.sinSuscripciones}</p> : null}
          <div className="filas">
            {data.suscripciones.map((s) => (
              <SubRow key={s.id} s={s} divisa={data.divisa} cats={cats} />
            ))}
          </div>
        </section>
      </div>
      {data.aproximado ? <p className="note-y">{t.pag.aproximado}</p> : null}
      <p className="fade small">{t.pag.nota}</p>
    </>
  );
}
