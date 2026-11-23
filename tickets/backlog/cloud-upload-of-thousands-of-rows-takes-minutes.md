---
id: cloud-upload-of-thousands-of-rows-takes-minutes
status: backlog
priority: medium
area: "cloud, import, performance"
created: 2026-11-22
updated: 2026-11-22
source: "lote 1 de Importar registros (2026-11-22), medición de `import-of-thousands-of-rows-in-cloud-mode-is-unmeasured`"
---

# Subir miles de filas a la nube tarda minutos

## Qué ve el usuario

En modo nube, tras importar 3.000 movimientos el otro teléfono no los ve hasta ~7 minutos después; deshacer ese import, otros
~6,5 minutos. Bajar es rápido (9-16 s): lo lento es subir.

## Evidencia (medido)

`YalaTests/ImportarLote1/ImportarLote1NubeStagingTests` contra staging (`TEST_RUNNER_YALA_CLOUD_E2E=1`, usuario A), simulador
en la Mac mini: 3.003 filas en 61 peticiones de 50 (`SyncPushClient.pushChunkSize`), 409 s; 3.000 borrados, 391 s. Unos
6,7 s por petición, sin reintentos. No se aisló si el tiempo es del Worker, de `apply_delta` fila a fila en Supabase o de la
red.

## Propuesta

Medir dónde se va cada petición (tiempos del Worker y de la RPC en staging) antes de tocar el tamaño del trozo: subirlo sin
saber la causa puede pasar el límite de CPU del Worker. Relacionado: `debounce-sync-imported-transactions`.

## Criterio de hecho

- [ ] Causa medida.
- [ ] 3.000 filas visibles en el otro teléfono en menos de 1 minuto, o la razón por la que no se puede.
