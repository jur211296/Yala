---
esfuerzo: medium
---
# El manifiesto de privacidad no declara lo que recoge la cuenta en la nube

**Card:** tablero-el-manifiesto-de-privacidad-no-declara-l-kgqv · **Prioridad:** según la card · **Versión:** 2.1 · **Ticket:** `tickets/backlog/privacy-manifest-misses-cloud-account-data.md` (del PR #443, checklist de envío)

## Qué se pide
1. Alinea `Yala/Resources/PrivacyInfo.xcprivacy` con la propuesta de §1.2 de `docs/RELEASE-CHECKLIST-2.1.md`: Name, Email, User ID, Other User Content, Product Interaction y Other Diagnostic Data; Device ID pasa a vinculado con App Functionality y Analytics; fotos y audio como vinculados (lo prudente, a confirmar por Jürgen: anótalo en el cierre).
2. Añade el motivo `1C8F.1` de UserDefaults por el App Group y revisa las demás Required Reason APIs que use la app y los targets (widget, share extension); valora un manifiesto para el widget y la extensión si les toca.
3. Valida que el plist es correcto (plutil -lint) y que entra en el bundle de Release (build del scheme «Yala»); si hay forma, genera el Privacy Report de Xcode desde un archive local sin subirlo.
4. Deja en el cierre la tabla final para que Jürgen copie lo mismo en App Privacy de App Store Connect.

## Reglas de siempre
- Arranca sobre `origin/2.1` y trabaja sin esperar a nadie. Justo antes de abrir el PR: `git fetch` y rebase sobre `origin/2.1`, resolviendo ahí los conflictos (strict=false); si el rebase toca lo tuyo, recompila y repite los tests afectados con un solo simulador.
- Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo en `tickets/`, mira con `tablero listar --proyecto Yala --todas` que no tenga card y, si no, `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url>"`. SIN --fecha (opcional desde el ADR-068; sin fecha de relleno). Lista esas cards en el aviso de cierre.
- Sin deploy, sin secretos y sin decisiones de UI de Jürgen: si algo lo pide, para y anótalo en el cierre.
- Cierre: `/cerrar-total` autónomo (PR a 2.1 en auto-merge, limpieza de simulador, worktree y DerivedData).

## Carga de la Mini (OBLIGATORIO)
- Todo xcodebuild va con `nice -n 10 xcodebuild -jobs 2 ...`.
- Nunca dos builds o tests a la vez (ni build + tests); pipeline serie: build → 1 simulador → tests → erase.
- Antes de cada build espera a que la carga baje de 8: `while [ $(sysctl -n vm.loadavg | awk '{print int($2)}') -ge 8 ]; do sleep 30; done`.
- Nunca pases xcodebuild por `| head` (mata el build): escribe a un log y lee el log.
- Los `-only-testing:` van en un array de zsh, no en un string.

## Paso 0

- **Fuente de §1.2 y del ticket:** siguen en el PR #443, abierto. Se leen de su rama; el ticket no se crea aquí para no duplicarlo cuando #443 aterrice.
- **Fotos y audio:** vinculados, como propone §1.2. Asumido; lo confirma Jürgen.
- **Clave financiera:** el manifiesto usaba `NSPrivacyCollectedDataTypeFinancialInfo`, que Apple no reconoce. Pasa a `…OtherFinancialInfo`, la que nombra §1.2.
- **Widget:** lee el App Group con `UserDefaults(suiteName:)` (`WidgetDataService.swift:206`, `ControlCenterIntents.swift:28,55`). Lleva manifiesto propio, solo con `1C8F.1` y sin datos recogidos: no hace red.
- **Extensión de compartir:** solo crea un directorio y escribe una imagen en el App Group. No usa APIs con motivo ni red, así que no lleva manifiesto.
- **Timestamps (`C617.1`):** se mantiene. Las tres lecturas de `creationDate` son de ficheros del App Group.
- **Privacy Report:** Xcode solo lo genera desde el Organizer, sobre un archive. No hay vía por línea de comandos; queda para Jürgen.
