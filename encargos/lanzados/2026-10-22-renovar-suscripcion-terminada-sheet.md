# Tras renovar desde «Tu suscripción terminó», el sheet reaparece en vez de pasar a «Ya eres Yala Pro»

## Contexto
Reporte de Jürgen del 22-oct, card `tablero-al-renovar-desde-tu-suscripcion-termino-7c97` (ready to launch, frank, v2.2). En el sheet «Tu suscripción terminó», tocar Renovar y completar la compra cierra la hoja de renovación, pero vuelve a mostrar «Tu suscripción terminó». Solo al tocar Renovar otra vez aparece «Ya eres Yala Pro» y se cierra todo.

Base y PR: **2.2**. Trabaja sobre origin/2.2 (si `lanzar-sesion` te dejó en otra base, `git fetch origin && git switch -C encargo-tmp origin/2.2` antes del primer commit, y comprueba que `git log origin/2.2..HEAD` sale vacío). El PR va contra **2.2**. El PR #600 (formulario de registro) está en cola de auto-merge en 2.2: no lo esperes y no toques el formulario de registro.

## Qué se pide
- Reproducir en el simulador con StoreKit de prueba.
- Encontrar por qué el estado de la suscripción no se refresca a tiempo tras la compra o por qué el sheet de suscripción terminada se vuelve a presentar, y arreglarlo en la causa, no con un parche de tiempo.
- Un test que cubra que, tras una renovación exitosa, el sheet se cierra (o pasa a «Ya eres Yala Pro») a la primera.
- Mover la card: al empezar `tablero mover tablero-al-renovar-desde-tu-suscripcion-termino-7c97 --a "in progress" --agente frank`. Al cerrar: a `in qa` asignada a `jurgen` con un guion corto para probarlo en el iPhone con una compra real de sandbox/TestFlight, o a `done` si no queda nada que probar en el teléfono. `--nota` reemplaza la nota entera: copia la que ya está y añade debajo.

## Qué NO hay que tocar
- Precios, productos de StoreKit, paywall ni textos, salvo que el arreglo lo exija (y entonces en los 16 idiomas con `/l10n-check` limpio).
- El formulario de registro (`NewTransactionView*`), que está en el PR #600.
- En `~/Yala` (árbol principal) no toques, commitees ni descartes `Cloudkit Schemas/*.ckdb`, `Yala.xcscheme` ni `encargos/pendientes/`.
- Nada de despliegues a producción.
- No toques tmux `salud--*`, `ecru--*`, `sat-lab--*`, `ruum--*`, `clinicas-dentales-bi--*` ni otros `Yala--` vivos.

## Reglas
- **Sin esperar el CI de ningún PR** (tampoco el tuyo): `git fetch origin && git rebase origin/2.2` justo antes de abrir el PR.
- Pipeline serial en la Mini: limpiar, build con `xcodebuild -jobs 2` sin simulador encendido, encender 1 simulador, tests, apagarlo. 1 simulador a la vez. Mira `df -h /` antes de compilar (hay ~12 GB libres). Simuladores iOS 27.0. Al cerrar, apaga y borra (erase) el simulador que usaste.
- Al lanzar y al cerrar borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen; no toques las de un worktree vivo.
- Si hay cambio visible, capturas de antes y después en `capturas/` del worktree, copiadas a `~/Claude/entregas/<sesión>/capturas/`, con sus rutas en el resumen.
- Cierra sola con **/cerrar-total** (modo cola: auto-merge, sin esperar CI). No esperes a nadie.

## Cómo se sabe que está bien
Tras una renovación exitosa el sheet de suscripción terminada no reaparece, a la primera; test que lo cubre en verde; `/gate` y `YalaTests` en verde; card movida; PR contra 2.2 explicando en lenguaje de usuario qué cambia.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Dónde está la causa?** → En la regla que decide el derecho local (`ProSubscriptionActivationLogic`), no en la hoja. Si `currentEntitlements` lista una transacción nuestra caducada, la regla la tomaba como veredicto de Apple: Free y borrado del derecho guardado, aunque ese derecho fuera una compra verificada que vence dentro de un año. Tras renovar una suscripción terminada, StoreKit sigue listando un rato la caducada vieja y aún no la nueva, y cualquier lectura en ese rato (la de volver a primer plano al cerrarse la hoja de pago, la del paywall) apagaba Pro. La hoja mira `isProUser` al cerrarse el paywall, lo ve en `false` y se queda; la segunda vuelta por «Renovar» relee cuando StoreKit ya lista la nueva.
Por qué: es la única forma, medida en el código, de que una lectura deje Free tras una compra buena (con la lista vacía, el derecho guardado de la compra la sostiene), y solo puede pasar al RENOVAR: una primera compra no tiene suscripción vieja que listar. Que StoreKit liste la caducada está inferido, no medido: lo confirma el device-QA. Alternativas descartadas: que el `onDismiss` del paywall no corra (el XCUITest con la compra simulada cierra bien sin el arreglo); una carrera de orden entre lecturas — fue el primer diseño (turnos por lectura) y la review lo tumbó: con la lista vacía no hay carrera que deje Free, con la caducada listada el orden no ayuda, y descartar lecturas abría un hueco con los reembolsos.

**D2 · ¿Cómo se arregla?** → Una transacción caducada de la MISMA suscripción (mismo `originalID`) no desmiente un derecho verificado que aún no ha vencido (`isSupersededExpiredListing`): si caducó, es un periodo anterior. `StoreKitManager` guarda el `originalID` con el derecho. Mandan como antes: una revocada (reembolso, familia), la caducada de otro Apple ID en el mismo teléfono (otro `originalID`; lo cazó la segunda review) y todo lo que no se puede situar (sin `originalID` o sin fecha, incluido lo que guardó un build anterior).
Por qué: arregla la causa, no el tiempo, en un solo sitio puro que comparten la compra y todas las lecturas. Que volver a suscribirse en el mismo grupo conserve el `originalID` lo dicen la comunidad y los foros, no Apple, y hay un aviso sin confirmar de un id nuevo pasados 180 días: ahí el arreglo no actúa y queda el comportamiento de antes. Precio aceptado: si un reembolso no llegara nunca como transacción revocada (lo entrega `Transaction.updates`) y Apple solo listara la caducada, Pro duraría hasta que venza lo guardado. Alternativa descartada: un retraso o reintento en la hoja (parche de tiempo, prohibido por el encargo).

**D3 · ¿Se toca la hoja?** → No. Con la regla bien, el `onDismiss` de la hoja ya hace lo correcto. `StoreKitManager` solo cambia para llevar el `originalID`.
Por qué: alcance mínimo.

**D4 · ¿Qué tests?** → Unit de la regla (`renovar_*` en `ProSubscriptionActivationLogicTests`, con control sin compra guardada, otro Apple ID, revocada, sin `originalID` y sin fecha; más el scan de que el manager guarda y lee el `originalID`) y el caso viejo `entitlementCaducado_borraLastVerified`, que fijaba el bug como contrato, rehecho con el derecho vencido. XCUITest del recorrido renovar → «Comenzar» → hoja cerrada a la primera, con la compra simulada.
Por qué: el unit discrimina por construcción (con la regla vieja cae). El XCUITest no ve StoreKit —en `Yala Dev` una compra real nunca activa Pro— y cubre la presentación que pide el encargo; la prueba con StoreKit real es el device-QA.

**D5 · ¿Cierre de la card?** → `in qa` asignada a Jürgen con guion de compra sandbox/TestFlight en el iPhone: el listado de la suscripción caducada solo existe con StoreKit real.
