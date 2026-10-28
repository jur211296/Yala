# Live Activities en Yala: qué se puede y cómo se corta (2.4)

2026-10-28 · Frank · card `tablero-live-activities-presencia-en-pantalla-de-hi45`

Ideas de Jürgen (1:1 del 2026-10-28): cuando hoy saldría una notificación estática, Yala abre
primero una Live Activity (pantalla de bloqueo + isla dinámica) durante unos 5 minutos, con
animación; si nadie la toca, cae a la notificación de siempre.

## Veredicto corto

| Caso | ¿Se puede? | En una frase |
|---|---|---|
| 1. Después de un pago con Apple Pay | **Sí** la presencia; **parcial** las acciones | La tarjeta «Registramos tu gasto» con el importe y lo que falta, y el toque a la Bandeja, sí. Elegir cuenta o categoría con un selector, no: solo caben botones. |
| 2. Umbral de presupuesto | **Sí** | Nombre y barra que se llena, unos 5 minutos, y luego la notificación de siempre. |
| 3. Pago planificado | **Parcial, con buena pinta** | Marcar como pagado con un botón, sí. Que aparezca sola el día del pago depende de una API nueva de iOS 26 que hay que confirmar en el iPhone. |
| 4. Registro por voz en curso | **Parcial** | «Escuchando… 0:12» con Listo y Cancelar en la isla, sí. La onda que sigue tu voz en vivo, no: la isla no se repinta tan rápido. |

Recomendación: **cinco tickets**, no uno. El primero monta la base y entrega Apple Pay; los
demás van detrás, y ninguno depende de los otros salvo de esa base.

## Qué manda la plataforma

Medido en el repo:

- Yala exige iOS 26.0 en todos sus targets. Todas las APIs de abajo existen ya ahí; no hace
  falta comprobar versiones dentro del código.
- Hoy no hay ActivityKit en ningún sitio. La extensión `YalaWidgets` (widgets y controles) es la
  que pintaría la Live Activity; no hace falta un target nuevo.
- El gateway ya manda pushes por APNs (los de Grupos). Sirve para un plan B, no para el plan A.

Lo que dice Apple (documentación y WWDC; lo marcado *por confirmar* no lo he visto en la
referencia de la API, solo en la sesión de WWDC26 y en un SDK de terceros):

1. **Cuándo puede nacer una Live Activity.** Con la app delante, siempre. Con la app detrás, solo
   por tres caminos: un push del servidor (push-to-start), un App Intent que adopte
   `LiveActivityIntent`, o *(por confirmar)* una Live Activity **programada** con la app delante
   para que arranque sola a una hora (iOS 26). Una tarea en segundo plano cualquiera, o una
   notificación local programada, **no** la pueden abrir.
2. **Qué se toca dentro.** Solo `Button` y `Toggle`, cada uno con un App Intent. Nada de
   selectores, menús, campos de texto ni listas que se desplacen. El intent corre en el proceso
   de la app, en segundo plano, y debe acabar en un segundo o poco más.
3. **Tocar la tarjeta** fuera de los botones abre la app en el enlace que se elija (la Bandeja,
   por ejemplo). Eso funciona igual que el toque de la notificación de hoy.
4. **Cuánto vive.** Hasta 8 horas activa y 4 más en pantalla de bloqueo. Para que dure **5
   minutos** no hay temporizador del sistema que la apague: se termina nada más crearla con
   «quítala a los 5 minutos» (`dismissalPolicy: .after`) o se le pone fecha de caducidad
   (`staleDate`), y la notificación de respaldo se deja programada a los 5 minutos y se cancela
   si el usuario la usó antes. El matiz: una Live Activity ya terminada sigue en la pantalla de
   bloqueo pero **sale de la isla**. Qué combinación queda mejor se decide en el iPhone.
5. **Animación.** La tarjeta no corre código: anima al cambiar de estado (la barra que se llena) y
   con relojes y barras de tiempo que lleva el propio sistema. No hay animación continua propia.
6. **Tamaño.** Unos 160 puntos de alto en pantalla de bloqueo; en la isla, la vista compacta es
   un icono y una cifra. El estado viaja en 4 KB.
7. **El usuario manda.** Puede apagar las Live Activities de Yala en Ajustes. Entonces cada caso
   cae a la notificación de hoy, sin más.
8. **Con la app abierta la isla no enseña la Live Activity de Yala.** Se ve al salir o con el
   iPhone bloqueado.
9. **App Store.** Hay que declarar `NSSupportsLiveActivities` en el `Info.plist`. Apple no deja
   usarlas para publicidad; ninguno de los cuatro casos lo es. Grabar audio con la app en segundo
   plano pide declarar ese modo y justificarlo en la revisión (caso 4).

## Caso por caso

### 1. Después de un pago con Apple Pay — sí, con las acciones en parcial

Hoy: la automatización de Wallet lanza `ApplePayTransactionIntent` **sin abrir la app**. El intent
no toca la base de datos: deja el pago en una cola compartida y avisa con una notificación; la app
convierte esa cola en un borrador de la Bandeja la próxima vez que se abre.

- **Presencia («Registramos tu gasto», importe, comercio, qué falta): sí**, siempre que el intent
  pueda abrirla desde segundo plano adoptando `LiveActivityIntent`. Apple lo describe así, pero en
  los foros hay quien recibe un error de visibilidad al lanzarlo desde Siri con otra Live
  Activity viva. **Primera tarea del ticket: probarlo en el iPhone** (el simulador no ejecuta
  automatizaciones de Wallet). Si falla, se queda la notificación de hoy y el resto del ticket no
  se hace.
- **Chevron y toque a la Bandeja: sí.** Mismo destino que la notificación.
- **Elegir cuenta o subcategoría desde la tarjeta: no** como selector. **Parcial** como botones:
  dos o tres sugerencias (la última cuenta usada con Apple Pay, la categoría más probable) y un
  «Guardar». Para que «Guardar» funcione con la app cerrada, el botón tendría que crear el
  registro de verdad desde segundo plano, cosa que el diseño de hoy evita a propósito. Por eso va
  en un ticket aparte, detrás.

### 2. Umbral de presupuesto — sí

Hoy: la comprobación corre al guardar un registro o aprobar un borrador, y al arrancar la app. La
app está delante en los tres casos, así que la Live Activity nace sin trucos.

- Nombre del presupuesto, porcentaje y barra que se llena hasta el umbral: sí.
- 5 minutos y luego notificación de siempre: sí, con el mecanismo del punto 4 de arriba.
- Matiz: como el usuario está dentro de Yala cuando se cruza el umbral, la isla no la enseña hasta
  que sale. La notificación de hoy sí se ve dentro. Hay que decidir en el ticket si se lanzan las
  dos o solo la Live Activity.

### 3. Pago planificado — parcial, probablemente sí

Hoy: los avisos del día se dejan programados como notificaciones locales; la app no está viva a
esa hora.

- **Marcar como pagado desde la tarjeta: sí**, un botón con su App Intent, como el «Valorar» del
  ejemplo de Apple.
- **Que aparezca sola el día del pago: depende de la Live Activity programada de iOS 26** (por
  confirmar en la API). Si existe como Apple la presentó, la app la deja programada al abrirse,
  igual que hoy deja programadas las notificaciones del día. Si no, solo nace cuando el usuario
  abre Yala ese día, y eso le quita casi todo el valor; el plan B sería el push del gateway, que
  obliga al servidor a conocer las fechas de pago de cada usuario. Ese plan B **no** se toma sin
  Jürgen.
- «Probar» (abrir el pago para revisarlo): sí, con el toque a la tarjeta.

### 4. Registro por voz en curso — parcial

Hoy: el control del Centro de control, el Atajo y el botón de la pantalla de bloqueo abren Yala y
la hoja de voz ya escucha. No hay grabación con la app en segundo plano.

- **Live Activity mientras graba («Escuchando…», tiempo que corre, Listo y Cancelar): sí.** Nace
  con la app delante, que es como se abre hoy.
- **Que siga grabando al salir de Yala o bloquear el iPhone:** pide declarar audio en segundo plano
  y justificarlo ante Apple. Es lo que hacen las apps de notas de voz; es viable pero añade riesgo
  de revisión y toca la sesión de audio.
- **La onda que sigue la voz: no.** La tarjeta no se repinta a ese ritmo. Sí cabe un indicador que
  late o el reloj que corre.
- Es el caso con más riesgo y menos urgencia; va el último.

## Tickets propuestos (2.4)

| # | Ticket | Depende de | Orden |
|---|---|---|---|
| 1 | `live-activity-base-and-apple-pay-presence` — Tras Apple Pay, la pantalla de bloqueo dice «Registramos tu gasto» | — | 1.º |
| 2 | `budget-threshold-live-activity` — Al llegar al umbral de un presupuesto, su barra en la pantalla de bloqueo | 1 | 2.º |
| 3 | `scheduled-payment-live-activity` — El día de un pago planificado, marcarlo pagado desde la pantalla de bloqueo | 1 | 2.º |
| 4 | `apple-pay-live-activity-inline-actions` — Completar y guardar el gasto de Apple Pay sin abrir Yala | 1 | 3.º |
| 5 | `voice-entry-live-activity` — El registro por voz sigue en la isla al salir de Yala | 1 | 4.º |

Los tickets 2 y 3 pueden ir a la vez. El 4 espera a que el 1 lleve un tiempo en manos de usuarios:
si la tarjeta sola ya resuelve, sobra.

Por qué cinco y no uno: cada caso se prueba de forma distinta en el iPhone, el 1 tiene un «sí o
no» que hay que medir antes de seguir, y el 4 y el 5 llevan riesgos (escribir desde segundo plano;
revisión de Apple) que no deben frenar a los otros.

## Lo que queda por medir

Todo esto sale de documentación; nada se ha probado en un iPhone. Los tres puntos que pueden
cambiar el veredicto, y en qué ticket se miden:

1. Abrir la Live Activity desde el intent de Apple Pay con la app cerrada → ticket 1.
2. Si la Live Activity programada de iOS 26 existe y cómo se llama → ticket 3.
3. Qué se ve mejor a los 5 minutos: terminada (sale de la isla) o caducada (se queda gris) → ticket 1.
