---
name: el-testigo-se-apunta-antes-de-conducir
description: un testigo durable escrito DESPUÉS de la llamada que conduce la máquina pierde el kill de su primera pasada; y una marca de sesión se ata a la SESIÓN, no a la cuenta
metadata:
  type: feedback
---

Apunté la marca «esta sesión la abrió el adopt» después de `submit(.signInSucceeded)` para no leer como salida una pasada
que no llega al claim. Las dos lentes cazaron lo mismo: ese `submit` conduce la primera pasada ENTERA (claim y hasta el
efecto), así que un kill ahí dejaba el adopt sin marca y su salida días después no cerraba nada. La forma buena fue
apuntar ANTES y retirar después si la llamada no llegó al claim.

La segunda: la ataba al hash de la CUENTA, y una sesión de Grupos firmada después con esa misma cuenta la heredaba. La
marca muere con cada sign-in y sign-out.

**Why:** 2026-09-24, `adopt-exit-keeps-the-session-it-opened`. Los dos fallos eran de mi diseño, no del código de antes.

**How to apply:** un testigo durable que describe «lo que empezó este intento» se escribe antes del primer `await` que
puede avanzar la máquina, y se retira si no avanzó. Si describe una sesión, lo borra quien crea o destruye sesiones.
Relacionado: [[el-testigo-vive-menos-que-lo-que-describe]], [[una-marca-que-abre-una-entrada-se-ata-a-quien-la-gano]].
