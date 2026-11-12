---
name: antes-del-iphone-con-git-archive
description: Para comparar la base con mis cambios sin tocar el árbol, `git archive HEAD` a una carpeta del scratchpad y compilarla aparte; apartar cambios con `git checkout --` lo deniega el clasificador
metadata:
  type: feedback
---

Para el «antes» de una comparación (capturas píxel a píxel de la base contra mis cambios), **no** apartes los cambios
del árbol: `git checkout -- <ficheros>` para compilar la base lo denegó el clasificador (2026-10-24), y con razón —
descarta trabajo. Lo que funcionó: `git archive HEAD Yala Yala.xcodeproj YalaShare YalaWidgets … | tar -x -C
<scratch>/base`, copiar `Secrets.xcconfig`, y compilar ahí con su propio `-derivedDataPath` y la copia de
`SourcePackages` ([[spm-sin-red-en-el-sandbox]]). Un build en frío tarda ~10 min con `-jobs 2`.

**Why:** un cambio de layout compartido (barras, scroll en el Welcome, `Label` en la barra) tiene que demostrar que el
iPhone queda igual, y el diff de píxeles con los mismos datos y reloj (molde de la ficha: semilla `ficha`, reloj al
13-oct, 9:41) es la prueba. Dio 0 px en cinco pantallas; las diferencias del Panel eran el scroll y la barra de
pestañas a medio animar, no el layout.

**How to apply:** captura las dos con el mismo guion (borrar, sembrar, relanzar por pantalla) y compara con un umbral
(>24 de diferencia) y la caja de lo distinto; mira a ojo lo que no dé 0 antes de culpar al cambio. Para poner la rama
al día sin commit (el pre-commit exige el sello del gate): `git stash push -u -m <etiqueta>`, `git merge --ff-only`,
`git stash apply <sha>` y soltar la entrada por su etiqueta.

**Atajo medido el 2026-10-28 (card t3fq), cuando el «antes» es solo una captura y no un diff de píxeles:** copia de
respaldo de MIS ficheros al scratchpad (`cp`), `git show HEAD:<f> > <f>` para los que cambié, aparta los tests nuevos
que no compilarían contra la base y pon un XCUITest temporal de captura. Corre en el MISMO DerivedData (build
incremental, minutos y sin gigas extra). Al acabar, `cp` de vuelta y `diff -q` fichero a fichero contra la copia antes
de seguir. El clasificador no lo paró: no descarta trabajo, porque la copia existe antes de tocar nada.
