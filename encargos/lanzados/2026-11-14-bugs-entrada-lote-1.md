Yala
# Bugs de entrada y recuperación de 2.3, lote 1: conectar lento, recuperar desde iCloud y avisos que no cuadran
---
toca: Yala/App/Views/Onboarding/,Yala/App/Logic/,Yala/Resources/de.lproj/Localizable.strings,Yala/Resources/en-GB.lproj/Localizable.strings,Yala/Resources/en.lproj/Localizable.strings,Yala/Resources/es-419.lproj/Localizable.strings,Yala/Resources/es-AR.lproj/Localizable.strings,Yala/Resources/es-ES.lproj/Localizable.strings,Yala/Resources/es.lproj/Localizable.strings,Yala/Resources/fr.lproj/Localizable.strings,Yala/Resources/it.lproj/Localizable.strings,Yala/Resources/ja.lproj/Localizable.strings,Yala/Resources/nl.lproj/Localizable.strings,Yala/Resources/pl.lproj/Localizable.strings,Yala/Resources/pt-BR.lproj/Localizable.strings,Yala/Resources/pt-PT.lproj/Localizable.strings,Yala/Resources/pt.lproj/Localizable.strings,Yala/Resources/zh-Hans.lproj/Localizable.strings,YalaTests/BugsEntradaLote1/,tickets/done/2026-11-14-bugs-entrada-lote-1.md
depende: Yala/conciliar-prs-abiertos-2-3
esfuerzo: high
cierre: cierra-sola
---

Rama base: 2.3, después de la conciliación de PR abiertos (varios PR de nube e iCloud pueden haber cambiado estas zonas). Lote de bugs del backlog de 2.3 (Jürgen 14-nov: bugs priorizados, de 3 a 5 por sesión). Antes de empezar, confirma en el tablero y en los PR mergeados que cada uno siga vigente; si alguno ya quedó resuelto, muévelo a in qa con la evidencia.

Cards (por título en el tablero, versión 2.3):
1. «Conectar con la cuenta tarda 22–50 s sin progreso real (se queda en 0 % y salta a lista)» (alta): medir dónde se va el tiempo y dar progreso real o acortar la espera.
2. «Recuperar desde iCloud: un solo "Continuar", sin volver a preguntar "Traer mis datos" ni flecha atrás».
3. «Recuperar desde iCloud: el resumen dice 63 categorías y dos pantallas después 65».
4. «Pregunta: con datos en iCloud, entrar con Google o Apple no menciona esos datos».
5. «"Pega tu enlace de invitación": con el teclado abierto, el aviso de enlace no válido queda debajo de "Unirme al grupo"».

Wording: solo «En tu iCloud» y «En tu cuenta de Yala» (decisión 51; la única excepción es el botón «Entrar con iCloud privado» de la bienvenida). No toques CloudKit Production. Tests nuevos en YalaTests/BugsEntradaLote1/. Probar de punta a punta en el iPhone 14 por DeviceMCP; en la Max puedes usar un segundo simulador además del de otra sesión. Commits y PR sin firma de IA; cards a in qa al mergear.

Lo menor y reversible lo decides con la opción recomendada y lo anotas en «Decidido sin consultar». Cierre: si todo está completo y CI verde, /cerrar-total según el modo de sesión fijado al arrancar, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada».

## Paso 0 — decisiones

> Resueltas en semi sin nadie delante: las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · Card 1 (conectar lento): ¿se arregla a ciegas o se mide primero?** → Se mide primero en el iPhone 14 con una traza temporal de solo DEBUG por paso (claim, espera del import, Merkle, lectura por páginas, reintentos del efecto, terminal), y se recorta lo que la traza señale. La traza no se commitea.
Por qué: el hecha-cuándo pide cifras antes y después, y el código tiene al menos tres candidatos (lectura de la cuenta, reintentos aparcados, espera del import). Descartada: subir el tamaño de página sin medir.

**D2 · Card 2 (un solo «Continuar»): ¿cómo sabe Restaurar, tras reabrir, que ya se eligió «Traer mis datos»?** → Una marca persistida que escribe un único sitio (`handleExistingOption(.restoreICloud)`): encendida si viene de la puerta de iCloud privado, apagada si viene de cualquier otra entrada. Con la marca y datos encontrados, Restaurar pinta un solo «Continuar», sin «Empezar desde cero» y sin flecha atrás; los demás estados no cambian. Se borra al salir de Restaurar por cualquier camino.
Por qué: el origen hoy vive en un `@State` que muere con el relanzamiento. Descartada: un destino pendiente nuevo (duplicaría el portal del relanzamiento).

**D3 · Card 3 (63 vs 65): ¿qué cifra es la buena?** → La de la sonda (63): cuenta las categorías de fábrica repetidas una sola vez, igual que las fundirá el deduplicador. El conteo del teléfono pasa a contar con la misma clave (`SubcategoryDedupLogic.identityKey`).
Por qué: así las tres pantallas dan el mismo número por construcción. Descartada: explicar la diferencia en pantalla.

**D4 · Card 4 (pregunta de producto): ¿se cambia el flujo?** → No se toca código: es una decisión de Jürgen. Se le pregunta con recomendación A (no mencionar iCloud en el camino de cuenta, coherente con su frase del 13-nov en E11) y, si elige cambiar el flujo, se encola aparte como dice la card.

**D5 · Card 5 (aviso bajo «Unirme al grupo»): ¿dónde se ancla el scroll?** → Un ancla al final del bloque del campo (después del aviso), y el scroll se lleva también ahí cuando aparece el aviso.
Por qué: hoy el ancla es «Pegar» y el aviso va debajo. Descartada: mover el aviso encima del campo (cambia el diseño).

**D6 · Ficheros fuera del `toca:`** → Se tocan `Yala/Services/iCloudSyncService.swift` (conteo de categorías) y, si la medición lo pide, `Yala/Services/CloudSync/`. Comprobado que la otra sesión viva de Yala en esta Max (tandas rojas de UI) no los toca.
