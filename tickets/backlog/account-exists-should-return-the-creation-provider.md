---
id: account-exists-should-return-the-creation-provider
status: backlog
priority: medium
area: "gateway, bienvenida, cuenta de Yala"
created: 2026-11-12
updated: 2026-11-12
source: "lote 02 de la bienvenida 2.3 (Y23-02), BLOQUEANTE del proveedor contestado por Jürgen el 12-nov (opción A)"
---

# En un iPhone nuevo, entrar con el otro proveedor crea una segunda cuenta sin avisar con certeza

## El problema, en lenguaje de usuario

La bienvenida 2.3 tiene un solo botón por proveedor: «Entrar con Google» o «Entrar con Apple» crea la cuenta o entra
según exista. Si alguien creó su cuenta con Google y en un iPhone nuevo toca «Entrar con Apple» (con el mismo correo),
Yala no sabe que ya tiene cuenta: le enseña «Vamos a crear tu cuenta» y, si sigue, le crea otra.

## Por qué pasa (medido el 2026-11-12)

`GET /account/exists` (`gateway/src/sync/account.ts`, ~328-355) busca por el `sub` del JWT, no por correo, y no
devuelve con qué proveedor se creó la cuenta. Apple y Google dan `sub` distintos, así que `exists:false` no ve la
cuenta del otro proveedor. El proveedor solo aparece en el claim (`profiles.provider`, ramas `existing_stable`) y en el
faro de iCloud-KV, que solo conoce el mismo Apple ID y si ya sincronizó.

## Qué se hizo mientras tanto (decisión A de Jürgen)

«Vamos a crear tu cuenta» avisa antes del botón: «¿Creaste tu cuenta con Apple? Entra con Apple: con Google sería una
cuenta nueva», con el botón para entrar con el otro proveedor. Es un aviso genérico: no sabe si la cuenta existe.

## Qué haría falta

Que el servidor conteste, sin exponer datos de otra persona, si el correo verificado del token ya tiene una cuenta y
con qué proveedor se creó (por ejemplo, `exists` con `provider` cuando el correo coincide con el de un perfil). Con
eso, la app enseñaría «Encontramos tu cuenta · La creaste con Google…» (el caso «misma cuenta con el otro proveedor»
del prototipo v35) en vez del aviso genérico. Decisión de servidor y de privacidad: la toma Jürgen.
