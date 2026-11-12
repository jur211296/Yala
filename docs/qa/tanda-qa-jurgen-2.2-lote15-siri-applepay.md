# Tanda de QA · 2.2 · lote 15 decidido (Siri, Atajos y Apple Pay)

Barrido acotado a las siete cards de esta sesión (2026-10-21, PR #581). Revisadas 7: 4 cerradas con evidencia, 1 de
ellas probada además en el simulador; 3 se quedan para el iPhone. Tiempo de la tanda: ~10 min.

**Build:** el que lleve el PR #581 (Yala Dev contra staging vale). Nada de esto bloquea el lanzamiento.

## Pruebas en el iPhone (un montaje: sin Pro, iPhone desbloqueado)

1. **L15-6 · Siri sin Pro** (2 min). «Oye Siri, anota un gasto en Yala». Esperado: Siri dice «Activa Yala Pro…» y Yala
   se abre en la hoja de Pro, sin pedirte antes qué registrar.
2. **L15-5 · Siri en otro idioma** (5 min). Ajustes del iPhone › General › Idioma › Deutsch. «Hey Siri, Notiere eine
   Ausgabe in Yala» → pregunta qué registrar. «Hey Siri, Erfasse in Yala» → abre Nuevo registro. Vuelve al español.
3. **L15-8 · Notificación de Apple Pay** (3 min, con la automatización de Apple Pay montada). Guarda un movimiento en
   una cuenta en soles; paga algo con Apple Pay. Esperado: «Pago de S/ … en <comercio> por revisar» · «Tócalo para
   aprobarlo.»; al tocarla, la Bandeja con ese borrador en soles.

## Lo que pasó a done

| Card | Motivo | Evidencia |
|---|---|---|
| L15-4 «Siri y Atajos» | XCUITest del flujo real + capturas | `SiriShortcutsScreenUITests` (el botón abre la página de Yala en Atajos); `despues-1`, `-1b`, `-4` |
| L15-7 aviso de la Bandeja | XCUITest + unitarios | `SiriShortcutsScreenUITests` (aviso solo Siri y mixto), `InboxAlertSiriLineTests`; `despues-5`, `-5b` |
| L15-9 guía de Apple Pay | capturas de iOS 27 sacadas del simulador + test | `ApplePayGuideIOS27Tests`; `despues-2`, `-6`, `-6b` |
| L15-10 «Listo» al final | XCUITest + unitarios | `StepGuideUITests` (incluido el avance guardado), `StepGuideFooterAndProgressTests` |

## Lo que se queda

| Card | Qué lo retiene (§4) |
|---|---|
| L15-5 frases en 16 idiomas | Siri por voz no existe en el simulador |
| L15-6 Siri sin Pro | Siri por voz (la acción desde Atajos sí se probó en el simulador: abre la hoja de Pro) |
| L15-8 notificación de Apple Pay | la automatización de Wallet no corre en el simulador |

Capturas: `~/Claude/entregas/Yala--lote-decidido-2-2-09-siri-atajos-y-apple-pay/capturas/`.
