---
esfuerzo: high
---
# Welcome solo-grupos: A+B (copy + salida en «Es mi primera vez»)

**Card:** `tablero-welcome-solo-grupos-a-b-copy-salida-en-p-jyhh` · Yala 2.2 · high · cierre cierra-sola  
**Decisión Jürgen 24-oct 09:59 Lima:** A+B; título «Dividir gastos con amigos»; con faro o sin elección de nube, la salida B **no sale** (aceptado). C2 va en otra sesión/card (`…-ycke`); no la implementes aquí.

## Fuentes (léelas)
- Estudio: `~/Claude/entregas/Yala--estudio-welcome-onboarding-solo-grupos/2026-10-24-welcome-caminos-solo-grupos.md` (secciones A y B).
- Lienzo: https://claude.ai/artifact/WjbNnX5xHjWpH5DsF8oZED
- PR estudio (docs): https://github.com/jur211296/Yala/pull/616
- Capturas del antes: `~/Claude/worktrees/_capturas/2026-10-24-estudio-welcome-onboarding-solo-grupos/`

## Qué se pide

### A · Copy del camino de grupos
En el elector del Welcome (`WelcomeFormScreen` / filas):

| Dónde | Hoy | Nuevo |
|---|---|---|
| Elector, título de la fila | Vengo por un grupo | **Dividir gastos con amigos** |
| Elector, descripción | Quiero dividir gastos con amigos: crear un grupo o unirme a uno. | **Viajes, depa, salidas: crea un grupo o entra al de tus amigos. Sin llevar tus finanzas.** |
| 2.º nivel, título | ¿Cómo empiezas con tu grupo? | **¿Cómo empiezas?** |
| 2.º nivel, fila unirse | Tengo una invitación · … | **Me invitaron a un grupo** · Abre el enlace que te mandaron, o pégalo aquí. |
| 2.º nivel, fila crear | (igual) | (igual) |

Claves × 16 idiomas (es-AR con voseo). Los XCUITest van por identificador: no rompas IDs.

### B · Salida a grupos dentro de «Es mi primera vez»
En la pantalla de elección de nube / «Es mi primera vez» (la del pie tipo «¡Hola de nuevo!» del estudio), añade:

> ¿Solo vienes a dividir gastos? **Empieza por aquí**

Ese enlace/botón lleva al **mismo camino** que la fila de grupos del elector (2.º nivel crear/unirse), no inventes un flujo nuevo.

**Faro / una sola opción de nube (aceptado por Jürgen):** si el faro está encendido o no hay elección de nube, **esa pantalla no se muestra** y B no aparece. No añadas B en el aviso del faro ni en el elector principal (B2 descartada).

## QA completo autónomo (pedido Jürgen 24-oct)
Haz tú todo el QA de A y B en simulador. Criterio:
- Recorre: elector con el nuevo copy → 2.º nivel; «Es mi primera vez» con B visible → llega a crear/unirse; caso faro o sin elección de nube: confirma que B no sale y el resto no se rompe.
- Unit + XCUITest afectados en verde (`WelcomeChooser` y los que toques).
- Capturas antes/después en `capturas/` del worktree; lístalas en el cierre.
- **Mueve la card a `done` tú** si el QA en sim + tests bastan. **Solo déjala en `in qa` asignada a jurgen** si de verdad necesita algo suyo (device real, decisión de producto, TestFlight). Si la dejas en QA, escribe en la nota el guion corto de qué falta.

## Qué NO hay que tocar
- C2 (cerrar formulario = quedarse), C (entrar sin crear/enlace), marketing/, App Store.
- No reinventes el diseño del Welcome (serif, filas, liquid glass). Solo copy + el pie B.
- Sin deploy.

## Base y Mini
- Arranca sobre `origin/2.2`. PR contra **2.2**.
- Rebase justo antes del PR: `git fetch && git rebase origin/2.2`.
- Pipeline serial: limpiar → build sin sim → boot 1 → tests → apagar/erase. `nice -n 10 xcodebuild -jobs 2`. Load < 8 antes de cada build. Nunca `| head` en xcodebuild.
- Al cerrar: DerivedData de esta sesión + cachés XcodeBuildMCP de worktrees muertos; `/cerrar-total`.

## Cómo se sabe que está bien
Copy A en 16 idiomas; B solo donde hay elección de nube; tests verdes; capturas; PR a 2.2; card en done (o in qa solo si Jürgen es imprescindible); `/cerrar-total`.

## Paso 0 (Frank, 24-oct)

- **Ficheros:** `WelcomeNewChooserView` (pie B, solo en contexto «primera vez»), `WelcomeFlowContainer` (callback de B → 2.º nivel de grupos y su «Volver»), `WelcomeBackStepLogic` (de dónde vuelve el 2.º nivel), `L10n.swift` (2 accessors), 16 `Localizable.strings` (6 claves: 4 cambian, 2 nuevas), un unit test y un XCUITest en `WelcomeChooserUITests`, `qa/coverage-index.json`.
- **B lleva al 2.º nivel de grupos** («¿Cómo empiezas?» crear/unirse), como pide el encargo; no salta directo a la puerta de crear.
- **Asumido:** el «Volver» del 2.º nivel vuelve a la pantalla de la que vino — «Es mi primera vez» si se entró por B, el elector si se entró por la fila. Si el cover se re-monta (p. ej. tras cancelar el inicio de sesión) el origen cae al elector, que la persona también vio.
- **Asumido:** B no sale en la activación de Yala completo (mismo chooser, contexto `.fullActivation`): ahí la persona ya está en grupos.
- **Asumido:** B sí sale en «Crear otra cuenta» del faro, porque abre la misma pantalla de elección de nube. No se toca el aviso del faro.
- **Copy:** se reusa la traducción histórica de «Dividir gastos con amigos» (retirada en `403d3057c`); es-ES con «piso», es-AR con voseo y «depto».
- **IDs XCUI intactos**; el nuevo es `welcome_new_start_groups`.
