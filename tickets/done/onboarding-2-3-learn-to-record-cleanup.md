---
id: onboarding-2-3-learn-to-record-cleanup
status: done
priority: high
area: onboarding
created: 2026-11-12
updated: 2026-11-12
source: tablero-bienvenida-2-3-paso-2-borrar-pruebas-pan-69nw (docs/onboarding-2-3/SPEC.md, Y23-10)
qa-status: passed
qa-date: 2026-11-12
qa-notes: simulador iPhone 17 Pro iOS 27.2 - hoja «¿Borramos los de prueba?», aviso, guía de la Bandeja, Panel lleno y mazo en el paso 3 recorridos por XCUITest con capturas
---
# Bienvenida 2.3 · Paso 2 · Cierre: borrar registros de prueba, Panel lleno y Bandeja (Y23-10)

Al terminar el tutorial sube una hoja a media altura, «¿Borramos los de prueba?», con los registros del tutorial todos
marcados; se desmarcan los que se conservan. «Borrar N registros» (rojo) / «Conservarlos todos»; aviso «Borramos N
registros de prueba». Borrar devuelve el saldo y quita los registros (el borrado de práctica de siempre); conservar los
deja en «Últimos registros».

Al cerrarla el Panel se llena: vuelven Nuevo registro, Voz, Foto y Yala IA (con su candado Free), y debajo de la cuenta
solo queda «Últimos registros» (las gráficas se suman después desde «Configurar Panel», guía de «días después»). Con
algo anotado, la pestaña Más lleva un punto de «algo nuevo» hasta abrirla. Guía de foco sobre la Bandeja: «Lo que Yala
anota solo» con «Entendido». El mazo pasa al paso 3.

Fuera de alcance (ficha): widgets de gráficas en el Panel recién creado (Y23-15).

Pruebas: `YalaTests/Bienvenida23PasosLimpiezaTests`, `YalaTests/Bienvenida23PasosTests` (PanelAfterLearningToRecordTests)
y `YalaUITests/Flows/Bienvenida23PasosUITests#test_step2_manualWithGuide_thenCleanupAndInboxGuide`.
