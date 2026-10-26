---
id: l10n-terminology-follows-the-tab-names
status: done
priority: low
area: l10n, copy
created: 2026-10-25
updated: 2026-10-26
source: revisión de traducciones con Sonnet del lote 12.4 (`qa/l10n-review/informes/2026-10-25/`), categoría «terminologia»
---

# Los textos nombran conceptos con otra palabra que la pestaña o la pantalla

## Qué ve el usuario

En 10 idiomas la pestaña principal se llama «Home», «Accueil», «Início», «Übersicht», «Start»…, pero la prosa de la
ayuda y de los avisos dice «Panel» («Show %@ on your Panel?»). En pt-BR la pantalla de ajustes se llama a la vez
«Ajustes» (`profile.title`) y «Configurações» (`settings.title`), y 70 textos dicen «Ajustes». Hay más casos sueltos:
«Etiketten» frente a «Tags» en alemán, «pianificati» frente a «programmati» en italiano, «planejados» frente a
«agendados» en pt-BR, y el nombre del asistente varía por idioma («Yala AI» en en/ja, «Yala KI» en de, «Yala IA» en
el resto, con excepciones dentro de cada uno).

## Por qué no se aplicó en el lote 12.4

La revisión dejó ~1.000 propuestas de terminología y el muestreo las vio contradecirse entre trozos (en pt-BR proponía
«Configurações» en unos textos y «Ajustes» en otros) y renombrar conceptos que son decisión de copy. Aplicarlas en
bloque habría mezclado más.

## Qué decidir (Jürgen)

1. ¿La prosa nombra la pestaña con su nombre en cada idioma («Home», «Início»…) o se renombra la pestaña a «Panel»?
2. pt-BR: ¿la pantalla es «Configurações» o «Ajustes»? (Los Ajustes del iPhone se llaman «Ajustes» en iOS brasileño
   y esos textos se quedan.)
3. ¿«Yala IA» en todos los idiomas, o el nombre traducido («Yala AI», «Yala KI»)?

Con eso, `qa/l10n-review/apply.py` puede aplicar las propuestas de `terminologia` filtradas por la decisión (están en
los `<idioma>.json` del informe, con `no_aplicada_por: categoría terminologia`).

## Resuelto (2026-10-26)

Jürgen eligió B en las tres: la pestaña se llama «Panel» en todos los idiomas (Painel en pt, パネル en ja, 面板 en
zh); pt-BR dice «Ajustes»; el asistente se nombra según el idioma (Yala AI / Yala KI / Yala IA).

- No se aplicaron las propuestas de `terminologia` del informe (se contradecían): se midió cada idioma y se reescribió
  clave a clave. ~400 textos de app y widgets en 12 idiomas; la pantalla de inicio del iPhone, su botón y «hogar» no
  cambian.
- pt-BR: 13 «Configurações» → «Ajustes». De paso, pt-PT: 8 «Ajustes» → «Definições» y fr: 2 «Paramètres» →
  «Réglages», para que cada idioma nombre la pantalla de una sola forma.
- El asistente ya tenía un solo nombre por idioma tras el lote 12.4: las «excepciones» eran comentarios del catálogo.
- Guardas en `LocalizationParityTests`: `tabPanel_isNamedPanel`, `textsThatNameThePanel_useTheTabWord`,
  `settingsScreen_hasOneName`, `assistant_hasOneName`.
