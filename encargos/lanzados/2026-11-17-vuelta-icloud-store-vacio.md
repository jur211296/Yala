Yala
# Arreglar que «Volver a tu iCloud» deje el iPhone sin datos
---
toca: Yala/Services/CloudSync/, Yala/App/Logic/CloudProgressStepsLogic.swift, Yala/App/Logic/FollowerWindowGateLogic.swift, Yala/App/Logic/ContentViewReadinessLogic.swift, Yala/App/ContentView.swift, YalaTests/VueltaICloudStoreVacio/, tickets/backlog/reverse-on-the-iphone-left-the-local-store-empty.md, tickets/done/reverse-on-the-iphone-left-the-local-store-empty.md
esfuerzo: high
cierre: cierra-sola
---

## Qué pidió Jürgen (16-nov, 19:13 Lima)
«Y encolamos el ticket de high que ha salido en esa sesión.» Es el ticket de prioridad alta que abrió la sesión «Nube 2.3: los cinco bugs media» (PR #1008): `tickets/backlog/reverse-on-the-iphone-left-the-local-store-empty.md`.

## Antes de empezar
- Este encargo depende de que el PR #1008 esté mergeado en `2.3` (ahí vive el ticket y el arreglo de volver a la nube con la misma cuenta). Si al arrancar sigue abierto y su CI está verde, mergéalo primero; si no está verde, trabaja sobre su rama y anótalo.
- Lee el ticket entero: tiene el rastro medido y dos hipótesis sin medir (una señal vieja de «Vaciar datos» en el iCloud de ese Apple ID que el receptor tardío aplica al montar el espejo en la vuelta, o una vuelta que no subió nada a iCloud y un remonte que dejó el store vacío).

## Qué hay que lograr
1. Reproducir y medir la causa real: repetir el recorrido en un Apple ID sin señal de «Vaciar datos», contando el store antes y después del remonte, y comprobar si el iCloud conserva las filas.
2. Arreglar la causa en la vuelta a iCloud para que el iPhone nunca quede con 0 movimientos, cuentas o categorías ni muestre «Datos no disponibles · Se vació Yala en otro de tus dispositivos» cuando nadie vació nada. Una señal de vaciado vieja no debe borrar lo creado después de ella.
3. Tests automáticos en `YalaTests/VueltaICloudStoreVacio/` y review adversarial del cambio de migración, según las reglas de `swiftdata-cloudkit.md`.
4. Prueba de punta a punta en el iPhone 14 (DeviceMCP, Yala Dev contra staging) con evidencia. Nada en Producción.
5. Mover el ticket a `tickets/done/` con lo medido.

## Recursos
- Puedes usar el iPhone 14 conectado por DeviceMCP. Si corres en la Max y otra sesión ocupa un simulador, puedes usar un segundo simulador (tope 2 en la Max; 1 en la Mini).
- Commits y PR sin firma de IA.

## Cierre
- El modo queda fijo al arrancar (nocturno 20:00–05:30, semiautónomo 05:30–20:00, hora Lima). Lo menor y reversible lo decides y lo anotas. En semi, lo vital se pregunta y esperas con la sesión viva; en nocturno, lo vital deja checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear ni declarar completo lo incompleto.
- Si el trabajo está completo y el modo lo permite, `/cerrar-total`. El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el resultado como artifact visual de Claude.

## Paso 0 — decisiones (resueltas en autónomo, nocturno)

Medido antes de decidir (iPhone 14, Yala Dev contra staging, 17-nov 02:25–02:30):
- Antes de remontar, el espejo de iCloud guardaba como posición la transacción 825 del historial y el store solo
  conservaba la 834: la purga del historial de la época en la nube (`purgeHistoryOnce`) se llevó lo que el espejo no
  había leído.
- Al remontar, su exportación falló con 134301 (historial caducado) y el espejo hizo un «reset» que borró 8.842 filas
  (autor `NSCloudKitMirroringDelegate.reset`). Ayer, a las 18:33:20, el mismo 134301: es la causa del ticket.
- iCloud conserva sus filas: al relanzar, el espejo bajó 2.370 movimientos y 9 cuentas. Lo que se pierde es lo hecho en
  la época en la nube, y el teléfono queda vacío hasta relanzar. La señal de «Vaciar datos» no interviene.

1. **Causa → apagar la purga del historial en modo nube** (`CloudSyncFlags.historyPurgeEnabled = false`). Es lo que
   rompe la premisa de la vuelta (el espejo repite al remontar lo que pasó en la nube); con la purga apagada, que es
   como se midió en verde la vuelta en julio, el espejo no caduca. Precio: el historial crece en modo nube como ya crece
   en modo iCloud. Alternativa descartada: purgar solo hasta la posición del espejo (más código sobre una tabla privada
   de Core Data para ahorrar disco).
2. **Teléfonos que ya purgaron → no se ofrece la vuelta** (`ReverseEligibility.mirrorHistoryExpired`, con su texto):
   montar el espejo los vaciaría. Fallo cerrado: si la posición del espejo no se deja leer, tampoco se ofrece «ahora».
   Recuperarlos (dejar que el espejo se reinicie y volver a bajar lo de la cuenta encima) es diseño: ticket aparte y
   card «Espera decisión» para Jürgen.
3. **Una sola lectura por proceso** de la sonda (`MirrorHistoryProbe`): con la purga apagada el estado no cambia
   mientras la app corre, y la pantalla de almacenamiento refresca cada segundo.
4. **Tests** en `YalaTests/VueltaICloudStoreVacio/`: decisión pura, lectura de un SQLite con la forma del de Core Data
   (con control positivo), elegibilidad y el flag apagado.
5. **PR #1008** tenía el CI verde y chocaba con 2.3 solo en documentación: se resolvió el merge en su rama (unión de
   filas) y se dejó en su cola de auto-merge; este encargo se apoya en esa rama.
