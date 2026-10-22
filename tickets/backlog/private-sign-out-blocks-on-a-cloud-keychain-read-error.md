---
id: private-sign-out-blocks-on-a-cloud-keychain-read-error
status: backlog
priority: low
area: "sesiones"
created: 2026-09-26
updated: 2026-10-08
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

## Medido en 2.1 (triage 2026-10-08)

- `CloudAuthService.sessionIsGone(sdkSeesSession:read:)`: un `read()` que lanza devuelve `false` («sigue»); `signOut()` lo devuelve vía `storedSessionIsGone`, también con `client == nil`, y `CloudSessionSignOut` hace `guard await CloudAuthService.shared.signOut() else {` en sus tres cierres.
- Decisión que falta: **A.** fallo cerrado también en la celda privada sin sesión en la nube (hoy); **B.** en esa celda, sin rastro de que este teléfono tuviera nunca una sesión en la nube (sin perfil guardado), no se pregunta al llavero. Recomendada **B**: sin sesión que cerrar, el fallo cerrado no protege nada y deja a la persona sin salida. La prioridad es la de B.

Triage 2026-10-08: abierto · low → low · sigue igual; un error de lectura del llavero en primer plano es raro y reintentar más tarde suele curarlo.
