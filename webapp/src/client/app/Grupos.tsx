/**
 * Grupos (lote 3): la lista con lo que te deben y lo que debes, y el detalle de cada grupo con quién le debe a quién,
 * los saldos por persona, los gastos y los pagos. Las cifras salen del núcleo compartido
 * (`shared-core/src/logic/groupBalances.ts`, con paridad contra `GroupBalanceService` de la app).
 *
 * Escribir (opción A de Jürgen, 14-nov; solo staging): «Nuevo gasto» con reparto igual, «Saldar» y «Invitar». Lo hace el
 * gateway con el rol propio de la web (`webapp/src/worker/groupsWrite.ts`); el reparto que se enseña es el mismo
 * `equalSplit` que guarda, con paridad contra `GroupSplitCalculator`. Editar o borrar gastos, otros repartos y confirmar
 * pagos siguen en el iPhone.
 */
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { texts } from "../i18n";
import { ApiError, getJson, postJson, type Banda, type Dinero, type GrupoDetalle, type GrupoTarjeta, type GruposLista } from "./api";
import { badge, money, shortDate, todayKey } from "./format";
import { parseAmount } from "./Apuntar";
import { equalSplit } from "../../../../shared-core/src/logic/groupSplit";

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


// ─── Escribir (opción A) ───────────────────────────────────────────────────────────────────────────────────────

type Miembro = GrupoDetalle["miembros"][number];

/** El instante que se guarda: hoy, ahora; otro día, a mediodía local (no cambia de día en ningún huso cercano). */
function instantFor(day: string): string {
  if (day === todayKey()) return new Date().toISOString();
  return new Date(`${day}T12:00:00`).toISOString();
}

/** Un id por formulario abierto: si el envío se repite (red lenta, doble toque), el gateway no lo duplica. */
function useOnceId(): string {
  return useRef(crypto.randomUUID()).current;
}

function errorText(err: unknown): string {
  const body = err instanceof ApiError ? err.body : {};
  const key = body.error === "limite" ? "limite" : body.error === "no_permitido" ? String(body.motivo ?? "otro") : typeof body.campo === "string" ? body.campo : "otro";
  return t.grp.errores[key] ?? t.grp.errores.otro!;
}

function Sheet({ title, onClose, onSubmit, children }: { title: string; onClose: () => void; onSubmit?: () => void; children: React.ReactNode }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);
  return (
    <div className="modal" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <form
        className="sheet"
        role="dialog"
        aria-modal="true"
        aria-label={title}
        onSubmit={(e) => {
          e.preventDefault();
          onSubmit?.();
        }}
      >
        <h2>
          {title}
          <button className="btn-s" type="button" onClick={onClose}>
            {onSubmit ? t.app.cancelar : t.grp.cerrar}
          </button>
        </h2>
        {children}
      </form>
    </div>
  );
}

function AmountField({ divisa, divisas, setDivisa, value, onChange, inputRef }: {
  divisa: string;
  divisas: string[];
  setDivisa: (d: string) => void;
  value: string;
  onChange: (v: string) => void;
  inputRef: React.RefObject<HTMLInputElement | null>;
}) {
  return (
    <label className="amt-in">
      {divisas.length > 1 ? (
        <select className="amt-cur" value={divisa} onChange={(e) => setDivisa(e.target.value)} aria-label={t.grp.divisaCampo}>
          {divisas.map((d) => (
            <option key={d} value={d}>
              {d}
            </option>
          ))}
        </select>
      ) : (
        <span>{divisa}</span>
      )}
      <input ref={inputRef} inputMode="decimal" autoComplete="off" aria-label={t.app.importe} placeholder="0.00" value={value} onChange={(e) => onChange(e.target.value)} maxLength={16} />
    </label>
  );
}

function ExpenseSheet({ data, onClose, onDone }: { data: GrupoDetalle; onClose: () => void; onDone: (msg: string) => void }) {
  const id = useOnceId();
  const me = data.miembros.find((m) => m.esTu);
  const [importe, setImporte] = useState("");
  const [divisa, setDivisa] = useState(data.divisa ?? data.divisas[0] ?? "PEN");
  const [descripcion, setDescripcion] = useState("");
  const [pagadoPor, setPagadoPor] = useState(me?.clave ?? data.miembros[0]?.clave ?? "");
  const [fecha, setFecha] = useState(todayKey());
  const [entre, setEntre] = useState<string[]>(data.miembros.map((m) => m.clave));
  const [error, setError] = useState<string | null>(null);
  const [sending, setSending] = useState(false);
  const amountRef = useRef<HTMLInputElement>(null);
  useEffect(() => amountRef.current?.focus(), []);
  const n = parseAmount(importe);
  const ordered = data.miembros.filter((m) => entre.includes(m.clave)).map((m) => m.clave);
  const parts = useMemo(() => new Map((n && n > 0 ? equalSplit(n, ordered) ?? [] : []).map((p) => [p.member, p.amount])), [n, ordered.join("|")]);
  const label = (m: Miembro) => (m.esTu ? t.grp.tu : who(m.nombre));

  const send = async () => {
    if (n === null || n <= 0 || Math.abs(Math.round(n * 100) - n * 100) > 1e-6) return setError(t.grp.errores.importe!);
    if (!descripcion.trim()) return setError(t.grp.errores.descripcion!);
    if (ordered.length === 0) return setError(t.grp.errores.participantes!);
    setSending(true);
    setError(null);
    try {
      await postJson("/api/grupos/gasto", {
        grupo: data.id,
        id,
        descripcion: descripcion.trim(),
        importe: n,
        divisa,
        pagadoPor,
        fecha: instantFor(fecha),
        participantes: ordered,
      });
      onDone(t.grp.gastoHecho);
    } catch (err) {
      setError(errorText(err));
    } finally {
      setSending(false);
    }
  };

  return (
    <Sheet title={t.grp.nuevoGasto} onClose={onClose} onSubmit={() => void send()}>
      <AmountField divisa={divisa} divisas={data.divisas} setDivisa={setDivisa} value={importe} onChange={setImporte} inputRef={amountRef} />
      <label className="fld">
        <span>{t.app.descripcion}</span>
        <input value={descripcion} onChange={(e) => setDescripcion(e.target.value)} placeholder={t.app.descripcionPh} maxLength={120} required />
      </label>
      <label className="fld">
        <span>{t.grp.pagadoPorCampo}</span>
        <select value={pagadoPor} onChange={(e) => setPagadoPor(e.target.value)}>
          {data.miembros.map((m) => (
            <option key={m.clave} value={m.clave}>
              {label(m)}
            </option>
          ))}
        </select>
      </label>
      <label className="fld">
        <span>{t.app.fecha}</span>
        <input type="date" value={fecha} max={todayKey()} onChange={(e) => setFecha(e.target.value)} required />
      </label>
      <fieldset className="fld who-list">
        <legend>{t.grp.entre}</legend>
        {data.miembros.map((m) => {
          const on = entre.includes(m.clave);
          const part = parts.get(m.clave);
          return (
            <label className="who" key={m.clave}>
              <input type="checkbox" checked={on} onChange={() => setEntre((xs) => (on ? xs.filter((x) => x !== m.clave) : [...xs, m.clave]))} />
              <span className="t">{label(m)}</span>
              <span className="amt">{on && part !== undefined ? money(part, divisa) : ""}</span>
            </label>
          );
        })}
      </fieldset>
      <p className="note-y">{t.grp.soloIgual}</p>
      {error ? (
        <p className="err" role="alert">
          {error}
        </p>
      ) : null}
      <button className="btn-p" type="submit" disabled={sending}>
        {sending ? t.grp.guardando : t.grp.anadir}
      </button>
    </Sheet>
  );
}

export interface PagoInicial {
  de: string;
  a: string;
  importe: number;
  divisa: string;
}

function SettleSheet({ data, inicial, onClose, onDone }: { data: GrupoDetalle; inicial: PagoInicial | null; onClose: () => void; onDone: (msg: string) => void }) {
  const id = useOnceId();
  const me = data.miembros.find((m) => m.esTu);
  const other = data.miembros.find((m) => !m.esTu);
  const [de, setDe] = useState(inicial?.de ?? me?.clave ?? "");
  const [a, setA] = useState(inicial?.a ?? other?.clave ?? "");
  const [importe, setImporte] = useState(inicial ? inicial.importe.toFixed(2) : "");
  const [divisa, setDivisa] = useState(inicial?.divisa ?? data.divisa ?? data.divisas[0] ?? "PEN");
  const [fecha, setFecha] = useState(todayKey());
  const [nota, setNota] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [sending, setSending] = useState(false);
  const amountRef = useRef<HTMLInputElement>(null);
  useEffect(() => amountRef.current?.focus(), []);
  const label = (m: Miembro) => (m.esTu ? t.grp.tu : who(m.nombre));
  const nameOf = (k: string) => {
    const m = data.miembros.find((x) => x.clave === k);
    return m ? label(m) : "";
  };
  // `SettlementSaldar23Logic.confirmsOnRecord`: si no lo apunta ni quien paga ni quien recibe, espera a quien recibe.
  const pendiente = !!me && me.clave !== de && me.clave !== a;
  // Si la divisa del pago no está entre las del grupo (una deuda convertida), se añade para que el selector la enseñe.
  const divisas = data.divisas.includes(divisa) ? data.divisas : [...data.divisas, divisa];

  const send = async () => {
    const n = parseAmount(importe);
    if (n === null || n <= 0 || Math.abs(Math.round(n * 100) - n * 100) > 1e-6) return setError(t.grp.errores.importe!);
    if (!de || !a || de === a) return setError(t.grp.errores.personas!);
    setSending(true);
    setError(null);
    try {
      await postJson("/api/grupos/pago", { grupo: data.id, id, de, a, importe: n, divisa, fecha: instantFor(fecha), nota: nota.trim() });
      onDone(pendiente ? t.grp.pagoPendienteHecho(nameOf(a)) : t.grp.pagoHecho);
    } catch (err) {
      setError(errorText(err));
    } finally {
      setSending(false);
    }
  };

  return (
    <Sheet title={t.grp.saldar} onClose={onClose} onSubmit={() => void send()}>
      <label className="fld">
        <span>{t.grp.quienPaga}</span>
        <select value={de} onChange={(e) => setDe(e.target.value)}>
          {data.miembros.map((m) => (
            <option key={m.clave} value={m.clave}>
              {label(m)}
            </option>
          ))}
        </select>
      </label>
      <label className="fld">
        <span>{t.grp.aQuien}</span>
        <select value={a} onChange={(e) => setA(e.target.value)}>
          {data.miembros.map((m) => (
            <option key={m.clave} value={m.clave}>
              {label(m)}
            </option>
          ))}
        </select>
      </label>
      <AmountField divisa={divisa} divisas={divisas} setDivisa={setDivisa} value={importe} onChange={setImporte} inputRef={amountRef} />
      <label className="fld">
        <span>{t.app.fecha}</span>
        <input type="date" value={fecha} max={todayKey()} onChange={(e) => setFecha(e.target.value)} required />
      </label>
      <label className="fld">
        <span>{t.grp.notaOpcional}</span>
        <input value={nota} onChange={(e) => setNota(e.target.value)} maxLength={300} />
      </label>
      {pendiente && a ? <p className="note-y">{t.grp.pendienteDe(nameOf(a))}</p> : null}
      {error ? (
        <p className="err" role="alert">
          {error}
        </p>
      ) : null}
      <button className="btn-p" type="submit" disabled={sending}>
        {sending ? t.grp.guardando : t.grp.apuntarPago}
      </button>
    </Sheet>
  );
}

function InviteSheet({ data, onClose }: { data: GrupoDetalle; onClose: () => void }) {
  const [link, setLink] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const asked = useRef(false);
  useEffect(() => {
    if (asked.current) return;
    asked.current = true;
    postJson<{ enlace: string }>("/api/grupos/invitar", { grupo: data.id }).then((r) => setLink(r.enlace), (err) => setError(errorText(err)));
  }, [data.id]);
  const copy = async () => {
    if (!link) return;
    try {
      await navigator.clipboard.writeText(link);
      setCopied(true);
    } catch {
      setCopied(false);
    }
  };
  return (
    <Sheet title={t.grp.invitarTitulo} onClose={onClose}>
      <p className="empty">{t.grp.invitarCuerpo}</p>
      {error ? (
        <p className="err" role="alert">
          {error}
        </p>
      ) : link ? (
        <>
          <input className="link-in" readOnly value={link} aria-label={t.grp.invitarTitulo} onFocus={(e) => e.currentTarget.select()} />
          <p className="note-y">{t.grp.invitarComo}</p>
          <button className="btn-p" type="button" onClick={() => void copy()}>
            {copied ? t.grp.copiado : t.grp.copiar}
          </button>
        </>
      ) : (
        <p className="empty" aria-busy="true">
          {t.grp.generando}
        </p>
      )}
    </Sheet>
  );
}

type Abierto = { tipo: "gasto" } | { tipo: "pago"; inicial: PagoInicial | null } | { tipo: "invitar" } | null;

type Tab = "saldos" | "gastos" | "pagos";

function Detail({ id, onBack }: { id: string; onBack: () => void }) {
  const [data, setData] = useState<GrupoDetalle | null>(null);
  const [error, setError] = useState<"no_existe" | "otro" | null>(null);
  const [tab, setTab] = useState<Tab>("saldos");
  const [abierto, setAbierto] = useState<Abierto>(null);
  const [hecho, setHecho] = useState<string | null>(null);
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
  const done = (msg: string) => {
    setAbierto(null);
    setHecho(msg);
    load();
  };
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

      {data.puedeEscribir ? (
        <div className="gacts">
          <button className="btn-p" type="button" onClick={() => setAbierto({ tipo: "gasto" })}>
            {t.grp.nuevoGasto}
          </button>
          <button className="btn-s" type="button" onClick={() => setAbierto({ tipo: "pago", inicial: null })}>
            {t.grp.saldar}
          </button>
          {data.puedeInvitar ? (
            <button className="btn-s" type="button" onClick={() => setAbierto({ tipo: "invitar" })}>
              {t.grp.invitar}
            </button>
          ) : null}
        </div>
      ) : null}
      {hecho ? (
        <p className="ok-line" role="status">
          {hecho}
        </p>
      ) : null}

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
                {data.puedeEscribir ? (
                  <button
                    className="btn-s btn-xs"
                    type="button"
                    aria-label={`${t.grp.saldar}: ${name(d.de, d.deTi)} → ${name(d.a, d.aTi)}`}
                    onClick={() => setAbierto({ tipo: "pago", inicial: { de: d.deClave, a: d.aClave, importe: d.importe, divisa: d.divisa } })}
                  >
                    {t.grp.saldar}
                  </button>
                ) : null}
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
      <p className="note-y">{data.puedeEscribir ? t.grp.notaEscribe : t.grp.nota}</p>

      {abierto?.tipo === "gasto" ? <ExpenseSheet data={data} onClose={() => setAbierto(null)} onDone={done} /> : null}
      {abierto?.tipo === "pago" ? <SettleSheet data={data} inicial={abierto.inicial} onClose={() => setAbierto(null)} onDone={done} /> : null}
      {abierto?.tipo === "invitar" ? <InviteSheet data={data} onClose={() => setAbierto(null)} /> : null}
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
