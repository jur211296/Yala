// Servidor de maqueta: sirve el build de webapp/dist/client y responde /api/* con datos de ejemplo.
// Solo para capturas locales. No toca producción ni staging.
import http from "node:http";
import fs from "node:fs";
import path from "node:path";

const DIST = process.argv[2];
const PORT = Number(process.argv[3] || 8787);
const SOLO_VACIO = process.env.VACIO === "1";

// Los gastos llegan con signo negativo, como los manda el núcleo (`buscar_movimientos`); hasta el lote 4 la maqueta los
// mandaba en positivo y la web los pintaba sin «−».
const mov = (id, fecha, importe, nota, tipo, categoria, subcategoria, cuenta, extra = {}) => {
  const v = tipo === "gasto" ? -importe : importe;
  return {
    id, fecha: fecha.slice(0, 10), importe: v, divisa: "PEN", importe_en_divisa_preferida: v, nota, tipo, categoria, subcategoria, cuenta,
    etiquetas: [], gasto_de_grupo: false, ...extra,
  };
};

// Lote 2: lo que manda el servidor con `apariencia` (ícono y color de la categoría, necesidad).
const LOOK = {
  "Comidas fuera": ["fork.knife", "#F59E0B", "esencial"],
  "Cafetería": ["cup.and.saucer.fill", "#F59E0B", "opcional"],
  "Taxi": ["car.fill", "#0EA5E9", "prioritaria"],
  "Supermercado": ["cart.fill", "#F59E0B", "esencial"],
  "Cine": ["film.fill", "#A855F7", "opcional"],
  "Sueldo": ["briefcase.fill", "#22C55E", "sin_clasificacion"],
  "Streaming": ["play.tv.fill", "#EC4899", "opcional"],
  "Veterinario": ["pawprint.fill", "#F97316", "esencial"],
  "Gasolina": ["fuelpump.fill", "#0EA5E9", "prioritaria"],
};
const conLook = (m) => {
  const [icono, color, necesidad] = LOOK[m.subcategoria] ?? [null, null, "sin_clasificacion"];
  return { ...m, categoria_id: "k-" + m.categoria, subcategoria_id: "s-" + m.subcategoria, cuenta_id: null, icono, color, necesidad };
};

const movimientos = [
  mov("m1", "2026-11-16T13:10:00Z", 38.5, "Almuerzo menú", "gasto", "Comida", "Comidas fuera", "Cuenta Principal"),
  mov("m2", "2026-11-16T09:20:00Z", 12.9, "Café y pan", "gasto", "Comida", "Cafetería", "Cuenta Principal"),
  mov("m3", "2026-11-15T20:40:00Z", 64.0, "Uber a casa", "gasto", "Transporte", "Taxi", "Tarjeta Visa", { etiquetas: ["Trabajo"] }),
  mov("m4", "2026-11-15T11:05:00Z", 212.3, "Plaza Vea", "gasto", "Comida", "Supermercado", "Tarjeta Visa"),
  mov("m5", "2026-11-14T18:00:00Z", 45.0, "Cine con Ana", "gasto", "Ocio", "Cine", "Cuenta Principal", { gasto_de_grupo: true, etiquetas: ["Compartido"] }),
  mov("m6", "2026-11-14T08:30:00Z", 8500, "Sueldo noviembre", "ingreso", "Ingresos", "Sueldo", "Cuenta Principal"),
  mov("m7", "2026-11-13T16:45:00Z", 89.9, "Netflix + Spotify", "gasto", "Suscripciones", "Streaming", "Tarjeta Visa", { etiquetas: ["Fijo"] }),
  mov("m8", "2026-11-12T10:15:00Z", 137.0, "Veterinaria Maia", "gasto", "Mascotas", "Veterinario", "Cuenta Principal"),
  mov("m9", "2026-11-11T19:30:00Z", 72.4, "Pollo a la brasa", "gasto", "Comida", "Comidas fuera", "Tarjeta Visa"),
  mov("m10", "2026-11-10T07:50:00Z", 150.0, "Recarga gasolina", "gasto", "Transporte", "Gasolina", "Tarjeta Visa"),
].map(conLook);

const cuentas = [
  { id: "c1", nombre: "Cuenta Principal", tipo: "corriente", divisa: "PEN", saldo: 12840.65, archivada: false, excluida_de_estadisticas: false, icono: "building.columns.fill", color: "#6366F1" },
  { id: "c2", nombre: "Ahorros USD", tipo: "ahorro", divisa: "USD", saldo: 26183.0, archivada: false, excluida_de_estadisticas: false, icono: "banknote", color: "#16A34A" },
  { id: "c3", nombre: "Tarjeta Visa", tipo: "credito", divisa: "PEN", saldo: -1420.3, archivada: false, excluida_de_estadisticas: false, icono: "creditcard.fill", color: "#FF0080" },
  { id: "c4", nombre: "Efectivo", tipo: "efectivo", divisa: "PEN", saldo: 320.0, archivada: false, excluida_de_estadisticas: false, icono: "banknote.fill", color: "#F59E0B" },
];

const top = [
  { categoria: "Comida", importe: 1461, movimientos: 18 },
  { categoria: "Fijos casa", importe: 2453, movimientos: 4 },
  { categoria: "Transporte", importe: 642.5, movimientos: 11 },
  { categoria: "Cuidado personal", importe: 512, movimientos: 3 },
  { categoria: "Ocio", importe: 391.4, movimientos: 6 },
];

const trozos = top.map((t, i) => ({ id: "k" + i, categoria: t.categoria, importe: t.importe, porcentaje: Math.round((t.importe / 5960) * 1000) / 10, movimientos: t.movimientos }));

const datos = {
  "/api/me": { nombre: "Jürgen", correo: "jurgen@ejemplo.pe", equipoCompartido: false },
  "/api/panel": {
    cuentas: { cuentas, total: { divisa: "PEN", importe: 55997.65, aproximado: true } },
    mes: { divisa: "PEN", ingresos: 8500, gastos: 5960, aproximado: false, top_categorias_gasto: top },
    ultimos: { movimientos: movimientos.slice(0, 6) },
  },
  "/api/registros": { movimientos, siguiente_cursor: null, avisos: [], divisa_preferida: "PEN" },
  // Con ícono y color (lote 2), para que Distribución del Panel y las sugerencias de Nuevo registro salgan como en la app.
  "/api/categorias": {
    categorias: [
      { id: "k1", nombre: "Comida", es_ingreso: false, oculta: false, icono: "fork.knife", color: "#F59E0B", subcategorias: [{ id: "s-Comidas fuera", nombre: "Comidas fuera", oculta: false, icono: "fork.knife", color: null }, { id: "s-Supermercado", nombre: "Supermercado", oculta: false, icono: "cart.fill", color: null }, { id: "s-Cafetería", nombre: "Cafetería", oculta: false, icono: "cup.and.saucer.fill", color: null }] },
      { id: "k2", nombre: "Transporte", es_ingreso: false, oculta: false, icono: "car.fill", color: "#0EA5E9", subcategorias: [{ id: "s-Taxi", nombre: "Taxi", oculta: false, icono: "car.fill", color: null }, { id: "s-Gasolina", nombre: "Gasolina", oculta: false, icono: "fuelpump.fill", color: null }] },
      { id: "k3", nombre: "Fijos casa", es_ingreso: false, oculta: false, icono: "house.fill", color: "#475569", subcategorias: [{ id: "s-Alquiler", nombre: "Alquiler", oculta: false, icono: "house.fill", color: null }] },
      { id: "k4", nombre: "Cuidado personal", es_ingreso: false, oculta: false, icono: "person.fill", color: "#A855F7", subcategorias: [{ id: "s-Gimnasio", nombre: "Gimnasio", oculta: false, icono: "dumbbell.fill", color: null }] },
      { id: "k5", nombre: "Ocio", es_ingreso: false, oculta: false, icono: "film.fill", color: "#D946EF", subcategorias: [{ id: "s-Cine", nombre: "Cine", oculta: false, icono: "film.fill", color: null }] },
      { id: "k6", nombre: "Ingresos", es_ingreso: true, oculta: false, icono: "briefcase.fill", color: "#22C55E", subcategorias: [{ id: "s-Sueldo", nombre: "Sueldo", oculta: false, icono: "briefcase.fill", color: null }] },
    ],
  },
  "/api/bandeja": {
    pendientes: [
      { sync_id: "p1", note: "Farmacia Inkafarma", amount: 46.8, date: "2026-11-16", cached_currency_code: "PEN", cached_account_name: "Tarjeta Visa", cached_subcategory_name: null, source_type_raw: "email", evidence: null, created_at: "2026-11-16T10:00:00Z", needs_user_input: ["category"] },
      { sync_id: "p2", note: "Rappi pedido", amount: 58.9, date: "2026-11-15", cached_currency_code: "PEN", cached_account_name: "Tarjeta Visa", cached_subcategory_name: "Comidas fuera", source_type_raw: "notification", evidence: null, created_at: "2026-11-15T21:00:00Z", needs_user_input: null },
    ],
    enviados: [
      { id: "e1", enviado: Date.parse("2026-11-16T15:00:00Z"), tipo: "gasto", importe: 25, divisa: "PEN", descripcion: "Estacionamiento", fecha: "2026-11-16", cuenta: "Efectivo", subcategoria: null },
    ],
  },
  "/api/presupuestos": {
    avisos: [],
    presupuestos: [
      { id: "b1", nombre: "Comidas fuera", divisa: "PEN", limite: 1800, gastado: 1461, porcentaje: 81, restante: 339, periodo: { tipo: "mensual", desde: "2026-11-01", hasta: "2026-11-30" }, dias_restantes: 15, estado: "en_riesgo", activo: true, movimientos: 18, aproximado: false },
      { id: "b2", nombre: "Cuidado personal", divisa: "PEN", limite: 800, gastado: 512, porcentaje: 64, restante: 288, periodo: { tipo: "mensual", desde: "2026-11-01", hasta: "2026-11-30" }, dias_restantes: 15, estado: "en_camino", activo: true, movimientos: 3, aproximado: false },
      { id: "b3", nombre: "Fijos casa", divisa: "PEN", limite: 3200, gastado: 2453, porcentaje: 77, restante: 747, periodo: { tipo: "mensual", desde: "2026-11-01", hasta: "2026-11-30" }, dias_restantes: 15, estado: "en_camino", activo: true, movimientos: 4, aproximado: false },
      { id: "b4", nombre: "Maia", divisa: "PEN", limite: 500, gastado: 137, porcentaje: 27, restante: 363, periodo: { tipo: "mensual", desde: "2026-11-01", hasta: "2026-11-30" }, dias_restantes: 15, estado: "en_camino", activo: true, movimientos: 1, aproximado: false },
      { id: "b5", nombre: "Ocio", divisa: "PEN", limite: 350, gastado: 391.4, porcentaje: 112, restante: -41.4, periodo: { tipo: "mensual", desde: "2026-11-01", hasta: "2026-11-30" }, dias_restantes: 15, estado: "excedido", activo: true, movimientos: 6, aproximado: false },
    ],
  },
  "/api/pagos": {
    divisa: "PEN", total_gastos: 3254.9, pagados: 1, aproximado: false, incompleto: false, suscripciones_mensual: 89.9,
    proximos: [
      { id: "q1", nombre: "Alquiler depa", dia: "2026-11-17", en_dias: 1, importe: 2400, divisa: "PEN", importe_en_divisa_preferida: 2400, movimiento: "gasto", tipo: "recurrente", frecuencia: "mensual", cada: 1, categoria: "Fijos casa", pagado: false },
      { id: "q2", nombre: "Luz del Sur", dia: "2026-11-20", en_dias: 4, importe: 165, divisa: "PEN", importe_en_divisa_preferida: 165, movimiento: "gasto", tipo: "recurrente", frecuencia: "mensual", cada: 1, categoria: "Fijos casa", pagado: false },
      { id: "q3", nombre: "Netflix", dia: "2026-11-24", en_dias: 8, importe: 44.9, divisa: "PEN", importe_en_divisa_preferida: 44.9, movimiento: "gasto", tipo: "suscripcion", frecuencia: "mensual", cada: 1, categoria: "Suscripciones", pagado: false },
      { id: "q4", nombre: "Gimnasio", dia: "2026-11-28", en_dias: 12, importe: 645, divisa: "PEN", importe_en_divisa_preferida: 645, movimiento: "gasto", tipo: "recurrente", frecuencia: "mensual", cada: 1, categoria: "Cuidado personal", pagado: false },
    ],
    suscripciones: [
      { id: "s1", nombre: "Netflix", importe: 44.9, divisa: "PEN", frecuencia: "mensual", cada: 1, proximo_cobro: "2026-11-24", equivalente_mensual_en_divisa_preferida: 44.9, categoria: "Suscripciones" },
      { id: "s2", nombre: "Spotify", importe: 45, divisa: "PEN", frecuencia: "mensual", cada: 1, proximo_cobro: "2026-12-02", equivalente_mensual_en_divisa_preferida: 45, categoria: "Suscripciones" },
    ],
  },
  "/api/grupos": {
    resumen: { teDeben: [{ divisa: "PEN", importe: 486.5 }], debes: [{ divisa: "PEN", importe: 120 }], pagosPorConfirmar: 1 },
    incompleto: false,
    grupos: [
      { id: "g1", nombre: "Viaje a Cusco", icono: "airplane", color: "#0EA5E9", divisa: "PEN", archivado: false, miembros: 4, gastos: 23, banda: { estado: "theyOweMe", teDeben: [{ divisa: "PEN", importe: 486.5 }], debes: [] }, personas: [{ nombre: "Ana", sentido: "teDebe", importe: 212.5, divisa: "PEN" }, { nombre: "Luis", sentido: "teDebe", importe: 274, divisa: "PEN" }] },
      { id: "g2", nombre: "Depa Miraflores", icono: "house", color: "#8B5CF6", divisa: "PEN", archivado: false, miembros: 3, gastos: 41, banda: { estado: "iOwe", teDeben: [], debes: [{ divisa: "PEN", importe: 120 }] }, personas: [{ nombre: "Carla", sentido: "debes", importe: 120, divisa: "PEN" }] },
      { id: "g3", nombre: "Cumple de Maia", icono: "gift", color: "#EC4899", divisa: "PEN", archivado: false, miembros: 5, gastos: 6, banda: { estado: "settled", teDeben: [], debes: [] }, personas: [] },
    ],
  },
  "/api/grupos/detalle": {
    id: "g1", nombre: "Viaje a Cusco", divisa: "PEN", archivado: false, incompleto: false, menosPagos: true, unaSolaMoneda: "PEN",
    miembros: [{ clave: "a", nombre: "Tú", rol: "owner", esTu: true }, { clave: "b", nombre: "Ana", rol: "member", esTu: false }, { clave: "c", nombre: "Luis", rol: "member", esTu: false }, { clave: "d", nombre: "Sofía", rol: "member", esTu: false }],
    banda: { estado: "theyOweMe", teDeben: [{ divisa: "PEN", importe: 486.5 }], debes: [] },
    puedeEscribir: true, puedeInvitar: true, divisas: ["PEN", "USD"],
    deudas: [
      { de: "Ana", a: "Tú", deClave: "b", aClave: "a", deTi: false, aTi: true, importe: 212.5, divisa: "PEN" },
      { de: "Luis", a: "Tú", deClave: "c", aClave: "a", deTi: false, aTi: true, importe: 274, divisa: "PEN" },
    ],
    saldos: [
      { nombre: "Tú", esTu: true, divisa: "PEN", pago: 1840, leToca: 1353.5, neto: 486.5 },
      { nombre: "Ana", esTu: false, divisa: "PEN", pago: 1141, leToca: 1353.5, neto: -212.5 },
      { nombre: "Luis", esTu: false, divisa: "PEN", pago: 1079.5, leToca: 1353.5, neto: -274 },
      { nombre: "Sofía", esTu: false, divisa: "PEN", pago: 1353.5, leToca: 1353.5, neto: 0 },
    ],
    gastos: [
      { id: "x1", descripcion: "Hotel en San Blas", nota: null, importe: 1260, divisa: "PEN", fecha: "2026-11-08", pagadoPor: "Tú", pagasteTu: true, tuParte: 315, categoria: "Alojamiento", saldoInicial: false, saldado: false },
      { id: "x2", descripcion: "Tren a Machu Picchu", nota: null, importe: 1980, divisa: "PEN", fecha: "2026-11-09", pagadoPor: "Ana", pagasteTu: false, tuParte: 495, categoria: "Transporte", saldoInicial: false, saldado: false },
      { id: "x3", descripcion: "Cena en Cicciolina", nota: null, importe: 420, divisa: "PEN", fecha: "2026-11-09", pagadoPor: "Luis", pagasteTu: false, tuParte: 105, categoria: "Comida", saldoInicial: false, saldado: false },
    ],
    pagos: [{ id: "y1", de: "Sofía", a: "Tú", deTi: false, aTi: true, importe: 150, divisa: "PEN", fecha: "2026-11-12", confirmado: false, nota: null }],
  },
  "/api/sesiones": {
    sesiones: [
      { id: "s1", navegador: "Chrome", sistema: "macOS", ciudad: "Lima", creada: Date.parse("2026-11-16T15:00:00Z"), ultimoUso: Date.now(), equipoCompartido: false, esta: true },
      { id: "s2", navegador: "Safari", sistema: "iOS", ciudad: "Lima", creada: Date.parse("2026-11-14T15:00:00Z"), ultimoUso: Date.parse("2026-11-15T15:00:00Z"), equipoCompartido: false, esta: false },
    ],
  },
};

const tend = ["2026-06", "2026-07", "2026-08", "2026-09", "2026-10", "2026-11"].map((mes, i) => {
  const g = [6120, 5480, 6890, 5730, 6240, 5960][i];
  const ing = [8500, 8500, 9100, 8500, 8500, 8500][i];
  return { mes, desde: mes + "-01", hasta: mes + "-28", ingresos: ing, gastos: g, neto: ing - g };
});
datos["/api/estadisticas"] = {
  periodo: "mes_actual",
  resumen: {
    divisa: "PEN", periodo: { desde: "2026-11-01", hasta: "2026-11-16" }, ingresos: 8500, gastos: 5960, neto: 2540, movimientos: 49,
    variacion: { ingresos: 0, gastos: 0.13, neto: -0.12, gasto_medio_diario: 0.05 }, gasto_medio_diario: 372.5, dias: 16, top_categorias: trozos,
    gasto_mas_alto: { importe: 2400, nota: "Alquiler depa", categoria: "Fijos casa", dia: "2026-11-01" }, aproximado: { ingresos: false, gastos: false, neto: false }, sin_categoria: 0,
  },
  distribucion: { divisa: "PEN", total: 5960, categorias: trozos },
  tendencias: tend,
  incompleto: false,
};

const tipos = { ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".css": "text/css", ".svg": "image/svg+xml", ".png": "image/png", ".ico": "image/x-icon", ".json": "application/json", ".webmanifest": "application/manifest+json" };

http.createServer((req, res) => {
  const url = new URL(req.url, "http://x");
  if (url.pathname.startsWith("/api/")) {
    const body = datos[url.pathname];
    if (body === undefined) { res.writeHead(200, { "Content-Type": "application/json" }); res.end("{}"); return; }
    let out = body;
    if (SOLO_VACIO && url.pathname === "/api/panel") out = { ...body, ultimos: { movimientos: [] } };
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify(out));
    return;
  }
  // El marco de 390 px de las capturas de celular vive junto a este servidor, no en el build: sin esto caía en
  // index.html y toda captura de celular salía con el Panel (medido en el lote 2).
  if (url.pathname === "/marco.html") {
    res.writeHead(200, { "Content-Type": tipos[".html"] });
    fs.createReadStream(new URL("./marco.html", import.meta.url)).pipe(res);
    return;
  }
  let file = path.join(DIST, url.pathname);
  if (!file.startsWith(DIST) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) file = path.join(DIST, "index.html");
  res.writeHead(200, { "Content-Type": tipos[path.extname(file)] || "application/octet-stream" });
  fs.createReadStream(file).pipe(res);
}).listen(PORT, () => console.log("maqueta en http://localhost:" + PORT));
