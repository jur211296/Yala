/**
 * Yala web: entrar y, con sesión, la app (`app/Shell.tsx`, lote 1). La página solo pinta: no ve ningún token (la cookie
 * es `HttpOnly`) y todo lo que sabe se lo pregunta al Worker en `/api/*`.
 */
import { useEffect, useRef, useState, type ReactNode } from "react";
import { Smartphone } from "lucide-react";
import { lang, texts, privacyUrl, turnstileLang } from "./i18n";
import { Shell } from "./app/Shell";
import { QrLogin } from "./QrLogin";
import { temaEsOscuro } from "./tema";

interface Me {
  nombre: string;
  correo: string | null;
  equipoCompartido: boolean;
  soloGrupos?: boolean;
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
const PRIVACY_URL = privacyUrl();

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

  if (state.kind === "dentro" && !aviso) return <Shell me={state.me} />;
  // Quien escanea el QR con la cámara del iPhone (y no desde Yala) llega aquí: se le explica dónde leerlo.
  if (window.location.pathname.startsWith("/v/")) {
    return (
      <Entrada>
        <h1 className="e-titulo">{t.qr.titulo}</h1>
        <p className="e-sub">{t.qr.pasos}</p>
        <a className="e-btn" href="/">
          {t.qr.volver}
        </a>
      </Entrada>
    );
  }

  return (
    <Entrada>
      {aviso === "sin-nube" ? (
        <SinNube titulo={t.sinNubeTitulo} cuerpo={t.sinNube} como={t.sinNubeComo} />
      ) : aviso === "solo-grupos" ? (
        <SinNube titulo={t.soloGruposTitulo} cuerpo={t.soloGrupos} />
      ) : (
        <>
          {aviso && Object.hasOwn(t.avisos, aviso) ? (
            <p className={`e-aviso ${aviso === "salida" ? "ok" : ""}`} role="status">
              {t.avisos[aviso]}
            </p>
          ) : null}
          {state.kind === "cargando" ? <p className="e-sub">{t.cargando}</p> : null}
          {state.kind === "no-disponible" ? <p className="e-aviso">{t.noDisponible}</p> : null}
          {state.kind === "fuera" ? <Login siteKey={state.siteKey} /> : null}
          {state.kind === "dentro" ? <Shell me={state.me} /> : null}
        </>
      )}
    </Entrada>
  );
}

/**
 * La entrada de Yala web: el logo oficial sobre una tarjeta, con el tema de la web (claro u oscuro según el sistema, o
 * el elegido en Ajustes) y el estilo del resto de la app web. Desde el 17-nov ya no copia la bienvenida de iOS.
 */
function Entrada({ children }: { children: ReactNode }) {
  return (
    <main className="entrada">
      <div className="e-caja">
        <span className="e-logo" role="img" aria-label="Yala" />
        {children}
      </div>
    </main>
  );
}

function SinNube({ titulo, cuerpo, como }: { titulo: string; cuerpo: string; como?: string }) {
  return (
    <>
      <h1 className="e-titulo">{titulo}</h1>
      <p className="e-sub">{cuerpo}</p>
      {como ? <p className="e-nota">{como}</p> : null}
      <a className="e-btn" href="/">
        {t.volver}
      </a>
    </>
  );
}

/** La manzana de Apple, en el color del texto del botón (como `apple.logo` en la app). */
function LogoApple() {
  return (
    <svg className="e-ico" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
      <path
        fill="currentColor"
        d="M16.37 12.73c-.02-2.28 1.86-3.38 1.95-3.43-1.06-1.55-2.71-1.77-3.3-1.79-1.4-.14-2.74.83-3.45.83-.71 0-1.8-.81-2.97-.79-1.53.02-2.94.89-3.72 2.26-1.59 2.76-.41 6.84 1.14 9.08.76 1.1 1.66 2.33 2.84 2.28 1.14-.05 1.57-.74 2.95-.74 1.37 0 1.76.74 2.97.71 1.23-.02 2-1.11 2.75-2.21.87-1.27 1.22-2.5 1.24-2.57-.03-.01-2.38-.91-2.4-3.63ZM14.12 6.04c.63-.76 1.05-1.82.94-2.87-.9.04-2 .6-2.65 1.36-.58.67-1.09 1.75-.95 2.78 1.01.08 2.03-.51 2.66-1.27Z"
      />
    </svg>
  );
}

/** La «G» de Google en sus cuatro colores: la guía de marca no deja recolorearla (como `GoogleG` en la app). */
function LogoGoogle() {
  return (
    <svg className="e-ico" viewBox="0 0 48 48" aria-hidden="true" focusable="false">
      <path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.4-.4-3.5Z" />
      <path fill="#FF3D00" d="m6.3 14.7 6.6 4.8C14.7 15.1 19 12 24 12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 16.3 4 9.7 8.3 6.3 14.7Z" />
      <path fill="#4CAF50" d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2A11.9 11.9 0 0 1 24 36c-5.2 0-9.6-3.3-11.3-7.9l-6.5 5C9.5 39.6 16.2 44 24 44Z" />
      <path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3a12 12 0 0 1-4.1 5.6l6.2 5.2C37 39.2 44 34 44 24c0-1.3-.1-2.4-.4-3.5Z" />
    </svg>
  );
}

function Login({ siteKey }: { siteKey: string }) {
  const [round, setRound] = useState(0);
  const [qr, setQr] = useState<{ token: string; compartido: boolean } | null>(null);
  if (qr) return <QrLogin turnstile={qr.token} compartido={qr.compartido} onBack={() => (setQr(null), setRound((r) => r + 1))} />;
  return <SsoLogin key={round} siteKey={siteKey} onQr={(token, compartido) => setQr({ token, compartido })} />;
}

function SsoLogin({ siteKey, onQr }: { siteKey: string; onQr: (token: string, compartido: boolean) => void }) {
  const widget = useRef<HTMLDivElement>(null);
  const shared = useRef<HTMLInputElement>(null);
  const [token, setToken] = useState<string | null>(null);

  useEffect(() => {
    let id: string | null = null;
    const render = () => {
      if (!widget.current || !window.turnstile || id) return;
      id = window.turnstile.render(widget.current, {
        sitekey: siteKey,
        language: turnstileLang(),
        appearance: "interaction-only",
        // El reto sigue al tema de la página («auto» solo mira al sistema y no ve el tema elegido en Ajustes).
        theme: temaEsOscuro() ? "dark" : "light",
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
    <form method="post" action="/auth/start" className="e-login">
      <h1 className="e-titulo">{t.titulo}</h1>
      <p className="e-sub">{t.subtitulo}</p>
      <input type="hidden" name="cf-turnstile-response" value={token ?? ""} />
      <div className="e-botones">
        <button className="e-btn" type="submit" name="provider" value="apple" disabled={!token}>
          <LogoApple />
          {t.apple}
        </button>
        <button className="e-btn" type="submit" name="provider" value="google" disabled={!token}>
          <LogoGoogle />
          {t.google}
        </button>
        <p className="e-o" aria-hidden="true">
          {t.qr.otraForma}
        </p>
        <button className="e-btn" type="button" disabled={!token} onClick={() => token && onQr(token, shared.current?.checked === true)}>
          <Smartphone className="e-ico" aria-hidden="true" />
          {t.qr.entrarConIphone}
        </button>
      </div>
      <div ref={widget} className="e-turnstile" />
      {!token ? <p className="e-fade">{t.esperandoVerificacion}</p> : null}
      <label className="e-check">
        <input ref={shared} type="checkbox" name="compartido" value="1" />
        {t.compartido}
      </label>
      <p className="e-fade">
        {t.protegido}{" "}
        <a href={PRIVACY_URL} target="_blank" rel="noreferrer">
          {t.politica}
        </a>
        .
      </p>
    </form>
  );
}
