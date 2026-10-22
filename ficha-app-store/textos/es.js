// Yala 2.1 · Textos de las capturas de la App Store (set B «Primer plano y objetos») y de la vista previa (vídeo).
// Idioma: es (Perú). Línea base extraída tal cual de:
//   capturas-app-store-final-v2-2026-10-13/_fuente/sets.js (TXT, PAGO_EJ y textos de los objetos)
//   capturas-app-store-final-v2-2026-10-13/_fuente/lamina.html (BOLETA y plantilla del pago)
//   assets-asc-2.1-2026-10-13/_fuente/preview/index.html (5 frases del vídeo)
// Misma forma en es.js, en.js y pt-BR.js: la plantilla multidioma carga un archivo por idioma.
// Funciona con <script src> (window.YALA_TEXTOS["es"]) y con require() en Node.
// Convenciones: <u>…</u> = palabra subrayada · <b>…</b> = negrita del chip · <small>…</small> = línea pequeña de la cifra.
const TEXTOS = {
  idioma: "es",
  moneda: {codigo: "PEN", simbolo: "S/", ejemplo: "S/ 1,284.50"},

  // [pill, titular, subtítulo | null]. Mismas claves y orden que TXT en sets.js (la clave «yape» se conserva por compatibilidad).
  TXT: {
    ia:      ["Yala IA · Pro", "Escríbele a Yala como a una <u>amiga</u>", null],
    foto:    ["Por foto · Pro", "Tómale <u>foto</u> a la boleta y listo", "Yala lee el comercio, la fecha y el total."],
    voz:     ["Por voz · Pro", "<u>Dilo</u> como te salga. Yala lo anota", "Sin teclear: lo dices y queda en su categoría."],
    yape:    ["Por captura · Pro", "Registra tus transferencias con una <u>captura</u>", "Yala saca el monto, el comercio y la fecha."],
    stats:   ["Estadísticas", "Mira a dónde se fue cada <u>sol</u>", "Categoría por categoría, sin abrir un Excel."],
    grupos:  ["Grupos", "Viaje a Cusco: las cuentas <u>claras</u> y la amistad intacta", null],
    presu:   ["Presupuestos", "¿Cuánto te <u>queda</u> este mes?", null],
    cuentas: ["Tus cuentas", "Todas tus cuentas, sin <u>conectar</u> tu banco", "Efectivo, tarjeta y ahorros en un solo panel. Tú decides qué anotas."],
    divisas: ["Multimoneda", "Soles y dólares, sin <u>calculadora</u>", "Cada cuenta en su moneda. Yala hace la conversión."],
    recor:   ["Recordatorios", "Te <u>avisamos</u> antes de cada pago", "Luz, teléfono, la cuota de la tarjeta: tú pones la fecha."],
  },

  // Textos dentro de los objetos dibujados, por captura (iguales en iPhone y en iPad salvo donde se indica).
  OBJ: {
    "01_ia":    {burbuja: "Gasté 45 en un taxi al aeropuerto y 120.50 en el súper"},
    "02_foto":  {boleta: {
      cab: ["BOLETA DE VENTA", "RESTAURANTE EL BUEN GUSTO"],
      peq: ["Miraflores · Lima", "30/03/2026 · 14:15 · Mesa 12"],
      items: [["1 Ceviche mixto", "48.00"], ["2 Lomo saltado", "84.00"], ["3 Cerveza artesanal", "42.00"], ["1 Jarra chicha morada", "20.00"]],
      totales: [["Subtotal", "S/ 194.00"], ["IGV 18 %", "S/ 34.92"], ["Propina 10 %", "S/ 22.89"]],
      total: ["TOTAL", "S/ 251.81"],
      pie: "¡Gracias por su visita!",
    }},
    "03_voz":   {burbuja: "«Almuerzo 25 con la tarjeta»"},
    "04_yape":  {
      // PAGO_EJ + plantilla PAGO de lamina.html. Captura genérica: sin nombre ni logo de ninguna billetera (guía 5.2).
      pago: {tit: "Transferencia realizada", monto: "S/ 35.00", a: "a Bodega Don Lucho",
             filas: [["Fecha", "13 oct. 2026"], ["Hora", "12:40"], ["N.º de operación", "04812736"]]},
      chip: "Compartir → <b>Yala</b>",
    },
    "05_stats": {
      cifra: "S/ 4,686<small>gastaste este mes</small>",
      chips: ["Hogar <b>47 %</b>", "Alimentación <b>28 %</b>", "Entretenimiento <b>8 %</b>", "Transporte <b>4 %</b>"],
    },
    "06_grupos": {
      tarjeta: {ico: "S/", t1: "Te deben", t2: "Viaje a Cusco · 3 personas", monto: "S/ 190.00"},
      chips: ["Mercado · Ana pagó <b>S/ 120</b>", "Almuerzo criollo · Beto pagó <b>S/ 180</b>"],
    },
    "07_presu": {
      cifra: "S/ 470<small>te quedan en Comidas fuera, para 19 días</small>",                     // iPhone
      tarjetaIpad: {ico: "S/", t1: "Te quedan S/ 470", t2: "Comidas fuera · 19 días", monto: "74 %"}, // iPad
    },
    "08_cuentas": {chips: ["Efectivo", "Tarjeta", "Ahorros en <b>US$</b>"]},
    "09_divisas": {
      cifra: "$ 33,615.00<small>en Ahorros USD, en su propia moneda</small>",                            // iPhone
      tarjetaIpad: {ico: "$", t1: "Ahorros USD", t2: "Ahorros · USD · Saldo", monto: "$ 33,615.00"},   // iPad
    },
    "10_recor": {tarjetas: [
      {ico: "!", t1: "Teléfono", t2: "En 2 días · Mensual", monto: "S/ 60.00"},
      {ico: "!", t1: "Spotify", t2: "En 5 días · Mensual", monto: "S/ 18.00"},
    ]},
  },

  // Vista previa (App Preview, 886×1920). Una frase por escena; cada línea es un .linea (nowrap).
  // Cada palabra separada por espacio va en <span class="w">; <u>…</u> = "w u" con su barra.
  // Un signo pegado tras </u> (el «.» del cierre) va en su propio <span class="w"> sin espacio, como en el original.
  VIDEO: {
    t0:     {acento: "azul",    pill: "Yala IA · Pro",   lineas: ["Escríbele como", "a una <u>amiga</u>"]},
    t1:     {acento: "rosa",    pill: "Por foto · Pro",  lineas: ["Tómale <u>foto</u>", "a la boleta"]},
    t2:     {acento: "teal",    pill: "Por voz · Pro",   lineas: ["<u>Dilo</u>", "como te salga"]},
    t3:     {acento: "violeta", pill: "Grupos · Gratis", lineas: ["Las cuentas <u>claras</u>", "en el viaje"]},
    cierre: {acento: "rosa",    pill: null,              lineas: ["Tus finanzas,", "sin <u>esfuerzo</u>."]},
  },
};
if (typeof module !== "undefined" && module.exports) module.exports = TEXTOS;
else (window.YALA_TEXTOS = window.YALA_TEXTOS || {})[TEXTOS.idioma] = TEXTOS;
