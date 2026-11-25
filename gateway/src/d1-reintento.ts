/**
 * Reintento de D1 ante saturación TRANSITORIA de la plataforma (2026-11-25, YALA-GATEWAY-2/3/4).
 *
 * Qué pasó: el 25-nov a las 02:15 UTC tres peticiones de una MISMA apertura de la app (una traza) recibieron
 * `D1_ERROR: D1 DB is overloaded. Requests queued for too long.` — un POST y un GET de `/account/entitlement` y un
 * GET de `/mail/drafts`. El gateway llevaba ~10 peticiones por minuto y las métricas de D1 de ese minuto no registran
 * NINGUNA consulta: las sentencias se quedaron en la cola de Cloudflare y nunca llegaron a la base. La falla fue de la
 * plataforma, no de carga nuestra ni de una consulta lenta (todas van por clave primaria o índice único).
 *
 * Qué se reintenta: SOLO esa familia de errores, que significa «la sentencia no llegó a ejecutarse». Un error de SQL,
 * una restricción o cualquier otro fallo sube tal cual a la primera.
 *
 * Idempotencia: quien llama decide qué envuelve, y envuelve una unidad que se pueda repetir entera sin cambiar el
 * resultado: lecturas, o una secuencia «leer → decidir → escribir» que vuelve a leer en cada intento (así un cambio que
 * entre entre dos intentos, como una revocación del webhook, se ve antes de escribir).
 *
 * Si se agotan los intentos se relanza el ÚLTIMO error: `app.onError` lo reconoce con `esD1Saturada` y responde 503
 * con `Retry-After` en lugar de un 500 genérico.
 */

/** Fragmentos del mensaje de D1 que indican cola saturada (la sentencia no se ejecutó). */
const MARCAS_SATURACION = ["D1 DB is overloaded", "Requests queued for too long", "Too many requests queued"];

/** Segundos que el 503 pide esperar al cliente. La saturación medida duró un instante. */
export const RETRY_AFTER_D1_SATURADA_S = 2;

export const INTENTOS_D1_POR_DEFECTO = 3;

function mensajes(err: unknown): string[] {
  const out: string[] = [];
  let actual: unknown = err;
  // D1 encadena el error con `cause`: se miran varios niveles por si el runtime cambia cuál lleva el texto.
  for (let i = 0; i < 4 && actual != null; i++) {
    if (actual instanceof Error) {
      out.push(actual.message);
      actual = (actual as Error & { cause?: unknown }).cause;
    } else {
      out.push(String(actual));
      break;
    }
  }
  return out;
}

/** ¿Es el error de D1 «cola saturada», el único que se reintenta? */
export function esD1Saturada(err: unknown): boolean {
  return mensajes(err).some((m) => MARCAS_SATURACION.some((marca) => m.includes(marca)));
}

export interface OpcionesReintentoD1 {
  /** Intentos en total, incluido el primero. */
  intentos?: number;
  /** Techo de la espera del primer reintento, en ms; se duplica en cada uno. */
  baseMs?: number;
  /** Tope de cada espera, en ms. */
  maxMs?: number;
  /** Etiqueta para el log (sin datos personales). */
  etiqueta?: string;
  /** Inyectables para los tests. */
  dormir?: (ms: number) => Promise<void>;
  aleatorio?: () => number;
}

const dormirReal = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

/**
 * Ejecuta `fn` y, si D1 responde «cola saturada», la repite con backoff exponencial y jitter completo: la espera es
 * uniforme en [0, min(maxMs, baseMs·2^n)]. Con los valores por defecto el peor caso añade ~300 ms.
 */
export async function conReintentoD1<T>(fn: () => Promise<T>, opciones: OpcionesReintentoD1 = {}): Promise<T> {
  const intentos = Math.max(1, opciones.intentos ?? INTENTOS_D1_POR_DEFECTO);
  const baseMs = opciones.baseMs ?? 100;
  const maxMs = opciones.maxMs ?? 1000;
  const dormir = opciones.dormir ?? dormirReal;
  const aleatorio = opciones.aleatorio ?? Math.random;
  const etiqueta = opciones.etiqueta ?? "d1";

  for (let n = 1; ; n++) {
    try {
      return await fn();
    } catch (err) {
      if (!esD1Saturada(err) || n >= intentos) throw err;
      const techo = Math.min(maxMs, baseMs * 2 ** (n - 1));
      const espera = Math.floor(aleatorio() * techo);
      console.log(`[d1-reintento] ${etiqueta}: D1 saturada en el intento ${n}/${intentos}; reintento en ${espera} ms`);
      await dormir(espera);
    }
  }
}
