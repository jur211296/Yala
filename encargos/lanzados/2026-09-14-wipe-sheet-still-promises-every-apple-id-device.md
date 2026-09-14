# Implementar ticket: wipe-sheet-still-promises-every-apple-id-device

## Contexto
Una más antes de la pausa por cambio de cuenta Claude (Jürgen 2026-09-14). Tras #157 la hoja de Vaciar datos sigue prometiendo wipe en todos los dispositivos del Apple ID; ya no es cierto para solo-grupos / prestado.

## Decisión de Jürgen (2026-09-14)
**(1) Suavizar la fila ☁️**: prometer solo donde uses Yala con tus datos personales / vida personal — no «cualquier dispositivo con este Apple ID». Sin jerga interna de «sesión privada» (rule l10n). Las 4 variantes de locale vía `qa/scripts/add-l10n-key.sh`. Actualizar o retirar el razonamiento en `DestructiveScopeLogic.swift:279-281`.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, board, `docs/TICKETS.md`, merge, `/cerrar-total`. Bugs/decisiones nuevas → ticket `--solo-crear` y avisar a Frank. Device-QA si aplica → `tickets/qa/`.

Avisos a Frank: (1) decisión/acceso; (2) PR; (3) `/cerrar-total` resumen producto; (4) idle una vez.

No lances el siguiente: cola en pausa tras este. No marketing/.

## Que se pide
1. Leer ticket + DestructiveScopeSheet / L10n keys.
2. Implementar copy suavizado (1) en las 4 variantes; criterios del ticket.
3. PR a `2.1`; board/`TICKETS.md`; `/cerrar-total`.

## Que NO hay que tocar
marketing/. Opción 2 (matiz) o 3 (dejarlo). Wipe de prod.

## Como se sabe que esta bien
La hoja en `.icloud` no afirma un alcance que el receptor puede no cumplir; locales al día; PR mergeado; `/cerrar-total`.

## Paso 0 — decisiones (resueltas en autónomo (bypass), 2026-09-14)

Jürgen ya zanjó la de producto (opción 1: suavizar la fila ☁️). Lo que quedaba abierto era **cómo**, y
son cinco nodos. Ninguno paró la sesión; se discuten en el PR.

| # | Nodo | Decidido | Por qué |
|---|---|---|---|
| 1 | ¿Editar el valor de la key existente o crear una nueva? | **Key nueva** `settings.wipeScopeCloudICloudPersonal`, y retirar `…AllDevices` | El nombre de la vieja afirma «AllDevices», que es justo lo que se deja de prometer. Un nombre que miente sobre su contenido es una trampa para el yo-futuro. Coste real: un `add-l10n-key.sh` + borrar una línea en 16 ficheros, con **un solo consumidor**. Y el encargo ya apuntaba a key nueva al nombrar el script |
| 2 | ¿Qué dice exactamente la frase? | «Se borran de iCloud, así que desaparecen de los otros dispositivos que **guardan ahí** tus datos personales» | «Más floja» no basta: tenía que ser **verdadera**. La condición se ancla a *ese* iCloud porque, sin el ancla, un dispositivo con la cuenta de Yala «usa Yala con tus datos personales» y la frase volvería a mentir. Comprobada contra las cuatro poblaciones |
| 3 | ¿Se toca también la fila ☁️ de `.cloud`? | **No**, y un test lo fija | Ahí el borrado viaja por la cuenta de Yala y los otros dispositivos sí lo pierden al sincronizar: la promesa se cumple. Suavizar las dos sería el arreglo con la forma del bug |
| 4 | ¿Tests? El ticket no los pide | **Sí**, suite nueva | Cero aserciones existían sobre el copy de esa fila — por eso la promesa pudo volverse falsa en silencio. Sin red, el siguiente cambio del mecanismo repite el ticket. Va por `Config.make` (camino de producción) + barrido de los 16 locales, con dos controles positivos |
| 5 | La razón nueva de no poner `.multiDeviceResidual` en `.icloud` | Decir que **se evaluó y se descartó**, sin afirmar que no exista residual | La razón vieja («la fila ya nombra todos los dispositivos») cayó. Escribir «en `.icloud` no hay residual» sería cambiar una premisa falsa por otra: un iPad offline con cambios pendientes también puede subirlos al reconectar. Reponer la línea es la opción 2, que Jürgen descartó |

**Alcance que NO se amplió:** el residual del solo-grupos anterior al paso 5 con espejo montado sigue
en su ticket (`remote-wipe-axis-misses-groups-only-installs-before-the-mount-mark`). Y `marketing/`
no se toca.
