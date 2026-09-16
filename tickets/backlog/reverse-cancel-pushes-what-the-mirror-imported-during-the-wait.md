---
id: reverse-cancel-pushes-what-the-mirror-imported-during-the-wait
status: backlog
priority: low
area: "modo-nube, sync, migración"
created: 2026-09-16
source: "review de `reverse-upload-has-no-ceiling-and-no-exit` (2026-09-16), decisión D12(c): residual documentado"
---

# Al cancelar la vuelta a iCloud, lo que el espejo importó durante la espera sube a la nube de Yala

## El problema, en lenguaje de usuario

Mi Apple ID tiene en iCloud datos de Yala de otra época, o de otro iPhone que sigue en modo privado. Empiezo
la vuelta a iCloud, la cancelo, y en la nube de Yala aparecen movimientos que no eran de esta cuenta.

## Por qué pasa

- Durante la espera de `reverseUpload` el espejo está montado e **importa** de la zona de CloudKit.
- La salida vuelve a la nube: tras relanzar, `CloudSyncEngine.drainOnce` procesa la History desde su token y
  **solo excluye el autor `outboxSaveAuthor`**. Las transacciones del import del espejo se traducen como
  cambios locales y se suben con HLC fresco.
- Si el import trajo filas ajenas —una zona con otro corpus del mismo Apple ID— o valores viejos que pisaron
  los locales, eso llega al backend, que era justo la copia limpia.

## Lo que añadió la review (2026-09-16, medido en código)

- **No hace falta que la zona cambie: basta un RE-IMPORT.** `reverseReconcile(.awaitingQuiescence)` solo mira
  `isImportQuiescent`, que al arrancar vale `true` ANTES del primer import del espejo (`lastSuccessfulImportDate
  == nil` y sin sync en curso). El barrido de zombis puede correr antes de que el espejo re-importe, y un
  re-import posterior (el borde «token inválido / re-import» que `qa/cloud/README.md` declara) resucita filas que
  la persona borró en la nube. Al salir, esas filas suben como INSERT con HLC fresco y reviven en el backend —la
  copia que estaba bien—. Las que el barrido sí pilló no resucitan (el INSERT del import falla el lookup).
- **Y no es «durante la espera»: es hasta relanzar.** Tras la salida, el proceso sigue con el espejo montado e
  importando hasta que se cierra Yala.
- Arreglos posibles: volver a barrer zombis entre `.rearmMirrorOff` y `.reverseRollback` (y que el motor no
  arranque con la salida a medias, `cloud-engine-can-start-with-a-reverse-abort-pending`), o exigir en
  `awaitingQuiescence` al menos un import visto cuando el mount espeja.

## Por qué se aceptó

Decisión de Jürgen (2026-09-16, D17 del ticket del techo): ticket aparte.

- La población es estrecha: para un migrado, la zona solo cambia si otro dispositivo en modo privado escribió
  en ella tras la migración (el marcador lo bloquea), o si hay un re-import; para un born-cloud, si su Apple ID
  ya tenía un corpus de Yala en iCloud.
- Lo mismo que se sube al cancelar se quedaría en local y en iCloud si la vuelta terminara: la mezcla no la
  crea la salida, la crea montar el espejo sobre esa zona.
- Excluir el autor del import en el drenaje cambia el motor para todos los usuarios de la nube.

## Criterios de aceptación

- [ ] Medido en device qué autor lleva una transacción de import del espejo.
- [ ] Decidido si el drenaje posterior a una salida de `reverseUpload` debe saltarse las transacciones del
      espejo, o si el riesgo se queda aceptado.
