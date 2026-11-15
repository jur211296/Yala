/**
 * Entrar con el iPhone (lote 2): la web enseña un código QR y su versión escrita; en el iPhone, «Vincular un navegador»
 * lo lee, enseña este navegador y pide Face ID. La página pregunta al Worker cada 2,5 s y entra en cuanto el iPhone
 * aprueba. El código cambia cada 60 s; pasados 10 minutos hay que pedir otro (y pasar otra vez por Turnstile).
 *
 * La página no ve ningún secreto: el código va en claro a propósito y lo que liga este navegador a él es una cookie
 * `HttpOnly` (ver `src/worker/pairing.ts`).
 */
import { useEffect, useMemo, useRef, useState } from "react";
import qrcode from "qrcode-generator";
import { texts } from "./i18n";

const t = texts();
const POLL_MS = 2500;

type Phase = "pidiendo" | "esperando" | "visto" | "entrando" | "caducado" | "error";

interface Code {
  codigo: string;
  url: string;
  expira: number;
}

async function post(path: string, body: unknown): Promise<{ status: number; data: Record<string, unknown> }> {
  const res = await fetch(path, {
    method: "POST",
    credentials: "same-origin",
    cache: "no-store",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  return { status: res.status, data: ((await res.json().catch(() => ({}))) as Record<string, unknown>) ?? {} };
}

/** El QR como SVG: un `path` por módulo oscuro, sin canvas ni imágenes (la CSP solo deja lo propio). */
function QrSvg({ text }: { text: string }) {
  const { size, d } = useMemo(() => {
    const qr = qrcode(0, "M");
    qr.addData(text);
    qr.make();
    const n = qr.getModuleCount();
    let path = "";
    for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) if (qr.isDark(r, c)) path += `M${c + 2} ${r + 2}h1v1h-1z`;
    return { size: n + 4, d: path };
  }, [text]);
  return (
    <svg className="qr" viewBox={`0 0 ${size} ${size}`} role="img" aria-label={t.qr.titulo} shapeRendering="crispEdges">
      <rect width={size} height={size} fill="#fff" />
      <path d={d} fill="#111" />
    </svg>
  );
}

export function QrLogin({ turnstile, compartido, onBack }: { turnstile: string; compartido: boolean; onBack: () => void }) {
  const [phase, setPhase] = useState<Phase>("pidiendo");
  const [code, setCode] = useState<Code | null>(null);
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000));
  const renewing = useRef(false);
  // El reloj del Worker manda: la diferencia con el del navegador se mide al recibir el código.
  const skew = useRef(0);

  useEffect(() => {
    let cancelled = false;
    void post("/auth/qr/start", { turnstile, compartido }).then(({ status, data }) => {
      if (cancelled) return;
      if (status !== 200 || typeof data.codigo !== "string") {
        setPhase("error");
        return;
      }
      const c = data as unknown as Code;
      skew.current = c.expira - 60 - Math.floor(Date.now() / 1000);
      setCode(c);
      setPhase("esperando");
    });
    return () => {
      cancelled = true;
    };
  }, [turnstile, compartido]);

  // Pregunta por el código y lo renueva al caducar.
  useEffect(() => {
    if (!code || (phase !== "esperando" && phase !== "visto")) return;
    const tick = async () => {
      const serverNow = Math.floor(Date.now() / 1000) + skew.current;
      setNow(serverNow);
      if (phase === "esperando" && serverNow >= code.expira && !renewing.current) {
        renewing.current = true;
        const { status, data } = await post("/auth/qr/renovar", { codigo: code.codigo });
        renewing.current = false;
        if (status === 200 && typeof data.codigo === "string") {
          setCode(data as unknown as Code);
          return;
        }
        // No se renueva un código que el iPhone acaba de leer: se sigue esperando su confirmación.
        const st = await post("/auth/qr/estado", { codigo: code.codigo });
        setPhase(st.data.estado === "visto" ? "visto" : "caducado");
        return;
      }
      const { status, data } = await post("/auth/qr/estado", { codigo: code.codigo });
      if (status !== 200) return;
      if (data.estado === "dentro") {
        setPhase("entrando");
        window.location.replace("/");
      } else if (data.estado === "visto") setPhase("visto");
      else if (data.estado === "caducado" && phase === "visto") setPhase("caducado");
      else if (data.estado === "error") setPhase("error");
    };
    const id = window.setInterval(() => void tick(), POLL_MS);
    const clock = window.setInterval(() => setNow(Math.floor(Date.now() / 1000) + skew.current), 1000);
    return () => {
      window.clearInterval(id);
      window.clearInterval(clock);
    };
  }, [code, phase]);

  if (phase === "error" || phase === "caducado") {
    return (
      <div className="login qr-login">
        <h1>{t.qr.titulo}</h1>
        <p className="aviso" role="status">
          {phase === "error" ? t.qr.error : t.qr.caducado}
        </p>
        <button className="btn dark" type="button" onClick={onBack}>
          {t.qr.otro}
        </button>
      </div>
    );
  }

  return (
    <div className="login qr-login">
      <h1>{t.qr.titulo}</h1>
      <p className="muted">{t.qr.pasos}</p>
      {code ? <QrSvg text={code.url} /> : <div className="qr qr-wait" aria-busy="true" />}
      {phase === "visto" || phase === "entrando" ? (
        <p className="aviso ok" role="status">
          {phase === "entrando" ? t.qr.entrando : t.qr.visto}
        </p>
      ) : (
        <>
          <p className="muted small-c">{t.qr.escribir}</p>
          <p className="qr-code" aria-live="polite">
            {code?.codigo ?? "····-····"}
          </p>
          {code ? <p className="fade">{t.qr.cambia(Math.max(0, code.expira - now))}</p> : null}
        </>
      )}
      <p className="fade">{t.qr.seguridad}</p>
      <button className="btn" type="button" onClick={onBack}>
        {t.qr.volver}
      </button>
    </div>
  );
}
