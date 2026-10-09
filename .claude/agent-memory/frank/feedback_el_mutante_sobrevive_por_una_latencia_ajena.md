---
name: el-mutante-sobrevive-por-una-latencia-ajena
description: Al mutar una ESPERA, otra llamada lenta del mismo camino puede tapar la carrera; el mutante sobrevive sin que la espera sobre.
metadata:
  type: feedback
---

Cuando el arreglo es una espera (que la UI se asiente antes de tocar), quitar solo esa espera no basta como
mutante: cualquier otra llamada lenta del mismo camino puede cubrir la carrera por accidente. El 2026-10-09 el
mutante sin `waitForSettledLayout` salió verde porque `waitForExistence` tarda ~1 s en iOS 27.0 aunque el
elemento ya exista.

**Why:** casi concluyo «la espera sobra» o «la causa es otra». La pregunta buena era la contraria: ¿la espera
SOLA basta, y la otra latencia SOLA también? Tres mutantes la contestaron: sin nada, rojo; solo la espera
nueva, verde y con lecturas que la ven trabajar; solo la latencia ajena, verde por accidente.

**How to apply:** al validar una espera, monta los tres mutantes (nada / solo la mía / solo la ajena), con una
sonda que imprima qué ve la espera en cada lectura. Se activan por `TEST_RUNNER_<VAR>` desde `xcodebuild` en una
sola build. Relacionado: [[el-mutante-que-sobrevive-puede-sobrar]], [[el-oraculo-del-mutante-es-el-efecto-que-produce]].
