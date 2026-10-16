// Set de capturas de la App Store (set B «Primer plano y objetos»), para cualquier idioma de textos/<idioma>.js.
// El teléfono se acerca y se corta, y lo que vende sale de la pantalla como objeto (la frase, la boleta, la cifra).
// Navy liso: cero brillo, cero glow, cero degradado de color. Pantallas oscuras, Pro en la pill, logo arriba a la derecha.
// Coordenadas: iPhone en un lienzo de 1320 de ancho (alto 2868 en 6,9" y 2856 en 6,5"); iPad en 2064×2752.
//
// Aquí solo vive la composición. Todo lo que se lee sale de los textos de Lola (TX.TXT y TX.OBJ): nada de cifras ni
// monedas escritas a mano. Lo que un idioma necesite distinto de composición (un titular más largo, una cifra más ancha)
// va en AJUSTES[idioma], nunca en los textos.
//
// Se carga en el navegador (lamina.html) y en Node (render.sh cuenta las láminas): construirSets(TX, idioma) → SETS.
function construirSets(TX, idioma) {
const O = TX.OBJ;
const T = (pillTxt, titular, subTxt, extra) => Object.assign({k: "texto", pillTxt, titular, subTxt}, extra);
const P = (img, w, pos, t, extra) => Object.assign({k: "phone", img, w, pos, t}, extra);
const TAB = (img, w, pos, t, extra) => Object.assign({k: "tablet", img, w, pos, t}, extra);

// Los textos son los mismos en iPhone y en iPad; solo cambia la composición.
const t = (k, extra) => T(TX.TXT[k][0], TX.TXT[k][1], TX.TXT[k][2], extra);
// Un chip de OBJ por índice; el tamaño y el giro son de la composición.
const chip = (html, pos, estilo, extra) => Object.assign({k: "chip", pos, estilo, html}, extra);
const tarjeta = (o, extra) => Object.assign({k: "tarjeta", ico: o.ico, t1: o.t1, t2: o.t2, monto: o.monto}, extra);
// Ajustes de composición por idioma: {iphone: {n: {...}}, ipad: {...}} se funden sobre la lámina n (1…10).
const aj = (AJUSTES[idioma] || {});

const LOGO = {right: 84, top: 132, width: 150};
const SETS = {};

// ─────────────────────────────────────────────────────────────────────────────
// iPhone · 10 capturas, en orden de conversión. Las tres primeras son las que salen en la búsqueda.
SETS.iphone = {
// Estrellas por defecto (las láminas que lo necesitan traen las suyas): en los márgenes, lejos del texto.
estrellas: [[1150, 470, 72, "rosa", -8], [50, 1560, 54, "teal", 12], [1200, 1700, 48, "azul", -14], [80, 2650, 60, "teal", 6]],
laminas: [
// 01 · Yala IA · la frase que escribes sale de la pantalla
{ logo: LOGO, acento: "azul", els: [
  t("ia", {pos: {left: 90, top: 150, width: 1140}}),
  {k: "burbuja", c: "#6164EB", pos: {left: 110, top: 600, width: 1100}, estilo: {"font-size": 62, padding: "48px 60px", "line-height": "1.22", transform: "rotate(-2deg)", "--cola": "880px"},
   html: O["01_ia"].burbuja},
  P("s-ia.png", 1060, {left: 80, top: 1010}, "rotateZ(3deg)"),
]},
// 02 · Por foto · la boleta en papel
{ logo: LOGO, acento: "rosa", els: [
  t("foto", {pos: {left: 90, top: 150, width: 1140}}),
  {k: "boleta", b: O["02_foto"].boleta, pos: {left: 60, top: 820, width: 700}, estilo: {"font-size": 31, padding: "70px 46px", transform: "rotate(-7deg)"}},
  P("s-foto.png", 780, {left: 560, top: 1180}, "rotateZ(8deg)", {foco: "bottom"}),
]},
// 03 · Por voz · el teléfono baja del borde y la frase dicha queda en el aire
{ logo: {right: 84, bottom: 84, width: 160}, acento: "teal", els: [
  P("s-voz-uno.png", 1000, {left: 150, top: -700}, "rotateZ(-4deg)"),
  {k: "burbuja", c: "#1E2A48", pos: {left: 90, top: 1520}, estilo: {"font-size": 60, padding: "40px 56px", transform: "rotate(-2deg)", border: "2px solid rgba(255,255,255,.18)", "white-space": "nowrap"},
   html: O["03_voz"].burbuja},
  {k: "onda", pos: {left: 100, top: 1800}, ancho: 22, hueco: 16, alturas: [40, 80, 140, 200, 120, 70, 160, 220, 130, 60, 110, 180, 90, 50, 120, 70]},
  t("voz", {pos: {left: 90, top: 2030, width: 1140}, subw: 900}),
]},
// 04 · Por captura · la captura de la transferencia, en grande, entra en la hoja de Yala
{ logo: LOGO, acento: "violeta", els: [
  t("yape", {pos: {left: 90, top: 150, width: 1140}, subw: 1000}),
  {k: "disco", c: "var(--violeta)", pos: {left: 640, top: 1500, width: 1100, height: 1100}},
  P("s-yape-origen.png", 820, {left: 470, top: 1060}, "rotateY(-22deg) rotateX(6deg) rotateZ(5deg)", {foco: "bottom"}),
  {k: "pago", m: O["04_yape"].pago, pos: {left: 70, top: 900, width: 640}, estilo: {"font-size": 40, padding: "56px 50px 44px", transform: "rotate(-6deg)"}},
  chip(O["04_yape"].chip, {left: 120, top: 1880}, {"font-size": 46, padding: "24px 42px", transform: "rotate(-4deg)"}, {acento: "violeta"}),
]},
// 05 · Estadísticas · el gasto del mes en grande y las categorías que salen de la gráfica
{ logo: LOGO, acento: "rosa", els: [
  t("stats", {pos: {left: 90, top: 150, width: 1140}}),
  {k: "cifra", pos: {left: 0, right: 0, top: 860}, estilo: {"font-size": 250, "text-align": "center"}, html: O["05_stats"].cifra},
  chip(O["05_stats"].chips[0], {left: 80, top: 690}, {"font-size": 46, padding: "22px 40px", transform: "rotate(-6deg)"}),
  chip(O["05_stats"].chips[1], {right: 90, top: 700}, {"font-size": 46, padding: "22px 40px", transform: "rotate(5deg)"}),
  chip(O["05_stats"].chips[2], {left: 110, top: 1250}, {"font-size": 42, padding: "20px 36px", transform: "rotate(4deg)"}),
  chip(O["05_stats"].chips[3], {right: 120, top: 1270}, {"font-size": 42, padding: "20px 36px", transform: "rotate(-5deg)"}),
  P("s-estadisticas-grafica.png", 960, {left: 180, top: 1380}, "rotateX(32deg) rotateZ(-6deg)"),
]},
// 06 · Grupos · el teléfono tumbado sobre la mesa y lo que te deben, encima
{ logo: LOGO, acento: "teal", els: [
  t("grupos", {pos: {left: 90, top: 150, width: 1140}, tit: 112}),
  P("s-grupo.png", 1000, {left: 170, top: 820}, "rotateX(36deg) rotateZ(-24deg)"),
  tarjeta(O["06_grupos"].tarjeta, {pos: {left: 90, width: 1140, top: 1000}, estilo: {transform: "rotate(-3deg)"}, escala: 1.3, icoC: "#3BD6F0"}),
  chip(O["06_grupos"].chips[0], {left: 600, top: 2180}, {"font-size": 44, padding: "24px 40px", transform: "rotate(4deg)"}),
  chip(O["06_grupos"].chips[1], {left: 80, top: 2460}, {"font-size": 44, padding: "24px 40px", transform: "rotate(-5deg)"}),
]},
// 07 · Presupuestos · lo que queda, en grande (Maia queda fuera del lienzo)
{ logo: LOGO, acento: "azul", els: [
  t("presu", {pos: {left: 90, top: 150, width: 1140}}),
  {k: "cifra", pos: {left: 90, top: 560}, estilo: {"font-size": 250}, html: O["07_presu"].cifra},
  P("s-presupuestos.png", 1000, {left: 200, top: 1180}, "rotateZ(-3deg)"),
]},
// 08 · Tus cuentas · de frente, con «Tus finanzas» desplegado: efectivo y tarjeta en el carrusel, cada chip junto a la
// suya (16-oct-2026, revisión de Lola); el de ahorro, sobre la tendencia. La estrella de abajo sube: el chip la tapaba.
{ logo: LOGO, acento: "violeta", estrellas: [[1150, 470, 72, "rosa", -8], [50, 1560, 54, "teal", 12], [1200, 1700, 48, "azul", -14], [70, 2780, 60, "teal", 6]], els: [
  t("cuentas", {pos: {left: 90, top: 150, width: 1140}, subw: 1060}),
  P("s-panel.png", 820, {left: 230, top: 1050}),
  chip(O["08_cuentas"].chips[0], {left: 50, top: 2215}, {"font-size": 46, padding: "22px 40px", transform: "rotate(-6deg)"}),
  chip(O["08_cuentas"].chips[1], {right: 50, top: 1800}, {"font-size": 46, padding: "22px 40px", transform: "rotate(5deg)"}),
  chip(O["08_cuentas"].chips[2], {left: 70, top: 2600}, {"font-size": 46, padding: "22px 40px", transform: "rotate(4deg)"}),
]},
// 09 · Multimoneda · el saldo de la cuenta en divisa extranjera, sacado de la app
{ logo: LOGO, acento: "rosa", els: [
  t("divisas", {pos: {left: 90, top: 150, width: 1140}, subw: 1000}),
  {k: "cifra", pos: {left: 90, top: 760}, estilo: {"font-size": 196, "white-space": "nowrap"}, html: O["09_divisas"].cifra},
  {k: "barra", c: "var(--rosa)", pos: {left: -200, top: 2060, width: 1900, height: 170, transform: "rotate(-11deg)"}},
  P("s-divisas.png", 860, {left: 330, top: 1260}, "rotateY(-20deg) rotateZ(6deg)", {foco: "bottom"}),
]},
// 10 · Recordatorios · los avisos salen de la lista como tarjetas
{ logo: LOGO, acento: "teal", els: [
  t("recor", {pos: {left: 90, top: 150, width: 1140}, subw: 1000}),
  P("s-programados.png", 900, {left: -120, top: 960}, "rotateY(28deg) rotateZ(-3deg)", {foco: "0 -200px"}),
  tarjeta(O["10_recor"].tarjetas[0], {pos: {left: 440, width: 840, top: 1240}, estilo: {transform: "rotate(-4deg)"}, escala: 1.15, icoC: "#8B5CF6"}),
  tarjeta(O["10_recor"].tarjetas[1], {pos: {left: 500, width: 780, top: 1560}, estilo: {transform: "rotate(3deg)"}, escala: 1.1, icoC: "#FF2D78"}),
]},
]};

// ─────────────────────────────────────────────────────────────────────────────
// iPad 13" · el mismo set y los mismos textos, en un lienzo de 2064×2752 y con pantallas del iPad
// (Apple no admite marcos de iPhone en las capturas de iPad). Las pantallas son las de 2.1: barra superior,
// Yala IA como columna lateral y listas con detalle al lado.
const TI = (k, extra) => t(k, Object.assign({pill: 54, tit: 156, sub: 64, gap: 50, pos: {left: 130, top: 190, width: 1650}}, extra));
const LOGO_I = {right: 130, top: 190, width: 220};
SETS.ipad = {
estrellas: [[1860, 560, 96, "rosa", -8], [80, 1150, 70, "teal", 12], [1940, 2250, 64, "azul", -14], [110, 2560, 80, "teal", 6]],
laminas: [
// 01 · Yala IA
{ logo: LOGO_I, acento: "azul", els: [
  TI("ia"),
  {k: "burbuja", c: "#6164EB", pos: {left: 160, top: 720, width: 1560}, estilo: {"font-size": 84, padding: "60px 80px", "line-height": "1.2", transform: "rotate(-2deg)", "--cola": "1300px"},
   html: O["01_ia"].burbuja},
  TAB("i-ia.png", 1700, {left: 240, top: 1200}, "rotateZ(3deg)"),
]},
// 02 · Por foto
{ logo: LOGO_I, acento: "rosa", els: [
  TI("foto"),
  TAB("i-foto.png", 1560, {left: 560, top: 1000}, "rotateZ(6deg)"),
  {k: "boleta", b: O["02_foto"].boleta, pos: {left: 90, top: 880, width: 900}, estilo: {"font-size": 40, padding: "84px 58px", transform: "rotate(-7deg)"}},
]},
// 03 · Por voz
{ logo: {right: 130, bottom: 120, width: 240}, acento: "teal", els: [
  TAB("i-voz.png", 1720, {left: 160, top: -560}, "rotateZ(-3deg)"),
  {k: "burbuja", c: "#1E2A48", pos: {left: 130, top: 1780}, estilo: {"font-size": 80, padding: "50px 70px", transform: "rotate(-2deg)", border: "2px solid rgba(255,255,255,.18)", "white-space": "nowrap"},
   html: O["03_voz"].burbuja},
  {k: "onda", pos: {left: 1300, top: 1790}, ancho: 26, hueco: 20, alturas: [50, 100, 170, 240, 140, 80, 190, 250, 150, 70, 130, 200, 100, 60]},
  TI("voz", {pos: {left: 130, top: 2090, width: 1700}, subw: 1500}),
]},
// 04 · Por captura
{ logo: LOGO_I, acento: "violeta", els: [
  TI("yape"),
  {k: "disco", c: "var(--violeta)", pos: {left: 1100, top: 1500, width: 1500, height: 1500}},
  TAB("i-yape-origen.png", 1500, {left: 640, top: 1100}, "rotateY(-18deg) rotateX(5deg) rotateZ(4deg)"),
  {k: "pago", m: O["04_yape"].pago, pos: {left: 110, top: 960, width: 800}, estilo: {"font-size": 50, padding: "70px 64px 56px", transform: "rotate(-6deg)"}},
  chip(O["04_yape"].chip, {left: 170, top: 2120}, {"font-size": 60, padding: "30px 54px", transform: "rotate(-4deg)"}, {acento: "violeta"}),
]},
// 05 · Estadísticas
{ logo: LOGO_I, acento: "rosa", els: [
  TI("stats"),
  {k: "cifra", pos: {left: 0, right: 0, top: 990}, estilo: {"font-size": 300, "text-align": "center"}, html: O["05_stats"].cifra},
  chip(O["05_stats"].chips[0], {left: 140, top: 870}, {"font-size": 58, padding: "26px 50px", transform: "rotate(-6deg)"}),
  chip(O["05_stats"].chips[1], {right: 150, top: 880}, {"font-size": 58, padding: "26px 50px", transform: "rotate(5deg)"}),
  chip(O["05_stats"].chips[2], {left: 200, top: 1390}, {"font-size": 54, padding: "24px 46px", transform: "rotate(4deg)"}),
  chip(O["05_stats"].chips[3], {right: 200, top: 1410}, {"font-size": 54, padding: "24px 46px", transform: "rotate(-5deg)"}),
  TAB("i-estadisticas.png", 1720, {left: 170, top: 1500}, "rotateX(30deg) rotateZ(-5deg)"),
]},
// 06 · Grupos
{ logo: LOGO_I, acento: "teal", els: [
  TI("grupos", {tit: 140}),
  TAB("i-grupo.png", 1700, {left: 180, top: 820}, "rotateX(36deg) rotateZ(-20deg)"),
  tarjeta(O["06_grupos"].tarjeta, {pos: {left: 150, width: 1500, top: 800}, estilo: {transform: "rotate(-3deg)"}, escala: 1.6, icoC: "#3BD6F0"}),
  chip(O["06_grupos"].chips[0], {left: 1000, top: 2280}, {"font-size": 58, padding: "28px 50px", transform: "rotate(4deg)"}),
  chip(O["06_grupos"].chips[1], {left: 120, top: 2520}, {"font-size": 58, padding: "28px 50px", transform: "rotate(-5deg)"}),
]},
// 07 · Presupuestos · la tarjeta de «te quedan» tapa la fila del presupuesto con nombre real de la semilla
{ logo: LOGO_I, acento: "azul", els: [
  TI("presu"),
  TAB("i-presupuestos.png", 1720, {left: 200, top: 800}, "rotateZ(-3deg)", {encima: [
    tarjeta(O["07_presu"].tarjetaIpad, {pos: {left: "-7%", width: "62%", top: "47.5%"}, escala: 1.55, icoC: "#6164EB"}),
  ]}),
]},
// 08 · Tus cuentas · efectivo y tarjeta bajo sus tarjetas del carrusel; el de ahorro, en el hueco bajo las acciones
// (16-oct-2026: el chip de efectivo tapaba el saldo).
{ logo: LOGO_I, acento: "violeta", els: [
  TI("cuentas", {subw: 1600}),
  TAB("i-panel.png", 1640, {left: 210, top: 1050}),
  chip(O["08_cuentas"].chips[0], {left: 1130, top: 1665}, {"font-size": 60, padding: "28px 52px", transform: "rotate(-6deg)"}),
  chip(O["08_cuentas"].chips[1], {right: 70, top: 1650}, {"font-size": 60, padding: "28px 52px", transform: "rotate(5deg)"}),
  chip(O["08_cuentas"].chips[2], {left: 110, top: 1565}, {"font-size": 60, padding: "28px 52px", transform: "rotate(4deg)"}),
]},
// 09 · Multimoneda · la tarjeta del saldo en divisa extranjera tapa la otra cuenta de la semilla (sale en negativo)
{ logo: LOGO_I, acento: "rosa", els: [
  TI("divisas", {subw: 1500}),
  {k: "barra", c: "var(--rosa)", pos: {left: -300, top: 2150, width: 2700, height: 230, transform: "rotate(-11deg)"}},
  TAB("i-divisas.png", 1560, {left: 330, top: 1060}, "rotateY(-16deg) rotateZ(4deg)", {encima: [
    tarjeta(O["09_divisas"].tarjetaIpad, {pos: {left: "35%", width: "67%", top: "16%"}, estilo: {transform: "rotate(-3deg)", "white-space": "nowrap"}, escala: 1.4, icoC: "#FF2D78"}),
  ]}),
]},
// 10 · Recordatorios
{ logo: LOGO_I, acento: "teal", els: [
  TI("recor", {subw: 1500}),
  TAB("i-programados.png", 1560, {left: -80, top: 980}, "rotateY(24deg) rotateZ(-3deg)"),
  tarjeta(O["10_recor"].tarjetas[0], {pos: {left: 900, width: 1080, top: 1300}, estilo: {transform: "rotate(-4deg)"}, escala: 1.45, icoC: "#8B5CF6"}),
  tarjeta(O["10_recor"].tarjetas[1], {pos: {left: 980, width: 1000, top: 1700}, estilo: {transform: "rotate(3deg)"}, escala: 1.4, icoC: "#FF2D78"}),
]},
]};

// Ajustes de composición por idioma: se funden sobre los elementos de la lámina (por índice de `els`).
const fundir = (o, cambio) => {
  const r = Object.assign({}, o);
  for (const [k, v] of Object.entries(cambio)) {
    r[k] = (v && typeof v === "object" && !Array.isArray(v)) ? Object.assign({}, o[k], v) : v;
  }
  return r;
};
for (const aparato of ["iphone", "ipad"]) {
  for (const [n, porEl] of Object.entries((aj[aparato] || {}))) {
    const lamina = SETS[aparato].laminas[+n - 1];
    for (const [i, cambio] of Object.entries(porEl)) {
      const el = lamina.els[+i];
      for (const [k, v] of Object.entries(cambio)) {
        if (k === "encima") {
          // Lo que va encima de una pantalla es una lista: el ajuste va por índice, {encima: {0: {…}}}.
          el.encima = el.encima.map((o, j) => v[j] ? fundir(o, v[j]) : o);
        } else {
          el[k] = (v && typeof v === "object" && !Array.isArray(v)) ? Object.assign({}, el[k], v) : v;
        }
      }
    }
  }
}
return SETS;
}

// Ajustes de composición por idioma, medidos sobre el render. Forma: {iphone: {<n.º de lámina>: {<índice del elemento>:
// {campo: valor, …}}}, ipad: {…}}. Un objeto se funde con el del elemento (pos, estilo); lo demás se sustituye.
const AJUSTES = {
  "pt-BR": {
    iphone: {
      1: {0: {tit: 108}},                        // «Escreva pro Yala como pra uma amiga» bajaba a 3 líneas bajo la burbuja
      2: {1: {pos: {width: 760}}},               // «Tributos aprox. (incl.)» partía en dos líneas (revisión de Lola, 16-oct)
      6: {3: {pos: {left: 470}}},                // «Mercado · Ana pagou R$ 240» llegaba al borde derecho
    },
    ipad: {
      // «US$ 3.615,00» se montaba sobre «Poupança · USD · Saldo» (revisión de Lola, 16-oct): tarjeta más ancha y algo menor.
      9: {2: {encima: {0: {escala: 1.25, pos: {left: "24%", width: "76%"}}}}},
      2: {2: {pos: {width: 960}}},             // «Tributos aprox. (incl.)» partía en dos líneas
      // El titular baja a 3 líneas y la tarjeta «Transferência enviada» tapaba «o estabelecimento» (revisión de Lola
      // 2, 16-oct): la tarjeta y el chip bajan.
      4: {3: {pos: {top: 1110}}, 4: {pos: {top: 2210}}},
    },
  },
};

if (typeof module !== "undefined" && module.exports) module.exports = {construirSets, AJUSTES};
