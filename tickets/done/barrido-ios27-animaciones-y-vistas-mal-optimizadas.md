---
id: barrido-ios27-animaciones-y-vistas-mal-optimizadas
status: done
priority: low
area: "groups, ui-animaciones"
created: 2026-10-29
updated: 2026-10-30
source: "tablero yc6k (Jürgen, 2026-10-27), encargo 2026-10-29-barrido-ios27-animaciones (S27c)"
qa-status: needs-testing
---

# Barrido iOS 27: animaciones y vistas mal optimizadas

## Patrón que guía el barrido

Tomado de los dos hallazgos ya mergeados, sin inventar uno nuevo:

- **S12c, PR #656** (chips de Estadísticas), regla en `.claude/rules/swiftui-ds.md` § «Animar dentro de una pestaña»:
  1. `ContentView` apaga la animación de toda transacción que cruza el `TabView`: dentro de una pestaña, `withAnimation`
     no anima.
  2. Una fila de chips que cambia de ancho y monta una pestaña pesada a la vez se come la animación: el chip salta
     «a tirones». Arreglo: `NavigationChipButton.switchTab` + `animatesSwitch` (la fila primero, la pestaña al terminar).
  3. El label de un `Menu` no se anima.
  4. Un `Text` que cambia de valor con animación se funde con el anterior.
  5. `GlassEffectContainer` alrededor de chips que cambian de ancho rompe la animación.
- **S12d, PR #662** (Welcome): una `NavigationStack` por paso, y la pantalla que sale pintada por debajo del fondo opaco.

## Secciones recorridas y veredicto

| Sección | Qué se miró | Veredicto |
|---|---|---|
| **Grupos (detalle de grupo)** | Fila de chips Gastos · Saldos · Estadísticas | **El mismo salto que Estadísticas** (S12c lo dejó apuntado). Medido en vídeo: el chip cambiaba de ancho en un fotograma. **Arreglado** |
| Estadísticas | Chips y período | Ya arreglado en S12c |
| Planificación, Reportes | Fila de chips | No aplica: enseñan el nombre en todos los chips, así que no cambian de ancho; solo cambia el color, en el acto |
| Panel | Chips de filtros (`PanelFilterControlBar`, dentro de `GlassEffectContainer`) | No es el caso de S12c: los chips no cambian de ancho al tocarlos y el morphing es a propósito. Sin tocar |
| Panel | Tarjeta de cambio de divisa (`FXPnLCard`) | Candidata al punto 4: `.animation(…, value: summary)` cubre también los importes. Sin semilla para medirla: apuntado, sin tocar |
| Panel, Informes, Grupos | Píldora del período (label de `Menu`) | Sin `titleMotion` cambia sin animación, en el acto: no hay salto a medias. Sin tocar |
| Registros, Flujo de caja | `.animation` implícitas | Barras y números con `.contentTransition(.numericText())`: no es el patrón |
| Welcome / onboarding | Pila por paso, fondo opaco | El Welcome ya está arreglado (S12d). `OnboardingView`, `GroupInviteOnboardingView` y `WelcomeRestoreView` llevan **una** pila y cambian de paso sin transición. «Activar Yala completo» ya tiene card (`p48h`) |
| Toda la app | `.transaction { $0.animation = nil }` en `ContentView` | **No se toca aquí**: es de toda la app (entró el 2026-01-15 contra un parpadeo de hojas y pestañas temporales). Deja sin efecto unos 45 `withAnimation` dentro de las pestañas (banners, avisos, plegados). Card `1yhi` (decide Jürgen) |

## Qué se hizo

- `GroupDetailView`: la fila de chips cambia en dos tiempos, como en Estadísticas. `chipsSelection` (lo que pinta la
  fila) va aparte de `selectedTab` (lo que monta la pestaña) y la sigue cuando cambia desde fuera de la fila (tocar el
  saldo, «Ver los saldos» desde Ajustes o Miembros). Con Reducir movimiento cambia en el acto, como antes.
- Comentario de `NavigationChipButton` y regla de `swiftui-ds.md` al día.

Vídeos y hojas de fotogramas: `~/Claude/entregas/Yala--barrido-ios27-animaciones/` (`antes.mp4`, `despues.mp4`,
`antes.png`, `despues.png`).

## Guion de QA (iPhone, Yala Dev, ~1 min)

1. Abre Yala Dev → pestaña **Grupos** → entra en un grupo.
2. Toca **Saldos** (el icono de las flechas), luego **Estadísticas** (el del gráfico), luego **Gastos**.
   - Esperado: el chip nuevo se ensancha y el viejo se encoge en un movimiento continuo; la pestaña aparece al
     terminar (~0,25 s). Antes cambiaban de un fotograma al siguiente.
3. Vuelve a **Gastos** y toca la cifra del saldo de arriba («En este grupo te deben…»).
   - Esperado: pasa a Saldos y el chip «Saldos» queda elegido.

Cerrado en el barrido de QA 2026-10-30: criterio estricto (filtro doble); motivo y evidencia en docs/qa/tanda-qa-jurgen-2.2-barrido-2026-10-30.md.
