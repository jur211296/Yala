---
id: prefs-synced-keys-upload-not-download
status: in-progress
created: 2026-08-06
updated: 2026-08-26
source: YalaWiki/Bugs/prefs-cinco-keys-synced-suben-y-no-vuelven.md
---


## El síntoma, en lenguaje de usuario

Cinco ajustes se guardan en la nube pero **nunca se leen de vuelta**. En un solo dispositivo no se nota nada.
En cuanto haya un segundo —o el usuario reinstale— esos cinco ajustes **no viajan**: la app los muestra en su
valor por defecto aunque en la nube esté guardado otro. No se pierde dinero ni datos financieros; se pierde
configuración, y de forma silenciosa.

## Lo medido

**5 de las 37 keys marcadas `synced: true` NO son `PrefSyncKey`**, así que el canal las **empuja** a iKV y al
outbox y **no tiene forma de aplicarlas al bajar**:

| Key | Qué controla |
|---|---|
| `moreSectionOrder` | orden de las tarjetas de la pestaña «Más» |
| `sankeyLabelMode` | modo de etiqueta del diagrama Sankey |
| `panelHeroKPIs` (×3) | qué KPIs muestra el hero del Panel |

⇒ el viaje es **de ida y sin vuelta**: se sube, ocupa cuota y tráfico, y el device receptor jamás lo materializa.

## Por qué importa ahora y no antes

Salió al arreglar el eco de `AppPreferences` (`05c44cf4`). Antes de ese fix, la **recarga** al arrancar era un
puente accidental que tapaba parte del problema; el fix lo quitó a propósito —cargar ya no escribe— y con él
desapareció la casualidad que disimulaba estas cinco. Es el mismo mecanismo por el que `financialMindset`
lleva sin sincronizar desde siempre sin que nadie lo notara.

**Y es el canal que el Modo Nube enciende.** Hoy el daño es invisible porque el multi-device de prefs está
dark; el día que se encienda, estas cinco se estrenan como pérdida de configuración entre dispositivos.

## La decisión pendiente (esto es lo que hay que resolver, no un fix mecánico)

Para cada una de las cinco, elegir:

1. **Añadirla a `PrefSyncKey`** — sincroniza de verdad, en las dos direcciones. Cuesta definir su forma en el
   wire y su resolución LWW; `moreSectionOrder` y los tres `panelHeroKPIs` son colecciones/orden, así que hay
   que decidir si el merge es LWW del blob entero o algo más fino.
2. **Bajarla a `synced: false`** — deja de subir. Es local por dispositivo, que para un orden de tarjetas o un
   modo de etiqueta puede ser lo correcto y lo más barato.

**No es «añadirlas todas al enum» por inercia:** un ajuste de presentación por dispositivo es una decisión de
producto legítima. Lo que NO es defendible es el estado actual —subir y no volver—, que tiene el coste de las
dos opciones y el beneficio de ninguna.

## Criterio de hecho

- Ninguna key `synced: true` fuera de `PrefSyncKey`. Un test que lo pinnee **por source-scan o por tabla**, con
  su mutación a exit 65 (añadir una key `synced: true` sin entrada en el enum tiene que poner rojo).
- Si alguna baja a `synced: false`, comprobar que deja de aparecer en el outbox de prefs y en iKV.

## Relacionado

- Regla durable: `.claude/rules/swiftdata-cloudkit.md` § «CARGAR una preferencia no puede ESCRIBIRLA» (donde
  vive el invariante y los otros tres residuales de la misma familia).
- Detalle del diagnóstico del eco: `.claude/rules/testing.md`, bullet del lavado general.
- Commit del fix que lo destapó: `05c44cf4`.

migrated from YalaWiki Bugs/prefs-cinco-keys-synced-suben-y-no-vuelven.md @ 1934e8ad
