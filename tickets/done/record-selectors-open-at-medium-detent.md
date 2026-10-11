---
id: record-selectors-open-at-medium-detent
status: qa
priority: medium
area: "transactions, groups, ui"
created: 2026-10-04
updated: 2026-10-04
source: encargo 2026-10-04-en-un-registro-nuevo-cuenta-etiquetas-y-xs4y (Jürgen, antes del QA del lunes)
---

# En un registro nuevo, cuenta / etiquetas / subcategoría abren a media altura

## Qué cambia para el usuario

Al tocar **Cuenta**, **Subcategoría** o **Etiquetas** desde Nuevo registro, la hoja abre a **media altura**, con el
formulario visible detrás. Si el usuario la estira, pasa a pantalla completa. Antes saltaba de golpe a pantalla
completa.

Vale también para las transferencias (cuenta de origen y de destino) y para el formulario de **gasto de grupo**
(cuenta y subcategoría; no tiene etiquetas). Allí la cuenta ya abría a media altura; la subcategoría abría grande.

Igual que el formulario de cuenta (#341, que no se toca): en ventana ancha (iPad a pantalla completa, Mac) y con
texto de accesibilidad (AX1–AX5) abre grande, y el fondo es transparente a media altura y el de siempre en grande.

## Lo medido (2026-10-04, iPhone 17 Pro, iOS 27.0)

- Antes: los tres abrían a pantalla completa desde Nuevo registro (`capturas/antes-*.png` del PR).
- Después: los tres abren a media altura, el tirador de la hoja dice «Media pantalla» y al estirar pasa a «Expandida».
  En grupos, la subcategoría abre a media altura.
- El resto de anfitriones de esos selectores (edición masiva, Inbox, favoritos, pagos programados, liquidaciones…)
  sigue igual: el tamaño es opt-in (`SelectorSheetSizing.mediumFirst`), el default `.large` no declara detent.

## Yala IA

Los selectores de la card de registro de Yala IA y de su hoja «Detalles» (`ChatDraftFieldSheet`, llegó con #348)
abren igual: media altura, estirable a grande.

## Guion de device-QA (iPhone)

1. Instala el build de TestFlight o de Xcode en el iPhone, con datos (cuentas, etiquetas).
2. Panel → **Nuevo registro**. Toca **Cuenta**: la hoja abre a media altura, con el formulario detrás.
3. Arrastra la hoja hacia arriba: pasa a pantalla completa. Elige una cuenta: se cierra y el chip la muestra.
4. Toca **Subcategoría**: media altura. Desliza la rejilla hacia arriba: la hoja crece a grande y luego desplaza.
5. Toca **Etiquetas**: media altura. Marca una y pulsa **Guardar**.
6. Cambia a **Transferencia** y toca las cuentas de origen y de destino: las dos a media altura.
7. Grupos → un grupo → **Nuevo gasto** → **Subcategoría** (y **Cuenta** si aparece): media altura.
8. Yala IA → dicta o escribe un gasto («gasté 20 en taxi»). En la card, toca la píldora de subcategoría o de cuenta:
   media altura. Toca «Detalles» → Cuenta: también media altura.
9. Ajustes de iOS → Accesibilidad → Tamaño de texto → el máximo con «Tamaños más grandes». Repite el paso 2: abre
   grande.
