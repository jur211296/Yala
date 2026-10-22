---
name: tipar-un-desenlace-despierta-defensas-dormidas
description: Al TIPAR un desenlace que antes se colapsaba, audita las defensas del productor que nadie necesitaba mientras daba igual acertar — el Merkle llevaba meses sin canRenewSession y era inofensivo hasta ese día.
metadata:
  type: feedback
---

Cuando un desenlace deja de aplanarse y pasa a **significar algo**, ve al PRODUCTOR de ese desenlace y pregunta qué
defensas le faltan. Las que nadie echó de menos mientras el valor se colapsaba.

**Why:** el 2026-09-22, al hacer que el 401 de `/sync/merkle` saliera tipado y encendiera el aviso de «vuelve a
entrar», `SyncMerkleClient` resultó ser el ÚNICO cliente del canal personal sin `canRenewSession` y sin la rama de
`yala_attest_required`. Llevaba meses así y **era inofensivo**: `SyncMerkle` aplanaba su `.sessionExpired` en un
`fetch-failed` que se leía como red, así que acertar o no daba igual. En cuanto el desenlace movió una pantalla, esa
ausencia se convirtió en mi regresión: pedir firmar otra vez a quien solo estaba sin cobertura (el bug que cerró
`personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`) y a quien no puede acuñar App Attest.

Y el comentario que lo custodiaba **lo decía, y era cierto cuando se escribió**: «aquí no cambia lo que hace la
máquina — el executor colapsa las dos en la misma parada retomable». Un docblock que justifica una ausencia describe
el mundo del día en que se escribió.

**How to apply:** antes de tipar, enumera los HERMANOS del productor (los otros clientes del mismo canal, las otras
implementaciones del mismo protocolo) y **diffea sus FIRMAS**, no su comportamiento: un `grep` de los parámetros del
init basta, y el que tenga uno menos es el que lleva la deuda dormida. Cuenta también los `case` de su `switch` de
respuesta — al Merkle le faltaba uno entero que el push y el pull sí tenían.

Relacionado: [[feedback_mi_arreglo_rompe_la_premisa_de_otro_guard]], [[feedback_el_copy_caduca_por_un_cambio_ajeno]],
[[feedback_mi_docblock_tambien_es_una_premisa]].
