// BORRADOR para Lola (Frank, 4-nov-2026): pt-PT adaptado de pt-BR.js (de Lola) a português de Portugal e a euros.
// As cifras saem da semente em euros (DevSeedFicha.cifras «EUR») e do ecrã de cada captura.
// Yala 2.2 · Textos das capturas da App Store (set B «Primeiro plano e objetos») e da pré-visualização (vídeo).
// Idioma: pt-PT. Mesma forma e chaves de es.js. Nomes das funções conforme a UI pt-PT da app: Yala IA, Estatísticas,
// Grupos, Orçamentos, Lembretes, categorias Moradia / Alimentação / Entretenimento / Transporte, «Te devem», «Comer fora».
// Moeda: EUR, formato português (€ 1284,50, como o mostra a app). Sem conteúdo só do Peru (Yape/Plin, soles, Cusco, boleta, menú).
const TEXTOS = {
  idioma: "pt-PT",
  moneda: {codigo: "EUR", simbolo: "€", ejemplo: "€ 1284,50"},

  TXT: {
    ia:      ["Yala IA · Pro", "Escreva ao Yala como a uma <u>amiga</u>", null],
    foto:    ["Por foto · Pro", "Tire uma <u>foto</u> ao talão e pronto", "O Yala lê o estabelecimento, a data e o total."],
    voz:     ["Por voz · Pro", "<u>Diga</u> à sua maneira. O Yala regista", "Sem escrever: diz e fica logo na categoria."],
    yape:    ["Por captura · Pro", "Registe as transferências com uma <u>captura</u>", "O Yala tira o valor, o estabelecimento e a data."],
    stats:   ["Estatísticas", "Veja para onde foi cada <u>euro</u>", "Categoria a categoria, sem folhas de cálculo."],
    grupos:  ["Grupos", "Viagem ao Algarve: contas <u>certas</u> e a amizade intacta", null],
    presu:   ["Orçamentos", "Quanto <u>sobra</u> este mês?", null],
    cuentas: ["As suas contas", "Todas as suas contas, sem <u>ligar</u> o banco", "Dinheiro, cartão e poupança num só ecrã. Decide o que regista."],
    divisas: ["Multimoeda", "Mais de 50 moedas, sem <u>calculadora</u>", "Cada conta na sua moeda. O Yala faz a conversão."],
    recor:   ["Lembretes", "<u>Avisamos</u> antes de cada pagamento", "Luz, telemóvel, o cartão de crédito: escolhe a data."],
  },

  OBJ: {
    "01_ia":    {burbuja: "Gastei 45 num táxi para o aeroporto e 120,50 no supermercado"},
    "02_foto":  {boleta: {
      cab: ["FATURA SIMPLIFICADA", "RESTAURANTE O BOM GOSTO"],
      peq: ["Alfama · Lisboa", "30/03/2026 · 14:15 · Mesa 12"],
      items: [["1 Mariscada para dois", "89,50"], ["2 Polvo à lagareiro", "58,00"], ["2 Alvarinho (garrafa)", "52,80"],
              ["4 Sobremesa da casa", "22,40"], ["4 Couvert", "14,00"], ["Águas e cafés", "15,11"]],
      // O IVA já está incluído nos preços: a linha informa, não soma.
      totales: [["Subtotal", "251,81 €"], ["IVA incluído", "28,97 €"]],
      total: ["TOTAL", "251,81 €"],
      pie: "Obrigado e volte sempre!",
    }},
    "03_voz":   {burbuja: "«Almoço 25 com o cartão»"},
    "04_yape":  {
      // Comprovativo de transferência genérico: sem MB WAY, sem nome nem logótipo de banco (diretriz 5.2).
      pago: {tit: "Transferência enviada", monto: "€ 35,00", a: "para Pastelaria Estrela",
             filas: [["Data", "13/10/2026"], ["Hora", "12:40"], ["Referência", "04812736"]]},
      chip: "Partilhar → <b>Yala</b>",
    },
    "05_stats": {
      cifra: "€ 4686<small>gastou este mês</small>",
      chips: ["Moradia <b>47%</b>", "Alimentação <b>28%</b>", "Entretenimento <b>8%</b>", "Transporte <b>4%</b>"],
    },
    "06_grupos": {
      tarjeta: {ico: "€", t1: "Te devem", t2: "Viagem ao Algarve · 3 pessoas", monto: "€ 190,00"},
      chips: ["Supermercado · Ana pagou <b>€ 120</b>", "Marisqueira · Bruno pagou <b>€ 180</b>"],
      chipsLista: ["Bruno deve-te <b>€ 110</b>", "Ana deve-te <b>€ 80</b>"],
    },
    "07_presu": {
      cifra: "€ 470<small>para Comer fora nos próximos 19 dias</small>",
      tarjetaIpad: {ico: "€", t1: "Sobram € 470", t2: "Comer fora · 19 dias", monto: "74%"},
    },
    "08_cuentas": {chips: ["Dinheiro", "Cartão", "Poupança em <b>$</b>"]},
    "09_divisas": {
      cifra: "$ 2400,00<small>em Viagem USD, na própria moeda</small>",
      tarjetaIpad: {ico: "$", t1: "Viagem USD", t2: "Poupança · USD · Saldo", monto: "$ 2400,00"},
    },
    "10_recor": {tarjetas: [
      {ico: "!", t1: "Telefone", t2: "Daqui a 2 dias · Mensal", monto: "€ 25,00"},
      {ico: "!", t1: "Spotify", t2: "Daqui a 5 dias · Mensal", monto: "€ 7,99"},
    ]},
  },

  VIDEO: {
    t0:     {acento: "azul",    pill: "Yala IA · Pro",      lineas: ["Escreva como", "a uma <u>amiga</u>"]},
    t1:     {acento: "rosa",    pill: "Por foto · Pro",     lineas: ["Tire uma <u>foto</u>", "ao talão"]},
    t2:     {acento: "teal",    pill: "Por voz · Pro",      lineas: ["<u>Diga</u>", "à sua maneira"]},
    t3:     {acento: "violeta", pill: "Grupos · Gratuito",  lineas: ["Contas <u>certas</u>", "na viagem"]},
    cierre: {acento: "rosa",    pill: null,                 lineas: ["As suas finanças,", "sem <u>esforço</u>."]},
  },
};
if (typeof module !== "undefined" && module.exports) module.exports = TEXTOS;
else (window.YALA_TEXTOS = window.YALA_TEXTOS || {})[TEXTOS.idioma] = TEXTOS;
