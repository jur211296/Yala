---
name: artifacts-no-se-pueden-hacer-publicos
description: Compartir un artifact con enlace en la org de Jürgen: a veces sale desactivado y a veces pasa (19-nov, las dos); siempre un intento
metadata:
  type: reference
---

Medido el 2026-11-19: al compartir un artifact desde Chrome, la opción «Cualquier persona con el enlace» sale gris con
el aviso «Compartir fuera de Zeal IT Consultants está desactivado». La regla de casa (ADR-112/123) pide UN intento y, si
falla, anotar «Artifact: privado, no se pudo compartir con enlace» y seguir. Cuesta 1 minuto comprobarlo; si vuelve a
salir gris, no buscar otra vía.

**Cambió el mismo día:** el 19-nov por la tarde, en la Mini, la opción salió activa y el artifact de los PR
atascados quedó público (`artifact-publico comprobar` → `publico`). El ajuste de la organización no es fijo:
haz siempre el intento entero (Compartir → «Cualquier persona con el enlace» → «Compartir públicamente», todo
con `find`) y anota solo lo que salga ese día.

**20-nov (00:30, Max):** otra vez gris con el mismo aviso.

**21-nov (06:40, Max, semi):** pasó entero, con base de datos incluida: find + clic por ref y `comprobar` → `publico`. Van dos fallidos de cuatro.
