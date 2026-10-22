---
name: una-ventana-dura-lo-que-su-reintento
description: Una ventana de carrera no dura lo que tarda la llamada sino todo lo que el trabajo pueda quedar aparcado y retomarse; el 16-sep descarté journalear una intención por «una petición» y la ventana era días
metadata:
  type: feedback
---

**Antes de aceptar un residual «porque la ventana es de una petición», mide por dónde se RETOMA ese trabajo.** Si el
paso puede aparcarse (red, quiescencia, sesión caducada) y volver a correr desde un `resume` o tras un relanzamiento,
la ventana dura lo que dure aparcado, no lo que tarda la llamada.

**Why:** en `settings-migrate-to-cloud-adopts-silently-instead-of-migrating` (2026-09-16) puse la intención de
«Migrar» solo en memoria y escribí en el Paso 0 que journalearla solo cubría «el relanzamiento a mitad del claim».
La review midió que un claim fallido por red deja `claimingMigration` journaleado con «Retomar», y que tras un kill
el runner nuevo nace con la intención por defecto: el claim retomado adoptaba. En la cuenta que volvió a iCloud eso
dejaba el teléfono en modo nube sobre un backend que rechaza todo push. Se journaleó (schema 6).

**How to apply:** para cada estado que el residual deja «a medias», busca sus lectores de arranque
(`resumeIfNeeded`, re-kicks, BGTasks) y pregunta con qué valor llega lo que vivía en memoria. Si llega con un
default, el residual no es una ventana: es un camino. Relacionado: [[antes-de-poner-techo-mide-que-la-espera-existe]].
