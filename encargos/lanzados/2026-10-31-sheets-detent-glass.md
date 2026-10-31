---
esfuerzo: medium
release: no
---
# Todos los sheets en detent medium se ven glass, como «Configurar panel»

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `sheets-detent-glass` · Sesión cola **S35b** · al cerrar → **S35c** (`panel-ultimos-registros-sin-hueco`).

## Contexto
Jürgen (2026-10-30): los sheets en detent medium salen con fondo gris sólido en vez de glass. Vistos: selectores de Cuenta y Categoría en Nuevo gasto de Grupos y selector de cuenta en Yala IA. No debe pasar en ninguna parte. Referencia correcta: el sheet de «Configurar panel» en Panel.

Cards:
- `tablero ver tablero-sheets-de-selector-en-detent-medium-sale-g1uw`

## Qué se pide
1. Mira cómo está hecho «Configurar panel» y extrae el patrón (modificador compartido si no existe).
2. Barre TODOS los `.sheet`/`presentationDetents` de la app y aplícalo donde haya fondo gris o `presentationBackground` sólido, en medium y large, claro y oscuro.
3. Regla nueva en `.claude/rules/swiftui-ds.md` y en la guía de diseño: ningún sheet con fondo gris; siempre el patrón de «Configurar panel».
4. Capturas antes/después de cada sheet en `capturas/`.
Al abrir el PR, cards a «in qa» de Jürgen si hay algo que mirar en dispositivo, o a «done» si no (con `--agente` de la sesión).

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
Contenido de los sheets (solo fondo). Nada de marketing/ ni Web/. No lances otras sesiones Yala; ningún otro PR ni rama.

## Cómo se sabe que está bien
Lo de «Qué se pide» hecho, tests verdes, review adversarial del diff, PR a 2.2 con auto-merge y capturas en `capturas/` si el cambio se ve.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico): no lo hagas; crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
Al cerrar, Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir: «Configurar panel» (`PanelSectionsConfigView`, `PanelSectionPreferencesSheet`) **no pinta fondo de presentación**: deja el Liquid Glass del sistema y su raíz va `.yalaScreenBackground(isLargeDetent ? .subtle : .transparent)`. El gris de los selectores de Cuenta, Categoría, Etiquetas y Necesidad (Nuevo registro, Nuevo gasto de Grupos, «Detalles» de Yala IA, voz e imagen) sale de un único sitio: `SelectorSheetSizingModifier` pinta `.presentationBackground { Rectangle().fill(.thickMaterial) }` en `mediumFirst` (L2-22, 14-oct).

**D1 · ¿Modificador nuevo para «el patrón de Configurar panel»?** → No. El patrón es *no pintar* la presentación y elegir el fondo de la raíz por detent, y eso ya lo dan `.yalaScreenBackground(.partialSheet)` / `isLargeDetent ? .subtle : .transparent`. Se quita el material de `SelectorSheetSizing` y se aplica lo existente donde falte.
Por qué: un modificador que no hace nada nuevo sería otra forma de decir lo mismo. Alternativa descartada: `glassSheet()`, que pone `.ultraThinMaterial` y tapa el glass del sistema (es lo contrario de la referencia).

**D2 · L2-22 (material grueso para que no se lea el monto rosa detrás) contra la orden del 30-oct** → Manda la del 30-oct: glass en todas. Se anota como revertido y se pide mirarlo en el iPhone.
Por qué: Jürgen pidió «no debe pasar en ninguna parte» con la referencia explícita. Alternativa descartada: mantener material solo en el formulario de Nuevo registro — contradice el encargo.

**D3 · ¿Y en large?** → Como «Configurar panel»: `.subtle` (fondo del tema) al estirar. «Glass en medium y large» se lee como «mismo patrón en los dos detents», que es lo que hace la referencia.
Por qué: la referencia es la definición de correcto. Alternativa descartada: glass también en large — cambiaría la referencia misma.

**D4 · `glassSheet()` (sin usos)** → El código se queda; la regla deja de recomendarlo para hojas.
Por qué: borrar código fuera del alcance no se pidió; la regla es lo que evita que se reuse.

**D5 · «La guía de diseño»** → No hay guía de diseño en el repo (`UI-PATTERNS.md` vive en el vault, que no es SSOT). La regla va en `swiftui-ds.md`, sección «Backgrounds de vista», que es la guía del Design System de facto.
Por qué: CLAUDE.md: dos superficies, no cinco. Alternativa descartada: crear un documento nuevo.

**D6 · Capturas** → `~/Claude/worktrees/_capturas/sheets-detent-glass/` (sobrevive al retiro del worktree) con un conductor XCUITest temporal que no se commitea; copia en `capturas/` del worktree, sin commitear.
