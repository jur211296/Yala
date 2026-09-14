---
name: apple-id-cierra-la-sesion-privada
description: PR #159 — cambiar el Apple ID del teléfono ya cierra la sesión privada, con confirmación. El ticket decía «alinear un aviso» y en realidad no había detección que alinear; la review cazó 14 defectos míos.
metadata:
  type: project
---

**PR #159 (2026-09-14): cambiar la cuenta de iCloud del teléfono con una sesión privada viva ya ofrece
cerrarla y borrar la copia local.** Decisión 1B de Jürgen: pasa por confirmación, no es silencioso.

**Why:** ADR 2026-09-09 §1 — la sesión privada es del Apple ID; si el Apple ID cambia, esos datos son de
una cuenta que ya no está. Hasta hoy la app seguía enseñando las finanzas del dueño anterior a quien
tuviera el teléfono.

**How to apply:**

- **La premisa del ticket era falsa y eso cambió el trabajo entero.** `checkForICloudMismatch` NO
  reacciona al cambio de cuenta (pregunta «¿monté sin espejo y ahora hay iCloud?») y **la app no
  guardaba ningún testigo del Apple ID con el que montó**. No había nada que alinear: había que
  construir la detección. Ese aviso viejo sigue vivo y es correcto — lo único que se le añadió es que
  se calle mientras el nuevo decide.
- **La identidad sale de `CKContainer.userRecordID()` del contenedor PERSONAL**, no del token de
  ubiquity (mide iCloud Drive) ni del contenedor de Grupos (tiene caducidad escrita: la Fase 4 le
  retira el entitlement). La notificación `NSUbiquityIdentityDidChange` es el **disparador**, jamás el
  veredicto.
- **Cuelga del arranque y del observer, NO de `handleBecameActive`** — con eso el criterio «no dispara
  repetidamente» se cumple por construcción, y lo fija un source-scan.
- **Deja dos tickets:** `apple-id-close-blocked-has-no-visible-outcome` (**high** — si el cierre se
  bloquea nadie lo enseña y el coordinador queda tapiado: pide una pantalla con fases, que además
  traería la hoja de alcance que este camino salta) y el device-QA, que **no es simulable** y lleva dos
  recorridos salidos de la review: el control negativo de iCloud Drive y si el espejo sube el corpus
  viejo a la cuenta nueva con «Ahora no».
- **La review adversarial cazó 14 defectos MÍOS con la suite en verde**, cinco de ellos con cambio de
  código. El peor: el testigo sobrevivía a «Empiezo de cero» y al dueño nuevo le habría ofrecido borrar
  sus propios datos. Ver [[el-testigo-vive-menos-que-lo-que-describe]].
- **Dos contadores del eje 1 subieron y hay que saberlo:** `confirmedPrivateSession` de 3 a **5** (este
  cierre aporta dos lecturas, no una: el pre-filtro y la re-lectura tras el `await`) y
  `hasPrivateSession` de 16 a **17** (la celda resuelta en el tap del aviso, donde el signo del error es
  el contrario). Los dos los obliga un test de `PrivateSessionMarkTests`, que es como se descubrió.

Relacionado: [[rediseno-sesiones-dos-ejes]] · [[eje1-marca-sesion-privada]] ·
[[only-testing-filtra-por-tipo-no-por-fichero]]
