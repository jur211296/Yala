---
updated: 2026-09-02
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-02 (Lima)

**Rama** `2.1` · **HEAD** `80880f2d` — *PR #61: rediseño visual del Panel*.
TestFlight build **12** (CPV 12). **Subida Yala (TF/store) = solo Mini.**

## Esta sesión
Rediseño visual del Panel contra Wise (PR #61). La jerarquía **iba al revés**: sección y widget
usaban el MISMO token y el nombre de la fila era el rótulo mayor. Sección a `title3`, aire invertido
(secciones 12→32, título a contenido 16→8) y color solo donde informa: barras al 22 % (**−60 %** de
superficie cromática) y **el gasto deja de teñirse** —ninguno de los cinco tonos llega al AA de 4,5
sobre tarjeta blanca—. El hero pierde el saludo y sus dos ejes; las acciones bajan al flujo y los
flotantes solo vuelven cuando el scroll se lleva la fila. Antes: aviso a Grok en push directo (#60).

## Abiertos
- **`welcome-fresh-start-alert-leaves-blank-screen`** (backlog, **high**) — «Es mi primera vez» +
  cancelar deja la app sin salida salvo matarla. Preexistente, **en producción**.
- **`scheduled-payment-once-labeled-monthly`** (backlog, low) — badge cosmético.
- **`AUDIT-appstore-guidelines.md`** — 3 hallazgos de riesgo de rechazo (OpenAI). De Lola.

## Release 2.1 (sin cambios)
2.0.5 no se lanza; release = 2.1. A7 y M5: **HOLD, no flip**. Prod: CLOUD_MODE 100 · GROUPS_BACKEND
100 · CLOUD_ONBOARDING_CHOICE 0 · SECONDARY_SESSION 0. Cola C: 9 ACs owner/device, no corrida; D-R1
sigue sin `ok_`. **Cero `ok_` inventado.**

## Siguiente
Commitear lo de esta sesión (sin commitear aún; `/gate` pendiente). Del Panel quedan dos:
«Últimos registros» se sigue diciendo dos veces —el rediseño lo hace más visible— y bajar los
nombres de fila a 15 tocaría Estadísticas. **Zanjados hoy:** el trailer `Co-Authored-By` no va, ni
en commits ni en PR (Jürgen ratificó su regla de mayo, medida; los 11 que ya lo llevan no se
reescriben); y el rojo de `.thisWeek` — el test era el equivocado, 15/15 en verde, ver
`[2026-08-17]` en DECISIONS. Abierto nuevo: quinta instancia del `DateInterval` cerrado
(`PreviousPeriodHelper:112` + `InsightsCalculator`), ticket sin crear.

## Bloqueo
Ninguno.
