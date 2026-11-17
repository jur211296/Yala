/**
 * La fila de un registro como la de la app (`RecordRowView`), lote 4 de «Yala web como la app»: una tarjeta con el
 * círculo de 40 px del color de la categoría y su ícono, el título (la nota; si no hay, la subcategoría o la categoría),
 * «subcategoría · cuenta», las etiquetas en píldoras, y a la derecha la cifra (`Monto`) y la píldora de necesidad.
 *
 * La píldora de necesidad sale como en la app: solo en un gasto con subcategoría (`showsNeedPill`). Un gasto de grupo que
 * aún no tiene subcategoría lleva el «!» rosa en el círculo (lote 2).
 *
 * También la cabecera de cada día (`DiaRegistros`), con lo gastado ese día, y el detalle (`DetalleRegistro`), que
 * Registros pinta a la derecha en escritorio y en una hoja en el celular y desde ⌘K.
 */
import type { ReactNode } from "react";
import { texts } from "../i18n";
import type { Movimiento } from "./api";
import { dayLabel } from "./format";
import { Monto } from "./Monto";
import { muestraNecesidad, subtituloDe, tituloDe } from "./registro";
import { COLOR_POR_DEFECTO, colorSeguro, iconoLucide } from "./simbolos";

const t = texts();

/** El rosa de marca con que la app marca un gasto de grupo que aún no tiene subcategoría (`Color.hotPink`). */
const ROSA_SIN_CLASIFICAR = "#FF0080";

/** Los colores de la píldora de necesidad (`SubcategoryNeed.color` de la app). */
export const COLOR_NECESIDAD: Record<string, string> = {
  esencial: "#F59E0B",
  prioritaria: "#8B5CF6",
  opcional: "#FB7185",
  sin_clasificacion: "#8E8E93",
};

export function Pildora({ color, children }: { color: string; children: ReactNode }) {
  return (
    <span className="pildora" style={{ ["--dot" as string]: color }}>
      {children}
    </span>
  );
}

/** El círculo de la fila: el ícono y el color de la categoría; el «!» rosa en un gasto de grupo sin subcategoría. */
export function CirculoRegistro({ m, grande }: { m: Movimiento; grande?: boolean }) {
  const sinClasificar = m.gasto_de_grupo && !m.subcategoria_id;
  const Icono = iconoLucide(m.icono);
  return (
    <span className={`circ${grande ? " grande" : ""}`} style={{ background: sinClasificar ? ROSA_SIN_CLASIFICAR : colorSeguro(m.color, COLOR_POR_DEFECTO) }} aria-hidden="true">
      {sinClasificar ? "!" : <Icono size={grande ? 30 : 20} strokeWidth={2.2} aria-hidden={true} focusable={false} />}
    </span>
  );
}

function CifraRegistro({ m }: { m: Movimiento }) {
  const ingreso = m.tipo === "ingreso";
  return <Monto importe={m.importe} divisa={m.divisa} signo={ingreso} className={`amt${ingreso ? " in" : ""}`} />;
}

export function FilaRegistro({ m, onOpen, abierta }: { m: Movimiento; onOpen?: (m: Movimiento) => void; abierta?: boolean }) {
  const inner = (
    <>
      <CirculoRegistro m={m} />
      <span className="fila-t">
        <b>{tituloDe(m)}</b>
        <span>{subtituloDe(m)}</span>
        {m.etiquetas.length > 0 ? (
          <span className="fila-tags">
            {m.etiquetas.map((e) => (
              <Pildora key={e} color="var(--acc)">
                {e}
              </Pildora>
            ))}
          </span>
        ) : null}
      </span>
      <span className="fila-a">
        <CifraRegistro m={m} />
        {muestraNecesidad(m) ? <Pildora color={COLOR_NECESIDAD[m.necesidad] ?? COLOR_NECESIDAD.sin_clasificacion!}>{t.app.necesidades[m.necesidad] ?? m.necesidad}</Pildora> : null}
      </span>
    </>
  );
  if (!onOpen) return <div className="fila">{inner}</div>;
  return (
    <button type="button" className="fila fila-btn" aria-current={abierta ? "true" : undefined} onClick={() => onOpen(m)}>
      {inner}
    </button>
  );
}

export function DiaRegistros({ dia, gastado, divisa }: { dia: string | null; gastado: number | null; divisa: string | null }) {
  return (
    <div className="dia">
      <span>{dayLabel(dia)}</span>
      {gastado !== null && divisa ? <Monto importe={-gastado} divisa={divisa} className="amt" /> : null}
    </div>
  );
}

/** El detalle de un registro: el círculo grande, el título, la cifra, la necesidad y sus datos. */
export function DetalleRegistro({ m, acciones }: { m: Movimiento; acciones?: ReactNode }) {
  const rows: [string, string][] = [
    [t.app.categoria, m.categoria ?? t.app.sinCategoria],
    [t.app.cuenta, m.cuenta ?? t.app.sinCuenta],
    [t.app.fecha, dayLabel(m.fecha)],
    [t.app.tipo, t.app.tipos[m.tipo] ?? m.tipo],
  ];
  if (m.subcategoria) rows.splice(1, 0, [t.app.subcategoria, m.subcategoria]);
  if (m.nota) rows.push([t.app.nota, m.nota]);
  if (m.etiquetas.length) rows.push([t.app.etiquetas, m.etiquetas.join(", ")]);
  return (
    <>
      <div className="det-h">
        <h2>{t.app.detalle}</h2>
        {acciones}
      </div>
      <div className="det-top">
        <CirculoRegistro m={m} grande />
        <b>{tituloDe(m)}</b>
        <Monto importe={m.importe} divisa={m.divisa} signo={m.tipo === "ingreso"} className={`amt det-amt${m.tipo === "ingreso" ? " in" : ""}`} />
        {muestraNecesidad(m) ? <Pildora color={COLOR_NECESIDAD[m.necesidad] ?? COLOR_NECESIDAD.sin_clasificacion!}>{t.app.necesidades[m.necesidad] ?? m.necesidad}</Pildora> : null}
      </div>
      <div className="det-list">
        {rows.map(([k, v]) => (
          <div className="det-row" key={k}>
            <span>{k}</span>
            <span>{v}</span>
          </div>
        ))}
      </div>
      {m.gasto_de_grupo ? <p className="note-y">{t.app.gastoDeGrupo}</p> : null}
      <p className="note-y">{t.app.registrosNota}</p>
    </>
  );
}
