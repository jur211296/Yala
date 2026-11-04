# Probar AnnotateKit en Yala Dev: anotaciones visuales que llegan a Claude

Pedido de Jürgen (2026-11-03). Card del tablero: «Probar AnnotateKit en Yala Dev (anotaciones visuales hacia Claude)». Rama base: 2.2. Una sola sesión Yala a la vez.

1. Instalar AnnotateKit (github.com/ooolzhas/annotatekit, licencia MIT) solo en Yala Dev y detrás de `#if DEBUG`.
2. Verificar con `strings` que el binario del scheme `Yala` (TestFlight y App Store) no lo incluye: 0 apariciones.
3. Probarlo en el simulador con una pantalla: anotar, enviar y confirmar que la nota llega a la sesión de Claude en la Mini.
4. Documentar en el PR cómo lo usa Jürgen desde su iPhone conectado a la Mini, con un video corto.
5. Si exige algo riesgoso, permisos raros o un servicio externo de pago, no instalarlo y explicarlo en el PR.
6. Mover la card a in qa con el link del PR. Squash auto-merge en 2.2 si el gate pasa.

Textos para Jürgen en español neutro latinoamericano.

Termina con /cerrar-total.

## Paso 0

Auto-contestado (sesión lanzada, sin nadie delante):

- **Riesgo (punto 5):** MIT, sin red ni servicio de pago, sin permisos ni claves de Info.plist. Una sola API privada (`_AXSSetAutomationEnabled`, la que usa XCUITest) por `dlsym`, solo en DEBUG. Se instala.
- **Versión:** fijada exacta a 1.0.0 (el repo nació hoy; nada de rangos).
- **Dónde se enciende:** `#if DEBUG && DEV_BUILD` (no basta DEBUG: el scheme Yala también corre en Debug) y fuera de unit tests y `-uitest`, para que el botón flotante no tape XCUITest ni capturas.
- **Release limpio (punto 2):** se mide con `strings` sobre el binario Release de Yala; si el paquete enlazado deja rastro, se enlaza solo en Debug-Dev.
- **Lado Mac:** no se instala el plugin de Claude Code de forma global (añade un Stop hook a todas las sesiones y pide un flag de research preview). La prueba usa el CLI `annotate watch` desde la sesión; el PR documenta las dos vías y Jürgen elige.
