# Lote · Crashes de Sentry: memoria, cuelgues, memcpy y refresco del widget
toca: arranque y ciclo de vida de la app, BGTask del widget, rendimiento

Rama base: origin/2.3. Un solo PR contra 2.3, un solo cierre. Máquina: la libre. Simulador OK. Cierre autónomo. Termina con `/cerrar-total`. Commits y PR sin firma de IA.

## Contexto
Cinco issues nuevos de Sentry (yala-ios) del 5 y 6 de nov, cada uno con card en el tablero (busca por id): YALA-IOS-B (WatchdogTermination por RAM, escalando), YALA-IOS-A (cuelgue total), YALA-IOS-9 y YALA-IOS-D (cuelgues parciales), YALA-IOS-C (crash en __swift_memcpy17_8), YALA-IOS-E (NSInternalInconsistencyException en el launch handler de com.jurgenschmidt.yala.widget-refresh). El detalle está en los correos de Sentry a admin@yala-app.pe; si necesitas stack y no lo tienes, `preguntar-bot`.

## Qué se pide
Para cada issue: encontrar la causa, arreglarla con test, y dejar la card in qa. Si uno no se puede reproducir ni explicar con el stack, `preguntar-bot` con opciones antes de saltarlo. Primero mide contra la versión publicada.

## Qué NO hay que tocar
marketing/, Web/.

## Hecha cuando
Las cinco cards in qa con causa y test; gate verde; sección «Saltado o asumido sin preguntar»; `/cerrar-total`.

## Paso 0 — decisiones

> D1 y D2 las contestó Jürgen por el bot (2026-11-06 ~08:30 Lima). El resto, resueltas en autónomo (bypass): se discuten en el PR.

Hechos medidos antes de decidir (API de Sentry + transcripts de las sesiones del iPhone 14):
- E: re-registro de `com.jurgenschmidt.yala.widget-refresh` en el re-bootstrap del swap de persona. Alcanzable también en 2.1 (`origin/1.0` tiene el mismo camino).
- C y F (gemelo nuevo): SwiftData tras el swap de almacén en caliente, al cerrarse la hoja del Panel viejo. Lo arregla el PR #825 (cola contra 2.2, «el tercer cierre de Yala»).
- B (13) y D: todos en el iPhone 14 con la build de desarrollo, en los segundos de un `devicectl … --terminate-existing` o de un `list_elements` de Device MCP de otra sesión. App en ~80 MB. No es memoria.
- 9 y A: reales, iPhone 18 Pro Max de Jürgen, 2.2 (7) TestFlight; memoria del proceso 540 MB → 1,1 GB al volver a primer plano y sincronizar; hilo principal en el render de SwiftUI sin código de Yala.

**D1 · ¿Qué hacer con B y D (ruido de las pruebas)?** → En builds de desarrollo, Sentry apaga el aviso de WatchdogTermination y los cuelgues; producción igual. B y D se cierran como ruido explicado.
Por qué: decisión de Jürgen (opción a). Alternativa descartada: filtrar solo el watchdog.

**D2 · ¿Cómo atacar 9 y A sin saber la pantalla?** → Medir memoria en las pestañas principales con datos de peor caso en el simulador y arreglar lo que aparezca; si Jürgen dice la pantalla, se mira esa.
Por qué: decisión de Jürgen (opción a).

**D3 · ¿Duplicar en 2.3 el arreglo de C/F?** → No. Se verifica que el PR #825 cubre el stack y la card va a QA citándolo.
Por qué: duplicar choca al integrar 2.2 en 2.3. Alternativa descartada: cherry-pick, por el mismo conflicto.

**D4 · ¿Cómo evitar el doble registro de E?** → Bandera por proceso en `BackgroundTaskManager.registerTasks()` + registrar inyectable para el test.
Por qué: los handlers ya registrados leen el container que el re-bootstrap repone. Alternativa descartada: sacar el registro del bootstrap, que mueve el orden de arranque.

**D5 · Hotfix de E en 2.1** → No se hace en este lote; se anota para Jürgen (el release es suyo).
