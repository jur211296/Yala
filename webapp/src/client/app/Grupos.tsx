/**
 * Grupos (lote 3), en lectura: la lista con lo que te deben y lo que debes, y el detalle de cada grupo con quién le debe
 * a quién, los saldos por persona, los gastos y los pagos. Las cifras salen del núcleo compartido
 * (`shared-core/src/logic/groupBalances.ts`, con paridad contra `GroupBalanceService` de la app).
 *
 * Añadir un gasto, saldar e invitar siguen en el iPhone hasta que Jürgen decida cómo escribe la web en Grupos.
 */
import { useCallback, useEffect, useState } from "react";
import { texts } from "../i18n";
import { ApiError, getJson, type Banda, type Dinero, type GrupoDetalle, type GrupoTarjeta, type GruposLista } from "./api";
import { badge, money, shortDate } from "./format";

const t = texts();

/** El nombre que se enseña: el de quien borró su cuenta llega como marca y se traduce, como `resolvedDisplayName`. */
export function who(n: string): string {
  if (n === "__deleted_user__") return t.grp.usuarioEliminado;
  return n || t.grp.sinNombre;
}

function joinMoney(list: Dinero[]): string {
  return list.map((d) => money(d.importe, d.divisa)).join(" · ");
}

function BandLine({ banda }: { banda: Banda }) {
  if (banda.estado === "settled") return <span className="amt">{t.grp.todoSaldado}</span>;
  return (
    <span className="band-l">
      {banda.teDeben.length > 0 ? <span className="amt owed">{t.grp.teDeben(joinMoney(banda.teDeben))}</span> : null}
      {banda.debes.length > 0 ? <span className="amt owe">{t.grp.debes(joinMoney(banda.debes))}</span> : null}
    </span>
  );
}

function Skeleton() {
  return (
    <div className="cd" aria-busy="true">
      <div className="skel" style={{ width: "40%" }} />
      <div className="skel" />
      <div className="skel" style={{ width: "70%" }} />
    </div>
  );
}

function Failed({ message, retry }: { message: string; retry?: () => void }) {
  return (
    <div className="cd">
      <p className="empty">{message}</p>
      {retry ? (
        <button className="btn-s" type="button" onClick={retry}>
          {t.app.reintentar}
        </button>
      ) : null}
    </div>
  );
}

function GroupCard({ g, onOpen }: { g: GrupoTarjeta; onOpen: () => void }) {
  const b = badge(g.nombre);
  const shown = g.personas.slice(0, 3);
  const rest = g.personas.length - shown.length;
  return (
    <button className="cd gcard" type="button" onClick={onOpen} aria-label={g.nombre || t.grp.sinNombre}>
      <span className="row" style={{ borderTop: 0, padding: 0 }}>
        <span className="ic" style={{ background: g.color && /^#[0-9a-f]{6}$/i.test(g.color) ? g.color : b.color }} aria-hidden="true">
          {b.letter}
        </span>
        <span className="t">
          <b>
            {g.nombre || t.grp.sinNombre}
            {g.archivado ? <span className="lk arch">{t.grp.archivado}</span> : null}
          </b>
          <span>{[t.grp.personas(g.miembros), t.grp.nGastos(g.gastos)].join(" · ")}</span>
        </span>
        <BandLine banda={g.banda} />
      </span>
      {shown.length > 0 ? (
        <span className="gpeople">
          {shown.map((p, i) => (
            <span className="gp" key={i}>
              <span>{p.sentido === "debes" ? t.grp.leDebes(who(p.nombre)) : t.grp.teDebe(who(p.nombre))}</span>
              <span className={`amt ${p.sentido === "debes" ? "owe" : "owed"}`}>{money(p.importe, p.divisa)}</span>
            </span>
          ))}
          {rest > 0 ? <span className="gp more">{t.grp.yMas(rest)}</span> : null}
        </span>
      ) : null}
    </button>
  );
}

function List({ onOpen }: { onOpen: (id: string) => void }) {
  const [data, setData] = useState<GruposLista | null>(null);
  const [error, setError] = useState(false);
  const load = useCallback(() => {
    setError(false);
    getJson<GruposLista>("/api/grupos").then(setData, () => setError(true));
  }, []);
  useEffect(load, [load]);

  if (error) return <Failed message={t.grp.noDisponible} retry={load} />;
  if (!data) return <Skeleton />;
  const { resumen, grupos } = data;
  const settled = resumen.teDeben.length === 0 && resumen.debes.length === 0;
  return (
    <>
      <section className="cd hero">
        <span className="cap">{t.grp.enTusGrupos}</span>
        {settled ? <span className="big">{t.grp.todoSaldado}</span> : null}
        {resumen.teDeben.length > 0 ? <span className="big amt owed">{t.grp.teDeben(joinMoney(resumen.teDeben))}</span> : null}
        {resumen.debes.length > 0 ? <span className={`${resumen.teDeben.length > 0 ? "mid" : "big"} amt owe`}>{t.grp.debes(joinMoney(resumen.debes))}</span> : null}
        {resumen.pagosPorConfirmar > 0 ? <span className="inout">{t.grp.pagosPorConfirmar(resumen.pagosPorConfirmar)}</span> : null}
      </section>
      {grupos.length === 0 ? (
        <section className="cd">
          <h2>{t.grp.sinGrupos}</h2>
          <p className="empty">{t.grp.sinGruposNota}</p>
        </section>
      ) : (
        <div className="ggrid">
          {grupos.map((g) => (
            <GroupCard key={g.id} g={g} onOpen={() => onOpen(g.id)} />
          ))}
        </div>
      )}
      {data.incompleto ? <p className="note-y">{t.grp.incompleto}</p> : null}
      <p className="note-y">{t.grp.nota}</p>
    </>
  );
}

type Tab = "saldos" | "gastos" | "pagos";

function Detail({ id, onBack }: { id: string; onBack: () => void }) {
  const [data, setData] = useState<GrupoDetalle | null>(null);
  const [error, setError] = useState<"no_existe" | "otro" | null>(null);
  const [tab, setTab] = useState<Tab>("saldos");
  const load = useCallback(() => {
    setError(null);
    getJson<GrupoDetalle>(`/api/grupos/detalle?id=${encodeURIComponent(id)}`).then(setData, (err) =>
      setError(err instanceof ApiError && err.status === 404 ? "no_existe" : "otro"),
    );
  }, [id]);
  useEffect(load, [load]);

  const back = (
    <button className="btn-s back" type="button" onClick={onBack}>
      ‹ {t.grp.volver}
    </button>
  );
  if (error) return (
    <>
      {back}
      <Failed message={error === "no_existe" ? t.grp.noExiste : t.grp.noDisponible} retry={error === "otro" ? load : undefined} />
    </>
  );
  if (!data) return (
    <>
      {back}
      <Skeleton />
    </>
  );
  const name = (n: string, esTu: boolean) => (esTu ? t.grp.tu : who(n));
  const opts = [data.menosPagos ? t.grp.menosPagos : null, data.unaSolaMoneda ? t.grp.todoEn(data.unaSolaMoneda) : null].filter(Boolean).join(" · ");
  return (
    <>
      {back}
      <section className="cd hero">
        <span className="cap">
          {data.nombre || t.grp.sinNombre}
          {data.archivado ? <span className="lk arch">{t.grp.archivado}</span> : null}
        </span>
        {data.banda.estado === "settled" ? <span className="big">{t.grp.todoSaldado}</span> : null}
        {data.banda.teDeben.length > 0 ? <span className="big amt owed">{t.grp.teDeben(joinMoney(data.banda.teDeben))}</span> : null}
        {data.banda.debes.length > 0 ? (
          <span className={`${data.banda.teDeben.length > 0 ? "mid" : "big"} amt owe`}>{t.grp.debes(joinMoney(data.banda.debes))}</span>
        ) : null}
        <span className="inout">{[t.grp.personas(data.miembros.length), opts].filter(Boolean).join(" · ")}</span>
      </section>

      <div className="seg seg3" role="group" aria-label={data.nombre}>
        {(["saldos", "gastos", "pagos"] as const).map((x) => (
          <button key={x} type="button" aria-pressed={tab === x} onClick={() => setTab(x)}>
            {t.grp[x]}
          </button>
        ))}
      </div>

      {tab === "saldos" ? (
        <>
          <section className="cd">
            <h2>{t.grp.quienDebe}</h2>
            {data.deudas.length === 0 ? <p className="empty">{t.grp.nadieDebe}</p> : null}
            {data.deudas.map((d, i) => (
              <div className="row" key={i}>
                <span className="t">
                  <b>
                    {name(d.de, d.deTi)} → {name(d.a, d.aTi)}
                  </b>
                </span>
                <span className={`amt${d.deTi ? " owe" : d.aTi ? " owed" : ""}`}>{money(d.importe, d.divisa)}</span>
              </div>
            ))}
          </section>
          <section className="cd">
            <h2>{t.grp.porPersona}</h2>
            <div className="tbl" role="table">
              <div className="tr th" role="row">
                <span role="columnheader">{t.grp.miembros}</span>
                <span role="columnheader">{t.grp.pago}</span>
                <span role="columnheader">{t.grp.leToca}</span>
                <span role="columnheader">{t.grp.saldo}</span>
              </div>
              {data.saldos.map((s, i) => (
                <div className="tr" role="row" key={i}>
                  <span role="cell">{name(s.nombre, s.esTu)}</span>
                  <span role="cell" className="amt">{money(s.pago, s.divisa)}</span>
                  <span role="cell" className="amt">{money(s.leToca, s.divisa)}</span>
                  <span role="cell" className={`amt${s.neto > 0.005 ? " owed" : s.neto < -0.005 ? " owe" : ""}`}>{money(s.neto, s.divisa, { sign: true })}</span>
                </div>
              ))}
            </div>
          </section>
          <section className="cd">
            <h2>{t.grp.miembros}</h2>
            {data.miembros.map((m, i) => (
              <div className="row" key={i}>
                <span className="t">
                  <b>{name(m.nombre, m.esTu)}</b>
                </span>
                {m.rol === "admin" || m.rol === "owner" ? <span className="src">{t.grp.admin}</span> : null}
              </div>
            ))}
          </section>
        </>
      ) : null}

      {tab === "gastos" ? (
        <section className="cd">
          {data.gastos.length === 0 ? <p className="empty">{t.grp.sinGastos}</p> : null}
          {data.gastos.map((g) => {
            const b = badge(g.categoria ?? g.descripcion);
            const extra = [g.saldoInicial ? t.grp.saldoInicial : null, g.saldado ? t.grp.saldado : null].filter(Boolean);
            return (
              <div className="row" key={g.id}>
                <span className="ic" style={{ background: b.color }} aria-hidden="true">
                  {b.letter}
                </span>
                <span className="t">
                  <b>{g.descripcion || g.categoria || t.app.gasto}</b>
                  <span>{[g.pagasteTu ? t.grp.pagasteTu : t.grp.pagadoPor(who(g.pagadoPor)), shortDate(g.fecha), ...extra].filter(Boolean).join(" · ")}</span>
                </span>
                <span className="amt-col">
                  <span className="amt">{money(g.importe, g.divisa)}</span>
                  <small>{g.tuParte !== null ? t.grp.tuParte(money(g.tuParte, g.divisa)) : t.grp.noParticipas}</small>
                </span>
              </div>
            );
          })}
        </section>
      ) : null}

      {tab === "pagos" ? (
        <section className="cd">
          {data.pagos.length === 0 ? <p className="empty">{t.grp.sinPagos}</p> : null}
          {data.pagos.map((p) => (
            <div className="row" key={p.id}>
              <span className="t">
                <b>
                  {name(p.de, p.deTi)} → {name(p.a, p.aTi)}
                </b>
                <span>{[shortDate(p.fecha), p.nota, p.confirmado ? null : t.grp.porConfirmar].filter(Boolean).join(" · ")}</span>
              </span>
              <span className={`amt${p.deTi ? " owe" : p.aTi ? " owed" : ""}`}>{money(p.importe, p.divisa)}</span>
            </div>
          ))}
        </section>
      ) : null}

      {data.incompleto ? <p className="note-y">{t.grp.grupoIncompleto}</p> : null}
      <p className="note-y">{t.grp.nota}</p>
    </>
  );
}

export function Grupos() {
  const [open, setOpen] = useState<string | null>(null);
  if (open) return <Detail id={open} onBack={() => setOpen(null)} />;
  return (
    <List
      onOpen={(id) => {
        setOpen(id);
        window.scrollTo(0, 0);
      }}
    />
  );
}

/** Lo que ve una cuenta «solo Grupos» en las secciones de la nube completa (lote 3, decisión D3). */
export function SoloGrupos({ onGroups }: { onGroups: () => void }) {
  return (
    <section className="cd">
      <h2>{t.app.soloGruposTitulo}</h2>
      <p className="empty">{t.app.soloGruposCuerpo}</p>
      <button className="btn-p" type="button" onClick={onGroups}>
        {t.app.irAGrupos}
      </button>
    </section>
  );
}
