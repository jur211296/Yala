# La subida de tus datos a la nube ya no se queda al 55 % para siempre

El encargo llegó vacío (0 bytes). Se trabajó desde el ticket `snapshot-upload-has-no-ceiling-and-no-way-out`, que sí
trae problema, medición y criterios.

## Paso 0 — decisiones

Resueltas el 2026-09-22 en sesión de día: las de producto las contestó Jürgen por AskUserQuestion; las técnicas, con
lo medido. El detalle completo vive en el `## Paso 0` del ticket (`tickets/in-progress/…`).

- **Techo** (Jürgen): 15 min acumulados bajo una causa que esperar no arregla (sesión caducada, cuenta suspendida,
  fallo local); 72 h sin subir una sola página con cualquier causa. Cada página confirmada reinicia los dos relojes.
- **Salida** (Jürgen): a la tarjeta de fallo que ya existe, con **texto por motivo**.
- **«Cancelar»** (Jürgen): sí, con confirmación, durante la subida; vuelve a «Migrar a la nube» sin aviso de fallo.
- **Alcance** (Jürgen): solo la subida. Los pasos del 22 %, 35 % y 80 % tienen el mismo agujero y van a
  `forward-migration-steps-have-no-ceiling-and-no-exit`.
- **Técnico** (Frank): dos relojes con el molde de #210, reloj por causa extraído a un helper compartido con la
  vuelta; la sesión caducada es definitiva en la ida (no hay botón de «Iniciar sesión» y la salida es la que vuelve a
  pedirla); la deriva del HLC va al plazo largo; el motivo lo elige el techo que venció; `MigrationState` v9.
