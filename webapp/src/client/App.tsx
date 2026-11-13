/**
 * Yala web, lote 0: entrar, ver de quién es la sesión y salir. La página solo pinta: no ve ningún token (la cookie es
 * `HttpOnly`) y todo lo que sabe se lo pregunta al Worker en `/api/*`.
 */
import { useEffect, useRef, useState } from "react";
import { lang, texts } from "./i18n";

interface Me {
  nombre: string;
  correo: string | null;
  equipoCompartido: boolean;
}

type State =
  | { kind: "cargando" }
  | { kind: "fuera"; siteKey: string }
  | { kind: "dentro"; me: Me }
  | { kind: "no-disponible" };

declare global {
  interface Window {
    turnstile?: {
      render: (el: HTMLElement, opts: Record<string, unknown>) => string;
      remove: (id: string) => void;
    };
  }
}

const t = texts();
const PRIVACY_URL = lang() === "en" ? "https://yala-app.pe/en/privacy" : "https://yala-app.pe/privacy";

/** El aviso con el que el Worker devolvió aquí, si lo hay. Se lee una vez y se quita de la dirección. */
function takeAviso(): string | null {
  const url = new URL(window.location.href);
  const aviso = url.searchParams.get("aviso");
  if (aviso) {
    url.searchParams.delete("aviso");
    window.history.replaceState(null, "", url.pathname + url.search);
  }
  return aviso;
}

async function load(): Promise<State> {
  try {
    const me = await fetch("/api/me", { credentials: "same-origin", cache: "no-store" });
    if (me.ok) return { kind: "dentro", me: (await me.json()) as Me };
    if (me.status !== 401) return { kind: "no-disponible" };
    const cfg = await fetch("/api/config", { cache: "no-store" });
    if (!cfg.ok) return { kind: "no-disponible" };
    const { turnstileSiteKey } = (await cfg.json()) as { turnstileSiteKey: string };
    return { kind: "fuera", siteKey: turnstileSiteKey };
  } catch {
    return { kind: "no-disponible" };
  }
}

export function App() {
  const [aviso] = useState(takeAviso);
  const [state, setState] = useState<State>({ kind: "cargando" });

  useEffect(() => {
    document.documentElement.lang = lang();
    void load().then(setState);
  }, []);

  return (
    <main className="shell">
      <div className="card">
        <div className="brand" aria-hidden="true">
          <i />
          Yala
        </div>
        {aviso === "sin-nube" ? (
          <SinNube titulo={t.sinNubeTitulo} cuerpo={t.sinNube} como={t.sinNubeComo} />
        ) : aviso === "solo-grupos" ? (
          <SinNube titulo={t.soloGruposTitulo} cuerpo={t.soloGrupos} />
        ) : (
          <>
            {aviso && Object.hasOwn(t.avisos, aviso) ? (
              <p className={`aviso ${aviso === "salida" ? "ok" : ""}`} role="status">
                {t.avisos[aviso]}
              </p>
            ) : null}
            {state.kind === "cargando" ? <p className="muted">{t.cargando}</p> : null}
            {state.kind === "no-disponible" ? <p className="aviso">{t.noDisponible}</p> : null}
            {state.kind === "fuera" ? <Login siteKey={state.siteKey} /> : null}
            {state.kind === "dentro" ? <Dentro me={state.me} /> : null}
          </>
        )}
      </div>
    </main>
  );
}

function SinNube({ titulo, cuerpo, como }: { titulo: string; cuerpo: string; como?: string }) {
  return (
    <>
      <h1>{titulo}</h1>
      <p className="muted">{cuerpo}</p>
      {como ? <p className="note">{como}</p> : null}
      <a className="btn" href="/">
        {t.volver}
      </a>
    </>
  );
}

function Login({ siteKey }: { siteKey: string }) {
  const widget = useRef<HTMLDivElement>(null);
  const [token, setToken] = useState<string | null>(null);

  useEffect(() => {
    let id: string | null = null;
    const render = () => {
      if (!widget.current || !window.turnstile || id) return;
      id = window.turnstile.render(widget.current, {
        sitekey: siteKey,
        language: lang(),
        appearance: "interaction-only",
        callback: (tok: string) => setToken(tok),
        "expired-callback": () => setToken(null),
        "error-callback": () => setToken(null),
      });
    };
    if (window.turnstile) render();
    else {
      const s = document.createElement("script");
      s.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
      s.async = true;
      s.onload = render;
      document.head.appendChild(s);
    }
    return () => {
      if (id && window.turnstile) window.turnstile.remove(id);
    };
  }, [siteKey]);

  return (
    <form method="post" action="/auth/start" className="login">
      <h1>{t.titulo}</h1>
      <p className="muted">{t.subtitulo}</p>
      <input type="hidden" name="cf-turnstile-response" value={token ?? ""} />
      <button className="btn dark" type="submit" name="provider" value="apple" disabled={!token}>
        {t.apple}
      </button>
      <button className="btn" type="submit" name="provider" value="google" disabled={!token}>
        {t.google}
      </button>
      <div ref={widget} className="turnstile" />
      {!token ? <p className="fade">{t.esperandoVerificacion}</p> : null}
      <label className="check">
        <input type="checkbox" name="compartido" value="1" />
        {t.compartido}
      </label>
      <p className="fade">
        {t.protegido}{" "}
        <a href={PRIVACY_URL} target="_blank" rel="noreferrer">
          {t.politica}
        </a>
        .
      </p>
    </form>
  );
}

function Dentro({ me }: { me: Me }) {
  return (
    <form method="post" action="/auth/logout" className="login">
      <h1>{t.hola(me.nombre)}</h1>
      <p className="muted">{t.dentro}</p>
      {me.correo ? (
        <div className="kv">
          <span>{t.cuenta}</span>
          <span>{me.correo}</span>
        </div>
      ) : null}
      {me.equipoCompartido ? <p className="note">{t.equipoCompartido}</p> : null}
      <button className="btn" type="submit">
        {t.salir}
      </button>
    </form>
  );
}
