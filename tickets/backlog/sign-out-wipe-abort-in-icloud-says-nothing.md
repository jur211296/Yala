---
id: sign-out-wipe-abort-in-icloud-says-nothing
status: backlog
priority: low
area: "settings, modo-nube"
created: 2026-09-11
source: "paso 9 del rediseño de sesiones (`session-exits-one-verb-per-session`)"
updated: 2026-10-08
---

# Si el borrado de cierre falla en una sesión privada, la app vuelve sin explicar nada

Desde el paso 9, si al arrancar no se puede borrar el archivo del store (fallo de disco o de permisos) y el
modo es `.icloud`, el boot-wipe DESARMA el cierre en vez de reintentarlo: con el espejo montado, un
reintento posterior se llevaría cambios que nadie esperó a exportar. Los datos quedan intactos, pero la
persona, que tocó «Cerrar sesión» y reabrió, se encuentra dentro sin ningún aviso. Solo queda un breadcrumb
(`signOutWipeAborted … icloud, disarmed`).

## Qué hacer

Un aviso de una vez al arrancar («No pudimos cerrar tu sesión; tus datos siguen aquí») y un canario.

## Relacionado, y probablemente se funde con él

`sign-out-boot-wipe-has-no-way-back-if-it-aborts` (priority high) describe el mismo aborto desde el otro
lado: con el arm puesto la app se queda sin drains, sin recordatorios nuevos y con el widget congelado, y
`clearSignOutWipeArm` no tiene más llamador que el borrado que termina bien. Lo escribió el 2026-09-10 la
sesión de la mitad 2 del paso 5 y **todavía no está en `2.1`**: vive en la rama
`encargo/2026-09-10-groups-entry-on-a-mirrored-store-still-blocks-the-owner`, sin PR.

El paso 9 le resuelve **la mitad `.icloud`**: C, D y F desarman al abortar, así que no heredan el estado
degradado. La mitad `.cloud` sigue igual (la nube reintenta con el arm puesto). Lo que queda pendiente en
los dos es lo mismo, que el fallo se vea. Cuando aquella rama aterrice, este ticket se cierra dentro del
suyo.

## Medido en 2.1 (triage 2026-10-08)

- El aborto en `.icloud` sigue en `SwiftDataConfiguration.swift` (hacia `:606-624`): desarma el cierre y solo emite `signOutWipeAborted(reason: "store file deletion failed — icloud, disarmed")`, sin aviso ni canario.
- `sign-out-boot-wipe-has-no-way-back-if-it-aborts` sigue sin existir en `2.1`: solo vive en la rama `encargo/2026-09-10-groups-entry-on-a-mirrored-store-still-blocks-the-owner`, sin mergear.

Triage 2026-10-08: abierto · low → low · sigue sin aviso, pero los datos quedan intactos y hace falta un fallo de disco o de permisos al borrar el store.
