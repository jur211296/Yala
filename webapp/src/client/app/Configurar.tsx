/**
 * Configurar en la beta: la cuenta, las sesiones web (cerrar las demás), ocultar montos al abrir, el idioma y salir.
 * Lo demás (categorías, cuentas, divisas, avisos, Pro) se cambia en el iPhone.
 */
import { useCallback, useEffect, useState } from "react";
import { chosenLang, setChosenLang, texts, type Lang } from "../i18n";
import { getJson, postJson, type Sesion } from "./api";
import { ago } from "./format";
import { readHidePref, writeHidePref, type Me } from "./Shell";

const t = texts();

function sessionTitle(s: Sesion): string {
  return t.app.en(s.navegador || t.app.navegador, s.sistema);
}

function sessionLine(s: Sesion): string {
  return [s.ciudad, ago(s.ultimoUso), s.equipoCompartido ? t.app.equipoCompartidoCorto : null].filter(Boolean).join(" · ");
}

export function Configurar({ me, onToast }: { me: Me; onToast: (msg: string) => void }) {
  const [sesiones, setSesiones] = useState<Sesion[] | null>(null);
  const [error, setError] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);
  const [hideOnOpen, setHideOnOpen] = useState(readHidePref);
  const [idioma, setIdioma] = useState<Lang | "">(chosenLang() ?? "");

  const load = useCallback(() => {
    setError(false);
    getJson<{ sesiones: Sesion[] }>("/api/sesiones").then((r) => setSesiones(r.sesiones), () => setError(true));
  }, []);
  useEffect(load, [load]);

  const close = async (id: string | null) => {
    setBusy(id ?? "todas");
    try {
      if (id) await postJson("/api/sesiones/cerrar", { id });
      else await postJson("/api/sesiones/cerrar-otras", {});
      onToast(t.app.cerradaToast);
      load();
    } catch {
      setError(true);
    } finally {
      setBusy(null);
    }
  };

  const others = (sesiones ?? []).filter((s) => !s.esta);
  const mine = (sesiones ?? []).find((s) => s.esta);

  return (
    <>
      <section className="cd">
        <h2>{t.app.tuCuenta}</h2>
        {me.nombre ? (
          <div className="kv">
            <span>{t.app.nombre}</span>
            <span>{me.nombre}</span>
          </div>
        ) : null}
        {me.correo ? (
          <div className="kv">
            <span>{t.app.correo}</span>
            <span>{me.correo}</span>
          </div>
        ) : null}
        <div className="kv">
          <span>{t.app.datos}</span>
          <span>{t.app.datosValor}</span>
        </div>
        {me.equipoCompartido ? <p className="note-y">{t.equipoCompartido}</p> : null}
      </section>

      <section className="cd" aria-busy={sesiones === null}>
        <h2>{t.app.sesiones}</h2>
        {error ? <p className="err">{t.app.noCargo}</p> : null}
        {sesiones === null && !error ? <div className="skel" /> : null}
        {mine ? (
          <div className="dev">
            <div className="t">
              <b>
                {t.app.estaSesion} · {sessionTitle(mine)}
              </b>
              <span>{sessionLine(mine)}</span>
            </div>
          </div>
        ) : null}
        {others.map((s) => (
          <div className="dev" key={s.id}>
            <div className="t">
              <b>{sessionTitle(s)}</b>
              <span>{sessionLine(s)}</span>
            </div>
            <button className="danger" type="button" disabled={busy !== null} onClick={() => void close(s.id)}>
              {t.app.cerrarSesion}
            </button>
          </div>
        ))}
        {sesiones && others.length === 0 ? <p className="empty">{t.app.soloEsta}</p> : null}
        {others.length > 1 ? (
          <div className="kv">
            <span />
            <button className="danger" type="button" disabled={busy !== null} onClick={() => void close(null)}>
              {t.app.cerrarLasDemas}
            </button>
          </div>
        ) : null}
        <p className="note-y">{t.app.sesionesNota}</p>
      </section>

      <section className="cd">
        <h2>{t.app.enEstaWeb}</h2>
        <label className="kv">
          <span>{t.app.ocultarAlAbrir}</span>
          <input
            className="sw"
            type="checkbox"
            role="switch"
            checked={hideOnOpen}
            onChange={(e) => {
              setHideOnOpen(e.target.checked);
              writeHidePref(e.target.checked);
            }}
          />
        </label>
        <div className="kv">
          <span>{t.app.tema}</span>
          <span>{t.app.temaValor}</span>
        </div>
        <label className="kv">
          <span>{t.app.idioma}</span>
          <select
            value={idioma}
            onChange={(e) => {
              const v = e.target.value as Lang | "";
              setIdioma(v);
              setChosenLang(v || null);
              window.location.reload();
            }}
          >
            <option value="">{t.app.idiomaAuto}</option>
            <option value="es">Español</option>
            <option value="en">English</option>
          </select>
        </label>
        <p className="note-y">{t.app.configurarNota}</p>
      </section>

      <form method="post" action="/auth/logout">
        <button className="btn-p" type="submit" style={{ width: "100%" }}>
          {t.app.salirDeYala}
        </button>
      </form>
    </>
  );
}
