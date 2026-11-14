/**
 * La app con sesión (lote 1): Panel, Bandeja, Registros y Configurar, con «Apuntar» y el ojo que oculta los montos.
 * Escritorio: barra lateral. Móvil: barra de pestañas con «+» en medio y «Más». Las secciones de los lotes siguientes
 * salen en la barra como «Pronto», sin abrir nada.
 *
 * La página pregunta `/api/me` cada 30 s y al volver a primer plano: si la sesión se cerró desde el iPhone o desde otra
 * pestaña, vuelve a la pantalla de entrar en menos de un minuto (lo que promete la maqueta).
 */
import { useCallback, useEffect, useState, type ReactNode } from "react";
import { texts } from "../i18n";
import { getJson, type Bandeja as BandejaData, type Categoria, type Panel as PanelData } from "./api";
import { Icons } from "./icons";
import { Panel } from "./Panel";
import { Registros } from "./Registros";
import { Bandeja } from "./Bandeja";
import { Configurar } from "./Configurar";
import { Apuntar } from "./Apuntar";

const t = texts();

export interface Me {
  nombre: string;
  correo: string | null;
  equipoCompartido: boolean;
}

type Sec = "panel" | "bandeja" | "registros" | "configurar" | "mas";
const SECTIONS: Sec[] = ["panel", "bandeja", "registros", "configurar", "mas"];
const HIDE_KEY = "yala-web-ocultar";

function secFromPath(): Sec {
  const p = window.location.pathname.replace(/^\/+|\/+$/g, "");
  return (SECTIONS as string[]).includes(p) ? (p as Sec) : "panel";
}

export function readHidePref(): boolean {
  try {
    return window.localStorage.getItem(HIDE_KEY) === "1";
  } catch {
    return false;
  }
}

export function writeHidePref(v: boolean): void {
  try {
    if (v) window.localStorage.setItem(HIDE_KEY, "1");
    else window.localStorage.removeItem(HIDE_KEY);
  } catch {
    // Sin almacenamiento: se queda para esta visita.
  }
}

const SOON: { key: keyof typeof t.app; icon: ReactNode; group?: boolean }[] = [
  { key: "presupuestos", icon: Icons.presupuestos },
  { key: "pagos", icon: Icons.pagos },
  { key: "estadisticas", icon: Icons.estadisticas },
  { key: "grupos", icon: Icons.grupos },
  { key: "ia", icon: Icons.ia },
];

export function Shell({ me }: { me: Me }) {
  const [sec, setSec] = useState<Sec>(secFromPath);
  const [hide, setHide] = useState(readHidePref);
  const [apuntar, setApuntar] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const [panel, setPanel] = useState<PanelData | null>(null);
  const [panelError, setPanelError] = useState(false);
  const [cats, setCats] = useState<Categoria[] | null>(null);
  const [bandeja, setBandeja] = useState<BandejaData | null>(null);

  const go = useCallback((s: Sec) => {
    setSec(s);
    const path = s === "panel" ? "/" : `/${s}`;
    if (window.location.pathname !== path) window.history.pushState(null, "", path);
    window.scrollTo(0, 0);
  }, []);

  const loadPanel = useCallback(() => {
    setPanelError(false);
    getJson<PanelData>("/api/panel").then(setPanel, () => setPanelError(true));
  }, []);
  const loadBandeja = useCallback(() => {
    getJson<BandejaData>("/api/bandeja").then(setBandeja, () => undefined);
  }, []);

  useEffect(() => {
    loadPanel();
    loadBandeja();
    const onPop = () => setSec(secFromPath());
    window.addEventListener("popstate", onPop);
    return () => window.removeEventListener("popstate", onPop);
  }, [loadPanel, loadBandeja]);

  // ¿Sigue viva la sesión? Cada 30 s y al volver a la pestaña. `getJson` lleva a la pantalla de entrar con un 401.
  useEffect(() => {
    const check = () => void getJson("/api/me").catch(() => undefined);
    const timer = window.setInterval(check, 30_000);
    const onVisible = () => {
      if (document.visibilityState === "visible") check();
    };
    document.addEventListener("visibilitychange", onVisible);
    return () => {
      window.clearInterval(timer);
      document.removeEventListener("visibilitychange", onVisible);
    };
  }, []);

  useEffect(() => {
    if (!toast) return;
    const id = window.setTimeout(() => setToast(null), 2800);
    return () => window.clearTimeout(id);
  }, [toast]);

  const openApuntar = () => {
    setApuntar(true);
    if (!cats) getJson<{ categorias: Categoria[] }>("/api/categorias").then((r) => setCats(r.categorias), () => setCats([]));
  };

  const pendingCount = bandeja ? bandeja.pendientes.length + bandeja.enviados.length : 0;
  const badge = pendingCount > 0 ? <span className="badge">{pendingCount}</span> : null;
  const title = sec === "mas" ? t.app.mas : t.app[sec];

  const navButton = (s: Exclude<Sec, "mas">, icon: ReactNode) => (
    <a
      className="nv"
      href={s === "panel" ? "/" : `/${s}`}
      aria-current={sec === s ? "page" : undefined}
      onClick={(e) => {
        e.preventDefault();
        go(s);
      }}
    >
      {icon}
      <span className="sp">{t.app[s]}</span>
      {s === "bandeja" ? badge : null}
    </a>
  );

  const soonItem = (x: (typeof SOON)[number]) => (
    <div className="nv later" key={x.key} aria-disabled="true">
      {x.icon}
      <span className="sp">{t.app[x.key] as string}</span>
      <span className="lk">{t.app.pronto}</span>
    </div>
  );

  return (
    <div className={`app${hide ? " hideamt" : ""}`}>
      <aside className="side" aria-label="Yala">
        <div className="brand" aria-hidden="true">
          <i />
          Yala
        </div>
        <nav aria-label={t.app.panel}>
          {navButton("panel", Icons.panel)}
          {navButton("bandeja", Icons.bandeja)}
          {navButton("registros", Icons.registros)}
          {SOON.map(soonItem)}
          {navButton("configurar", Icons.configurar)}
        </nav>
        <div className="sidefoot">{t.app.beta}</div>
      </aside>

      <div className="main">
        <header className="topbar">
          <h1>{title}</h1>
          <button
            className="ib"
            type="button"
            aria-pressed={hide}
            aria-label={hide ? t.app.mostrarMontos : t.app.ocultarMontos}
            title={hide ? t.app.mostrarMontos : t.app.ocultarMontos}
            onClick={() => setHide((h) => !h)}
          >
            {Icons.eye}
          </button>
          <button className="add" type="button" onClick={openApuntar}>
            + {t.app.apuntar}
          </button>
        </header>

        <main className="content">
          {sec === "panel" ? <Panel data={panel} error={panelError} retry={loadPanel} onSeeAll={() => go("registros")} /> : null}
          {sec === "registros" ? <Registros cuentas={panel?.cuentas.cuentas ?? []} /> : null}
          {sec === "bandeja" ? <Bandeja data={bandeja} reload={loadBandeja} /> : null}
          {sec === "configurar" ? <Configurar me={me} onToast={setToast} /> : null}
          {sec === "mas" ? (
            <div className="cd" style={{ padding: "6px 10px" }}>
              {navButton("configurar", Icons.configurar)}
              {SOON.map(soonItem)}
            </div>
          ) : null}
        </main>
      </div>

      <nav className="mtabs" aria-label={t.app.panel}>
        {(["panel", "registros"] as const).map((s) => (
          <button key={s} type="button" className="mt" aria-current={sec === s ? "page" : undefined} onClick={() => go(s)}>
            {s === "panel" ? Icons.panel : Icons.registros}
            {t.app[s]}
          </button>
        ))}
        <button type="button" className="mt plus" aria-label={t.app.apuntar} onClick={openApuntar}>
          <span className="c">{Icons.plus}</span>
        </button>
        <button type="button" className="mt" aria-current={sec === "bandeja" ? "page" : undefined} onClick={() => go("bandeja")}>
          {Icons.bandeja}
          {t.app.bandeja}
          {badge}
        </button>
        <button type="button" className="mt" aria-current={sec === "mas" || sec === "configurar" ? "page" : undefined} onClick={() => go("mas")}>
          {Icons.mas}
          {t.app.mas}
        </button>
      </nav>

      {apuntar ? (
        <Apuntar
          cuentas={panel?.cuentas.cuentas ?? []}
          divisaPreferida={panel?.cuentas.total.divisa ?? "PEN"}
          categorias={cats}
          onClose={() => setApuntar(false)}
          onSent={() => {
            setApuntar(false);
            setToast(t.app.enviadoToast);
            loadBandeja();
          }}
        />
      ) : null}
      {toast ? (
        <div className="toast" role="status">
          {toast}
        </div>
      ) : null}
    </div>
  );
}
