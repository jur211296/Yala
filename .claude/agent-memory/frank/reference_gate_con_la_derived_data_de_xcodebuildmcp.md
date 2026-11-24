---
name: gate-con-la-derived-data-de-xcodebuildmcp
description: Con el disco justo en la Mini, el gate puede reusar la DerivedData de XcodeBuildMCP; apunta a la subcarpeta con hash, no a su padre, o duplica 6 GB.
metadata:
  type: reference
---

El 18-nov (Comparativa simple) el disco de la Mini estaba en 4,8 GB y un `xcodebuild` a pelo del gate habría creado
otra DerivedData de ~6 GB en `~/Library/Developer/Xcode/DerivedData`. Se reusó la de XcodeBuildMCP con
`-derivedDataPath`.

- La ruta buena es la subcarpeta con hash: `~/Library/Developer/XcodeBuildMCP/workspaces/<worktree>-<hash>/DerivedData/Yala-<hash>`.
  Apuntar a `.../DerivedData` (su padre) creó al lado `Build`, `SourcePackages` y compañía: 2,6 GB de golpe. Se borró
  con `shutil.rmtree` (el sandbox niega `rm -rf` con variables).
- El primer `test` de `Yala Dev` sobre esa carpeta recompila la app entera aunque XcodeBuildMCP ya la hubiera compilado
  con `Debug-Dev`: cuenta ~3 min más en el presupuesto de interfaz.
- Para el «antes» de varios aparatos sin una segunda DerivedData: guardar los `.swift` propios en un tar, `git checkout
  HEAD --` de esos ficheros, compilar (1 min incremental), copiar el `.app` al scratchpad y devolver los ficheros.

Relacionado: [[disco-de-la-mini-con-simulador-y-build-de-iphone]], [[el-antes-del-iphone-con-git-archive]].

**En la Max (23-nov, Sankey de subcategorías):** una DerivedData NUEVA para el build de `Yala Dev` del gate se colgó
30 min sin escribir nada al log, en `YalaWidgetsExtension` (xcodebuild vivo con 4 s de CPU). Matado y repetido sobre la
carpeta que ya había compilado el «después» (`-derivedDataPath <scratchpad>/dd-despues`): verde en ~2 min. ⇒ el gate
compila y prueba sobre la DerivedData del «después», no sobre otra de cero; y un log que no crece en 5 min es cuelgue.
