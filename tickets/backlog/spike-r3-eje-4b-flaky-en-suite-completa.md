---
id: spike-r3-eje-4b-flaky-en-suite-completa
status: backlog
priority: low
area: "testing"
created: 2026-09-11
source: "corrida completa de YalaTests durante `detach-history-replay-can-tombstone-groups-on-next-launch`"
---

# `SpikeR3ContainerReleaseTests` «eje 4b» se pone rojo en la suite completa y verde en solitario

## Lo medido (2026-09-11)

En una corrida completa de `YalaTests` (6923 casos, 710 suites) falló **solo**
`SpikeR3ContainerReleaseTests` → «R3 eje 4b · control negativo — wipe y segunda conexión con el container
VIVO», con dos issues. Su propio log dice qué cambió de forma:

    (ii) el superviviente LEE 25 filas tras el borrado (sembradas 25)
    (iii) el save del superviviente lanzó: NSCocoaErrorDomain 134030 … "El archivo no existe."
    ↳ el superviviente dejó de leer vacío ⇒ el modo de fallo del §1.10 cambió de forma

**La misma suite, aislada, pasa 5/5. La corrida completa siguiente, sin tocar nada, pasa 6923/710.** O sea
que es no determinista y depende del estado previo del proceso, no del cambio que la sesión traía (su
harness vive en `YalaSpikeR3.store`, dentro del App Group, y no comparte superficie con el canal de Grupos).

## Por qué merece ticket y no Lista Negra a secas

El test es un **control negativo de un spike**: afirma que borrar los archivos bajo un container VIVO deja
al superviviente en un modo de fallo concreto. Si ese modo «cambia de forma» según lo que corriera antes, lo
que está midiendo el spike no es estable — y sus conclusiones sostienen decisiones del boot-wipe.

## Lo que se espera

Reproducirlo (correr la suite completa varias veces y ver con qué frecuencia cae), decidir si el aserto tiene
que aflojar sus expectativas sobre el modo de fallo o si el harness necesita aislamiento, y —si se queda
flaky— entrada en la Lista Negra con owner y fecha, que hoy no tiene.

## 2026-09-28 · también el eje 4a

En la corrida completa del gate de `groups-outbox-rows-without-a-live-session-have-no-exit` (8447 casos, 804 suites) falló
**solo** «R3 eje 4a · wipe in-process con release verificado», con su log: `EJE 4a ❌ ABORTADO: quedan 3 descriptores abiertos`.
Aislada, la suite pasa 2/2, y las tres corridas completas anteriores del mismo día, con el mismo cambio, pasaron. Es la misma
forma que el 4b: el spike cuenta descriptores del proceso, y lo que corrió antes deja algunos abiertos. El release verificado
que sostiene (sentinel nil **y** cero descriptores) sigue fallando cerrado en producción —aborta el borrado—; lo inestable es
el test.

## 2026-10-03 · cae en la PRIMERA corrida tras arrancar el simulador

Medido en la Mini (iPhone 17 Pro, iOS 27.0) durante `fix-ci-pure-logic-advisory-on-2-1`, corriendo solo
`SpikeR3ContainerReleaseTests` + las dos suites de `PrivateSessionMark` (26 casos): con el scheme `Yala`, la
corrida inmediatamente posterior a `simctl boot` dio el mismo rojo del 4b —(ii) lee 25 filas, (iii) el save
lanza 134030— **2 de 2 veces**; la corrida siguiente, sin tocar nada, verde (y `Yala Dev` verde también).
Encaja con la regla «la primera corrida tras bootear no cuenta» de `testing.md`, y apunta a que lo que
cambia el modo de fallo es la temperatura del simulador, no el orden de las suites. No es la causa del
rojo de CI de ese día: allí el 4b pasó en las tres pasadas de los dos runs.

## 2026-10-05 · otra vez el 4a, y aislado también cae

Gate de `personal-drain-that-always-aborts-blocks-cloud-sign-out-with-a-wait-a-moment-copy` (8886 casos, 865 suites,
`Yala Dev`, iPhone 17 Pro iOS 27.0, simulador con dos corridas encima): cayó **solo** el 4a con `quedan 3 descriptores
abiertos`. Aislada, con el MISMO binario, la suite dio **rojo y luego verde** (1 de 2). O sea que no hace falta la suite
completa para que caiga: basta el estado del proceso de test de esa corrida.
