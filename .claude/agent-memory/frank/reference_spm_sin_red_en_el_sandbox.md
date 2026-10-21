---
name: spm-sin-red-en-el-sandbox
description: xcodebuild dentro del sandbox se cuelga resolviendo paquetes (sin red a GitHub); fuera del sandbox la red a GitHub corta a ratos — usar una copia de SourcePackages
metadata:
  type: reference
---

En la Mini, un `xcodebuild` lanzado desde el Bash con sandbox se queda minutos en «Resolve Package Graph» con
`Couldn't fetch updates … Operation timed out` (medido el 2026-10-20): el sandbox no tiene red. Fuera del sandbox
(`dangerouslyDisableSandbox`) la red existe, pero GitHub cortó dos veces (`Connection reset by peer`) y el build murió.

Lo que funcionó: copiar `SourcePackages` del DerivedData del árbol principal (`/Volumes/ExtDev/DerivedData/Yala-<hash>/`,
el de `WorkspacePath` = `/Users/jur/Yala/…`, ~200 MB) al scratchpad, comprobar que `Package.resolved` es idéntico, y
compilar con `-clonedSourcePackagesDirPath <copia> -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile`.
Copia y no la ruta del árbol principal: ese DerivedData es de Jürgen. Relacionado: [[deriveddata-en-extdev]].
