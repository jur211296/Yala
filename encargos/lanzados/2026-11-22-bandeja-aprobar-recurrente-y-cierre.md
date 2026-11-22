Yala
# Bandeja: «Aprobar y hacer recurrente» vuelve a abrir el editor y la Bandeja se cierra al guardar los últimos listos
---
toca: Yala/App/Views/Inbox/,Yala/App/Logic/RecurringFromRecord/,YalaTests/BandejaRecurrenteCierre/,YalaUITests/BandejaRecurrenteCierre/,Yala/Resources/de.lproj/BandejaRecurrenteCierre.strings,Yala/Resources/en-GB.lproj/BandejaRecurrenteCierre.strings,Yala/Resources/en.lproj/BandejaRecurrenteCierre.strings,Yala/Resources/es-419.lproj/BandejaRecurrenteCierre.strings,Yala/Resources/es-AR.lproj/BandejaRecurrenteCierre.strings,Yala/Resources/es-ES.lproj/BandejaRecurrenteCierre.strings,Yala/Resources/es.lproj/BandejaRecurrenteCierre.strings,Yala/Resources/fr.lproj/BandejaRecurrenteCierre.strings,Yala/Resources/it.lproj/BandejaRecurrenteCierre.strings,Yala/Resources/ja.lproj/BandejaRecurrenteCierre.strings,Yala/Resources/nl.lproj/BandejaRecurrenteCierre.strings,Yala/Resources/pl.lproj/BandejaRecurrenteCierre.strings,Yala/Resources/pt-BR.lproj/BandejaRecurrenteCierre.strings,Yala/Resources/pt-PT.lproj/BandejaRecurrenteCierre.strings,Yala/Resources/pt.lproj/BandejaRecurrenteCierre.strings,Yala/Resources/zh-Hans.lproj/BandejaRecurrenteCierre.strings,tickets/backlog/inbox-approve-and-make-recurring-no-longer-opens-the-editor.md,tickets/backlog/inbox-does-not-close-after-saving-the-last-ready-drafts-in-2-3.md,tickets/backlog/2026-11-18-bandeja-aprobar-y-recurrente-choca-con-posible-duplicado.md,tickets/done/inbox-approve-and-make-recurring-no-longer-opens-the-editor.md,tickets/done/inbox-does-not-close-after-saving-the-last-ready-drafts-in-2-3.md,tickets/done/2026-11-18-bandeja-aprobar-y-recurrente-choca-con-posible-duplicado.md,tickets/backlog/2026-11-22-bandeja-aprobar-recurrente-y-cierre.md,tickets/done/2026-11-22-bandeja-aprobar-recurrente-y-cierre.md
esfuerzo: medium
cierre: cierra-sola
---

Jürgen pidió el 22-nov (15:08 Lima) encolar todo lo pendiente del backlog que esté claro o tenga decisión. Este encargo junta tickets afines.

## Tickets
- `tickets/backlog/inbox-approve-and-make-recurring-no-longer-opens-the-editor.md`
- `tickets/backlog/inbox-does-not-close-after-saving-the-last-ready-drafts-in-2-3.md`
- `tickets/backlog/2026-11-18-bandeja-aprobar-y-recurrente-choca-con-posible-duplicado.md`

## Qué hacer
«Aprobar y hacer recurrente» aprueba el borrador y abre el editor del pago planificado, también cuando sale el aviso de posible duplicado. «Guardar los listos» con los últimos borradores cierra la Bandeja como en 2.2. Hazlo con pruebas de interfaz.

## Reglas
- Antes de tocar nada, verifica contra `origin/2.3` que cada ticket siga pasando (varios son viejos). Si uno ya no pasa o ya está hecho, muévelo a done con la evidencia y sigue con los demás.
- Si un ticket resulta ser una decisión de diseño o de producto que solo Jürgen puede tomar, no la inventes: déjalo en backlog con la pregunta y las opciones con su recomendación, y anótalo en el cierre.
- Textos nuevos en su propia tabla `.strings` (la del toca), no en Localizable.strings ni L10n.swift, en los 16 idiomas y siempre en español neutro latinoamericano (en es-ES también, sin vosotros).
- Si hace falta tocar algo fuera del toca, toca lo mínimo y anótalo en el cierre.
- Producción (iCloud Production, Supabase prod, gateway, web publicada) no se toca: déjalo probado en desarrollo y anotado para Dan, con el OK de Jürgen.
- Nada de pago.

## Dispositivos
Antes de usar un simulador, comprueba si el iPhone 14 conectado por DeviceMCP está libre; no lo des por ocupado sin comprobarlo. En la Max puedes usar un segundo simulador si otra sesión ya usa uno (tope 2); en la Mini, 1.

## Cierre
Commits y PR sin firma de IA y sin saltarse hooks. Espera el merge real del PR en 2.3 antes de `/cerrar-total`. Si a los ~45 min el CI sigue rojo por algo ajeno al PR, cierra y anótalo. El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada».

## Paso 0 — decisiones (resueltas en semi, sin preguntar: ninguna es de producto)

1. **¿Siguen rojos los tickets?** Medido sobre `origin/2.3` (4368d5ccb) en el iPhone 17 Pro, iOS 27.2, solo en el
   simulador: `RecurrenteDesdeRegistroUITests#test_inbox_approveAndMakeRecurring_approvesAndOpensTheEditor` y
   `InboxCrudUITests#test_saveReadyButton_savesEveryCompleteDraftAfterConfirming` verdes 1 de 1, y 3 vueltas más con
   `-test-iterations 3 -run-tests-until-failure`. ⇒ los dos tickets de rojo van a `done` con esa evidencia; no se toca
   el cierre de la Bandeja ni el paso al editor, que ya funcionan.
2. **El choque con «Posible duplicado».** Su causa (un transporte de −18 de la semilla en hoy−3) ya la quitó 57d54796a
   (importes con céntimos). Lo que queda del encargo es que el camino con el aviso funcione: con
   `-uitest-inbox-duplicate-draft` se prueba «Crear de todas formas» → editor prellenado.
3. **«Cancelar» en el aviso no deja lo recurrente armado** (sospecha al leerlo, refutada): las dos únicas entradas a
   `approveDraft()` fijan `approvesIntoRecurring` antes de aprobar; «Guardar» lo pone a `false`. No se toca producción
   más allá de los ids; un segundo XCUITest fija ese desarme (cae con el mutante que lo quita).
4. **Dónde van las pruebas:** `YalaUITests/BandejaRecurrenteCierre/` (la carpeta del toca). Los botones del aviso
   llevan id (`inbox_duplicate_cancel` / `inbox_duplicate_save_anyway`) para no depender del texto.
5. **Textos nuevos:** ninguno, así que no hay tabla `.strings` nueva.
