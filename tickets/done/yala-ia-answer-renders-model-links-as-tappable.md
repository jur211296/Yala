---
id: yala-ia-answer-renders-model-links-as-tappable
status: done
priority: medium
area: "ia, privacidad, chat"
created: 2026-10-18
updated: 2026-10-18
source: "Review adversarial de la sesión partir-ia-nube-o-privado, medido sobre origin/2.2 9e341a461"
card: tablero-yala-ia-pinta-como-enlace-tocable-cualqu-34lb
---

# Yala IA pinta como enlace tocable cualquier link que escriba el modelo

## El problema, en lenguaje de usuario

La respuesta de Yala IA se pinta con markdown en línea (`Yala/App/Views/Chat/ChatMessageBubble.swift:52`,
`Text(LocalizedStringKey(paragraph))`), así que un `[texto](https://…)` del modelo sale como enlace que se puede
tocar.

El modelo lee texto que el usuario no escribió: la nota de un gasto de grupo es la descripción que puso otro miembro
(`GroupTransactionBridge`). Una nota con instrucciones podría conseguir que la respuesta enseñe un enlace con cifras
del usuario metidas en la URL; tocarlo las mandaría a un tercero. Hoy ya llegan al prompt los comercios que salen de
las notas del mes; el camino ampliado de la nube (`docs/ai-cloud-vs-private-2026-10.md`) lo agranda: notas completas,
de cualquier fecha y con búsqueda.

Lo que lo limita: hace falta que el usuario toque el enlace, y las herramientas no pueden escribir ni salir a internet.

## Qué hacer

Pintar la respuesta del asistente sin enlaces tocables (negrita y código sí), o quitar los enlaces del texto, con un
test que lo fije. Antes de encender el camino ampliado.

## Hecho cuando

Una respuesta de Yala IA que trae un enlace markdown no abre nada al tocarla, y un test lo fija.

## Cerrado (2026-10-18)

Decisión 4A de Jürgen: los enlaces del modelo salen como texto salvo los de yala-app.pe. La burbuja pinta con
`YalaIAAnswerLinkPolicy.inlineMarkdown` (markdown en línea; solo `https` a `yala-app.pe` o un subdominio conserva el
enlace) y las tarjetas de Observaciones, que pintaban markdown del modelo igual, pasan por el mismo filtro. Lo fijan
`YalaIAAnswerLinkPolicyTests` y el XCUITest `YalaIACloudExploreConsentUITests#test_answerBubble_onlyTheYalaLinkIsTappable`,
que con la burbuja de antes sale rojo (medido).
