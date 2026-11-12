# Barrido iOS 27: animaciones y vistas mal optimizadas

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: high.
Slug: `barrido-ios27-animaciones` · Sesión cola **S27c** · al cerrar → **S27e** (eficiencia-carga-por-vista).

## Encargo
Cumple **íntegramente** el brief per-card:

`~/Claude/tmp-frank/barrido-ios27-animaciones-yc6k.md`

Léelo y ejecútalo tal cual. Si el brief dice «para y deja nota en la card» (patrón de S12c no documentado), no te detengas: usa como guía lo que encuentres en el PR #656 / card yc6k, documenta en la card qué patrón tomaste, y sigue el barrido. Solo tras el hallazgo documentado de S12c (chips); S12d si aporta.

## Qué NO tocar
Lo que diga el brief. Además: no lanzar otras sesiones Yala; no tocar marketing/ ni Web/.

## Cómo se sabe que está bien
El criterio del brief + PR o informe a 2.2.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

## Noche autónoma (Jürgen 2026-10-29 22:18 Lima: «que la noche fluya sin pedirme inputs»)
- Se lanza con `--permission-mode bypassPermissions`. No uses AskUserQuestion ni esperes respuesta de Jürgen: es de noche (21:00–6:00).
- Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en el ticket/card y en el PR, y sigue.
- Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico, firma/2FA): no lo hagas; crea una card separada con `cierra-sola` asignada a jurgen explicando la decisión pendiente, termina el resto y cierra.
- Git: haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.
- Termina siempre con `/cerrar-total`.

/cerrar-total

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **¿Hay patrón documentado?** Sí: S12c (PR #656, regla en `.claude/rules/swiftui-ds.md` § «Animar dentro de una
   pestaña») y S12d (PR #662, pila única del Welcome + `zIndex`). No hace falta parar.
2. **¿Qué se arregla?** Solo los casos claros del mismo patrón. El único claro es **Grupos (detalle de grupo)**: misma
   fila de chips que cambia de ancho, sin `switchTab`; S12c lo dejó apuntado. Se adopta `switchTab` + `animatesSwitch` y
   una `chipsSelection` aparte, como Estadísticas.
3. **¿Se quita el apagado global de `ContentView` (`.transaction { $0.animation = nil }`)?** No. Es de toda la app,
   entró en enero contra un parpadeo de hojas y pestañas temporales y reactivaría ~45 `withAnimation` a la vez. Opción
   conservadora: card aparte para Jürgen con la decisión y cómo medirla.
4. **Planificación y Reportes**: no se tocan. Enseñan el nombre en todos los chips; no cambian de ancho.
5. **Chips de filtros del Panel en `GlassEffectContainer`**: no se tocan. No cambian de ancho al pulsar; el morphing es
   a propósito.
6. **`FXPnLCard`** (importes animados por valor): candidata al punto «Text que se funde», sin semilla para medirla. Se
   apunta en el informe, sin tocar.
7. **Planes de prueba**: vídeo antes/después en el simulador con un conductor XCUITest temporal (no se commitea); gate
   con las suites de Grupos que tocan sus chips.
8. **Ticket**: `tickets/qa/barrido-ios27-animaciones-y-vistas-mal-optimizadas.md` con el informe por sección y guion de
   iPhone (la sensación a 60 fps se valida allí; no frena el merge).
