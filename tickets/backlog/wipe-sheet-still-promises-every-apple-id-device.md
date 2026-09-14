---
id: wipe-sheet-still-promises-every-apple-id-device
status: backlog
priority: high
area: "settings, copy, sesiones"
created: 2026-09-14
source: "review adversarial de `remote-wipe-signal-honored-by-any-session`, lente de producto"
---

# La hoja de «Vaciar datos» sigue prometiendo que se borran de TODOS tus dispositivos

## El síntoma, en lenguaje de usuario

Voy a vaciar mis datos desde mi iPhone. La hoja de confirmación me dice, en la fila ☁️: **«Se borran de
iCloud y desaparecen también de tu iPad, tu Mac y cualquier dispositivo con este Apple ID»**. Confirmo.
En mi iPad, que tengo con una sesión solo de grupos —o que le he prestado a alguien—, los datos **no**
se borran. Nadie me lo dice, ni antes ni después.

## Lo medido (2026-09-14)

- La frase es `settings.wipeScopeCloudICloudAllDevices` (`Yala/Resources/es.lproj/Localizable.strings:5143`,
  `Yala/Utils/L10n.swift:4455`). La elige `DestructiveScopeSheet.swift:357` cuando
  `cloudLabel != .cloudAccount`, y `cloudLabel` sale de `DestructiveScopeLogic.cloudLabel(storageMode:)`,
  que **solo mira `storageMode`** — nunca qué sesión tienen los dispositivos que reciben la señal.
- Hasta el 2026-09-14 la frase era cierta: todo dispositivo del Apple ID con el onboarding hecho obedecía
  la señal. El ticket `remote-wipe-signal-honored-by-any-session` cerró eso a propósito —una sesión en la
  nube subía esos borrados a SU cuenta y una solo-grupos borraba el perfil de quien tenía el teléfono— y
  **con ello volvió falsa la segunda mitad de la frase**.
- Y la única línea de matiz que existe (`.multiDeviceResidual`, `settings.wipeScopeMultiDeviceResidual`)
  está suprimida justo en esta rama, con esta razón escrita en `DestructiveScopeLogic.swift:279-281`:
  «`.icloud` → sin línea: su fila ☁️ ya nombra todos los dispositivos del Apple ID». Esa razón es la
  promesa que ahora no se cumple.

## Por qué no se arregló en el mismo PR

**El texto exacto no es computable desde el dispositivo que emite.** El iCloud-KV no lleva inventario de
dispositivos ni de sus sesiones: el emisor no puede saber cuántos de los otros obedecerán. Así que la
salida no es un cálculo mejor, es una decisión de producto sobre qué se promete.

## Lo que hay que decidir (Jürgen)

Tres opciones, y ninguna es obviamente la buena:

1. **Suavizar la fila ☁️**: «…y de los dispositivos donde uses tu cuenta privada». Honesto, pero mete
   vocabulario de sesión en una frase que hoy habla de dispositivos.
2. **Reponer la línea de matiz** (`.multiDeviceResidual`) también en `.icloud`, con su propio texto.
   Deja la promesa fuerte arriba y la salvedad abajo, que es donde vive el resto de residuales.
3. **Dejarlo**: asumir que el caso —tener un segundo dispositivo del mismo Apple ID en sesión no
   privada— es raro, y que la frase vale para la gran mayoría.

Nota de la rule de l10n: el vocabulario de sesiones **no se corrige hacia la jerga interna** (cero de los
4.128 strings ES dice «sesión privada»), así que la opción 1 necesita una formulación que hable de dónde
viven los datos, no de sesiones.

## Criterios de aceptación

- [ ] La hoja de «Vaciar datos» en `.icloud` no afirma un alcance que el receptor puede no cumplir.
- [ ] Si se elige texto nuevo, va a las 4 variantes completas (`qa/scripts/add-l10n-key.sh`).
- [ ] El razonamiento de `DestructiveScopeLogic.swift:279-281` queda al día o retirado.
