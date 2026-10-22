---
updated: 2026-10-22
tags: [cloudkit, despliegue, owner, v2.2]
---

# CloudKit para 2.2: los dos campos nuevos, en una pasada

**Para quién:** Jürgen, desde el Mac (la consola de CloudKit no se usa bien desde el móvil).
**Cuánto lleva:** unos 15 minutos los dos contenedores.
**Cuándo:** antes de subir a TestFlight cualquier build de 2.2. TestFlight ya usa el entorno Production de iCloud.

**Por qué no lo hizo Frank:** en la Mini no hay token de gestión de CloudKit (`xcrun cktool get-teams` responde «No
management token found», medido el 2026-10-22). Y llevar un esquema a Production solo se hace desde la consola.

## Qué se añade

| Record type | Campo | Tipo | Índices | Por qué corre prisa |
|---|---|---|---|---|
| `CD_Account` | `CD_parentAccountID` | String | ninguno | Lo escribirá la primera build que deje vincular una línea de tarjeta a otra divisa |
| `CD_CashFlowLine` | `CD_amountChangesRaw` | String | ninguno | **La build de 2.2 ya lo escribe** al elegir «Ese mes y los siguientes». Sin el campo, iCloud rechaza esa línea sin avisar |

Solo son dos altas. No se borra ni se cambia nada.

## Pasos, contenedor de producción (`iCloud.com.jurgenschmidt.yala`)

1. Abre <https://icloud.developer.apple.com/dashboard> e inicia sesión con la cuenta de desarrollador.
2. Arriba a la izquierda, elige el contenedor **`iCloud.com.jurgenschmidt.yala`**.
3. Comprueba que el selector de entorno dice **Development**.
4. Menú lateral: **Schema → Record Types → `CD_Account`**.
5. Si en la lista de campos ya está `CD_parentAccountID`, salta al paso 7.
6. Pulsa **+** (añadir campo). Nombre `CD_parentAccountID`, tipo **String**. **Save**.
7. Vuelve a **Record Types** y abre **`CD_CashFlowLine`**.
8. Si ya está `CD_amountChangesRaw`, salta al paso 10.
9. Pulsa **+**. Nombre `CD_amountChangesRaw`, tipo **String**. **Save**.
10. Menú lateral: **Schema → Deploy Schema Changes…**
11. Lee la lista antes de confirmar. Tiene que traer **solo altas**, y entre ellas estas dos:
    - «Add field `CD_parentAccountID` to `CD_Account`»
    - «Add field `CD_amountChangesRaw` to `CD_CashFlowLine`»
12. Si aparece cualquier «Remove» o «Change», pulsa **Cancel** y avisa a Frank: no se despliega.
13. Si solo hay altas, pulsa **Deploy**.
14. Cambia el selector de entorno a **Production** y abre `CD_Account` y `CD_CashFlowLine`. Los dos campos tienen que
    estar, como **String**.

## Pasos, contenedor de desarrollo (`iCloud.com.jurgenschmidt.yala.dev`)

15. Arriba a la izquierda, cambia al contenedor **`iCloud.com.jurgenschmidt.yala.dev`**.
16. Repite los pasos 3 a 14.

## Cuando acabes

17. Dile a Frank «CloudKit hecho». Él mueve las dos cards y deja los `.ckdb` del repo iguales al export.

Si quieres que la próxima vez lo pueda hacer Frank desde la Mini: CloudKit Console → tu cuenta → **Tokens** →
**Management Token** → crear uno, y en la Mini `xcrun cktool save-token --type management`, pegándolo cuando lo pida.
Aun así, el paso de Development a Production (pasos 10-13) sigue siendo de la consola.

## Cómo se comprueba que funcionó (con la build de 2.2 en dos iPhone)

1. En el iPhone A: Reportes → Flujo de caja → toca una línea del mes en curso → «Ajustar monto» → otra cifra →
   Guardar → «Ese mes y los siguientes».
2. En el iPhone B, al rato: la misma línea en el mes siguiente dice «Desde <mes>» con la cifra nueva, y la del mes
   pasado no cambió.

Detalle y alternativa por `cktool`: `docs/cloudkit-schema-diff-2.1.md`, secciones «El campo nuevo de la tarjeta con
varias divisas» y «El campo de los cambios «desde este mes» del flujo de caja».
