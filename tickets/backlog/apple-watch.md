---
id: apple-watch
status: backlog
priority: low
area: platform
created: 2026-07-01
updated: 2026-10-08
source: YalaWiki/Ideas/Integración con Apple Watch.md
---


# Integración con Apple Watch

## La idea

Una app nativa de Yala para Apple Watch. Jürgen la vuelve a nombrar el 2026-09-09, en la misma tanda
que iPad e iPhone Duo, y esta vez con prioridad: **low**.

## Por que importa

El reloj es donde se paga, así que es donde el gasto está más fresco. Pero también es la pantalla
más pequeña de todas: sirve para capturar y consultar un número, no para revisar finanzas — y por
eso va detrás de iPad.

## Notas

- Capturado originalmente en Inbox sin desarrollo; reubicado en la limpieza del vault del 2026-07-01.
- **2026-09-09**: Jürgen lo repite como idea nueva. No se creó un ticket duplicado — se le puso aquí
  la prioridad `low` que él dio y se rellenó el cuerpo, que estaba vacío desde la migración.
- Sin spec. Antes de estimar, medir qué necesita un target de watchOS en este proyecto (App Group,
  SwiftData, sync) — no está medido.

## Relacionados

- [[ipad-native-app]] y [[iphone-duo-native-app]] — la misma tanda de plataformas del 2026-09-09.

migrated from YalaWiki Ideas/Integración con Apple Watch.md @ 1934e8ad

## Medido en 2.1 (triage 2026-10-08)

- No hay target de watchOS: `grep -ci "watchos\|WatchKit" Yala.xcodeproj/project.pbxproj` da 0. Sigue sin spec ni medida de qué necesita (App Group, SwiftData, sync).

Triage 2026-10-08: abierto · low → low · idea sin empezar (ningún target de watchOS) con la prioridad `low` que le dio Jürgen el 2026-09-09.
