# Roadmap de Yala, de 2.1 a 4.0

> **Propuesta del 2026-10-19**, la víspera del lanzamiento de 2.1. No mueve ninguna card: la asignación la decide Jürgen.
> Cubre las **673 cards abiertas** de Yala en el tablero y lo que no tiene card todavía (marcado como **idea nueva**).
> La tabla card por card está en `docs/roadmap-asignacion.tsv`; las reglas para asignar lo que llegue después, en
> `docs/criterios-de-version.md`.

## La estrategia en cinco frases

1. **Primero igualar y después superar.** Pablo y Clever ya apuntan solos los gastos que llegan por el correo del banco, y
   Pablo además por WhatsApp. Yala lo iguala en 2.3 (correo) y 2.5 (WhatsApp), y gana con su interfaz, Grupos y las
   divisas.
2. **2.2 es la versión de entender la app, no de añadirle cosas.** La auditoría UX dejó más de 150 arreglos decididos; si
   se le suman funciones grandes, no sale nunca.
3. **La nube se endurece antes de abrir la web.** Hay unos 200 bugs de nube abiertos, casi todos de prioridad baja. Con la
   web (3.0), la nube pasa a ser el camino principal, así que entre 2.3 y 2.5 se cierran todos.
4. **La masa llega por la web y por Android.** La web (3.0) va antes que Android (4.0), como ya está decidido, y como app
   web instalable (PWA) llega también a los teléfonos Android.
5. **Pro cobra lo que cuesta por uso** (IA, correo, WhatsApp), con un cupo de prueba. Lo que hace que las cifras sean
   correctas es gratis.

## Resumen por versión

| Versión | Objetivo en una frase | Hito que la define | Cards | Meta de bugs |
|---|---|---|---|---|
| **2.1** | Sale la nube, con las sesiones rediseñadas. | Envío a la App Store (20-oct). | 5 | Sin bugs de prioridad alta conocidos en el build enviado |
| **2.1.1** | Arreglar lo que vio el QA guiado del build 18. | Activar la nube y la primera foto no fallan. | 14 | Atacar los 13 bugs; 0 de prioridad alta |
| **2.2** | Que cada pantalla se entienda a la primera. | Auditoría UX cerrada, y Grupos y Flujo de caja con el mismo diseño que el resto de la app. | 245 | 50 bugs + 157 arreglos de UX; 0 alta en toda la app |
| **2.3** | Que Yala apunte sola los gastos que llegan del banco. | Leer el correo de alertas del banco. | 107 | 40 bugs; 0 de nube de prioridad media |
| **2.4** | Que las cifras reflejen tu mes real. | El «Mes financiero» y la sección de Ahorros. | 113 | 70 de 95 bugs; 0 de nube con riesgo de datos |
| **2.5** | Que se pueda hablar con Yala, también por WhatsApp. | Asistente por WhatsApp. | 185 | 100 de 140 bugs; nube cerrada por completo (condición de 3.0) |
| **3.0** | Yala en el navegador, con la misma cuenta y la misma suscripción. | La web con el Panel y el registro. | 1 | 0 alta en la web; 0 regresiones en iOS |
| **3.1** | Finanzas en pareja o en familia. | Plan dúo: cuentas y presupuestos compartidos. | 1 | 0 alta en lo compartido |
| **3.2** | Apuntar y mirar desde el reloj. | App de Apple Watch. | 1 | — |
| **4.0** | Yala nativa en Android. | Android en Google Play, con captura desde las notificaciones del banco. | 1 | 0 alta en Android |

Las cifras de cards cuentan la propuesta de este documento. Hoy hay 244 en 2.2, 11 en 2.3, 12 en 2.1 y 406 sin versión.

---

## Las versiones, una por una

### 2.1 — Sale la nube

**Objetivo.** Publicar 2.1 con la nube encendida y el rediseño de sesiones.

**Hitos.** La checklist de envío verificada; la IA eligiendo modelo en el gateway, con su QA cerrado; la ficha de la App
Store al día.

**Cards que entran.** «Checklist de envío de 2.1 a App Store, verificada contra el código», «IA sesión 2: la app manda su
tarea, las 12 llamadas por el banco, voz en 10 idiomas y cupo free 5+5», «Aplicar plan Superapp al lanzar 2.1…» (de Lola) y
«Ficha de la App Store: quitar «detección de gastos hormiga» de los textos guardados…». Esta última **toca `marketing/`**,
que es de Lola: si no se quita antes del envío, la ficha promete una función que la app no tiene.

**Meta de bugs.** Ningún bug de prioridad alta conocido dentro del build que se envía.

**Criterio de salida.** El build está en revisión de Apple con la ficha corregida.

### 2.1.1 — Parche del lanzamiento

**Objetivo.** Arreglar lo que el QA guiado del 19-oct encontró en el build 18, sin funciones nuevas.

**Hitos.**
1. «Activar la nube» termina sin quedarse en el ~60 % y sin pedir cerrar y abrir la app.
2. La primera foto después de instalar se lee bien. Le pasa a quien acaba de pagar Pro, que es el cliente más valioso.
3. Volver a tu cuenta de Grupos por «Ya tengo una cuenta» enseña tus grupos sin reiniciar la app.

**Cards que entran (14).** Las cuatro que están en curso en 2.1 («Al cancelar la voz, la música de otra app no vuelve a
sonar», «Al volver a tu cuenta de Grupos por «Ya tengo una cuenta»…», ««Dónde viven tus datos» dice que tus grupos usan una
cuenta vieja…», ««Volver a iCloud › Empezar sin ellos» falla con un iCloud grande…»). Las cuatro listas para lanzar en 2.1.
Dos de 2.2 que pesan más de lo que dice su versión: «Al activar la nube con muchos movimientos, la barra se queda quieta en
~60 %…», porque empuja a cerrar la app en plena migración, y «La primera foto tras instalar falla…». Además, el guard del
Worker («Llevar a 2.1 el guard que impide bajar el manifest del Worker»), el arreglo de backend para el segundo
dispositivo de una cuenta que volvió a iCloud, la de iCloud Drive apagado (ya mergeada en el PR #562, falta confirmarla) y
el device-QA pendiente. Si alguna entra en un
build nuevo antes del envío, pasa a 2.1.

**Meta de bugs.** Los 13 bugs; 0 de prioridad alta (hoy hay 6).

**Criterio de salida.** Los 13 cerrados o vistos en un iPhone; ningún bug de prioridad alta nuevo en la primera semana de
2.1 en la App Store.

### 2.2 — Se entiende a la primera

**Objetivo.** Que cada pantalla se entienda sin ayuda y que toda la app parezca la misma.

**Hitos.**
1. **Auditoría UX cerrada:** los 157 arreglos de copy y de flujo ya decididos, incluido el formulario de registro (lote 2),
   que es la pantalla más usada.
2. **Coherencia visual:** Grupos y Flujo de caja con el diseño de Registros y Estadísticas.
3. **Tarjetas:** la tarjeta con varias divisas (entregas 2 a 4) y la **tarjeta de crédito con fecha de corte y fecha de
   pago**, en la misma ventana de cambio de esquema.
4. **Siri con IA de iOS 27** y el widget extragrande.
5. **Saber cuándo falla la app** (avisos de errores con Sentry), antes de crecer.

**Cards que entran (245).** Las de la auditoría UX y de UI de 2.2 que están en QA, listas para lanzar o en espera de
decisión. «Flujo de caja tiene que sentirse la misma app…», «Grupos tiene que sentirse la misma app…», «Ajustar tarjeta de
crédito: fecha de corte, fecha de pago y aviso antes de pagar», las tres entregas de «Tarjeta con varias divisas», «Integrar
Yala con el nuevo Siri con IA de iOS 27», «Widgets extragrandes en el iPhone con iOS 27», «Sentry: avisos de errores y
caídas en la app y el backend», «Revisar a fondo cómo usa Yala la IA…» (como revisión, sin implementar) y los bugs ya
apuntados. La lista completa está en el apéndice.

**Revisión de 2.2: qué sobra y qué falta.**

*Sobra; se propone sacarlo:*

| Card | A dónde | Por qué |
|---|---|---|
| Registrar movimientos desde correos de alertas del banco | 2.3 | Es la función estrella de la paridad y necesita una pieza nueva en el backend: un buzón por persona. Merece ser el centro de su propia versión y su propio QA. |
| Registrar movimientos desde la notificación del banco (Atajos + App Intent) | 2.3 | Va con el correo: es el mismo bloque de captura automática. |
| Ciclo del mes según tu día de pago | 2.4 | Cambia todos los selectores de período, y ese terreno ya dio cuatro bugs de fechas (ver `CLAUDE.md`). Pide su propia versión. |
| Pagos en cuotas · Seguimiento de ahorros con metas · Seguimiento de deudas personales · El hero de cada vista… · Las cuentas se ven poco… | 2.4 | Funciones nuevas de finanzas: son el tema de 2.4. |
| Rediseñar las notificaciones desde cero | 2.4 | Proyecto propio, no un arreglo de la auditoría. |
| Rediseñar por completo los tutoriales… · Logos de suscripción… · Yala en el iPhone Duo… | 2.3 | Los tutoriales, mejor cuando la UX de 2.2 ya esté asentada; los logos van con la detección de suscripciones; el Duo, con el bloque de tamaños. |
| Las cinco del conector de Claude (endurecerlo, saldo de hoy, zona horaria, diseño del servidor, issue opcional) | 2.5 | El conector sale a producción con la nube ya endurecida. |
| Yala IA entiende Grupos… · Explorar si Yala IA puede ayudar en Flujo de caja | 2.5 | Van con el bloque de IA. |

*Falta; se propone añadirlo* (31 cards sin versión): bugs de prioridad media que dan **cifras distintas para el mismo
dinero**, como «El saldo de arriba del Panel y la hoja «¿Cuánto tienes hoy?» dan cifras distintas…», «Ingresos y gastos del
mismo mes salen distintos según la pantalla…», «El «vs mes pasado» de los heros… cuenta un día de más si el gasto se fechó a
medianoche» (la trampa de `DateInterval` de `CLAUDE.md`) y «Un pago planificado de «Una sola vez» aparece como «Mensual»…».
También los de Grupos que la persona ve («…enseña «Error de Yala.GroupsRPCError 1»», «Tocar una notificación de grupo no
abre el grupo…»), el contraste de los ingresos en modo oscuro, la Bandeja con texto grande en el iPhone SE y los tests rojos
que frenan el gate. Faltan además, como prerrequisitos de Jürgen, «Aplicar en producción el DDL de parentAccountID…» y
«Desplegar CD_parentAccountID a Production en CloudKit». Esta última está asignada a Lola, pero es una tarea de consola.

**Meta de bugs.** Los 157 arreglos de UX y al menos los 50 bugs (27 de prioridad media). 0 de prioridad alta en toda la app.
0 de prioridad media en UX, divisas y Grupos.

**Criterio de salida.** La auditoría por flujos no deja ningún hallazgo abierto en 2.2. Grupos y Flujo de caja pasan la
revisión visual de Jürgen sobre el simulador. Las dos tarjetas pasan su QA en iPhone.

### 2.3 — Yala apunta sola

**Objetivo.** Que los gastos que el banco ya te avisa entren solos a la Bandeja, sin escribirlos.

**Hitos.**
1. **Correo de alertas del banco:** una dirección propia por persona. El gateway lee el correo con IA y el movimiento llega
   a la Bandeja por confirmar. Empieza con los bancos más usados en Perú y se mide qué porcentaje de alertas acierta.
2. **Notificación del banco** con Atajos de iOS 27 y una App Intent.
3. **Detectar pagos recurrentes y suscripciones** en el historial, con logos.
4. **Gastos hormiga:** cuánto suman al mes los gastos pequeños y frecuentes.
5. **Empezar con datos:** importar el último estado de cuenta desde la bienvenida, y que el CSV que exporta Yala se pueda
   volver a importar.
6. **Manos libres y reglas en lenguaje natural** («lo menor a S/5 va a Gastos hormiga»).
7. **iPad y iPhone Duo**, en paralelo, según el ADR del 2026-09-27.
8. **Nube:** las 22 cards de prioridad media.

**Cards que entran (107).** «Registrar movimientos desde correos de alertas del banco», «Registrar movimientos desde la
notificación del banco…», «Detectar pagos recurrentes y suscripciones…», «Logos de suscripción…», «Detectar gastos
hormiga…», «Bienvenida: proponer importar el último estado de cuenta…», «El CSV que exporta Yala no se puede volver a
importar en Yala», «Modo manos libres…», «Reglas para clasificar gastos dichas en lenguaje natural…», «Panel: ranking de
comercios…», «Avisar unos días antes de que termine la prueba gratis…», «Soporte por WhatsApp…», «Yala IA: guía con
ejemplos…», «Rediseñar por completo los tutoriales…», «Yala en el iPhone Duo…», las de iPad, las dos de **control del coste
de IA** («Ninguna llamada de IA pone tope a la longitud de la respuesta…» y «No se guarda cuántos tokens gasta cada función
de IA…»), que deben estar antes de que el correo multiplique las llamadas, y «Analizar una mascota en la app» (la decisión).

**Meta de bugs.** Al menos 40 (25 de prioridad media). 0 de nube de prioridad media.

**Criterio de salida.** Con las alertas de correo de un banco peruano activadas, al menos el 90 % de los movimientos de una
semana llega a la Bandeja con el monto y el comercio bien leídos. Es un umbral propuesto: se ajusta al medir. Además, ningún
bug de nube de prioridad media queda abierto.

**Dependencias.** Un buzón de correo por persona en el backend (Cloudflare Email Routing o Workers, como dice la card). Si
la persona solo usa iCloud, el movimiento leído tiene que llegarle de alguna forma: o una cola en el servidor que el teléfono
recoge, o el correo exige cuenta en la nube. **Es una decisión de producto de Jürgen.** También hace falta la política de
privacidad al día (el correo pasa por el servidor) y el control de coste de IA.

### 2.4 — Tu mes real

**Objetivo.** Que el Panel cuente tu mes como lo vives: de cobro a cobro, con tus ahorros, tus deudas y tus cuotas.

**Hitos.**
1. **Mes financiero:** un período nuevo en el selector, que va de día de cobro a día de cobro.
2. **Sección de Ahorros:** las cuentas de ahorro y los depósitos a plazo juntos, con metas.
3. **Deudas y cuotas:** préstamos propios y compras a plazos con lo que queda por pagar.
4. **Cuentas con presencia:** la lista de Ajustes › Cuentas, el formulario, colecciones de cuentas y el perfil de negocio y
   personal.
5. **Presupuestos más listos:** que se adapten a los ingresos o los gastos, recomendados con IA y con predicción del mes en
   curso.
6. **Notificaciones rediseñadas,** también dentro de la Bandeja y con IA.
7. **Integridad de datos:** las 36 cards de nube con riesgo de perder, duplicar o no subir datos, y las de divisas que
   enseñan como exacta una cifra aproximada.

**Cards que entran (113).** «Ciclo del mes según tu día de pago…», «Seguimiento de ahorros con metas», «Seguimiento de
deudas personales», «Pagos en cuotas…», «El hero de cada vista…», «Las cuentas se ven poco…», «Ajustes › Cuentas…»,
«Formulario de cuenta…», «Archivar una cuenta: decidir…», «Colecciones de cuentas…», «Perfil Empresa y Personal…»,
«Presupuesto que se adapta…», «Presupuestos recomendados con IA», «Predicción del gasto del mes en curso…», «Exportar los
insights…», «Rediseñar las notificaciones desde cero», «2.2 · Notificaciones dentro de la Bandeja», «Notificaciones
inteligentes con IA», «Buscar gastos dentro de un grupo…», «Importar un grupo desde el export de Splitwise o Tricount…» y
los bugs de nube, Grupos y divisas de su tema.

**Meta de bugs.** Al menos 70 de los 95 bugs. 0 de prioridad media. 0 de nube con riesgo de datos.

**Criterio de salida.** El mes financiero da en el Panel, Estadísticas, presupuestos, informes, widgets e IA el mismo total
que un cálculo a mano en los dos bordes del período: el día de cobro a las 00:00 y el día anterior a las 23:59:59. Ninguna
cifra aproximada sale sin «≈».

### 2.5 — Yala conversa

**Objetivo.** Que se pueda hablar con Yala, también fuera de la app, y que la nube quede lista para la web.

**Hitos.**
1. **Asistente por WhatsApp:** anotar con texto, voz o foto; preguntar «¿en qué gasté más?»; recibir avisos.
2. **Yala IA hace más que crear registros:** consultar, explicar y resumir. Entiende Grupos, ayuda en Flujo de caja y
   contesta por voz, según la revisión de 2.2.
3. **Conector de Claude en producción,** con entrada por Apple o Google.
4. **Rachas y mascota,** si Jürgen aprueba la mascota en 2.3.
5. **Endurecimiento final de la nube:** se cierran los avisos y textos confusos que quedan. Es la condición para empezar la
   web.

**Cards que entran (185).** «Asistente de Yala por WhatsApp…», «Yala AI haga más que crear registros», «Analizar que Yala AI
responda por voz…», «Yala IA entiende Grupos…», «Explorar si Yala IA puede ayudar en Flujo de caja…», «Registrar un gasto de
grupo desde el chat o por voz…», «El chat registra como máximo cinco movimientos…», «Plugin de Yala para Claude…»,
«Conectar Yala en Claude iniciando sesión con Apple o Google», «Endurecer el conector MCP en producción…», «Idea: rachas de
registros…», 125 de nube y la deuda técnica de prioridad muy baja.

**Meta de bugs.** Al menos 100 de los 140. Cero cards de nube abiertas de prioridad baja o más, salvo las que se descarten
por escrito. Las de prioridad muy baja pueden quedar con la nota «revisar».

**Criterio de salida.** Una persona registra, pregunta y recibe un aviso por WhatsApp sin abrir la app. La nube queda sin
bugs abiertos que la web vaya a heredar.

**Dependencias del WhatsApp.** Cuenta en la nube, porque el número de teléfono se tiene que asociar a una cuenta. La
verificación de empresa en Meta. El coste por conversación. El cupo del plan gratis.

### 3.0 — Yala en la web

**Objetivo.** Usar Yala desde cualquier navegador, con la misma cuenta y la misma suscripción.

**Por qué es mayor.** Abre una plataforma, cambia dónde viven los datos de quien la usa (solo una cuenta en la nube puede
abrirse en la web) y cambia el cobro (suscripción por cuenta, pagable fuera de la App Store).

**Hitos.**
1. La web, instalable como app (PWA): Panel, registrar, Bandeja y Grupos.
2. Suscripción por cuenta, válida en iOS y en la web, con cobro en soles.
3. Entrar con Apple o Google en la web.
4. **Decisión de Jürgen:** si la nube pasa a ser la opción recomendada para quien llega nuevo. La privada se mantiene.

**Cards que entran.** «Yala en la web: ver el Panel y registrar gastos desde el navegador». Hoy está en 2.3, pero su propia
card dice «candidata a 3.0».

**Dependencias técnicas.**
- **Nube endurecida**, que es la salida de 2.5.
- **Entrar con Apple desde la web:** hoy no existe ese flujo; lo dice «Con Apple solo puedes entrar en la nube con el Apple
  ID del teléfono».
- **Otra defensa en lugar de App Attest**, que solo existe en Apple. Por ejemplo, un desafío anti-bots y límites por cuenta
  (idea nueva).
- **Suscripción por cuenta.** Las cards la describen latente detrás de un interruptor apagado.
- **Pagos.** Pablo cobra en soles y no acepta Yape ni Plin; aceptar Yape en la web sería una ventaja (idea nueva, hay que
  investigar el procesador).
- **La web de marketing (`Web/`) es de Lola.** La app web debe vivir en otro sitio, o se acuerda con ella.

**Meta de bugs.** 0 de prioridad alta en la web. 0 regresiones en iOS.

**Criterio de salida.** Una cuenta en la nube abre la web, ve el mismo saldo que en el iPhone, registra un gasto y lo ve
llegar al iPhone. Un pago en la web activa Pro en el iPhone.

### 3.1 — Juntos (plan dúo)

**Objetivo.** Que una pareja o una familia lleve sus finanzas juntas: cuentas, metas y presupuestos compartidos, y que cada
uno vea lo suyo.

**Por qué es mayor.** Cambia quién es dueño de una cuenta: hoy cada cuenta es de una sola persona. Y abre un plan de pago
nuevo, el Pro Dúo (idea nueva).

**Cards que entran.** «Cuentas y presupuestos compartidos de pareja o familia: propuesta».

**Dependencias.** La nube; se reutilizan las invitaciones de Grupos. Un modelo de propiedad compartida en el backend.
Conviene que la web exista, porque en Perú es muy probable que uno de los dos use Android.

**Criterio de salida.** Dos personas en dos teléfonos distintos ven el mismo saldo de una cuenta compartida y no ven las
cuentas que el otro no compartió.

### 3.2 — Yala en la muñeca

**Objetivo.** Apuntar un gasto y ver el saldo desde el Apple Watch.

**Cards que entran.** «App de Yala para Apple Watch…». Jürgen le dio prioridad baja el 9-sep. No necesita la nube: usa
complicaciones (WidgetKit) y las App Intents que ya existen.

### 4.0 — Yala en Android

**Objetivo.** Yala nativa en Android, con la misma cuenta y la misma suscripción.

**Cards que entran.** «Yala para Android».

**Dependencias.** Todo lo de 3.0, más el equivalente de App Attest (Play Integrity), avisos push propios (FCM) y el cobro de
Google Play con la suscripción por cuenta. **Decisión técnica pendiente:** Kotlin nativo, código compartido o Swift en
Android. La card cita una «Fase 0» sin empezar.

**Dónde superar a la competencia (idea nueva).** Android deja que una app lea las notificaciones de otras apps, con el
permiso de la persona. Yala podría apuntar sola cada aviso de la app del banco, sin correo ni Atajos.

### Más allá de 4.0 (ideas nuevas, sin card)

- **Finanzas abiertas:** conectar los bancos cuando Perú tenga un marco regulado para eso. No está verificado en qué punto
  está esa regulación.
- **Impuestos:** Quipuk (Perú) junta finanzas personales y la declaración anual. Encaja con el perfil de negocio de 2.4.

---

## Los seis ejes, cruzados con las versiones

### Eje 1 · Mejoras de UI y de UX

| Versión | Qué |
|---|---|
| 2.2 | La auditoría UX completa. Grupos y Flujo de caja con el diseño nuevo. Contraste AA en temas oscuros y de color. Textos en 16 idiomas (pt-BR, pt-PT, francés, es-419). Transición más cuidada en la entrada. Onda de voz en vivo. |
| 2.3 | Tutoriales rehechos desde cero. iPad con barra lateral y lista y detalle; iPhone Duo. Decisión sobre la mascota. |
| 2.4 | Cuentas con presencia propia en la app. Pase de estrés de accesibilidad: texto grande y VoiceOver con importes. |
| 2.5 | Rachas y, si se aprueba, mascota (idea nueva: la mascota en los estados vacíos, el onboarding y Yala IA). |
| 3.0 | El sistema de diseño se lleva a la web. |

### Eje 2 · Mejoras de funciones que ya existen

| Función | Hoy (medido en el código) | Propuesta | Versión |
|---|---|---|---|
| **Tarjeta de crédito** | Guarda el día de pago y avisa ese día. | Fecha de corte, fecha de pago y aviso unos días antes. Después, el ciclo de la tarjeta como período y qué compras entran en el estado de cuenta (idea nueva), y las cuotas. | 2.2 (corte y pago) · 2.4 (ciclo y cuotas) |
| **Selector de período** | Semana, 7 días, 30 días, mes, mes pasado, año, año pasado, todo y a medida. | **Mes financiero**, de cobro a cobro, en todos los selectores. Gratis. | 2.4 |
| **Ahorros** | El tipo de cuenta «Cuenta de ahorros» existe. Hay una gráfica de ahorro en Flujo de caja. No hay metas ni una vista propia. | **Sección Ahorros** con las cuentas de ahorro y un tipo nuevo, **depósito a plazo**, con tasa, plazo y vencimiento (idea nueva). Metas con aporte. | 2.4 |
| **Gastos hormiga** | No existen; la ficha de la App Store los promete. | Ver la propuesta de abajo. | 2.3 |
| **Pagos planificados** | Manuales, con recordatorios. | Detectarlos en el historial, con logos. | 2.3 |
| **Importar** | PDF de estados de cuenta (también con contraseña), CSV y Excel; capturas de Yape y Plin y fotos de recibos. | Proponerlo en la bienvenida; que el CSV exportado se pueda volver a importar. | 2.3 |
| **Presupuestos** | Límite fijo. | Que se adapten a los ingresos y se recomienden con IA. | 2.4 |
| **Yala IA** | Chat que sobre todo crea registros. | Consultar, explicar y resumir; Grupos; respuestas por voz. | 2.5 |

**Gastos hormiga, las dos dudas de Jürgen:**

- **¿Usa IA?** Para detectarlos, **no hace falta**. Basta una regla: monto por debajo de un umbral (Clever usa S/5),
  frecuencia en el mes y el mismo comercio o subcategoría. Es exacta, gratis por uso y se explica sola. La IA sirve para lo
  que va después: el consejo («si bajas el café a tres por semana, ahorras S/ X al mes»).
- **¿Es solo Pro?** Se propone **ver el total y la lista gratis**, porque Pablo y Clever lo dan a todos y la ficha ya lo
  promete. El consejo con IA y las alertas serían Pro.

Las dos quedan como propuesta para que Jürgen decida.

### Eje 3 · Secciones nuevas

| Sección | Qué es | Versión |
|---|---|---|
| Suscripciones | Las detectadas en el historial, con logo y próximo cobro. | 2.3 |
| Comercios | Dónde gastas más y por qué cuenta o tarjeta pagas. | 2.3 |
| Ahorros | Cuentas de ahorro, depósitos a plazo y metas. | 2.4 |
| Deudas | Préstamos propios y compras en cuotas. | 2.4 |
| Perfiles | Negocio y personal, con colecciones de cuentas. | 2.4 |
| Notificaciones en la Bandeja | Los avisos dentro de la app. | 2.4 |
| WhatsApp | Yala fuera de la app. | 2.5 |
| Compartido | Lo que lleva la pareja o la familia. | 3.1 |

### Eje 4 · Competencia

**Qué tienen, verificado hoy en sus páginas** (usapablo.com y goclever.app, 19-oct-2026), más lo que traen las cards:

| Función | Pablo | Clever | Yala hoy | Versión para igualar | Cómo superarlo |
|---|---|---|---|---|---|
| Apuntar por WhatsApp (texto, voz y foto) | Sí (voz y foto, Premium) | Según las cards, sí | No | 2.5 | Que el gasto aparezca en el Panel al instante y se pueda dividir con el grupo desde el mismo mensaje. |
| Leer el correo del banco | Sí (Premium) | Sí (Gmail, solo avisos del banco) | No | **2.3** | Que llegue a la Bandeja con la cuenta correcta y en la divisa correcta, también en dólares. |
| Leer la notificación del banco | — | Sí | No | 2.3 (Atajos) · 4.0 (Android, automático) | — |
| Gastos hormiga | Sí | Sí (menos de S/5) | No (la ficha lo promete) | **2.3** | Regla exacta y gratis, con el consejo de la IA para Pro. |
| Metas de ahorro | Sí (1 en el plan gratis) | — | No | 2.4 | Depósitos a plazo y proyección con el flujo de caja. |
| Rachas | Sí | — | No | 2.5 | Con mascota y sin culpa: la voz de marca ya lo pide. |
| Tarjetas con fecha de corte | Según las cards, sí | Resumen de tarjetas | Solo el día de pago | 2.2 | Tarjeta con varias divisas, que nadie más tiene. |
| Cuentas compartidas | Según las cards, sí | — | No (solo Grupos) | 3.1 | Grupos ya cubre los gastos compartidos sueltos; el plan dúo cubre las cuentas. |
| Perfil de negocio | — | Sí | No | 2.4 | — |
| Reglas por chat, manos libres | — | Según las cards, sí | No | 2.3 | — |
| Proyección de fin de mes | — | Sí | Flujo de caja proyectado | Ya existe | Mejor: el plan por línea, a varios meses. |
| Web | Sí | Sí (panel web) | No | 3.0 | — |
| Android | Sí | No consta | No | 4.0 (antes, la web instalable) | — |
| Aviso antes de cobrar la prueba | — | Sí (3 días antes) | No consta | 2.3 | — |
| Precio | Premium desde S/20 al mes; gratis con 5 mensajes al día, 3 cuentas, 1 moneda y 1 meta | US$5.90 al mes o US$35.90 al año, con 14 días de prueba | — | — | — |

**Dónde Yala ya es mejor:** Grupos integrado con las finanzas personales (ninguno de los dos lo tiene); 54 divisas y una
tarjeta con varias; el flujo de caja proyectado; Siri, Apple Pay y widgets; 16 idiomas; la lectura de capturas de Yape y
Plin, de fotos de recibos y de PDF de estados de cuenta, que ya existe.

**Qué igualar primero, en orden:** (1) el correo del banco y los gastos hormiga, en 2.3, porque es lo que la persona ve el
primer día y la ficha ya lo promete; (2) las metas, en 2.4; (3) WhatsApp y las rachas, en 2.5; (4) la web, en 3.0.

**Otras apps de la región** (conocimiento general, no verificado hoy): Fintonic (conecta bancos en España y Chile), Mobills
(Brasil), y Splitwise y Tricount para gastos de grupo, de donde Yala propone importar en 2.4.

### Eje 5 · Formatos y plataformas nuevos

| Formato | Versión | Dependencias técnicas |
|---|---|---|
| Widgets | 2.2 (extragrande) · 2.3 (widget interactivo para apuntar con un toque; idea nueva) · 2.4 (metas y mes financiero) | Las App Intents ya existen. El widget lee de su copia en el App Group. |
| iPad y iPhone Duo | 2.3 | El ADR del 2026-09-27 y el runtime de iOS 27.1 en la Mac. |
| Mac | 2.4 (idea nueva) | La app de iPad en Mac con Apple Silicon, cuando el iPad ya sea adaptativo. Una app de Mac nativa no compensa: la web de 3.0 cubre la computadora. |
| Web | **3.0** | Nube endurecida, cuenta en la web (Apple y Google), defensa en lugar de App Attest, suscripción por cuenta. |
| Plan dúo | **3.1** | Nube, propiedad compartida en el backend, invitaciones de Grupos. |
| Apple Watch | 3.2 | Complicaciones con WidgetKit y App Intents. No necesita la nube. |
| Android | **4.0** | Todo lo de la web, Play Integrity, FCM, Google Play Billing y la decisión del lenguaje. |

### Eje 6 · Qué entra en Pro en cada versión

| Versión | Pro gana | Sigue gratis |
|---|---|---|
| Hoy (2.1) | Voz y foto (5 y 5 de prueba en gratis), chat de Yala IA, análisis con IA, temas e iconos, flujo de caja avanzado, más de 4 cuentas, más de 3 presupuestos, registrar con Siri. | Lo demás. |
| 2.2 | Nada nuevo. Se arregla cómo se explica Pro: paywall con ejemplos, vista previa de temas, «1 mes gratis» en lugar de «30 días». **Decisión:** las preguntas a Siri con IA, ¿gratis o Pro? | Tarjeta multidivisa y fecha de corte. |
| 2.3 | Correo y notificación del banco, con un cupo de prueba. Manos libres. Reglas en lenguaje natural. El consejo con IA sobre gastos hormiga. | El total y la lista de gastos hormiga. Suscripciones detectadas. Importar. |
| 2.4 | Metas ilimitadas (1 gratis, como Pablo). Presupuestos con IA. Perfiles de negocio y personal. Notificaciones con IA. | Mes financiero, cuotas, deudas, la sección de Ahorros. |
| 2.5 | WhatsApp (con un cupo gratis al día, como Pablo). Yala IA ampliada y respuestas por voz. Conector de Claude. | Rachas y mascota. Accesorios de la mascota como cosmética Pro (idea nueva). |
| 3.0 | Una sola suscripción por cuenta en iOS y la web, con precio en soles. | — |
| 3.1 | **Pro Dúo** (idea nueva): un plan para dos cuentas, con precio por decidir. | — |
| 4.0 | La misma suscripción, pagable también en Google Play. | — |

Los precios de Yala no se fijan aquí. Como referencia: Pablo cobra desde S/20 al mes y Clever US$5.90 al mes.

### Los ejes por versión, de un vistazo

| Eje | 2.2 | 2.3 | 2.4 | 2.5 | 3.0 | 3.1 | 4.0 |
|---|---|---|---|---|---|---|---|
| UI y UX | Auditoría y coherencia | Tutoriales, iPad, Duo | Cuentas, accesibilidad | Rachas, mascota | Diseño en la web | — | Diseño en Android |
| Funciones existentes | Tarjeta de crédito | Pagos planificados, importar | Período, ahorros, presupuestos | IA | — | — | — |
| Secciones nuevas | — | Suscripciones, comercios | Ahorros, deudas, perfiles | WhatsApp | — | Compartido | — |
| Competencia | Fecha de corte | Correo, gastos hormiga | Metas | WhatsApp, rachas | Web | Cuentas compartidas | Android |
| Plataformas | Widget extragrande | iPad, Duo, widget interactivo | Mac (app de iPad) | — | Web | — | Android |
| Pro | Explicarlo mejor | Captura automática | Metas, IA en presupuestos | WhatsApp, IA ampliada | Suscripción por cuenta | Pro Dúo | Google Play |

---

## Cards que conviene revisar (sin moverlas)

### Duplicadas o solapadas

| Cards | Qué pasa |
|---|---|
| «El aviso de saldo de una cuenta no lleva a ningún sitio al tocarlo» · «UX 2.2 · L10-14 · El aviso de pago de la tarjeta de crédito no lleva a ningún sitio» | Misma causa: el aviso apunta a un destino que la app no reconoce. Fundir. |
| «Las frases de Siri que la app enseña en portugués no activan Siri» · «UX 2.2 · L15-5 · En 10 de los 16 idiomas, ninguna frase de Siri funciona» | La primera es una parte de la segunda. |
| «Rediseñar por completo los tutoriales y actualizarlos» · «UX 2.2 · L16-16 · Los tutoriales felicitan por algo que no se hizo…» | El rediseño absorbe el arreglo. Decidir si L16-16 se hace igual en 2.2. |
| «Rediseñar las notificaciones desde cero» · «2.2 · Notificaciones dentro de la Bandeja» · «Notificaciones inteligentes con IA» | Tres piezas del mismo proyecto. |
| «Revisar a fondo cómo usa Yala la IA…» · «Yala AI haga más que crear registros» | La revisión cubre la investigación de la segunda. |
| «Yala en ChatGPT, Claude y Grok: diseñar el servidor MCP de solo lectura» · «Plugin de Yala para Claude…» | El diseño ya está hecho; queda la salida. |
| «Al activar la nube con muchos movimientos, la barra se queda quieta en ~60 %…» · ««Activar la nube» se queda en ~60 % sin subir nada…» · ««Activar la nube» con 6 movimientos espera más de 5 min…» | El mismo síntoma con causas distintas. Revisarlas juntas. |
| ««Volver a iCloud › Empezar sin ellos» falla con un iCloud grande…» · «Tras confirmar «Borrar y volver a iCloud», la pantalla no dice que está trabajando» · ««¿Borrarlos de tu iCloud?» no enseña ninguna salida…» | El mismo flujo. |
| «Tras vaciar datos en un dispositivo, un gasto de grupo puede salir dos veces en el otro con dos borradores» · «Tras vaciar los datos en un dispositivo, algunos gastos de grupo pueden salir dos veces en otro, con dos borradores en la Bandeja» | Títulos casi iguales y causas distintas: renombrar una de las dos para que no parezcan la misma. |
| «UX 2.2 · «Vengo por un grupo» no ofrece salida…» · «Al volver a entrar por «Vengo por un grupo» con la misma cuenta…» · «Al volver a tu cuenta de Grupos por «Ya tengo una cuenta»…» | La misma puerta de entrada. |
| «UX 2.2 · Entrar con Google en un iPhone que usó Apple…» · «Las notas de entrar del Welcome dicen que la cuenta queda ligada a un método…» | El mismo malentendido. |
| «Perfil Empresa y Personal…» · «Colecciones de cuentas…» | Decidir si las colecciones son la versión sencilla de los perfiles. |
| «Las cuentas se ven poco…» · «Ajustes › Cuentas…» · «Formulario de cuenta…» | Tres entregas del mismo rediseño. |

### Probablemente obsoletas

| Card | Por qué |
|---|---|
| «Con iCloud Drive apagado antes de abrir Yala, la app arranca vacía y no avisa de nada» | El arreglo se mergeó hoy a 2.1 (PR #562) y su ticket está en `tickets/qa/`. Falta pasarla a QA. |
| «Rediseño de sesiones: seguir el orden de implementación ticket a ticket» | Medido: de sus 13 tickets, 9 están en `done` y 4 en `qa`. No queda nada que seguir. |
| «Yala en ChatGPT, Claude y Grok: diseñar el servidor MCP de solo lectura» | El conector ya existe en staging (ADR del 2026-09-26). |
| «Adoptar el formato JSON del proyecto de Xcode cuando 27.2 sea estable» | Dice «en esta Mac está Xcode 27.0», y otra card dice que ya está 27.1. Re-medir. |
| «DMARC sigue en p=none: la re-comprobación del 15-sep venció» | La fecha venció hace más de un mes. |
| «En los teléfonos de QA que tuvieron una sesión de visita…» | Solo afecta a teléfonos de QA; nadie en producción abrió una sesión de visita. |

### Datos de la card que no cuadran

| Card | Qué no cuadra |
|---|---|
| «Llevar a 2.1 el guard que impide bajar el manifest del Worker» | Está en 2.2 y pide ir en 2.1. Se propone 2.1.1. |
| «Yala en la web…» | Está en 2.3 y su texto dice «candidata a 3.0». |
| «2.2 · Notificaciones dentro de la Bandeja» | El título dice 2.2 y la card no tiene versión. |
| «Desplegar CD_parentAccountID a Production en CloudKit» | Asignada a Lola; es un despliegue en la consola de CloudKit. |
| «Ficha de la App Store: quitar «detección de gastos hormiga»…» y «README de marca todavía trae brillos y degradados…» | Asignadas a Frank, pero tocan `marketing/`, que es de Lola. |

### Necesitan una decisión de Jürgen

- Las cuatro en «espera decisión» de 2.2: el tema que vuelve solo al perder Pro, «Datos no disponibles», la bienvenida a Pro
  con los nombres viejos y «30 días» frente a «1 mes».
- «Probar momentic.ai (E2E con IA) en Yala, plan gratis»: ¿se lanza o se descarta?
- Las que llevan pregunta abierta: L12-10 (invitar al crear un grupo), L10-13 y L10-14 (a dónde lleva cada aviso), L1-9
  (onboarding de 8 a 6 pasos), «El saldo cuenta los movimientos con fecha futura…», «Al tocar un segmento de una
  gráfica…», «Las cuentas se ven poco…», «Archivar una cuenta: decidir…» y ««Mira lo nuevo en Yala» no sale en el primer
  arranque»: ¿2.1 o 2.2?
- «Decidir qué hacer con lo que llega a iCloud después de la comprobación del adopt».
- «Siri con IA: ¿tus cuentas y movimientos en Spotlight? ¿Las preguntas a Siri, gratis o Pro?».
- «Encender Yala IA ampliada en la nube (staging → producción)».
- «Analizar una mascota en la app».
- **Las que abre este roadmap:** sacar el correo del banco de 2.2; si el correo exige cuenta en la nube; gastos hormiga
  gratis con el consejo de IA como Pro; si la nube pasa a ser la opción recomendada en 3.0; y el lenguaje de Android.

---

## Apéndice — Todas las cards por versión propuesta

Agrupadas por tema. El motivo de cada una está en `docs/roadmap-asignacion.tsv`.

<details>
<summary><b>2.1</b> — 5 cards</summary>


**Personalidad y marca** (2)

- Aplicar plan Superapp al lanzar 2.1 (nombre/subtítulo ASO, corregir privacidad en listing, prueba Apple Ads US$5/día)
- Ficha de la App Store: quitar «detección de gastos hormiga» de los textos guardados, porque la app no la tiene

**Lanzamiento y parche de 2.1** (1)

- Checklist de envío de 2.1 a App Store, verificada contra el código

**Robustez de la nube y las sesiones** (1)

- Rediseño de sesiones: seguir el orden de implementación ticket a ticket

**Yala IA** (1)

- IA sesión 2: la app manda su tarea, las 12 llamadas por el banco, voz en 10 idiomas y cupo free 5+5

</details>

<details>
<summary><b>2.1.1</b> — 14 cards</summary>


**Lanzamiento y parche de 2.1** (10)

- Al actualizar desde la 2.0.4, «Mira lo nuevo en Yala» no sale en el primer arranque, sino en el segundo
- Al cancelar la voz, la música de otra app no vuelve a sonar
- Al volver a tu cuenta de Grupos por «Ya tengo una cuenta», tus grupos no aparecen hasta cerrar y abrir Yala
- La primera foto tras instalar falla al momento con «No pude leerla esta vez» y la segunda funciona
- Llevar a 2.1 el guard que impide bajar el manifest del Worker
- Unirse por enlace en una instalación nueva bloquea por los datos privados del propio iCloud
- «Activar la nube» con 6 movimientos espera más de 5 min a que iCloud «termine de sincronizar» y solo sigue al volver a la app
- «Activar la nube» se queda en ~60 % sin subir nada hasta cerrar y abrir Yala (App Attest en producción)
- «Dónde viven tus datos» dice que tus grupos usan una cuenta vieja y bloquea «Activar la nube»
- «Volver a iCloud › Empezar sin ellos» falla con un iCloud grande: el borrado se corta a los 2 minutos

**Robustez de la nube y las sesiones** (3)

- Al activar la nube con muchos movimientos, la barra se queda quieta en ~60 % y parece colgada
- Con iCloud Drive apagado antes de abrir Yala, la app arranca vacía y no avisa de nada
- En el segundo dispositivo de una cuenta que ya volvió a iCloud, salir de la espera impide volver a intentar «Volver a iCloud»

**Tarea de Jürgen** (1)

- Device-QA de Yala: 27 tickets en tickets/qa esperan un iPhone

</details>

<details>
<summary><b>2.2</b> — 245 cards</summary>


**Auditoría UX 2.2** (157)

- Al tocar un segmento de una gráfica con exclusiones activas, que la app pregunte si excluirlo o ver solo ese segmento
- Al volver a entrar por «Vengo por un grupo» con la misma cuenta, Yala pide otra vez el consentimiento de Grupos y tu nombre
- Auditoría UX 2.2 · lote 5: primeros días, guías y tips
- Auditoría de UX por flujos para 2.2: mapa de todos los flujos y revisión con cinco tipos de usuario
- Auditoría del modo «Solo gastos»: qué enseña y qué esconde cada pantalla
- Diez avisos de App Attest siguen diciendo «la verificación de seguridad que pide nuestro servidor»
- Entrada a Yala: las pantallas se cierran y se abren enteras; buscar una transición más bonita
- Flujo de caja tiene que sentirse la misma app: alinear sus pantallas con el diseño del resto
- Grupos tiene que sentirse la misma app: alinear sus pantallas con el diseño nuevo de Registros y Estadísticas
- Las notas de entrar del Welcome dicen que la cuenta queda ligada a un método (y no es así)
- Quien entra por «Ya tengo una cuenta» vuelve a ver todos los tips de principiante
- Registro por voz: onda de voz y texto en vivo mientras hablas
- Revisar el diseño de la hoja de la cuenta eliminada (mover o borrar movimientos)
- Revisar las Novedades de 2.2 antes de publicarla
- Revisar si «Seguridad y cuenta» en Ajustes se divide en dos subsecciones
- Tras confirmar «Borrar y volver a iCloud», la pantalla no dice que está trabajando
- UI 2.2 · L12-10 · Al guardar un grupo no se propone invitar a nadie
- UI 2.2 · L15-10 · En la guía, «Listo» compite con «Hecho» y deja terminar sin hacer los pasos
- UI 2.2 · L15-4 · «Siri y Atajos» enseña frases pero no deja hacer nada, y nombra las acciones distinto que Atajos
- UI 2.2 · L17-6 · Al terminar la prueba salen dos hojas seguidas y la primera alarma
- UI 2.2 · L18-11 · La tira de meses y el resumen no dicen qué es cada número
- UI 2.2 · L18-3 · La tabla no dice qué es cada número, y «P-1» y «A-1» son jerga
- UI 2.2 · L18-5 · Crear el plan pide revisar 29 líneas y empieza con S/ 0 teniendo S/ 83,666
- UI 2.2 · L19-1 · Una solicitud para unirse es un punto rojo, y se acepta con dos iconos sin texto
- UI 2.2 · L19-5 · Archivar, desarchivar y eliminar salen en rojo, igual de graves
- UI 2.2 · L19-6 · El presupuesto del grupo se teclea en una alerta, sin decir qué pasa al llegar al tope
- UI 2.2 · L2-16 · El monto no dice qué es ni en qué moneda hasta que eliges cuenta
- UI 2.2 · L2-17 · «Calcular mi parte» da un número suelto: no se ve cómo se reparte ni de dónde sale
- UI 2.2 · L2-18 · El tipo de cambio se puede cambiar, pero no lo parece
- UI 2.2 · L2-19 · Lo que eliges solo cambia de contorno: sobre el glass no destaca
- UI 2.2 · L2-20 · Todo pesa igual: «Calcular», «Favorito» y «Recurrente» son círculos grises y «Guardar» no destaca al estar listo
- UI 2.2 · L2-21 · Elegir no se siente: el chip cambia de golpe y nada celebra que ya puedes guardar
- UI 2.2 · L2-22 · Las hojas a media altura dejan ver el formulario borroso detrás: el rosa del monto se mezcla con el contenido
- UI 2.2 · L20-11 · Activar la nube: cuatro pasos antes de entrar, «Migrar» y «Activar», y la vista previa parece código
- UX 2.2 · Entrar con Google en un iPhone que usó Apple: «Esa cuenta usa otro método» confunde y el consentimiento se pide dos veces
- UX 2.2 · L1-9 · onboarding «control»: de 8 pasos a 6 fusionando cómo organizas y el tipo de cuenta
- UX 2.2 · L10-13 · Tocar un recordatorio abre la lista, no el pago, y el monto del aviso no sigue la preferencia de divisa
- UX 2.2 · L10-14 · El aviso de pago de la tarjeta de crédito no lleva a ningún sitio
- UX 2.2 · L11-12 · El editor del informe no dice qué días entran, «Probar» sin permiso no hace nada y el mensual del día 1 dice «este mes»
- UX 2.2 · L11-7 · Quien paga Pro y no ha generado la IA ve menos que quien no paga: «Observaciones» queda vacía
- UX 2.2 · L12-1 · En el grupo, «Estadísticas» se corta y «Balances» es una palabra prestada
- UX 2.2 · L12-11 · Si para crear hubo que iniciar sesión y aceptar, al terminar no vuelve al formulario
- UX 2.2 · L12-12 · «Crear mi primer grupo» desde la bienvenida son 9 pantallas (10 sin cuenta) y «Crear mi grupo» abre otro formulario
- UX 2.2 · L12-14 · El enlace se manda solo, sin un texto que diga qué es ni qué hacer
- UX 2.2 · L12-15 · La web de invitación no dice qué hacer tras instalar ni quién invita, y «Abrir en Yala» falla sin la app
- UX 2.2 · L12-16 · «Pega tu enlace» no tiene botón de pegar y rechaza el mensaje de WhatsApp entero
- UX 2.2 · L12-17 · Se pide cuenta y consentimiento antes de enseñar a qué grupo te unes
- UX 2.2 · L12-18 · «¡Todo listo!» no dice a qué grupo entraste ni qué hacer ahora
- UX 2.2 · L12-19 · Mientras se conecta, la pestaña dice «Sin grupos · Crea un grupo» debajo de «Conectando con tu grupo…»
- UX 2.2 · L12-20 · Al que espera aprobación se le pide volver a mirar y no se le avisa; y hay dos textos para lo mismo
- UX 2.2 · L12-21 · Jerga y frases raras en los avisos: «Pídele al admin que regenere uno», «se sincronizan con un iCloud»
- UX 2.2 · L12-3 · «Un último paso · Continuar» no dice qué paso es
- UX 2.2 · L12-4 · El paso 3 del educativo y el consentimiento cuentan lo mismo: dos pantallas para una sola decisión
- UX 2.2 · L12-5 · El consentimiento habla de «alias», repite el título y lleva cuatro iconos de información iguales en azul de sistema
- UX 2.2 · L12-6 · «Puedes cambiar este comportamiento en Ajustes de Grupos» no dice qué comportamiento
- UX 2.2 · L12-7 · «Iniciar sesión con Apple» y «Crear cuenta con Google»: dos verbos para lo mismo, y el título dos veces
- UX 2.2 · L12-8 · El permiso de avisos de grupo se pide en una alerta suelta, en cuanto aparece el primer grupo
- UX 2.2 · L12-9 · El formulario habla como un contador: «Simplificar deudas», «Moneda única para deudas», «División predeterminada»
- UX 2.2 · L13-10 · Los saldos iniciales están al fondo de Miembros y el formulario no explica qué son
- UX 2.2 · L13-11 · Al convertir un borrador en gasto de grupo, desaparece sin decir adónde fue
- UX 2.2 · L13-12 · Las hojas para completar un borrador de grupo no hablan igual
- UX 2.2 · L13-13 · «¿Quién ha hecho más pagos?» mide dinero, no pagos
- UX 2.2 · L13-14 · Activar y desactivar el puente no hablan igual, y borrar de tus cuentas no pide confirmación
- UX 2.2 · L13-15 · No hay forma de enlazar un gasto de grupo con un movimiento que ya apuntaste a mano
- UX 2.2 · L13-4 · Borrar un gasto solo dice «Eliminar»: no avisa de que desaparece para todos ni de que se borra tu movimiento
- UX 2.2 · L13-5 · Cinco palabras para lo mismo: «Liquidar», «Registrar pago», «Liquidaciones», «saldar», «Salda pagos»
- UX 2.2 · L13-6 · Saldos y el resumen para compartir dan cifras distintas para la misma deuda
- UX 2.2 · L13-7 · «Sí, registrar» no registra: deja un borrador en la Bandeja y no lo dice
- UX 2.2 · L13-8 · Desde el Panel sin grupos, «Grupo» lleva a «¿Cómo funcionan los grupos?» y el formulario aparece después, sin explicarlo
- UX 2.2 · L13-9 · «Guardar» se apaga sin decir qué falta
- UX 2.2 · L14-1 · La misma función tiene siete nombres según la pantalla
- UX 2.2 · L14-10 · «Personalizar IA» son dos menús sin explicación, y en Ajustes no está el tono
- UX 2.2 · L14-11 · Privacidad IA usa nombres internos, y deja aceptar el permiso de una función que no puedes usar
- UX 2.2 · L14-12 · Un usuario Pro no puede ocultar el botón de Yala IA
- UX 2.2 · L14-13 · El paywall de Yala IA no dice qué hace
- UX 2.2 · L14-6 · «Temas» repite las mismas tres sugerencias del saludo
- UX 2.2 · L14-7 · «Reiniciar contexto de conversación» es jerga y borra la conversación entera sin preguntar
- UX 2.2 · L14-8 · No se sabe que hay un límite de preguntas hasta las últimas diez, ni cuándo se renueva
- UX 2.2 · L14-9 · La tarjeta de registro no dice si es gasto o ingreso, y con varios hay que guardar uno por uno
- UX 2.2 · L15-1 · Los widgets se llaman distinto que lo que abren
- UX 2.2 · L15-11 · Una ventana de Yala se queda con un indicador de carga sin decir por qué
- UX 2.2 · L15-12 · Soltar un recibo en el iPad con algo abierto no hace nada
- UX 2.2 · L15-13 · Atajos de teclado: «Configuración» en vez de «Ajustes», ⌘K abre Yala IA y no hay deshacer
- UX 2.2 · L15-14 · Con el iPhone girado o en el iPad, los botones flotantes tapan el contenido
- UX 2.2 · L15-15 · No hay accesos rápidos al mantener pulsado el icono
- UX 2.2 · L15-2 · Sin datos, los widgets enseñan ceros o «todo pagado» sin decir por qué
- UX 2.2 · L15-3 · Widgets que enseñan lo mismo llevan a sitios distintos
- UX 2.2 · L15-5 · En 10 de los 16 idiomas, ninguna frase de Siri funciona
- UX 2.2 · L15-6 · Sin Pro, Siri dice «Activa Yala Pro» y no lleva a ningún sitio
- UX 2.2 · L15-7 · Un dictado de Siri no avisa dentro de la app
- UX 2.2 · L15-8 · La notificación de Apple Pay dice «Se ha registrado» algo que aún no está registrado
- UX 2.2 · L15-9 · La guía de Apple Pay describe el Atajos de iOS 26
- UX 2.2 · L16-1 · Ajustes no se llama «Ajustes» en ningún sitio
- UX 2.2 · L16-10 · Elegir un tema (o un idioma) te saca de Ajustes
- UX 2.2 · L16-11 · Un tema o un icono Pro no se puede ver antes de pagar
- UX 2.2 · L16-13 · La barra de pestañas habla de «Tabs» y no explica sus límites
- UX 2.2 · L16-14 · Permisos te saca de Yala sin avisar
- UX 2.2 · L16-15 · «Calificar y recomendar» solo califica, y a veces no hace nada
- UX 2.2 · L16-16 · Los tutoriales felicitan por algo que no se hizo y enseñan una versión vieja
- UX 2.2 · L16-17 · Las preguntas frecuentes no cubren lo nuevo y no tienen salida
- UX 2.2 · L16-18 · El formulario de soporte no dice qué pasa al enviar
- UX 2.2 · L16-19 · Privacidad y términos te sacan de Yala
- UX 2.2 · L16-2 · Editar el nombre obliga a borrar «Usuario» y la hoja no dice cómo se guarda
- UX 2.2 · L16-20 · En el iPad, la lista de Ajustes no marca qué ajuste está abierto
- UX 2.2 · L16-21 · El tamaño de un widget del Panel se esconde detrás del «?»
- UX 2.2 · L16-4 · Los tipos de cambio de divisas débiles no se pueden leer
- UX 2.2 · L16-5 · El idioma de la app solo se cambia si lo elegiste en el onboarding, y cambiarlo te saca de Ajustes
- UX 2.2 · L16-6 · Activar «Solo gastos» parece borrar algo
- UX 2.2 · L16-7 · Personalización habla en jerga y no dice dónde se ve cada ajuste
- UX 2.2 · L16-8 · «Personalizar resumen de IA» controla Estadísticas › Resumen, y casi nada es IA
- UX 2.2 · L17-7 · El banner de prueba invita a «Suscribirse» a quien ya está suscrito
- UX 2.2 · L17-8 · La pantalla de Pro activo está casi vacía
- UX 2.2 · L17-9 · Tras comprar, Yala no te devuelve a lo que querías hacer
- UX 2.2 · L18-1 · Reportes queda al fondo de «Más» y sus dos tarjetas no dicen para qué sirven
- UX 2.2 · L18-10 · Cambiar el saldo inicial: un lápiz que parece «prohibido» y una hoja sin divisa
- UX 2.2 · L18-12 · Las gráficas no dicen de qué período son y sus cifras no casan con el detalle del mes
- UX 2.2 · L18-13 · «Agregar línea» ofrece tres caminos sin decir cuál conviene
- UX 2.2 · L18-2 · La Comparativa abre en «Todo el tiempo», donde no hay nada que comparar
- UX 2.2 · L18-4 · El desglose habla en jerga: «Profundizar», «Tipo», «Naturaleza», «Flujo neto»
- UX 2.2 · L18-6 · Tres explicaciones apiladas al entrar, y la primera dice «hasta fin de mes»
- UX 2.2 · L18-7 · Una vez creado el plan, una línea no se puede cambiar ni borrar a la vista
- UX 2.2 · L18-8 · «Este mes y futuros» cambia también los meses pasados y el actual
- UX 2.2 · L18-9 · Ajustar un monto: el campo no dice qué es y el teclado tapa «Guardar»
- UX 2.2 · L19-10 · «Eliminar» bloqueado no dice qué saldo lo bloquea, y a veces son dos céntimos
- UX 2.2 · L19-11 · Salir o eliminar no dicen qué pasa con tu dinero
- UX 2.2 · L19-13 · Los grupos que no se pudieron dejar dicen «Eres administrador y hay otros miembros»
- UX 2.2 · L19-14 · Desasociar la cuenta de grupos se explica con jerga y dos salidas difíciles
- UX 2.2 · L19-2 · «¿Carla entra con saldo inicial?» es jerga, y casi nadie lo necesita
- UX 2.2 · L19-3 · No se puede hacer administrador a nadie en un grupo de la nube
- UX 2.2 · L19-4 · Quitar a alguien que debe no dice cuánto ni a quién
- UX 2.2 · L19-7 · Las opciones del grupo hablan en jerga, y el nombre no parece editable
- UX 2.2 · L19-8 · Archivar sin deudas no pregunta ni avisa: el grupo desaparece
- UX 2.2 · L19-9 · Un grupo archivado no lo dice, y su deuda deja de sumar
- UX 2.2 · L2-1 · La cuenta nunca viene puesta, ni siquiera cuando solo hay una
- UX 2.2 · L2-10 · Las etiquetas quedan fuera de la pantalla, y crear una pide icono, color, «Estado» y un código hexadecimal
- UX 2.2 · L2-11 · Al apuntar en dólares no ves cuánto es en soles, y «TC» no se explica
- UX 2.2 · L2-12 · «Calcular» no dice qué calcula, empieza en porcentaje y el resultado queda como «% ÷ 3 personas»
- UX 2.2 · L2-13 · Favoritos: la misma estrella para guardar y para usar, y usar uno cuesta cuatro toques
- UX 2.2 · L2-14 · Un favorito guardado desde una transferencia queda «Sin configurar»
- UX 2.2 · L2-15 · «Recurrente» abre un formulario largo y no avisa de que también guarda el de hoy
- UX 2.2 · L2-2 · «Guardar» apagado no dice qué falta, y la guía pide «monto y categoría» cuando también hace falta la cuenta
- UX 2.2 · L2-3 · «Subcategoría» en el chip, «categoría» en la guía, y 50 opciones sin buscador
- UX 2.2 · L2-4 · Deslizar hacia abajo cierra el formulario y se pierde lo escrito
- UX 2.2 · L2-5 · Una pantalla entera de «¡Listo!» tras cada registro
- UX 2.2 · L2-6 · Con una sola cuenta, la transferencia dice «Aún no tienes cuentas»
- UX 2.2 · L2-7 · Elegir «ayer» cuesta tres toques y los días futuros salen grises sin explicación
- UX 2.2 · L2-8 · «Usa @ cuenta, ! categoría, # etiqueta» es jerga y el campo no da un ejemplo
- UX 2.2 · L2-9 · Necesidad: «discrecionales», «naturaleza»… y nada dice para qué sirve
- UX 2.2 · L20-12 · El consentimiento de la nube es un muro de texto con jerga
- UX 2.2 · L20-17 · «Volver a iCloud» pide dos confirmaciones que dicen lo mismo
- UX 2.2 · L20-7 · Cerrar sesión espera 45 segundos con un pie gris, y el aviso ofrece «Cerrar sesión igualmente» primero, sin exportar
- UX 2.2 · L20-8 · Cerrar sesión sin copia y eliminar una cuenta de la nube no ofrecen «Exportar antes»
- UX 2.2 · L20-9 · «Tu cuenta de Yala» no dice qué cuenta es, y contradice a la pantalla de entrar
- UX 2.2 · L6-13 · «Conectando con tu cuenta…» puede tardar minutos sin decir cuánto falta
- UX 2.2 · «Vengo por un grupo» no ofrece salida a quien ya tiene una cuenta de Grupos
- «Ahora mismo no puedes volver a iCloud desde este dispositivo» no dice que en ese aparato no se podrá nunca
- «Quitar mis datos de este iPhone» lleva a avisos que dicen «Cerrar sesión»

**Bugs de la app** (24)

- Al filtrar el Panel por una cuenta excluida de estadísticas, el saldo grande enseña el total y los widgets enseñan 0
- Al terminar de importar un archivo no sale «Importación completada»
- Apple Pay, la voz y la Bandeja pueden poner a un gasto una subcategoría de ingreso aprendida del comercio
- Bug 2.2 · En es-ES, es-AR, en-GB y pt-PT los recuentos de uno salen en plural
- Bug 2.2 · En «Ocultar», con una sola moneda marcada, el monto se filtra en la moneda que se oculta
- Bug 2.2 · «¡Gasto agregado!» puede decir que se apuntó algo que el puente no escribió (casos raros)
- Bug · Al reabrir la calculadora del saldo con 1.000 o más, dice 0
- Bug · El aviso de error de StoreKit no se vacía en el paywall ni en la oferta
- Bug · Un recibo compartido que choca con «Función Pro» se descarta
- Con varias cuentas filtradas, el Panel cuenta mal tus cuentas y el formulario precarga una al azar, incluso una excluida
- Desde un movimiento en dólares de una cuenta en soles, «Guardar como favorito» y «Hacer recurrente» lo crean en soles
- El aviso de una notificación puede perderse con la app cerrada
- El saldo de arriba del Panel y la hoja «¿Cuánto tienes hoy?» dan cifras distintas del mismo dinero
- El «vs mes pasado» de los heros de Tendencias y del Panel cuenta un día de más si el gasto se fechó a medianoche
- Estadísticas › Distribución arranca en Gráficas; debería abrir en Detalle
- Gráfica del Saldo: «apr 26» pisa a «oct 26» y la pastilla «Today» tapa «100K»
- Ingresos y gastos del mismo mes salen distintos según la pantalla cuando un movimiento no tiene categoría o su signo la contradice
- La cifra y la curva del widget de saldo no cuentan lo mismo con movimientos sin cuenta
- Lo importado desde CSV no se distingue de lo escrito a mano y puede caer en una categoría de ingreso siendo un gasto
- MainTab publica su hoja después de que ContentView drene
- Por dentro, el Excel sigue diciendo «Transacciones» y el archivo de grupos lleva la hora en cifras
- Tendencias no se entera de que editaste el importe de un movimiento
- UX 2.2 · En modo duplicados, sin el criterio «Fecha», no se ve de qué día es cada registro
- Un pago planificado de «Una sola vez» aparece como «Mensual» en la lista de Pagos planificados

**Deuda técnica interna** (13)

- Al leer un recibo completo con la cámara, «Guardar» sale apagado en los tests de iOS 27
- Cruzar tickets abiertos con el tablero y deduplicar cards
- El golden 20 del gateway (la cuenta congelada sigue pudiendo leer) cae por timeout y nadie comprueba ese invariante
- El script de reintentos del CI trata el error de arranque del simulador como un test y deja el job en rojo sin repetir nada
- Hay 11 canarios y 8 rastros que nadie emite, el índice de cobertura los cita como red, y el gate Pro de Siri no deja señal
- Los XCUITest no pueden fingir qué contesta el servidor sobre una cuenta, y el bloque de identidad del Welcome queda sin cobertura de UI
- Release-Dev habla con el gateway de producción con el bundle .dev y no obtiene sesión (¿debe ir a staging?)
- Revisión de traducciones con Sonnet antes de cada release (16 idiomas)
- Sentry: avisos de errores y caídas en la app y el backend
- Si los avisos de Grupos dejan de llegar, el servidor no deja rastro y nadie se entera
- Test · DemoIAPizzaUITests no encuentra «Registrado» en la card del gasto (rojo también en 2.2 limpio)
- Test · RecordsLote8UITests cuenta filas visibles y da por no borrado un registro borrado (rojo también en 2.2 limpio)
- Un test de la marca ≈ del resumen de Registros falla en la suite completa y pasa aislado

**Accesibilidad y textos** (12)

- Con el texto muy grande en un iPhone SE, la Bandeja no deja ver ni aprobar los borradores
- El índigo de marca como texto pequeño no llega a AA sobre los temas oscuros
- En es-419, los nombres de categorías usan palabras peruanas
- En iPad, el texto de almacenamiento de Grupos dice «este iPhone»
- En los temas Rosa, Teal y Minimalista el texto blanco de los botones no llega a AA
- En modo oscuro, los importes de ingresos se leen mal: el turquesa no llega al contraste mínimo
- Las fechas cortas salen «13 Oct» también en inglés de EE. UU.
- Las frases de Siri que la app enseña en portugués no activan Siri
- Los textos de categorías en pt-BR siguen con «Eliminar» y sin acentos
- Unas 260 cadenas antiguas en francés salen sin tildes
- VoiceOver lee un gasto en divisa extranjera con el símbolo de la divisa preferida
- pt-PT: su bloque de respaldo quedó con el pt-BR viejo

**Tarea de Jürgen** (7)

- Aplicar en producción el DDL de parentAccountID de Modo Nube
- DMARC sigue en p=none: la re-comprobación del 15-sep venció
- Declarar el entitlement de App Attest después de activarlo en el App ID
- Desplegar CD_parentAccountID a Production en CloudKit
- El token de gestión de Supabase en la Mini (~/Secrets/yala-supabase-mgmt/pat) da Invalid access token: rotarlo y guardarlo en 1Password
- Pedir la beta review para que el grupo externo vea el TestFlight
- Revocar el token de gestión de Supabase «yala-mcp-fase0» (no consta que se hiciera)

**Yala IA** (7)

- Encender Yala IA ampliada en la nube (staging → producción)
- Integrar Yala con el nuevo Siri con IA de iOS 27
- La política solo nombra a OpenAI: actualizarla antes de encender Gemini u otro proveedor
- Revisar a fondo cómo usa Yala la IA (privada y en la nube) para dar mejores respuestas
- Siri con IA: ¿tus cuentas y movimientos en Spotlight? ¿Las preguntas a Siri, gratis o Pro?
- Yala IA calcula los saldos solo con los últimos 13 meses de movimientos
- Yala IA no cuenta hasta el mediodía un gasto de hoy leído de una foto o de una nota de voz

**Grupos** (6)

- Aceptar el consentimiento de Grupos desde la pestaña queda registrado como si vinieras de una invitación
- Crear un grupo, aprobar o expulsar a alguien sin conexión enseña «Error de Yala.GroupsRPCError 1»
- El canal de Grupos no declara su versión de columnas: cada columna nueva apaga la verificación Merkle a los teléfonos sin actualizar
- Importar archivo deja elegir la cuenta interna de Grupos («Grupos PEN»)
- Si la creación de un grupo falla tras guardarse en el servidor, quien lo creó no aparece como dueño
- Tocar una notificación de grupo no abre el grupo, y cualquier push dispara una sincronización completa

**Robustez de la nube y las sesiones** (5)

- Al volver a iCloud, el arranque dispara una falsa alarma de «modo nube con espejo de iCloud»
- Con iCloud Drive apagado y el espejo adjunto, los borrados del Welcome no empiezan nunca
- Con iCloud Drive apagado, la pantalla de iCloud dice que iCloud no está activo aunque sincroniza
- UX 2.2 · L20-15 · «Datos no disponibles»: el botón que borra va primero en un aviso que nadie pidió
- «¿Borrarlos de tu iCloud?» no enseña ninguna salida: solo «Borrar y volver a iCloud»

**Tarjetas y cuentas** (4)

- Ajustar tarjeta de crédito: fecha de corte, fecha de pago y aviso antes de pagar
- Tarjeta con varias divisas, entrega 2: la tarjeta con sus líneas en el Panel, la ficha, Ajustes y el formulario
- Tarjeta con varias divisas, entrega 3: se elige la tarjeta y la divisa del importe decide la línea
- Tarjeta con varias divisas, entrega 4: informes, flujo de caja y exportación por tarjeta

**Divisas y cifras exactas** (3)

- El saldo cuenta los movimientos con fecha futura y la curva no los dibuja
- Los totales de «Este mes» cuentan un movimiento fechado mañana a las 00:00
- Panel y Planificación pueden decir distinto lo que queda de un presupuesto

**Pro y monetización** (3)

- UX 2.2 · El tema de Pro vuelve al de siempre en silencio al perder Pro
- UX 2.2 · La bienvenida a Pro sigue con los nombres viejos de las funciones
- UX 2.2 · La prueba se anuncia como «30 días» y es de un mes

**Personalidad y marca** (2)

- Con la semilla ficha-mx-vida el saldo cae de golpe el último día
- README de marca todavía trae brillos y degradados (choca con la regla nueva)

**Notificaciones** (1)

- El aviso de saldo de una cuenta no lleva a ningún sitio al tocarlo

**Plataformas nuevas** (1)

- Widgets extragrandes en el iPhone con iOS 27

</details>

<details>
<summary><b>2.3</b> — 107 cards</summary>


**Deuda técnica interna** (49)

- /l10n-check corre 13 de los 17 tests de paridad y no puede notarlo
- ADR-013 de casa no dice que Yala tiene su propio hook commit-msg
- CI: un runner lento agota el tope de 45 min y frena un PR que iba en verde
- Cada corrida de tests unitarios deja ficheros de preferencias huérfanos en el simulador, y llena el disco poco a poco
- Cinco lecturas locales que fallan en silencio dejan un rastro falso o ninguno, y confunden el diagnóstico de una avería
- Con la cola de métricas llena, un envío puede borrar canarios del Modo Nube que nunca salieron
- Dos bancos de pruebas del gate y del CI no los ejecuta nadie, así que no vigilan nada
- El --dry-run del avisador de Grok envía el aviso de verdad si va con --avisar
- El CI sigue usando `actions/checkout@v4`, que GitHub ya fuerza a correr sobre otro Node
- El XCUITest de ⌘F para abrir Buscar pasa en un iPad recién creado y falla tras varias corridas
- El XCUITest del aviso de pérdida al cambiar de Apple ID falla en iOS 27
- El aviso de cierre de una sesión puede citar el PR de otra o ninguno, sin avisar
- El botón «OK» del aviso de cierre de sesión bloqueado no tiene identificador, así que ningún XCUITest puede pulsarlo
- El candado anti-atribución no ve rebase, cherry-pick, revert ni los merges hechos en GitHub
- El gate local no corre el check de aislamiento de tests que el CI sí bloquea
- El gate no ve los warnings de los ficheros de test y lee los de la app de un build incremental
- El gate puede filtrar tests por el nombre del fichero y correr menos suites de las pedidas sin avisar
- El guion de la tanda de QA vuelve a dejar fuera, sin avisar, tickets que esperan prueba en el iPhone
- El panel de depuración de la nube dice «red 0» en una vuelta a iCloud parada por red y no enseña su reloj
- El sello del gate cambia al mover un renombrado dentro o fuera del índice, y no ve el fichero borrado del renombrado
- El test del aviso de divisa secundaria sale rojo en el iPhone SE porque vuelve atrás con el primer botón de la barra
- El test del paywall retenido tras el aviso de la Bandeja falla solo cuando corre en lote con otras cinco clases
- El test que obliga al aislamiento del espejo de grupos no vigila wipeLocalGroupsDomain
- El texto de «no pudimos desasociar» se decide dentro de la vista y ningún test de comportamiento lo alcanza
- En el iPad, el test de la barra lateral falla cuando corre detrás de los tests que estrechan la ventana
- Falta un seam de UI-test que siembre la asociación de grupos, y por eso dos estados de «¿Dónde viven tus datos?» no se prueban en pantalla
- Falta un test que pruebe que una sesión en la nube no encola el vaciado remoto del Apple ID
- Filtro de tickets con Haiku: duplicados y ya resueltos antes de lanzar
- Los XCUITest de navegación buscan la barra de pestañas del iPhone y en iPad fallan
- Los XCUITest del registro por imagen no llegan al botón flotante en el iPad
- Los botones de las pantallas de la puerta de Grupos no tienen su identificador de accesibilidad en runtime
- Los comentarios del re-arranque del canal de Grupos prometen una protección que ya no existe
- Los dos tests de edición masiva (`BulkEditUITests`) fallan en el iPhone SE
- Los ejes 4a y 4b del spike del borrado del store salen rojos de vez en cuando en el gate, también con la suite aislada
- Los goldens del gateway hacen en serie las llamadas que el Worker lanza en paralelo: el fetch de Node 26 encola los POST
- Los tests borran el fichero SQLite con la conexión todavía abierta, y eso llena el log de avisos de integridad
- Los tests del cambio de divisa preferida copian la lógica en vez de ejecutarla
- Los unit tests dejan entradas en el espejo real del App Group del simulador, y otros tests pueden leerlas
- Ningún perfil de seed de Grupos tiene un heredero, así que «Transferir y salir» no se puede ver en el simulador
- No hay datos de prueba con una solicitud de grupo rechazada, así que su aviso no se puede ver en el simulador
- Perfil de prueba de voz two pone Taxi en Restaurantes
- Probar momentic.ai (E2E con IA) en Yala, plan gratis
- Recetas de traducción y el /qa usan el simulador compartido sin pedir turno, y pueden dar rojos falsos
- Relanzar sin -uitest-reset a veces enseña el Panel con todas las secciones
- Relanzar un UI-test con la misma siembra y sin reset duplica todos los datos, y parece un error de cálculo
- Restaurar desde iCloud no deja rastro en el log cuando encuentra tus datos, el único desenlace sin miga
- Un PR que solo toca encargos/ en markdown dispara la suite entera de iOS en CI
- Una corrida de tests deja el onboarding marcado como visto en el simulador
- `test_recordSelectorsOpenAtMediumDetent` falla porque toca el chip de etiquetas cuando está fuera de pantalla

**Robustez de la nube y las sesiones** (22)

- Al activar la nube, algunas categorías y movimientos antiguos pueden salir duplicados en todos tus teléfonos
- Al darse de alta en la nube, el consentimiento se registra antes de saber si podrás entrar, y puede quedar en el iCloud del dueño
- Al reinstalar con conexión, Restaurar puede decir «No encontramos tus datos» porque el aviso de la cuenta en la nube aún no ha llegado
- Al reinstalar, Restaurar puede decir que tus datos están a salvo en una cuenta ya borrada, o traerte una copia vieja sin avisar
- Cambiar la divisa de una cuenta en un teléfono puede dejar el otro con movimientos en la divisa vieja
- Cancelar la activación desde la bienvenida mientras comprueba tus datos te deja en la barra al 35 % sin salida
- Con Ajustes abierto, un aviso importante (cambio de Apple ID, vaciado remoto) puede perderse hasta el siguiente arranque
- Con Apple solo puedes entrar en la nube con el Apple ID del teléfono
- Con iCloud Drive apagado, cerrar sesión con grupos puede guardar en plena importación de iCloud y cerrar la app
- Decidir qué hacer con lo que llega a iCloud después de la comprobación del adopt
- En una cuenta en la nube, el idioma de la app no llega a tus otros dispositivos y va al iCloud del teléfono
- En una sesión solo de grupos, «Dónde viven tus datos» dice que tus datos viven en tu iCloud privado
- Medir en un iPhone por qué fallan filas al volver a iCloud, y decidir qué motivos cuentan
- Si la app se cierra mientras borra tus datos viejos de iCloud, pueden volver a aparecer
- Si reinstalas Yala o cierras sesión a mitad de activar la nube, ese iPhone no puede volver a intentarlo
- Tras cerrar la sesión privada para prestar el móvil, la otra persona ve tu nombre y tu moneda
- Tras «Vaciar datos», los gastos de grupo no vuelven a Registros y al Panel hasta que la app se cierra y se abre de nuevo
- Una compra de Apple Pay en una sesión solo grupos se convierte en un borrador personal que esa sesión no enseña
- Volver atrás desde el acceso a la nube deja el Welcome como ya elegido, y si la app se cierra ahí se salta la comprobación de iCloud
- «Dónde viven tus datos» dice «Todo al día» con la sincronización parada y tus movimientos sin subir
- «Tengo una invitación» pide reabrir Yala para encender una copia en iCloud que ese camino no usa
- «Volver a iCloud» no aparece en el segundo dispositivo de quien creó su cuenta en la nube

**Captura automática (paridad)** (11)

- Bienvenida: proponer importar el último estado de cuenta para empezar con datos
- Detectar gastos hormiga y decir cuánto suman al mes
- Detectar pagos recurrentes y suscripciones en el historial y proponer convertirlos en pagos planificados
- El CSV que exporta Yala no se puede volver a importar en Yala
- Logos de suscripción en pagos planificados (Netflix, Spotify…)
- Modo manos libres: aprobar sola la Bandeja cuando Yala está segura y mandar un resumen diario
- Panel: ranking de comercios y reparto del gasto por cuenta o tarjeta
- Registrar movimientos desde correos de alertas del banco
- Registrar movimientos desde la notificación del banco (Atajos + App Intent)
- Reglas para clasificar gastos dichas en lenguaje natural («lo menor a S/5 va a Gastos hormiga»)
- Soporte por WhatsApp para quien escribe a Yala

**Bugs de la app** (10)

- Al volver a Yala, una pantalla podría quedarse sin actualizar sus números hasta volver a salir de la app (sin medir)
- Cambiar el tamaño del texto con Exportar abierto devuelve las cuentas a «todas»
- Con dos necesidades filtradas desde Registros, el Panel enseña solo una en su chip y en el widget de necesidades
- Con «Todo el tiempo», el Sankey de Distribución se recalcula en cada repintado
- Distribución recalcula dos veces cada vez que tocas el filtro de ingresos o gastos
- En «Profundizar» de Reportes, el centro de la fila no añade la dimensión
- La ayuda dice que mantener pulsado un registro abre la edición masiva, y lo que abre es su menú
- Las etiquetas de un registro cambian de orden cada vez que abres Yala, y con más de tres cambian las que se ven
- Un aviso de la cola que no llega a enseñar nada podría dejar esperando al siguiente
- «No se pudo guardar» aparece aunque los cambios de la cuenta ya se ven en el resto de la app

**iPad, iPhone Duo y otros tamaños** (8)

- En iPad, 19 hojas de Yala se abren a media altura aunque la ventana sea enorme
- En iPad, Ajustes puede no salir con lista y ajuste lado a lado según desde dónde lo abras
- En iPad, Reportes y Buscar estiran sus filas a todo el ancho de la pantalla
- En iPad, con Yala IA abierto en Registros, el texto «Elige un registro para verlo aquí» sale medio tapado por la lista
- En iPad, la lista no marca qué registro o presupuesto tienes abierto al lado
- ReceiptDropUITests: test_lockedPDF falla 2 de 5 en iPad (crash de UIKit al retirar la contraseña enfocada; soltar sin hoja)
- Simulador del iPhone Duo: Xcode 27.1 ya está; falta el runtime iOS 27.1 y crear el simulador
- Yala en el iPhone Duo: barras laterales, el pliegue y pantalla completa

**Yala IA** (3)

- Ninguna llamada de IA pone tope a la longitud de la respuesta: una respuesta desbocada cuesta tokens y puede acabar en error en el chat
- No se guarda cuántos tokens gasta cada función de IA, así que no hay coste por pregunta, foto o nota de voz
- Yala IA: guía con ejemplos de cómo pedirle las cosas

**Pro y monetización** (2)

- Al entrar con tu cuenta, el Pro pagado puede no aparecer hasta volver a abrir la app
- Avisar unos días antes de que termine la prueba gratis de Yala Pro

**Auditoría UX 2.2** (1)

- Rediseñar por completo los tutoriales y actualizarlos

**Personalidad y marca** (1)

- Analizar una mascota en la app

</details>

<details>
<summary><b>2.4</b> — 113 cards</summary>


**Robustez de la nube y las sesiones** (36)

- Al cancelar la vuelta a iCloud, lo que iCloud bajó durante la espera sube a tu cuenta de la nube, incluso movimientos que habías borrado
- Al cerrar sesión en la nube, las preferencias que no subieron se pierden sin aviso
- Al entrar en tu cuenta de la nube, un importe que cambias justo antes de reabrir puede subir con el valor viejo que trajo iCloud
- Al entrar en una cuenta de la nube vacía, lo que iCloud baje antes de reabrir sube a la cuenta sin que nada lo cuente
- Al volver a iCloud, algunos movimientos podrían aparecer dos veces si otro teléfono exportó tarde sus datos viejos
- Con el reloj del iPhone atrasado, tus datos dejan de subir a la nube cada hora y Yala te pide volver a iniciar sesión
- Con la hora del iPhone atrasada, tu edición de un gasto que otro ya cambió se pierde en el servidor sin aviso
- Crear una cuenta nueva en la nube puede subirle los datos que iCloud ya bajó al teléfono, aunque sean de otra persona
- El reparto de «Vaciar datos» ocupa el almacén de iCloud sin techo y no se retira nunca
- El servidor acepta un importe «NaN» al subir cambios, y eso rompe la verificación de integridad de la cuenta o el grupo
- En la nube, aceptar perder tus cambios cuando el aviso no pudo contarlos se lleva también lo que apuntes después
- La primera vez que arranca la nube en un teléfono, un cambio tuyo a medio guardar podría no subir nunca
- La vuelta a iCloud de una cuenta migrada suma lo que otro dispositivo escribió en ese iCloud después de migrar
- Leer la cuenta de Grupos asociada borra preferencias si el dato está corrupto, y esa lectura corre en cada pintado de Ajustes
- Repetir «Desasociar» tras un fallo puede duplicar en tu Panel los gastos de grupo que conservaste
- Si dos teléfonos se cruzan en el servidor en el mismo instante de la activación, el segundo puede volver a subir todos sus datos encima
- Si el llavero falla al leerse, alguien que nunca tuvo cuenta en la nube no puede cerrar su sesión privada
- Si el teléfono no puede leer sus presupuestos al fusionar cuentas duplicadas, un presupuesto sigue filtrando por una cuenta borrada
- Si falla una lectura mientras se reparan etiquetas o cuentas duplicadas, la reparación puede quedar a medias y dejar etiquetas huérfanas
- Si iCloud no termina nunca de importar, entrar en tu cuenta de la nube no se rinde nunca y «Cancelar» no hace nada
- Si la app se cierra justo después de guardar el onboarding de la nube, repetir la activación puede duplicar cuentas y categorías
- Si llega «Vaciar datos» desde otro dispositivo mientras este cambia de modo, la señal se pierde para siempre y este nunca se vacía
- Si sales a mitad de «Volver a iCloud», lo que ya subió se queda en iCloud y puede reaparecer como una copia vieja
- Si soltar la cuenta de grupos falla a medias sin asociación guardada, nunca aparece «Terminar de soltar»
- Si un teléfono ya tenía dos relojes para un movimiento, la app puede leer el viejo y pisar el importe bueno de una transferencia
- Tras soltar y volver a asociar tu cuenta de grupos, borrar un borrador conservado deja el gasto del grupo sin su movimiento
- Tras vaciar datos en un dispositivo, un gasto de grupo puede salir dos veces en el otro con dos borradores
- Tras vaciar los datos en solo-grupos y restaurar, un cobro de grupo ya aprobado puede volver a pedir cuenta y contar doble
- Tras vaciar los datos en un dispositivo, algunos gastos de grupo pueden salir dos veces en otro, con dos borradores en la Bandeja
- Un cambio de grupo apuntado sin sesión antes de actualizar no se sube nunca, y al cerrar sesión Yala dice que es de otra cuenta
- Un gasto apuntado sin red después de vaciar los datos en otro dispositivo puede quedarse sin su cuenta o su etiqueta
- Un gasto de grupo apuntado mientras el cierre de la sesión privada espera a iCloud se borra sin aviso
- Un movimiento que borro en el segundo teléfono mientras el primero está callado reaparece al terminar de activar la nube
- Una edición o un borrado que el primer teléfono aún no subió puede perder frente a la copia que subió el segundo al entrar en la cuenta
- Una referencia que queda colgada durante «Volver a iCloud» no se vuelve a resolver nunca
- Vaciar los datos en dos dispositivos seguidos puede duplicar gastos de grupo en tus cuentas

**Grupos** (28)

- Al abrir una invitación con la bienvenida en pantalla, otra hoja en cola puede abrirse encima de la bienvenida
- Al entrar en Yala por un grupo, la app olvida el idioma que acabas de elegir y vuelve a preguntarlo
- Al unirte a un grupo por enlace, tu nombre no lleva la marca «(tú)» hasta que reabres la app
- Ante un empate, «quién paga a quién» en un grupo puede salir distinto en cada apertura y en cada resumen compartido
- Buscar gastos dentro de un grupo por descripción, importe o quién pagó
- Con la hora del teléfono atrasada o tras un cambio en el servidor, los cambios de mis grupos dejan de subir un rato aunque todo esté bien
- Con un segundo dispositivo sin actualizar, aprobar allí el aviso de importe cambiado de una liquidación suma el pago dos veces
- Cuando Grupos te bloquea una cuenta ya completa, la opción de usarla para tus finanzas es solo un texto, sin botón a Ajustes
- Cuando «Empezar de cero» se para un momento, la cifra del aviso a veces deja fuera los cambios de grupos de otra cuenta
- Dos procesos de grupos siguen decidiendo por fila en vez de por grupo cuando hay duplicados antiguos
- El pull de Grupos hace 5 peticiones por cada grupo aunque no haya cambios, y con ~200 grupos chocaría con el límite del Worker
- El recordatorio de deuda dice «lleva semanas sin moverse» tras registrar un pago con fecha atrasada o editar un gasto viejo
- En Archivados, el aviso de una liquidación que dejé con su importe anterior parece un pago que rechacé
- En el widget, el saldo cuenta las patas de préstamo de los gastos de grupo que el gasto del mismo widget excluye
- Importar un grupo desde el export de Splitwise o Tricount para seguir con los mismos saldos
- Quien venía a crear su primer grupo lo pierde si la app tiene que relanzarse al entrar con su cuenta
- Si abres una invitación de grupo mientras Yala borra el teléfono en la bienvenida, al terminar la app sale igual por el camino privado
- Si el dispositivo que vació repone justo cuando el otro deja de esperarle, un gasto o un pago de grupo sale dos veces
- Si falla el guardado al preparar tus cambios de grupos, quedan a medio escribir con su copia de seguridad puesta
- Si la nota de hasta dónde bajó cada grupo no se deja leer, la app vuelve a bajar todos los grupos desde cero
- Si me rechazaron de un grupo y vuelvo a pedir entrada sin buena red, la invitación puede perderse mientras se envía
- Si un reparto de un gasto de grupo llega repetido, Balances muestra el doble de lo que cada uno debe
- Si una invitación interrumpe la bienvenida justo al comprobar Grupos, Ajustes puede quedarse sin responder hasta relanzar
- Tras «Empezar desde cero» la app no pregunta si traer los gastos de grupo a tus finanzas
- Una invitación a un grupo que falla por algo pasajero caduca a los 7 días sin avisar a la persona
- Una invitación a un grupo que falló sin red no se reintenta al volver la red, aunque la pantalla diga que sí
- «Salir de todos mis grupos» cuenta mi segunda fila de miembro como otra persona y clasifica mal el grupo
- «Transferir y salir» desde Ajustes del grupo no se retoma solo si la app se cierra entre ceder el grupo y salir

**Divisas y cifras exactas** (22)

- Al cambiar de divisa preferida, la app pide las tasas de la divisa que dejas y no de la nueva
- Al tocar un día del gráfico de flujo, su detalle nunca dice si ese día es aproximado
- Cambiar la divisa de una cuenta con mucho histórico tapa la pantalla minutos, sin progreso ni forma de cancelar
- Con dos filas de tasas del mismo día, un gasto en otra divisa puede convertirse distinto en cada iPhone
- Con el iPhone en calendario budista o japonés, las conversiones de divisa usan la tabla aproximada y las tasas se guardan con otro año
- El barrido que corrige tasas 1:1 antiguas no deja ningún dato de cuántas filas curó
- El importe del mes anterior con el que comparas nunca dice si es aproximado
- El saldo de un mes cerrado nunca lleva «≈» aunque sus tasas fueran aproximadas
- El total de «Análisis del gasto» no lleva la marca ≈ aunque el Panel sí la pone al mismo número
- El total de «Gasto promedio por día» no lleva la marca ≈ aunque el mismo gasto la lleva en Resumen
- El widget de tasas deja de enseñar tu divisa, sin explicación, cuando la tasa del día no la trae
- Estadísticas y el widget de inicio no se corrigen solos cuando llegan las tasas del día con la app abierta
- Importar movimientos más antiguos que el saldo inicial deja su conversión con la tasa del día viejo
- Informes enseña como exactos los mismos importes que el Panel marca con «≈»
- Las categorías del desglose no dicen cuál hace que el total del mes sea aproximado
- Las páginas de un extracto en PDF que no escriben la divisa salen sin cuenta
- Ningún detector caza que se cambie la divisa, el importe o la fecha de un movimiento sin recalcular su conversión
- Si falta la divisa preferida, cada parte de la app supone una distinta (región, soles o dólares)
- Tres caminos guardan tasas sin avisar a la app, y la marca «≈» puede quedarse con la tasa buena ya guardada
- Un gasto de grupo que cambia de divisa deja tu movimiento con el importe viejo, sin aviso, si el puente está apagado
- Una divisa fuera del catálogo se trata como dólares y se presenta como conversión exacta
- Volver a Yala en un día nuevo no pide las tasas de hoy y el «≈» puede quedarse todo el día

**Accesibilidad y textos** (9)

- Con VoiceOver, algunos controles que muestran un importe solo leen su nombre y no la cifra
- Con el texto muy grande, importes y rótulos aún se cortan en pantallas secundarias
- Con el texto muy grande, la hoja de «datos viejos en tu iCloud» puede dejar sus botones fuera de la pantalla
- Con texto grande, la fila de entradas y salidas del hero de Estadísticas sale cortada
- En el iPhone SE con texto grande quedan textos cortados, dos pantallas de éxito sin medir y una tarjeta de la guía que puede salirse
- En español de Argentina, «Dónde viven tus datos» y otros avisos salen en tuteo y el resto de la app en voseo
- Si exportar tus datos falla, el aviso sale en español aunque tengas la app en otro idioma
- Yala IA no usa el trato que toca (tuteo, voseo, «você») cuando la app está en una variante regional del idioma
- «Inicia sesión para subir 1 cambios» sale sin plural en «Dónde viven tus datos»

**Finanzas más hondas** (9)

- Ciclo del mes según tu día de pago (por ejemplo, del 25 al 25)
- El hero de cada vista: que el usuario elija qué muestra (disponible del mes, saldo actual u otro)
- Exportar los insights en un resumen sencillo y fácil de compartir
- Pagos en cuotas: registrar una compra a plazos y ver lo que queda por pagar
- Predicción del gasto del mes en curso dentro de cada línea del flujo de caja
- Presupuesto que se adapta a tus ingresos o a tus gastos
- Presupuestos recomendados con IA
- Seguimiento de ahorros con metas
- Seguimiento de deudas personales

**Tarjetas y cuentas** (6)

- Ajustes › Cuentas: lista clara con el nombre, tocar abre la vista de la cuenta y desarchivar en lote
- Archivar una cuenta: decidir si oculta su historial, y qué pasa con el downgrade y las archivadas antiguas
- Colecciones de cuentas: agrupar cuentas («Casa», «Negocio») para filtrar el Panel por ellas de un toque
- Formulario de cuenta: vista previa en vivo, elegir color y editar el saldo bien explicado
- Las cuentas se ven poco: darles más presencia en la app
- Perfil Empresa y Personal: separar los gastos del negocio de los de la casa

**Notificaciones** (3)

- 2.2 · Notificaciones dentro de la Bandeja
- Notificaciones inteligentes con IA
- Rediseñar las notificaciones desde cero

</details>

<details>
<summary><b>2.5</b> — 185 cards</summary>


**Robustez de la nube y las sesiones** (125)

- Al activar Yala completo en privado, tus otros dispositivos no se enteran de que terminaste el alta
- Al activar la nube, si la sesión caduca al verificar, la app reintenta como si faltara conexión y acaba diciendo que falló
- Al cerrar la sesión privada, el aviso de cambios sin subir puede volver a salir con otra cifra tras tocar «Cerrar sesión igualmente»
- Al cerrar la sesión privada, el aviso de «no pudimos confirmar» puede salir después de soltar la sesión en vez de antes
- Al cerrar sesión en Ajustes, la hoja promete que tus grupos siguen en tu cuenta aunque esa cuenta ya no exista o sea de otra persona
- Al cerrar sesión esperando a otro dispositivo, el aviso pide terminar desde aquí un paso de datos que solo se puede dejar de esperar
- Al confirmar «Empezar desde cero» la app promete una cuenta nueva sin tus datos, y lo que abre es otra comprobación de iCloud
- Al crear un enlace de invitación, Yala te pide revisar la conexión aunque el fallo sea del servidor o de la sesión
- Al migrar a la nube, si tu sesión se borra en el paso del 22 %, Yala no te lo dice hasta pasados 15 minutos
- Al pasar a la nube, la activación sigue adelante aunque no pudo leer lo que iCloud sabe de tus datos
- Al volver a iCloud, un «Cancelar» tocado en el momento justo borra el aviso que acababa de salir y no confirma nada
- Auditar las marcas `cloudSync.*` que sobreviven al borrado del cierre de sesión
- Borrar la cuenta en una sesión solo de grupos no espera a que lo último llegue a iCloud
- Cerrar la app justo después de borrar mis datos de iCloud me devuelve a «Restaurar», sobre un iCloud ya vacío
- Cerrar sesión en la nube no comprueba si hay una vuelta a iCloud a medias
- Cerrar sesión en la nube puede borrar un cambio guardado en el instante entre la subida y el cierre
- Cerrar una sesión privada sin cuenta de grupos deja en el teléfono los grupos antiguos de la época CloudKit
- Comprobar en Supabase si algún grupo quedó a la vez en iCloud y en el servidor
- Con el reloj del teléfono atrasado, salir de un grupo puede decir «Tu sesión caducó» con red y sesión buenas
- Con el servidor sin poder guardar, cerrar sesión dice «Un momento más… espera unos segundos» una y otra vez
- Con la hora del teléfono adelantada, un cambio que falla y se reintenta puede devolver un gasto a su importe viejo en todos los teléfonos
- Con otra cuenta abierta en el teléfono, cerrar sesión dice «Tu sesión caducó» y manda a un «Iniciar sesión» que no aparece
- Durante el paso a la nube, un dispositivo privado deja de obedecer el vaciado remoto: no resetea sus preferencias y calla el aviso
- El alta de un móvil prestado se cierra sola con «Listo, tus datos están aquí» cuando el dueño termina su alta en otro dispositivo
- El ancla de subida a iCloud acepta eventos de cualquier contenedor y supone que un export con éxito lo subió todo
- El aviso de «No pudimos soltar la cuenta» dice que tus grupos siguen en el iPhone cuando ya se borraron
- El aviso de «datos viejos en tu iCloud» puede ofrecer borrarlos mientras tus datos se están subiendo a la nube
- El aviso pendiente de «vuelta a iCloud terminada» se manda con la sesión de la cuenta que esté abierta, aunque sea otra
- El aviso «Cerraste tu sesión de grupos» ya no lo enciende nadie y queda como código muerto
- El aviso «No pudimos preparar este teléfono» puede salir días después sin que se haya intentado nada
- El aviso «no pudimos comprobar tus datos» se decide mirando Supabase, pero la configuración se pide al gateway
- El barrido de tasas 1:1 viejas puede sellarse con la restauración de iCloud a medio bajar
- El comentario de StorageRowGateLogic dice que producción sirve la nube al 0 % cuando sirve el 100 %
- El marcador de la activación de la nube se escribe sin la cuenta si la sesión falta en ese instante
- El sello del claim se apunta a la cuenta que hay al volver, no a la que mandó el claim
- El servidor responde «atestación inválida» cuando lo que falla es su propia base de datos, y el teléfono puede acabar sin sincronizar
- En la bienvenida, «Empezar desde cero» sin poder comprobar iCloud responde «Puedes seguir»
- En la sesión privada, el aviso de sesión de grupos caducada pide volver a entrar sin decir dónde
- En los teléfonos de QA que tuvieron una sesión de visita, la sesión de nube de la otra persona sobrevive a su retirada
- En modo nube, si la sincronización personal se para, tus grupos también dejan de sincronizar y volver a la app no lo arregla
- En tres de los cuatro cierres de sesión, el rastro dice cuántos cambios quedaban pero no qué aviso vio la persona
- En un iPhone restaurado, «Activar la nube» puede pasar tus finanzas a otra cuenta antes de saber cuál es la de tus grupos
- Esperando a otro teléfono, «Dejar de esperar» puede quedarse gris hasta cinco minutos sin que la tarjeta diga por qué
- Falta la red que impida que un nuevo sitio cambie el perfil financiero sin sincronizarlo
- La bienvenida dice «Revisa tu conexión» cuando otro dispositivo tomó el relevo de la activación
- La limpieza de borradores de grupo corre una vez por lote de importación de iCloud en vez de una al final
- La nota que justifica tener el motor de sync encendido dice que todo dispositivo de producción es iCloud, y ya no es cierto
- La pantalla de error de «Restaurar desde iCloud» existe y está traducida, pero nada la muestra nunca
- Los borradores que crea la espera del cierre de sesión no aparecen en la Bandeja hasta el siguiente refresco
- Mientras esperas la vuelta a iCloud, «Dónde viven tus datos» puede engancharse cada 30 s con muchos movimientos
- Mientras «Activar la nube» comprueba la cuenta, «Asociar» y «Desasociar» de Grupos siguen activos y pueden tapar el consentimiento
- Reparar una identidad colapsada igual en dos teléfonos (líneas de tarjeta)
- Repetir el alta en la nube sobre tu propia cuenta vacía la marca como nacida en la nube sin comprobar si el teléfono tuvo iCloud
- Restaurar decide su desenlace con una señal de descarga que puede venir de antes de esta búsqueda
- Restaurar desde iCloud puede contar grupos borrados y no contar los archivados
- Restaurar dice «Eliminaste tus datos en este dispositivo» aunque el borrado se hizo en otro
- Si Restaurar solo encuentra presupuestos, el onboarding no te pregunta tu moneda y la da por sabida
- Si Yala se cierra a mitad de «Activar la nube», la cuenta con la que entraste se queda como tu cuenta de grupos
- Si atrasas la fecha del iPhone durante la vuelta a iCloud y luego la corriges, la vuelta puede cancelarse sola
- Si cambias la categoría de un movimiento que esperaba la suya de la nube, la app puede devolverle la vieja
- Si cancelas el camino privado y eliges Restaurar, días después «Empezar de cero» del aviso de iCloud deja grupos que no eran tuyos
- Si cancelas «Migrar a la nube», cierras sesión y vuelves, Yala dice que esa cuenta ya tiene datos y no puedes terminar la migración
- Si confirmas «Cancelar la activación» justo cuando vence el plazo, ves la tarjeta de fallo en vez de volver a empezar
- Si el arranque no puede leer el estado de la migración, el aviso de cambio de Apple ID no sale hasta el siguiente arranque en frío
- Si el segundo dispositivo entró a la nube tras borrar algo, un tercero con el mismo iCloud puede quedarse siempre en «espera a iCloud»
- Si el servidor rechaza un token de App Attest válido, tus cambios no suben y ningún aviso te lo dice
- Si el teléfono no puede leer su propia base al mover los datos a la nube, la pantalla dice que falta conexión
- Si iCloud aún está bajando datos al desasociar, el aviso dice que quedan cambios de tus grupos sin subir
- Si instalas una versión anterior de Yala, la tarjeta de la nube te pide reabrir la app cuando lo que hace falta es actualizarla
- Si la app se cierra justo al terminar de entrar en tu cuenta de la nube, puede quedarse sin sincronizar diciendo que todo va bien
- Si la app se cierra mientras sale de una activación de la nube fallida, el arranque siguiente registra esa sesión como tu cuenta de Grupos
- Si la bienvenida se queda esperando a iCloud y luego activas la nube desde Almacenamiento, la sesión no se cierra al pararse otra vez
- Si la cuenta no te deja entrar, la bienvenida puede decir «Escríbenos» y a la vez ofrecer un «Reintentar» que no arregla nada
- Si la hoja del aviso tardío de iCloud se cierra justo tras borrar, el borrado se repite al abrir la app otra vez
- Si la sesión se renueva justo después de soltar la cuenta de grupos, la sesión vuelve y los grupos pueden volver a bajar
- Si la subida a la nube choca con un error que esperar no arregla, al cerrar sesión Yala te dice que lo intentes en un rato
- Si la vuelta a iCloud se rinde mientras estás en otra pantalla, al abrir «Dónde viven tus datos» no sale ningún aviso
- Si se corta la red al crear tu cuenta en la nube y eliges iCloud, «Migrar a la nube» con esa cuenta dice que ya tiene datos y no es así
- Si se pierde la marca de sesión, la app enseña todas las pestañas vacías y calla el aviso de datos borrados
- Si tocas «Volver a iCloud» mientras la app retoma algo por su cuenta, el toque no hace nada y no lo dice
- Si «Activar la nube» se agota en el paso del 22 %, la vuelta a iCloud que quedó pendiente en el servidor ya no se completa
- Si «Cerrar sesión» no puede borrar los datos al reabrir Yala en una sesión privada, vuelves a entrar sin ningún aviso
- Si «Cerrar sesión» se para porque la sesión sigue abierta, el Pro de la cuenta puede verse apagado hasta reintentar o reabrir Yala
- Si «Empezar de cero» del aviso de iCloud falla a medias, puede saltar después el aviso de «tus datos se borraron desde otro dispositivo»
- Si «Empiezo de cero» falla a medias, el aviso dice «Tus datos siguen aquí» cuando parte ya se borró
- Si «Terminar de borrar» falla pronto, la pantalla vuelve igual y no dice que lo intentó
- Si «Vaciar datos» falla a medias, desaparece el borrador que preguntaba a qué cuenta llegó un cobro de grupo
- Sin App Attest y con la sesión caducada, el aviso de cerrar sesión manda a un «Iniciar sesión» que no aparece
- Tocar «Volver a iCloud» con la tarjeta desfasada cancela la vuelta anterior en vez de empezar una nueva
- Tras activar Yala completo en la nube, apagar los avisos de pagos programados no sobrevive a reinstalar la app
- Tras cambiar de cuenta de iCloud, la app sigue creyendo que hay datos bajando de la cuenta anterior
- Tras cancelar sin conexión la vuelta a iCloud, mis cambios en la nube no suben hasta que salgo y vuelvo a la app
- Tras un borrado a medias, la pantalla de «faltan cambios de grupos» dice «No borramos nada» aunque iCloud ya se borró
- Tras un «Volver a iCloud» que el servidor no concede, un teléfono con la migración a medias deja de sincronizar hasta reabrir Yala
- Tras «Empezar desde cero», el teléfono puede quedar en modo nube sin sesión y pedir a la persona nueva entrar en una cuenta ajena
- Tras «Vaciar datos» en otro dispositivo, algunas cuentas o categorías viejas sin uso pueden sobrevivir y volver
- Un aviso pasajero de iCloud justo antes de cerrar Yala hace que, al volver horas después, la vuelta a iCloud se cancele en el acto
- Un cambio de preferencia hecho cuando el teléfono no puede leer su cola de pendientes no llega a tus otros dispositivos
- Un enlace de tarjeta cambiado en v1 sube con la hora de la subida, no con la suya
- Un error pasajero al subir a iCloud queda apuntado hasta cerrar la app aunque después todo suba bien
- Un gasto que iCloud baja mientras entras en tu cuenta de la nube se queda en este iPhone y no llega a la nube
- Un inicio de sesión que Yala rechaza deja igual mi suscripción Pro vinculada a esa otra cuenta
- Un modo de almacenamiento que la versión instalada no reconoce se lee como iCloud y podría montar el espejo sobre datos en la nube
- Un teléfono que espera a otro puede esperar para siempre si la reserva del servidor no tiene latido
- Una migración a la nube que empieza mientras se cierra la sesión se queda sin sesión y pide volver a entrar
- Una preferencia que acabas de cambiar vuelve un momento al valor de la nube antes de que tu cambio suba
- Una preferencia que el servidor rechaza siempre se vuelve a mandar en cada sincronización, sin fin y sin avisar
- Una referencia mal formada desde la nube deja viva la nota vieja de «esto va con tal categoría»
- Una sincronización con iCloud que falla por un error interno cuenta como completada en el estado de sync
- Volver desde la revisión de iCloud tras «Empezar desde cero» lleva a «Es mi primera vez» en vez de a Restaurar
- Volviendo a iCloud, si la sesión caduca mientras se limpian los restos de la nube, la barra se para sin decir nada
- «Activar Yala completo → nube» con una cuenta que ya es completa te hace el onboarding y luego te pide cerrar sesión
- «Activar la nube» desde la bienvenida empieza aunque el registro de la migración no se pueda leer, y se queda al 0 % sin «Cancelar»
- «Crear mi primer grupo» te pide cerrar sesión desde Ajustes en una bienvenida donde no hay Ajustes
- «Crear otra cuenta» que acaba en «reinicia Yala» no dice que entraste en tu cuenta
- «Descargando tus datos…» sigue en pantalla aunque ya haya movimientos visibles
- «Descargando tus datos…» sigue girando cuando la nube ya dejó de intentar descargar
- «Empezar desde cero» al activar Yala completo deja en el teléfono los datos de iCloud si otro dispositivo ya vació iCloud
- «Empezar desde cero» en Restaurar es texto suelto: sin rol destructivo y con un área táctil menor de 44 pt
- «Encontramos tus datos en iCloud» cuenta también tus grupos, que no están en iCloud sino en tu cuenta de Yala
- «Sincronizar ahora» de iCloud responde OK sin tocar la red si ya había un sync en curso
- «Terminar de soltar la cuenta» dice «Estás cerrando sesión» cuando en realidad acabas de volver a entrar
- «Tu cuenta está lista» sale sin comprobar que la sincronización arrancó
- «Vaciar datos», «Empezar de cero» y el vaciado desde otro dispositivo no esperan a que termine el paso de tus datos a la nube
- «Volver a iCloud» se ofrece en un iPhone sin iCloud activo, y la vuelta no puede terminar

**Deuda técnica interna** (19)

- Adoptar el formato JSON del proyecto de Xcode cuando 27.2 sea estable
- Al fallar el borrado del desasociar, el rastro de diagnóstico queda abierto como si hubiera crasheado
- BalanceTrendCalculator y BalanceHelper.initialBalanceForTrend no tienen llamadores de producción
- Comentarios del código que aún hablan de la sesión de visita retirada
- Documentar que los worktrees heredan el candado anti-atribución por la ruta absoluta de core.hooksPath
- El /gate dice que todo el repo es Swift Testing, y los XCUITest son XCTest
- El Atlas de flujos de Modo Nube describe pantallas que el rediseño de sesiones ya retiró (58 fallos)
- El README de las migraciones de la nube no tiene entrada para g13_04 ni g13_05, y una migración remite a ella
- El barrido de tasas corre también durante los XCUITest, al revés que los demás barridos del arranque
- El comentario de `resolveEmptyState` promete una cancelación que su `Task` suelto no recibe nunca
- El recuento `_meta.counts` del índice de QA no coincide con las áreas que tiene
- El turno del simulador se toma también para compilar, y durante ese rato el simulador está parado
- El volumen de CI de hoy no cabría en la Mini si Yala pasara a privado
- El workflow del CI remite tres veces a `TESTING-STRATEGY.md`, un documento que no está en el repo
- La carpeta tickets/qa/ guarda capturas de tickets que ya no están en qa
- La sesión gráfica del usuario `ci` en la Mini arranca servicios que el runner no usa
- Los unit tests pueden borrar la racha de App Attest de la app del simulador que un device-QA de 24 h necesita
- Ningún test fija qué reloj publican el canario y el rastro de espera de la subida y de la vuelta a iCloud
- Un XCUITest de cierre de sesión que falla deja el borrado armado en el simulador

**Yala IA** (16)

- Al dictar en el chat no se respeta el idioma de voz elegido en Ajustes, y la hoja de voz no filtra las frases inventadas del silencio
- Analizar que Yala AI responda por voz (GPT Voice)
- Con el modo «solo gastos» activo, el chat de Yala IA puede proponer un borrador de ingreso
- El chat de Yala IA reenvía todos los turnos del día en cada pregunta y paga tokens que no usa
- El chat registra como máximo cinco movimientos por mensaje y no alcanza para pegar un mes entero
- El prompt del resumen de Tendencias pide el idioma solo con el código y cita «gasto» entre comillas
- Explorar si Yala IA puede ayudar en Flujo de caja, y cómo
- Las respuestas de IA piden «un JSON» y no un esquema fijo: un campo que falta se rellena en silencio con un valor por defecto
- Las sugerencias del chat descartan las que nombran un pago recurrente del usuario
- Los comentarios de IA pueden malinterpretar tus datos: tres etiquetas que la app le manda inducen a error
- Registrar un gasto de grupo desde el chat o por voz («cena 120 dividida entre todos»)
- Si el contexto del chat no se puede preparar, Yala IA contesta que no tiene datos en vez de avisar del error
- Si rechazas el permiso de IA al compartir una foto, la próxima vez que registres por imagen sale esa foto vieja
- Si sales del análisis de IA y vuelves en menos de 5 segundos, sale un error aunque la respuesta ya esté guardada
- Yala AI haga más que crear registros
- Yala IA entiende Grupos como un contenedor aparte de lo personal

**Conector de Claude (MCP)** (8)

- Conectar Yala en Claude iniciando sesión con Apple o Google
- Desconectar Claude desde Claude deja abierta una sesión huérfana en Supabase
- El conector de Claude da otro «saldo de hoy» que la app con un movimiento de fecha futura
- Endurecer el conector MCP en producción cuando la nube esté estable
- Opcional: publicar el issue redactado para supabase/auth y probar el conector MCP de staging desde Claude
- Plugin de Yala para Claude: que Claude lea tus finanzas de la nube, sin poder tocarlas
- Que el conector de Claude sepa en qué zona horaria vives para que «este mes» cuadre con la app
- Yala en ChatGPT, Claude y Grok: diseñar el servidor MCP de solo lectura

**Grupos** (8)

- Al abrir Grupos o un grupo, la app lee del disco dos veces seguidas
- Con el almacén dañado, la app vuelve a repasar todos los gastos de grupo en cada arranque, sin parar nunca
- Con el drain de Grupos atascado, otra cuenta y el historial ilegible, el aviso nombra solo el atasco
- Con tres fallos de grupos a la vez, el aviso nombra dos de las tres causas
- Dentro de un grupo, Miembros y Ajustes no comprueban si tu solicitud sigue pendiente
- Los avisos de cambios de grupos de otra cuenta dicen «con ella» aunque puedan ser de varias
- Si otra persona cambia el sentido o la divisa de una liquidación que ya aprobé, mi cuenta del banco no se entera
- Un enlace de invitación sin el parámetro «s» abre la web en vez de la app

**Bugs de la app** (6)

- Al deslizar las gráficas de Distribución, el total de arriba cambia de estilo en cada página
- El botón «+» de nuevo registro aparece de golpe, sin la animación que tienen sus botones hermanos
- En Insights, un presupuesto en riesgo puede salir con el icono genérico al abrir la app en frío
- La rama por cuenta de Tendencias no limpia el saldo de hoy del cálculo anterior, aunque hoy ninguna pantalla llega a ella
- Los cinco métodos de edición masiva de TransactionService son una copia muerta de los del ViewModel
- `ensureRatesForExistingTransactions` no la llama nadie: retirarla o cablearla

**Captura automática (paridad)** (1)

- Asistente de Yala por WhatsApp: anotar gastos, preguntar y recibir avisos sin abrir la app

**Divisas y cifras exactas** (1)

- Un importe de 0,0001 o menos en otra divisa se guarda con una tasa 1:1 falsa marcada como exacta

**Personalidad y marca** (1)

- Idea: rachas de registros (umbral, recordatorios, y la mascota si se decide)

</details>

<details>
<summary><b>3.0</b> — 1 cards</summary>


**Plataformas nuevas** (1)

- Yala en la web: ver el Panel y registrar gastos desde el navegador

</details>

<details>
<summary><b>3.1</b> — 1 cards</summary>


**Finanzas compartidas** (1)

- Cuentas y presupuestos compartidos de pareja o familia: propuesta

</details>

<details>
<summary><b>3.2</b> — 1 cards</summary>


**Plataformas nuevas** (1)

- App de Yala para Apple Watch: apuntar y consultar un gasto desde el reloj

</details>

<details>
<summary><b>4.0</b> — 1 cards</summary>


**Plataformas nuevas** (1)

- Yala para Android

</details>
