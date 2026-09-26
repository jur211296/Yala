---
id: ipad-real-multiwindow-with-per-scene-state
status: backlog
priority: low
area: "platform, ipad, navigation, modo-nube"
created: 2026-09-26
source: "exploración iPad (docs/exploracion/ipad-nativo.md §5.4, §6.1 y §8, fase 4), 2026-09-26"
---

# iPad · fase 4: varias ventanas de verdad, con estado por ventana

**Tamaño L. Cuando haya demanda.** Toca lógica donde un bug sale caro (covers de cierre de sesión,
router): lleva review adversarial.

## Qué cambia para el usuario

Abrir un grupo, un registro o una sección en una ventana propia; tener Registros en una y
Estadísticas en otra; Split View y Stage Manager probados en iPad real.

## Qué hay que resolver

- **Navegación por ventana**: pestaña, modales y bandeja a `@SceneStorage` o a un estado por escena, no
  en `SessionState.shared`. `AppRouter` decide a qué ventana va cada intent (widget, enlace, Siri).
- **Covers terminales** (cierre de sesión, «Un momento más», swap de contenedor): se muestran en **todas**
  las ventanas a la vez. El swap ya remonta toda la jerarquía (`YalaApp.swift:90-97`); falta que ninguna
  ventana siga operando mientras otra enseña el cover.
- `WindowGroup(for:)` para abrir un grupo o un registro en ventana propia.
- Volver a encender `UIApplicationSupportsMultipleScenes` si
  [[ipad-multiple-windows-share-one-navigation-state]] lo apagó.

## Relacionados

- [[ipad-native-app]]. Depende de [[ipad-multiple-windows-share-one-navigation-state]].
