# La bienvenida lleva su propio texto en el diálogo de cancelar la activación de la nube, sin «desde aquí»

## Contexto
Ticket `tickets/backlog/welcome-adopt-cancel-dialog-says-from-here.md` (léelo entero primero). Tarjeta del tablero p4bk.
Entro en mi cuenta de la nube desde la bienvenida y toco «Cancelar la activación». El diálogo dice «Puedes volver a activar la nube en este dispositivo desde aquí cuando quieras». Al confirmar, la app me lleva a la pantalla de elegir y ese «aquí» ya no existe. Pasa porque la bienvenida reusa el cuerpo del diálogo de Almacenamiento (`StorageFailureCopyLogic.cancelMigrationBody`: `storage.confirm.cancelAdoptBody` / `cancelAdoptEffectBody`).

Decisión de Jürgen del 2026-10-04: **opción B**. La bienvenida lleva un cuerpo propio, sin «desde aquí», aunque sean dos claves nuevas en los 16 idiomas. El texto debe decir la verdad de dónde queda el usuario (vuelve a la pantalla de elegir y puede entrar otra vez por «Ya tengo cuenta» cuando quiera). Español neutro latinoamericano en las variantes es/es-419; nada de vosotros.

Jürgen prefiere siempre lo más robusto y la mejor práctica, aunque tome más tiempo.

## Qué se pide
- Dos claves nuevas para la bienvenida (equivalentes a `cancelAdoptBody` y `cancelAdoptEffectBody`), con variantes completas en los 16 `Localizable.strings` y alias byte a byte donde el repo lo use así.
- La bienvenida usa esas claves; Almacenamiento sigue igual con las suyas.
- Tests que fijen qué cuerpo sale en cada superficie (bienvenida vs. Almacenamiento) y mutantes que lo prueben.
- Capturas de antes y después del diálogo en la bienvenida en `capturas/` del worktree (`antes.png`, `despues.png`), con las rutas en el resumen de cierre. Si no hay forma de montar ese estado en el simulador, dilo en el cierre en vez de inventarlas.
- Ticket a `qa` con guion corto de device-QA si hace falta, `docs/TICKETS.md` y `qa/coverage-index.json` al día.
- Cierra con PR a `2.1` en auto-merge y luego `/cerrar-total` autónomo, sin esperar a Jürgen.

## Qué NO hay que tocar
- El texto y el comportamiento del diálogo de Almacenamiento.
- La lógica de cancelar la activación (solo cambia el copy de la bienvenida).
- marketing/ y Web/.

## Pipeline serial en la Mini (obligatorio)
1. Limpiar sims muertos, basura previa, DerivedData de sesiones ya cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen. Sin preguntar.
2. Build con `xcodebuild -jobs 2` sin simulador encendido.
3. Encender UN solo simulador.
4. Tests.
5. Apagar y borrar los datos de ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests. La Mini anda justa de disco (~32 GB libres).

## Gate después del CI del PR anterior
La sesión arranca ya, sobre `origin/2.1`. Justo antes del gate, mira si el PR #378 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez. (#378 también añade claves en los 16 Localizable.strings: resuelve el conflicto si sale.)

## DerivedData y cachés
Al lanzar y al cerrar, borra sola el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No preguntes. No toques los de un worktree vivo. Si el borrado falla, dilo en el cierre.

## Cierre limpio
Al `/cerrar-total`: apaga el simulador que usaste, borra sus datos, quita el worktree y su DerivedData si ya no hace falta, y no dejes devices apagados ni worktrees huérfanos. Si creaste algún secreto en el Llavero, dilo en el cierre.

## Cómo se sabe que está bien
- En la bienvenida, cancelar la activación muestra un cuerpo que no dice «desde aquí» y describe bien a dónde vuelve el usuario, en los 16 idiomas.
- Almacenamiento sin cambios.
- Build verde, unit y UI de las áreas tocadas verdes, mutantes muertos.
- PR a 2.1 en auto-merge, capturas antes/después (o motivo de su ausencia), Mini limpia.

## Paso 0 (auto-contestado, MODO AUTÓNOMO)

- **A dónde vuelve el usuario (medido):** `cancelLanded` → `onBack` → `welcomeFlowInitialStep = .chooser` (ContentView), el
  selector «¡Hola! ¿Qué quieres hacer en Yala?», cuyas tres filas salen siempre; «Ya tengo una cuenta» → sub-elección →
  `.cloudSignIn`/`.googleSignIn` → la misma pantalla. El copy lo dice así: «Volverás al inicio. Cuando quieras, puedes
  entrar otra vez en tu cuenta con «Ya tengo una cuenta»».
- **Primera frase de cada cuerpo, igual que en Almacenamiento** (alcance mínimo): solo cambia la frase del «desde aquí».
- **El nombre del botón se cita con el texto EXACTO de `welcome.chooser.optionExisting.title` en cada locale** (es-ES
  «Ya tengo cuenta», pt «Já tenho conta»…), y un test lo fija contra el fichero de cada locale.
- **Claves:** `welcome.cloud.cancelAdoptBody` y `welcome.cloud.cancelAdoptEffectBody`. `es`/`pt` copia byte a byte de
  `es-419`/`pt-BR`; es-AR con voseo; es-ES con tú (sin vosotros).
- **API:** `StorageFailureCopyLogic.cancelMigrationBody` gana `surface: CancelDialogSurface` (`.storage`/`.welcome`) SIN
  default: la elección de fase sigue en un solo sitio y cada pantalla declara la suya. Almacenamiento devuelve lo mismo
  que hoy.
- **Rama «Migrar» (ni claim ni efecto) en la bienvenida:** se queda con `cancelMigrationBody` de Almacenamiento; no dice
  «desde aquí» y el encargo pide solo las dos del adopt.
- **Capturas:** se intentan con el seed de UITest del adopt en la bienvenida; si no hay forma de montar el estado, se dice.
