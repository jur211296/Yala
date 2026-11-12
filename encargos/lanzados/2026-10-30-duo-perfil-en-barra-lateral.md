---
esfuerzo: high
release: no
---
# Duo abierto: el botón de perfil pasa a la barra lateral y el contenido usa todo el alto

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `duo-perfil-en-barra-lateral` · Sesión cola **S29c** · al cerrar → **S29d** (`notificaciones-grupos-revision`).

## Contexto
Jürgen (2026-10-30), mirando el simulador Duo: en Duo abierto (y en iPad cuando se usa la barra lateral) el avatar de perfil sigue arriba a la derecha y deja una franja que impide usar todo el alto de la pantalla.

Card:
- `tablero ver tablero-duo-abierto-el-boton-de-perfil-pasa-a-la-a5kf`

## Qué se pide
1. En Duo abierto, y en iPad con barra lateral, el botón de perfil va en la barra lateral junto a la bandeja y «…», con su badge.
2. Se quita la franja de arriba y el contenido sube hasta arriba, usando todo el alto.
3. En iPhone, o en Duo cerrado, no cambia nada.
4. Capturas antes y después en los simuladores Duo e iPad, claro y oscuro, en `capturas/`. Agrega un test de UI si es viable.
Ojo: la sesión de capturas de App Store usa el simulador; esta va después de ella en la cola. No arranques si sigue viva.
Al abrir el PR, pasa la card a «in qa» de Jürgen.

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

## Ya hecho por la sesión anterior (no repetir)
El parpadeo al entrar a Grupos y las 3 propuestas de rediseño de Grupos ya los resolvió la sesión `grupos-hero-neto-moneda-principal` (PR #703, en cola de merge a 2.2). No los toques en esta sesión.

## Ya está hecho para el Duo cerrado: extiéndelo al abierto (Frank revisó el código, 2026-10-30)

El commit 6157abd47 (PR #624, «iPhone Duo cerrado — avatar en la barra vertical y nada detrás de ella») ya resolvió esto, pero solo en ancho compacto: `ProfileToolbarItem` lleva `.joinsVerticalBar(horizontalSizeClass == .compact)` y el mensaje del commit dice «abierto en horizontal se queda como estaba». Jürgen (2026-10-30): el Duo abierto debe seguir las MISMAS directrices que el cerrado (opción 2: avatar y botones de la página en la barra vertical, ceden las pestañas si no cabe todo, Regla A: nada de lo que se desplaza pasa por detrás de la barra). El arreglo esperado es quitar la condición de ancho compacto y decidir por la presencia de la barra vertical (`\.toolbarVerticalEdge != nil`, ver `ToolbarVerticalBar.swift` y `.claude/rules/swiftui-ds.md`), y revisar las demás condiciones `.compact` de ese commit (`prefersToolbarItemsInVerticalBar`, `staysOutOfVerticalBar`, `hiddenInVerticalBar`). Verifica en las cuatro posturas del Duo (guía en `.claude/agent-memory/frank/reference_montar_el_simulador_del_duo.md`) y en iPad con barra lateral; el iPhone normal debe quedar con 0 px de diferencia.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
El layout de iPhone, el contenido de las vistas y la pantalla de perfil en sí. Ninguna otra sesión Yala; ningún otro PR ni rama.

## Cómo se sabe que está bien
En Duo abierto e iPad con barra lateral, el perfil y su badge están en la barra lateral y el contenido llega hasta arriba. iPhone queda igual. Hay capturas y tests verdes, review adversarial del diff y PR a 2.2 con auto-merge.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico): no lo hagas; crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
Al cerrar, Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Criterio: presencia de barra vertical, no el ancho.** `joinsVerticalBar()` (avatar) y
   `toolbarVerticalCompressionBehavior(.prefersToolbarItems)` (páginas) van sin condición: solo actúan donde hay
   barra vertical. Sin `if`, sin cambiar de identidad. `staysOutOfVerticalBar`, `hiddenInVerticalBar`,
   `fadesTowardVerticalBar` y `extendsUnderVerticalBar` ya decidían por `toolbarVerticalEdge`: no se tocan.
2. **iPad: sin cambios (conservadora).** Medido: el iPad no tiene barra vertical (es del Duo) y su barra lateral es la
   de pestañas; arriba siguen la bandeja, Filtros y Configurar, así que mover solo el avatar no quitaría la franja.
   Qué hacer en el iPad es diseño: card `cierra-sola` a Jürgen con capturas.
3. **Páginas con lista y detalle (Grupos, Registros, Planificación)**: el avatar va en la barra de la columna de lista,
   que el sistema deja horizontal; no hay franja aparte y no se fuerza nada.
4. **Test de UI**: invariante «el avatar va en la misma barra que la bandeja» (misma fila o misma columna) en el
   Panel. En el iPhone del CI pasa por la fila; en el Duo abierto en horizontal es el que discrimina (por UDID).
5. **Verificación**: Duo en cuatro posturas antes/después, iPad horizontal y iPhone 17 Pro al píxel contra la base.
