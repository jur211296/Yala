---
id: image-entry-network-failure-reads-as-no-transactions
status: done
priority: high
area: "image"
created: 2026-10-04
source: recorrido del registro por imagen (encargo 2026-10-04-mejorar-el-registro-por-imagen-de-punta-a-punta)
---

# Si el servicio de imagen falla, la app dice «No se detectaron transacciones»

## Qué le pasa al usuario

Sube una foto clara de un recibo. Si la pasarela no responde (timeout de 20 s, App Attest, proxy caído, cuota),
la hoja dice **«No se detectaron transacciones en la imagen»**. El usuario concluye que la foto es mala y repite
con otra, que fallará igual. Lo que pasó es que el servicio no contestó.

## Dónde (medido en este árbol, base `5a7f6f9e6`)

`Yala/App/Views/Image/ImageSelectionView.swift`, `processAllImages()`: el `catch` de cada imagen solo imprime en
DEBUG (≈ línea 785) y el bucle sigue. Al final, `allDrafts.isEmpty` → `handleError(L10n.Image.errorNoData, …)`.
Un error de red, un timeout y «la foto no tiene importes» acaban en el mismo mensaje.

Cinco claves de error ya existen y ningún camino las dispara: `errorPhotoPermission`, `errorCorrupted`,
`errorUnrecognized`, `errorNoApiKey`, `errorGeneric`.

## Cómo se reproduce

Simulador (sin App Attest): Panel › «+» › Imagen › elegir cualquier foto → tras la cuenta atrás y el procesado,
«No se detectaron transacciones en la imagen».

## Relación con el rediseño

Si Jürgen elige una de las propuestas del lienzo del registro por imagen, sus fallos «en lenguaje de usuario»
(molde de `VoiceEntryFlowLogic`) cierran este ticket. Si no, el arreglo mínimo es distinguir el error del
servicio de «no hay importes» y reusar `errorNoApiKey`.

## Cerrado (2026-10-04)

Lo arregla el rediseño C del registro por imagen (`image-entry-end-to-end-redesign`).
