---
esfuerzo: medium
release: no
---
# Quitar el hero celeste de Grupos, dar a las tarjetas de gráficas de Flujo de caja y Comparativa el fondo de tarjeta de la app, y centrar el Welcome como el onboarding

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Slug: `grupos-blanco-graficas-welcome-centrado` · al cerrar → **S28tf** (`subida-testflight-2-2-5`).
Card: `tablero ver tablero-grupos-en-blanco-sin-hero-celeste-fondo-bvpn` (referencias: e7by Flujo de caja, k2up Grupos, i00g onboarding/Welcome).

## Contexto
El barrido de QA 2.2 (PR #699) le pidió a Jürgen 6 vistos buenos de diseño. Fotos en `~/Claude/worktrees/_capturas/2026-10-30-barrido-qa-2-2/` (mira `p5-una-sola-yala-e7by-k2up/` y `p6-onboarding-estilos-i00g/`). El 30-oct 12:15 (Lima) aprobó 1–4 y pidió cambios en 5 y 6. Sus palabras textuales:

- Pregunta 5 (Grupos y Flujo de caja como parte de la misma app; cards e7by, k2up): «¿por qué usamos hero color celeste? se ve feo. Blanco nomás estaría bien en todo Grupos. Y las gráficas dentro de flujo de caja o comparativa, no sé cuáles son, el fondo de las cards es gris, no es el que debería ser».
- Pregunta 6 (estilos nuevos del Welcome y onboarding; card i00g): «sí, mejor centrado todo como el onboarding».

## Qué se pide
1. **Grupos en blanco.** Quitar el hero/tinte celeste en TODAS las pantallas de Grupos. Fondo blanco/de sistema como el resto de la app, respetando el modo oscuro (fondo de sistema, no un blanco fijo).
2. **Fondo de las tarjetas de gráficas.** Localizar en código qué tarjetas de gráficas de Flujo de caja y de la Comparativa usan fondo gris y ponerles el mismo fondo de tarjeta que el resto de la app. Usar el token/estilo existente, no un color nuevo. Anotar en el PR qué tarjetas eran.
3. **Welcome centrado.** Centrar el Welcome (hero, chooser y cuenta existente) con las mismas alineaciones del onboarding.
4. Capturas antes/después, en claro y en oscuro, de cada pantalla tocada, en `capturas/` del worktree, con las rutas en el resumen.
5. Tests en verde (unitarios + los UI tests que cubren estas pantallas; ajusta snapshots/aserciones solo si el cambio es el pedido).
6. Review adversarial del diff antes de abrir el PR.
7. Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.
8. Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.
9. PR a 2.2 con auto-merge. Card a «in qa» de Jürgen con las capturas para su visto bueno.

## Qué NO hay que tocar
- Nada fuera de Grupos, las tarjetas de gráficas de Flujo de caja/Comparativa y el Welcome.
- Sin colores ni tokens nuevos. Sin cambios de copy ni de flujo.
- Sin decisiones vitales: si algo es ambiguo, elige lo más consistente con el resto de la app y déjalo anotado en el PR y en la card.

## Cómo se sabe que está bien
Grupos sin celeste en claro y oscuro; las gráficas con el mismo fondo de tarjeta que el resto; el Welcome centrado como el onboarding; capturas antes/después; tests en verde; PR en cola de auto-merge a 2.2.

Termina con /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Qué es el «hero celeste» de Grupos.** Medido: Grupos (lista y detalle) monta `.yalaScreenBackground(.panel)`, el degradado del tema (acento → negro en los temas oscuros; blanco → índigo 10 % en el claro). Es lo único que tiñe la pantalla; `GroupBalanceHero` no tiene fondo propio. ⇒ Grupos pasa a `.subtle` (`theme.background` plano: #FAFBFF en claro, el negro del tema en oscuro). Token existente, respeta el modo oscuro. Las vistas empujadas desde el detalle heredan; las hojas ya eran `.subtle`.
2. **Qué tarjetas de gráficas son «grises».** Comparativa de Reportes es una tabla, sin gráficas. Las gráficas de Flujo de caja viven en la hoja «Gráficas» (`CashFlowChartsSheet`). Se decide tras medir en simulador claro/oscuro; la corrección usa un token existente.
3. **«Centrado como el onboarding».** El onboarding centra icono, titular y subtítulo, y deja las filas de opción alineadas a la izquierda dentro de su tarjeta. ⇒ En las pantallas de entrada del Welcome (`WelcomeFormScreen`: chooser, «Ya tengo una cuenta», «Es mi primera vez», «Vengo por un grupo», intro de la nube) se centran titular, subtítulo, la ayuda «¿No te acuerdas?» y las etiquetas/notas de la tarjeta; las filas de opción siguen como las del onboarding. El Hero ya está centrado.
4. **Capturas:** conductor XCUITest local (no se commitea), temas «Claro» (1) y «Liquid Glass» (8, el de fábrica) como claro/oscuro.
