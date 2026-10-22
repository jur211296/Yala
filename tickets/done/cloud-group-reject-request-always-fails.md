---
id: cloud-group-reject-request-always-fails
status: done
priority: medium
area: "groups, modo-nube"
created: 2026-10-20
updated: 2026-10-21
source: "tablero-en-un-grupo-de-la-nube-rechazar-una-soli-840m (QA guiado del TF19, 2026-10-20)"
---

# En un grupo de la nube, «Rechazar» una solicitud de unión falla siempre

## En lenguaje de usuario

Soy el administrador de un grupo. Alguien pide unirse y toco «Rechazar»: Yala dice «No se pudo completar la acción. Vuelve a intentarlo», y la solicitud se queda pendiente para siempre.

## Lo medido (2026-10-20)

- `GroupService.rejectMember` lanzaba `.backendActionUnavailable` para los grupos del canal backend: el rechazo nunca salía del teléfono (wrangler tail de staging: solo un `/groups/pull`).
- **El servidor ya sabía rechazar** (la card suponía lo contrario): `remove_member` deja `rejected` a quien está `pendingApproval` y `removed` a quien está activo (`supabase-groups-staging.ddl`, §5); `g13_02` deja al rechazado leer su fila (en producción desde el 2026-09-03); el Worker le manda el aviso neutro `remoteMembershipUpdate`, y la app le pinta «no te aceptaron» en el detalle del grupo.

## Lo que cambia

- `rejectMember` es `async`: en un grupo de la nube llama a `remove_member` (servidor primero, como aprobar) y marca `.rejected` en local solo si el servidor contesta `rejected` (`GroupMemberRejectLogic`).
- Exige la solicitud pendiente en local, el grupo escribible y ser admin ANTES de llamar: el mismo RPC expulsaría a un miembro ya activo. Si un pull ya la marcó mientras volaba, no se vuelve a escribir.
- Sin migración ni deploy del gateway: funciona en producción con el build.
- `GroupMembersView.performReject` usa el molde de `performApprove`.

## Residual con ticket

`cloud-group-reject-can-expel-a-member-approved-on-another-device`.

## Tests

`GroupRejectMemberBackendTests`: el RPC con su clave y `.rejected` en local; control con el canal de CloudKit (local, sin red); miembro ya activo (no llama); servidor que no confirma; servidor que falla; sin `member_key`.

## Device-QA (Jürgen, dos aparatos, Yala Dev contra staging)

1. Con test@ (iPad), abre el enlace de «QA unión 19» y pide unirte.
2. Con admin@ (iPhone), Grupos › «QA unión 19» › Miembros › la solicitud › «Rechazar» › confirmar.
3. Esperado en el iPhone: la solicitud desaparece, sin error.
4. Esperado en el iPad: llega el aviso, y al abrir el grupo pone «no te aceptaron».

Cerrado en el QA guiado 2026-10-21 (iPhone de QA e iPad Air, Yala Dev @ e47b5cca9, staging): admin@ rechazó a test@ en «QA unión 20»: la solicitud desaparece sin error y el iPad dice «Solicitud rechazada» (staging: rejected).
