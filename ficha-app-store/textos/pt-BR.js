// Yala 2.1 · Textos das capturas da App Store (set B «Primeiro plano e objetos») e da prévia (vídeo).
// Idioma: pt-BR (português do Brasil). Adaptado de es.js (não é tradução literal). Mesma forma e chaves de es.js.
// Nomes das funções conforme a UI pt-BR em origin/2.1: Yala IA, Estatísticas, Grupos, Orçamentos, Suas contas, Lembretes,
// categorias Moradia / Alimentação / Entretenimento / Transporte, «Te devem», «Comer fora», «Mensal», Dinheiro / Poupança.
// Moeda: BRL, formato brasileiro (R$ 1.284,50). Sem conteúdo só do Peru (Yape/Plin, soles, Cusco, boleta, menú).
const TEXTOS = {
  idioma: "pt-BR",
  moneda: {codigo: "BRL", simbolo: "R$", ejemplo: "R$ 1.284,50"},

  TXT: {
    ia:      ["Yala IA · Pro", "Escreva pro Yala como pra uma <u>amiga</u>", null],
    foto:    ["Por foto · Pro", "Tire <u>foto</u> da nota e pronto", "O Yala lê o estabelecimento, a data e o total."],
    voz:     ["Por voz · Pro", "<u>Fale</u> do seu jeito. O Yala anota", "Sem digitar: você fala e já cai na categoria."],
    yape:    ["Por print · Pro", "Registre suas transferências com um <u>print</u>", "O Yala tira o valor, o estabelecimento e a data."],
    stats:   ["Estatísticas", "Veja para onde foi cada <u>real</u>", "Categoria por categoria, sem abrir planilha."],
    grupos:  ["Grupos", "Viagem ao Rio: contas <u>claras</u> e amizade intacta", null],
    presu:   ["Orçamentos", "Quanto <u>sobra</u> este mês?", null],
    cuentas: ["Suas contas", "Todas as suas contas, sem <u>conectar</u> o banco", "Dinheiro, cartão e poupança numa só tela. Você decide o que anota."],
    divisas: ["Multimoeda", "50+ moedas, sem <u>calculadora</u>", "Cada conta na sua moeda. O Yala faz a conversão."],
    recor:   ["Lembretes", "Te <u>avisamos</u> antes de cada conta", "Luz, celular, a fatura do cartão: você define a data."],
  },

  OBJ: {
    "01_ia":    {burbuja: "Gastei 45 num táxi pro aeroporto e 120,50 no mercado"},
    "02_foto":  {boleta: {
      cab: ["CUPOM FISCAL", "RESTAURANTE SABOR DA CASA"],
      peq: ["Pinheiros · São Paulo", "30/03/2026 · 14:15 · Mesa 12"],
      items: [["1 Moqueca de peixe", "89,00"], ["2 Picanha na chapa", "138,00"], ["3 Chope artesanal", "51,00"], ["1 Jarra de suco de caju", "24,00"]],
      // Os tributos aproximados (Lei 12.741) já estão incluídos nos preços: a linha informa, não soma.
      totales: [["Subtotal", "R$ 302,00"], ["Tributos aprox. (incl.)", "R$ 39,26"], ["Serviço 10%", "R$ 30,20"]],
      total: ["TOTAL", "R$ 332,20"],
      pie: "Obrigado pela preferência!",
    }},
    "03_voz":   {burbuja: "“Almoço 25 no cartão”"},
    "04_yape":  {
      // Comprovante de transferência genérico: sem Pix, sem nome nem logo de banco ou carteira (diretriz 5.2, como o Yape).
      pago: {tit: "Transferência enviada", monto: "R$ 35,00", a: "para Padaria São Jorge",
             filas: [["Data", "13/10/2026"], ["Hora", "12:40"], ["ID da transação", "04812736"]]},
      chip: "Compartilhar → <b>Yala</b>",
    },
    "05_stats": {
      cifra: "R$ 4.686<small>você gastou este mês</small>",
      chips: ["Moradia <b>47%</b>", "Alimentação <b>28%</b>", "Entretenimento <b>8%</b>", "Transporte <b>4%</b>"],
    },
    "06_grupos": {
      tarjeta: {ico: "R$", t1: "Te devem", t2: "Viagem ao Rio · 3 pessoas", monto: "R$ 380,00"},
      chips: ["Mercado · Ana pagou <b>R$ 240</b>", "Churrascaria · Beto pagou <b>R$ 360</b>"],
    },
    "07_presu": {
      cifra: "R$ 470<small>para Comer fora nos próximos 19 dias</small>",
      tarjetaIpad: {ico: "R$", t1: "Sobram R$ 470", t2: "Comer fora · 19 dias", monto: "74%"},
    },
    "08_cuentas": {chips: ["Dinheiro", "Cartão", "Poupança em <b>US$</b>"]},
    "09_divisas": {
      cifra: "US$ 3.615,00<small>em Viagem USD, na própria moeda</small>",
      tarjetaIpad: {ico: "$", t1: "Viagem USD", t2: "Poupança · USD · Saldo", monto: "US$ 3.615,00"},
    },
    "10_recor": {tarjetas: [
      {ico: "!", t1: "Telefone", t2: "Em 2 dias · Mensal", monto: "R$ 59,90"},
      {ico: "!", t1: "Spotify", t2: "Em 5 dias · Mensal", monto: "R$ 21,90"},
    ]},
  },

  VIDEO: {
    t0:     {acento: "azul",    pill: "Yala IA · Pro",   lineas: ["Escreva como", "pra uma <u>amiga</u>"]},
    t1:     {acento: "rosa",    pill: "Por foto · Pro",  lineas: ["Tire <u>foto</u>", "da nota"]},
    t2:     {acento: "teal",    pill: "Por voz · Pro",   lineas: ["<u>Fale</u>", "do seu jeito"]},
    t3:     {acento: "violeta", pill: "Grupos · Grátis", lineas: ["Contas <u>claras</u>", "na viagem"]},
    cierre: {acento: "rosa",    pill: null,              lineas: ["Suas finanças,", "sem <u>esforço</u>."]},
  },
};
if (typeof module !== "undefined" && module.exports) module.exports = TEXTOS;
else (window.YALA_TEXTOS = window.YALA_TEXTOS || {})[TEXTOS.idioma] = TEXTOS;
