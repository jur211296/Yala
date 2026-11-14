---
id: adopt-halfway-always-has-an-exit
status: done
priority: very-high
area: "cloud, welcome, adopt"
created: 2026-11-13
updated: 2026-11-13
card: tablero-cerrar-yala-en-pleno-conectando-con-tu-c-gd78
source: "lote de 4 cards del 13-nov (gd78, 285z, rfzc, jxbp), medidas en el iPhone 14"
---

# Entrar con la cuenta a medias: siempre hay salida, se retoma o se deshace, y la barra avanza en pasos reales

Cuatro bugs muy altos de la entrada a una cuenta que ya existe, medidos el 13-nov en el iPhone 14 (Yala Dev, staging,
cuenta con grupos):

1. Cerrar Yala en pleno «Conectando con tu cuenta» la deja a medias en iCloud y sin salida (card gd78).
2. Tras un traspaso a medias, entrar con Google se queda para siempre en «Ahora mismo no podemos preparar este
   dispositivo» (card 285z).
3. Tras «reabre Yala», la cuenta no baja nada y «Descargando tus datos…» no termina (card rfzc).
4. «Conectando con tu cuenta» avanza a saltos: 0 → 60 → lista (card jxbp).

## Hecho cuando

- Cerrar Yala en cualquier punto del traspaso y reabrirla lo retoma o lo deshace, sin subir datos de la cuenta a iCloud.
- Un traspaso a medias de otro intento ya no bloquea la entrada con Google.
- Después de reabrir, la cuenta baja sus registros y grupos, o la pantalla dice qué la frena y qué hacer.
- La persona siempre tiene una salida que funciona: seguir, cancelar o cerrar sesión. Ningún dato de la cuenta se pierde.
- La barra de «Conectando» avanza en pasos pequeños ligados a trabajo real.
- Probado de punta a punta en el iPhone 14, matando la app en cada fase.

## Medido antes de tocar nada (13-nov, 13:50 Lima)

- **Staging conserva la cuenta entera**: 8 movimientos vivos, 6 cuentas, 13 categorías; `profiles` sin traspaso en
  curso (`migration_in_progress = false`). Lo que no bajaba al teléfono no se había perdido.
- **El estado a medias de la card 2 no vive fuera del teléfono**: vive en el journal del App Group, que en el iPhone de
  pruebas sobrevivía a desinstalar Yala Dev porque Yala de producción declara ese mismo App Group.

Decisiones: Paso 0 del encargo `encargos/lanzados/2026-11-13-adopt-a-medias-siempre-con-salida.md`.

## Resolución (13-nov)

- **Cerrar a mitad** (gd78): una marca durable (`WelcomeAdoptInFlight`) mantiene el montaje neutro hasta que el traspaso
  escriba su par o se deshaga, y el arranque vuelve a «Conectando con tu cuenta», que lo retoma. Con la marca puesta el
  arranque no siembra avisos (eran los 7 que paraban el traspaso retomado por linaje) ni ofrece «reinicia para iCloud».
- **Salida siempre**: «Cancelar la activación» se toca con el efecto en vuelo; cancelar devuelve a la bienvenida limpia.
- **Paso a medias de otro intento** (285z, opción A de Jürgen): la puerta de la bienvenida ofrece cancelarlo y sigue sola.
- **No baja nada** (rfzc): era el espejo montado de gd78. Con el arreglo la cuenta baja (Panel y Grupos medidos), y
  Ajustes dice «Descargando tus datos…» hasta el primer pull en vez de «Todo sincronizado».
- **Barra a saltos** (jxbp): pasos reales del efecto (`AdoptEffectProgress`) y la pantalla refresca mientras conduce.

Medido en el iPhone 14 (Yala Dev, staging, cuenta con grupos): matar a mitad de la lectura, reabrir → «Conectando» al
31 %, cero eventos de iCloud, «¡Tu cuenta está lista!», Panel con S/ 1.353 y los dos grupos. Cancelar con el traspaso
parado → bienvenida, onboarding sin marcar y neutro repuesto. Evidencia en
`~/Claude/entregas/2026-11-13-adopt-a-medias-siempre-con-salida/evidencia/`.

## Device-QA pendiente (opcional): la puerta con un paso a medias de otro intento

Solo se monta con Yala de producción y Yala Dev en el iPhone 14 (comparten App Group):
1. Con Yala de producción instalada, instala Yala Dev de esta rama, entra con Google y mata Yala Dev en «Conectando».
2. Desinstala SOLO Yala Dev y vuelve a instalarla (el journal sobrevive en el App Group).
3. «Entrar con Google» → si sale «Ahora mismo no podemos preparar este dispositivo», toca «Cancelar la activación» y
   confirma.
4. Esperado: la puerta vuelve a comprobar sola y la entrada sigue; nada de la cuenta se pierde.
