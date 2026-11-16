// BORRADOR para Lola (Frank, 4-nov-2026): en-GB adaptado de en.js (de Lola) a libras, ortografía británica y un recibo
// de Londres. Las cifras salen de la semilla en libras (DevSeedFicha.cifras «GBP»).
// Yala 2.1 · App Store screenshot texts (set B "Close-up and objects") and App Preview (video).
// Language: en-GB (adapted from en-US). Adapted from es.js (not a literal translation). Same shape and keys as es.js.
// Feature names follow the app's en UI on origin/2.1: Yala AI, Statistics, Groups, Budgets, Your accounts, Reminders,
// categories Housing / Food / Entertainment / Transport, "Owed to you", "Eating Out", "Monthly", Cash / Savings.
// Currency: GBP, UK formatting (£1,284.50). No Peru-only content (no Yape/Plin, soles, Cusco, boleta, menú).
const TEXTOS = {
  idioma: "en-GB",
  moneda: {codigo: "GBP", simbolo: "£", ejemplo: "£1,284.50"},

  TXT: {
    ia:      ["Yala AI · Pro", "Message Yala like a <u>friend</u>", null],
    foto:    ["Photo · Pro", "<u>Snap</u> the receipt and you're done", "Yala reads the merchant, date and total."],
    voz:     ["Voice · Pro", "<u>Say</u> it your way. Yala logs it", "No typing: say it and it lands in its category."],
    yape:    ["Screenshot · Pro", "Log your transfers with a <u>screenshot</u>", "Yala picks out the amount, merchant and date."],
    stats:   ["Statistics", "See where every <u>pound</u> went", "Category by category, no spreadsheet needed."],
    grupos:  ["Groups", "Lisbon trip: bills <u>settled</u>, friendship intact", null],
    presu:   ["Budgets", "What's <u>left</u> this month?", null],
    cuentas: ["Your accounts", "All your accounts. No bank <u>linking</u>.", "Cash, cards and savings on one screen. You decide what to log."],
    divisas: ["Multi-currency", "50+ currencies, no <u>calculator</u>", "Each account in its own currency. Yala converts."],
    recor:   ["Reminders", "We <u>remind</u> you before every bill", "Electricity, phone, your card payment: you set the date."],
  },

  OBJ: {
    "01_ia":    {burbuja: "Spent 45 on a taxi to the airport and 120.50 on groceries"},
    "02_foto":  {boleta: {
      cab: ["RECEIPT", "BLUE DOOR BISTRO"],
      peq: ["Islington · London", "30/03/2026 · 14:15 · Table 12"],
      items: [["1 Fish and chips", "18.95"], ["2 Steak and ale pie", "37.90"], ["3 Pint of bitter", "17.85"], ["2 Sticky toffee pudding", "18.91"]],
      totales: [["Subtotal", "£93.61"], ["incl. VAT 20%", "£15.60"], ["Service 12.5%", "£11.70"]],
      total: ["TOTAL", "£105.31"],
      pie: "Thank you, see you soon!",
    }},
    "03_voz":   {burbuja: "“Lunch, 25, on my card”"},
    "04_yape":  {
      // Generic bank transfer receipt: no wallet or bank name, no logo (guideline 5.2).
      pago: {tit: "Transfer sent", monto: "£35.00", a: "to Corner Shop",
             filas: [["Date", "13 Oct 2026"], ["Time", "12:40"], ["Reference", "04812736"]]},
      chip: "Share → <b>Yala</b>",
    },
    "05_stats": {
      cifra: "£4,686<small>spent this month</small>",
      chips: ["Housing <b>47%</b>", "Food <b>28%</b>", "Entertainment <b>8%</b>", "Transport <b>4%</b>"],
    },
    "06_grupos": {
      tarjeta: {ico: "£", t1: "Owed to you", t2: "Lisbon trip · 3 people", monto: "£190.00"},
      chips: ["Groceries · Ana paid <b>£120</b>", "Seafood dinner · Ben paid <b>£180</b>"],
      // BORRADOR para Lola (Frank, 4-nov-2026): desde la 2.2 el iPhone enseña la LISTA de Grupos; son sus filas del viaje.
      chipsLista: ["Ben owes you <b>£110</b>", "Ana owes you <b>£80</b>"],
    },
    "07_presu": {
      cifra: "£470<small>left for Eating Out, with 19 days to go</small>",
      tarjetaIpad: {ico: "£", t1: "£470 left", t2: "Eating Out · 19 days", monto: "74%"},
    },
    "08_cuentas": {chips: ["Cash", "Card", "Savings in <b>€</b>"]},
    "09_divisas": {
      cifra: "€1,850.00<small>in Travel EUR, in its own currency</small>",
      tarjetaIpad: {ico: "€", t1: "Travel EUR", t2: "Savings · EUR · Balance", monto: "€1,850.00"},
    },
    "10_recor": {tarjetas: [
      {ico: "!", t1: "Phone", t2: "In 2 days · Monthly", monto: "£18.00"},
      {ico: "!", t1: "Spotify", t2: "In 5 days · Monthly", monto: "£11.99"},
    ]},
  },

  VIDEO: {
    t0:     {acento: "azul",    pill: "Yala AI · Pro", lineas: ["Text Yala like", "a <u>friend</u>"]},
    t1:     {acento: "rosa",    pill: "Photo · Pro",   lineas: ["Snap a <u>photo</u>", "of the receipt"]},
    t2:     {acento: "teal",    pill: "Voice · Pro",   lineas: ["<u>Say</u> it", "your way"]},
    t3:     {acento: "violeta", pill: "Groups · Free", lineas: ["Trip costs,", "all <u>square</u>"]},
    cierre: {acento: "rosa",    pill: null,            lineas: ["Your finances,", "<u>effortlessly</u>."]},
  },
};
if (typeof module !== "undefined" && module.exports) module.exports = TEXTOS;
else (window.YALA_TEXTOS = window.YALA_TEXTOS || {})[TEXTOS.idioma] = TEXTOS;
