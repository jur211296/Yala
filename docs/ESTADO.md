---
updated: 2026-09-03
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-03 (Lima)

**Rama** `2.1` · TestFlight build **12** (CPV 12). **Subida Yala (TF/store) = solo Mini.**
Gateway de producción: **desplegado hoy** (versión `6f033324`, 16:42 UTC).

## Lo que cambió para el usuario (sesión del 2 al 3 de septiembre)

- **Los avisos de Grupos ya no dependen de que la app esté abierta.** Eran dos cosas: el push era
  silencioso por diseño (la app fabricaba el aviso al despertar) y **las RPC de membresía no emitían
  nada**. Ahora el banner lo pinta iOS y el eco silencioso viaja en el mismo push. **Ya en producción**
  — es cambio de servidor, no hace falta actualizar la app.
- **Cancelar «Empezar desde cero» ya no deja la app en negro** sin salida. Estaba en producción para
  cualquiera que reinstale con datos.
- **La puerta de Grupos ya no acusa a la dueña** de traer datos ajenos mientras restaura de iCloud.
- **Cinco ajustes** (orden de «Más», etiqueta del Sankey, KPIs del hero) dejan de subir a iCloud para
  no volver nunca.

## Te esperan a ti

1. **Verificar el push con dos teléfonos reales.** App Attest en `enforce` lo hace imposible desde
   simulador o build de Xcode. Lo medido es que el gateway compone y envía lo correcto; **que Apple
   entregue el banner, no**. Si no llega: `Ajustes → Yala → Notificaciones` en el receptor — el único
   ticket cerrado del repo sobre esto era el permiso apagado, y APNs devuelve 200 igual.
2. **`hasCompletedOnboarding`: par escritor/lector partido.** Un escritor y cuatro lectores repartidos
   entre dos dominios. Es una decisión, no trabajo; las dos salidas están en
   `secondary-visitor-writes-owner-domain`.
3. **D4 · consent legacy (RGPD)**, decidido «custodiar y reponer» y sin implementar. Dos riesgos que el
   ticket no traía: `GroupsConsentState` escribe en `.standard` a pelo (el dominio por sesión **no** lo
   cubrió) y la reposición cae en la ventana donde un borrado mal dirigido arrasaría el `UserDefaults`
   entero de la dueña.
4. **Device-QA pendiente**: el residual de `welcome-copy-blames-owner` (SIWA real) y comprobar que las
   cinco prefs dejan de aparecer en el outbox y en el iKV.

## Abiertos, por prioridad

- **`ci-verde-con-la-suite-en-rojo`** (in-progress) — pasos 1 y 2 hechos; 3 y 4 fuera de alcance por
  decisión. Promover a bloqueante exige refutar el `EXC_BREAKPOINT`, y una corrida verde no lo refuta.
- **`invite-refresh-forzado-es-noop-si-hay-otro-en-vuelo`** (**high**) · **`aviso-de-nuevo-miembro`**
  (implementado y desplegado; queda el e2e con teléfonos) · **`canarios-y-breadcrumbs-sin-emisor`** ·
  **`undercount-dias-intervalos-cerrados`** (~7-10 sitios reales; helper único ya elegido) ·
  **`appstorage-onboarding-…`** · **`scheduled-payment-once-labeled-monthly`** (low, el más barato).
- **Nuevos de hoy**: `push-client-ignores-yala-kind` · `gateway-has-no-telemetry` ·
  `only-testing-filters-may-be-silently-empty` · `account-goldens-freeze-read-test-times-out` ·
  `gate-doc-says-swift-testing-only` · `staging-test-user-c-does-not-exist`.
- Los **2 de `blocked`** no esperan decisión ni código: esperan **hardware** (dos aparatos con el mismo
  iCloud; dos iPhones con TestFlight).

## Infraestructura, al día

- **Credenciales de test de staging rotadas** el 2026-09-03 y guardadas en
  `~/Secrets/yala-supabase-test/test-users.env` (permisos 600, con backup). Las anteriores se aplicaron
  pero se perdió su valor. **La batería del gateway necesita además `PUSH_ROLE_JWT` y `GROUPS_ENC_KEY`**
  — el procedimiento entero está en `qa/cloud/README.md`. Con las tres cargadas: 321 tests pasan.
- **Disco**: 13 → 59 GB liberados la madrugada del 3. El informe del repo no ve los snapshots de Time
  Machine, que retienen lo borrado.

## Método, que es lo que más cambió

El mismo error de medición mordió **ocho veces en dos sesiones**: un filtro descarta lo que buscas y la
ausencia se lee como resultado. ⇒ **exigir siempre el denominador** — suites pedidas contra arrancadas,
filas de índice contra ficheros en disco, delta del conteo contra tests añadidos.

Y su hermano: **en cinco de los seis defectos arreglados, la causa no era la que decía el ticket.** En
el de la pantalla en blanco hicieron falta dos arreglos equivocados antes de acertar, y lo que los
descartó no fue razonar mejor: fueron tres `print`. Cuando un ticket traiga una hipótesis, reproducir y
medir va **antes** de leer código buscando confirmarla.

## Release 2.1 (sin cambios)

2.0.5 no se lanza; release = 2.1. A7 y M5: **HOLD, no flip**. Prod: CLOUD_MODE 100 · GROUPS_BACKEND 100
· CLOUD_ONBOARDING_CHOICE 0 · SECONDARY_SESSION 0 (verificado hoy contra `/config` vivo). Cola C: 9 ACs
owner/device, no corrida; D-R1 sigue sin `ok_`. **Cero `ok_` inventado.**

## Board

93 tickets · backlog 51 · in-progress 8 · qa 14 · blocked 2 · done 13 · discarded 5. Índice cuadrado.
