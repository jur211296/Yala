/**
 * La app con sesión (lotes 1 a 3): Panel, Bandeja, Registros, Pagos planificados, Estadísticas, Grupos y Configurar,
 * con «Apuntar» y el ojo que oculta los montos. Una cuenta «solo Grupos» (lote 3, decisión D3) abre en Grupos, no ve
 * «Apuntar», y las secciones de la nube completa le explican por qué no tienen nada.
 * Escritorio: barra lateral. Móvil: barra de pestañas con «+» en medio y «Más». Las secciones de los lotes siguientes
 * salen en la barra como «Pronto», sin abrir nada.
 *
 * La página pregunta `/api/me` cada 30 s y al volver a primer plano: si la sesión se cerró desde el iPhone o desde otra
 * pestaña, vuelve a la pantalla de entrar en menos de un minuto (lo que promete la maqueta).
 */
import { useCallback, useEffect, useState, type ReactNode } from "react";
import { texts } from "../i18n";
import { getJson, type Bandeja as BandejaData, type Categoria, type Enviado, type Panel as PanelData } from "./api";
import { Icons } from "./icons";
import { Panel } from "./Panel";
import { Registros } from "./Registros";
import { Bandeja } from "./Bandeja";
import { Configurar } from "./Configurar";
import { Apuntar } from "./Apuntar";
import { Estadisticas } from "./Estadisticas";
import { Pagos } from "./Pagos";
import { Grupos, SoloGrupos } from "./Grupos";

const t = texts();

export interface Me {
  nombre: string;
  correo: string | null;
  equipoCompartido: boolean;
  soloGrupos?: boolean;
}

type Sec = "panel" | "bandeja" | "registros" | "pagos" | "estadisticas" | "grupos" | "configurar" | "mas";
const SECTIONS: Sec[] = ["panel", "bandeja", "registros", "pagos", "estadisticas", "grupos", "configurar", "mas"];
/** Lo que vive en la nube completa: una cuenta «solo Grupos» no tiene nada que ver ahí. */
const FULL_CLOUD: Sec[] = ["panel", "bandeja", "registros", "pagos", "estadisticas"];
const HIDE_KEY = "yala-web-ocultar";

function secFromPath(home: Sec = "panel"): Sec {
  const p = window.location.pathname.replace(/^\/+|\/+$/g, "");
  return (SECTIONS as string[]).includes(p) ? (p as Sec) : home;
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
  { key: "ia", icon: Icons.ia },
];

export function Shell({ me }: { me: Me }) {
  const solo = me.soloGrupos === true;
  const home: Sec = solo ? "grupos" : "panel";
  const [sec, setSec] = useState<Sec>(() => secFromPath(home));
  const [editando, setEditando] = useState<Enviado | null>(null);
  const [hide, setHide] = useState(readHidePref);
  const [apuntar, setApuntar] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const [panel, setPanel] = useState<PanelData | null>(null);
  const [panelError, setPanelError] = useState(false);
  const [cats, setCats] = useState<Categoria[] | null>(null);
  const [bandeja, setBandeja] = useState<BandejaData | null>(null);

  const go = useCallback((s: Sec) => {
    setSec(s);
    const path = s === home ? "/" : `/${s}`;
    if (window.location.pathname !== path) window.history.pushState(null, "", path);
    window.scrollTo(0, 0);
  }, [home]);

  const loadPanel = useCallback(() => {
    setPanelError(false);
    getJson<PanelData>("/api/panel").then(setPanel, () => setPanelError(true));
  }, []);
  const loadBandeja = useCallback(() => {
    getJson<BandejaData>("/api/bandeja").then(setBandeja, () => undefined);
  }, []);

  useEffect(() => {
    if (!solo) {
      loadPanel();
      loadBandeja();
    }
    const onPop = () => setSec(secFromPath(home));
    window.addEventListener("popstate", onPop);
    return () => window.removeEventListener("popstate", onPop);
  }, [loadPanel, loadBandeja, solo, home]);

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

  const loadCats = () => {
    if (!cats) getJson<{ categorias: Categoria[] }>("/api/categorias").then((r) => setCats(r.categorias), () => setCats([]));
  };
  const openApuntar = () => {
    setApuntar(true);
    loadCats();
  };
  const openEdit = (d: Enviado) => {
    setEditando(d);
    loadCats();
  };

  const pendingCount = bandeja ? bandeja.pendientes.length + bandeja.enviados.length : 0;
  const badge = pendingCount > 0 ? <span className="badge">{pendingCount}</span> : null;
  const title = sec === "mas" ? t.app.mas : t.app[sec];

  const navButton = (s: Exclude<Sec, "mas">, icon: ReactNode) => (
    <a
      className="nv"
      href={s === home ? "/" : `/${s}`}
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
          {navButton("pagos", Icons.pagos)}
          {navButton("estadisticas", Icons.estadisticas)}
          {navButton("grupos", Icons.grupos)}
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
          {solo ? null : (
            <button className="add" type="button" onClick={openApuntar}>
              + {t.app.apuntar}
            </button>
          )}
        </header>

        <main className="content">
          {solo && FULL_CLOUD.includes(sec) ? <SoloGrupos onGroups={() => go("grupos")} /> : null}
          {sec === "grupos" ? <Grupos /> : null}
          {!solo && sec === "panel" ? <Panel data={panel} error={panelError} retry={loadPanel} onSeeAll={() => go("registros")} /> : null}
          {!solo && sec === "registros" ? <Registros cuentas={panel?.cuentas.cuentas ?? []} /> : null}
          {!solo && sec === "bandeja" ? <Bandeja data={bandeja} reload={loadBandeja} onEdit={openEdit} onToast={setToast} /> : null}
          {!solo && sec === "pagos" ? <Pagos /> : null}
          {!solo && sec === "estadisticas" ? <Estadisticas /> : null}
          {sec === "configurar" ? <Configurar me={me} onToast={setToast} /> : null}
          {sec === "mas" ? (
            <div className="cd" style={{ padding: "6px 10px" }}>
              {navButton("pagos", Icons.pagos)}
              {navButton("estadisticas", Icons.estadisticas)}
              {navButton("grupos", Icons.grupos)}
              {navButton("configurar", Icons.configurar)}
              {SOON.map(soonItem)}
            </div>
          ) : null}
        </main>
      </div>

      {solo ? (
        <nav className="mtabs two" aria-label={t.app.grupos}>
          {(["grupos", "configurar"] as const).map((s) => (
            <button key={s} type="button" className="mt" aria-current={sec === s ? "page" : undefined} onClick={() => go(s)}>
              {s === "grupos" ? Icons.grupos : Icons.configurar}
              {t.app[s]}
            </button>
          ))}
        </nav>
      ) : (
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
        <button type="button" className="mt" aria-current={sec === "mas" || sec === "configurar" || sec === "pagos" || sec === "estadisticas" || sec === "grupos" ? "page" : undefined} onClick={() => go("mas")}>
          {Icons.mas}
          {t.app.mas}
        </button>
      </nav>
      )}

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
      {editando ? (
        <Apuntar
          cuentas={panel?.cuentas.cuentas ?? []}
          divisaPreferida={panel?.cuentas.total.divisa ?? "PEN"}
          categorias={cats}
          editar={editando}
          onClose={() => setEditando(null)}
          onSent={() => {
            setEditando(null);
            setToast(t.app.guardadoToast);
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
