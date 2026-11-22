---
id: 2026-11-21-captura-foto-comercio-atajo-banco-parte-2
status: done
priority: medium
area: "captura, foto, atajo-banco, pagos-recurrentes, gateway"
created: 2026-11-21
updated: 2026-11-22
source: "encargo 2026-11-22 · decisiones 75 (t1678u) y 66 (t1661u), reconfirmadas el 21-nov 08:39"
---

# Captura por foto: la IA reconoce el comercio, y atajo del banco y suscripciones parte 2 (B2, B3 y S2)

Definición del atajo y las suscripciones: `docs/ux/atajo-banco-y-suscripciones/` (lotes B2, B3 y S2). B0 y B1 en
`tickets/done/2026-11-14-atajo-banco-b0-b1.md`; S1 en `tickets/done/2026-11-14-pagos-recurrentes-s1.md`. Las
decisiones están en el Paso 0 del encargo (`encargos/lanzados/2026-11-22-captura-foto-comercio-atajo-banco-parte-2.md`)
y en el PR.

## Qué se construyó

- **Foto**: la IA devuelve `merchantKind` (lista cerrada de 34 tipos, `VisionMerchantKind`) y el comercio por su nombre
  comercial; el teléfono lo traduce a una subcategoría del usuario (`MerchantKindSubcategory`: nombre de la semilla en
  el idioma de la app, y si no, su icono). Orden: memoria de comercios › IA › banco de 666 comercios. No viaja nada
  nuevo. El aviso del banco usa el banco de comercios. Esquema del gateway (`PHOTO_SCHEMA`) con el campo; sin desplegar.
- **B2**: Ajustes › «Avisos del banco» (`BankNoticesView`, `BankNoticeBankView`): bancos activos con su estado, «¿De qué
  banco?», estado (esperando, funcionando, silencio, pausado), contadores del mes, cuenta por defecto, pausa, guía de
  cuatro pasos, aviso de ejemplo y cómo quitarlo. Estado en el App Group (`BankNoticeActivityStore`), purgado en las
  fronteras de cuenta y en `-uitest-reset`. Atajos por enlace: hueco preparado (`BankNoticeShortcutLinks`), vacío.
- **B3**: parámetro «Origen» (Notificación / Correo) en la acción; `BankNoticeMail` recorta el pie y lee «Monto:» y
  «Comercio:» (también en dos líneas).
- **S2**: `RecurringPaymentChanges` + `RecurringChangesCards` en Pagos planificados: «X subió/bajó a S/ …» (Actualizar /
  Dejar así) y «¿Dejaste de pagar X?» (Pausar el pago / Sigue activo). Card «Dos suscripciones de la misma marca se
  anulan»: dos montos intercalados de una marca son dos series.

## Pruebas

`YalaTests/CapturaAtajoParte2/` (4 suites), `YalaUITests/CapturaAtajoParte2/` (2 casos, fixture
`-uitest-seed-s2-changes`), `gateway/test/ai.photo-comercio.test.ts`. Suite unitaria entera: 15.661 en verde.

## Device-QA (Jürgen, cuando pueda)

1. En tu iPhone, Ajustes de Yala › «Avisos del banco» › BCP: sigue la guía de cuatro pasos y haz una compra pequeña.
   Debe pasar a «Funcionando» y el gasto llegar a la Bandeja como «Aviso de BCP».
2. Si recibes las alertas del BCP en Mail, repite con el disparador «Correo electrónico» y «Origen: Correo».
3. Con el gateway desplegado, una foto de un voucher (Starbucks, Wong): debe proponer el comercio con su categoría.
