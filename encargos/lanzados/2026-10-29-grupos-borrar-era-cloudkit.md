---
esfuerzo: high
---
# Grupos: la puerta borra los grupos de la era CloudKit (opción A, caso Pia)

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Slug: `grupos-borrar-era-cloudkit` · Sesión cola **S27d** · al cerrar → **S27tf** (TestFlight 2.2 (4)).

## Contexto
Pia quedó atrapada en un bucle en el Welcome: la puerta de Grupos pide «Continuar y borrar», Yala se reinicia y vuelve a pedir lo mismo. El veredicto (PR #680, ya mergeado) está en `tickets/backlog/welcome-groups-gate-loops-on-legacy-cloudkit-groups.md`: la puerta cuenta todos los `SplitGroup` (`ContentView.checkHasExistingData` / `checkHasGroupsData`), pero el cierre privado (`CloudSignOutFlowLogic.wipeForgetsGroups`, `.privateOnly`) no borra el store de Grupos si solo hay grupos de la era CloudKit sin migrar (`isBackendGroup == false && movedToBackendAt == nil`). Tras el reinicio la puerta los vuelve a contar.

**Jürgen decidió la opción A el 2026-10-29 05:31 Lima:** la vuelta al neutro de la puerta de Grupos se lleva también los grupos de la era CloudKit (que ya no pueden volver y que «Es mi primera vez» ya borra).
Card: `tablero ver tablero-grupos-la-puerta-borra-los-grupos-de-la-229z`.

## Qué se pide
1. Implementar A en la vuelta al neutro que disparan las dos puertas (organizador e invitado): el borrado incluye el store de Grupos cuando hay grupos legacy sin migrar. Lee el ticket entero antes.
2. Test de la fórmula (sembrar un `SplitGroup` legacy, recorrer puerta → borrado → arranque y comprobar que la puerta deja de contarlo); comprobar con un mutante que el test cae si se quita el cambio.
3. Review adversarial del cambio: toca el borrado del cierre de sesión; que no borre grupos del backend ni datos de una sesión con cuenta de grupos.
4. Escribir en el ticket «Decisión: A (Jürgen, 2026-10-29 05:31)» y moverlo según toque.
5. Un solo PR a 2.2 en auto-merge. Card a in progress con `--agente frank` al empezar; al cerrar, a in qa (device-QA de Jürgen si no se reprodujo en sim) o done.

## Qué NO tocar
- El cierre desde Ajustes (ticket `private-sign-out-keeps-legacy-cloudkit-groups`) queda con su propia decisión: no cambiarlo aquí salvo que sea la misma línea; si lo es, dilo en el cierre.
- El aviso al organizador con copia en iCloud: sigue pendiente de decisión, no lo inventes.
- marketing/ y Web/ (Lola).
- No lanzar otras sesiones Yala.

## Reglas de Mini
Pipeline serial: limpiar → build `xcodebuild -jobs 2` sin sim → boot 1 sim → tests → apagar sim. Al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar; no toques las de un worktree vivo. Antes de abrir el PR, haz un solo fetch y rebase sobre `origin/2.2` con el simulador apagado; no esperes el CI de otro PR.

## Cómo se sabe que está bien
- Con un grupo legacy sembrado, tras «Continuar y borrar» la puerta deja pasar al primer reinicio.
- Test + mutante verdes/rojo como toca; PR en auto-merge a 2.2; decisión escrita en el ticket.

/cerrar-total

## Paso 0 (Frank, 2026-10-29)

- **Dónde entra A:** las dos puertas (organizador e invitado) vuelven al neutro por UN solo sitio,
  `WelcomeGroupsGateView.returnToNeutral` → `CloudSessionSignOut.signOut`. Se añade un parámetro
  `neutralReturnFromGroupsGate` (default `false`) que viaja guardado en el coordinador hasta
  `armAfterCredentials`, igual que `destinationOnArm`, y sobrevive a los cierres retomados.
- ~~Asumido: con la puerta, el borrado se lleva SIEMPRE el store de Grupos~~ → **corregido tras la review: solo si el
  store tiene algún `SplitGroup`** (la marca retira además el libro de conservados y la cuenta asociada). Razonamiento
  original:
  la puerta promete el teléfono en blanco y cuenta TODO `SplitGroup`; con el store sin filas legacy el
  resultado para la persona es el mismo. Además, con grupos «conservados por el aviso tardío», la puerta
  no los cuenta, pero el borrado retira esa marca: si sobrevivieran, la vuelta siguiente los contaría y
  volvería el bucle.
- **No se deriva del destino** (`destinationOnArm`): el del invitado puede ser `nil`.
- **Fórmula única:** `CloudSignOutFlowLogic.wipeForgetsGroups` gana el término, sin default; la hoja del
  cambio de Apple ID pasa `false`. Ajustes no cambia (ticket `private-sign-out-keeps-legacy-cloudkit-groups`).
- **Aviso al organizador con copia:** no se toca.
- **Test:** cadena con stores reales en disco (siembra legacy → puerta → fórmula → boot-wipe real con
  `deleteFiles` inyectado → remontar → puerta `.proceed`) para las dos puertas, con control (sin el término,
  la puerta vuelve a pedir el neutro). Mutantes: quitar el término de la fórmula y quitar el paso por el arm.
