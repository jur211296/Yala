---
id: migrate-retry-after-a-sign-out-meets-its-own-half-claimed-account
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-29
source: "review adversarial de `a-previous-owners-claim-seal-passes-the-cloud-identity-gate` (lente 1, H1)"
---

# Si cancelo «Migrar a la nube», cierro sesión y vuelvo, no puedo terminar la migración a esa cuenta

## El problema, en lenguaje de usuario

Empiezo a migrar mis datos a una cuenta nueva y lo cancelo a mitad. Cierro la sesión privada, vuelvo a entrar y restauro
mi iCloud. Al reintentar «Migrar» a la misma cuenta, Yala me dice que esa cuenta ya tiene datos, y no puedo terminar.

## Por qué pasa (INFERIDO, sin medir en dispositivo)

- El claim del primer intento deja la cuenta `complete` con este teléfono de líder, y el sello `.proceedMigration` (o la
  marca del claim sin respuesta) es lo que deja reintentar (`StorageMigrationIdentityGateLogic.check`, `claimedForMigrationHere`).
- Desde `a-previous-owners-claim-seal-passes-the-cloud-identity-gate` (2026-09-29) el borrado del cierre de sesión olvida
  los sellos de todas las cuentas: el teléfono no distingue si quien vuelve es la misma persona u otra, y un sello
  superviviente dejaba entrar a la cuenta anterior sobre los datos de la siguiente.
- Así que el reintento llega a la puerta sin sello y la cuenta `complete` se lee como ajena.

## Qué medir primero

1. Si el claim de un «Migrar» cancelado al 22 % deja de verdad la cuenta `complete` y si el servidor le devuelve `created`
   al mismo dispositivo (g16_01): si es así, la salida puede ser del servidor y no del sello.
2. Qué ve la persona: si el aviso le da alguna salida (otra cuenta, borrar la cuenta a medias).
