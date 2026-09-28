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
