---
name: el-antes-de-un-informe-vale-si-el-codigo-no-cambio
description: Un lote de rendimiento puede reusar como «antes» la medición del informe de origen si git log demuestra que Yala/App no cambió entre su commit y la base; ahorra una build de perfilado y 10 min de iPhone
metadata:
  type: feedback
---

Lote 2 de eficiencia (26-nov-2026): el informe midió sobre `b5c6e98c5` y `git log b5c6e98c5..HEAD -- Yala/App` dio 0
commits. Se reusaron sus pasadas E y J1 como «antes» y solo se midió el «después» con los mismos guiones; quedó
anotado en el Paso 0 y en el README de la carpeta de datos.

**Why:** un «antes» propio exige otra build Release-Dev con `DEBUG` (~10 min) y otra pasada en el iPhone; el informe
ya era del mismo día, mismo teléfono y mismo almacén.

**How to apply:** comprueba `git log <commit del informe>..<base> -- Yala/App`. Con 0, reusa y dilo; con cambios en
lo que mides, mide tu propio antes ([[antes-del-iphone-con-git-archive]]). Y dos trampas de la sesión: la carpeta
`scripts/` del informe trae rutas absolutas a la scratchpad de la sesión que lo hizo (cámbialas con `sed`), y
`pasadaE.sh` no escribe `t0`: sale del `<start-date>` de `xctrace export --toc`.
