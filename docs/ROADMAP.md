# Roadmap de Yala, de 2.2 a 4.0

> **Definitivo, decidido con Jürgen el 2026-10-21**, con 2.1 en revisión de Apple. Sustituye a la propuesta del 19-oct
> (PR #565), que sigue en el historial de git con su apéndice card por card y `docs/roadmap-asignacion.tsv`. Esa
> asignación se aplicó al tablero el 21-oct, ajustada con lo decidido ese día, y el TSV se retiró.
> **La versión de cada card vive en el tablero** (`tablero listar --proyecto yala --version 2.3`), no en este documento.
> Las reglas para ponerle versión a lo que llegue después están en `docs/criterios-de-version.md`, vigentes desde hoy.
> La decisión, con sus razones, está en `docs/DECISIONS.md` («Roadmap de Yala de 2.2 a 4.0»).

## Lo que se decidió el 21-oct

| Tema | Decisión |
|---|---|
| **Parche de 2.1** | No hay 2.1.1 planificado. La barra de «Activar la nube» parada en ~60 % y la primera foto que falla se arreglan en 2.2. Un bug de prioridad muy alta obliga a un parche igual, según los criterios. |
| **Alcance de 2.2** | UX y tarjetas: se cierra la auditoría (también el formulario de registro), Grupos y Flujo de caja pasan al diseño del resto, y entran las tarjetas multidivisa y la de crédito con fecha de corte. Lo grande sale a 2.3 y 2.4. |
| **Fechas** | Ninguna versión tiene fecha. Cada una sale cuando cumple su criterio de salida. |
| **2.3** | «Yala apunta sola»: correo y notificación del banco, suscripciones detectadas y gastos hormiga. Además, Grupos como gancho de llegada. |
| **Correo del banco** | En 2.3 por reenvío a una dirección de Yala; «Conectar Gmail» y Outlook llegan cuando Google apruebe la verificación, que se pide ya. Por el servidor, exige cuenta en la nube; no se construye una cola para iCloud. Quien usa iCloud o el plan free tiene el **atajo del banco**, que se lee en el iPhone. |
| **Pro en 2.3** | El correo leído en el servidor es Pro, con un cupo de prueba gratis. El atajo del banco, leído en el iPhone, es gratis. El total y la lista de gastos hormiga son gratis; el consejo con IA sobre ellos es Pro. |
| **2.4 y 2.5** | 2.4 «Tu mes real» y 2.5 «Yala conversa», en ese orden. La nube queda cerrada al salir 2.5. |
| **Web** | Partida en dos. En 2.3, «Yala web» beta para cuentas en la nube, en una sesión paralela: ver y apuntar borradores a la Bandeja, entrando con Apple o Google. En 3.0, la web completa, después de cerrar la nube. Desde 3.0, la bienvenida propone la nube primero; iCloud privado se mantiene como alternativa. |
| **Mayores** | 3.1 plan dúo, 3.2 Apple Watch, 4.0 Android. El lenguaje de Android se decide en su fase 0. |
| **Conectores de IA** | En 2.3, no en 2.5: Claude y ChatGPT (Grok si se puede) consultan y registran en Yala. La IA solo deja borradores en la Bandeja. Gratis. |
| **Peso de 2.3** | Salen de 2.3: iPad, iPhone Duo y tutoriales a 2.4; «Empezar con datos» a 2.4; manos libres y reglas a 2.5. |
| **Grupos** | Gancho de llegada: importar desde Splitwise y Tricount entra en 2.3 y se promociona en su lanzamiento. También en 2.3, **repartir un recibo con IA** (Pro): foto o voz, «quién comió qué», y la persona ajusta a quién se cobra cada cosa. Sin guardar las líneas, para no cambiar el esquema. |
| **Deuda técnica** | Una cuota en cada versión. Sentry entra en 2.2. Cada versión deja en cero los bugs de prioridad alta. |
| **IA en el iPhone** | En 2.5, lo que el modelo del iPhone haga bien pasa a local y gratis. Hoy ya lo usa Siri. |
| **Lanzamiento** | Cada menor sale con ficha, capturas y novedades al día. El lanzamiento fuerte es el de 2.3, y el siguiente el de 3.0. Lo ejecuta Lola. |
| **Descartado** | Probar momentic.ai: ya hay XCUITest y QA agentic. |

## La estrategia en cinco frases

1. **Primero igualar y después superar.** Pablo y Clever ya apuntan solos los gastos que llegan por el correo del banco, y
   Pablo además por WhatsApp. Yala los iguala en 2.3 (correo) y 2.5 (WhatsApp). Gana con su interfaz, con Grupos y con
   las divisas.
2. **2.2 es la versión de entender la app, no de añadirle cosas.** La auditoría UX dejó más de 150 arreglos decididos. Si
   se le suman funciones grandes, no sale nunca.
3. **Grupos trae gente.** Cada grupo invita a personas que no usan Yala. Importar desde Splitwise y Tricount quita la
   razón para no cambiarse.
4. **La nube se endurece antes de abrir la web entera.** En 2.3 la web solo mira y deja borradores; con la web completa (3.0), la
   nube pasa a ser el camino recomendado, así que sus
   bugs se cierran entre 2.2 y 2.5.
5. **Pro cobra lo que cuesta por uso** (IA, correo y WhatsApp), con un cupo de prueba. Lo que hace que las cifras sean
   correctas es gratis.

## Resumen por versión

| Versión | Objetivo en una frase | Hito que la define | Meta de bugs |
|---|---|---|---|
| **2.1** | Sale la nube, con las sesiones rediseñadas. | En revisión de Apple desde el 21-oct. | — |
| **2.2** | Que cada pantalla se entienda a la primera. | La auditoría UX cerrada, y Grupos y Flujo de caja con el diseño del resto. | 0 de prioridad alta en toda la app; 0 de media en UX, divisas y Grupos. |
| **2.3** | Que Yala apunte sola los gastos que llegan del banco. | Leer el correo de alertas del banco. | 0 de nube de prioridad media. |
| **2.4** | Que las cifras reflejen tu mes real. | El mes financiero y la sección de Ahorros. | 0 de prioridad media; 0 de nube con riesgo de datos. |
| **2.5** | Que se pueda hablar con Yala, también por WhatsApp. | El asistente por WhatsApp. | La nube cerrada por completo: es la condición de 3.0. |
| **3.0** | Yala en el navegador, con la misma cuenta y la misma suscripción. | La web con el Panel y el registro. | 0 de prioridad alta en la web; 0 regresiones en iOS. |
| **3.1** | Finanzas en pareja o en familia. | El plan dúo. | 0 de prioridad alta en lo compartido. |
| **3.2** | Apuntar y mirar desde el reloj. | La app de Apple Watch. | — |
| **4.0** | Yala nativa en Android. | Android en Google Play. | 0 de prioridad alta en Android. |

Ninguna lleva fecha. Cada una sale cuando cumple su criterio de salida, y el roadmap se revisa entero al cerrar cada menor.

---

## Las versiones, una por una

### 2.2 — Se entiende a la primera

**Objetivo.** Que cada pantalla se entienda sin ayuda y que toda la app parezca la misma.

**Dónde está el 21-oct.**

- *Ya mergeado en 2.2:* los lotes decididos 01 (Estadísticas y saldo de hoy), 03 (Exportar y Vaciar), 04 (cuenta, cerrar
  sesión y modo solo grupos), 05 (nube e iCloud), 06 (Yala Pro), 09 (Siri, Atajos y Apple Pay), 10 (Flujo de caja y
  reportes) y 11 (gastos de grupo y saldar), además de Siri gratis con el modelo del iPhone.
- *En PR:* el 07 (Yala IA, #571), el 08 (widgets, iPad y teclado, #576) y el 12 (administrar grupos, #588).
- *Decidido el 21-oct, falta construirlo:* el formulario de registro (lote 2, 22 cards y 3 de backlog, en dos sesiones). Es la pantalla más usada.
- *Falta construirlo:* lo que queda de Grupos I (L12) y de Ajustes (L16), y el resto de lo que está en «lista para lanzar».
- *Espera a Jürgen:* 36 cards en QA y las decisiones de pantalla en «espera decisión».

**Hitos.**

1. **La auditoría UX cerrada:** todos los lotes, incluido el formulario de registro.
2. **Coherencia visual:** Grupos y Flujo de caja con el diseño de Registros y Estadísticas.
3. **Tarjetas:** la tarjeta con varias divisas (entregas 2 a 4) y la **tarjeta de crédito con fecha de corte, fecha de pago
   y aviso antes de pagar**. Van en la misma ventana de cambio de esquema.
4. **Lo que vio el QA guiado de 2.1:** «Activar la nube» termina sin quedarse en ~60 % y sin pedir cerrar la app, y la
   primera foto después de instalar se lee bien. Era el 2.1.1; ya no hay parche.
5. **Siri con la IA de iOS 27** y el widget extragrande.
6. **Sentry:** saber cuándo falla la app y el backend, antes de crecer.

**Sale de 2.2.**

| Qué | A dónde |
|---|---|
| Registrar movimientos desde el correo de alertas del banco, y desde la notificación del banco (Atajos y App Intent) | 2.3 |
| Logos de suscripción en pagos planificados | 2.3 |
| Rediseñar por completo los tutoriales · Yala en el iPhone Duo | 2.4 |
| Ciclo del mes según tu día de pago · ahorros con metas · deudas personales · pagos en cuotas · el hero que elige la persona · que las cuentas se vean más | 2.4 |
| Rediseñar las notificaciones desde cero · las notificaciones dentro de la Bandeja | 2.4 |
| Las del conector de Claude (endurecerlo en producción, saldo de hoy, zona horaria, issue opcional) | 2.3 |
| Yala IA entiende Grupos · explorar si Yala IA ayuda en Flujo de caja | 2.5 |

El arreglo pequeño de los tutoriales (L16-16, «felicitan por algo que no se hizo») sí se hace en 2.2. El rediseño entero
va en 2.4.

**Entra en 2.2.** Los bugs de prioridad media que dan **cifras distintas para el mismo dinero** (el saldo del Panel frente
a «¿Cuánto tienes hoy?», ingresos y gastos distintos según la pantalla, el «vs mes pasado» con un día de más). Los bugs de
Grupos que la persona ve. Los tests rojos que frenan el gate.

**Prerrequisitos de Jürgen, en consola.** El DDL de `parentAccountID` y `CD_parentAccountID` en producción, `CD_amountChangesRaw`
en Development y Production, el DDL `g21_01` con el Worker v3, y `g22_01` con su Worker (cambiar el rol de un miembro).

**Criterio de salida.**

- La auditoría por flujos no deja ningún hallazgo abierto en 2.2.
- Grupos y Flujo de caja pasan la revisión visual de Jürgen sobre el simulador.
- Las dos tarjetas pasan su QA en el iPhone.
- «Activar la nube» con muchos movimientos termina sin cerrar la app, y la primera foto tras instalar funciona.
- Sentry está encendido en la app y en el backend.
- La cola de QA de 2.2 está vacía, y no queda ningún bug de prioridad alta en la app.

### 2.3 — Yala apunta sola

**Objetivo.** Que los gastos que el banco ya te avisa entren solos a la Bandeja, sin escribirlos, y que pasarse a Yala
desde otra app de grupos no cueste nada.

**Hitos.**

1. **Correo de alertas del banco, por reenvío.** Cada persona tiene una dirección propia de Yala y reenvía a ella las
   alertas de su banco con un filtro de su correo, que vale para Gmail, Outlook y el correo de iCloud. La app trae una guía
   paso a paso y recoge el código con el que Gmail confirma la dirección. El gateway lee el correo con IA y el movimiento
   llega a la Bandeja, por confirmar. Empieza con los bancos más usados en Perú. **Exige cuenta en la nube.** Es Pro, con
   un cupo de prueba gratis.
   **Conectar Gmail (y Outlook) con un toque**, como Pablo y Clever, llega en cuanto Google apruebe su verificación: leer
   Gmail es un permiso restringido que pide una auditoría de seguridad anual. La verificación se pide al empezar 2.3 y no
   frena la salida de 2.3.
2. **Atajo del banco, sin nube.** Una automatización de Atajos llama por detrás a una App Intent de Yala («Registrar desde
   texto»), como Apple Pay hoy, y el movimiento entra a la Bandeja por confirmar. Lo dispara la notificación de la app del
   banco (disparador nuevo de iOS 27) y, si la prueba lo confirma, el correo que llega a la app Mail. Yala lo lee en el
   iPhone, con reglas por banco y con el modelo del iPhone donde exista. **Vale con iCloud y es gratis**, porque no
   cuesta nada por uso. Incluye una guía en la app para configurarlo.
   *Prueba al empezar 2.3, en el iPhone de Jürgen:* ¿la notificación le pasa su texto al atajo? ¿El correo de Mail le
   pasa el cuerpo? (Un usuario de un foro dice que no.) ¿Funciona con el iPhone bloqueado? Según salga, el atajo cubre la
   notificación, el correo o los dos.
3. **Tu IA registra en Yala: conectores de Claude y ChatGPT.** La persona conecta Yala a su Claude o a su ChatGPT (MCP) y
   puede preguntarle por sus finanzas y pedirle que registre: «apunta 25 soles de almuerzo», o «revisa las alertas del BCP
   de esta semana en mi Gmail y regístralas en Yala». Lo segundo funciona con el Gmail que la persona ya conectó a su IA,
   sin esperar la verificación de Google. **La IA solo deja borradores en la Bandeja,** por confirmar: nunca cambia un
   registro ni un saldo. **Gratis,** porque la IA la paga la persona. Exige cuenta en la nube. Grok entra si su app acepta
   conectores al medirlo; si no, va después sin frenar 2.3. Requisito: el conector, endurecido en producción.
4. **Suscripciones y pagos recurrentes** detectados en el historial, con logos. Gratis.
5. **Gastos hormiga.** Cuánto suman al mes los gastos pequeños y frecuentes, con una regla exacta y sin IA: total y lista
   gratis. El consejo con IA («si bajas el café a tres por semana, ahorras S/ X») es Pro.
6. **Grupos como gancho de llegada.** Importar un grupo desde el export de Splitwise o Tricount, y promocionarlo en el
   lanzamiento.
   Y **repartir un recibo con IA**, que es Pro: en el grupo, «Añadir gasto» › «Desde un recibo», con una foto o con la voz.
   La IA lee las líneas y la frase («Ana comió el lomo, Luis y yo compartimos la pizza»), propone cuánto le toca a cada
   uno, y la persona mueve líneas y elige a quién se le cobra qué. Se guarda como un gasto de grupo normal, con el importe
   de cada uno: **sin las líneas ni la foto, y sin cambio de esquema**. La voz y la foto siguen las reglas de hoy: Pro, con
   el cupo de prueba de 5 y 5. Splitwise cobra el reparto por líneas en su Pro.
7. **Yala web, beta.** Para cuentas en la nube, en el navegador: ver el Panel, los registros y los saldos, y apuntar un
   gasto que llega a la Bandeja del iPhone por confirmar. Escribe por la misma vía estrecha que los conectores de IA, así
   que no toca la sincronización. Se entra con Apple o con Google. Va en **una sesión paralela**, porque no usa el
   simulador. Requisitos: el Services ID de Apple y el cliente web de Google (consolas, Jürgen), y una defensa en lugar de
   App Attest (anti-bots y límites por cuenta). La app web vive fuera de `Web/`, que es la web de marketing de Lola.
8. **Nube:** las cards de prioridad media.

**Antes del correo, y no después:** el control del coste de la IA. Hay que poner tope a la longitud de las respuestas y
guardar los tokens que gasta cada función, porque el correo multiplica las llamadas. También hay que poner al día la
política de privacidad, porque el correo pasa por el servidor.

**Lanzamiento.** Es el fuerte del roadmap: la paridad con Pablo y Clever, y el gancho de Grupos.

**Dependencias.** Un buzón de correo por persona en el backend (Cloudflare Email Routing o Workers). La cuenta en la nube.
Para conectar Gmail, la verificación de Google del proyecto `yala-502622`, con su auditoría de seguridad.

**Criterio de salida.** Con las alertas de correo de un banco peruano activadas, al menos el 90 % de los movimientos de una
semana llega a la Bandeja con el monto y el comercio bien leídos. El umbral se ajusta al medir. Un export real de Splitwise
y uno de Tricount entran como grupo con los mismos saldos. Un recibo de restaurante de cinco líneas, con una frase de
quién comió qué, queda repartido bien a la primera o con un solo ajuste. Desde Claude y desde ChatGPT, «apunta 25 soles de almuerzo» deja un borrador en la Bandeja
que se aprueba con un toque. Una cuenta en la nube entra en la web con Apple y con Google, ve el mismo saldo que en el
iPhone y un gasto apuntado en la web llega a su Bandeja. Ningún bug de nube de prioridad media queda abierto.

### 2.4 — Tu mes real

**Objetivo.** Que el Panel cuente tu mes como lo vives: de cobro a cobro, con tus ahorros, tus deudas y tus cuotas.

**Hitos.**

1. **Mes financiero:** un período nuevo en el selector, que va de día de cobro a día de cobro. Gratis.
2. **Sección de Ahorros:** las cuentas de ahorro y los depósitos a plazo juntos, con metas. Propuesto: una meta gratis e
   ilimitadas en Pro.
3. **Deudas y cuotas:** préstamos propios y compras a plazos con lo que queda por pagar. Gratis.
4. **Cuentas con presencia:** la lista de Ajustes › Cuentas, el formulario, las colecciones de cuentas y el perfil de negocio
   y personal.
5. **Presupuestos más listos:** que se adapten a los ingresos o a los gastos, recomendados con IA y con predicción del mes
   en curso.
6. **Notificaciones rediseñadas,** también dentro de la Bandeja y con IA.
7. **Grupos:** buscar gastos dentro de un grupo.
8. **Integridad de datos:** las cards de nube con riesgo de perder, duplicar o no subir datos, y las de divisas que enseñan
   como exacta una cifra aproximada.
9. **iPad y iPhone Duo,** según el ADR del 2026-09-27, y después **Yala en el Mac** como la app de iPad.
10. **Tutoriales rehechos** sobre la UX ya asentada de 2.2.
11. **Empezar con datos:** importar el último estado de cuenta desde la bienvenida, y que el CSV que exporta Yala se pueda
    volver a importar.

**Criterio de salida.** El mes financiero da en el Panel, Estadísticas, presupuestos, informes, widgets e IA el mismo total
que un cálculo a mano en los dos bordes del período: el día de cobro a las 00:00 y el día anterior a las 23:59:59. Ninguna
cifra aproximada sale sin «≈». No queda ningún bug de prioridad media ni de nube con riesgo de datos.

### 2.5 — Yala conversa

**Objetivo.** Que se pueda hablar con Yala, también fuera de la app, y que la nube quede lista para la web.

**Hitos.**

1. **Asistente por WhatsApp:** anotar con texto, voz o foto; preguntar «¿en qué gasté más?»; recibir avisos. Propuesto: Pro, con
   un cupo gratis al día.
2. **Yala IA hace más que crear registros:** consultar, explicar y resumir. Entiende Grupos, ayuda en Flujo de caja y
   contesta por voz.
3. **IA en el propio iPhone:** lo que el modelo del iPhone haga bien (clasificar, resúmenes cortos) pasa a local y gratis.
   Abarata la IA y sirve al modo privado.
4. **Manos libres y reglas en lenguaje natural:** que Yala apruebe sola la Bandeja cuando está segura, con un resumen
   diario, y reglas dichas en frases («lo menor a S/5 va a Gastos hormiga»).
5. **Rachas y mascota,** si se aprueba la mascota.
6. **Endurecimiento final de la nube:** se cierran los avisos y textos confusos que quedan.

**Dependencias del WhatsApp.** La cuenta en la nube, porque el número se asocia a una cuenta. La verificación de empresa en
Meta. El coste por conversación. El cupo del plan gratis.

**Criterio de salida.** Una persona registra, pregunta y recibe un aviso por WhatsApp sin abrir la app. No queda ninguna card
de nube de prioridad baja o más, salvo las descartadas por escrito: es la condición para empezar la web.

### 3.0 — Yala en la web

> La beta de 2.3 ya deja ver y apuntar borradores. 3.0 la completa.

**Objetivo.** Usar Yala desde cualquier navegador, con la misma cuenta y la misma suscripción.

**Por qué es mayor.** La web empieza a escribir en la sincronización. Cambia dónde viven los datos por defecto: **desde 3.0, la bienvenida propone la
nube primero**, y iCloud privado queda como alternativa clara. Y cambia el cobro: una suscripción por cuenta, pagable fuera
de la App Store.

**Hitos.**

1. La web completa, instalable como app (PWA): registrar y editar de verdad, aprobar la Bandeja y Grupos. Como app instalable llega también a los teléfonos
   Android.
2. Una suscripción por cuenta, válida en iOS y en la web, con cobro en soles.
3. La bienvenida de iOS con la nube como opción recomendada.

**Dependencias técnicas.** La nube cerrada (la salida de 2.5), porque la web pasa a escribir en la sincronización. La
entrada y la defensa sin App Attest ya llegan con la beta de 2.3. La suscripción por cuenta, hoy
latente detrás de un interruptor apagado. El procesador de pagos: aceptar Yape en la web sería una ventaja. La web de
marketing (`Web/`) es de Lola: la app web vive en otro sitio, o se acuerda con ella.

**Lanzamiento.** El segundo fuerte del roadmap.

**Criterio de salida.** Una cuenta en la nube abre la web, ve el mismo saldo que en el iPhone, registra un gasto y lo ve
llegar al iPhone. Un pago en la web activa Pro en el iPhone.

### 3.1 — Juntos (plan dúo)

**Objetivo.** Que una pareja o una familia lleve sus finanzas juntas: cuentas, metas y presupuestos compartidos, y que cada
uno vea lo suyo.

**Por qué es mayor.** Cambia quién es dueño de una cuenta: hoy cada cuenta es de una sola persona. Y abre un plan de pago
nuevo, el Pro Dúo.

**Dependencias.** La nube, las invitaciones de Grupos y un modelo de propiedad compartida en el backend. La web, porque en
Perú es muy probable que uno de los dos use Android.

**Criterio de salida.** Dos personas en dos teléfonos distintos ven el mismo saldo de una cuenta compartida y no ven las
cuentas que el otro no compartió.

### 3.2 — Yala en la muñeca

**Objetivo.** Apuntar un gasto y ver el saldo desde el Apple Watch. No necesita la nube: usa complicaciones (WidgetKit) y las
App Intents que ya existen.

### 4.0 — Yala en Android

**Objetivo.** Yala nativa en Android, con la misma cuenta y la misma suscripción.

**Fase 0.** Antes de escribir la app se decide el lenguaje, con una prueba corta de cada opción: Kotlin con Jetpack Compose,
o compartir la lógica de Swift en Android.

**Dependencias.** Todo lo de 3.0, más el equivalente de App Attest (Play Integrity), los avisos push propios (FCM) y el cobro
de Google Play con la suscripción por cuenta.

**Dónde superar a la competencia.** Android deja que una app lea las notificaciones de otras, con el permiso de la persona.
Yala podría apuntar sola cada aviso de la app del banco, sin correo ni Atajos.

### Más allá de 4.0 (ideas nuevas, sin card)

- **Finanzas abiertas:** conectar los bancos cuando Perú tenga un marco regulado para eso. No está verificado en qué punto
  está esa regulación.
- **Impuestos:** Quipuk (Perú) junta finanzas personales y la declaración anual. Encaja con el perfil de negocio de 2.4.

## Lo que sigue abierto

No bloquea el roadmap. Cada punto se decide al planificar la versión que lo necesita.

- **Pro de 2.4 en adelante:** las filas de la tabla del eje 6 son propuesta. Los precios no están fijados.
- **Las preguntas a Siri con IA** («cuánto gasté», «mi saldo»): ¿gratis o Pro? Anotar con Siri ya es gratis.
- **La mascota:** se decide en 2.3, y de eso dependen las rachas y la mascota de 2.5.
- **El lenguaje de Android:** en la fase 0 de 4.0.

---

## Los seis ejes, cruzados con las versiones

### Eje 1 · Mejoras de UI y de UX

| Versión | Qué |
|---|---|
| 2.2 | La auditoría UX completa. Grupos y Flujo de caja con el diseño nuevo. Contraste AA en temas oscuros y de color. Textos en 16 idiomas (pt-BR, pt-PT, francés, es-419). Transición más cuidada en la entrada. Onda de voz en vivo. |
| 2.3 | Decisión sobre la mascota. |
| 2.4 | Tutoriales rehechos desde cero. iPad con barra lateral y lista y detalle; iPhone Duo. Cuentas con presencia propia en la app. Pase de estrés de accesibilidad: texto grande y VoiceOver con importes. |
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
| **Importar** | PDF de estados de cuenta (también con contraseña), CSV y Excel; capturas de Yape y Plin y fotos de recibos. | Proponerlo en la bienvenida; que el CSV exportado se pueda volver a importar. | 2.4 |
| **Presupuestos** | Límite fijo. | Que se adapten a los ingresos y se recomienden con IA. | 2.4 |
| **Yala IA** | Chat que sobre todo crea registros. | Consultar, explicar y resumir; Grupos; respuestas por voz. | 2.5 |

**Gastos hormiga, las dos dudas de Jürgen:**

- **¿Usa IA?** Para detectarlos, **no hace falta**. Basta una regla: monto por debajo de un umbral (Clever usa S/5),
  frecuencia en el mes y el mismo comercio o subcategoría. Es exacta, gratis por uso y se explica sola. La IA sirve para lo
  que va después: el consejo («si bajas el café a tres por semana, ahorras S/ X al mes»).
- **¿Es solo Pro?** Se propone **ver el total y la lista gratis**, porque Pablo y Clever lo dan a todos y la ficha ya lo
  promete. El consejo con IA y las alertas serían Pro.

**Decidido el 21-oct:** el total y la lista, gratis; el consejo con IA, Pro.

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
| Reglas por chat, manos libres | — | Según las cards, sí | No | 2.5 | — |
| Proyección de fin de mes | — | Sí | Flujo de caja proyectado | Ya existe | Mejor: el plan por línea, a varios meses. |
| Web | Sí | Sí (panel web) | No | 2.3 (beta) · 3.0 (completa) | — |
| Android | Sí | No consta | No | 4.0 (antes, la web instalable) | — |
| Aviso antes de cobrar la prueba | — | Sí (3 días antes) | No consta | 2.3 | — |
| Precio | Premium desde S/20 al mes; gratis con 5 mensajes al día, 3 cuentas, 1 moneda y 1 meta | US$5.90 al mes o US$35.90 al año, con 14 días de prueba | — | — | — |

**Dónde Yala ya es mejor:** Grupos integrado con las finanzas personales (ninguno de los dos lo tiene); 54 divisas y una
tarjeta con varias; el flujo de caja proyectado; Siri, Apple Pay y widgets; 16 idiomas; la lectura de capturas de Yape y
Plin, de fotos de recibos y de PDF de estados de cuenta, que ya existe.

**Qué igualar primero, en orden:** (1) el correo del banco y los gastos hormiga, en 2.3, porque es lo que la persona ve el
primer día y la ficha ya lo promete; (2) las metas, en 2.4; (3) WhatsApp y las rachas, en 2.5; (4) la web, con una beta en 2.3 y completa en 3.0.

**Otras apps de la región** (conocimiento general, no verificado hoy): Fintonic (conecta bancos en España y Chile), Mobills
(Brasil), y Splitwise y Tricount para gastos de grupo, de donde Yala importa en 2.3 (decidido el 21-oct: Grupos como gancho de llegada).

### Eje 5 · Formatos y plataformas nuevos

| Formato | Versión | Dependencias técnicas |
|---|---|---|
| Widgets | 2.2 (extragrande) · 2.3 (widget interactivo para apuntar con un toque; idea nueva) · 2.4 (metas y mes financiero) | Las App Intents ya existen. El widget lee de su copia en el App Group. |
| iPad y iPhone Duo | 2.4 | El ADR del 2026-09-27 y el runtime de iOS 27.1 en la Mac. |
| Mac | 2.4 (idea nueva) | La app de iPad en Mac con Apple Silicon, cuando el iPad ya sea adaptativo. Una app de Mac nativa no compensa: la web de 3.0 cubre la computadora. |
| Web | **2.3** (beta: ver y borradores) · **3.0** (completa) | Beta: cuenta en la web (Apple y Google), defensa en lugar de App Attest. Completa: nube endurecida, suscripción por cuenta. |
| Plan dúo | **3.1** | Nube, propiedad compartida en el backend, invitaciones de Grupos. |
| Apple Watch | 3.2 | Complicaciones con WidgetKit y App Intents. No necesita la nube. |
| Android | **4.0** | Todo lo de la web, Play Integrity, FCM, Google Play Billing y la decisión del lenguaje. |

### Eje 6 · Qué entra en Pro en cada versión

| Versión | Pro gana | Sigue gratis |
|---|---|---|
| Hoy (2.1) | Voz y foto (5 y 5 de prueba en gratis), chat de Yala IA, análisis con IA, temas e iconos, flujo de caja avanzado, más de 4 cuentas, más de 3 presupuestos, registrar con Siri. | Lo demás. |
| 2.2 | Nada nuevo. Se arregla cómo se explica Pro: paywall con ejemplos, vista previa de temas, «1 mes gratis» en lugar de «30 días». **Decisión:** las preguntas a Siri con IA, ¿gratis o Pro? | Tarjeta multidivisa y fecha de corte. |
| 2.3 (decidido) | El correo del banco leído en el servidor, con un cupo de prueba. El consejo con IA sobre gastos hormiga. Repartir un recibo con IA en Grupos. | **El atajo del banco** (notificación y correo de Mail, leídos en el iPhone). **Los conectores de Claude y ChatGPT**, también para registrar. El total y la lista de gastos hormiga. Suscripciones detectadas. Importar. |
| 2.4 | Metas ilimitadas (1 gratis, como Pablo). Presupuestos con IA. Perfiles de negocio y personal. Notificaciones con IA. | Mes financiero, cuotas, deudas, la sección de Ahorros. |
| 2.5 | WhatsApp (con un cupo gratis al día, como Pablo). Yala IA ampliada y respuestas por voz. Manos libres y reglas en lenguaje natural. | Rachas y mascota. Accesorios de la mascota como cosmética Pro (idea nueva). |
| 3.0 | Una sola suscripción por cuenta en iOS y la web, con precio en soles. | — |
| 3.1 | **Pro Dúo** (idea nueva): un plan para dos cuentas, con precio por decidir. | — |
| 4.0 | La misma suscripción, pagable también en Google Play. | — |

Solo la fila de 2.3 está decidida (21-oct); las de 2.4 en adelante son propuesta y se deciden al planificar cada
versión. Los precios de Yala no se fijan aquí. Como referencia: Pablo cobra desde S/20 al mes y Clever US$5.90 al mes.

### Los ejes por versión, de un vistazo

| Eje | 2.2 | 2.3 | 2.4 | 2.5 | 3.0 | 3.1 | 4.0 |
|---|---|---|---|---|---|---|---|
| UI y UX | Auditoría y coherencia | Bandeja que se llena sola | Tutoriales, iPad, Duo, cuentas, accesibilidad | Rachas, mascota | Diseño en la web | — | Diseño en Android |
| Funciones existentes | Tarjeta de crédito | Pagos planificados | Período, ahorros, presupuestos, importar | IA | — | — | — |
| Secciones nuevas | — | Suscripciones, comercios | Ahorros, deudas, perfiles | WhatsApp | — | Compartido | — |
| Competencia | Fecha de corte | Correo, gastos hormiga, Splitwise, tu IA registra | Metas | WhatsApp, rachas | Web | Cuentas compartidas | Android |
| Plataformas | Widget extragrande | Claude y ChatGPT, web beta, widget interactivo | iPad, Duo, Mac (app de iPad) | — | Web | — | Android |
| Pro | Explicarlo mejor | Captura automática | Metas, IA en presupuestos | WhatsApp, IA ampliada | Suscripción por cuenta | Pro Dúo | Google Play |

---
