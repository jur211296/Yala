Encargo Yala 2.2 · Nube y primera foto (cola final, punto 2). Busca las cards con `tablero listar --proyecto yala --version 2.2 --estado "lista para lanzar" --buscar nube` (y --buscar iCloud, --buscar foto) y resuelve juntas:
- «Activar la nube» se queda en ~60 % con muchos movimientos.
- Con 6 movimientos, activar la nube espera más de 5 min.
- Tras confirmar «Borrar y volver a iCloud» la pantalla no dice que está trabajando.
- Texto «no puedes volver a iCloud».
- L6-13 «Conectando con tu cuenta…».
- Reabre Yala solo en iCloud privado.
- Primera foto tras instalar.
Paso 0: el disco de la Mini está en 24 GB libres (umbral 32). Corre `limpiar-mac` antes de compilar.
Reglas: arranca sobre origin/2.2, no esperes el CI de ningún PR; git fetch + rebase sobre origin/2.2 solo justo antes de abrir el PR. Solo simulador, nunca los iPhone/iPad reales de Jürgen. No toques en ~/Yala los .ckdb de CloudKit, Yala.xcscheme ni encargos/pendientes/. No toques tmux salud--, sat-lab-- ni clinicas-dentales-bi--. Si hay diseño de UI sin decidir, deja propuestas y para para que Jürgen decida. Capturas antes/después, tests en verde, mueve las cards en el tablero (lo que necesite dispositivo real a in qa a jurgen con tanda), digest en español neutro.
Al terminar: /cerrar-total

## Paso 0 (Frank, 2026-10-21 21:40 Lima — de noche: lo técnico se decide aquí; el diseño de UI va en propuestas)

Medido antes de decidir:
- Telemetría de producción del TF19 (20-oct): entre el consentimiento (21:37:47) y el corte del servidor (21:47:16) el teléfono no emitió nada, ni un export de iCloud (el último 21:37:11, el siguiente 21:46:45). INFERIDO: el espejo de iCloud estaba ocupado bajando la zona (instalación nueva) y la migración esperaba su quiescencia, que solo deja rastro en el log local.
- Cada «Entrar con mi cuenta» de la flota subió 366 huérfanas (`cloudAdoptOrphanReconciled`, 5 de 5 desde el 14-oct): son los tipos de cambio que el arranque descarga antes del Welcome. Se suben antes de dejar pasar.
- El gateway cuenta la ráfaga por minuto (5 en free) en UNA lista por teléfono que también llenan sync, grupos y tipos de cambio: la primera foto tras instalar choca con un 429 `yala_quota_burst` que la app pinta como «No pude leerla».

Decisiones:
1. i9qh — texto propio para `.degradedNoMap` en los 16 idiomas; `.mapUnreadable` conserva el «ahora mismo». Seam `-uitest-adopted-cloud-storage` + XCUITest.
2. hov2 — (a) el adopt casa cada tipo de cambio local sin identidad con el del backend de la misma fecha y base (el de menor `syncID` si hay varios: no hay relaciones que apunten a un tipo de cambio) y no lo sube; (b) «Esto puede tardar unos minutos» solo aparece si la conexión pasa de unos segundos. La primera cuenta sin tipos de cambio en el backend sigue pagando su subida una vez.
3. vv0k — (a) gateway: la ráfaga se cuenta por categoría; (b) la app distingue el 429 de ráfaga y de cuota diaria con su texto; (c) tras comprar Pro se olvida el token de sesión para que el plan nuevo viaje; (d) canario del fallo de la foto con su tipo. El despliegue del Worker es de Jürgen.
4. ppxk — canario cuando la migración agota la espera a iCloud (para confirmar la inferencia en la flota). Lo que la persona ve mientras espera es diseño: propuestas.
5. igt9 + 27z3 + la espera de ppxk — propuestas en lienzo, sin construir. Cards a «espera decisión».
6. ypit — inventario de los 9 «reabre» con la propuesta por sitio; card a «espera decisión», sin implementar.
Asumido: cierre con PR en cola de auto-merge aunque queden cards de diseño esperando a Jürgen (las implementa otra sesión tras su elección).
