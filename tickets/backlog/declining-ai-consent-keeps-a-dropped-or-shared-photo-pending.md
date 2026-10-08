---
id: declining-ai-consent-keeps-a-dropped-or-shared-photo-pending
status: backlog
priority: low
area: "image"
created: 2026-10-07
source: hallazgo del encargo 2026-10-07-ipad-drop-unreadable-file-fails-silently
updated: 2026-10-08
---

# Rechazar el consentimiento de IA deja pendiente la foto soltada o compartida

## Qué pasa (inferido del código, sin reproducir)

Sin el consentimiento de IA aceptado, soltar o compartir una foto legible pide primero el consentimiento. Si el usuario
toca Cancelar, `SceneNavigation.pendingSharedImageURL` se queda puesto y el fichero sigue en `PendingImages/`. La
próxima vez que abra el registro por imagen —por cualquier camino y aceptando el consentimiento— la hoja lee esa foto
vieja en vez de abrir eligiendo. Y la recuperación del arranque la vuelve a ofrecer.

## Por qué es una decisión y no solo un bug

Puede ser a propósito («tu recibo sigue esperando»). El encargo del soltar ilegible tomó la decisión contraria solo para
el fallo: si se rechaza el consentimiento, el fallo pendiente se olvida (`PanelSheetsModifier`), porque un aviso viejo no
explica nada. Falta decidir qué hace la foto legible.

## Medido en 2.1 (triage 2026-10-08)

- `AppBootstrapper.enqueueSharedImage` deja `pendingSharedImageURL` puesto antes de pedir el consentimiento, y el `.onChange(of: sheets.showAIConsentAlert)` de `PanelSheetsModifier` solo borra `pendingImageEntryFailure` al rechazar: la URL y el fichero de `PendingImages/` se quedan.
- Solo `ImageSelectionView` (al consumirla) y `SceneNavigation.resetForNewStore` la ponen a `nil`.
- Decisión pendiente. A) Al rechazar, olvidar la foto y borrar el fichero, como ya se hace con el fallo (recomendada: la foto vieja aparece sin contexto y la recuperación del arranque la vuelve a ofrecer). B) Guardarla a propósito y decirlo («tu recibo sigue esperando»). C) Dejarlo. Con A sigue `low`.

Triage 2026-10-08: abierto · low → low · `pendingSharedImageURL` sigue puesto tras rechazar el consentimiento; molestia sin pérdida de datos, falta decidir A/B/C.
