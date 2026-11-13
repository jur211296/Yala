Yala
# Después de «Ya está tu cuenta», Yala va directo al Panel y no vuelve a la bienvenida
---
card: tablero-despues-de-ya-esta-tu-cuenta-yala-vuelve-zrya
toca: Yala/App/Logic/WelcomeMirrorRelaunchLogic.swift, Yala/App/Logic/WelcomeRestoreRelaunchLogic.swift, Yala/App/Logic/RelaunchNetLogic.swift, Yala/App/Views/Onboarding/WelcomeMirrorRelaunchView.swift, Yala/App/Views/Onboarding/WelcomeRestoreView.swift, Yala/App/Views/Onboarding/WelcomeFlowContainer.swift, Yala/Services/CloudSync/AdoptSessionOwnership.swift, YalaTests/WelcomeNoRelaunchAfterAdopt/, tickets/backlog/account-ready-returns-to-welcome-and-asks-to-relaunch.md, tickets/done/account-ready-returns-to-welcome-and-asks-to-relaunch.md
esfuerzo: high
cierre: cierra-sola
---

Error grave reportado por Jürgen el 13-nov a las 09:46 en el iPhone 14 (staging, cuenta con grupos), al probar el arreglo del bloqueo de 15 minutos. Después de ver «Ya está tu cuenta», el adopt termina bien, pero la app vuelve a la bienvenida y pide reabrir Yala. Eso nunca debe pasar. Rama base: 2.3; la 2.2 está cerrada.

Antes de empezar, lee los comentarios de la card: la sesión del bloqueo de 15 minutos dejó ahí en qué paso pasa, los registros, la causa probable y cómo reproducirlo. Crea el ticket en `tickets/backlog/` con el nombre de `toca:`.

Qué se pide: tras «Ya está tu cuenta» se llega directo al Panel con los datos, sin volver a la bienvenida, sin pedir reabrir la app y sin relanzar. Si algún caso de verdad exige reiniciar, la app lo hace sola sin mostrar la bienvenida, y lo explicas en el PR.

**Pruebas:** reproduce en el iPhone 14 por DeviceMCP, conectado a la Mini, con la cuenta de staging que tiene grupos. Si hace falta que Jürgen toque el teléfono o inicie sesión, pídeselo según el modo. Puedes usar un segundo simulador si otra sesión ocupa el primero. Agrega tests que caigan sin el arreglo. Corre solo las pruebas de interfaz que toca el cambio y la suite completa una vez al final. Si hay dos timeouts seguidos, la prueba es inestable: anótalo y sigue. Tope de 30 minutos en pruebas de interfaz, y nunca más de 3 minutos sin escribir avance.

**Archivos:** puede correr en paralelo con otra sesión de Yala en la otra máquina, así que te quedas dentro de `toca:`. Si de verdad hace falta tocar algo fuera, que sea un cambio mínimo: lo anotas en «Decidido sin consultar» y rebasas sobre 2.3 antes del PR.

**Entrega:** un PR contra 2.3, mergeado si CI pasa, y el ticket en done. Commits y PR sin firma de IA. Lo menor y reversible lo decides y lo anotas en «Decidido sin consultar». Si el trabajo queda completo y el modo lo permite, cierra con `/cerrar-total`.

## Paso 0 — decisiones

*Modo semi, con Jürgen en el chat. Las de alcance las contestó él; las menores, aquí.*

1. **Causa, medida en el iPhone 14 con logs de consola (no inferida).** «¡Tu cuenta está lista!» → «Empezar» llama a
   `onFinishedToApp`, que lee `hasCompletedOnboarding = true`; el cover se cierra y su `onDismiss`
   (`welcomeCoverDidDismiss`) lee `false` en la línea siguiente del log: es el cierre de cuando se presentó el cover,
   anterior al adopt. Con `false`, el respaldo reabre el elector (que en 2.3 pinta la bienvenida). *Medido.*
2. **Alcance (Jürgen, 11:3x):** este PR arregla solo la vuelta a la bienvenida. «Un último paso: reabre Yala» (el proceso
   arrancó con el espejo de iCloud montado) va aparte: lo trabaja la sesión de la Max «Entrar con otra cuenta de Google o
   Apple» (su punto 2); se le pasaron las mediciones y no se crea card duplicada. *Jürgen.*
3. **Arreglo:** el respaldo lee el onboarding de su almacén en el momento (`UserDefaults`), con la decisión en una función
   pura de `WelcomeCoverContentLogic`. No se toca el resto del respaldo (los otros tres términos son `@State` y se leyeron
   bien en el log). *Resuelto aquí.*
4. **Ficheros fuera de `toca:`** (mínimos): `ContentView.swift` (3 líneas del respaldo), `WelcomeCoverContentLogic.swift`
   (dos funciones), `YalaTests/WelcomeCoverContentLogicTests.swift` (el scan fijaba la línea vieja), la regla en
   `.claude/rules/swiftui-ds.md` y `qa/coverage-index.json`. Ninguno es de la sesión de la Max. *Resuelto aquí.*
5. **Tests:** lógica pura + scan del cableado que cae sin el arreglo (mutante). Sin XCUITest: llegar a
   «¡Tu cuenta está lista!» exige un adopt real contra el backend, y el seam viviría en `WelcomeCloudSignInView`, fichero
   de la sesión de la Max. La prueba de punta a punta es en el iPhone 14. *Resuelto aquí.*
6. **Cada atasco del QA, a su card** (Jürgen): tres creadas (cerrar Yala en pleno Conectando; entrada parada por un
   traspaso a medias; no baja nada tras reabrir) y la de la barra de progreso con hitos más pequeños. *Jürgen.*
