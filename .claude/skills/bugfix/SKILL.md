# Bug Fix Lifecycle

Flujo completo para resolver un bug de forma disciplinada.

1. Leer las notas de QA o descripción del bug proporcionada
2. Analizar causa raíz — proponer fix mínimo, NO hacer cambios no relacionados
3. Presentar plan y ESPERAR aprobación del usuario
4. Implementar fix (leer archivos de localización antes de editarlos)
5. Ejecutar build completo: `/verify-ios`
6. Ejecutar tests relevantes si aplica: `/test-smart`
7. Resumir cambios y preguntar si el usuario quiere device QA
8. Commitear con mensaje descriptivo cuando el usuario apruebe
