# Bugs de cuenta (25-nov-2026) — evidencia

Medido en el iPhone 14 (Yala Dev, staging) y en el iPhone 18 de Jürgen (copia de su store y sus preferencias).

| Qué | Antes | Después |
|---|---|---|
| Cola de subida tras «Recargar datos de prueba» + «Vaciar datos» | 7.166 cambios (3.148 altas con su baja, 1.099 bajas de tipos de cambio) | 602 |
| Esqueleto del Panel al reabrir, con sesión válida | 62 s (techo de la espera) | ~17 s contando el arranque (build Debug) |
| Esqueleto del Panel al reabrir, sin sesión | 60 s y banner | 2 s y banner |
| «Tu cuenta de Yala» en modo nube sin sesión | no sale | sale, con «Eliminar mi cuenta» |
| «Eliminar mi cuenta» sin sesión | — | pide entrar con Google, borra en staging, termina en el Welcome |
| Primeros pasos tras alta nueva en un teléfono de antes de 2.3 | no sale (falta `onboarding23.freshInstall`) | sale en «Solo gastos» y en «Gastos e ingresos» (XCUITest) |

Capturas: `capturas/antes.png` y `capturas/despues.png` en la raíz del repo, y el artifact del cierre.
