---
status: inbox
created: 2026-09-18
source: mesa Grok → Frank (pedido explícito Jürgen)
rule: no abrir tickets ni lanzar Mini hasta que Jürgen priorice
---

# Inbox de producto — 18 sep 2026

Captura para no perder el hilo. **No es backlog ejecutable.** Jürgen decide qué pasa a `tickets/` / `docs/TICKETS.md`.

## Prioridad sugerida por Frank (cuando reabran producto)

1. Captura → asiento &lt;15 s  
2. Alerta a mitad de mes (ampliar cercanos; no epic nuevo a ciegas)  
3. UI 27 táctico (skills en repo + `.reorderable()` + sheet al pulgar); Duo = low  
4. Recurrentes (discovery acotado; Latam = ver/avisar/proyectar, no cancel-one-tap)  
5. Mío / tuyo / nuestro + split por ingreso — después; **no** relanzar `groups-pending-member`  
6. On-device first — tesis/ADR, no sprint de feature ahora  

Primero, cuando vuelva la cola: device-QA de lo ya mergeado en 2.1.

## Ideas (le gustaron; tickets posibles, no epic)

1. **Capa de recurrentes** — ver, avisar subida de precio, proyectar el año. En Latam: visibilidad + recordatorio, no “cancel with one tap”.
2. **Mío / tuyo / nuestro + split por ingreso** — resumen para la conversación, no para el feed. Relacionado con `groups-pending-member` (sigue bloqueado a decisión; no relanzar esa pregunta).
3. **On-device first, sync opcional** — Claude Money (pestaña Money en Claude iOS, EE.UU., 14–15 sep) es amenaza de categoría (LLM + banco). Yala gana en Latam / privacidad.
4. **Captura → asiento en &lt;15 s** (foto de boleta / SMS del banco). Tres días sin abrir no deberían generar deuda de categorización.
5. **UI 27** — sobres `.reorderable()` + sheet anclado; cargar skill de Apple en el repo.
6. **Alerta a mitad de mes** (“vas a pasarte en comida”), no solo el cierre.

## Swift / Xcode (pegar al repo cuando toque; no rewrite)

- **Swift 6.4** (15 sep): `await` en `defer`; `anyAppleOS 27`; opaque `some T?`; `@diagnose`; Swift Testing ↔ XCTest (migración incremental). Swift Build default en SPM solo si hay CI fuera de Darwin.
- **Xcode 27 Agent Skills**: `xcrun agent skills export` → `swiftui-specialist` + `swiftui-whats-new-27` en el repo. Skill v5 Antoine (14 sep): SDK 27 + layouts iPhone Duo (proposed size, size classes, ViewThatFits, AnyLayout — no `UIScreen.main`).
- **SDK 27 usable ya**: `.reorderable()` sobres; `presentationPlacement()` sheet de gasto al pulgar; AsyncImage con URLRequest. Cuidado: ToolbarKeyboardAssistant en iOS 27 desfasa altura del teclado — testear captura de monto.
- **iPhone Duo** (anuncio 9 sep, preorden 16 oct, venta 23 oct, USD 1999): 5.4" cerrado / 7.6" abierto, mismo aspect, Split View, Device Hub. No es el ship de Q4; no diseñar como si solo existiera un Pro de 6,3".

## Mercado 2026 (contexto)

YNAB ~USD 109/año, Monarch 100–199, Copilot Money ~95. Queja nº 1: el bank sync se cae. No Plaid-hero en Perú. Nada de FIRE, crypto ni RSU.

## Solapes ya en el board (no duplicar)

| Tema | Ticket existente | Notas |
|---|---|---|
| Duo | `iphone-duo-native-app` (backlog, low) | Idea 2026-09-09 |
| Groups pending | `groups-pending-member-sees-detail-chrome` (backlog) + done de la puerta | Decisión de producto sigue pendiente; no relanzar |
| Cercanos a alerta / proyección | `cashflow-spend-prediction`, `smart-ai-notifications` | Ampliar si toca mitad-de-mes |
| Cercano a split por ingreso | `budget-tied-to-income-or-expense` | No es mío/tuyo/nuestro |

Las seis ideas de arriba **no** tienen ticket 1:1 todavía.
