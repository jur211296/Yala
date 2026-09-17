---
name: acciones-grupos-token-nulo-pasajero
description: Encargo nocturno del 17-sep — salir de un grupo y aceptar una invitación sin red ya no leen el token nulo como sesión caducada; en qa con guion de iPhone sin ventana estrecha; una decisión low espera a Jürgen
metadata:
  type: project
---

`groups-actions-read-an-offline-token-refresh-as-a-session-expiry` queda en `qa` (PR del 2026-09-17, sesión nocturna y
autónoma). Cierra el tercer sitio del patrón: canal de sync de Grupos (15-sep), canal personal (#188, 16-sep) y ahora las
acciones de Grupos (`GroupsMembershipClient.call`).

**Lo que espera cada cosa:**

- **El device-QA** no tiene ventana estrecha, a diferencia del personal: la acción pide el token antes que App Attest, así
  que basta con pasar `exp` en modo avión. El guion distingue builds (la vieja dice «Tu sesión caducó» y abre la hoja de
  inicio de sesión al aceptar una invitación).
- **`groups-join-is-not-retried-when-the-network-returns`** (low): decisión de Jürgen. Quitar el bucle de la hoja de
  inicio de sesión quitó, por accidente, el único reintento continuo de la unión; y la app no tiene vigilante de conexión
  a propósito (D6 del 15-sep).

**Why:** de noche el encargo pedía elegir lo recomendado sin preguntar y aparcar lo que fuera producto.

**How to apply:** si alguien propone volver a meter el token nulo en el reintento corto «por si vuelve la red», la review
del 17-sep ya lo midió y lo retiró: [[el-reintento-de-fuera-multiplica-el-de-dentro]]. Y si Jürgen pregunta por qué crear
grupo sin red dice «GroupsRPCError 1», es anterior y tiene ticket (`groups-create-approve-remove-show-a-raw-rpc-error`).

Relacionado: [[sync-personal-token-nulo-pasajero]].
