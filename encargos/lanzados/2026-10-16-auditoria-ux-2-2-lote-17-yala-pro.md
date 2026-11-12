> **DISCO:** la Mini tiene unos 17 GB libres y en paralelo corre el QA guiado de 2.1 (no toques su worktree ni su DerivedData). Antes de compilar, mira `df -h /`. Si baja de 10 GB, borra solo tu propio DerivedData de este worktree. Al cerrar, apaga el simulador y borra tu DerivedData.

# Auditoría UX 2.2 · lote 17: Yala Pro

> **ALCANCE ESTRICTO:** solo los flujos del lote 17. Los criterios UX/UI se aplican solo a sus pantallas. Si ves algo fuera, anótalo en una línea en el informe y no lo toques.

Card: la de título «Auditoría UX 2.2 · lote 17: …» (búscala con `tablero listar --version 2.2`; muévela a in progress al empezar y a done al cerrar) (Yala, 2.2, high). Card madre ogl6: no la muevas.

**Base y PR: 2.2.** `lanzar-sesion` ignora --base: Frank ya te deja sobre origin/2.2; ANTES de tu primer commit, `git fetch origin && git log origin/2.2..HEAD` debe salir vacío. PR contra **2.2**.

## Fuentes
- Brief madre (método, cinco lentes, formato de informe, HTML acumulado y «Criterios UX/UI permanentes de Jürgen»): ~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md. Léelo entero.
- Mapa: docs/ux/mapa-de-flujos-2.2.md (sección lote 17).
- SIMULADOR A CUALQUIER HORA (Jürgen, 2026-10-14): ya NO existe la franja de 9:00 a 11:00 Lima. Si el mapa (docs/ux/mapa-de-flujos-2.2.md, regla 7) o un encargo viejo dice lo contrario, está desactualizado: ignóralo. Sigue: 1 simulador a la vez y apagado al terminar.
- Lotes anteriores como ejemplo: ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-7-cuentas-categorias/informe.md y ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html.
- Referencia visual: ~/Claude/referencias-ui/kargul-2026-10-07/.

## Lote 17 · Yala Pro (del mapa)
| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 17.1 | Suscribirme o gestionar la suscripción | Ajustes › Seguridad › Suscripciones | `SubscriptionView` → `SubscriptionSuccessView`; siendo Pro, «Gestionar en App Store» | `V/Settings/SubscriptionView.swift`, `V/Subscription/SubscriptionSuccessView.swift` | `ProConversionUpsells` |
| 17.2 | Toparme con una función de pago | Voz, imagen, chat, insights, cuentas o presupuestos al límite, temas, iconos, flujo de caja, soltar recibo | `UpgradePromptSheet` → `SubscriptionView` | `V/Shared/UpgradePromptSheet.swift`, `S/FeatureGateService.swift` | `ProConversionUpsells`, `PaywallInboxAlertRouting` |
| 17.3 | Empezar la prueba gratis | Tras el onboarding · checklist | `ProTrialOfferSheet` | `V/Subscription/ProTrialOfferSheet.swift` | `ExternalEntryForeignSheet`, `PaywallInboxAlertRouting` |
| 17.4 | Que se acabe la prueba | Automático | `UpgradePromptSheet(.trialExpired)` | `CV` | `ExternalEntryForeignSheet` |
| 17.5 | Elegir qué conservo al dejar de ser Pro | Automático mientras haya exceso | `DowngradeResolutionSheet` («Confirmar selección» / «Reactivar Pro») | `V/Subscription/DowngradeResolutionSheet.swift` | no |
| 17.6 | Restaurar compras | `SubscriptionView` · `ProTrialOfferSheet` | Alerta si hay error | `V/Settings/SubscriptionView.swift` | no |
| 17.7 | Ver el banner de Pro o de prueba en el Panel | Panel | `TrialBanner`, `ProUpgradeBanner` | `V/Panel/PanelView.swift` | `ProConversionUpsells` |

**Visto en el código:**
- Productos: mensual a 4,99 y anual a 29,99, los dos con un mes gratis (`Configuration.storekit`).
- La fila de suscripciones no existe en solo grupos.
- `UpgradePromptSheet` es a menudo una hoja sobre otra hoja.
- En el flujo de caja, tocar un método con candado no hace nada ni ofrece Pro.

**Tickets abiertos del lote:** `paywall-inbox-routing-uitest-misses-the-held-paywall-in-a-batch`,
`blocked-sign-in-still-binds-the-subscription-to-that-account`, `orphan-alerts-behind-fullscreen-covers`,
`journal-unreadable-card-says-reopen-when-a-downgrade-needs-an-update`.

---

## Qué hacer
1. Recorre cada flujo en el simulador; capturas en ~/Claude/entregas/<sesión>/capturas/.
2. Informe en español (entregas/<sesión>/informe.md): mejoras numeradas L17-1, L17-2…; por cada una: problema, tipo de usuario, captura, opciones A/B/C y recomendación. Añade la sección del lote 17 al HTML acumulado sin borrar nada.
3. No implementes cambios de UX: solo propone. Arregla únicamente bugs claros, cada uno con su card (Yala, 2.2, frank), en un PR a 2.2 con antes/después.
4. Una card en espera decisión (Yala, 2.2, assignee jurgen) por cada mejora, con sus opciones y la ruta de sus capturas.

## Elecciones de UI: variantes y CERRAR (Jürgen, 2026-10-14 13:01)
Si alguna mejora es una elección visual, construye ~/Claude/propuestas/auditoria-ux-2.2/variantes-L17.html: autocontenida (imágenes en base64), pestañas o rejilla, **2–3 variantes claramente distintas lado a lado** por item más el «antes», hechas con maquetas reales en el simulador. Guarda también las PNG de cada variante en ~/Claude/entregas/<sesión>/capturas/ (`L17-k-antes.png`, `L17-k-A.png`…), porque Frank se las enseñará a Jürgen pregunta por pregunta.
**No esperes la elección de Jürgen.** Cuando termines, `xcrun simctl shutdown all` y cierra normal con /cerrar-total. Frank junta las decisiones después y las guarda en las cards para la fase de implementación.

## Reglas duras de UI
- NADA de degradados, NADA de glows/brillos, NADA de contraste en blanco sólido.
- El botón «Siguiente» NO se toca.
- El liquid glass se queda.
- La moneda «S/» frente a «PEN» es una preferencia del usuario: nunca la pongas como opción A/B/C.
- Capturas de HOY (de esta sesión) y maquetas reales en el simulador para cada propuesta visual.
- Copy nueva en los 16 idiomas (es-AR con voseo).

## Cómo
- Pipeline serie en la Mini: `nice -n 10 xcodebuild -jobs 2`, como máximo 1 simulador, `xcrun simctl shutdown all` al terminar.
- Tests de lo que arregles con -only-testing y /gate.

## Reglas
Totalmente autónomo: nunca AskUserQuestion ni preguntas, decide tú. Sin deploy.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Sobre qué rama?** → `origin/2.2`. El worktree nació sobre 2.1 (b912200ae); se realineó con `reset --hard origin/2.2` antes de tocar nada (no había commits propios).
Por qué: el encargo pide base y PR a 2.2. Alternativa descartada: rebasar más tarde, que arrastraría 2.1 al PR.

**D2 · ¿Cómo se ven precios y compra en el simulador?** → Un conductor XCUITest TEMPORAL con `SKTestSession` (copia local de `Configuration.storekit`), no commiteado.
Por qué: `xcodebuild` + `simctl` no aplican la configuración StoreKit del scheme y el paywall sale sin planes. Alternativa descartada: auditar sin precios, que deja fuera la mitad de 17.1.

**D3 · ¿Cómo se capturan estados que Yala Dev no alcanza (prueba activa, banner periódico, éxito de compra, hoja de conservar)?** → Parche local de maqueta (`LOTE17-TEMP`), igual que los lotes 7-16; no entra al PR.
Por qué: en Yala Dev una compra real nunca activa Pro (rama `.dev` de `updateSubscriptionStatus`) y los productores de esos avisos están apagados bajo `-uitest`. Alternativa descartada: añadir seams permanentes, que es alcance que nadie pidió.

**D4 · ¿Qué cuenta como bug claro a arreglar en el PR?** → Lo que contradice al propio producto o miente al usuario: precios que no cargan sin aviso, «Error de compra» al cancelar, la etiqueta de ahorro que nunca sale, la prueba gratis prometida a quien ya la usó, el precio mensual mal compuesto, la hoja de prueba vencida que destaca solo la voz, «insights AI» en español y el error de verificación en inglés.
Por qué: el encargo manda arreglar solo bugs claros. Alternativa descartada: rediseñar el paywall aquí; eso es de Jürgen (cards).

**D5 · La etiqueta «Ahorra N %» lleva un degradado y ahora pasará a verse.** → Se pinta con relleno sólido del acento del tema.
Por qué: regla dura del encargo, nada de degradados; el arreglo no puede estrenar uno. Alternativa descartada: dejar el degradado porque «ya estaba en el código».

**D6 · Prueba ya usada en la oferta de prueba (`ProTrialOfferSheet`)** → Las tarjetas y el botón dejan de prometer la prueba, y el título pasa al del paywall general (copy existente, ya traducido). No se cambia CUÁNDO sale la oferta.
Por qué: arregla la mentira sin decidir producto; cuándo ofrecerla va a card (L17).

**D7 · Copy nuevo** → tres claves (`subscription.perMonthUnit`, `subscription.restoreErrorTitle`, `subscription.error.verificationFailed`) en los 16 idiomas, es-AR con voseo, `es`/`pt` copia de `es-419`/`pt-BR`.

**D8 · Tests** → unit para la lógica de precios y la clasificación del error al restaurar; XCUITest para «sin precios» (el simulador no carga productos de forma determinista) y para la hoja de prueba vencida sin la fila de voz.
