---
id: private-sign-out-blocks-on-a-cloud-keychain-read-error
status: backlog
priority: low
area: "sesiones"
created: 2026-09-26
updated: 2026-09-26
source: "review adversarial de `sign-out-exits-do-not-verify-the-cloud-session-closed` (2026-09-26)"
---

# Un fallo al leer el llavero de la nube puede impedir cerrar sesión a quien nunca tuvo cuenta en la nube

## El problema, en lenguaje de usuario

Alguien que solo usa su iCloud privado toca «Cerrar sesión» y ve «Tu sesión sigue abierta en este iPhone». Nunca tuvo sesión en
la nube, así que reintentar no cambia nada.

## Lo medido (2026-09-26)

- `CloudAuthService.sessionIsGone` falla CERRADO: si el llavero de la sesión (`com.yala.cloudauth`) no se deja leer con un error
  que no sea «no encontrado», dice que la sesión sigue. Es a propósito: un fallo de lectura es justo cuando el borrado tampoco
  entró.
- Desde `sign-out-exits-do-not-verify-the-cloud-session-closed` los cierres privados (C) consultan esa respuesta y se paran.
  Antes el fallo se ignoraba y el cierre seguía.
- Inferido, sin medir: con la app en primer plano y el llavero `AfterFirstUnlock`, ese error es raro. Cazado por la review.

## Qué habría que decidir

Si la celda privada sin sesión en la nube debe preguntar siquiera (no hay nada que cerrar), o seguir con fallo cerrado. Un
`hasSession` a secas no vale: lleva el seam de XCUITest.
