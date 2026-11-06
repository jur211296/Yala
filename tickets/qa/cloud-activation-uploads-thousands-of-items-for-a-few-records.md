---
id: cloud-activation-uploads-thousands-of-items-for-a-few-records
status: qa
priority: medium
area: "sync, cloud"
created: 2026-11-05
updated: 2026-11-05
source: "QA en el iPhone de pruebas del 2026-11-05 (montaje B1) · card tablero-activar-la-nube-sube-3333-elementos-para-i9wh"
---

# Activar la nube sube miles de elementos para un puñado de datos, y por eso tarda 8 minutos

## Lo que ve la persona

Con 2 registros y 2 cuentas, «Activar la nube» tardó 8 min 25 s, casi todo en «Subir tus datos», que contó de 15 a
**3333 de 3333** de 50 en 50 cada ~6 s.

## Medido (2026-11-05, noche)

- **Qué son los 3333.** Store del iPhone 14 de pruebas copiado con `devicectl` (App Group de `Yala Dev`): `ExchangeRate`
  3234 filas para **383 días distintos** (hasta 9 copias del mismo día), subcategorías 69, categorías 13, avisos 7,
  movimientos 3, cuentas 2. Total ~3328: el 97 % son copias de tipos de cambio.
- **De dónde salen.** `persistRate` no duplica en local (busca por `dateKey`), pero cada instalación siembra su año de
  tasas antes de que llegue el import de iCloud, y el espejo junta las copias de todas. El iPhone de pruebas se
  reinstala a menudo: 9 copias.
- **Dónde se va el tiempo** (Analytics Engine de staging, instalación `b20327d9`): `upload>verify` 459 s,
  `verify>cutover` 33 s, `identity>upload` 1 s. La espera al import de iCloud no pesa.

## Arreglo

La subida de la ida funde las tasas del mismo día y base antes de enumerar (`ExchangeRateDuplicateLogic`,
`MigrationSnapshotUploader.fuseDuplicateExchangeRates`): queda la de menor `syncID` —la misma en dos dispositivos— con
las tasas de todas, y el resto se borra. Va antes del baseline del historial, así los borrados no viajan al backend,
que nunca conoció esas filas. Canario `cloudSnapshotDuplicateRatesFused` (días, filas borradas). Con los datos del
iPhone de pruebas la subida pasa de ~3330 a ~480 elementos.

Tests: `ExchangeRateDuplicateLogicTests` y `MigrationSnapshotUploaderTests#duplicateRates_*`; mutante (fusión detrás del
baseline) → rojo.

Fuera: la causa de fondo (las copias se siguen creando en iCloud) va en
`exchange-rates-duplicate-per-day-across-installs`.

## Guion de QA (iPhone de pruebas, Yala Dev con este build)

1. Con datos en iCloud restaurados (los de hoy valen), «Dónde viven tus datos» → «Activar la nube».
2. En «Subir tus datos», la cifra total ronda los 480, no los 3333.
3. Cronometra: la activación entera debería bajar de 8 min a 1-2 min.
