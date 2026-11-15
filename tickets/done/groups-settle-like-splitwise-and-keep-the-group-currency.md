---
id: groups-settle-like-splitwise-and-keep-the-group-currency
status: done
priority: high
area: "groups, settlements"
created: 2026-11-10
updated: 2026-11-12
card: tablero-mejoras-2-3-grupos-saldar-como-en-splitw-gqcf
source: "revisión 2.3, decisiones 3 y 37 (docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md)"
---

# Grupos: saldar como en Splitwise y la moneda del grupo que no cambia sola

Dos decisiones de Jürgen del 9-nov, «Lote 1», que el lote 01 de Grupos no llevó.

## Hecho cuando

- C1: cualquier miembro apunta cualquier pago entre miembros; si no lo paga ni lo recibe quien lo apunta, queda «Falta
  que <quien recibe> lo confirme».
- C2: «Todo» o «Una parte», con lo que queda y un aviso si se paga de más.
- C3: al guardar, un aviso con el saldo nuevo y «Deshacer».
- Opción A: apagar «Ver las deudas en una sola moneda» conserva la moneda del grupo.
- Un test de regresión por punto, review adversarial y gate en verde.

## Resolución (2026-11-12)

- **Antes, medido en el simulador** (capturas en `capturas/` del PR): la deuda de Beto con Ana no tenía «Saldar»; pagar
  S/ 100 sobre una deuda de S/ 80 se guardaba sin aviso y dejaba una deuda al revés; la hoja se cerraba sin decir nada;
  y al apagar la vista en una moneda, el pie del presupuesto pasaba de «en $» a «en S/».
- **C1**: `SettlementSaldar23Logic.confirmsOnRecord` — nace confirmado si lo apunta quien paga o quien recibe; si lo
  apunta un tercero, queda pendiente y quien recibe lo confirma con el «¿Lo recibiste?» de siempre (la tarjeta dice
  «Lucía apuntó que Beto te pagó…»). La lista dice «Lo apuntó Lucía · Falta que Ana lo confirme». Sin cambio de
  servidor: `split_settlements_insert` solo exige escritor activo.
- **C2**: segmentado «Todo · importe / Una parte»; debajo, lo que queda o el aviso de pagar de más, y el botón pasa a
  «Saldar igual».
- **C3**: el aviso común (`DraftDiscardUndoNotice`) con «Pagaste S/ 40.00 a Ana. Ya están a mano.» o el resto que
  queda, y «Deshacer», que borra el pago por `deleteSettlement`.
- **A**: `GroupSettingsView` ya no escribe la divisa por defecto en el grupo al apagar; la rama de edición de
  `GroupFormView` conserva la del grupo.
- Tests: `YalaTests/GruposSaldar23Tests` y `YalaUITests/Flows/GruposSaldar23UITests` (un caso por punto, los cuatro
  rojos con el código de antes por construcción: el id, el segmentado, el aviso y el pie no existían o decían otra cosa).

## Review adversarial (tres lentes, 2026-11-12)

- Aplicado: «Saldar» entre otros solo si quien recibe es miembro activo (si no, el pago quedaría pendiente para
  siempre); tras «Sí, registrar» en tus cuentas el aviso sale sin «Deshacer» (lo aprobado en esa hoja es un movimiento
  sin enlace al pago); el paso «Todo → Una parte» al escribir cuelga del campo; cambiar de moneda vuelve a «Todo»;
  VoiceOver anuncia el pago de más; «Deshacer» no lee un grupo borrado; tres textos (es-ES «a mano», «quedas/quedás»,
  «você fica»).
- Separado en tickets: `pending-settlement-leaves-the-debt-card-with-settle` (decisión de producto: el mismo pago
  apuntado dos veces mientras uno espera confirmación), `settlement-notification-states-a-third-party-payment-as-fact` y
  `pending-settlements-spend-the-bridge-retry-budget`.
