# Maquetas: deudas 1 a 1 con personas fuera de grupos (26-nov-2026)

Artifact para decidir (público): https://claude.ai/artifact/NfgWRf4y1eKSfaTkGkR1gf
Card «Espera decisión» de Jürgen en el tablero de Yala 2.3: «Elegir: deudas 1 a 1 con personas (maquetas)».
La decisión se guarda en la base del artifact (`decisiones/deudas-directas`: `opcion`, `correo`, `prestamos`, `nota`).

- `index.html`: la página publicada (iPhone 14, claro y oscuro; Carla y el almuerzo a medias, Diego con tres gastos
  y un pago parcial, Martín sin Yala que luego entra).
- `maquetas-claro.jpg`, `maquetas-oscuro.jpg`: la página entera tal como se ve en el artifact.

## Recomendación

**A en 2.3**: «Personas» como segunda vista dentro de Grupos; por dentro, cada persona es un grupo de dos oculto.
Alta rápida «me debe / le debo», saldo por persona sumando directo y grupos, liquidar todo o una parte, recordar con
imagen, invitar por enlace y aceptar antes de ver nada. El correo entra como pista para vincular cuando la persona
llega con Apple o Google, sin que Yala mande correos. Unas 5 a 6 sesiones.
**2.4**: Yala manda el correo de invitación, aviso al otro teléfono, y «Préstamos con personas» construido sobre la
misma pantalla de persona (sin fusionar las cards).
B (libro propio, solo tú) y C (amigos por correo, como Splitwise) quedan comparadas en la página.

## Medido en `2.3`

- Miembro solo con nombre ya existe: `GroupService.addMember(to:displayName:role:)` crea un `SplitMember` con
  `userID == nil` («hueco sin reclamar»).
- Reclamar un hueco al unirse ya lo acepta el servidor: `join_group(p_token, p_display_name, p_legacy_member_key)`
  (`gateway/src/groups/rpc.ts`, `GroupsMembershipClient.joinGroup`); hoy solo lo usan los grupos migrados.
- Pago parcial: `SettlementSaldar23Logic.PaymentScope` `.all` / `.part`.
- Reparto para dos: `GroupTwoPersonSplitView` (`applyTwoPersonChoice`).
- Correo: nada en `Yala/Services/Groups` ni en `gateway/src/groups` (ni invitar ni buscar). Es lo nuevo.
- Saldo por persona entre grupos: no existe; hoy es por grupo (`GroupBalanceService`).
- Recordatorios: notificación local, apagada por defecto (`GroupSettlementReminderService`); no llegan al otro.
- Entrar a Grupos exige Apple o Google (`GroupsSignInView`); el correo de relevo de Apple impide casar por correo real.
- Tablas de Grupos en el servidor: `split_groups`, `group_members`, `split_expenses`, `split_shares`,
  `split_settlements` (`gateway/src/groups/manifest.ts`); no hay tabla de invitaciones por correo.
