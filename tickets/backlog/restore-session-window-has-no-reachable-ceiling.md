---
id: restore-session-window-has-no-reachable-ceiling
status: backlog
priority: medium
area: "icloud, restore, sesiones"
created: 2026-09-21
source: "review adversarial de `leaving-and-reentering-restore-renews-the-hard-cap`, 2026-09-21 — se implementó un techo y la review lo tumbó midiendo sus dos mitades"
---

# La ventana de sesión del restore no tiene techo alcanzable

## El problema, en lenguaje de usuario

No hay síntoma para el dueño legítimo. Quien tiene en la mano un teléfono con los datos de otra
persona puede mantener abierta —todo el tiempo que quiera— la ventana que permite entrar en la cuenta
sin que la app avise de que ese corpus es ajeno. No hay un número que lo limite.

## Medido (2026-09-21): por qué el techo obvio no funciona

`leaving-and-reentering-restore-renews-the-hard-cap` cerró la mitad monótona del agujero: el re-ancla
ya exige una descarga VIGENTE, no una histórica. Su tercer criterio pedía además **un techo acotado y
medible**, y ahí se implementó uno —`reanchorChainStartedAt`, el reloj de la cadena de re-anclas, que
ningún re-ancla movía— que **la review tumbó midiendo sus dos mitades**. Se retiró antes de commitear.

### Mitad 1 · No acotaba, porque `noteRestoreFinished` es alcanzable desde la UI con el import vivo

Recorrido medido, tres toques y sin esperar nada:

1. En `.restore` con la ventana abierta, estado `.importIncomplete` o `.found` —los dos ofrecen
   «Empezar desde cero» (`WelcomeRestoreView:560` y `:381`).
2. «Empezar desde cero» → confirmar. Su confirmación llama a `noteRestoreFinished`
   (`WelcomeRestoreView:222-225`), que apaga la ventana **con el import todavía bajando** — y apagaba
   también la cadena. Después, `onStartFresh()` → `FullModeActivationView:216` `go(to: .restoreDiscardGate)`.
3. En la puerta, «Volver» → `FullModeActivationView:174` `go(to: .restore)`. **La puerta solo pregunta:
   no ha borrado nada.**
4. Remonta `WelcomeRestoreView` → `.task { startSearch() }` → `restoreStartedAt == nil` ⇒ **ventana
   nueva de 600 s**, y con el techo puesto, cadena nueva también.

En `ContentView` el bucle es el mismo (`:902` → `WelcomeFlowContainer:264-267`).

**Y hay un baseline por debajo que ningún techo puede tocar**: la señal vive en memoria a propósito
—su sesgo fail-closed—, así que **matar la app y volver a entrar estrena todo**.

### Mitad 2 · Y sí bloqueaba al dueño legítimo, de forma permanente en el proceso

Con el techo puesto:

- `t=0` entra a Restaurar con un corpus de 15 minutos. `restoreStartedAt = 0`, cadena `= 0`.
- `t=100` toca atrás → la ventana queda huérfana (el reloj sigue puesto: el import baja).
- `t=650` vuelve: `chainAge ≥ 600` ⇒ no re-ancla, hereda `restoreStartedAt = 0`; `elapsed ≥ hardCap`
  ⇒ `isRestoringNow == false` ⇒ **`.blockedForeignData` sobre su propia cuenta con sus datos bajando**.

Y peor: a partir de ahí **nada vuelve a armar la cadena en ese proceso**. Con `restoreStartedAt != nil`
la rama del estreno no corre, y la única que lo limpia es `noteRestoreFinished`, que en ese desenlace
(`!settled && sawImport`) no se llama por diseño. No es «una ventana cada 600 s»: es **una
oportunidad, y solo una**, hasta que la persona mate la app.

⇒ El techo **no frenaba a quien quisiera saltárselo y sí castigaba a quien no**. Por eso se retiró en
vez de apuntalarse.

## Lo que haría falta para que un techo signifique algo

Cualquier intento tiene que empezar por cerrar —o aceptar— las dos puertas libres:

- **El estreno** (`restoreStartedAt == nil`) es la puerta grande y tiene que seguir abierta: es lo que
  hace útil la señal. Un techo que viva dentro de `noteRestoreStarted` no puede acotarla.
- **`noteRestoreFinished` desde la UI**: hoy lo llaman la pantalla de progreso y la confirmación de
  «Empezar desde cero». La segunda es la del recorrido de arriba.

Tres caminos posibles, ninguno decidido:

1. **Un presupuesto de tiempo abierto por PROCESO**, leído dentro de `isRestoringNow` en vez de en el
   re-ancla. Acota también los estrenos, y por eso hay que medir antes a quién deja fuera: tocaría el
   corazón del guard.
2. **Que volver desde la puerta de descarte NO estrene**, distinguiendo «volví sin descartar» de una
   entrada nueva. Cierra el recorrido de tres toques y deja intacto el baseline de relanzar.
3. **Aceptar que no hay techo y declararlo**, apoyándose en que el baseline de relanzar la app lo hace
   inalcanzable de todos modos, y gastar el esfuerzo en que la ventana sea más estrecha por otras vías.

## Criterios de aceptación

- [ ] El recorrido «Empezar desde cero» → «Volver» → Restaurar no estrena ventana nueva, **o** está
      escrito por qué se acepta que lo haga.
- [ ] Ningún camino deja al dueño legítimo sin poder abrir ventana durante el resto del proceso
      (la mitad 2 de arriba no se reintroduce).
- [ ] Lo que se elija se mide con un test que recorra el ciclo completo, incluido el paso por
      `noteRestoreFinished`.

## Relación con otros tickets

- `leaving-and-reentering-restore-renews-the-hard-cap` — de donde sale; cerró la mitad monótona.
- `abandoned-restore-no-longer-clears-the-session-window-clock` — el re-ancla que no se puede deshacer.
- `restore-timeout-closes-the-session-window-with-the-import-still-running` — la misma familia por el
  eje del desenlace.
