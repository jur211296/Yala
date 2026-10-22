---
name: rojo-conocido-no-exime-de-bisecar
description: Un test documentado como flaky o preexistente puede estar rojo HOY por tu cambio. Bisecar contra el árbol base cuesta minutos y es lo único que distingue las dos cosas.
metadata:
  type: feedback
---

**Un rojo que la documentación llama «flaky» o «preexistente» se biseca igual antes de archivarlo.**
Los dos estados producen exactamente la misma línea en el log; solo la medición los separa.

**Why:** el 2026-09-06, `QuickActionsFavoritesUITests.test_saveAsFavoriteFromTransactionAppearsInList`
salió rojo en mi gate. Estaba documentado como flaky en **dos sitios** (`secondary-visitor-writes-owner-domain`
lo lista como «flaky que pasó al reintento», y `uitest-compara-fechas-sin-fijar-locale` lo cita entre
cuatro rojos preexistentes de `2.1` medidos comparando dos runs de CI). Archivarlo habría sido lo
cómodo y lo defendible. **Era mío**, y no un detalle: había roto **el guardado de una transacción**
para toda la app. En el árbol base pasaba; en el mío fallaba 2 de 2.

El mismo día y en la misma tanda, `EdgeCasesUITests.test_extremeMinimumAmountSaves` dio el mismo
síntoma, en la misma línea del mismo helper — y ése **sí** era preexistente. Falla igual con
`ContentView.swift` revertido a HEAD. **Dos rojos idénticos en el log, causas opuestas.**

**How to apply:**

1. **Aislado primero** (`-only-testing:` del caso concreto). Separa el flake del fallo determinista y
   cuesta un par de minutos. Si pasa, era carga o entorno — y si la corrida murió por memoria, o el
   disco está por debajo del umbral, eso ya es la explicación.
2. **Si es determinista, biseca contra el árbol base.** Dos vías, la segunda mucho más barata:
   `git worktree add --detach <tmp> <commit-base>` —recuerda **copiar `Secrets.xcconfig`**, que no
   está en git y sin él el build muere con «Unable to open base configuration reference file» y **cero
   casos**— o, si el sospechoso es un fichero concreto, `git show HEAD:<f> > <f>` con respaldo previo
   por `cp` y restaurar igual. Nunca `git checkout --` en árbol sucio.
3. **Dentro del fichero, biseca por trozos y con control en las dos direcciones.** Lo que convierte
   una sospecha en causa no es que quitarlo lo arregle: es que **volver a ponerlo lo rompa otra vez**.

**Y el corolario que más caro sale:** un cambio de presentación aparentemente inerte puede romper un
flujo cualquiera. Mi rojo salió en «guardar como favorito», un área que ningún cruce de `codeGlobs`
habría señalado como afectada por un cambio en invitaciones de grupo. ⇒ **cuando toques `ContentView`
o cualquier anchor de presentación, corre la suite XCUITest ENTERA**, no las áreas que el índice
cruza. Y si la máquina no aguanta, córrela en tandas — pero córrela.

Relacionado: [[el-arbol-base-contesta-si-es-mio]] · [[review-adversarial-caza-lo-mio]] ·
[[el-orden-del-enum-se-ve-fuera]]

**Y un flaky documentado puede dejar de comportarse como flaky (2026-09-11).** El ticket del helper que
guarda transacciones decía «un rojo por corrida y la víctima cambia», así que la comprobación barata era
re-correrlo y ver si se mudaba. Ese día **no se mudó**: `TransactionsCrudUITests.test_createTransaction`
falló en su lote y volvió a fallar a solas. Con la firma del ticket rota, lo único que clasificaba el rojo
era **correr esa clase sola en un worktree desde el commit base** — cayó igual, con la misma duración, y
quedó probado que no era mío. Cuesta 90 s y un `git worktree add`.

**How to apply:** la prueba que zanja «¿es mío?» es el ÁRBOL BASE, no la estadística del flaky. Y cuando
midas algo que contradiga la descripción del ticket, escríbelo ahí: la próxima sesión va a aplicar su
receta vieja.
