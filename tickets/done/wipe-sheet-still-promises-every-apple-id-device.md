---
id: wipe-sheet-still-promises-every-apple-id-device
status: done
priority: high
area: "settings, copy, sesiones"
created: 2026-09-14
updated: 2026-09-14
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
  está suprimida justo en esta rama, con esta razón escrita en `DestructiveScopeLogic.swift:293-295`
  (el ticket decía 279-281, que hoy son los parámetros de `model(...)`):
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

- [x] La hoja de «Vaciar datos» en `.icloud` no afirma un alcance que el receptor puede no cumplir.
- [x] Si se elige texto nuevo, va a las 4 variantes completas (`qa/scripts/add-l10n-key.sh`).
- [x] El razonamiento queda al día — y eran **tres** sitios, no uno.

## Lo entregado (2026-09-14, PR)

**Decisión de Jürgen: opción 1**, suavizar la fila ☁️ sin vocabulario de sesiones.

| es-419 | Se borran de iCloud, así que desaparecen de los otros dispositivos que guardan ahí tus datos personales |
|---|---|

Key nueva `settings.wipeScopeCloudICloudPersonal` en los 16 locales (4 variantes regionales
materializadas; sin override regional — la frase no lleva verbo en 2ª persona, así que el voseo y el
peninsular coinciden). **Retirada `settings.wipeScopeCloudICloudAllDevices`**: su nombre afirmaba justo el
alcance que se deja de prometer, y tenía un único consumidor.

**Por qué la frase nueva es verdadera, y no solo más floja.** El borrado alcanza a otro dispositivo por dos
caminos independientes, y la condición «guarda ahí tus datos personales» es la misma en los dos: el espejo
exporta los borrados de filas a ese iCloud, de donde los lee cualquiera que monte ese store; y la señal de
vaciado solo la obedece `wipeSignalObeyedByThisSession`, que pide exactamente esos datos. Comprobado contra
las cuatro poblaciones: sesión privada (cumple por los dos caminos), teléfono prestado y dispositivo con la
cuenta de Yala (la frase no promete nada sobre ellos, y es correcto), y el solo-grupos anterior al paso 5
con espejo montado (el camino del espejo sí lo alcanza — su residual de wipe local sigue en
`remote-wipe-axis-misses-groups-only-installs-before-the-mount-mark`).

**La fila ☁️ de la cuenta de Yala no se toca**, y un test lo fija: ahí el borrado viaja por la cuenta y los
otros dispositivos sí lo pierden al sincronizar. Suavizar las dos habría sido el arreglo con la forma del
bug.

**Tres razonamientos citaban la promesa vieja como premisa**, no uno: el docblock de `wipeDataFull`, el de
`personalMountAttachesMirror` y la razón de no poner `.multiDeviceResidual` en `.icloud` — más el docblock
de un test que repetía el segundo. Los cuatro al día. La razón nueva para no poner la línea de matiz no
afirma que en `.icloud` no exista residual: dice que la fila ya acota en su propio texto, y que reponerla
se evaluó y se descartó (opción 2 del ticket).

## La red que faltaba

**Cero tests miraban el copy de esa fila.** `DestructiveScopeLogicTests` mide la ESTRUCTURA —filas, tonos,
líneas, secundarias— y nunca el texto, así que la promesa pudo volverse falsa el mismo día en que se cerró
el receptor, en silencio. `WipeCloudRowScopeTests` la cierra por los dos lados:

| Qué fija | Cómo |
|---|---|
| la fila ☁️ en iCloud usa el texto acotado | `Config.make`, el camino de producción — no un grep |
| ningún locale repone la promesa | barrido de los 16 ficheros de strings, con `Apple ID`/`Apple-ID`/`iPad` |
| la key retirada no vuelve | mismo barrido |
| la fila de la cuenta de Yala sigue intacta | `Config.make` con `.cloudAccount` |

Dos controles positivos, porque los dos modos de fallo abierto eran reales: si `L10n` devolviera la key
cruda, `detail == L10n.…` sería cierto por ambos lados y no probaría nada; y si el listado de `.lproj`
saliera vacío, el barrido pasaría en verde leyendo cero ficheros.

**4 mutantes verificados**: la key cambiada en el sheet, la promesa repuesta en un solo locale (en alemán,
que el host de test no lee), la key retirada devuelta, y la rama de la cuenta de Yala apuntada a la nueva.
Los cuatro salieron rojos.

**Device-QA: no hace falta.** El cambio es una cadena de texto en una hoja que el XCUITest ya abre, y su
contenido queda fijado por unit desde el camino de producción.
