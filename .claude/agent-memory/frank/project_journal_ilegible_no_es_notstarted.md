---
name: journal-ilegible-no-es-notstarted
description: PR del 22-sep: un journal de migración que no se deja leer ya no es `notStarted` ni borra motivos; la review cazó que mi fail-closed dejaba el motor `.idle` hasta relanzar.
metadata:
  type: project
---

El 22-sep (cola A autónoma) cerré `an-unreadable-migration-journal-reads-as-never-started`: `JournaledPhaseRead`,
`MigrationPhaseStore.currentPhaseRead`, estado de UI `.journalUnreadable`, y los cuatro `try?` de la pantalla. Ticket en
`done` sin device-QA (el caso no tiene guion en un iPhone; lo cubre un XCUITest con seam).

**Why:** la review adversarial (4 lentes) cazó dos defectos serios del propio arreglo —el motor `.idle` que nadie
re-evaluaba y `.journalUnreadable` colándose como «dentro» por un `!= .idle`— y cambió el diseño en seis puntos. 33/33
mutantes muertos tras ello.

**How to apply:** si vuelve a tocarse la lectura del journal, empezar por la regla de `swiftdata-cloudkit.md` que empieza
por «Un journal que no se deja leer NO es `notStarted`». Residuales con ticket: `an-undecodable-migration-phase-reads-as-never-started`
y `apple-id-change-boot-check-runs-before-the-migration-guard-can-see`. Ver [[un-fail-closed-sin-reintento-es-permanente]]
y [[un-case-nuevo-hereda-cada-distinto-de]].
