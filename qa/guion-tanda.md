# Guion de la tanda de QA

> **Qué es esto.** Los tickets de `tickets/qa/` no se drenan de uno en uno: se acumulan y se hacen
> juntos (decisión del owner, 2026-09-03). Este guion los agrupa **por montaje**, que es donde está el
> ahorro — siete de ellos necesitan dos teléfonos, y montar eso una vez en lugar de siete es la mitad
> del trabajo de la tanda.
>
> **Actualizado: 2026-09-03 · 20 tickets.** Al mover algo a `qa/` o sacarlo de ahí, actualiza también
> este guion; si no, en dos semanas manda a montar cosas que ya no hacen falta.
>
> `qa` NO significa «terminado»: significa que el código está hecho y verificado hasta donde el
> simulador alcanza, y que falta la comprobación en aparato real.

## Orden recomendado

Por montaje, de menor a mayor coste de preparación. **Los grupos C y D no necesitan nada especial y se
pueden hacer en cualquier rato**; los grupos A y B piden preparar aparatos, así que conviene juntarlos
en una sesión sola.

---

## Grupo A · Dos teléfonos con TestFlight (7 tickets)

**Montaje único para los siete**: dos aparatos con TestFlight, dos cuentas distintas (A y B), la misma
build. App Attest está en `enforce`, así que **nada de esto sale en simulador ni en build de Xcode** —
ése es el motivo de que lleven aquí y no se hayan podido cerrar antes.

**Prepara antes de empezar:** `wrangler tail --env production` corriendo en una terminal. Es la señal
más barata para los tres de notificaciones, y sin ella un fallo silencioso del servidor no se distingue
de uno de entrega.

| Ticket | Qué comprobar |
|---|---|
| `aviso-de-nuevo-miembro-no-llega-hasta-abrir-la-app` | B pide entrar al grupo de A → **a A le llega el banner con la app cerrada** |
| `groups-expense-notif-only-on-foreground` | A crea un gasto → **a B le llega con la app en segundo plano**, y también con la app matada |
| `invite-backend-stale-config` | El enlace funciona aunque el aparato tenga la configuración vieja cacheada |
| `scheduled-payments-notif-dedup` | Varios pagos el mismo día → **una sola** notificación, a la hora configurada |
| `siri-intent-dual-container` | El atajo de Siri escribe donde debe |
| `storekit-appgroup-siri-pro-gate` | El gate Pro del atajo — **sus pasos 1 y 2 ya están corridos**, mira el ticket antes de repetirlos |
| `applepay-shortcut-warm-launch-empty-data` | Tras la automatización de Apple Pay, la app NO queda vacía |

**Dos avisos medidos que ahorran una tarde:**

- Si el banner no llega, **antes de sospechar del servidor** mira `Ajustes → Yala → Notificaciones` en
  el receptor: el único ticket cerrado del repo sobre esto era el permiso apagado, y APNs devuelve 200
  igualmente. No hay forma de distinguirlo desde el servidor.
- **`PUSH_ROLE_JWT` está configurado en producción** (verificado el 2026-09-03). Si el fan-out no sale,
  no es por eso — esa hipótesis ya está descartada en el ticket.
- El rate-limit de avisos de grupo es de **5 minutos por grupo**, y persiste entre arranques: dos
  pruebas seguidas parecerán «no llegó» cuando lo que hubo es un colapso por diseño. Espera entre
  intentos y anota las horas.

---

## Grupo B · Móvil prestado (4 tickets)

**Montaje único**: un aparato, dos cuentas — la del dueño y una visita que entra con la suya.
`SECONDARY_SESSION` está al **0 %** en producción, así que hay que abrir el recorrido a mano.

| Ticket | Qué comprobar |
|---|---|
| `secondary-groups-off-wipes-owner` | La visita **no puede borrar los grupos del dueño**. Recién arreglado; el ticket trae receta de repro |
| `prefs-domain-per-secondary-session` | Los ajustes de la visita no pisan los del dueño |
| `widget-snapshot-visitor-overwrites-owner` | El widget no se queda con los números de la visita |
| `groups-consent-door-spec` | El consent de Grupos viaja con la cuenta, no con el aparato |

---

## Grupo C · Simulador · el recorrido de bienvenida (3 tickets)

**Un solo recorrido cubre los tres.** Abre la app con datos previos en el teléfono y recorre
«Empezar» → «Es mi primera vez», probando cancelar en cada punto.

| Ticket | Qué comprobar |
|---|---|
| `welcome-fresh-start-alert-leaves-blank-screen` | Cancelar el alert **devuelve al selector**, no a una pantalla en blanco |
| `welcome-start-fresh-wipes-before-ask` | No se borra nada antes de preguntar, y si el borrado falla te enteras |
| `welcome-copy-blames-owner` | El texto no acusa a la dueña de traer datos ajenos. **Su residual necesita SIWA real**, así que esa parte se va al grupo A |

---

## Grupo D · Simulador con datos (6 tickets)

Sin montaje especial. Necesitan una cuenta con **cuentas en dos monedas** y un histórico de varios
meses, así que siembra primero.

| Ticket | Qué comprobar |
|---|---|
| `fx-partial-rate-rows-silent-1to1` | Los tres criterios del ticket. **Necesita red y un histórico real de tasas**: es el más exigente de este grupo |
| `undercount-dias-intervalos-cerrados` | En «mes pasado», el promedio diario y el gasto por día de la semana cuadran con los días reales del mes |
| `registros-calendario-cuenta-gastos-por-signo` | El calendario de Registros cuadra con el resto de la app |
| `cloud-fx-rates-blob-two-faces` | Las tasas sobreviven al viaje por la nube |
| `prefs-synced-keys-upload-not-download` | Los ajustes que suben, vuelven |
| `update-banner-appstore-criteria` | El banner de actualización, con sus criterios |

---

## Al terminar cada ticket

- **No inventes un PASS.** Si no se pudo comprobar, se dice qué faltó y se queda en `qa/`.
- Lo verificado se mueve a `tickets/done/` con su evidencia, y se actualiza `docs/TICKETS.md` (los
  conteos y la fila) — el índice se comprueba con un diff contra el disco, no a ojo.
- Si tocaste código para arreglar algo, `lastVerified` del área en `qa/coverage-index.json` va en el
  **mismo commit**.
