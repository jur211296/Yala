# Lote · Cerrar sesión con cambios: crash y Welcome tras «Ya tengo cuenta»
toca: flujo de cerrar sesión / Welcome / cuenta existente

Rama base: origin/2.2. Un solo PR contra 2.2, un solo cierre. Máquina: la libre. Usa simulador (pipeline serial). Cierre autónomo (`cierra-sola`). Termina con `/cerrar-total`.

## Contexto
Card alta 2.2: «Cerrar sesión con cambios: crash; al volver «Ya tengo cuenta» deja en Welcome tras «Tu cuenta e…»» (tablero-cerrar-sesion-con-cambios-crash-al-volve-7e60).

## Qué se pide
1. Reproducir el crash al cerrar sesión con cambios pendientes; arreglarlo.
2. Tras cerrar y elegir «Ya tengo cuenta», no quedar atrapado en Welcome: llegar al flujo correcto de la cuenta.
3. Capturas antes/después; `tablero` en curso → in qa con guion corto.
4. Si falta decisión de producto: `preguntar-bot` (no asumas).

## Qué NO hay que tocar
marketing/, TestFlight, despliegues a producción.

## Hecha cuando
- La card cumple su hechaCuando; gate en verde; `/cerrar-total` con «Saltado o asumido sin preguntar».

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, 22:40 Lima): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Dónde se corta el crash?** → En la hoja de Ajustes: su contenido deja de pintarse en cuanto el almacén con el que se montó ya no es el montado (`detachesFromSwappedStore()`, por generación del host).
Por qué: el `.ips` muestra el `onAppear` de Ajustes reapareciendo con el `modelContext` del almacén soltado; quitando la vista no corre ni ese ni ningún otro lector (`.task`, `body`). Alternativa descartada: un `guard` dentro de `ProfileViewModel` — no puede saber si su contexto está muerto sin tocarlo (tocarlo es el trap).

**D2 · ¿Qué más presentaciones lo llevan?** → Solo las que pueden lanzar un cambio en caliente y siguen montadas mientras ocurre: Ajustes (cerrar sesión y borrar cuenta en la nube). La hoja del cambio de Apple ID cierra sesiones privadas, que montan con espejo y no cambian en caliente; la puerta de Grupos del Welcome no lee el contexto en su `body` tras armar. Se documenta la regla para la próxima.
Por qué: alcance mínimo, sin dejar la clase abierta. Alternativa descartada: ponerlo en todas las hojas — ruido sin caso.

**D3 · «Ya tengo cuenta» → «¡Tu cuenta está lista!» → Empezar vuelve al Welcome** → Se mide en el iPhone 14 antes de arreglar: en el código, con `hasCompletedOnboarding` en `true` (lo pone `onAdoptStarted`), ningún camino conocido reabre el elector; el defaults del teléfono tras la prueba lo tiene en `true`. Se instrumenta con logs DEBUG y se reproduce con el Google de Jürgen (05:00+; la regla nocturna impide preguntar antes).
Por qué: arreglar a ciegas una navegación de 3.800 líneas es inventar la causa. Alternativa descartada: forzar `showWelcomeFlow = false` tras «Empezar» — taparía el síntoma sin saber quién lo enciende.

**D4 · Verificación del crash** → En el iPhone 14 con Yala Dev de esta rama: cerrar sesión en la nube con red, sin crash y aterrizando en el Welcome; antes = vídeo del QA del 5-nov.
Por qué: el simulador monta con espejo y salta el cambio en caliente (regla de swiftui-ds); solo el teléfono lo ejerce.
