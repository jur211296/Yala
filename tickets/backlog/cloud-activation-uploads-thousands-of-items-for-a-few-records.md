---
id: cloud-activation-uploads-thousands-of-items-for-a-few-records
status: backlog
priority: medium
area: "sync, cloud"
created: 2026-11-05
updated: 2026-11-05
source: "QA en el iPhone de pruebas del 2026-11-05 (montaje B1) · relacionado: card tablero-al-activar-la-nube-algunas-categorias-y-70nl, ticket cloud-activation-time-is-unmeasured-between-the-claim-and-the-cutover"
---

# Activar la nube sube miles de elementos para un puñado de datos, y por eso tarda 8 minutos

## Lo que ve la persona

Con 2 registros y 2 cuentas, «Activar la nube» tardó 8 min 25 s, casi todo en «Subir tus datos», que contó de 15 a
**3333 de 3333** de 50 en 50 cada ~6 s. Para quien tenga pocos datos, la espera no se corresponde con lo que tiene.

## Lo medido

iPhone 14, iOS 27.2, Yala Dev sobre `origin/2.2` (#809), iCloud privado restaurado de iCloud («2 registros, 2 cuentas,
62 categorías»). Registro de la pantalla cada 5 s: `~/Claude/entregas/2026-11-05-qa-dispositivo-fisico-device-mcp/evidencia/B1-registro-activar-la-nube.txt`.

## Sin medir

Qué son los 3333. Hipótesis por comprobar: el historial de tipos de cambio, categorías del sistema y de iCloud
duplicadas (la vista previa de iCloud dijo 124 categorías y la de restaurar 62, el doble; ver
`icloud-restore-preview-counts-categories-twice`), o tombstones. Siguiente paso: contar por entidad lo que encola la
subida antes de cambiar nada.
