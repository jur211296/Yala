# Qué hay que hacer, en una línea
Aplicar la transición A · Fundido en el salto del Welcome a «Entra a tu cuenta» (y su vuelta), sin el negro de ~0,6 s de hoy.

## Contexto
- Card: Entrada a Yala: las pantallas se cierran y se abren enteras; buscar una transición más bonita (tablero-entrada-a-yala-las-pantallas-se-cierran-4gfj).
- Decisión Jürgen 2026-10-25 07:30 Lima: **A · Fundido** (recomendación de la propuesta del lote 12.3).
- Hoy: al pasar de «¡Hola de nuevo!» / «Es mi primera vez» a la entrada con cuenta de Yala, una pantalla se cierra y la otra se abre entera (~0,6 s en negro). Causa: cambio de vista raíz (`WelcomeFlowContainer.leaveWelcome` → `onBeaconRoutesToCloudSignIn`), no un push dentro del mismo flujo.
- Referencia visual: `~/Claude/entregas/Yala--lote-12-3-accesibilidad-contraste/transicion-welcome/` — `hoy.mp4`, `fundido.mp4` (objetivo), `entrada-a-yala.html`.
- El fundido debe ser el mismo lenguaje que ya usan los pasos del Welcome entre sí: fondo morado quieto, contenido que se funde ~0,35 s, sin negro intermedio. Con «Reducir movimiento», el fundido sigue válido (no desplaza nada).
- Base: `origin/2.2`. PR contra 2.2. No esperar CI del PR anterior; justo antes del PR, `git fetch` + un solo rebase sobre `origin/2.2`, y build/simulador una vez después.
- Pipeline Yala serial (1 sim): limpiar → build sin sim → boot 1 sim → tests → apagar y limpiar.
- Mini con ~25 GB libres (bajo umbral 32 GB): limpia DerivedData/cachés de worktrees cerrados antes del build; un solo sim.

## Qué se pide
1. Implementar **A · Fundido** en estos cuatro saltos:
   - Ya tengo cuenta → Entra a tu cuenta
   - Faro de «Es mi primera vez» → Entra a tu cuenta
   - Crear otra cuenta (desde la entrada)
   - Volver (de la entrada al Welcome)
2. Quitar el negro intermedio; el fondo morado no se mueve; el contenido se funde ~0,35 s (mismo criterio que los pasos internos del Welcome).
3. Respetar «Reducir movimiento».
4. Dejar vídeo del después en `~/Claude/entregas/Yala--transicion-entrada-fundido/capturas/` (o equivalente) y capturas si ayudan.
5. Antes de diseñar/ajustar UI, mira `~/Claude/referencias-ui/README.md` y usa lo que aplique como inspiración (no copies marcas ni pantallas).
6. `/barrido-qa` de lo tocado y `/cerrar-total` al terminar. Ticket nuevo → su card.

## Qué NO hay que tocar
- No reabrir la decisión A/B/C.
- No cambiar copy del Welcome ni el flujo de la nube más allá de la transición.
- No tocar Duo, idiomas (12.4) ni lotes 12.5–12.7.
- No CloudAgent; trabajo solo en este worktree.
- No instalar ni probar simslim en esta sesión.

## Cómo se sabe que está bien
- Los cuatro saltos usan fundido sin negro.
- Vídeo del después en entregas.
- Tests unitarios/UI relevantes en verde.
- Card 4gfj a done (o in qa solo si hace falta ojo de Jürgen; si el vídeo basta y CI pasa → done).

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Cómo quitar el negro.** El negro sale de que Welcome y «Entra a tu cuenta» son dos `fullScreenCover` del mismo anchor: uno baja entero y el otro sube. → **Un solo cover** cuyo contenido es el Welcome o la entrada, con `.transition(.opacity)`. Descartado: quitar la animación de UIKit con `Transaction.disablesAnimations` y pintar el degradado debajo (no hay fundido de verdad entre las dos pantallas, solo un corte con fade-in, y depende de cómo encadena UIKit dos presentaciones).
2. **Fondo quieto.** Las dos pantallas pintan su propio degradado; en un cross-fade de dos capas opacas el centro deja ver el fondo del cover. → Degradado `heroIndigoBlack` **debajo** de las dos dentro del cover.
3. **Duración.** 0,35 s `easeInOut` (encargo). Los pasos internos del Welcome siguen con su 0,5 s: no se tocan.
4. **Reducir movimiento.** El fundido se mantiene (no desplaza nada; es lo que la propuesta A dijo y Jürgen eligió).
5. **Alcance.** Los cuatro saltos pedidos más los que comparten el mismo cambio de cover (alta born-cloud y la vuelta a la puerta de Grupos desde la entrada): son el mismo salto y quedan coherentes. Restaurar e invitación son otros covers y no se tocan (van a «Encontrado»).
6. **Estado de la entrada al volver sin cerrar el cover.** El `onDismiss` de la entrada reponía `adoptStartsAtConsent` y `cloudSignInFromExistingChooser`; sin cierre, esa limpieza corre al pasar de la entrada al Welcome. El respaldo «reabrir el elector» solo corre si lo último que enseñó el cover fue la entrada.
7. **Lógica pura + test.** `WelcomeCoverContentLogic` con unit tests y source-scan del cableado.
8. **Vídeo del después** con un conductor XCUITest (faro → Entra a tu cuenta → Crear otra cuenta, y Ya tengo cuenta → Volver) grabado con `simctl io recordVideo`. El «antes» es `hoy.mp4` de la propuesta (mismo día, misma base).
