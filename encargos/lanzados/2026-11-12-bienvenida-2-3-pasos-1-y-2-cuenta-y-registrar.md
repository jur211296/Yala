Yala
# Bienvenida 2.3 · Pasos 1 y 2: primera cuenta y aprender a registrar
card: tablero-bienvenida-2-3-paso-1-crear-la-primera-c-1771,tablero-bienvenida-2-3-paso-2-pagina-y-formulari-6vu0,tablero-bienvenida-2-3-paso-2-voz-foto-y-yala-ia-d1ab,tablero-bienvenida-2-3-paso-2-borrar-pruebas-pan-69nw
toca: Yala/App/Views/Onboarding/, Yala/App/Views/Accounts/, Yala/App/Views/Transactions/, Yala/App/Views/Panel/, Yala/App/Views/Inbox/, Yala/App/Views/Voice/, Yala/App/Views/Image/, Yala/App/Views/Chat/, Yala/App/Tips/, Yala/App/Services/, Yala/App/ViewModels/, Yala/App/Models/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3, Yala/bienvenida-2-3-alta-vitrina-y-acceso

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Lote 03 de 5 de la implementación oficial de Primeros pasos de Yala 2.3. Fuente: docs/onboarding-2-3/SPEC.md, cards Y23-07 a Y23-10. Prototipo oficial v35, pestañas 3 · Primera cuenta y 4 · Nuevo registro: https://claude.ai/artifact/AcwrfYm96uy8k6Ga2EXnU6. Depende del lote 02 (llegada al Panel tras el alta) y usa el mazo y los momentos de permiso del lote 01. El tope de 4 monedas por cuenta ya está decidido en la ficha Y23-07; no se reabre. Las demás decisiones ya están en el SPEC.

## Encargo y criterio de terminado
Implementar SOLO estas 4 cards, cada una tal como está en su sección del SPEC:
1. Y23-07 · Paso 1 · Crear la primera cuenta (atajo `#cta-s_cuenta.intro`). Preguntas en vez del formulario, mismos datos. Moneda con líneas ANTES de guardar. Recordatorio de tarjeta 0/1/3/5 y permiso solo si lo eligió (Y23-17). Fuera de alcance: número de cuenta, «Excluir de las estadísticas», páginas E1 y E3.
2. Y23-08 · Paso 2 · Página y formulario con guía de foco (atajo `#reg`). «Cuatro maneras de anotar» y el formulario de hoy (NewTransactionView) con CoachMarkOverlay en 5 pasos. No rediseñar el formulario (R1, R2 y R3 se descartaron).
3. Y23-09 · Paso 2 · Voz, foto y Yala IA con prueba de cortesía (atajo `#reg-s_reg.voz`). Hay que construir la prueba de cortesía de Yala IA. Con cuenta Free, cada una funciona una vez y el registro se guarda de verdad; después vuelve el candado.
4. Y23-10 · Paso 2 · Cierre: borrar registros de prueba, Panel lleno y Bandeja (atajo `#reg-s_reg.fin`). Hoja «¿Borramos los de prueba?»; el Panel se llena y funciona normal; guía de la Bandeja; el mazo pasa al paso 3. Fuera de alcance: widgets de gráficas en el Panel recién creado (Y23-15).

Reglas del lote:
- Los textos exactos y el comportamiento salen del SPEC y del prototipo. No se reabren decisiones. Si el artifact y la ficha no coinciden, manda la ficha y se avisa en el cierre.
- Compara con el prototipo (https://claude.ai/artifact/AcwrfYm96uy8k6Ga2EXnU6, versión 35) y deja capturas antes y después de lo que se vea, en `capturas/` del worktree.
- Accesibilidad de la ficha «Cómo usar esta especificación»: Reducir movimiento deja solo fundidos y las páginas que avanzan solas se quedan quietas; VoiceOver no avanza solo; texto grande no corta.
- Textos en español neutro, con «tú», según docs/planning/BRAND-VOICE.md. Los textos marcados «de la app» se copian de Localizable.strings, no se reescriben.
- Un test de comportamiento por card (unit o XCUITest según `qa/coverage-index.json`). Review adversarial obligatoria.
- Si un punto exige una decisión de producto que no esté ya en el SPEC, sepáralo y déjalo pendiente con su pregunta; no elijas alternativa. Infraestructura o un hueco del servidor: `BLOQUEANTE:`, sin inventar.
- No choques con otras sesiones de bienvenida ni con los lotes 2.3 ya en cola: si comparten fichero, rebasa y cita.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:55 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- La especificación oficial vive en `docs/onboarding-2-3/SPEC.md` (entró por el PR 873 en 2.2; tras el merge tiene que estar en origin/2.3). Léela completa para las cards de este lote y no implementes lo que sea de otra card.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve las cards a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0 (Frank, 12-nov, modo semi)

Comprobado: `origin/2.2` ya no existe y `v2.2` está entero en `origin/2.3` (0 commits fuera). El lote 02 (alta) está
en cola de auto-merge (PR abierto, tests en curso): se trabaja sobre `origin/2.3` y se rebasa una vez antes del gate.

Decisiones (técnicas; ninguna de producto queda abierta):

1. **Paso 1 (Y23-07)**: una pantalla completa propia (`FirstAccountFlowView`) que abre el mazo. Página E2 de tres
   partes (3,4 s, quieta con Reducir movimiento o VoiceOver) y preguntas con la tarjeta arriba. Guarda con las piezas de
   la app: `Account` + `InitialBalanceService.setInitialBalance` + `AccountLineService.addLine` por cada moneda extra
   (hasta 4) + días de la tarjeta y aviso 0/1/3/5 de `CreditCardStatementLogic`. Tarjeta: lo que se debe se guarda en
   negativo, como el formulario. Permiso de notificaciones solo al elegir recordatorio (`TutorialPermissionMoments`).
   Selector de moneda: la lista de 54 de la app (no la corta del prototipo).
2. **Paso 2 (Y23-08/09)**: una pantalla completa (`RecordTutorialView`) con la página de las cuatro maneras y la de
   «entre maneras»; desde ella se abren las pantallas de HOY (`NewTransactionView`, `VoiceRecordingView`,
   `ImageSelectionView`, chat de Yala IA). La guía de foco es `CoachMarkOverlay`, ampliada para que el foco deje pasar
   el toque y los botones se puedan nombrar. Mientras dura, ningún camino da por hecho el paso 2 (ni el formulario ni
   `autoDetect`): lo cierra el tutorial al terminar.
3. **Prueba de cortesía de Yala IA**: `FeatureGateService.enableSetupTrial(.chatAssistant)` dentro del tutorial, y el
   mensaje sale como «apuntar» (`forceIntent: .register`). Medido en `gateway/src/policy.ts` y `ai/tasks.ts`: Free no
   tiene cubo `chat`, pero «apuntar» solo llama a `text.parse` (cubo `voice`, cupo de prueba de 5): **no hace falta
   tocar el servidor**. Cada manera se gasta una vez (estado guardado); al cerrar su pantalla vuelve el candado.
4. **Cierre (Y23-10)**: hoja a media altura con los registros del tutorial marcados; borrar usa el borrado de
   práctica de hoy (`deletePracticeItem`) y avisa con el aviso breve de la app. Después, guía de foco de la Bandeja
   como una guía más de `PlaceGuide` (`.inbox`). El mazo pasa solo al paso 3.
5. Textos: los de la ficha y del prototipo v35; en los 16 idiomas por JSON + script. El artifact no se deja leer desde
   esta sesión: se compara contra la fuente local del v35 (`~/Claude/entregas/onboarding-yala-20261107/prototipo`).
