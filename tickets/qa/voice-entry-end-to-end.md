---
id: voice-entry-end-to-end
status: qa
priority: medium
area: "voz, registro, inbox, design-system"
created: 2026-10-04
updated: 2026-10-04
qa-status: needs-testing
source: tarjeta del tablero `tablero-mejorar-el-registro-por-voz-de-punta-a-p-u58k`; encargo `encargos/lanzados/2026-10-04-mejorar-el-registro-por-voz-de-punta-a-punta.md`
---

# Registro por voz de punta a punta: escucha y confirma en la misma hoja

## Qué le pasaba al usuario

Tocar Voz abría una pantalla con dos micros (uno decorativo y el botón), chips cortados («Gasto/Ingreso/Tra…») y
ejemplos que no cabían. Había que tocar otra vez para grabar, sin ver si el micro le oía. Al parar, una cuenta atrás
3-2-1 procesaba sola. Si salía bien, saltaba a otra hoja para revisar el borrador; con varios registros, a la Bandeja.
Los errores salían en inglés o en técnico («Network error: … AppAttestError 2»). Todo en rosa, ajeno al tema.

## Lo decidido (2026-10-04)

Tres propuestas en un lienzo (https://claude.ai/artifact/L34Tg6iimtk1xhsQG2vq57): A hoja que ya escucha, B pantalla
con guía, C escucha y confirma aquí. Jürgen eligió la **C**, con el **color del tema**.

- Tocar Voz abre una hoja a media altura que **ya escucha**: el panel del dictado de Yala IA (#350) — «Escuchando…»,
  la pista, el orbe que late con la voz, el tiempo y Cancelar / Listo. Cancelar descarta y cierra.
- Listo procesa sin cuenta atrás: el orbe gira y dice el paso («Transcribiendo…», «Entendiendo tu registro…»,
  «Preparando tu registro…»). Se puede cancelar.
- **Esto entendí**: lo dicho en cursiva y una fila por registro, como se verá en Registros, con las píldoras de la card
  de Yala IA (#348): lo que falta en ámbar, cuenta, fecha y etiquetas, con los mismos selectores de Nuevo registro.
  Tocar la fila abre el formulario completo de siempre. **Guardar** (o «Guardar 2») registra ahí mismo y las filas pasan
  a «Registrado»; Listo cierra. **Volver a grabar** borra lo entendido y escucha otra vez. Cerrar sin guardar deja los
  borradores en la Bandeja, y la hoja lo dice.
- Los fallos se cuentan en lenguaje de usuario y con salida: sin conexión (Usar imagen / Volver a grabar), micrófono
  (Abrir Configuración), no te escuché / no escuché un importe (Volver a grabar), y el genérico (Reintentar con el mismo
  audio / Volver a grabar).

## Fuera

- La hoja **no se agranda sola** con varios registros: agrandarla por código no movía la hoja en el simulador (iOS
  27.0), así que se desplaza por dentro y el usuario la estira. Con texto de accesibilidad abre grande.
- La memoria de comercios sigue sin filtrar por naturaleza en la voz: ticket aparte
  `merchant-memory-suggests-across-natures-in-three-more-places`.
- Las etiquetas que el modelo crea al leer una grabación no se borran al «Volver a grabar» (igual que al rechazar un
  borrador en la Bandeja).

## Guion de device-QA (iPhone físico)

1. En el Panel, toca el icono de onda (Voz), o el «+» flotante › Voz.
2. La hoja sube a media altura y **ya escucha**: «Escuchando…», la pista, el orbe con el color de tu tema, el tiempo
   corriendo con un punto rojo, Cancelar y Listo. La primera vez, iOS pide el micrófono antes.
3. Habla en voz normal y luego más fuerte: el halo crece con la voz y se encoge en silencio.
4. Toca **Cancelar**: la hoja se cierra sin aviso. Pon música en otra app y comprueba que vuelve a sonar.
5. Vuelve a abrir Voz, di «almuerzo 25 con la tarjeta» y toca **Listo**. El orbe gira y el título cambia de paso.
6. Sale «Esto entendí» con lo que dijiste y una fila: Almuerzo, su subcategoría y el importe, con las píldoras debajo.
   Si falta algo, va en ámbar y Guardar está apagado: toca la píldora, elige, y Guardar se enciende.
7. Toca **Guardar**: la fila pasa a «Registrado» y queda Listo. Ciérrala y comprueba el registro en Registros.
8. Repite diciendo dos gastos («taxi 12 y café 8»): salen dos filas y «Guardar 2» los registra a los dos.
9. Repite y, en lo entendido, toca **Volver a grabar**: vuelve a escuchar, y en la Bandeja no queda el borrador anterior.
10. Repite y cierra con la X sin guardar: el borrador está en la Bandeja.
11. Con modo avión, toca Voz: «Sin conexión», con «Usar imagen» y «Volver a grabar».
12. Con Ajustes › Accesibilidad › Movimiento › Reducir movimiento: el halo no se mueve y procesar enseña el spinner del
    sistema. Con el texto al máximo, la hoja abre grande y nada se corta.

## Evidencia

Capturas de antes y después en `~/Claude/worktrees/_capturas/2026-10-04-mejorar-el-registro-por-voz-de-punta-a-punta/`.
Tests: `YalaTests/VoiceEntryFlowLogicTests` (fallos y Guardar), `YalaUITests/Flows/VoiceEntryReviewUITests` (guardar,
lo que falta, varios, volver a grabar; seam `-uitest-voice-result`), `VoiceInputCurrencyExamplesUITests` (la hoja abre
escuchando).
