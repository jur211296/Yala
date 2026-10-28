# Estadísticas: chips de pestaña a tirones y mes que se solapa

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: high.
Slug: `estadisticas-chips-animacion` · Sesión cola **S12c** · al cerrar → **S12d**.

## Encargo
Cumple **íntegramente** el brief per-card:

`~/Claude/tmp-frank/estadisticas-chips-animacion-6l5n.md`

Léelo y ejecútalo tal cual. Vídeo del antes: `~/Claude/entregas/Yala--bugs-animacion-2026-10-27/chips-estadisticas.mp4`.

## Qué NO tocar
Lo que diga el brief. Además: no lanzar otras sesiones Yala; no tocar marketing/ ni Web/.

## Cómo se sabe que está bien
El criterio del brief + PR a 2.2 cuando aplique.


## Entrega para barrido iOS 27 (S27c)
Jürgen 2026-10-27: al cerrar, deja **documentado en el PR/resumen** el motivo de los tirones y qué objetos visuales no estaban bien optimizados para iOS 27 (API, modificador, layout, animación). Eso desbloquea la sesión **S27c** (barrido en todas las secciones), más abajo en la cola. No hace falta arreglar otras secciones aquí.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

## Paso 0 — decisiones (resueltas en autónomo (bypass))

1. **¿Dónde se arregla la fila de chips?** En el componente compartido `NavigationChipButton` (cápsula recortada, nombre que entra fundido y sale en el acto) + un cambio en dos tiempos opcional (`switchTab`, `animatesSwitch`) que **solo usa Estadísticas**. Planificación, Reportes y Grupos no lo llaman y siguen sin animación: el encargo es Estadísticas y el barrido de las demás es S27c.
2. **¿Por qué en dos tiempos y no una animación sin más?** Medido: montar una pestaña congela la pantalla 0,12–0,27 s en el iPhone de Jürgen; una animación a la vez se consume entera durante el bloqueo. Primero se anima la fila, al terminar se monta la pestaña (~0,25 s después).
3. **¿Se quita el apagado global de animaciones de `ContentView`?** No. Es de toda la app (2026-01-15) y quitarlo cambiaría animaciones de todas las pestañas. El control del período se anima con `.animation(_:value:)` propio, que actúa por debajo. Queda documentado para S27c.
4. **Píldora del período:** se pinta fuera del `Menu` (el label de un `Menu` no anima) y el `Menu` va encima, transparente. Coste asumido: la píldora pierde el brillo de pulsación del cristal; el menú se abre igual.
5. **Título:** el viejo sale en el acto y el nuevo entra deslizándose desde el lado de la flecha (desde el menú, fundido). Sin cruce.
6. **`GlassEffectContainer`:** probado y descartado (rompía la animación de ancho y fundía chips al pulsar).
7. **Reducir movimiento:** cambio instantáneo, sin desplazamientos; el nombre y la fecha aparecen con fundido.
8. **QA del iPhone:** la animación se verificó en el simulador fotograma a fotograma; la sensación real a 60 fps se valida en el teléfono → card a `in qa` con guion corto.
