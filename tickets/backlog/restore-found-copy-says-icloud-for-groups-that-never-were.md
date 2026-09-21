---
id: restore-found-copy-says-icloud-for-groups-that-never-were
status: backlog
priority: low
area: "welcome, icloud, restore, l10n"
created: 2026-09-21
updated: 2026-09-21
source: "medición durante `restore-treats-budgets-and-groups-as-no-data` (2026-09-21): al añadir los grupos al criterio de «hay datos» salió que los grupos NO viajan por iCloud"
---

# «Encontramos tus datos en iCloud» a quien solo tiene grupos, que no están en iCloud

## El problema, en lenguaje de usuario

Entro por un grupo compartido, y luego en el Welcome toco «Restaurar desde iCloud». La app me
enseña la pantalla del hallazgo con **«Encontramos tus datos en iCloud: 2 grupos compartidos»**. Mis
grupos existen y la cifra es correcta; lo que no es cierto es el **en iCloud**: mis grupos no están
ahí, están en la cuenta de Yala.

## Medido (2026-09-21)

- `SplitGroup` vive en `groupsSchema` (`SwiftDataConfiguration.swift:118-126`), cuyo store monta
  `cloudKitDatabase: .none` (`:1060`). Sus filas llegan por el backend de Yala
  (`GroupsSyncClient.applyGroupMeta` inserta el born-remote; `GroupBackendMembershipService` al
  unirse). **No hay ningún `CD_SplitGroup` en el contenedor personal de CloudKit.**
- `welcome.restore.foundBody` = «Encontramos tus datos en iCloud:» (los 16 locales). Es el único
  texto de `foundView` que nombra el origen; el título no lo hace.
- `groupsCount` **no** cuenta para `hasAnyData` (se midió y se descartó en
  `restore-treats-budgets-and-groups-as-no-data`, D1), así que el caso PURO solo-grupos **no alcanza
  `.found`**: a esa persona la pantalla le dice, correctamente, que en iCloud no hay nada suyo.

## Cuál es exactamente la población

La card de grupos **sí se sigue pintando** cuando hay grupos Y algo que vino de iCloud. Ahí la
frase es cierta para el hallazgo —sus cuentas o sus presupuestos sí estaban en iCloud— y engloba
una cifra que no lo estaba. El encabezado afirma un origen común para cinco cifras que no lo
tienen.

## Por qué salió en backlog y no se arregló en el sitio

Tres razones, y la tercera es la que decide:

1. **La rule de l10n dice «no reescribas copy que ya funciona»**, y la frase es correcta para toda
   la población menos ésta.
2. Cualquier arreglo toca **16 locales** — bien un `foundBody` alternativo con clave nueva, bien
   quitarle «en iCloud» al existente.
3. **El residual es decir de más de DÓNDE vienen unos datos que SÍ existen y SÍ se enseñan.** Nadie
   pierde nada ni toma una decisión equivocada por ello: la cifra es correcta y la pantalla conserva
   los datos. Es imprecisión de encabezado.

## Qué habría que decidir

- ¿Quitarle «en iCloud» a `welcome.restore.foundBody` para todo el mundo (una edición por locale,
  ninguna clave nueva), o dejarlo? La frase pierde un matiz que la mayoría sí agradece.
- ¿Merece la pena a esta prioridad, o se deja escrito y se cierra como aceptado?

## Relación con otros tickets

- `restore-treats-budgets-and-groups-as-no-data` — de donde sale (su D6).
