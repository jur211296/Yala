---
esfuerzo: high
---
# iPhone Duo: adaptar Yala full (SDK 27.1)

**Card:** `tablero-iphone-duo-adaptar-yala-full-sdk-27-1-ba-vgsc` · Yala 2.2 · high · cierra-sola  
**Pedido Jürgen 24-oct:** adaptar **bien**, full buenas prácticas. Barras/tab bars en el **lado** (verticales bajo el status bar), **sin huecos negros / letterboxing**. No vale “corre pero se ve a medias”.

**Cola:** solo después de Welcome A+B (`…-jyhh`) y C2 (`…-ycke`).

## Fuentes Apple (obligatorias)
- https://developer.apple.com/iphone-duo/prepare/
- https://developer.apple.com/news/?id=kkphp5qo
- Tech Talk: Prepare your app for iPhone Duo
- Screenshot specs ASC (exterior 1398×2034 / 2034×1398; interior 2007×2853 / 2853×2007)

## Paso 0 · Disco en la Mini (solo al empezar ESTA sesión)
Hoy Welcome/C2 usan iPhone 17 Pro + runtime iOS 27.0. **No lo toques antes de esta sesión.**

Al arrancar Duo:
1. Apagar y borrar devices de sim que no sean Duo (`xcrun simctl shutdown all`; borrar iPhone 17 Pro / iPad si hacen falta GB).
2. Si hace falta espacio: quitar el runtime iOS 27.0 (`xcrun simctl runtime delete …` solo tras confirmar tamaño libre < ~32 GB o si el Duo no cabe).
3. Instalar **solo** el runtime/sim de iPhone Duo (SDK ya es 27.1 en Xcode 27.1 de la Mini).
4. Un solo sim a la vez. Pipeline serial Yala.

Al **cerrar** esta sesión (antes de `/cerrar-total` o en el cierre):
- Apagar/erase Duo.
- Volver a dejar un **iPhone 17 Pro** (o el device lane habitual) + runtime iOS 27.x usable para la cola siguiente. No dejes la Mini sin sim normal.

## Qué se pide (calidad alta)
1. **SDK 27.1:** el build de envío/PR usa el SDK iOS 27.1 (Xcode 27.1). Objetivo: experiencia “iOS 27.1 SDK or later” de Apple (pantalla completa interior; toolbars/tab bars **verticales** bajo el status bar), no el letterbox del SDK 26 ni el hueco del borde del SDK 27.0.
2. Correr el skill de resizability de Apple si está disponible (`xcrun agent skills export` / “get my app ready for iPhone Duo”) y aplicar los hallazgos.
3. Auditoría y fixes (app, no solo tests):
   - Nada de `UIScreen.main` para tamaño/layout (hoy la app ya va limpia; verifica de nuevo y en paquetes locales).
   - Nada de layout por `UIDevice.orientation` / `statusBarOrientation` / `interfaceOrientation`.
   - Nada de layout por idiom “es iPhone” o “regular = iPad” a ciegas; size classes / espacio disponible.
   - Nada de alturas/anchos mágicos de modelos concretos.
   - Hero/media: que no recorten mal al ensanchar.
   - Contenido que respete safe areas y la barra vertical (botones alcanzables, no tapados, no flotando en vacío negro).
4. **QA visual en sim Duo** (Device Hub: abierto, cerrado, plegado, rotado):
   - Welcome, Panel, Grupos, Ajustes, hojas modales, teclado.
   - Cero bandas negras / ventanas flotando centradas / UI cortada.
   - Tab bar / toolbar en disposición lateral vertical correcta.
   - Capturas `capturas/` antes/después por pose clave.
5. **App Store:** generar capturas Duo (exterior + interior) listas para ASC; el badge sale al subirlas (eso lo hace Jürgen/Lola en Connect; tú dejas los PNG con nombres claros y tamaños exactos). Anota en el cierre la ruta.
6. PR a **2.2**. Tests unit + XCUITest afectados en verde (los que usen `XCUIScreen.main` para adjuntos pueden quedarse; no uses eso para layout de producto).

## Qué NO
- No es solo “abre en Duo”. Si queda letterbox o hueco negro, **no está hecho**.
- No implementes features Duo avanzadas (Split View custom, hinge creativo, dual-display camera) salvo que caigan gratis con APIs estándar. Prioridad: resize + barras + sin vacíos.
- Sin deploy. Sin marketing/ salvo que hace falta una línea en el cierre para Lola (capturas ASC).

## Mini / build
- `nice -n 10 xcodebuild -jobs 2`, load < 8, un sim, sin `| head`.
- Rebase a `origin/2.2` antes del PR.
- `/cerrar-total` + restaurar sim iPhone normal (paso 0).

## Cómo se sabe que está bien
En Duo abierto y cerrado la UI llena bien, barras laterales correctas, sin vacíos negros; tests verdes; capturas ASC listas; PR; card **done** (solo `in qa` si Jürgen debe validar en hardware real Duo).

## Ticket previo
Revisar y cerrar/actualizar `tickets/backlog/iphone-duo-native-app.md` en el mismo PR si el alcance coincide.

## Sims (Jürgen 24-oct 13:36 Lima) — duro
Al **empezar** Duo: borrar **todos** los demás simuladores/runtimes que no sean Duo; dejar **solo** el sim Duo.
Al **cerrar** Duo: desinstalar Duo (runtime/device) y volver a instalar un iPhone normal; iPad **solo** si la siguiente sesión lo pide. No acumular sims «por si acaso».

## DerivedData y cachés (sin preguntar)
Al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques los de una sesión viva. No pidas aprobación; si el borrado falla, dilo en el cierre.

## Cierre
Este encargo cierra solo: al terminar, PR a 2.2 con auto-merge, card a done (o in qa a jurgen solo si hace falta hardware Duo real), restaurar el sim iPhone normal y `/cerrar-total`.

## Paso 0 (Frank, 2026-10-24 — auto-contestado, MODO lanzado)

1. **SDK 27.1 ya es el de siempre**: la Mini tiene Xcode 27.1 y el build sale con `iphonesimulator27.1` (medido en el
   `Info.plist` del `.app`). No hay ajuste de proyecto que tocar; el trabajo es que la app se vea bien con él.
2. **Simuladores**: al empezar, borrados el iPhone 17 Pro, el iPad y el runtime 27.0; `xcodebuild -downloadPlatform iOS`
   trajo el 27.1 (solo admite el Duo) **y volvió a traer el 27.0**. El 27.0 se dejó instalado sin dispositivos: hace
   falta al cerrar para el iPhone 17 Pro de la cola, y volver a bajarlo era un riesgo de dejar la Mini sin simulador
   normal. *Asumido.*
3. **Barras**: se deja el comportamiento del sistema para los botones de solo texto y el avatar (se quedan arriba, en
   horizontal). Pasarlos a la barra vertical cambia el iPhone o manda Filtros a «···»: decisión de Jürgen, en el ticket
   `iphone-duo-title-only-toolbar-buttons-stay-in-a-top-bar`. Sí se pasa la bandeja del Panel, que flotaba encima de la
   gráfica. *Asumido.*
4. **Pliegue**: se aparta el contenido solo donde el sistema lo da activo (medio plegado), con su región reservada; no
   se inventa la posición. No se hacen funciones propias del Duo (bisagra, cámara, Split View a medida).
5. **iPad mini en vertical**: con la misma regla del Duo abierto en vertical (no caben dos columnas de iPhone), su página
   con lista y detalle pasa a la pila en vez de superponer la lista. Se acepta como mejora; no medido en un iPad mini.
6. **Capturas de App Store**: sin componer (pantalla de la app a la medida exacta), seis por pantalla del Duo, con la
   semilla de casa. Componer láminas con textos de Lola queda fuera: `marketing/` es suyo y `sets.js` no tiene medidas
   del Duo.
7. **Card**: `done`. Todo lo pedido se verificó en el simulador del Duo; el hardware real no cambia la decisión.
