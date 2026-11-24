---
id: 2026-11-23-correos-del-banco-claridad-y-volver
status: done
priority: medium
area: "bank-email, step-guides, l10n"
created: 2026-11-23
updated: 2026-11-23
source: "pruebas de Jürgen de Yala 2.3 en el iPhone (Correo del banco › Reenviar desde Gmail)"
---

# Correos del banco: guía para principiantes y poder volver a un paso anterior

Jürgen probó «Correo del banco» en el iPhone y vio dos cosas: la guía daba por hecho que uno ya sabía configurar un
reenvío, y un «Hecho» tocado sin querer dejaba el paso cerrado sin forma de volver a él.

## Qué cambió

- **Volver a un paso hecho.** Cada paso hecho de una guía por pasos (`YalaStepGuide`) lleva «Volver a este paso», y la
  fila entera se toca. El paso queda activo otra vez, los de después vuelven a pendientes y el avance se guarda. Vale
  para las tres guías: correos, Apple Pay y Face ID.
- **Copiar la dirección en cualquier paso.** La cabecera de la guía de correos tiene «Copiar dirección» debajo de la
  dirección `@yalainbox.com`.
- **Textos para quien nunca lo hizo.** Cada paso dice dónde entrar, qué tocar y qué se va a ver, con subpasos
  numerados: Gmail en Safari (y cómo pedir la versión de escritorio), qué NO marcar, cómo encontrar la dirección del
  banco, el código de confirmación que Yala recibe solo, el filtro, y las reglas de Outlook e iCloud Mail.
- **Tabla propia** `CorreosBancoGuia.strings` en los 16 idiomas (es-419 neutro, es-AR en voseo, es-ES con los nombres de
  botón de Gmail en España). Las claves viejas `bankEmail.*` de la guía quedan sin uso en `Localizable.strings`.

## Pruebas

- Unit: `YalaTests/CorreosDelBancoGuia/` (reabrir, guardado, cableado y los textos en los 16 idiomas).
- XCUITest: `BankEmailGuideUITests#test_gmailGuide_goesBackToADoneStep`.
- Capturas de antes y después en el simulador.

## Para mirar en el iPhone (no bloquea)

Recorrer la guía de Gmail contra Gmail real en Safari y confirmar que los nombres de los botones coinciden con lo que
se ve (dependen del idioma de la cuenta de Google).
