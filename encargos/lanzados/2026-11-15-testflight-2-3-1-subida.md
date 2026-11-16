Yala
# Subir Yala 2.3 (1) a TestFlight: retomar el checkpoint con el campo de iCloud en Production
---
toca: Yala.xcodeproj/project.pbxproj, docs/qa/testflight-2-3-1/
esfuerzo: medium
cierre: cierra-sola
---

## Contexto
Continuación del checkpoint nocturno del PR 986 («[checkpoint nocturno] Subir Yala 2.3 (1) a TestFlight», rama del encargo del 15-nov). Ese intento paró solo por una pregunta: 2.3 añade el campo `CD_brandLogoID` (texto, en `CD_ScheduledPayment`) y no había registro de que estuviera en Production de `iCloud.com.jurgenschmidt.yala`.

Jürgen respondió el 15-nov a las 07:42 Lima: «Que lo haga Dan ya si es que no está. Lancemos la subida.» Dan despliega el campo en Production desde el panel de CloudKit. También decidió que los fallos y bugs del barrido final se encolan aparte: NO frenan esta subida.

## Qué se pide
0. Retoma la rama y el trabajo del PR 986 (trae `origin/2.3`, resuelve si choca). Comprueba en solo lectura si `CD_brandLogoID` ya existe en Production. Si no está, NO lo despliegues tú: espera con la sesión viva comprobando cada 10 minutos hasta 90 minutos. Si a los 90 minutos sigue sin estar, es bloqueo real: `BLOQUEANTE:` y checkpoint según el modo.
1. Con el campo en Production, sigue el plan original: MARKETING_VERSION 2.3 y CURRENT_PROJECT_VERSION 1 en todos los targets, `origin/2.3` en verde, PR mergeado a 2.3.
2. Cualquier OTRO cambio de esquema de CloudKit o de Supabase Production que no esté desplegado sigue siendo decisión vital: pregunta con la lista exacta.
3. Archiva, sube a App Store Connect, espera a que quede procesado y asígnalo al grupo interno de TestFlight. Notas cortas en español neutro latinoamericano con lo nuevo de 2.3.
4. Instala desde TestFlight en el iPhone 14 por DeviceMCP y haz la prueba de humo: abrir, registrar un gasto, nube y Grupos.

## Entregable
Artifact visual corto de Claude (fuente en `docs/qa/testflight-2-3-1/`): qué build subió, si está procesado, la prueba de humo y lo que Jürgen debe mirar en TestFlight (de la tanda de indispensables del barrido, `docs/qa/tanda-qa-jurgen-2.3-barrido-final.md`). Cierra la card «Espera decisión · Subir Yala 2.3 (1) a TestFlight».

## Reglas
- Commits y PR sin firma de IA. No imprimas secretos.
- Si falta un acceso o un certificado, no lo inventes: pregunta.
- Puedes usar un segundo simulador o el iPhone 14 por DeviceMCP.
- /cerrar-total cuando el build esté en TestFlight y la prueba de humo hecha.

## Paso 0 — decisiones (modo semi)

1. **¿`CD_brandLogoID` está en Production?** Desde la Max no se puede medir (sin token de `cktool`). Se preguntó al bot (07:45); Dan lo revisó en la consola: ya estaba en Production en `CD_ScheduledPayment` de `iCloud.com.jurgenschmidt.yala` (String, sin índice propio). No hubo que desplegar nada.
2. **Otros cambios de esquema:** `CD_systemRoleRaw` ya estaba desplegado (Dan, 14-nov). Supabase: las migraciones de 2.3 son de Yala web/panel/gateway, no de la app iOS; esta subida no aplica ninguna.
3. **Versión:** se reusa el commit del checkpoint (2.3 / 1 en los 20 targets) sobre `origin/2.3` al día; el PR del checkpoint se cierra sustituido por este.
4. **Bugs del barrido final:** se encolan aparte (decisión de Jürgen, 07:43); no frenan la subida.
5. **Pase de estrés:** no aplica: la subida no cambia UI respecto a lo que barrió QA.
