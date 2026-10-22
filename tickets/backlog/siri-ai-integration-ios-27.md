---
id: siri-ai-integration-ios-27
status: backlog
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
