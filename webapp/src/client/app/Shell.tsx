/**
 * La app con sesión (lotes 1 a 3 y 2b): Panel, Bandeja, Registros, Planificación (Presupuestos y Pagos planificados),
 * Estadísticas, Grupos y Configurar, con la búsqueda ⌘K (lote 2b), «+ Nuevo registro» y el ojo que oculta los montos.
 * Una cuenta «solo Grupos» (lote 3, decisión D3) abre en Grupos, no ve «Nuevo registro», y las secciones de la nube
 * completa le explican por qué no tienen nada.
 *
 * Navegación como la app (lote 3 de «Yala web como la app»): en escritorio, barra lateral de cristal como la app en iPad,
 * con el campo Buscar arriba y el avatar abajo, que abre Configurar. En el celular, la barra flotante de la app (Panel,
 * Registros, Grupos y Más) con la lupa aparte, la Bandeja en su botón arriba a la izquierda y «+ Nuevo registro» en el
 * contenido. Qué dirección abre qué, en `navegacion.ts`. Yala IA sale como «Pronto», sin abrir nada.
 *
 * La página pregunta `/api/me` cada 30 s y al volver a primer plano: si la sesión se cerró desde el iPhone o desde otra
 * pestaña, vuelve a la pantalla de entrar en menos de un minuto (lo que promete la maqueta).
 */
import { useCallback, useEffect, useRef, useState, type ReactNode } from "react";
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
import { Presupuestos } from "./Presupuestos";
import { Busqueda, type Destino } from "./Busqueda";
import type { FiltroInicial } from "./Registros";
import { FULL_CLOUD, isPlan, pathOf, secFromPath, segmentOf, shortcutLabel, sideOf, tabOf, type Sec } from "./navegacion";

const t = texts();

export interface Me {
  nombre: string;
  correo: string | null;
  equipoCompartido: boolean;
  soloGrupos?: boolean;
}

/** Las secciones con entrada propia (todas menos «Más»), con su ícono. */
type Nav = Exclude<Sec, "mas">;
const ICON: Record<Nav, ReactNode> = {
  panel: Icons.panel,
  bandeja: Icons.bandeja,
  registros: Icons.registros,
  estadisticas: Icons.estadisticas,
  planificacion: Icons.planificacion,
  presupuestos: Icons.presupuestos,
  pagos: Icons.pagos,
  grupos: Icons.grupos,
  configurar: Icons.configurar,
};
/** La barra lateral de escritorio, en el orden de la app en iPad. */
const SIDE: Nav[] = ["panel", "registros", "estadisticas", "planificacion", "grupos"];
/** Los colores de las tarjetas de «Más», los de la app. */
const TILE: Partial<Record<Nav, string>> = {
  bandeja: "#ff0080",
  estadisticas: "#0a84ff",
  presupuestos: "#d946ef",
  pagos: "#14b8a6",
  configurar: "#8e8e93",
};
const HIDE_KEY = "yala-web-ocultar";

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

export function Shell({ me }: { me: Me }) {
  const solo = me.soloGrupos === true;
  const home: Sec = solo ? "grupos" : "panel";
  const [sec, setSec] = useState<Sec>(() => secFromPath(window.location.pathname, home));
  const [editando, setEditando] = useState<Enviado | null>(null);
  const [hide, setHide] = useState(readHidePref);
  const [apuntar, setApuntar] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const [panel, setPanel] = useState<PanelData | null>(null);
  const [panelError, setPanelError] = useState(false);
  const [cats, setCats] = useState<Categoria[] | null>(null);
  const [bandeja, setBandeja] = useState<BandejaData | null>(null);
  const [buscar, setBuscar] = useState(false);
  /** Lo que tenía el foco al abrir la búsqueda: vuelve ahí al cerrarla, para seguir con el teclado donde estabas. */
  const prevFocus = useRef<HTMLElement | null>(null);
  /** El filtro con el que la búsqueda abrió Registros; `n` lo vuelve a montar aunque el filtro se repita. */
  const [regFiltro, setRegFiltro] = useState<{ f: FiltroInicial; n: number } | null>(null);

  const go = useCallback((s: Sec) => {
    setSec(s);
    const path = pathOf(s, home);
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
    const onPop = () => setSec(secFromPath(window.location.pathname, home));
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

  const openSearch = useCallback(() => {
    if (document.activeElement instanceof HTMLElement) prevFocus.current = document.activeElement;
    setBuscar(true);
  }, []);
  const closeSearch = useCallback(() => {
    setBuscar(false);
    const el = prevFocus.current;
    prevFocus.current = null;
    if (el?.isConnected) window.setTimeout(() => el.focus(), 0);
  }, []);

  // ⌘K / Ctrl+K abre y cierra la búsqueda desde cualquier sección (también con el foco en un campo).
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && !e.altKey && !e.shiftKey && e.key.toLowerCase() === "k") {
        e.preventDefault();
        if (buscar) closeSearch();
        else openSearch();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [buscar, openSearch, closeSearch]);

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

  // Las secciones a las que lleva la búsqueda: las que esta cuenta puede abrir.
  const destinos: Destino[] = (Object.keys(ICON) as Nav[])
    .filter((k) => !solo || !FULL_CLOUD.includes(k))
    .map((k) => ({ key: k, label: t.app[k], icon: ICON[k] }));

  const pendingCount = bandeja ? bandeja.pendientes.length + bandeja.enviados.length : 0;
  const badge = pendingCount > 0 ? <span className="badge">{pendingCount}</span> : null;
  const title = sec === "mas" ? t.app.mas : isPlan(sec) ? t.app.planificacion : t.app[sec];
  const side = sideOf(sec);
  const tab = tabOf(sec, solo);
  const kbd = shortcutLabel(navigator.platform || navigator.userAgent);
  const full = !solo;

  /** Un enlace de verdad (abre en otra pestaña con ⌘-clic), que navega dentro de la página con el clic normal. */
  const link = (s: Sec, className: string, current: boolean, children: ReactNode, label?: string) => (
    <a
      key={s}
      className={className}
      href={pathOf(s, home)}
      aria-current={current ? "page" : undefined}
      aria-label={label}
      onClick={(e) => {
        if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || e.button !== 0) return;
        e.preventDefault();
        go(s);
      }}
    >
      {children}
    </a>
  );

  const sideItem = (s: Nav) =>
    link(
      s,
      "nv",
      side === s,
      <>
        {ICON[s]}
        <span className="sp">{t.app[s]}</span>
        {s === "bandeja" ? badge : null}
      </>,
    );

  const soon = (
    <div className="nv later" aria-disabled="true">
      {Icons.ia}
      <span className="sp">{t.app.ia}</span>
      <span className="lk">{t.app.pronto}</span>
    </div>
  );

  const newRecord = (className: string) => (
    <button className={className} type="button" onClick={openApuntar}>
      {Icons.plus}
      {t.app.nuevoRegistro}
    </button>
  );

  // En el celular «+ Nuevo registro» va dentro del contenido, debajo de la cifra principal, como en la app (lote 4).
  const actsMob = <div className="acts mob">{newRecord("add")}</div>;

  const tile = (s: Nav, wide = false) =>
    link(
      s,
      `tile${wide ? " wide" : ""}`,
      false,
      <>
        <span className="tic" style={{ background: TILE[s] }}>
          {ICON[s]}
        </span>
        <b>{t.app[s]}</b>
        {s === "bandeja" ? badge : null}
      </>,
    );

  const segment = segmentOf(sec);

  return (
    <div className={`app${hide ? " hideamt" : ""}`}>
      <aside className="side" aria-label="Yala">
        <div className="brand">
          <i aria-hidden="true" />
          Yala
          <span className="lk">{t.app.beta}</span>
        </div>
        <button className="sfield" type="button" aria-keyshortcuts="Meta+K Control+K" onClick={openSearch}>
          {Icons.search}
          <span>{t.bus.abrir}</span>
          <kbd aria-hidden="true">{kbd}</kbd>
        </button>
        <nav aria-label="Yala">
          {SIDE.map(sideItem)}
          <div className="navh">{t.app.mas}</div>
          {sideItem("bandeja")}
          {soon}
        </nav>
        {link(
          "configurar",
          "sfoot",
          sec === "configurar",
          <>
            <span className="av">{Icons.avatar}</span>
            <span className="who">
              <b>{me.nombre}</b>
              <span>{t.app.configurar}</span>
            </span>
          </>,
        )}
      </aside>

      <div className="main">
        <header className="topbar">
          {full
            ? link(
                "bandeja",
                "ib mob inbox",
                sec === "bandeja",
                <>
                  {Icons.bandeja}
                  {badge}
                </>,
                pendingCount > 0 ? `${t.app.bandeja} (${pendingCount})` : t.app.bandeja,
              )
            : null}
          <h1>{title}</h1>
          <button
            className="ib eye"
            type="button"
            aria-pressed={hide}
            aria-label={hide ? t.app.mostrarMontos : t.app.ocultarMontos}
            title={hide ? t.app.mostrarMontos : t.app.ocultarMontos}
            onClick={() => setHide((h) => !h)}
          >
            {Icons.eye}
          </button>
          {full ? newRecord("add desk") : null}
          {link("configurar", "ib mob av", sec === "configurar", Icons.avatar, `${me.nombre} · ${t.app.configurar}`)}
        </header>

        <main className="content">
          {solo && FULL_CLOUD.includes(sec) ? <SoloGrupos onGroups={() => go("grupos")} /> : null}
          {sec === "grupos" ? <Grupos /> : null}
          {full && sec === "panel" ? <Panel data={panel} error={panelError} retry={loadPanel} onGo={go} accion={actsMob} /> : null}
          {full && sec === "registros" ? (
            <Registros key={regFiltro?.n ?? 0} cuentas={panel?.cuentas.cuentas ?? []} inicial={regFiltro?.f} onToast={setToast} accion={actsMob} />
          ) : null}
          {full && isPlan(sec) ? (
            <>
              <div className="psegs" role="group" aria-label={t.app.planificacion}>
                {link("presupuestos", "pseg", segment === "presupuestos", <>{Icons.presupuestos}{t.app.presupuestos}</>)}
                {link("pagos", "pseg", segment === "pagos", <>{Icons.pagos}{t.app.pagos}</>)}
              </div>
              {segment === "pagos" ? <Pagos /> : <Presupuestos />}
            </>
          ) : null}
          {full && sec === "bandeja" ? <Bandeja data={bandeja} reload={loadBandeja} onEdit={openEdit} onToast={setToast} /> : null}
          {full && sec === "estadisticas" ? <Estadisticas /> : null}
          {sec === "configurar" ? <Configurar me={me} onToast={setToast} /> : null}
          {sec === "mas" ? (
            <div className="tiles">
              {full ? tile("bandeja", true) : null}
              {tile("estadisticas", true)}
              <div className="navh">{t.app.planificacion}</div>
              <div className="tgrid">
                {tile("presupuestos")}
                {tile("pagos")}
              </div>
              {tile("configurar", true)}
              <div className="tile wide later" aria-disabled="true">
                <span className="tic">{Icons.ia}</span>
                <b>{t.app.ia}</b>
                <span className="lk">{t.app.pronto}</span>
              </div>
            </div>
          ) : null}
        </main>
      </div>

      <div className="mbar">
        <nav className="mtabs" aria-label="Yala">
          {(solo ? (["grupos", "configurar"] as const) : (["panel", "registros", "grupos", "mas"] as const)).map((s) =>
            link(
              s,
              "mt",
              tab === s,
              <>
                {s === "mas" ? Icons.mas : ICON[s]}
                {s === "mas" ? t.app.mas : t.app[s]}
              </>,
            ),
          )}
        </nav>
        <button className="msearch" type="button" aria-label={t.bus.abrir} onClick={openSearch}>
          {Icons.search}
        </button>
      </div>

      {apuntar ? (
        <Apuntar
          cuentas={panel?.cuentas.cuentas ?? []}
          divisaPreferida={panel?.cuentas.total.divisa ?? "PEN"}
          categorias={cats}
          recientes={panel?.ultimos.movimientos}
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
      {buscar ? (
        <Busqueda
          solo={solo}
          destinos={destinos}
          cuentas={panel?.cuentas.cuentas ?? []}
          onClose={closeSearch}
          onGo={(k) => {
            setBuscar(false);
            prevFocus.current = null;
            go(k as Sec);
          }}
          onRegistros={(f) => {
            setBuscar(false);
            prevFocus.current = null;
            setRegFiltro((r) => ({ f, n: (r?.n ?? 0) + 1 }));
            go("registros");
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
