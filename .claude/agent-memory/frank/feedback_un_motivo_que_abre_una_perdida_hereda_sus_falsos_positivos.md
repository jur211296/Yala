---
name: un-motivo-que-abre-una-perdida-hereda-sus-falsos-positivos
description: Cuando un motivo que solo elegía un TEXTO pasa a abrir una salida que pierde datos, sus falsos positivos pasan a costar datos; exige prueba aparte.
metadata:
  type: feedback
---

Antes de colgar una salida destructiva de un motivo existente, **enumera qué más produce ese motivo**. Si el clasificador
sobre-aproxima (lo que no sabe, lo mete ahí), exige una prueba independiente de la condición antes de ofrecer la pérdida.

**Why:** 2026-09-28, `cloud-sign-out-with-an-expired-session-and-personal-changes-has-no-exit`. Colgué «Cerrar sesión y
perderlos» de `.sessionExpired`, y todo 401 del gateway que no sea de attest llega así, también con la sesión guardada y
renovable. Mientras el motivo solo elegía el texto «vuelve a entrar», ese falso positivo era inocuo; con la salida, un deploy
roto habría ofrecido a toda la flota perder sus movimientos. Lo cazó la lente de pérdida de datos, no yo; los tests puros
pasaban porque probaban la tabla de motivos, no quién los produce.

**How to apply:** al abrir una salida por motivo, busca los productores del motivo (`grep` del `case` y de su traducción) y
pregúntate «¿quién llega aquí sin que la condición sea verdad?». La prueba va como parámetro de la decisión pura, fail-closed
(sin testigo, `false`), y con su mutante. Relacionado: [[el-outcome-que-clasifico-lo-produce-otro]],
[[mi-arreglo-cumple-una-premisa-que-era-falsa]].
