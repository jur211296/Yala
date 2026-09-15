---
name: indice-trabajo-anterior
description: Índice de las memorias de proyecto de los PR #62 a #154 (4-14 sep): qué cerró cada uno y qué dejó abierto. Salió de MEMORY.md el 15-sep para que el índice cupiera en su límite; los ficheros siguen enteros.
metadata:
  type: project
---

# Trabajo anterior al 14-sep

Cada línea apunta a su memoria completa. Lo que sigue abierto vive en su ticket (`tickets/`), que es la fuente;
aquí queda el porqué y el contexto de cada entrega.

- [Un 403 de infra ya no es un veredicto de cuenta](project_403_infra_no_es_veredicto_de_cuenta.md) — PR #154.
- [El eje 1 ya tiene fuente propia](project_eje1_marca_sesion_privada.md) — PR #150; eran 9 constructores y no 6; el barrido de M1 es el PR-B y el device-QA NO es simulable.
- [El paso 12 estaba roto: el eje 1 no tenía fuente](project_paso12_dominio_preferencias.md) — PR #149 entrega el tercio mecánico; 4 decisiones del 12-sep.
- [El simulador se pide por turno, y la segunda espera](project_cola_del_simulador.md) — PR #147; la review cazó DOS llaves maestras mías.
- [La cuenta de grupos ya se suelta con la nube en pausa](project_killswitch_puerta_grupos.md) — PR #146; el predicado del ticket era el equivocado; device-QA SÍ simulable.
- [Los 7 XCUITest del Welcome estaban SANOS](project_siete_xcuitest_welcome_falso_positivo.md) — `discarded` con 3 mediciones (PR #145).
- [«Desasociar» ya no finge que soltó la cuenta](project_desasociar_no_finge_exito.md) — PR #144; la review fue en DOS vueltas y la 2.ª cazó 2 ALTAS de mi rediseño.
- [Aceptar una invitación en un teléfono prestado ya no cruza datos](project_puerta_neutro_del_invitado.md) — PR #143.
- [La cuenta de grupos ya se ve y se suelta en Ajustes](project_asociacion_cuenta_de_grupos.md) — paso 10, PR #140.
- [«Vengo por un grupo» ya no bloquea al dueño](project_puerta_grupos_vuelve_al_neutro.md) — mitad 2, PR #139; el relanzamiento ya estaba decidido en la fila B.
- [Paso 9: un verbo por sesión](project_paso9_un_verbo_por_sesion.md) — PR #138; M15 sobrevive y es hallazgo; el único rojo de XCUITest lo zanjó el árbol base.
- [«Activar Yala completo» ya pregunta privado / nube](project_activacion_pregunta_donde_viven.md) — paso 8, PR #137; la review cazó 14 MÍOS.
- [La card «Grupos» del propósito ya no existe](project_paso7_card_grupos_retirada.md) — paso 7, PR #136; la puerta B se fue entera.
- [El faro solo encamina: «Crear otra cuenta» y mismatch con dos salidas](project_faro_solo_encamina.md) — paso 6, PR #135; el huérfano se limpia con PRUEBA (Apple+Apple).
- [Una sesión solo-grupos ya no baja el iCloud del teléfono](project_neutro_durable_solo_grupos.md) — PR #134; la review cazó 12 defectos MÍOS, dos graves.
- [«Primera vez → privado» ya valida iCloud antes de reiniciar](project_puerta_icloud_rama_privada.md) — PR #133; la review cazó 19 defectos MÍOS y el peor dejaba el bug vivo.
- [«Volver a iCloud» ya está abierta a quien nació en la nube](project_reversa_abierta_a_born_cloud.md) — PR #132; la review cazó DOS defectos graves MÍOS.
- [Todo sign-in en la nube ya descubre el tipo de cuenta y rutea](project_bloque_identidad_nube_rutea.md) — bloque [I].
- [La elección nube ya no se apaga sola en un deploy](project_percent_eleccion_nube_alineado_con_prod.md) — PR #128 desplegado y verificado.
- [Cambiar la divisa de una cuenta ya no deja su histórico atrás](project_divisa_de_una_cuenta_con_historico.md) — PR #118; la review cazó SEIS defectos del ARREGLO.
- [La familia FX, recorrida entera en simulador](project_seam_cuenta_divisa_ausente.md) — PR #114 y #115: 5 PASS, 2 parciales por red/seam; deja 4 tickets.
- [El gasto de grupo ya lleva la incertidumbre de sus patas](project_marca_aproximado_gasto_de_grupo.md) — PR #113 cierra la familia del «≈»; device-QA NO simulable.
- [El cambio masivo de cuenta ya no arrastra la divisa vieja](project_bulk_cuenta_divisa_vieja.md) — PR #110; el método se BORRÓ (cero llamadores en toda la historia).
- [Las filas que el chat selló con tasa falsa ya se curan](project_barrido_tasa_sellada_chat.md) — PR #108; el plan obvio (reabrir) DAÑABA; deja 3 tickets.
- [El chat ya guarda en la divisa de la cuenta](project_divisa_del_chat_vs_cuenta.md) — PR #107; el hueco grande que queda es editar la divisa de una CUENTA (**high**).
- [El borrador del chat ya no se contradice a sí mismo](project_signo_vs_subcategoria_chat.md) — PR #106; el ticket decía 1 sitio y eran 6; deja 2 tickets, uno **high**.
- [El corpus viejo del chat ya se cura solo](project_barrido_signo_chat.md) — PR #103, acotado para no tocar lo importado por CSV; falta device-QA.
- [El chat ya guarda la tasa que usó](project_chat_tasa_del_borrador.md) — PR #99; deja 4 tickets, uno **high**: el chat pierde el signo y el gasto SUMA al saldo.
- [La cola del reparador de tasas ya tiene salida](project_cola_reparador_tasas.md) — PR #98; dos de los tres daños del ticket eran FALSOS (medido); deja 3 tickets.
- [Las escrituras a mano ya no sellan una tasa aproximada](project_fx_escrituras_a_mano.md) — PR #94; eran 14 y no 10, y el AC nº2 pedía algo que no procede.
- [La ganancia cambiaria ya tiene número](project_fx_pnl_card.md) — PR #92; device-QA NO simulable (ningún seed es multi-divisa); el FIFO no se simplifica.
- [El tope de gasto del grupo ya avisa](project_presupuesto_de_grupo.md) — PR #91 y g14_01 en prod; quedan device-QA, tres migraciones de staging y el Worker.
- [El recordatorio de deuda ya avisa al deudor](project_recordatorio_liquidacion.md) — PR #89; falta device-QA y una decisión; NO se respeta `simplifyDebts` a propósito.
- [El Panel ya suma las cuentas filtradas](project_panel_conjunto_de_cuentas.md) — PR #87; quedan tres preexistentes con ticket propio.
- [Salir del grupo: cerrado en código, abierto en decisión](project_salir_del_grupo_espera_decision.md) — PR #75; falta device-QA y qué se le ofrece al dueño con deuda.
- [El archivado ya cierra la puerta](project_archivado_no_acepta_entradas.md) — g13_05 en prod; falta device-QA, y staging arrastra ya DOS migraciones por falta de credencial.
- [La re-entrada: cerrada en código, abierta en decisión](project_reentrada_piezas_2_y_3.md) — piezas 2 y 3 hechas (PR #68).
- [La identidad del recién llegado a un grupo](project_identidad_del_joiner_en_grupos.md) — cerrada en código el 4 y 5-sep.
- [Web: lo que Jürgen decidió, y lo que no](project_web_pr62_espera_a_jurgen.md) — PR #62 mergeado el 4-sep; siguen abiertas dos suyas: legal de Grupos y autoalojar fuentes.
- [El cron de Actions estuvo muerto y revivió](project_cron_de_actions_no_dispara.md) — disparó el 8-sep con 4h35 de retraso.
- [Hipótesis de la Lista Negra, re-comprobadas](project_hipotesis_lista_negra_recomprobadas.md) — el runner de XCUITest; el CI y sus pasos ADVISORY.
