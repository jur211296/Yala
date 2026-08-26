# Estado

Fecha: 2026-08-26 (Lima)

- **Rama:** `2.1`
- **HEAD:** `f4cf3d2b` — Build 12 para TestFlight de 2.1
- **TestFlight:** 2.1 build 12 VALID
- **SSOT:** este repo (`jur211296/Yala`). No usar Obsidian / YalaWiki como fuente de verdad.
- **Tickets:** `tickets/` — índice en `docs/TICKETS.md`

## HOLD

store · tag · A7 · M5

## Discarded (Jurgen, 2026-08-26)

No PASS. No `tickets/done/`. CloudKit dead / no remaining written AC:

- `groups-cloud-mode-hardening-v1` → `tickets/discarded/`
- `groups-cloud-identity-loss-on-migrate` → `tickets/discarded/`
- `device-handover-groups-leak` → `tickets/discarded/`

## Abiertos

Absorción SSOT fase A+C: punteros y schema en este repo. Los 60 cuerpos de ticket y el texto de `planning/NOW.md` + `planning/DECISIONS.md` salen de `jur211296/YalaWiki` @ `1934e8ad`.

## Siguiente

Copiar los 60 tickets del mapa en `docs/TICKETS.md` (los 3 de arriba directo a `tickets/discarded/`) y el texto de NOW/DECISIONS cuando este entorno pueda leer YalaWiki.

## Bloqueo

Tras las setup actions del 2026-08-26 (App en YalaWiki + secret `YALAWIKI_GITHUB_TOKEN` marcados completed):

- `GET /installation/repositories` sigue listando solo `jur211296/Yala`.
- `YALAWIKI_GITHUB_TOKEN` no está en el entorno de **esta** VM (los user secrets se inyectan al arrancar el agente, no a mitad de run).
- `gh api repos/jur211296/YalaWiki` sigue en 404.

No se inventó ningún cuerpo de ticket. Un agente **nuevo** en esta rama, con el PAT o un token que incluya YalaWiki, puede copiar los 60 @ `1934e8ad`.

> Este ESTADO es el de la sesión de absorción (hechos medidos + owner), no una copia de `planning/NOW.md` del vault.
