---
id: siri-ai-integration-ios-27
status: qa
priority: high
area: "platform, siri"
created: 2026-09-09
source: idea Jürgen 2026-09-09
---

# Integrar Yala con el nuevo Siri con IA de iOS 27

## La idea

Enganchar Yala al Siri renovado de iOS 27, para que registrar un gasto o preguntar por el saldo se
pueda hacer hablando, sin abrir la app.

## Por qué importa

Es el camino más corto entre «acabo de pagar algo» y que quede registrado — que es justo donde una
app de finanzas personales se gana o se pierde el hábito. Y llegar tarde a una integración de
sistema se nota: quien ya está dentro aparece en las sugerencias, quien no, no existe.

## Requiere investigación profunda antes de nada

Jürgen lo marca así, y con razón: **no hay spec posible sin averiguar primero qué expone iOS 27**
(qué reemplaza o amplía a App Intents, qué se puede hacer sin abrir la app, qué exige de permisos y
de privacidad, y qué versión mínima obliga). El target hoy es iOS 26+ (`CLAUDE.md`), así que subir
el suelo es parte de la decisión, no un detalle.

## Estado

Idea capturada, **sin spec**. Prioridad `high` puesta por Jürgen. El primer paso no es diseñar: es
una investigación con conclusiones escritas.

## Relacionados

- [[siri-intent-dual-container]] — el intent de Siri que ya existe, y su callout sobre contenedores.
- [[storekit-appgroup-siri-pro-gate]] — el gate Pro de Siri vía App Group.

## Investigación y entrega (2026-10-18)

Documento: [`docs/siri-ios-27-2026-10.md`](../../docs/siri-ios-27-2026-10.md) — qué hace hoy Yala con Siri, qué abre
iOS 27, opciones A/B/C con coste y privacidad, y la recomendación. Fuente: SDK de iOS 27.1 (Xcode 27.1) y sesiones
WWDC26 240, 343, 344, 345 y 295.

**Lo que decide todo**: el Siri con IA entiende y actúa en las apps a través de **esquemas** de Apple, y **no hay
esquema de finanzas**. El único que encaja es el de sistema («abrir», «buscar dentro de la app»). **No hace falta subir
el mínimo de iOS 26**: lo de iOS 27 va marcado para iOS 27.

**Hecho (opción B, reversible y sin datos nuevos fuera del teléfono)**:

- «¿Cuánto gasté en Yala?» (por voz, este mes; en Atajos, también esta semana, el mes pasado o este año) y «¿Cuánto tengo en Yala?»
  (total o una cuenta): contestan sin abrir la app, con el iPhone desbloqueado, leyendo una foto de tus números que la
  app guarda en el teléfono junto a la de los widgets (`SiriFinanceSnapshot`). Si la foto es de otro mes, no inventa.
- Entidad «cuenta» con búsqueda por nombre, sin índice de Spotlight.
- «Abrir cuenta» con el esquema `.system.open` (solo iOS 27): abre la ficha de la cuenta en el Panel.
- Gratis, como los widgets (pregunta abierta para Jürgen en `siri-ai-content-in-spotlight-and-pro-decision`).

Tests: `YalaTests/SiriIOS27Tests.swift` (8 suites) y `YalaUITests/Flows/SiriIntentsUITests.swift` (App Intents Testing,
la app real y la vía real; solo compila con Xcode 27).

**Pendiente de decisión** (no se hace aquí): opción C — cuentas y movimientos en Spotlight, «esta cuenta» con la pantalla
abierta, «busca X en Yala» — y si las preguntas son Pro. Ticket `siri-ai-content-in-spotlight-and-pro-decision`.

### Guion de iPhone (Jürgen, 5 min, iPhone con iOS 27 y Siri con IA)

Siri por voz no existe en el simulador: hace falta el iPhone.

1. Instala el TestFlight de 2.2 que traiga este cambio y abre Yala una vez (así guarda la foto para Siri).
2. Con el iPhone **desbloqueado**, di «Oye Siri, **¿Cuánto gasté en Yala?**». Debería decir lo que llevas gastado este
   mes, el mismo número del widget de gastos.
3. Di «Oye Siri, **¿Cuánto tengo en Yala?**». El total, como el widget de saldo.
4. Bloquea el iPhone y repite el paso 3: Siri tiene que pedirte desbloquear antes de decir el número.
5. Desbloqueado, di «Oye Siri, **abre mi cuenta <nombre de una cuenta> en Yala**». Debería abrir su ficha.

Si algo de esto no pasa, dime qué contestó Siri, palabra por palabra.

**Medido en el simulador (2026-10-18, iOS 27.0, es-PE)**: la pregunta «¿Qué quieres registrar?» y «Activa Yala Pro para
usar registro con Siri.» salen en español con este cambio (antes, en inglés). Los botones «Cancel / Done» y el «Text» del
campo los pinta el sistema y siguen en inglés en el simulador; no dependen de Yala. Capturas en el PR.
