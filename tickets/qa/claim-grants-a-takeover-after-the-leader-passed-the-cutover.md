---
id: claim-grants-a-takeover-after-the-leader-passed-the-cutover
status: backlog
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

- [ ] Decidido qué recibe B con `migrated_at` puesto y el lease vencido.
- [ ] La rama de `claim_account` lo implementa, con el banco de escenarios de g16_03 ampliado (sandbox transaccional en
      producción, receta en la memoria de Frank `verificar-backend-yala`).
- [ ] El cliente de B lo trata sin callejón (seguidor o adopt).
