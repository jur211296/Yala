/**
 * Ajustes (antes «Configurar») en la beta: la cuenta, las sesiones web (cerrar las demás), ocultar montos al abrir, el
 * tema (Como el sistema, Claro, Oscuro o Liquid Glass; lote 1 de «Yala web como la app»), el idioma (los 16 de la app,
 * lote 2b) y salir. Lo demás (categorías, cuentas, divisas, avisos, Pro) se cambia en el iPhone.
 *
 * Lote 5 de «Yala web como la app» (decisión D8): se llama «Ajustes», como en la app, y su dirección sigue siendo
 * `/configurar`. Arriba el avatar grande con el nombre y el correo; debajo, grupos de filas con el cuadrito de color e
 * ícono de los Ajustes de iOS, en una columna de 700 px (el ancho legible de la app).
 */
import { useCallback, useEffect, useState, type ReactNode } from "react";
import { Cloud, EyeOff, Globe, Languages, LogOut, Mail, Monitor, Palette, UserRound } from "lucide-react";
import { chosenLang, LANGS, setChosenLang, texts, type Lang } from "../i18n";
import { aplicarTema, guardarTema, temaElegido, TEMAS, type Tema } from "../tema";
import { getJson, postJson, type Sesion } from "./api";
import { ago } from "./format";
import { readHidePref, writeHidePref, type Me } from "./Shell";

const t = texts();

/** El cuadrito de color con su ícono, como las filas de Ajustes de la app. */
function Cuadro({ color, children }: { color: string; children: ReactNode }) {
  return (
    <span className="aj-sq" style={{ background: color }} aria-hidden="true">
      {children}
    </span>
  );
}
const I = { "aria-hidden": true, focusable: false } as const;

const TEMA_NOMBRE: Record<Tema, string> = { sistema: t.app.temaValor, claro: t.app.temaClaro, oscuro: t.app.temaOscuro, liquid: t.app.temaLiquid };

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
  const [tema, setTema] = useState<Tema>(temaElegido);

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
    <div className="ajustes">
      <section className="aj-perfil" aria-label={t.app.tuCuenta}>
        <span className="av grande">
          <UserRound {...I} />
        </span>
        {me.nombre ? <b>{me.nombre}</b> : null}
        {me.correo ? <span>{me.correo}</span> : null}
      </section>

      <section aria-labelledby="aj-cuenta">
        <h2 className="aj-h" id="aj-cuenta">
          {t.app.tuCuenta}
        </h2>
        <div className="aj-grupo">
          {me.nombre ? (
            <div className="aj-fila">
              <Cuadro color="#0A84FF">
                <UserRound {...I} />
              </Cuadro>
              <span className="aj-t">{t.app.nombre}</span>
              <span className="aj-v">{me.nombre}</span>
            </div>
          ) : null}
          {me.correo ? (
            <div className="aj-fila">
              <Cuadro color="#0A84FF">
                <Mail {...I} />
              </Cuadro>
              <span className="aj-t">{t.app.correo}</span>
              <span className="aj-v">{me.correo}</span>
            </div>
          ) : null}
          <div className="aj-fila">
            <Cuadro color="#32ADE6">
              <Cloud {...I} />
            </Cuadro>
            <span className="aj-t">{t.app.datos}</span>
            <span className="aj-v">{t.app.datosValor}</span>
          </div>
        </div>
        {me.equipoCompartido ? <p className="note-y">{t.equipoCompartido}</p> : null}
      </section>

      <section aria-labelledby="aj-sesiones" aria-busy={sesiones === null}>
        <h2 className="aj-h" id="aj-sesiones">
          {t.app.sesiones}
        </h2>
        <div className="aj-grupo">
          {error ? <p className="err aj-fila">{t.app.noCargo}</p> : null}
          {sesiones === null && !error ? (
            <div className="aj-fila">
              <div className="skel" />
            </div>
          ) : null}
          {mine ? (
            <div className="aj-fila">
              <Cuadro color="#30D158">
                <Monitor {...I} />
              </Cuadro>
              <span className="aj-t">
                <b>
                  {t.app.estaSesion} · {sessionTitle(mine)}
                </b>
                <span>{sessionLine(mine)}</span>
              </span>
            </div>
          ) : null}
          {others.map((s) => (
            <div className="aj-fila" key={s.id}>
              <Cuadro color="#8E8E93">
                <Globe {...I} />
              </Cuadro>
              <span className="aj-t">
                <b>{sessionTitle(s)}</b>
                <span>{sessionLine(s)}</span>
              </span>
              <button className="danger" type="button" disabled={busy !== null} onClick={() => void close(s.id)}>
                {t.app.cerrarSesion}
              </button>
            </div>
          ))}
          {sesiones && others.length === 0 ? <p className="aj-fila empty">{t.app.soloEsta}</p> : null}
          {others.length > 1 ? (
            <div className="aj-fila">
              <button className="danger aj-todo" type="button" disabled={busy !== null} onClick={() => void close(null)}>
                {t.app.cerrarLasDemas}
              </button>
            </div>
          ) : null}
        </div>
        <p className="aj-pie">{t.app.sesionesNota}</p>
      </section>

      <section aria-labelledby="aj-web">
        <h2 className="aj-h" id="aj-web">
          {t.app.enEstaWeb}
        </h2>
        <div className="aj-grupo">
          <label className="aj-fila">
            <Cuadro color="#5E5CE6">
              <EyeOff {...I} />
            </Cuadro>
            <span className="aj-t">{t.app.ocultarAlAbrir}</span>
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
          <label className="aj-fila">
            <Cuadro color="#BF5AF2">
              <Palette {...I} />
            </Cuadro>
            <span className="aj-t">{t.app.tema}</span>
            <select
              value={tema}
              onChange={(e) => {
                const v = e.target.value as Tema;
                setTema(v);
                guardarTema(v);
                aplicarTema(v);
              }}
            >
              {TEMAS.map((k) => (
                <option key={k} value={k}>
                  {TEMA_NOMBRE[k]}
                </option>
              ))}
            </select>
          </label>
          <label className="aj-fila">
            <Cuadro color="#FF9F0A">
              <Languages {...I} />
            </Cuadro>
            <span className="aj-t">{t.app.idioma}</span>
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
              {LANGS.map((l) => (
                <option key={l.code} value={l.code} lang={l.code}>
                  {l.name}
                </option>
              ))}
            </select>
          </label>
        </div>
        <p className="aj-pie">{t.app.configurarNota}</p>
      </section>

      <form method="post" action="/auth/logout" className="aj-grupo">
        <button className="aj-fila aj-salir" type="submit">
          <Cuadro color="#FF453A">
            <LogOut {...I} />
          </Cuadro>
          <span className="aj-t">{t.app.salirDeYala}</span>
        </button>
      </form>
    </div>
  );
}
