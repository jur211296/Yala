# Mejoras necesarias 2.3 · Formulario: monedas claras y salida manual disponible
card: tablero-mejoras-necesarias-2-3-formulario-moneda-3lj2
toca: Yala/Views/Transactions/,Yala/Views/Voice/,Yala/Views/Image/
esfuerzo: high

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Encargo y criterio de terminado
Implementar tres correcciones mínimas de claridad objetiva del PR848, sin rediseñar formulario:
1. M1: al elegir cuenta que cambia moneda, mostrar inequívocamente en qué moneda se interpretará el importe ya escrito. NO convertir automáticamente, reordenar cuentas ni cambiar semántica de los datos; conservar comportamiento actual.
2. T1 mínimo: identificar cada importe de transferencia por cuenta/moneda de origen y destino, también VoiceOver/texto grande; NO mover cuentas ni añadir «cuánto llegó» o reglas nuevas.
3. V3: cuando la pantalla de voz/foto/Pro promete registrar a mano, ofrecer salida manual real al formulario (sin pérdida del estado ya existente y sin esquivar límites Pro). No implementar precarga IA ambigua V1 ni nuevas llamadas al gateway; si no hay forma segura de conservar estado, documentar ese caso sin inventar mapping.
Tests y capturas antes/después, teclado, texto máximo e iPad. No G1 barra de teclado, C2 categorías frecuentes, Z2 botón que dice requisitos, F1/F2 favoritos nuevos ni M4 orden de cuentas. Ningún cherry-pick masivo de 2.2: arreglos allí aprobados y en QA se evalúan por separado antes de duplicar. gate de proyecto.
FIN

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D0 · Base de la rama** → `origin/2.3` (la rama nació de 2.2, con 63 commits de 2.2 que 2.3 no tiene; se recolocó sobre 2.3 antes del primer cambio).
Por qué: el encargo dice «Base: origin/2.3» y «ningún cherry-pick masivo de 2.2». Alternativa descartada: quedarse en 2.2 (traería 63 commits ajenos al PR).

**D1 · M1: cuándo sale el aviso** → solo cuando cambia la moneda del importe (al elegir otra cuenta) y el número ya estaba escrito y sigue igual. Línea bajo el importe: «Ahora en dólares (USD), la moneda de Ahorros USD», anunciada a VoiceOver. Se queda mientras la moneda siga siendo esa y haya importe.
Por qué: es el caso del informe (el número se queda y el símbolo cambia en silencio); con el importe escrito después, o llegado con un favorito en el mismo cambio, no hubo cambio que avisar. Alternativa descartada: una línea fija siempre que la moneda no sea la principal (avisa sin que nada haya cambiado, y no cubre volver de dólares a soles).

**D2 · M1: cómo se nombra la moneda** → plural corto («dólares») + código ISO entre paréntesis; si la divisa no tiene nombre en la app, solo el código.
Por qué: «pesos» no distingue MXN de COP o ARS; el código lo hace inequívoco. No se convierte nada ni cambia la semántica del dato.

**D3 · T1: forma mínima** → un rótulo encima de cada importe («Sale de Cuenta Principal» / «Llega a Ahorros USD») y la etiqueta de VoiceOver de cada campo con cuenta y moneda. Los chips de cuenta no se mueven.
Por qué: el encargo pide T1 mínimo, sin mover cuentas. Alternativa descartada: fundir los chips con los importes (es la T1 completa del informe y mueve piezas).

**D4 · V3: dónde sale el botón** → en el muro de Pro de voz y foto (contexto «función Pro», el que dice «Apuntar a mano sigue gratis») cuando quien lo presenta sabe abrir el formulario: Panel, Registros, Estadísticas, la hoja de voz, la hoja de foto y el reparto por recibo de Grupos (ahí «a mano» es volver al formulario del gasto de grupo, que sigue con lo escrito). Reusa el texto existente «Apuntarlo a mano».
Por qué: el texto lo promete en todos esos sitios. El formulario se abre al terminar de cerrarse el muro (sin dos hojas a la vez). Alternativa descartada: botón en todo muro aunque nadie sepa abrir el formulario (botón muerto).

**D5 · V3: estado** → el formulario se abre vacío, como el «Apuntarlo a mano» que ya existe. No hay estado que conservar en el muro (se toca antes de dictar o fotografiar). No se implementa V1 (precarga de lo entendido) ni llamadas nuevas al gateway.
Por qué: fuera de alcance por encargo; no hay mapping que inventar.

**D6 · Pruebas** → XCUITest nuevo con capturas adjuntas (antes = mismo test sobre la base, en rojo; después = verde), con teclado, texto AX máximo y en iPad Pro 13; tests unitarios de la lógica del aviso; source-scan de que cada muro de voz/foto con salida conocida la cablea.

**D7 · T1: el sitio de los rótulos** → el aire entre los dos importes baja de 16 a 4 pt para que los rótulos no alarguen el bloque.
Por qué: con los rótulos y el aire de antes, en un iPhone 17 Pro la transferencia dejaba de caber y la fila de cuentas quedaba bajo «Para guardar, falta…» (medido en la captura). Con el ajuste, la fila queda donde estaba. Alternativa descartada: rótulos más pequeños (caption) — se leen peor y el informe pide que se lean.

**D8 · V3: forma de la API** → sobrecarga aparte de `proUpgradeSheet` con la salida manual obligatoria, en vez de un segundo cierre opcional.
Por qué: con dos cierres opcionales, el `{ … }` final de los demás llamadores (cuentas, presupuestos, temas…) casaba por la regla vieja de Swift, avisada como obsoleta: el día que cambie se iría a «Apuntarlo a mano».
