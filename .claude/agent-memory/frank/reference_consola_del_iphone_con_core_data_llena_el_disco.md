---
name: consola-del-iphone-con-core-data-llena-el-disco
description: devicectl --console con -com.apple.CoreData.Logging.stderr 1 escribe GB en minutos y llenó la Mini; filtrar con grep --line-buffered y sin cut detrás; parar la consola cierra la app
metadata:
  type: reference
---

Medido el 2026-11-17 de madrugada en la Mini (encargo de la vuelta a iCloud que vaciaba el store): una ida de 3.260 filas
con `xcrun devicectl device process launch --console … -- -com.apple.CoreData.Logging.stderr 1` volcado a un fichero del
scratchpad, junto a dos DerivedData propios (9,4 + 4 GB), dejó el disco a CERO. Todo falla a la vez: los dos builds del
gate salen `BUILD FAILED` sin decir disco, ningún Bash arranca (ENOSPC en la carpeta temporal de Claude Code) y el `Write`
tampoco (escribe un `.tmp` al lado).

- Captura la consola así: `… --console … 2>&1 | grep --line-buffered -E "cloudMigrationStep|…" > fichero`. Con un `| cut`
  detrás del grep el fichero se queda VACÍO hasta que acaba (cut no vacía por línea).
- Para leer qué hizo el espejo no hace falta el stderr de Core Data: el store lo guarda (`ANSCKEVENT` y el autor de
  `ATRANSACTION`), ver `docs/aprendizajes-tecnicos.md` («Qué hizo el espejo de iCloud…»).
- **Parar la tarea de `devicectl --console` (TaskStop) CIERRA la app** en el iPhone: la ida se cortó a mitad de la
  verificación (se retomó sola al reabrir).
- Sin espacio y con `rm` denegado en nocturno (el bot no recibe hasta las 05:30): `XcodeBuildMCP clean` sobre tu
  DerivedData libera sin Bash, y luego `mv` de tu propio DerivedData a `/Volumes/ExtDev/DerivedData/_aparcado-…` deja
  sitio sin borrar nada. Ver [[borrar-en-disco-lo-hace-el-bot]].
