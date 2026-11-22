---
id: 2026-11-22-cuenta-limite-tarjeta-campo-sincronizado
status: qa
priority: high
area: cuentas
created: 2026-11-22
updated: 2026-11-22
source: decisión t1874u de Jürgen (22-nov 06:23, opción A) y GO del 22-nov 06:28
qa-status: needs-testing
---
# Límite de la tarjeta como campo sincronizado y «uso de línea» en la hoja de cuenta

Jürgen eligió la opción A para el «uso de línea» de la hoja de una tarjeta («16 % usado · disponible de 8,000»): el
límite se guarda en un campo nuevo de la cuenta, sincronizado. La hoja ya traía la línea lista y oculta sin límite
(Novedades 2.3).

## Hecho

- **Campo nuevo** `Account.creditLimit` (opcional, en la divisa de la cuenta; vacío, 0 o negativo = sin límite). Cuentas
  de antes y equipos con versiones anteriores siguen igual: sin el campo no hay línea, y un equipo viejo no lo pisa.
- **Editar cuenta › Tarjeta de crédito:** fila «Límite de la tarjeta», opcional, con la divisa al lado y un pie que dice
  para qué sirve. Solo en la principal de la tarjeta; cambiar el tipo de la cuenta lo borra.
- **Hoja de la cuenta:** con límite, «X % usado · N disponible de M» bajo lo que debes (facturado + por facturar; un
  saldo a favor cuenta 0, pasarse se dice tal cual). Sin límite, nada. Con varias divisas, nada (regla de la hoja: no se
  suman divisas).
- **iCloud:** `CD_creditLimit` (DOUBLE, record type `CD_Account`) en los dos esquemas de desarrollo. Production espera a
  Dan; el test de paridad lo lleva apuntado como pendiente y falla en cuanto el campo aparezca en el snapshot de
  producción, para retirar la entrada.
- **Nube de Yala:** `accounts.credit_limit` (`numeric(18,4)`, `since: 10`), manifest v10, apunte y reemisión al subir
  de versión, DDL de staging y migración `qa/cloud/g35_01_*` (con su marcha atrás y su script remoto).
- **Textos:** `LimiteTarjeta.strings`, 16 idiomas.
- **Semilla** `tarjeta-limite`: «Visa QA» solo en soles con corte, para probar la línea.

## Pendiente fuera de la app (Dan, con OK de Jürgen)

1. iCloud Production: campo `CD_creditLimit`, tipo DOUBLE, en el record type `CD_Account`, en los contenedores
   `iCloud.com.jurgenschmidt.yala` y `iCloud.com.jurgenschmidt.yala.dev`, ANTES de subir un build que lo escriba.
   «Deploy Schema Changes» solo copia lo que existe en el Development VIVO de cada contenedor, y el `.ckdb` del repo no lo
   crea allí: primero se lleva a Development (un Debug del scheme `Yala` que guarde un límite, o `cktool import-schema`;
   `docs/cloudkit-schema-diff-2.1.md` §3) y después se despliega (§4-§5). Al terminar, re-exportar los dos
   `*-production.ckdb` (§6) y vaciar `PersonalCloudKitSchemaParityTests.pendingProductionDeploy`: mientras tenga algo,
   `scripts/asc-preflight.sh` para la subida a TestFlight.
2. Nube de Yala: `bash qa/cloud/g35_01-remote.sh staging apply` y `production apply`, y después desplegar el gateway con
   `manifest_version: 10` (en ese orden: la columna antes que el Worker).

## Guion de QA (dos equipos con Yala Dev y la misma cuenta de iCloud)

1. Equipo A: Panel › la tarjeta › Editar › «Límite de la tarjeta» = 8000 › Guardar.
2. La hoja de la tarjeta dice «… % usado · … disponible de 8,000.00» (si la tarjeta tiene día de corte y una sola divisa).
3. Equipo B, tras unos minutos: la misma tarjeta enseña la misma línea; Editar enseña 8,000.00.
4. En B, borrar el límite y guardar. En A, la línea desaparece.
