// Páginas por funcionalidad y preguntas frecuentes (es / en).
//
// Cada afirmación sale de la app o de la web ya publicada, no de un deseo: los límites del plan Gratis
// (4 cuentas, 3 presupuestos) y qué es Pro viven en `Yala/App/Services/FeatureGateService.swift`;
// los modos de reparto de Grupos en `SplitType` (`Yala/App/Models/TransactionFormModels.swift`); los
// períodos de presupuesto en `Budget.periodType`. Si cambian allí, cambian aquí.
// Sin comparativas con otras apps ni portugués: decisión de Jürgen (2026-11-04).

export type SeoLang = 'es' | 'en';

export interface Qa { q: string; a: string }

export interface FeatureText {
  nav: string;          // nombre corto (tarjeta del índice)
  title: string;        // <title>
  description: string;  // meta description
  h1: string;
  lede: string;
  steps: string[];      // cómo funciona
  details: string[];    // lo que conviene saber
  planNote: string;
  faq: Qa[];
}

export interface Feature {
  id: string;
  slug: Record<SeoLang, string>;
  plan: 'free' | 'pro' | 'mixed';
  text: Record<SeoLang, FeatureText>;
}

export const seoPaths = {
  features: { es: '/funciones/', en: '/en/features/' },
  faq: { es: '/preguntas-frecuentes/', en: '/en/faq/' },
} as const;

export const featureUrl = (f: Feature, lang: SeoLang) => `${seoPaths.features[lang]}${f.slug[lang]}/`;

export const APP_STORE_URL = 'https://apps.apple.com/pe/app/yala-finanzas-sin-esfuerzo/id6758253109';

export const ui = {
  es: {
    home: 'Inicio',
    features: 'Funciones',
    faq: 'Preguntas frecuentes',
    backHome: '← Volver a Inicio',
    howTitle: 'Cómo funciona',
    detailsTitle: 'Lo que conviene saber',
    planTitle: 'En qué plan está',
    faqTitle: 'Dudas sobre esta función',
    moreFeatures: 'Otras funciones',
    download: 'Descargar en la App Store',
    newTab: 'se abre en otra pestaña',
    platform: 'Solo iPhone, iOS 26 o superior.',
    planFree: 'Plan Gratis',
    planPro: 'Yala Pro',
    planMixed: 'Gratis, con más en Pro',
    featuresTitle: 'Funciones de Yala, la app de finanzas personales para iPhone',
    featuresDescription: 'Qué puedes hacer con Yala: anotar gastos en segundos, leer comprobantes, dictar o fotografiar recibos, preguntarle a Yala IA, armar presupuestos y dividir gastos en grupo.',
    featuresH1: 'Qué puedes hacer con Yala',
    featuresLede: 'Yala es una app de finanzas personales para iPhone. Anotas lo que gastas en segundos y, a fin de mes, entiendes a dónde se fue tu dinero. Estas son sus funciones, una por página.',
    faqPageTitle: 'Preguntas frecuentes sobre Yala, la app de finanzas personales',
    faqPageDescription: 'Respuestas cortas sobre Yala: cuánto cuesta, qué incluyen el plan Gratis y Yala Pro, dónde viven tus datos, si se conecta a tu banco, en qué teléfonos funciona y más.',
    faqH1: 'Preguntas frecuentes',
    faqLede: 'Lo que más nos preguntan sobre Yala, con respuestas directas.',
    seeFeature: 'Ver la función',
    contact: '¿Te quedó una duda? Escríbenos a',
    privacy: 'Privacidad',
    terms: 'Términos',
    help: 'Ayuda',
  },
  en: {
    home: 'Home',
    features: 'Features',
    faq: 'FAQ',
    backHome: '← Back to Home',
    howTitle: 'How it works',
    detailsTitle: 'Good to know',
    planTitle: 'Which plan includes it',
    faqTitle: 'Questions about this feature',
    moreFeatures: 'Other features',
    download: 'Download on the App Store',
    newTab: 'opens in a new tab',
    platform: 'iPhone only, iOS 26 or later.',
    planFree: 'Free plan',
    planPro: 'Yala Pro',
    planMixed: 'Free, with more in Pro',
    featuresTitle: 'Yala features: the personal finance app for iPhone',
    featuresDescription: 'What you can do with Yala: log expenses in seconds, read payment receipts, dictate or photograph receipts, ask Yala AI, set budgets and split expenses with a group.',
    featuresH1: 'What you can do with Yala',
    featuresLede: 'Yala is a personal finance app for iPhone. You log what you spend in seconds and, at the end of the month, you understand where your money went. Here are its features, one per page.',
    faqPageTitle: 'Frequently asked questions about Yala, the personal finance app',
    faqPageDescription: 'Short answers about Yala: what it costs, what the Free plan and Yala Pro include, where your data lives, whether it connects to your bank, which phones it runs on and more.',
    faqH1: 'Frequently asked questions',
    faqLede: 'What people ask us most about Yala, with straight answers.',
    seeFeature: 'See the feature',
    contact: 'Still have a question? Write to',
    privacy: 'Privacy',
    terms: 'Terms',
    help: 'Help',
  },
} satisfies Record<SeoLang, Record<string, string>>;

export const features: Feature[] = [
  {
    id: 'log',
    slug: { es: 'anotar-gastos', en: 'expense-tracker' },
    plan: 'free',
    text: {
      es: {
        nav: 'Anotar gastos en segundos',
        title: 'Anotar gastos en segundos desde el iPhone | Yala',
        description: 'Con Yala anotas un gasto en dos toques: escribe qué fue y cuánto, con atajos para la cuenta, la categoría y la etiqueta, o desde Siri. También importas el Excel o CSV de tu banco.',
        h1: 'Anota tus gastos en lo que tarda el vuelto',
        lede: 'Llevar la cuenta de tus gastos solo funciona si anotar no es un trabajo. En Yala escribes qué fue y cuánto, y listo: la app lo ordena por categoría y cuenta para que a fin de mes veas cómo vas.',
        steps: [
          'Abre Yala y escribe el gasto como lo dirías: «taxi 18.50» o «almuerzo 25».',
          'Si quieres, completa sin salir del teclado: @cuenta para la cuenta, !categoría para la categoría y #etiqueta para la etiqueta.',
          'Guarda. El gasto aparece en tu Panel, en tus presupuestos y en tus reportes.',
        ],
        details: [
          'También anotas con un atajo de Siri, sin abrir la app.',
          'Ingresos, gastos y transferencias entre tus cuentas, en más de 50 divisas.',
          '¿Ya tienes historial? Importa el archivo Excel o CSV que te da tu banco.',
          'Los widgets de la pantalla de inicio te muestran cómo vas sin abrir la app.',
          'Funciona sin internet: anotar, presupuestos, gráficos y widgets van sin conexión.',
        ],
        planNote: 'Anotar a mano, con Siri e importar archivos están en el plan Gratis, con hasta 4 cuentas. Yala Pro quita el límite de cuentas.',
        faq: [
          { q: '¿Yala se conecta a mi banco?', a: 'No. Yala no se conecta a bancos ni pide tus claves. Anotas tú, o importas el archivo de tu banco cuando quieras.' },
          { q: '¿Puedo anotar en dólares si mi cuenta está en otra moneda?', a: 'Sí. Yala maneja más de 50 divisas y consulta el tipo de cambio para mostrarte los totales en tu moneda principal.' },
        ],
      },
      en: {
        nav: 'Log expenses in seconds',
        title: 'Log expenses in seconds on your iPhone | Yala',
        description: 'With Yala you log an expense in two taps: type what it was and how much, with shortcuts for account, category and tag, or use Siri. You can also import your bank’s Excel or CSV file.',
        h1: 'Log your expenses before the change comes back',
        lede: 'Tracking your spending only works if logging it isn’t a chore. In Yala you type what it was and how much, and you’re done: the app sorts it by category and account so at the end of the month you see how you’re doing.',
        steps: [
          'Open Yala and type the expense the way you’d say it: “taxi 18.50” or “lunch 25”.',
          'If you like, fill in the rest without leaving the keyboard: @account, !category and #tag.',
          'Save. The expense shows up in your Dashboard, your budgets and your reports.',
        ],
        details: [
          'You can also log with a Siri shortcut, without opening the app.',
          'Income, expenses and transfers between your accounts, in more than 50 currencies.',
          'Already have a history? Import the Excel or CSV file your bank gives you.',
          'Home Screen widgets show how you’re doing without opening the app.',
          'Works offline: logging, budgets, charts and widgets need no connection.',
        ],
        planNote: 'Manual logging, Siri and file import are in the Free plan, with up to 4 accounts. Yala Pro removes the account limit.',
        faq: [
          { q: 'Does Yala connect to my bank?', a: 'No. Yala doesn’t connect to banks or ask for your bank credentials. You log, or you import your bank’s file whenever you want.' },
          { q: 'Can I log in dollars if my account is in another currency?', a: 'Yes. Yala handles more than 50 currencies and looks up the exchange rate to show your totals in your main currency.' },
        ],
      },
    },
  },
  {
    id: 'screenshots',
    slug: { es: 'leer-comprobantes-de-pago', en: 'read-payment-receipts' },
    plan: 'pro',
    text: {
      es: {
        nav: 'Leer comprobantes y estados de cuenta',
        title: 'Registra gastos desde la captura de un comprobante | Yala',
        description: 'Comparte a Yala la captura de un comprobante de pago (Yape, Plin, transferencia) o de tu estado de cuenta, y la app lee todos los movimientos de una vez. Función de Yala Pro.',
        h1: 'Compártele la captura y Yala anota los movimientos',
        lede: 'Muchos pagos ya dejan una prueba en tu teléfono: el comprobante de una billetera digital, el de una transferencia o la pantalla de movimientos de tu banco. En vez de copiarlos a mano, compártele la captura a Yala.',
        steps: [
          'Toma la captura del comprobante o de tu estado de cuenta, aunque tenga varios movimientos.',
          'Compártela a Yala desde el menú de compartir del iPhone.',
          'Yala lee los montos, las fechas y los comercios. Revisas lo que encontró y confirmas.',
        ],
        details: [
          'Una sola captura con varios movimientos se registra de una vez.',
          'Sirve para comprobantes de Yape o Plin, transferencias y pantallas de movimientos del banco.',
          'Antes de usarla por primera vez, Yala te dice qué información sale del teléfono para leer la imagen.',
          'Siempre confirmas tú: nada se guarda sin que lo revises.',
        ],
        planNote: 'Leer capturas es una función de Yala Pro. Pro tiene un mes de prueba gratis.',
        faq: [
          { q: '¿Necesito darle a Yala acceso a mi banco?', a: 'No. Yala lee la imagen que tú compartes; no entra a tu banco ni pide tus claves.' },
          { q: '¿Qué pasa si lee un monto mal?', a: 'Antes de guardar ves lo que encontró y puedes corregir o quitar cualquier movimiento.' },
        ],
      },
      en: {
        nav: 'Read receipts and statements',
        title: 'Log expenses from a payment screenshot | Yala',
        description: 'Share a screenshot of a payment receipt or your bank statement with Yala and the app reads every transaction at once. A Yala Pro feature.',
        h1: 'Share the screenshot and Yala logs the transactions',
        lede: 'Many payments already leave proof on your phone: a digital wallet receipt, a transfer confirmation or your bank’s transactions screen. Instead of copying them by hand, share the screenshot with Yala.',
        steps: [
          'Take a screenshot of the receipt or your statement, even if it has several transactions.',
          'Share it to Yala from the iPhone share sheet.',
          'Yala reads the amounts, dates and merchants. You review what it found and confirm.',
        ],
        details: [
          'One screenshot with several transactions is logged in one go.',
          'Works with payment app receipts, bank transfers and bank transaction screens.',
          'Before the first use, Yala tells you what information leaves the phone to read the image.',
          'You always confirm: nothing is saved until you review it.',
        ],
        planNote: 'Reading screenshots is a Yala Pro feature. Pro comes with a one-month free trial.',
        faq: [
          { q: 'Do I need to give Yala access to my bank?', a: 'No. Yala reads the image you share; it doesn’t log into your bank or ask for your credentials.' },
          { q: 'What if it reads an amount wrong?', a: 'Before saving you see what it found and can fix or remove any transaction.' },
        ],
      },
    },
  },
  {
    id: 'voice-photo',
    slug: { es: 'anotar-gastos-por-voz-y-foto', en: 'voice-and-receipt-scanning' },
    plan: 'pro',
    text: {
      es: {
        nav: 'Por voz o con la foto del recibo',
        title: 'Anota gastos por voz o con la foto del recibo | Yala',
        description: 'Dile a Yala «gasté 50 en el súper» o apunta la cámara al recibo, y el gasto queda listo para confirmar. Dictado y lectura de recibos son funciones de Yala Pro.',
        h1: 'Díctale el gasto o fotografía el recibo',
        lede: 'Cuando tienes las manos ocupadas o el recibo en la mano, escribir sobra. Con Yala Pro dictas el gasto o le tomas una foto al recibo, y Yala arma el registro por ti.',
        steps: [
          'Toca el micrófono y di el gasto: «gasté 50 en el súper».',
          'O toca la cámara y apunta al recibo.',
          'Yala completa el monto, la descripción y la categoría. Tú confirmas.',
        ],
        details: [
          'Hablas como hablarías con alguien; no hace falta un formato especial.',
          'Del recibo toma el total y el comercio.',
          'Antes de usarlas por primera vez, Yala te avisa qué sale del teléfono para procesar la voz o la imagen.',
        ],
        planNote: 'Dictado y foto del recibo son funciones de Yala Pro. Pro tiene un mes de prueba gratis.',
        faq: [
          { q: '¿Se guarda mi voz o la foto?', a: 'Yala las usa para armar el registro. Antes de activarlas te explica qué sale del teléfono; el detalle está en la política de privacidad.' },
          { q: '¿Puedo corregir lo que entendió?', a: 'Sí. Siempre ves el gasto antes de guardarlo y puedes cambiar cualquier dato.' },
        ],
      },
      en: {
        nav: 'By voice or receipt photo',
        title: 'Log expenses by voice or with a receipt photo | Yala',
        description: 'Tell Yala “spent 50 at the supermarket” or point the camera at the receipt, and the expense is ready to confirm. Dictation and receipt scanning are Yala Pro features.',
        h1: 'Dictate the expense or snap the receipt',
        lede: 'When your hands are full or the receipt is in your hand, typing is one step too many. With Yala Pro you dictate the expense or take a photo of the receipt, and Yala builds the entry for you.',
        steps: [
          'Tap the microphone and say the expense: “spent 50 at the supermarket”.',
          'Or tap the camera and point it at the receipt.',
          'Yala fills in the amount, description and category. You confirm.',
        ],
        details: [
          'Speak the way you’d talk to someone; no special format needed.',
          'From the receipt it takes the total and the merchant.',
          'Before the first use, Yala tells you what leaves the phone to process the voice or image.',
        ],
        planNote: 'Dictation and receipt photos are Yala Pro features. Pro comes with a one-month free trial.',
        faq: [
          { q: 'Is my voice or photo stored?', a: 'Yala uses them to build the entry. Before you turn them on it explains what leaves the phone; the details are in the privacy policy.' },
          { q: 'Can I fix what it understood?', a: 'Yes. You always see the expense before saving and can change anything.' },
        ],
      },
    },
  },
  {
    id: 'yala-ia',
    slug: { es: 'yala-ia', en: 'yala-ai' },
    plan: 'pro',
    text: {
      es: {
        nav: 'Yala IA, tu asistente',
        title: 'Yala IA: pregúntale a tu app de finanzas cómo vas | Yala',
        description: 'Yala IA es un asistente que conoce tus números y responde en lenguaje normal: cuánto llevas gastado, en qué se va tu dinero y, si se lo pides, anota el gasto por ti. Función de Yala Pro.',
        h1: 'Pregúntale a Yala IA cómo vas',
        lede: 'Yala IA es un asistente con inteligencia artificial (IA) dentro de la app. Conoce tus movimientos y presupuestos, así que le puedes preguntar por tu dinero como le preguntarías a un amigo que lleva tus cuentas.',
        steps: [
          'Abre Yala IA y escribe tu pregunta: «¿cómo van mis gastos este mes?».',
          'Te responde con tus cifras: cuánto llevas, la media diaria y en qué categorías se va más.',
          'Pídele que anote por ti: «registra 24 soles de pizza con amigos».',
        ],
        details: [
          'Responde con tus datos, no con consejos genéricos.',
          'Solo funciona si tú la activas, y antes te decimos qué comparte.',
          'No es asesoría financiera: te ayuda a entender tus números.',
        ],
        planNote: 'Yala IA es una función de Yala Pro. Pro tiene un mes de prueba gratis.',
        faq: [
          { q: '¿Yala IA puede mover mi dinero?', a: 'No. Yala no se conecta a bancos: Yala IA solo lee lo que registraste en la app y, si se lo pides, anota un movimiento.' },
          { q: '¿Qué datos ve Yala IA?', a: 'Los movimientos, cuentas y presupuestos que necesita para responder. Antes de activarla te mostramos qué comparte.' },
        ],
      },
      en: {
        nav: 'Yala AI, your assistant',
        title: 'Yala AI: ask your finance app how you’re doing | Yala',
        description: 'Yala AI is an assistant that knows your numbers and answers in plain language: how much you’ve spent, where your money goes and, if you ask, it logs the expense for you. A Yala Pro feature.',
        h1: 'Ask Yala AI how you’re doing',
        lede: 'Yala AI is an assistant powered by artificial intelligence (AI) inside the app. It knows your transactions and budgets, so you can ask about your money the way you’d ask a friend who keeps your books.',
        steps: [
          'Open Yala AI and type your question: “how are my expenses this month?”.',
          'It answers with your figures: how much you’ve spent, your daily average and which categories take the most.',
          'Ask it to log for you: “log 24 for pizza with friends”.',
        ],
        details: [
          'It answers with your data, not generic advice.',
          'It only works if you turn it on, and we tell you first what it shares.',
          'It isn’t financial advice: it helps you understand your numbers.',
        ],
        planNote: 'Yala AI is a Yala Pro feature. Pro comes with a one-month free trial.',
        faq: [
          { q: 'Can Yala AI move my money?', a: 'No. Yala doesn’t connect to banks: Yala AI only reads what you logged in the app and, if you ask, logs a transaction.' },
          { q: 'What data does Yala AI see?', a: 'The transactions, accounts and budgets it needs to answer. Before you turn it on we show you what it shares.' },
        ],
      },
    },
  },
  {
    id: 'budgets',
    slug: { es: 'presupuestos', en: 'budgets' },
    plan: 'mixed',
    text: {
      es: {
        nav: 'Presupuestos con alertas',
        title: 'Presupuesto mensual con alertas en el iPhone | Yala',
        description: 'Arma presupuestos por categoría en Yala y recibe una alerta antes de pasarte. Suma pagos planificados y mira tu salud financiera en un número. Hasta 3 presupuestos en el plan Gratis.',
        h1: 'Un presupuesto que te avisa antes de pasarte',
        lede: 'Un presupuesto sirve si te enteras a tiempo. En Yala pones un tope para la categoría que te importa y la app te avisa cuando te estás acercando, no cuando ya es tarde.',
        steps: [
          'Crea un presupuesto: elige la categoría, el monto y el período.',
          'Anota tus gastos como siempre; el presupuesto se descuenta solo.',
          'Si vas rápido, Yala te avisa para que ajustes a tiempo.',
        ],
        details: [
          'Los pagos planificados (alquiler, servicios, suscripciones) te recuerdan lo que viene.',
          'Tu salud financiera en una cifra sobre 100, con presupuestos, ritmo y compromisos.',
          'Ves cuánto llevas frente al mes pasado y qué presupuesto se está pasando.',
        ],
        planNote: 'El plan Gratis incluye hasta 3 presupuestos con alertas y pagos planificados. Yala Pro quita el límite de presupuestos.',
        faq: [
          { q: '¿Cuántos presupuestos puedo tener en el plan Gratis?', a: 'Hasta 3. Con Yala Pro, los que quieras.' },
          { q: '¿Solo hay presupuestos mensuales?', a: 'No: puede ser semanal, mensual, anual o para un período único, como unas fiestas o una mudanza.' },
        ],
      },
      en: {
        nav: 'Budgets with alerts',
        title: 'Monthly budget with alerts on iPhone | Yala',
        description: 'Set budgets by category in Yala and get an alert before you overspend. Add planned payments and see your financial health in one number. Up to 3 budgets on the Free plan.',
        h1: 'A budget that warns you before you overspend',
        lede: 'A budget only helps if you find out in time. In Yala you set a limit for the category you care about and the app warns you as you get close, not when it’s too late.',
        steps: [
          'Create a budget: choose the category, the amount and the period.',
          'Log your expenses as usual; the budget updates on its own.',
          'If you’re spending fast, Yala warns you so you can adjust in time.',
        ],
        details: [
          'Planned payments (rent, utilities, subscriptions) remind you of what’s coming.',
          'Your financial health as one score out of 100, combining budgets, pace and commitments.',
          'See how much you’ve spent compared with last month and which budget is running over.',
        ],
        planNote: 'The Free plan includes up to 3 budgets with alerts and planned payments. Yala Pro removes the budget limit.',
        faq: [
          { q: 'How many budgets can I have on the Free plan?', a: 'Up to 3. With Yala Pro, as many as you want.' },
          { q: 'Are budgets only monthly?', a: 'No: a budget can be weekly, monthly, yearly or for a one-off period, like the holidays or a move.' },
        ],
      },
    },
  },
  {
    id: 'groups',
    slug: { es: 'dividir-gastos', en: 'split-expenses' },
    plan: 'free',
    text: {
      es: {
        nav: 'Dividir gastos en grupo',
        title: 'Dividir gastos con amigos, pareja o roomies | Yala',
        description: 'Con Grupos de Yala anotas un gasto compartido, lo repartes en partes iguales, por porcentaje, por monto o por partes, y Yala simplifica las deudas para decirte quién le paga a quién.',
        h1: '¿Quién le debe a quién? Yala lo sabe',
        lede: 'El departamento compartido, la cena con amigos, los gastos de la casa en pareja. Con Grupos anotas como siempre y Yala lleva la cuenta de lo que cada uno puso y lo que debe.',
        steps: [
          'Crea un grupo e invita a los demás con un enlace.',
          'Anota el gasto y elige cómo repartirlo: en partes iguales, por porcentaje, por monto exacto o por partes.',
          'Yala simplifica las deudas del grupo y te dice a quién pagarle y cuánto.',
        ],
        details: [
          'Menos transferencias: Yala junta las deudas para que haya la menor cantidad de pagos posible.',
          'Cuando alguien paga, lo marcas y el saldo se actualiza para todos.',
          'Los importes del grupo solo los ven sus miembros, junto con el alias de cada uno.',
          'Grupos pide iniciar sesión con Apple o Google para que los miembros se vean entre sí.',
        ],
        planNote: 'Grupos está en el plan Gratis.',
        faq: [
          { q: '¿Los demás también necesitan Yala?', a: 'Sí: cada miembro se une al grupo desde su iPhone con Yala, con la invitación que le compartes.' },
          { q: '¿Qué ven los demás miembros de mis finanzas?', a: 'Solo los gastos, saldos y alias del grupo. El resto de tus cuentas y movimientos no se comparte.' },
        ],
      },
      en: {
        nav: 'Split expenses with a group',
        title: 'Split expenses with friends, partners or roommates | Yala',
        description: 'With Yala Groups you log a shared expense, split it equally, by percentage, by exact amount or by shares, and Yala simplifies the debts to tell you who pays whom.',
        h1: 'Who owes whom? Yala knows',
        lede: 'The shared apartment, dinner with friends, household costs with your partner. With Groups you log as usual and Yala keeps track of what everyone paid and owes.',
        steps: [
          'Create a group and invite the others with a link.',
          'Log the expense and choose how to split it: equally, by percentage, by exact amount or by shares.',
          'Yala simplifies the group’s debts and tells you whom to pay and how much.',
        ],
        details: [
          'Fewer transfers: Yala combines debts so there are as few payments as possible.',
          'When someone pays, you mark it and the balance updates for everyone.',
          'Group amounts are only visible to its members, along with each member’s nickname.',
          'Groups asks you to sign in with Apple or Google so members can see each other.',
        ],
        planNote: 'Groups is included in the Free plan.',
        faq: [
          { q: 'Do the others need Yala too?', a: 'Yes: each member joins the group from their iPhone with Yala, using the invite you share.' },
          { q: 'What do other members see of my finances?', a: 'Only the group’s expenses, balances and nicknames. The rest of your accounts and transactions isn’t shared.' },
        ],
      },
    },
  },
];

// Preguntas frecuentes generales (/preguntas-frecuentes/ y /en/faq/).
export const faq: Record<SeoLang, Qa[]> = {
  es: [
    { q: '¿Qué es Yala?', a: 'Yala es una app de finanzas personales para iPhone. Anotas tus gastos e ingresos en segundos, armas presupuestos con alertas y ves a dónde se va tu dinero. Está hecha en Lima, Perú, y está en la App Store desde marzo de 2026.' },
    { q: '¿Cuánto cuesta Yala?', a: 'Se descarga sin pagar y tiene un plan Gratis sin fecha de vencimiento. Yala Pro cuesta S/ 12.90 al mes o S/ 99.90 al año en Perú; en otros países la App Store muestra el precio local. Pro tiene un mes de prueba gratis.' },
    { q: '¿Qué incluye el plan Gratis y qué agrega Yala Pro?', a: 'Gratis: hasta 4 cuentas, anotar a mano y con atajos de Siri, hasta 3 presupuestos con alertas, pagos planificados, widgets, más de 50 divisas, Grupos e importar y exportar en CSV o Excel. Pro agrega cuentas y presupuestos ilimitados, leer capturas, dictado y foto del recibo, Yala IA y reportes avanzados.' },
    { q: '¿Yala se conecta a mi banco?', a: 'No. Yala no se conecta a bancos ni pide tus claves. Anotas tú, compartes la captura de un comprobante (Pro) o importas el archivo Excel o CSV de tu banco.' },
    { q: '¿Dónde se guardan mis datos?', a: 'Tú eliges: en tu iPhone y tu iCloud personal, sin cuenta de Yala, o en tu cuenta en la nube de Yala, con inicio de sesión de Apple o Google. No hay contraseña de Yala.' },
    { q: '¿Qué información sale de mi teléfono?', a: 'Sale información si eliges la cuenta en la nube o usas Grupos, si activas Yala IA, la voz o la foto (te avisamos antes), para consultar tipos de cambio y en una analítica mínima sin tus datos financieros. El detalle está en la política de privacidad.' },
    { q: '¿Funciona en Android o en la computadora?', a: 'De momento no: Yala funciona solo en iPhone con iOS 26 o superior.' },
    { q: '¿Funciona sin internet?', a: 'Sí. Anotar, presupuestos, gráficos y widgets van sin conexión. Internet solo hace falta para sincronizar, Grupos, tipos de cambio y Yala IA.' },
    { q: '¿Puedo usar varias monedas?', a: 'Sí. Yala maneja más de 50 divisas y muestra los totales en tu moneda principal con el tipo de cambio.' },
    { q: '¿Puedo dividir gastos con amigos o con mi pareja?', a: 'Sí, con Grupos: repartes cada gasto en partes iguales, por porcentaje, por monto o por partes, y Yala te dice quién le paga a quién. Está en el plan Gratis.' },
    { q: '¿Qué pasa si cambio de teléfono?', a: 'Con tu iCloud personal se sincronizan solos al configurar el nuevo iPhone con la misma cuenta de iCloud. Con tu cuenta en la nube, inicia sesión con la misma cuenta de Apple o Google y tus datos vuelven.' },
    { q: '¿Puedo llevarme mis datos?', a: 'Cuando quieras, en CSV o Excel, desde la app. Exportar todo está en el plan Gratis.' },
    { q: '¿Y si dejo de pagar Pro?', a: 'No pierdes nada: tus datos se quedan y solo se apagan las funciones Pro.' },
    { q: '¿Yala da asesoría financiera?', a: 'No. Yala te ayuda a registrar y entender tu dinero; no recomienda inversiones ni productos financieros.' },
  ],
  en: [
    { q: 'What is Yala?', a: 'Yala is a personal finance app for iPhone. You log expenses and income in seconds, set budgets with alerts and see where your money goes. It’s made in Lima, Peru, and has been on the App Store since March 2026.' },
    { q: 'How much does Yala cost?', a: 'It’s free to download and has a Free plan with no end date. Yala Pro costs S/ 12.90 a month or S/ 99.90 a year in Peru; in other countries the App Store shows the local price. Pro comes with a one-month free trial.' },
    { q: 'What does the Free plan include and what does Yala Pro add?', a: 'Free: up to 4 accounts, manual logging and Siri shortcuts, up to 3 budgets with alerts, planned payments, widgets, more than 50 currencies, Groups, and CSV or Excel import and export. Pro adds unlimited accounts and budgets, screenshot reading, dictation and receipt photos, Yala AI and advanced reports.' },
    { q: 'Does Yala connect to my bank?', a: 'No. Yala doesn’t connect to banks or ask for your credentials. You log, share a receipt screenshot (Pro) or import your bank’s Excel or CSV file.' },
    { q: 'Where is my data stored?', a: 'You choose: on your iPhone and your personal iCloud, with no Yala account, or in your Yala cloud account, signing in with Apple or Google. There is no Yala password.' },
    { q: 'What information leaves my phone?', a: 'Information leaves the phone if you choose the cloud account or use Groups, if you turn on Yala AI, voice or photo (we tell you first), to look up exchange rates, and in minimal analytics without your financial data. Details are in the privacy policy.' },
    { q: 'Does it work on Android or on a computer?', a: 'Not for now: Yala runs only on iPhone with iOS 26 or later.' },
    { q: 'Does it work offline?', a: 'Yes. Logging, budgets, charts and widgets work offline. You only need internet to sync, for Groups, exchange rates and Yala AI.' },
    { q: 'Can I use several currencies?', a: 'Yes. Yala handles more than 50 currencies and shows totals in your main currency using the exchange rate.' },
    { q: 'Can I split expenses with friends or my partner?', a: 'Yes, with Groups: split each expense equally, by percentage, by amount or by shares, and Yala tells you who pays whom. It’s in the Free plan.' },
    { q: 'What happens if I change phones?', a: 'With your personal iCloud, everything syncs when you set up the new iPhone with the same iCloud account. With your cloud account, sign in with the same Apple or Google account and your data comes back.' },
    { q: 'Can I take my data with me?', a: 'Any time, as CSV or Excel, from the app. Exporting everything is in the Free plan.' },
    { q: 'What if I stop paying for Pro?', a: 'You lose nothing: your data stays and only the Pro features turn off.' },
    { q: 'Does Yala give financial advice?', a: 'No. Yala helps you record and understand your money; it doesn’t recommend investments or financial products.' },
  ],
};
