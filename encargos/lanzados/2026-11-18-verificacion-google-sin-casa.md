Yala
# Verificación de Google sin pagar CASA: qué tenemos, qué queremos y qué perdemos sin leer Gmail
---
toca: docs/analisis/2026-11-18-verificacion-google-sin-casa/,tickets/backlog/2026-11-18-verificacion-google-sin-casa.md
esfuerzo: high
cierre: cierra-sola
---

Contexto: el 18-nov (14:21 Lima) Google (Third Party Data Safety Team) respondió a la verificación OAuth del proyecto `yala-502622`: para seguir exige una evaluación ADA-CASA AL1 antes del 16-feb-2027, porque pedimos el permiso restringido `https://www.googleapis.com/auth/gmail.readonly` (lo usa `GmailBankAlertImporter` para leer alertas de bancos). Precios vistos: TAC Security 675/855 USD, Secusy 499/599 USD, y se repite cada año. Decisión de Jürgen del 18-nov, registrada: NO se paga la evaluación (demasiado cara). Pide analizar bien lo que tenemos, lo que queremos tener y lo que perderemos sin ese permiso, y buscar las mejores soluciones.

Antecedentes en el repo: `docs/verificacion-google/` (videos v2 a v4 y respuestas a Google) y el importador de Gmail.

## Qué hacer (solo análisis, sin cambiar código de la app)
1. Lo que tenemos: inventario real de todo lo que depende de Google en Yala (inicio de sesión, `gmail.readonly`, importador de alertas, bancos cubiertos, cuántos usuarios lo usan si hay datos sin tocar producción, pantallas y textos afectados, web incluida). Qué pasa hoy con usuarios fuera de la lista de prueba (pantalla de app no verificada, tope de 100 usuarios, caducidad de tokens a 7 días en modo prueba, etc.), con fuente oficial.
2. Lo que queremos: la experiencia ideal de registrar movimientos automáticamente desde los avisos del banco.
3. Lo que perderemos si quitamos el permiso, y lo que pasa si no hacemos nada antes del 16-feb.
4. Alternativas, comparadas en costo (sin gastos nuevos como regla), esfuerzo, privacidad, fricción para el usuario, cobertura de bancos peruanos y riesgo con Apple y Google. Como mínimo: reenvío de alertas a una dirección de Yala (Cloudflare Email Routing u otra entrada que ya tengamos), filtro de reenvío automático de Gmail configurado por el usuario, atajos o automatizaciones de iOS sobre notificaciones o SMS, compartir desde Mail con la extensión, notificaciones push del banco, Apple FinanceKit si aplica en Perú, Open Banking o agregadores, y mantener Gmail solo en modo prueba para Jürgen y testers. Si encuentras otras mejores, inclúyelas.
5. Recomendación clara con plan por fases (qué entra en 2.3, qué después), qué contestarle a Google (cancelar solo el permiso restringido manteniendo la verificación de marca de inicio de sesión) y la lista de sesiones de implementación propuestas, sin encolarlas.

## Cómo entregar
- Base 2.3, un PR solo con el análisis y el ticket en backlog con la recomendación.
- No toques producción, la consola de Google ni el correo de Google: nada de responderle. Para fuentes web usa las oficiales y cítalas.
- Si necesitas probar algo en simulador: puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, solo uno.
- Entregable visual: artifact de Claude interactivo, en español neutro latinoamericano, fácil para decidir (tabla comparativa, recorridos de usuario de cada alternativa, recomendación destacada). Nunca Markdown ni PDF como entregable.
- Commits y PR sin firma de IA.
- Lo vital, según el modo fijado al arrancar (semi: pregunta y espera viva; nocturno: checkpoint recuperable y card «Espera decisión», sin mergear lo incompleto). Lo menor, con la opción recomendada, en «Decidido sin consultar».
- Cierre: completo y CI verde, `/cerrar-total` con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones

> Resueltas en autónomo (sesión lanzada, modo semi, sin nadie delante): las recomendaciones se dan por buenas. Se
> discuten en el PR. Hechos cerrados antes: producción (rama `1.0`) no pide ningún permiso de Gmail; «Conectar Gmail»
> vive solo en el PR abierto de «Conectar Gmail» mínimo, detrás de `DEV_BUILD`; 2.3 ya trae el reenvío a
> yalainbox.com y el atajo del banco.

**D1 · ¿Qué es la entrega?** → Un artifact público con db (veredicto sí / no / después por fase y por sesión), y en el
repo `docs/analisis/2026-11-18-verificacion-google-sin-casa/` con la fuente (`artifact/index.html`) y un `README.md`
corto que la resume. Por qué: decisión del 11-nov (propuestas como artifact visual) y memoria de Frank. Alternativa
descartada: solo Markdown, que el encargo prohíbe como entrega.

**D2 · ¿Se miden usuarios de Gmail en producción?** → No se consulta producción: se mide por el código. Producción no
lleva la función, así que el número es cero por construcción; el tope de 100 usuarios sin verificar se cita del
estado medido el 23-oct (3 de 100), sin abrir la consola. Por qué: el encargo prohíbe tocar producción y la consola.

**D3 · ¿Simulador o iPhone?** → No hacen falta: no se cambia la app y los recorridos de 2.3 ya están medidos (atajo B0
en el iPhone 14, reenvío con su gate). Las pruebas de interfaz no aplican. Alternativa descartada: recapturar
pantallas, que no cambia ninguna conclusión.

**D4 · ¿Se incorpora la decisión del 18-nov?** → Sí, entrada en `docs/DECISIONS.md` y su índice. `decisiones.py` no
existe en la Max (medido): el registro del lote queda para la Mini o el bot, anotado en el cierre.

**D5 · ¿Se escribe la respuesta a Google?** → Se deja un borrador en inglés en el análisis; no se envía ni se toca la
consola (lo prohíbe el encargo). La envía Dan con el GO de Jürgen.

**D6 · Base y entrega** → Rama `encargo/…` sobre `2.3`, PR solo de documentación y cola de auto-merge al cerrar
(`cierre: cierra-sola`).
