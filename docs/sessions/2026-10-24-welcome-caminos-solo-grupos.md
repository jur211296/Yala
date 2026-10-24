---
updated: 2026-10-24
tags: [sesion, welcome, onboarding, grupos, estudio]
estado: abierto — espera la elección de Jürgen (card dq2g)
---

# Welcome y onboarding: el camino de quien viene solo por grupos

> Estudio de la card `dq2g`, antes del barrido de QA 2.2. **Solo análisis y propuestas**: no cambia código.
> El mapa está medido contra el código de `2.2` (`ee2d4e502`) y las capturas del «antes» salen del simulador
> (iPhone 17 Pro, iOS 27.0, Yala Dev). Las maquetas de las propuestas están en el lienzo enlazado abajo.

## En tres frases

1. Quien baja Yala para reemplazar Splitwise **no se reconoce en «Vengo por un grupo»**: el título suena a «me
   trajo una invitación», así que elige «Es mi primera vez».
2. «Es mi primera vez» **no tiene salida a grupos**: pregunta dónde guardar sus finanzas, le hace el onboarding
   personal de 7 pasos y lo deja en el Panel, con Grupos escondido en «Más». Son ~16 pantallas hasta su primer
   grupo, contra 6 por el camino de grupos.
3. Y quien sí entra por grupos **tiene que crear un grupo para quedarse**: cerrar el formulario lo devuelve al
   Welcome. No hay forma de entrar a solo grupos «a mirar» o a esperar un enlace.

## Material

- **Maquetas de las propuestas y capturas en un lienzo**: https://claude.ai/artifact/WjbNnX5xHjWpH5DsF8oZED
- **Capturas del «antes»** (simulador, 2.2), en `_shots/2026-10-24-welcome-solo-grupos/`:

| Captura | Qué enseña |
|---|---|
| `antes-01-hero` | Hero: «Tus finanzas personales, sin esfuerzo» |
| `antes-02-chooser` | El elector: «Vengo por un grupo» |
| `antes-03-vengo-por-un-grupo` | «¿Cómo empiezas con tu grupo?» |
| `antes-04-crear-educativo` | «Grupos en la nube» (qué se guarda; aceptar) |
| `antes-05-crear-inicio-de-sesion` | «Conecta tu cuenta» |
| `antes-06-crear-cancelar-inicio-de-sesion` | Cancelar el inicio de sesión → vuelta al 2.º nivel |
| `antes-07-crear-formulario-primer-grupo` | «Nuevo grupo» con «Tu nombre en el grupo» |
| `antes-08-crear-cerrar-formulario` | Cerrar el formulario sin crear → vuelta al 2.º nivel |
| `antes-09-tengo-una-invitacion` | «Pega tu enlace de invitación» (el aviso del teclado es del simulador) |
| `antes-10-primera-vez-donde-guardar` | «Es mi primera vez»: nube o iCloud privado |
| `antes-11-ya-tengo-cuenta` | «¡Hola de nuevo!», con la pregunta de pie que copia la propuesta B |
| `antes-12-onboarding-nombre` | Onboarding personal, paso 1 de 7 |
| `antes-13-onboarding-proposito` | Paso 2 de 7: dos propósitos, sin grupos |
| `antes-14-app-completa-grupos-sin-cuenta` | Grupos en la app completa: «Tu primer grupo, en tres pasos» |
| `antes-15-solo-grupos-destino` | La sesión de solo grupos con grupos (destino) |

## 1. Mapa de caminos (hoy)

Los nombres de pantalla son los títulos que ve la persona.

| # | Camino | Qué ve | Dónde acaba | Pantallas hasta el 1.er grupo |
|---|---|---|---|---|
| 0 | **Primera apertura** | Hero «Tus finanzas personales, *sin esfuerzo*» + carrusel de 8 tarjetas (una es «Gastos compartidos») → «¡Hola! ¿Qué quieres hacer en Yala?» con 3 filas | El elector | — |
| 1 | **Es mi primera vez** | «Elige dónde quieres guardar tus datos»: *Tu cuenta en la nube* / *Tu cuenta en tu iCloud privado* | Onboarding personal → Panel | ~16 (ver 1a) |
| 1a | ↳ iCloud privado | Puerta que pregunta a iCloud si hay datos (y puede pedir reabrir la app) → onboarding: nombre · propósito (*Llevar el control* / *Solo anotar gastos*) · cuentas · moneda · saldo · categorías · resumen → Panel | Panel. La barra trae Panel, Estadísticas y Planificación; **Grupos está en «Más»** | Más → Grupos («Tu primer grupo, en tres pasos»: crea tu cuenta · acepta cómo se guardan · ponle nombre e invita) → «Grupos en la nube» → «Conecta tu cuenta» (Apple/Google) → formulario del grupo |
| 1b | ↳ Nube | Consentimiento + entrar con Apple/Google → mismo onboarding personal → Panel | Panel | Igual que 1a, sin volver a iniciar sesión |
| 1c | ↳ Faro (este Apple ID ya tiene cuenta nube) | Encamina a «entrar con tu cuenta», con «Crear otra cuenta» | Su cuenta | — |
| 2 | **Ya tengo una cuenta** | «¡Hola de nuevo!»: Restaurar desde iCloud · Entrar con Apple · Entrar con Google | Su app (completa o solo grupos, según la cuenta) | — |
| 3 | **Vengo por un grupo** | «¿Cómo empiezas con tu grupo?»: *Crear mi primer grupo* / *Tengo una invitación* | — | — |
| 3a | ↳ Crear mi primer grupo | Puerta (canal de grupos encendido; si el teléfono tiene datos personales, los sube a iCloud y lo deja en blanco) → «Grupos en la nube» (qué se guarda y dónde; *Aceptar y continuar* / *Ahora no*) → «Conecta tu cuenta» (Apple/Google) → «Nuevo grupo» con «Tu nombre en el grupo» → Grupos + hoja para invitar | Sesión **solo grupos** con un grupo (barra: Grupos · Más · Buscar) | **6** |
| 3b | ↳ Tengo una invitación | «Pega tu enlace de invitación» | El grupo de la invitación (sesión solo grupos) | — |
| 4 | **Enlace de invitación** (desde WhatsApp, etc.) | «Abriendo tu invitación…» sin pasar por el elector → mismo alta que 3a, terminando en *unirse* | El grupo | — |
| 5 | **Solo grupos sin grupo ni enlace** | **No existe.** En 3a, cerrar el formulario (o cancelar el inicio de sesión) devuelve al elector de grupos | — | — |

**Nube vs iCloud en estos caminos.** Los grupos viven siempre en la cuenta de Yala (Apple/Google), por cualquier
camino. La pregunta nube/iCloud solo aparece en «Es mi primera vez» y habla de los datos **personales**: para
quien solo quiere grupos es una pregunta que no le toca, y es la primera que se encuentra.

**Historia que importa para las propuestas.** Hasta el 2026-09-10 el paso Propósito del onboarding tenía una
tercera tarjeta, «Dividir gastos con amigos · Viajes, cenas y cuentas compartidas», que llevaba a solo grupos y
aterrizaba en la pestaña Grupos lista para crear o invitar, **sin obligar a crear un grupo** (`182c326a6`). Se
retiró en el rediseño de sesiones (ADR 2026-09-09 §7: «solo-grupos es una sesión que se abre desde el Welcome,
no un propósito de quien ya eligió llevar sus finanzas personales», `403d3057c`). El motivo técnico: estaba
**después** de elegir dónde viven los datos personales (y de una posible reapertura), así que mezclaba las dos
sesiones.

## 2. Dónde se pierde quien viene por Splitwise sin enlace

- **H1 · La primera pantalla le habla a otra persona.** El Hero dice «Tus finanzas personales, sin esfuerzo».
  Los grupos aparecen como una tarjeta de ocho en el carrusel.
- **H2 · El título «Vengo por un grupo» se lee como invitación.** La descripción sí dice «crear un grupo o
  unirme a uno», pero quien escanea lee el título. Alguien que quiere *organizar* gastos con amigos no «viene
  por» un grupo: no hay grupo todavía.
- **H3 · «Es mi primera vez» es el camino natural de cualquiera que es nuevo, y es un callejón para él.** Su
  primera pregunta es dónde guardar sus finanzas personales; no hay ninguna salida a grupos en todo el recorrido.
- **H4 · El rodeo cuesta ~16 pantallas** (3 de elección + puerta de iCloud + 7 de onboarding + Más + Grupos +
  3 de alta) contra 6, y le hace contestar saldo, cuentas y categorías que no va a usar.
- **H5 · Al terminar, Grupos ni siquiera está en la barra.** La barra por defecto es Panel · Estadísticas ·
  Planificación; Grupos vive en «Más» (solo aparece en la barra mientras está abierta).
- **H6 · Por el camino bueno, crear un grupo es obligatorio para quedarse.** Si cierra el formulario —porque
  aún no sabe cómo llamar al grupo, o porque espera que un amigo lo invite— vuelve al elector de grupos del
  Welcome. La sesión que abrió se queda, pero para entrar tiene que volver a «Crear mi primer grupo» y crearlo.
- **H7 · Sin enlace a mano, «Tengo una invitación» es un callejón.** Pide pegar el enlace; si el amigo aún no lo
  mandó, solo queda volver. Y dentro de Grupos no hay sitio para pegar un enlace: depende de abrirlo desde el
  mensaje.

## 3. Propuestas

Las tres se pueden combinar: A es copy y casi gratis; B y C atacan problemas distintos (B, el que entra por
la puerta equivocada; C, el que entra por la buena y no quiere crear todavía). Las maquetas usan el mismo
lienzo del Welcome (`WelcomeFormScreen`: titular serif y filas en una tarjeta).

### A · Solo copy: que la tarjeta de grupos se reconozca

**Qué cambia.** Los textos del elector y del 2.º nivel de grupos. Ni un paso nuevo.

| Dónde | Hoy | Propuesta |
|---|---|---|
| Elector, título de la fila | Vengo por un grupo | **Dividir gastos con amigos** |
| Elector, descripción | Quiero dividir gastos con amigos: crear un grupo o unirme a uno. | **Viajes, depa, salidas: crea un grupo o entra al de tus amigos. Sin llevar tus finanzas.** |
| 2.º nivel, título | ¿Cómo empiezas con tu grupo? | ¿Cómo empiezas? |
| 2.º nivel, fila crear | Crear mi primer grupo · Invitas tú. Registras lo que pagan todos y Yala lleva las cuentas. | (igual) |
| 2.º nivel, fila unirse | Tengo una invitación · Pega el enlace que te enviaron y entras al grupo. | **Me invitaron a un grupo** · Abre el enlace que te mandaron, o pégalo aquí. |

Alternativas de título para elegir: «Dividir gastos con amigos» (la de la tarjeta retirada, ya traducida a 16
idiomas en el historial) · «Solo grupos, como Splitwise» (más claro, pero nombra una marca ajena en la app) ·
«Cuentas compartidas».

- **Alcance:** 3-4 claves × 16 idiomas; ningún fichero de lógica. Los XCUITest van por identificador, no por
  texto: no se rompen.
- **Riesgo:** bajo. No arregla H3-H6: quien igualmente toque «Es mi primera vez» sigue sin salida.
- **«Sin llevar tus finanzas»** es la frase que separa a esta fila de «Es mi primera vez»; si se lee rara,
  la alternativa es «Solo para los gastos compartidos».

### B · Una salida a grupos dentro de «Es mi primera vez»

**Qué cambia.** El 2.º nivel de «Es mi primera vez» («Elige dónde quieres guardar tus datos») gana una
**pregunta de pie** —el mismo patrón que ya usa «¡Hola de nuevo!» con «¿Es tu primera vez en Yala? Empieza
aquí»—:

> ¿Solo vienes a dividir gastos? **Empieza por aquí**

que lleva al mismo camino 3a (o al 2.º nivel de grupos, si se combina con C). Es la tarjeta retirada en
septiembre, pero **antes** de elegir dónde viven los datos personales: así no contradice el §7 (solo grupos se
sigue abriendo desde el Welcome) ni mezcla las dos sesiones, que era el motivo técnico de retirarla.

- **Por qué la pregunta de pie y no una tercera fila:** la tarjeta contesta «¿dónde guardo mis datos?», y
  «solo grupos» no es una respuesta a esa pregunta. Una tercera fila la convertiría en otra cosa.
- **Alcance:** 2 claves × 16 idiomas; un callback más en `WelcomeNewChooserView` que reusa el destino que ya
  existe (`.groupsGate(purpose: .createGroup)`); el «Volver» de esa puerta tiene que volver a «Es mi primera
  vez», no al elector de grupos. 1 XCUITest nuevo.
- **Riesgo:** bajo-medio. Toca un flujo vivo con faro y bypass: con el faro encendido o con una sola opción
  visible (sin App Attest, percent en 0), «Es mi primera vez» **no enseña** esa pantalla, así que la salida
  no se vería. Hay que decidir si en esos casos también se ofrece (en el aviso del faro, por ejemplo) o se acepta.
- **Variante B2 (más visible):** la pregunta de pie también en el elector principal, bajo las tres filas. Se
  descarta como primera opción: duplica la fila de grupos en la misma pantalla.

### C · «Solo grupos» abierto: entrar sin crear grupo y sin enlace

**Qué cambia.** El 2.º nivel de grupos pasa de dos caminos obligatorios a una entrada que termina **dentro**
de Grupos, con el grupo como primera acción y no como requisito:

> **¿Cómo empiezas?**
> · **Entrar a Grupos** — Inicia sesión y crea tu grupo cuando quieras. Si te invitan, el enlace te lleva directo.
> · Tengo un enlace de invitación — Pégalo y entras al grupo.

Recorrido de «Entrar a Grupos»: puerta → «Grupos en la nube» → «Conecta tu cuenta» → **tu nombre** (una
pantalla, como la de antes de L12-12) → pestaña Grupos vacía con «Crear grupo» y una línea nueva «¿Te invitaron?
Abre el enlace desde el mensaje o pégalo aquí». Cerrar ahí ya no devuelve al Welcome: la persona está en su
sesión de solo grupos.

- **Alcance:** medio-grande. El alta de solo grupos (`GroupsOrganizerOnboarding.completeSetup`, el trío nombre
  + modo + onboarding completo) hoy vive **dentro** del formulario del grupo (L12-12, decisión B de Jürgen); C
  la saca a su propia pantalla o la mueve al primer «crear/unirse». Más: estado vacío de Grupos con la entrada
  de enlace (hoy no existe en la pestaña), copy × 16 idiomas, tests de la cadena (`GroupsGateLogic`) y
  XCUITest del recorrido.
- **Riesgos:** (1) deshace en parte L12-12, que juntó nombre y grupo para no pedir dos formularios; (2) una
  sesión solo grupos **vacía** es un estado nuevo: avisos, «Activar Yala completo» y el cierre de sesión
  tienen que estar bien con cero grupos (medir antes); (3) review adversarial obligatoria: toca la cadena de
  alta y la sesión.
- **Variante C2 (más barata):** mantener los dos caminos y solo cambiar qué hace **cerrar el formulario** en
  3a: en vez de volver al Welcome, completar el alta con el nombre ya escrito y aterrizar en Grupos vacío. Si el
  nombre está vacío, se pregunta en una línea. Arregla H6 sin tocar el 2.º nivel.

## 4. Comparativa

| | A · copy | B · salida en «primera vez» | C · solo grupos abierto | C2 · cerrar = quedarse |
|---|---|---|---|---|
| Arregla | H2 | H3, H4, H5 | H6, H7 | H6 |
| Toca lógica | No | Un destino nuevo en el Welcome | Cadena de alta y sesión | Un `onDismiss` y el alta |
| Claves × idiomas | 3-4 × 16 | 2 × 16 | ~8 × 16 | ~2 × 16 |
| Riesgo | Bajo | Bajo-medio | Medio-alto | Medio |
| Review adversarial | No | No | Sí | Sí (alta) |

**Recomendación de Frank:** **A + B** en 2.2, juntos (copy + una salida en el sitio por donde de verdad entra
quien se equivoca), y **C2** como card aparte si te convence que cerrar el formulario no te eche del recorrido.
C entero tiene sentido si el producto quiere que «solo grupos» sea una app que se abre vacía, como Splitwise;
es la que más se parece a lo que hace la competencia, y la que más cuesta.

## 5. Qué decides tú

1. ¿Qué combinación: A, A+B, A+B+C2, o C?
2. Si hay A: ¿qué título para la fila de grupos? («Dividir gastos con amigos» es el recomendado.)
3. Si hay B: con el faro encendido o sin la elección nube, la salida no se ve. ¿Se acepta, o se ofrece también ahí?

## Fuera de este estudio

- Pasar de la app completa a solo grupos (`p0iu`): es otra card y no se toca aquí.
- El Hero (H1) es también la cara de la ficha de la App Store, que es de Lola: si se cambia su titular, que lo
  coordine con marketing.
