---
id: es-419-category-names-use-peruvian-words
status: done
priority: low
area: l10n
created: 2026-10-12
updated: 2026-10-25
---

# es-419: subcategorías con palabras que en México no se dicen

`es-419.lproj` (lo que ve un iPhone en es-MX) trae «Supermercados y **bodegas**» (`subcategory.supermarkets`, :2763) y «**Alquiler** o hipoteca» (`subcategory.rent`, :2779). «Bodega» es peruano; en México se dice «tienda de la esquina» o «abarrotes», y «renta» en vez de «alquiler». Salen en las capturas de la ficha es-MX (Distribución, Registros). Decidir si es-419 se neutraliza o si hace falta es-MX propio; ojo con las categorías ya sembradas en usuarios existentes (el nombre vive en el modelo).

## Resuelto (lote 12.4, 2026-10-25)

«Supermercados y bodegas» → «Supermercados y tiendas» en es-419, es, es-ES y es-AR. «Alquiler o hipoteca» se queda: «alquiler» se entiende en toda Latinoamérica y «renta» se lee como impuesto en varios países (BRAND-VOICE §9.4: un cambio léxico no justifica es-MX).
- Quien ya tiene la categoría sembrada conserva el nombre viejo (el nombre vive en su base y es editable); el deduplicador funde por icono y color, no por nombre, así que no duplica. Las capturas de la ficha es-MX (Lola) siguen con el texto viejo hasta su próxima tanda.
- La revisión de Sonnet del es-419 (qa/l10n-review) encontró además «Neto» escrito «Yala» (`cashFlow.net`) y textos sin tildes («Sin conexion», «Ano pasado»): corregidos.
- Lo fija `TranslationLot124GuardTests.neutralSpanish_categoryNamesHaveNoPeruvianWords` y `netLabel_isNotTheAppName`.
