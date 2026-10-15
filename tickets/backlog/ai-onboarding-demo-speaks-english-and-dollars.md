---
id: ai-onboarding-demo-speaks-english-and-dollars
status: backlog
priority: low
area: ai
created: 2026-10-12
updated: 2026-10-15
---

# La presentación de Yala IA dice «Yala AI» y enseña dólares en es-MX

En español (es / es-419), la presentación de la IA (`yalaAI.onboarding.*`) dice «Te presento a **Yala AI**» y «Tres formas de aprovechar a Yala AI», cuando el resto de la app dice «Yala IA». El chat de ejemplo registra «Gasté $12 en almuerzo» como **USD 12.00** aunque la divisa principal sea MXN, y otra burbuja trae «casi $1.000 al año» (separador de miles europeo) y una raya «—». Medido en simulador con `-AppleLocale es_MX -defaultCurrencyCode MXN` el 2026-10-12. Por eso las capturas de la ficha 2.1 usan el selector de tono y no esta pantalla.

## 2026-10-15 · la mitad del nombre, arreglada (auditoría UX 2.2 · lote 14)

La presentación ya dice el nombre del chat en cada idioma: «Yala IA» en los cuatro españoles, francés, italiano y los
tres portugueses, y «Yala KI» en alemán (`YalaAIAuditLote14Tests` lo fija contra `chat.assistantName`). Queda abierto
lo de la divisa: la demo sigue escribiendo «$12» y la tarjeta de ejemplo `USD 12.00` aunque el usuario lleve soles o
pesos, y el paso 5 sugiere «Registra un café de 5 pesos» también en Perú.
