---
id: ai-onboarding-demo-speaks-english-and-dollars
status: done
priority: low
area: ai
created: 2026-10-12
updated: 2026-10-16
---

# La presentación de Yala IA dice «Yala AI» y enseña dólares en es-MX

En español (es / es-419), la presentación de la IA (`yalaAI.onboarding.*`) dice «Te presento a **Yala AI**» y «Tres formas de aprovechar a Yala AI», cuando el resto de la app dice «Yala IA». El chat de ejemplo registra «Gasté $12 en almuerzo» como **USD 12.00** aunque la divisa principal sea MXN, y otra burbuja trae «casi $1.000 al año» (separador de miles europeo) y una raya «—». Medido en simulador con `-AppleLocale es_MX -defaultCurrencyCode MXN` el 2026-10-12. Por eso las capturas de la ficha 2.1 usan el selector de tono y no esta pantalla.

## 2026-10-15 · la mitad del nombre, arreglada (auditoría UX 2.2 · lote 14)

La presentación ya dice el nombre del chat en cada idioma: «Yala IA» en los cuatro españoles, francés, italiano y los
tres portugueses, y «Yala KI» en alemán (`YalaAIAuditLote14Tests` lo fija contra `chat.assistantName`). Queda abierto
lo de la divisa: la demo sigue escribiendo «$12» y la tarjeta de ejemplo `USD 12.00` aunque el usuario lleve soles o
pesos, y el paso 5 sugiere «Registra un café de 5 pesos» también en Perú.

## Resuelto (2026-10-16)

La presentación habla en la divisa principal del usuario en los 16 idiomas: los importes del chat, la tarjeta, la
frase del estilo «Ahorrador» y el consejo del último paso salen de `YalaAIOnboardingDemoAmounts` (base en dólares
escalada con la tasa de respaldo y redondeada a cifras redondas) con el formato de la app. Medido en es-MX con MXN:
«Gasté $ 210 en almuerzo» y la tarjeta en `$ 210.00`, no `USD 12.00`. El anual es el mensual × 12 («son … al año»,
sin «casi»), las dos rayas se fueron, y «Yala IA» sustituye a «Yala AI» en es, es-419, es-AR, es-ES, fr, it y pt-PT.
Tests: `YalaAIOnboardingDemoAmountsTests`.
