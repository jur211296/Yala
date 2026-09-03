---
updated: 2026-09-03
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-03 (Lima)

**Rama** `2.1` · **HEAD** `7a70f70f` — *la red de tests dejó de mentir*.
TestFlight build **12** (CPV 12). **Subida Yala (TF/store) = solo Mini.**

## Sesión nocturna (2026-09-02/03)
Siete commits. **Cuatro de los cinco defectos arreglados estaban en la RED DE TESTS, no en la app** —
la app estaba mejor de lo que el tablero decía, y la red peor.

- **El CI llevaba semanas en verde con ocho tests en rojo** (el más viejo, del 17-ago). Eran **tres
  causas**, no una: zona horaria (4), idioma del simulador (1) y un helper de aislamiento que borraba
  22 de los 31 modelos del schema (1). Más un **rojo real** de hace quince días que nadie vio: el
  escáner de `SplitGroup` tenía un hueco en su allowlist. Los `continue-on-error` **siguen puestos**;
  lo que se añadió es que el fallo deje rastro (aviso a Grok leyendo `outcome`, no `conclusion`).
- **La puerta de Grupos** ya no acusa a la dueña de traer datos ajenos mientras restaura de iCloud.
- **Cinco preferencias** dejan de subir a iCloud para no volver nunca.

## Te esperan a ti
1. **`hasCompletedOnboarding`: par escritor/lector partido** — el escritor va al dominio de la dueña y
   hay lectores en LOS DOS dominios. Apareció al medir; no estaba en ningún ticket. Dos salidas
   escritas en `secondary-visitor-writes-owner-domain`. **Es una decisión, no trabajo.**
2. **D4 · consent legacy (RGPD)** — decidido «custodiar y reponer», sin implementar. Al medirlo
   salieron dos riesgos que el ticket no traía: `GroupsConsentState` escribe en `.standard` a pelo
   (el dominio por sesión **no** lo cubrió) y la reposición cae en la ventana donde ya se documentó
   que un borrado mal dirigido arrasaría el `UserDefaults` entero de la dueña.
3. **Device-QA que sólo puedes hacer tú**: el residual de `welcome-copy-blames-owner` (SIWA con Apple
   ID real), y comprobar que las cinco prefs dejan de aparecer en el outbox y en el iKV.
4. **`gate.md`** dice «este repo es Swift Testing entero» — cierto para `YalaTests`, falso para
   `YalaUITests`, que es XCTest. Una línea de matiz, pero `.claude/` va por PR.

## Abiertos (sin cambios de anoche)
- **`ci-verde-con-la-suite-en-rojo`** — pasos 1 y 2 hechos. **3 y 4 sin hacer** por decisión: promover
  unit a bloqueante exige refutar el `EXC_BREAKPOINT`, y una corrida verde no lo refuta.
- **`welcome-fresh-start-alert-leaves-blank-screen`** (**high**, en producción) · **`invite-refresh-forzado`**
  (**high**) · **`aviso-de-nuevo-miembro`** (**high**, HOLD: tres remedios incompatibles, es tuya la
  elección) · **`canarios-y-breadcrumbs-sin-emisor`** · **`undercount-dias-intervalos-cerrados`**
  (~7-10 sitios reales de 33 candidatos; helper único ya elegido) · **`appstorage-onboarding-…`** ·
  **`scheduled-payment-once-labeled-monthly`** (low, el más barato del board).
- Los **2 de `blocked`** no esperan decisión ni código: esperan **hardware** (dos aparatos con el mismo
  iCloud; dos iPhones con TestFlight).

## Lo que cambió en cómo se mide
El mismo error de medición mordió **ocho veces en dos sesiones**: un filtro descarta lo que buscas y
la ausencia se lee como resultado. La peor variante es nueva y está documentada: **`-only-testing` con
el nombre del FICHERO no filtra** si las suites se llaman distinto — sale `TEST SUCCEEDED` sin
ejecutar nada. ⇒ **Exigir siempre el denominador**: suites pedidas contra arrancadas, filas de índice
contra ficheros en disco, delta del conteo contra tests añadidos. Hay un chip abierto para auditar si
otros filtros del repo están rotos igual.

## Release 2.1 (sin cambios)
2.0.5 no se lanza; release = 2.1. A7 y M5: **HOLD, no flip**. Prod: CLOUD_MODE 100 · GROUPS_BACKEND
100 · CLOUD_ONBOARDING_CHOICE 0 · SECONDARY_SESSION 0. Cola C: 9 ACs owner/device, no corrida; D-R1
sigue sin `ok_`. **Cero `ok_` inventado.**

## Board
87 tickets · backlog 45 · in-progress 8 · qa 14 · blocked 2 · done 13 · discarded 5. Índice cuadrado.
**Movidos anoche: 3** — `welcome-copy-blames-owner` y `prefs-synced-keys` a `qa/`, `ci-verde` a `in-progress`.
