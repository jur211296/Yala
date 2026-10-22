---
name: activacion-descarta-y-borra-de-verdad
description: «Activar Yala completo → Restaurar → Empezar desde cero» ya borra de verdad (PR del 2026-09-14). Dos hallazgos que el ticket no preveía, dos defectos ALTA de mi propio arreglo, y 4 tickets abiertos.
metadata:
  type: project
---

**Cerrado el 2026-09-14, un día después de su hermano (#155).** El botón no borraba NADA —ni zona ni
filas— y como a esa pantalla solo se llega tras un relanzamiento, el store espeja: el corpus descartado
se re-exportaba a la zona, también al segundo dispositivo. Ahora va a `.restoreDiscardGate`, un case
propio que monta la MISMA puerta de iCloud con un borrado distinto (`ICloudWipeScope.importedRows`).

**Why:** la decisión que lo desbloqueó fue de Jürgen (2.1A partir `wipeAllUserData` con flag; 2.2A
Grupos intactos; 2.3A nombre, divisa y prefill se quedan). El hermano lo había declarado imposible
(«pide un borrador que no existe»); costó un flag y un enum de tres scopes.

**How to apply:**

- **Case propio y no un flag sobre `.privateGate`**, porque las dos entradas necesitan borrados
  **opuestos**: antes del relanzamiento el store no espeja y lo local es de quien activa; después, lo
  local ES el corpus importado. Las tres diferencias del cableado (borrado, `onBack` a `.restore`,
  retirada del arm en `onRestore`) están en el ticket.
- **Dos premisas del ticket eran FALSAS y las dos las encontré midiendo:** el botón no «borra la zona»
  (no borraba nada), y `wipeAllUserData` **no** toca el eje 1 — `cloudSync.hasPrivateSession` está en el
  prefijo que el barrido excluye a propósito y con test. Lo que rompe son `hasCompletedOnboarding` y
  `hasShownWelcomeChooser`.
- **El hallazgo que más importa, y no estaba en ningún sitio:** sin reabrir el centinela del seed, la
  persona termina el onboarding **sin ninguna categoría**. El detalle en
  [[feedback_el_flag_que_conserva_deja_estado_incoherente]].
- **La review adversarial (4 lentes) cazó dos defectos ALTA de mi propio arreglo**, y los dos con la
  suite verde: el alert de wipe remoto que desmontaba la sheet cinco segundos después de borrar
  ([[feedback_mi_escritura_dispara_el_onchange_que_evito]]), y que el borrado se llevaba las filas
  puenteadas de los grupos sin que nadie las repusiera — justo lo que el flujo existe para conservar.
  Ese segundo lo cazaron TRES lentes a la vez; se cierra dejando pedida la convergencia del bridge, que
  el arranque siguiente ejecuta.
- **Y una corrección de lente que medí y RECHACÉ:** limpiar el buffer durable de intents se llevaría la
  navegación a un grupo vivo (`SerializableIntent` tiene `.navigateGroupDetail`). Demasiado ancha.
- **16 mutantes verificados**, los seis últimos de las correcciones de la review. **Tres de mis tests
  salieron rojos después** porque mis propias correcciones desfasaron sus source-scans — el `onProceed`
  pasó a multilínea, una prohibición era demasiado ancha, y un `segment` usaba un comentario como
  marcador de cierre sobre una fuente de la que ya se habían quitado los comentarios.
- **Device-QA NO simulable**, y esta vez la razón es concreta: `ICloudPersonalCorpusProbe` no tiene ni un
  seam de `uitest`, así que el estado «Encontramos tus datos» no existe en simulador — y a la pantalla de
  Restaurar de la activación solo se llega desde ahí. Ficha en
  `tickets/qa/device-qa-activation-restore-start-fresh.md`. **El fallo más probable del PR se mira
  siempre: tras borrar, que haya categorías y «Ajuste de saldo».**
- **Deja 4 tickets**, uno `high`: tres salidas de la puerta (sin red, sin cuenta iCloud) llaman a
  `onProceed()` sin pasar por el borrado, y el aviso del espejo tardío que llega después usa `.handover`
  — o sea que purgaría los grupos.

Relacionado: [[project_restore_start_fresh_pasa_por_la_puerta]] (el hermano) ·
[[project_paso12_dominio_preferencias]] · [[project_rediseno_sesiones_dos_ejes]]
