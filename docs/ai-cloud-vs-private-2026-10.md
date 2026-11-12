# Yala IA en modo nube y en modo privado — octubre 2026

> Fecha: 2026-10-18. Árbol medido: `origin/2.2` (`9e341a461`). Card `tablero-partir-la-ia-segun-modo-nube-o-privado-0y9k`.
> Punto de partida: `docs/ai-usage-review-2026-10.md` §6. **No cambia modelo ni proveedor.** No se hizo ninguna llamada
> de pago: los costes son **estimaciones** y se marcan como tales.

## Resumen en cinco líneas

1. Hoy el modo no cambia nada de Yala IA: en privado y en nube el chat manda el mismo resumen al servicio de IA.
2. Propuesta: en modo nube, Yala IA **pide los datos que le faltan** con herramientas que leen tu cuenta en la nube
   (cualquier fecha, cualquier comercio, búsqueda por nota). En privado, todo sigue igual.
3. Ya está construido y probado, **apagado** en la app y en el gateway. Encendido, el chat se ve igual.
4. Coste estimado: una pregunta que no necesita más datos cuesta un ~20 % más; una que sí, entre 1,5 y 2,5 veces lo de
   hoy; el peor caso, unas 7 veces, y está acotado.
5. Antes de encenderlo, Jürgen decide tres cosas: el texto de consentimiento de la nube, cómo se explica el modo
   privado y las cuotas. Cada una tiene su card.

## 1. Qué hace Yala IA hoy en cada modo

| | Con tu cuenta en tu iCloud privado | Con tu cuenta en la nube |
|---|---|---|
| Dónde viven tus datos | Tu iPhone y tu iCloud | Los servidores de Yala (y tu iPhone) |
| Qué se manda al preguntar | Un resumen de los últimos 13 meses, armado en el iPhone | **Lo mismo** |
| Qué incluye el resumen | Saldos y nombres de cuentas, totales por categoría y subcategoría (mes actual y tres anteriores, año), 20 comercios, 10 etiquetas, presupuestos, pagos recurrentes, patrones por día de la semana y **los gastos más grandes del mes en curso** (hasta 10 por subcategoría en 10 subcategorías: fecha, importe, comercio y cuenta) | Lo mismo |
| Por dónde pasa | El gateway de Yala → un servicio de IA. Nada se guarda: el gateway solo registra tarea, modelo, tiempo y tokens | Igual |
| Qué no puede contestar | Lo que se sale del resumen: un mes de hace medio año, un comercio que no está entre los 20, un movimiento concreto de otro mes, buscar por nota | Igual |

Medido en `FullFinancialContextBuilder.swift` (`buildTopTxBySubcategory` sobre `currentMonthExpenseTx`).

**Hallazgo:** el consentimiento del chat de hoy (`aiConsent.chatMessage`) enumera saldos, totales, comercios,
presupuestos y recurrentes, pero **no dice que también van los gastos más grandes del mes** uno a uno. Es así en los dos
modos y desde antes de esta sesión. Va en la card de la decisión (b) y en el ticket
`chat-consent-does-not-mention-this-months-largest-expenses`.

## 2. Qué cambia con el camino ampliado encendido

**En modo privado: nada.** La app ni siquiera mira el flag: la petición sale byte a byte como hoy (lo fijan
`YalaIAChatRoutingTests` y `ProxyTaskHeaderTests`).

**En modo nube:** la misma pregunta y el mismo resumen, y además el modelo puede pedir datos con seis herramientas de
solo lectura sobre tu cuenta en la nube. Son las del conector de Yala para Claude, con sus cálculos ya contrastados con
los de la app:

| Herramienta | Qué devuelve |
|---|---|
| Cuentas y saldos | Cada cuenta con su saldo y el total en tu divisa |
| Categorías | Categorías y subcategorías |
| Buscar movimientos | Movimientos de cualquier fecha, por cuenta, categoría o texto de la nota; hasta 50 por consulta |
| Resumen de un periodo | Ingresos, gastos, ahorro y lo que más pesó, de cualquier periodo |
| Estado de los presupuestos | Gastado, lo que queda y si va en riesgo |
| Pagos recurrentes | Importe, próximo cobro y equivalente mensual |

Lo que nota el usuario: preguntas que hoy terminan en «no tengo ese dato» pasan a tener respuesta. Por ejemplo, «¿cuánto
gasté en Uber en marzo?», «¿cuándo pagué la matrícula?» o «¿en qué se fue mi dinero el verano pasado?». Si el resumen ya
responde, el modelo no usa herramientas. El chat se ve igual; una pregunta que usa herramientas tarda unos segundos más.

Lo que no cambia: el modelo (el mismo de `chat.answer`), el proveedor, el registro de gastos desde el chat, las
sugerencias y los grupos (tienen su propia card).

## 3. Coste por pregunta (estimado)

Precios de `gpt-6-luna` (`docs/ai-usage-review-2026-10.md` §2): entrada 0,10 USD por millón de tokens, entrada en
caché 0,01, salida 0,50. Tamaños **medidos** con datos de prueba (6 cuentas, 40 subcategorías, 600 movimientos): las
definiciones de las seis herramientas más la instrucción añadida suman ≈1 500 tokens por llamada al modelo; una
respuesta de herramienta, entre ≈300 (saldos, resumen de un mes) y ≈4 200 tokens (50 movimientos).

Base: una pregunta de hoy con ≈6 500 tokens de resumen y 150 de respuesta (el supuesto de la revisión de octubre). El
banco midió 0,20 USD por 1 000 preguntas con perfiles más pequeños.

| Caso | Llamadas | Coste (≈) | Frente a hoy |
|---|---|---|---|
| Hoy, en los dos modos | 1 | 0,0007 USD | — |
| Nube, el resumen alcanza | 1 | 0,0009 USD | +20 % |
| Nube, una herramienta | 2 | 0,0011–0,0018 USD (con o sin caché de prompts) | ×1,5–2,5 |
| Nube, peor caso (tope de 3 rondas y 4 herramientas) | hasta 4 | ≈0,005 USD | ×7 |

Por usuario Pro y mes, con 30 preguntas y la mitad usando herramientas: ≈0,04 USD (hoy ≈0,02). El techo lo pone la
cuota: 75 preguntas al día en el peor caso serían ≈11 USD al mes, que nadie hace.

Tiempo: cada ronda con herramientas suma una llamada al modelo (p95 de `chat.answer`: 2,1 s) y las lecturas de la
base. La app espera hasta 30 s en este camino (hoy 20 s). El gateway lanza en paralelo las consultas de una misma ronda,
corta la que pasa de 6 s, deja de pedir herramientas a los 12 s y, si una llamada falla después de usar herramientas,
repite una vez la pregunta sin ellas: el usuario recibe su respuesta igual.

**Medición**: cada pregunta del camino ampliado deja en el log del gateway (`ai_route`) las rondas, qué herramientas
usó, cuánto devolvieron y los tokens sumados. Con dos semanas de eso, la tabla de arriba se sustituye por la medida.
Guardar esos números fuera del log sigue siendo `gateway-does-not-record-ai-token-usage`.

## 4. Riesgo de privacidad

- **Privado:** sin cambios. Queda el hallazgo del §1: el texto no menciona los gastos del mes uno a uno.
- **Nube, qué sale de más:** solo lo que el modelo pide para esa pregunta, que puede incluir **notas** escritas por el
  usuario y movimientos de **cualquier fecha**. El consentimiento de hoy («un resumen de tus últimos 13 meses») no lo
  cubre: el flag no se enciende sin texto nuevo (decisión (d)).
- **Quién lee los datos:** el gateway, con la sesión del propio usuario. La base de datos solo le deja ver las filas de
  ese usuario, y el gateway solo puede hacer lecturas de nueve tablas (lista cerrada). Ninguna herramienta escribe,
  ninguna toca grupos y el JWT del usuario no llega al servicio de IA.
- **Una nota con instrucciones** («ignora tus reglas…»): el peor caso es una respuesta rara para ese mismo usuario. No
  hay herramienta que escriba, que lea a otro usuario ni que salga a internet.
- **Un enlace en la respuesta:** la burbuja del chat pinta los enlaces que escriba el modelo, y una nota de un gasto de
  grupo la escribió otro miembro. Tocar un enlace inventado podría mandar cifras a un tercero. Se arregla en la app antes
  de encender (ticket `yala-ia-answer-renders-model-links-as-tappable`).
- **Nada se guarda:** el log del gateway no lleva preguntas, respuestas ni resultados de herramientas (lo fija un test).

## 5. Decisiones

Recomendación primero. Lo reversible lo decidió la sesión y está implementado así; lo que cambia coste o privacidad de
cara al usuario espera a Jürgen en su card.

### (a) Cómo explora más Yala IA en la nube — decidido por la sesión

- **A (recomendada, implementada):** herramientas desde el gateway contra tu cuenta en la nube, además del resumen de hoy.
  Quita los topes y solo cuesta de más cuando hace falta.
- B: herramientas ejecutadas en el iPhone. Valdría también en privado, pero el diseño quedaría en la app (cada cambio,
  una versión) y cambiaría lo que se manda en privado.
- C: un resumen más grande en la nube (más meses, más comercios). Paga tokens en cada pregunta y sigue teniendo topes.

### (b) Qué se manda en privado y cómo se cuenta — Jürgen

Lo que se manda no cambia (decidido por la sesión, porque el encargo lo pide). Lo que decide Jürgen es el texto:

- **A (recomendada):** corregir el texto de hoy para que diga también «tus gastos más grandes de este mes» (texto P1 del
  anexo). Es verdad hoy y cierra el hallazgo.
- B: A, y además una línea en Ajustes › Privacidad de la IA que explique que en la nube Yala IA puede consultar más.
- C: dejarlo como está.

### (c) Cuotas por modo — Jürgen

Implementado: **la misma cuota en los dos modos** (75 preguntas al día en Pro) y una pregunta gasta un uso aunque haga
varias llamadas, con topes por pregunta (3 rondas, 4 herramientas, 16 000 caracteres por resultado).

- **A (recomendada):** así, y revisar con dos semanas de medición.
- B: más preguntas en la nube (por ejemplo, 100 al día), como parte de la ventaja.
- C: un cupo aparte para las preguntas que usan herramientas (por ejemplo, 30 al día); pasado, se contesta con el
  resumen.

### (d) El consentimiento de la nube — Jürgen (bloquea el encendido)

- **A (recomendada):** texto nuevo para la nube (N1 del anexo), que se enseña una vez a quien tenga la cuenta en la nube
  antes de su primera pregunta con el camino ampliado.
- B: dejar el texto de hoy y limitar las herramientas a lo que cubre (sin notas, 13 meses). Vale menos.
- C: un interruptor aparte en Privacidad de la IA («dejar que Yala IA consulte todos tus datos»), apagado por defecto.

## 6. Qué quedó construido (todo apagado)

| Dónde | Qué |
|---|---|
| Gateway | Tarea nueva `chat.explore` (mismo modelo y cuota que `chat.answer`), el bucle con topes y la lista cerrada de lecturas (`gateway/src/ai/explore/`). Flag `AI_CLOUD_EXPLORE_ROLLOUT_PERCENT`, a `"0"` en staging y en producción; un test se pone rojo si alguien lo cambia sin querer |
| Conector MCP | Sus seis herramientas, separadas en `mcp/src/toolCore.ts` para que el gateway las use sin copiarlas. Un test compara los dos esquemas campo a campo |
| App | `YalaIAChatRouting`: en privado, el camino de siempre; en la nube con el flag y sesión, `chat.explore` con el JWT y la zona horaria. El flag (`aiCloudExploreRolloutPercent` en `/config`) falla cerrado en todos los builds |

Con el flag del gateway a 0, una petición `chat.explore` se contesta como `chat.answer`; sin sesión, la app usa el
camino de siempre. Ningún caso es un error nuevo.

## 7. Cómo se enciende, cuando estén las decisiones

1. Jürgen decide (d) y, si quiere, (b) y (c). Una sesión mete los textos en los 16 idiomas y, con A en (d), la pantalla
   que lo enseña una vez.
2. Staging: `AI_CLOUD_EXPLORE_ROLLOUT_PERCENT = "100"` en `[vars]` de `gateway/wrangler.toml`, ajustar el test de
   `config.test.ts` y desplegar staging.
3. QA en un iPhone con `Yala Dev`, cuenta en la nube y el secreto de desarrollo: preguntas que el resumen no cubre.
   `wrangler tail` enseña `explore: "tools"`, rondas y tokens.
4. Producción por porcentaje (10 → 50 → 100) mirando el log y el coste.

## Anexo · Textos propuestos (16 idiomas)

No están en la app. Se pegan cuando Jürgen decida. Ninguno nombra al proveedor: el nombre vive en la Política de
privacidad, enlazada desde el mismo aviso.

### P1 — Privado: el texto de hoy, corregido (`aiConsent.chatMessage` con la cuenta en tu iCloud privado)

| Idioma | Texto |
|---|---|
| es, es-419, es-AR, es-ES | Yala responde tus preguntas sobre tus finanzas con tus propios datos. Para eso envía a un servicio de IA un resumen de tus últimos 13 meses: saldos y nombres de tus cuentas, totales por categoría, comercios frecuentes, presupuestos, pagos recurrentes y tus gastos más grandes de este mes. Se usa solo para responderte y no para entrenar a la IA. |
| en, en-GB | Yala answers your questions about your finances using your own numbers. To do that it sends an AI service a summary of your last 13 months: your account balances and names, totals by category, frequent merchants, budgets, recurring payments, and your largest expenses this month. It’s used only to answer you, not to train the AI. |
| de | Yala beantwortet deine Fragen zu deinen Finanzen mit deinen eigenen Zahlen. Dafür wird eine Zusammenfassung der letzten 13 Monate an einen KI-Dienst gesendet: Salden und Namen deiner Konten, Summen nach Kategorie, häufige Händler, Budgets, wiederkehrende Zahlungen und deine größten Ausgaben in diesem Monat. Sie wird nur für die Antwort verwendet, nicht zum Trainieren der KI. |
| fr | Yala répond à tes questions sur tes finances avec tes propres chiffres. Pour cela, il envoie à un service d’IA un résumé de tes 13 derniers mois : les soldes et noms de tes comptes, les totaux par catégorie, les commerces fréquents, les budgets, les paiements récurrents et tes plus grosses dépenses du mois. Il sert uniquement à te répondre, pas à entraîner l’IA. |
| it | Yala risponde alle tue domande sulle tue finanze con i tuoi numeri. Per farlo invia a un servizio di IA un riepilogo degli ultimi 13 mesi: saldi e nomi dei tuoi conti, totali per categoria, commercianti frequenti, budget, pagamenti ricorrenti e le tue spese più grandi di questo mese. Viene usato solo per risponderti, non per addestrare l’IA. |
| nl | Yala beantwoordt je vragen over je financiën met je eigen cijfers. Daarvoor gaat er een samenvatting van de afgelopen 13 maanden naar een AI-dienst: saldi en namen van je rekeningen, totalen per categorie, veelgebruikte verkopers, budgetten, terugkerende betalingen en je grootste uitgaven van deze maand. Die wordt alleen gebruikt om je te antwoorden, niet om de AI te trainen. |
| pl | Yala odpowiada na twoje pytania o finanse na podstawie twoich własnych liczb. W tym celu wysyła do usługi AI podsumowanie ostatnich 13 miesięcy: salda i nazwy twoich kont, sumy według kategorii, częstych sprzedawców, budżety, płatności cykliczne i twoje największe wydatki w tym miesiącu. Służy ono wyłącznie do odpowiedzi, a nie do trenowania AI. |
| pt, pt-BR | O Yala responde às suas perguntas sobre suas finanças com os seus próprios números. Para isso, envia a um serviço de IA um resumo dos seus últimos 13 meses: saldos e nomes das suas contas, totais por categoria, comerciantes frequentes, orçamentos, pagamentos recorrentes e seus maiores gastos deste mês. Ele é usado só para responder, não para treinar a IA. |
| pt-PT | O Yala responde às tuas perguntas sobre as tuas finanças com os teus próprios números. Para isso, envia a um serviço de IA um resumo dos teus últimos 13 meses: saldos e nomes das tuas contas, totais por categoria, comerciantes frequentes, orçamentos, pagamentos recorrentes e as tuas maiores despesas deste mês. É usado só para te responder, não para treinar a IA. |
| ja | Yalaがあなた自身の数字をもとに、お金に関する質問にお答えします。そのために、直近13か月の概要（口座の残高と名前、カテゴリ別の合計、よく利用する店舗、予算、定期的な支払い、今月の大きな支出）をAIサービスに送ります。回答のためだけに使われ、AIの学習には使われません。 |
| zh-Hans | Yala 会根据你自己的数字回答你的财务问题。为此，它会把你最近 13 个月的摘要发送给 AI 服务：账户余额和名称、按类别的总计、常用商家、预算、定期付款以及你本月最大的几笔支出。这些数据仅用于回答你，不会用于训练 AI。 |

### N1 — Nube con el camino ampliado (`aiConsent.chatMessage` con la cuenta en la nube)

| Idioma | Texto |
|---|---|
| es, es-419, es-AR, es-ES | Yala responde tus preguntas sobre tus finanzas con tus propios datos. Para eso envía a un servicio de IA un resumen de tus últimos 13 meses y, cuando la pregunta lo necesita, los datos de tu cuenta en la nube que hacen falta para responderla: movimientos de cualquier fecha con su nota, cuentas, presupuestos y pagos recurrentes. Se usa solo para responderte y no para entrenar a la IA. |
| en, en-GB | Yala answers your questions about your finances using your own numbers. To do that it sends an AI service a summary of your last 13 months and, when a question needs it, the data from your cloud account needed to answer it: entries from any date with their notes, accounts, budgets, and recurring payments. It’s used only to answer you, not to train the AI. |
| de | Yala beantwortet deine Fragen zu deinen Finanzen mit deinen eigenen Zahlen. Dafür wird eine Zusammenfassung der letzten 13 Monate an einen KI-Dienst gesendet und, wenn eine Frage es erfordert, die Daten aus deinem Cloud-Konto, die für die Antwort nötig sind: Einträge aus jedem Zeitraum mit ihrer Notiz, Konten, Budgets und wiederkehrende Zahlungen. Sie werden nur für die Antwort verwendet, nicht zum Trainieren der KI. |
| fr | Yala répond à tes questions sur tes finances avec tes propres chiffres. Pour cela, il envoie à un service d’IA un résumé de tes 13 derniers mois et, quand une question le demande, les données de ton compte dans le cloud nécessaires pour y répondre : des mouvements de n’importe quelle date avec leur note, tes comptes, tes budgets et tes paiements récurrents. Elles servent uniquement à te répondre, pas à entraîner l’IA. |
| it | Yala risponde alle tue domande sulle tue finanze con i tuoi numeri. Per farlo invia a un servizio di IA un riepilogo degli ultimi 13 mesi e, quando una domanda lo richiede, i dati del tuo account nel cloud necessari per rispondere: movimenti di qualsiasi data con la loro nota, conti, budget e pagamenti ricorrenti. Vengono usati solo per risponderti, non per addestrare l’IA. |
| nl | Yala beantwoordt je vragen over je financiën met je eigen cijfers. Daarvoor gaat er een samenvatting van de afgelopen 13 maanden naar een AI-dienst en, als een vraag erom vraagt, de gegevens uit je cloudaccount die nodig zijn om te antwoorden: boekingen van elke datum met hun notitie, rekeningen, budgetten en terugkerende betalingen. Ze worden alleen gebruikt om je te antwoorden, niet om de AI te trainen. |
| pl | Yala odpowiada na twoje pytania o finanse na podstawie twoich własnych liczb. W tym celu wysyła do usługi AI podsumowanie ostatnich 13 miesięcy, a gdy pytanie tego wymaga, także dane z twojego konta w chmurze potrzebne do odpowiedzi: operacje z dowolnej daty z ich notatką, konta, budżety i płatności cykliczne. Służą one wyłącznie do odpowiedzi, a nie do trenowania AI. |
| pt, pt-BR | O Yala responde às suas perguntas sobre suas finanças com os seus próprios números. Para isso, envia a um serviço de IA um resumo dos seus últimos 13 meses e, quando a pergunta precisa, os dados da sua conta na nuvem necessários para responder: lançamentos de qualquer data com a nota, contas, orçamentos e pagamentos recorrentes. Eles são usados só para responder, não para treinar a IA. |
| pt-PT | O Yala responde às tuas perguntas sobre as tuas finanças com os teus próprios números. Para isso, envia a um serviço de IA um resumo dos teus últimos 13 meses e, quando a pergunta precisa, os dados da tua conta na nuvem necessários para responder: movimentos de qualquer data com a nota, contas, orçamentos e pagamentos recorrentes. São usados só para te responder, não para treinar a IA. |
| ja | Yalaがあなた自身の数字をもとに、お金に関する質問にお答えします。そのために、直近13か月の概要をAIサービスに送ります。質問に必要な場合は、回答に必要なクラウドアカウントのデータ（任意の日付の記録とそのメモ、口座、予算、定期的な支払い）も送ります。回答のためだけに使われ、AIの学習には使われません。 |
| zh-Hans | Yala 会根据你自己的数字回答你的财务问题。为此，它会把你最近 13 个月的摘要发送给 AI 服务；当问题需要时，还会发送回答所需的云端账户数据：任意日期的记录及其备注、账户、预算和定期付款。这些数据仅用于回答你，不会用于训练 AI。 |

Términos: «movimientos» / «entries» / «lançamentos» siguen el vocabulario de cada idioma en la app (se comprueba contra
`Localizable.strings` al pegarlos con `/l10n-check`).
