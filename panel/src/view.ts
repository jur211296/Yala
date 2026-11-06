import { addDays, dayRange, within } from "./days";
import { dec, int, longDay, outOfTen, pct, people, peopleNum, peopleText, usd, vsLastWeek, weekLabel } from "./format";
import { levelFor, type Level } from "./health";
import { CANARY_LABELS, FEATURE_LABELS, PRO_FEATURES, SIGNUP_PATHS, SIGNUP_STEPS, TASK_LABELS, label } from "./labels";
import type { MetricRow } from "./summarize";

/**
 * Del resumen diario a lo que enseña la página: siete secciones, cada una con su frase de arriba y sus tarjetas, y
 * cada tarjeta con su número y su frase. Todas las frases son PLANTILLAS FIJAS (decisión 4): mismas cifras, misma
 * frase. Nada de IA aquí.
 *
 * La semana es la de los 7 días que terminan en el último día resumido; la anterior, los 7 de antes.
 */

export type Seg = { t: string; b?: boolean };
export type Tag = "medido" | "servidor" | "sin datos";
export interface Bar { label: string; value: number; display: string; level?: Level }
export interface Card {
  title: string;
  tag: Tag;
  big?: string;
  bigSmall?: string;
  delta?: { text: string; dir: "up" | "down" | "flat" };
  bars?: Bar[];
  spark?: number[];
  say: string;
  note?: string;
}
export interface Section { id: string; title: string; lead: Seg[]; cards: Card[] }
export interface PanelView {
  hasData: boolean;
  week: { from: string; to: string; label: string };
  sections: Section[];
}

class Rows {
  private byMetric = new Map<string, MetricRow[]>();
  constructor(rows: MetricRow[]) {
    for (const r of rows) {
      const list = this.byMetric.get(r.metric);
      if (list) list.push(r);
      else this.byMetric.set(r.metric, [r]);
    }
  }
  all(metric: string): MetricRow[] {
    return this.byMetric.get(metric) ?? [];
  }
  on(metric: string, day: string): MetricRow[] {
    return this.all(metric).filter((r) => r.day === day);
  }
  one(metric: string, day: string, dim = ""): MetricRow | undefined {
    return this.all(metric).find((r) => r.day === day && r.dim === dim);
  }
  sum(metric: string, from: string, to: string, dim?: (d: string) => boolean): number {
    return this.all(metric)
      .filter((r) => within(r.day, from, to) && (!dim || dim(r.dim)))
      .reduce((a, r) => a + r.value, 0);
  }
  lastDay(metric: string): string | null {
    const list = this.all(metric);
    return list.length ? list.reduce((a, r) => (r.day > a ? r.day : a), list[0].day) : null;
  }
}

/** «unos 3,4 centavos» · «menos de un centavo» · «unos US$ 1,20». */
function perPersonCents(usdPerPerson: number): string {
  const cents = usdPerPerson * 100;
  if (cents < 0.05) return "menos de un centavo";
  if (cents >= 100) return `unos ${usd(usdPerPerson)}`;
  return `unos ${dec(cents, 1)} ${dec(cents, 1) === "1" ? "centavo" : "centavos"}`;
}

function deltaOf(cur: number, prev: number, unit = ""): Card["delta"] {
  const d = Math.round(cur * 10) / 10 - Math.round(prev * 10) / 10;
  if (Math.abs(d) < 0.05) return { text: "= igual", dir: "flat" };
  return { text: `${d > 0 ? "▲" : "▼"} ${dec(Math.abs(d))}${unit}`, dir: d > 0 ? "up" : "down" };
}

function bars(entries: [string, number][], fmt: (n: number) => string = peopleNum, level?: (k: string) => Level): Bar[] {
  return entries
    .sort((a, b) => b[1] - a[1])
    .map(([k, v]) => ({ label: k, value: v, display: fmt(v), ...(level ? { level: level(k) } : {}) }));
}

export function buildView(rowsIn: MetricRow[], activeHistory: { day: string; value: number }[]): PanelView {
  const rows = new Rows(rowsIn);
  const L = rows.lastDay("active");
  if (!L) {
    return { hasData: false, week: { from: "", to: "", label: "" }, sections: [] };
  }
  const W0 = addDays(L, -6);
  const P0 = addDays(L, -13);
  const P1 = addDays(L, -7);
  const M0 = addDays(L, -29);
  const weekDays = dayRange(W0, L);

  // ---------------------------------------------------------------- Uso
  const avgW = rows.sum("active", W0, L) / 7;
  const avgP = rows.sum("active", P0, P1) / 7;
  const best = weekDays
    .map((d) => ({ d, v: rows.one("active", d)?.value ?? 0 }))
    .reduce((a, b) => (b.v > a.v ? b : a), { d: W0, v: -1 });
  const active7 = rows.one("active7", L)?.value ?? 0;
  const active30 = rows.one("active30", L)?.value ?? 0;
  const versions = rows.on("version7", L).map((r) => [r.dim, r.value] as [string, number]);
  const vTotal = versions.reduce((a, [, v]) => a + v, 0);
  const vSorted = [...versions].sort((a, b) => b[1] - a[1]);
  const top = vSorted[0];
  let versionSay = "Aún no hay versiones esta semana.";
  if (top && vTotal > 0) {
    const share = top[1] / vTotal;
    const rest = vSorted.slice(1).filter(([, v]) => v > 0);
    const tail = rest.length ? `; quedan ${people(rest.reduce((a, [, v]) => a + v, 0), "aparato", "aparatos")} en otras` : "";
    versionSay =
      share >= 0.8 ? `Casi todos ya están en la ${top[0]}${tail}.` : share >= 0.5 ? `La mayoría está en la ${top[0]}${tail}.` : `Las versiones están repartidas: la ${top[0]} va primera con ${people(top[1], "aparato", "aparatos")}.`;
  }

  const uses = rows.on("use7", L).filter((r) => !(r.dim in PRO_FEATURES) && !r.dim.startsWith("alta."));
  const usesBars = bars(uses.map((r) => [label(FEATURE_LABELS, r.dim), r.value]));
  const usesCard: Card = usesBars.length
    ? {
        title: "Lo que más se usa",
        tag: "medido",
        bars: usesBars.slice(0, 8),
        say: `${usesBars[0].label} es lo más usado: ${people(usesBars[0].value, "persona", "personas")} en 7 días.`,
        note: "Cuenta personas distintas que usaron cada función en la semana (como mucho una vez al día).",
      }
    : {
        title: "Lo que más se usa",
        tag: "sin datos",
        say: "Aún no llega. Empieza con la versión de la app que mande el aviso «usó esta función».",
      };

  // Retención: cohortes de hace dos semanas (7 días) y de hace cinco (30 días), con la ventana ya cerrada.
  const cohort = (metric: string, from: string, to: string) => {
    const rs = rows.all(metric).filter((r) => within(r.day, from, to));
    return { back: rs.reduce((a, r) => a + r.value, 0), size: rs.reduce((a, r) => a + (r.devices ?? 0), 0) };
  };
  const r7 = cohort("cohort_r7", addDays(L, -19), addDays(L, -13));
  const r30 = cohort("cohort_r30", addDays(L, -42), addDays(L, -36));
  const retentionCard: Card =
    r7.size > 0
      ? {
          title: "Vuelven a la semana",
          tag: "servidor",
          big: outOfTen(r7.back, r7.size),
          bigSmall: "vuelven a los 7 días",
          say: `De ${people(r7.size, "persona que se dio", "personas que se dieron")} de alta hace dos semanas, ${outOfTen(r7.back, r7.size)} siguieron abriendo la app la semana siguiente.`,
          note:
            r30.size > 0
              ? `A los 30 días: ${outOfTen(r30.back, r30.size)} (de ${people(r30.size, "alta", "altas")} de hace cinco semanas).`
              : "A los 30 días: aún no hay altas con el mes cumplido.",
        }
      : { title: "Vuelven a la semana", tag: "sin datos", say: "Aún no hay altas con la semana siguiente cumplida." };

  const weekly: number[] = [];
  for (let i = 0; i + 7 <= activeHistory.length; i += 7) {
    weekly.push(activeHistory.slice(i, i + 7).reduce((a, r) => a + r.value, 0) / 7);
  }

  const uso: Section = {
    id: "uso",
    title: "Uso",
    lead: [
      { t: "Esta semana abrieron Yala " },
      { t: `${people(Math.round(avgW), "persona", "personas")} al día`, b: true },
      { t: ` de media, ${vsLastWeek(avgW, avgP)}.` },
    ],
    cards: [
      {
        title: "Activos por día",
        tag: "medido",
        big: dec(avgW),
        bigSmall: "/ día",
        delta: deltaOf(avgW, avgP),
        spark: dayRange(M0, L).map((d) => rows.one("active", d)?.value ?? 0),
        say: best.v > 0 ? `El mejor día fue el ${longDay(best.d)}, con ${people(best.v, "persona", "personas")}.` : "Ningún día con aperturas esta semana.",
        note: "Últimos 30 días.",
      },
      {
        title: "Activos en la semana",
        tag: "medido",
        big: peopleNum(active7),
        bigSmall: `${peopleNum(active30)} en 30 días`,
        say: `${people(active7, "instalación distinta abrió", "instalaciones distintas abrieron")} la app al menos una vez en 7 días.`,
        note: "Cuenta instalaciones, no personas: reinstalar suma una nueva.",
      },
      { title: "Versión en uso", tag: "medido", bars: bars(versions), say: versionSay },
      usesCard,
      retentionCard,
      {
        title: "Historia",
        tag: "medido",
        spark: weekly,
        say:
          weekly.length > 1
            ? `${int(weekly.length)} semanas guardadas desde el ${longDay(activeHistory[0].day)}. Media de activos por día, semana a semana.`
            : "La historia empieza a crecer con cada día que resume el panel.",
        note: "Analytics Engine guarda 90 días; el resumen diario se queda para siempre.",
      },
    ],
  };

  // ---------------------------------------------------------------- Registro
  const isLocal = (d: string) => d === "local";
  const isCloud = (d: string) => d === "cloud";
  const regW = rows.sum("alta", W0, L);
  const regP = rows.sum("alta", P0, P1);
  const localW = rows.sum("alta", W0, L, isLocal);
  const cloudW = rows.sum("alta", W0, L, isCloud);
  const local14 = rows.sum("alta", P0, L, isLocal);
  const cloud14 = rows.sum("alta", P0, L, isCloud);
  // «Llegaron a este paso o más allá»: un paso que el flujo se salta (el saldo con «solo gastos», lo que trae el
  // prefill de iCloud, el alta por un grupo) no puede leerse como abandono.
  const reached = SIGNUP_STEPS.map(([slug, name]) => ({ name, value: rows.one("use7", L, slug)?.value ?? 0 }));
  const funnel = reached.map((s, i) => ({ name: s.name, value: Math.max(...reached.slice(i).map((r) => r.value)) }));
  const funnelStart = funnel[0]?.value ?? 0;
  const funnelEnd = funnel[funnel.length - 1]?.value ?? 0;
  const steps = funnel.slice(1, -1);
  const worst = steps.reduce<{ name: string; drop: number } | null>((acc, s, i) => {
    const prev = i === 0 ? funnelStart : steps[i - 1].value;
    const drop = prev - s.value;
    return drop > 0 && (!acc || drop > acc.drop) ? { name: s.name, drop } : acc;
  }, null);
  const paths = rows.on("use7", L).filter((r) => r.dim in SIGNUP_PATHS);
  const funnelCard: Card =
    funnelStart > 0
      ? {
          title: "Dónde abandonan el alta (7 días)",
          tag: "medido",
          bars: funnel.map((s) => ({ label: s.name, value: s.value, display: peopleNum(s.value) })),
          say:
            funnelEnd >= funnelStart
              ? `Todos los que vieron la bienvenida terminaron el alta.`
              : `Se pierden ${outOfTen(funnelStart - funnelEnd, funnelStart)} antes de terminar${worst ? `; donde más, en «${worst.name}»` : ""}.`,
          note: "Personas distintas que llegaron a cada paso, o más allá, en la semana. Un paso que el flujo se salta no cuenta como abandono.",
        }
      : { title: "Dónde abandonan el alta", tag: "sin datos", say: "Aún no llega. Empieza con la versión de la app que mande los pasos del alta." };
  const pathsCard: Card =
    paths.length > 0
      ? {
          title: "Qué camino eligen (7 días)",
          tag: "medido",
          bars: bars(paths.map((r) => [label(SIGNUP_PATHS, r.dim), r.value])),
          say: `${label(SIGNUP_PATHS, [...paths].sort((a, b) => b.value - a.value)[0].dim)} es el camino más elegido en la bienvenida.`,
        }
      : { title: "Qué camino eligen", tag: "sin datos", say: "Aún no llega. Empieza con la versión de la app que mande los pasos del alta." };
  const registro: Section = {
    id: "registro",
    title: "Registro",
    lead: [
      { t: "Esta semana se dieron de alta " },
      { t: people(regW, "persona", "personas"), b: true },
      { t: `: ${people(localW, "sin cuenta", "sin cuenta")} y ${people(cloudW, "con cuenta en la nube", "con cuenta en la nube")}. La anterior fueron ${peopleText(regP)}.` },
    ],
    cards: [
      {
        title: "Altas en la semana",
        tag: "medido",
        big: peopleNum(regW),
        bigSmall: "en 7 días",
        delta: deltaOf(regW, regP),
        spark: dayRange(M0, L).map((d) => rows.sum("alta", d, d)),
        say: `Fueron ${people(regW, "alta", "altas")}, ${vsLastWeek(regW, regP)}.`,
        note: "Últimos 30 días, alta por alta.",
      },
      {
        title: "Cómo empiezan (14 días)",
        tag: "medido",
        bars: bars([
          ["Sin cuenta (local)", local14],
          ["Con cuenta (nube)", cloud14],
        ]),
        say:
          local14 + cloud14 > 0
            ? `${outOfTen(cloud14, local14 + cloud14)} altas nacen ya con cuenta en la nube.`
            : "No hubo altas en 14 días.",
        note: "Cuenta personas: un alta en la nube manda dos avisos y aquí cuenta una.",
      },
      funnelCard,
      pathsCard,
    ],
  };

  // ---------------------------------------------------------------- Grupos
  const delivered = rows.sum("gw_canary", W0, L, (d) => d === "groupFanoutDelivered");
  const fanoutFailures = ["groupApnsSendFailed", "groupFanoutTokensRpcFailed", "groupFanoutApnsNotConfigured", "groupFanoutPushRoleMissing"];
  const failed = rows.sum("gw_canary", W0, L, (d) => fanoutFailures.includes(d));
  const sbDay = rows.lastDay("sb");
  const sb = (k: string) => (sbDay ? rows.one("sb", sbDay, k)?.value : undefined);
  const noBase = "Sin datos de la base todavía: falta conectar el conteo (ver panel/README.md).";
  const grupos: Section = {
    id: "grupos",
    title: "Grupos",
    lead: [
      { t: "Esta semana se entregaron " },
      { t: `${int(delivered)} avisos`, b: true },
      { t: failed === 0 ? " de gastos compartidos sin un solo fallo." : ` de gastos compartidos, y ${int(failed)} fallaron.` },
    ],
    cards: [
      {
        title: "Avisos de grupo entregados",
        tag: "medido",
        big: int(delivered),
        bigSmall: `${int(failed)} ${failed === 1 ? "fallo" : "fallos"}`,
        say: "Lo cuenta el propio servidor cada vez que avisa a los demás de un grupo.",
        note: "Con las notificaciones apagadas en el teléfono, Apple igual da el aviso por entregado.",
      },
      sb("groups_total") === undefined
        ? { title: "Grupos activos", tag: "sin datos", say: noBase }
        : {
            title: "Grupos activos",
            tag: "servidor",
            big: peopleNum(sb("groups_active_7d") ?? 0),
            bigSmall: "con movimiento en 7 días",
            say: `Hay ${people(sb("groups_active_7d") ?? 0, "grupo", "grupos")} con movimiento esta semana; ${people(sb("groups_new_7d") ?? 0, "es nuevo", "son nuevos")}.`,
            note: `${int(sb("groups_total") ?? 0)} grupos en total, ${int(sb("members_active") ?? 0)} miembros con cuenta.`,
          },
      sb("invites_created_7d") === undefined
        ? { title: "Invitaciones", tag: "sin datos", say: noBase }
        : {
            title: "Invitaciones",
            tag: "servidor",
            big: peopleNum(sb("invites_used_7d") ?? 0),
            bigSmall: `de ${peopleNum(sb("invites_created_7d") ?? 0)} creadas`,
            say: `De ${people(sb("invites_created_7d") ?? 0, "invitación", "invitaciones")} de esta semana, ${people(sb("invites_used_7d") ?? 0, "terminó", "terminaron")} con alguien dentro del grupo.`,
            note: `${people(sb("members_joined_7d") ?? 0, "persona entró", "personas entraron")} a un grupo en 7 días.`,
          },
      sb("expenses_7d") === undefined
        ? { title: "Gastos compartidos", tag: "sin datos", say: noBase }
        : {
            title: "Gastos compartidos",
            tag: "servidor",
            big: int(sb("expenses_7d") ?? 0),
            bigSmall: "en 7 días",
            say: `Se apuntaron ${int(sb("expenses_7d") ?? 0)} gastos en grupos esta semana.`,
          },
    ],
  };

  // ---------------------------------------------------------------- Nube
  const c30 = (name: string) => rows.one("canary30", L, name);
  const consent = c30("cloudConsentAccepted")?.devices ?? 0;
  const exportOk = rows.sum("canary", M0, L, (d) => d === "cloudkitExportSucceeded");
  const exportFail = rows.sum("canary", M0, L, (d) => d === "cloudkitExportFailed");
  const exportFailDevices = c30("cloudkitExportFailed")?.devices ?? 0;
  const mismatch = (c30("cloudSyncMerkleDivergence")?.value ?? 0) + (c30("groupMerkleDivergence")?.value ?? 0);
  const mismatchDevices = Math.max(c30("cloudSyncMerkleDivergence")?.devices ?? 0, c30("groupMerkleDivergence")?.devices ?? 0);
  const nube: Section = {
    id: "nube",
    title: "Nube",
    lead: [
      { t: "En 30 días, " },
      { t: people(consent, "aparato", "aparatos"), b: true },
      { t: ` activaron la nube, y la copia en iCloud se guardó bien el ${pct(exportOk, exportOk + exportFail)} de las veces.` },
    ],
    cards: [
      {
        title: "Activaron la nube",
        tag: "medido",
        big: peopleNum(consent),
        bigSmall: "aparatos · 30 días",
        say: "Aceptaron el aviso de privacidad y encendieron la nube.",
      },
      {
        title: "Copias en iCloud",
        tag: "medido",
        big: pct(exportOk, exportOk + exportFail),
        bigSmall: `${int(exportFail)} fallos en ${people(exportFailDevices, "aparato", "aparatos")}`,
        say: `${int(exportOk)} copias bien y ${int(exportFail)} que fallaron en 30 días. Un fallo suelto se reintenta solo.`,
      },
      {
        title: "Datos que no cuadraban",
        tag: "medido",
        big: int(mismatch),
        bigSmall: people(mismatchDevices, "aparato", "aparatos"),
        say:
          mismatch === 0
            ? "En 30 días ninguna copia dejó de coincidir con la del servidor."
            : `${int(mismatch)} veces la copia de un aparato no coincidía con la del servidor y se volvió a bajar.`,
      },
      sb("accounts_complete") === undefined
        ? { title: "Cuentas en la nube", tag: "sin datos", say: noBase }
        : {
            title: "Cuentas en la nube",
            tag: "servidor",
            big: peopleNum(sb("accounts_complete") ?? 0),
            bigSmall: "con sus finanzas en la nube",
            say: `Hay ${people(sb("accounts_complete") ?? 0, "cuenta", "cuentas")} con la nube encendida y ${people(sb("accounts_groups_only") ?? 0, "cuenta", "cuentas")} solo para Grupos.`,
          },
    ],
  };

  // ---------------------------------------------------------------- Pro (avisos de Apple, solo producción)
  const apple = (pred: (type: string, sub: string, offer: string) => boolean) =>
    rows.sum("server", W0, L, (d) => {
      const [name, type, sub, offer, env] = d.split("|");
      return name === "appstoreNotification" && env === "Production" && pred(type, sub, offer);
    });
  const anyApple = rows.all("server").some((r) => r.dim.startsWith("appstoreNotification|"));
  const trials = apple((t, _s, o) => t === "SUBSCRIBED" && o === "trial");
  const purchases = apple((t, _s, o) => t === "SUBSCRIBED" && o === "paid");
  const renewals = apple((t) => t === "DID_RENEW");
  const cancels = apple((t, s) => t === "DID_CHANGE_RENEWAL_STATUS" && s === "AUTO_RENEW_DISABLED");
  const refunds = apple((t) => t === "REFUND");
  const expired = apple((t) => t === "EXPIRED");
  const proUses = rows.on("use7", L).filter((r) => r.dim in PRO_FEATURES);
  const pro: Section = {
    id: "pro",
    title: "Pro",
    lead: anyApple
      ? [
          { t: "Esta semana empezaron " },
          { t: people(trials, "prueba", "pruebas"), b: true },
          { t: ` de Pro y hubo ${people(purchases, "compra", "compras")}.` },
        ]
      : [{ t: "Aún no llegan los avisos de compra de Apple: empiezan a contarse cuando el servidor con este cambio esté publicado." }],
    cards: [
      anyApple
        ? {
            title: "Pruebas, compras y bajas",
            tag: "servidor",
            bars: [
              { label: "Pruebas", value: trials, display: peopleNum(trials) },
              { label: "Compras", value: purchases, display: peopleNum(purchases) },
              { label: "Renovaciones", value: renewals, display: peopleNum(renewals) },
              { label: "Apagaron la renovación", value: cancels, display: peopleNum(cancels) },
              { label: "Vencieron", value: expired, display: peopleNum(expired) },
              { label: "Reembolsos", value: refunds, display: peopleNum(refunds) },
            ],
            say: `En 7 días: ${people(trials, "prueba", "pruebas")}, ${people(purchases, "compra", "compras")} y ${people(cancels + expired + refunds, "baja", "bajas")}.`,
            note: "Llega de los avisos que Apple manda al servidor de Yala en cada compra, renovación o baja. Cuántas pruebas pasan a pago no se puede separar de una renovación: no se pinta.",
          }
        : { title: "Pruebas, compras y bajas", tag: "sin datos", say: "Llega de los avisos que Apple manda al servidor de Yala." },
      ...proUses.map(
        (r): Card => ({
          title: label(PRO_FEATURES, r.dim),
          tag: "medido",
          big: peopleNum(r.value),
          bigSmall: "personas · 7 días",
          say: `${label(PRO_FEATURES, r.dim)}: ${people(r.value, "persona", "personas")} en la semana.`,
        }),
      ),
    ],
  };

  // ---------------------------------------------------------------- IA
  const okCalls = rows.sum("ai_calls", W0, L, (d) => d.endsWith("|ok"));
  const errCalls = rows.sum("ai_calls", W0, L, (d) => d.endsWith("|err"));
  const byTask = new Map<string, number>();
  for (const r of rows.all("ai_calls").filter((r) => within(r.day, W0, L))) {
    const task = r.dim.split("|")[0];
    byTask.set(task, (byTask.get(task) ?? 0) + r.value);
  }
  const cost = rows.sum("ai_cost_usd", W0, L);
  const unpriced = rows.sum("ai_unpriced", W0, L);
  const exhausted = rows.sum("server", W0, L, (d) => d.startsWith("aiQuotaExhausted|"));
  const exhaustedFree = rows.sum("server", W0, L, (d) => d.startsWith("aiQuotaExhausted|free|"));
  const anyAI = rows.all("ai_calls").length > 0;
  const ia: Section = {
    id: "ia",
    title: "IA",
    lead: [
      { t: "Esta semana Yala IA respondió " },
      { t: `${int(okCalls)} ${okCalls === 1 ? "vez" : "veces"}`, b: true },
      { t: errCalls > 0 ? `, y ${int(errCalls)} ${errCalls === 1 ? "llamada falló" : "llamadas fallaron"}.` : ", sin fallos." },
    ],
    cards: [
      anyAI
        ? {
            title: "Llamadas a la IA por tarea",
            tag: "medido",
            bars: bars([...byTask.entries()].map(([k, v]) => [label(TASK_LABELS, k), v]), int).slice(0, 8),
            say: "El servidor apunta cada llamada sin guardar lo que se preguntó.",
          }
        : { title: "Llamadas a la IA por tarea", tag: "sin datos", say: "Aún no hay llamadas registradas." },
      {
        title: "Costo de la semana",
        tag: "servidor",
        big: usd(cost),
        say:
          active7 > 0
            ? `La IA costó ${usd(cost)} esta semana, ${perPersonCents(cost / active7)} por persona activa.`
            : `La IA costó ${usd(cost)} esta semana.`,
        note:
          unpriced > 0
            ? `${int(unpriced)} llamadas de un modelo sin precio en panel/src/prices.ts no están sumadas.`
            : "Sale de los tokens de cada llamada y el precio de cada modelo. Las notas de voz se cobran por minuto y no entran.",
      },
      {
        title: "Llegaron al límite",
        tag: "servidor",
        big: peopleNum(exhausted),
        bigSmall: "veces en 7 días",
        say:
          exhausted === 0
            ? "Nadie gastó su último uso del cupo esta semana."
            : `${people(exhausted, "vez", "veces")} alguien gastó su último uso del cupo; ${people(exhaustedFree, "fue", "fueron")} del plan gratis (su prueba de voz o foto).`,
        note: "Una por persona y cupo: quien lo agota tres días cuenta tres.",
      },
    ],
  };

  // ---------------------------------------------------------------- Salud
  const canaries = rows.on("canary7", L).map((r) => ({ name: r.dim, n: r.value, devices: r.devices ?? 0, level: levelFor(r.dim, r.devices ?? 0) }));
  const signal = canaries.filter((c) => c.level !== "info");
  const red = signal.filter((c) => c.level === "bad");
  const amber = signal.filter((c) => c.level === "warn");
  const gwFails = rows
    .all("gw_canary")
    .filter((r) => within(r.day, W0, L) && r.dim !== "groupFanoutDelivered")
    .reduce((m, r) => m.set(r.dim, (m.get(r.dim) ?? 0) + r.value), new Map<string, number>());
  const salud: Section = {
    id: "salud",
    title: "Salud",
    lead: [
      { t: `${int(signal.length)} ${signal.length === 1 ? "aviso interno" : "avisos internos"}`, b: true },
      {
        t:
          ` ${signal.length === 1 ? "dio" : "dieron"} señal esta semana; ` +
          (red.length === 0 ? "ninguno pasa su umbral rojo." : `${int(red.length)} ${red.length === 1 ? "pasa" : "pasan"} su umbral rojo.`),
      },
    ],
    cards: [
      {
        title: "Los que más sonaron",
        tag: "medido",
        bars: [...signal]
          .sort((a, b) => b.n - a.n)
          .slice(0, 8)
          .map((c) => ({ label: label(CANARY_LABELS, c.name), value: c.n, display: int(c.n), level: c.level })),
        say: "Son avisos que la app deja cuando algo raro pasa por dentro. Sirven para cazar errores antes de que nadie escriba.",
        note: "Color por aparatos en la semana: ámbar desde 1, rojo desde 5 (umbrales en panel/src/health.ts).",
      },
      {
        title: "Estado",
        tag: "medido",
        bars: [...red, ...amber].slice(0, 8).map((c) => ({
          label: label(CANARY_LABELS, c.name),
          value: c.devices,
          display: peopleNum(c.devices),
          level: c.level,
        })),
        say:
          red.length + amber.length === 0
            ? "Todo en verde esta semana."
            : `${int(red.length)} ${red.length === 1 ? "aviso" : "avisos"} en rojo y ${int(amber.length)} en ámbar. La cifra de cada uno es de aparatos.`,
        note: "Los cuelgues siguen en Sentry; aquí va lo que Sentry no ve.",
      },
      {
        title: "Avisos del servidor",
        tag: "medido",
        bars: bars([...gwFails.entries()].map(([k, v]) => [label(CANARY_LABELS, k), v]), int),
        say: gwFails.size === 0 ? "El servidor no dio ningún aviso esta semana." : "Lo que el propio servidor apuntó como raro en la semana.",
      },
    ],
  };

  return {
    hasData: true,
    week: { from: W0, to: L, label: weekLabel(W0, L) },
    sections: [uso, registro, grupos, nube, pro, ia, salud],
  };
}
