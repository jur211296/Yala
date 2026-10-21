---
name: qa-guiado-2-1-espera-tf19
description: El QA guiado de 2.1 (sesión Yala--qa-guiado-2-1-tf17) sigue abierto a propósito; tras el TF19 (20-oct) espera 4 cards de 2.1 y un TestFlight 20 para otra tanda corta.
metadata:
  type: project
---

Sesión del QA guiado de 2.1 abierta a petición de Jürgen («no la cerremos aún, ya vendrán las cards que faltan»). PR
#563 abierto, SIN cola de merge: lleva el resultado del TF18 (19-oct) y la tanda + resultado del TF19
(`docs/qa/tanda-qa-jurgen-2.1-tf19.md`, 20-oct).

**Why:** el 20-oct, sobre el TF19, pasaron 8171, 9ttd, ewkw, cq2i, gk5w (E2), n2xn, axgf; falló t2q8 (bienvenida ›
invitación con cuenta completa, y relanzamiento a mitad → «queda en blanco»); ppxk pasó a 2.2 alta. Quedan para 2.1,
con las decisiones de Jürgen ya en las cards y enviadas al bot Frank: t2q8, 840m (rechazar solicitud en grupo de la
nube: implementarlo en backend), blqa (revisión de iCloud > 25 s: 2.1), z81w (invitación 10-15 s en la bienvenida: 2.1
con pantalla «Abriendo tu invitación…»).

**Actualizado 20-oct 21h:** las 4 entraron con el #577 (`e47b5cca9`) y el TF20 está VALID (PR #578). La tanda corta es
`docs/qa/tanda-qa-jurgen-2.1-tf20.md`, toda en Yala Dev (compilado desde el #577 en el mismo DerivedData).

**How to apply (histórico):** cuando Frank cierre esas 4, subir un TestFlight 20 (lanzar-sesion como el 19, receta en
`encargos/lanzados/2026-10-20-subida-testflight-19-2-1.md`) y hacer una tanda corta **en Yala Dev contra staging**
salvo lo que exija producción ([[qa-en-yala-dev-antes-que-prod]]). Estado al pausar: staging y producción SIN cuentas de
prueba (solo las i5-* fijas de staging); el iPhone de QA tiene Yala Dev (privado) y una Yala de TestFlight que apunta a
una cuenta borrada; el iPad tiene iCloud `test@yala-app.pe` hasta que Jürgen lo devuelva. Yala Dev de `ad6781f8a` en
`/Volumes/ExtDev/DD-qa-guiado-tf17/…/Debug-Dev-iphoneos/Yala.app` (recompilar desde origin/2.1 al retomar).
E2 de verdad exige que el segundo aparato ADOPTE («Activar en este dispositivo»), no que entre con «Ya tengo una cuenta».
Relacionado: [[el-guion-se-adapta-al-estado-del-telefono]].
