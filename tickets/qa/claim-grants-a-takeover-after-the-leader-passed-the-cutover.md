---
id: claim-grants-a-takeover-after-the-leader-passed-the-cutover
status: qa
priority: medium
area: "modo-nube, migración, backend"
created: 2026-09-24
updated: 2026-09-24
source: "sesión de `leader-displaced-after-the-cutover-pushes-its-residual-in-the-reconcile` (2026-09-24), candidata de servidor que quedó fuera"
---

# El servidor da el relevo de una activación que ya pasó el cutover

## El problema, en lenguaje de usuario

Activo la nube en el teléfono A, que llega hasta el final —sus datos ya están verificados en la cuenta— y se queda
esperando a que reabra Yala. Si tardo más de una hora, un segundo teléfono B que activa la nube recibe el relevo y vuelve a
subir su corpus entero encima de una cuenta que ya estaba completa. Desde
`leader-displaced-after-the-cutover-pushes-its-residual-in-the-reconcile` el teléfono A ya no sube nada mientras B lidera
y se une cuando B termina, así que no hay pérdida ni bucle: lo que queda es trabajo inútil de B y una segunda subida sobre
un corpus verificado.

## Lo medido (2026-09-24, producción, lectura)

- `claim_account` (md5 `c96106b7f3b043e5a26f68ff971c2123`) da `created` a un claim de migración con
  `migration_in_progress` y el lease vencido (> 60 min), sin mirar `migrated_at`.
- `migrated_at` solo lo estampa `migration_progress('cutover')` del líder, con `coalesce`: no se borra nunca.

## Por qué no se hizo en esa sesión

Cambia el flujo de B, y es una decisión: con `migrated_at` puesto, ¿B espera como seguidor (`claiming_in_progress`)
o adopta la cuenta (`existing_stable`)? Esperar deja a B atascado si A no vuelve nunca (teléfono perdido); adoptar
cierra ese caso, pero deja la cuenta con `migration_in_progress` hasta que A vuelva. Y el cliente tiene que resolver el
`other_leader` después del cutover igual: la vuelta a iCloud de otro dispositivo también toma el relevo tras el cutover, y
eso sí es por diseño (`reverse_claim` sobre un forward abandonado).

## Criterios de aceptación

- [x] Decidido qué recibe B con `migrated_at` puesto y el lease vencido: **adopt** (`existing_stable`), decisión de Jürgen.
- [x] La rama de `claim_account` lo implementa, con el banco de escenarios de g16_03 ampliado (sandbox transaccional en
      producción, receta en la memoria de Frank `verificar-backend-yala`).
- [x] El cliente de B lo trata sin callejón (adopt).

## Lo hecho (2026-09-24)

**Para quien usa la app:** si el primer teléfono llegó hasta el final de la activación y se quedó más de una hora sin
reabrir Yala, el segundo teléfono ya no vuelve a subir todos sus datos encima: entra en la cuenta como cualquier segundo
dispositivo, baja lo que hay y sube solo lo que el otro no tenía. Tampoco se queda esperando a un teléfono que quizá no
vuelve (perdido, sin batería). Cuando el primero vuelve, termina su activación como si nada.

**Cómo:** migración `qa/cloud/g16_04_claim_no_takeover_after_the_cutover.sql`, aplicada en staging y producción el
2026-09-24 (md5 de `claim_account` `c96106b7…` → `35423724…`). Con `migrated_at` puesto y el lease vencido, el claim de
otro dispositivo —con o sin `migration`— recibe `existing_stable` y el líder no cambia; con `migration`, deja el sello de
g16_02. Lease vigente, latido nulo y relevo antes del cutover, sin cambio. Sin deploy del Worker ni cambio de lógica en la
app: `existing_stable` ya lleva al adopt por las tres puertas. Se corrigieron los docblocks (`MigrationWorkExecutor`,
`AccountClaimDecision`, `gateway/src/sync/account.ts`) y la regla del área («Y el servidor ya no da ese relevo»).

**Verificado:** banco de 27 escenarios (los 14 de g16_03 más 13) contra el motor de producción: la función vieja falla los
4 del cutover y la nueva pasa 27/27; 13 mutantes muertos (6 antes de aplicar, 7 más tras la review). Goldens del Worker contra staging 33/34 dos veces (el rojo es el
timeout conocido del 20); se repararon el 9 y el 9-bis, que fijaban el relevo post-cutover como contrato, y el 3, que
heredaba el lease de la corrida anterior; nuevos el 9-ter y el 9-quater. Detalle en `qa/cloud/README.md` §g16_04.

**Efecto sobre #238** (`leader-displaced-after-the-cutover-pushes-its-residual-in-the-reconcile`): el teléfono que hizo el
cutover ya no puede perder el lease ante otra ida, así que su guion («B toma el relevo tras el cutover») deja de poder
montarse. Lo sustituye el de abajo. Sus ramas `retaken`/`otherLeads` quedan para un servidor sin g16_04.

**Encontrado en la review y no tocado** (tickets propios): `adopt-after-the-cutover-needs-a-marker-the-leader-never-exported`
(medium: si A pasa el cutover del servidor y no llega a exportar el marcador, B con datos propios no puede entrar),
`adopt-orphan-with-a-fresh-hlc-beats-the-absent-leaders-edit` (low) y `claim-takeover-races-the-leader-cutover-without-cas`
(low, carrera anterior a g16_04).

## Guion de device-QA (dos iPhone, misma cuenta, build de TestFlight)

1. iPhone A en iCloud con datos. Ajustes → Almacenamiento → «Migrar a la nube», inicia sesión y deja que llegue al final
   (pide cerrar y reabrir Yala). **No reabras A.** Ponlo en modo avión.
2. Espera **más de 60 min**.
3. iPhone B, con el mismo iCloud y Yala ya instalada: Ajustes → Almacenamiento → tarjeta «Activar la nube en este
   dispositivo» → «Activar en este dispositivo», con la misma cuenta de Apple/Google que A. (En un iPhone recién instalado,
   la bienvenida → «Ya tengo una cuenta» recorre el mismo camino.) **Esperado:** B no sube sus datos como una migración:
   entra en la cuenta, baja los datos de A y queda con la nube activa en pocos minutos.
4. Crea un gasto en B.
5. Quita el modo avión a A, ábrelo y reábrelo cuando lo pida. **Esperado:** A termina su activación sin error, queda con la
   nube activa y el gasto del paso 4 aparece en A tras sincronizar.
6. Crea un gasto en A: aparece en B.
7. **Fallo si:** B hace una migración entera (la barra de subida de «Migrar a la nube»), aparecen datos duplicados, B se
   queda esperando a otro dispositivo, o A sale con error o no sincroniza tras el paso 5.
