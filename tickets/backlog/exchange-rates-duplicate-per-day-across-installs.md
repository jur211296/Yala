---
id: exchange-rates-duplicate-per-day-across-installs
status: backlog
priority: low
area: "divisas, iCloud"
created: 2026-11-05
updated: 2026-11-05
source: "medición de la card i9wh (2026-11-05): 3234 tasas para 383 días en el iPhone de pruebas"
---

# Cada instalación siembra su año de tipos de cambio y iCloud acumula copias del mismo día

## En lenguaje de usuario

Nada visible hoy, salvo lo que ya se arregló en «Activar la nube». Pero el iCloud de quien reinstala o tiene varios
dispositivos guarda varias copias del tipo de cambio de cada día, y crece con cada instalación.

## Medido

iPhone de pruebas (reinstalado a menudo): 3234 filas de `ExchangeRate` para 383 días, hasta 9 por día.
`persistRate` busca por `dateKey` antes de insertar, así que en un teléfono no duplica: las copias nacen porque
`preloadHistoricalIfNeeded` corre en el primer arranque antes de que baje el import de iCloud, y luego el espejo trae
las de las otras instalaciones.

## Sin decidir

Si merece una fusión en el arranque para todos (la lógica ya existe: `ExchangeRateDuplicateLogic`), o retrasar la
siembra hasta que el import se asiente. Inferido, sin medir: `fetchExchangeRate` devuelve `results.first`, así que con
copias la tasa que se lee de un día puede variar entre lecturas si las copias no traen las mismas divisas.
