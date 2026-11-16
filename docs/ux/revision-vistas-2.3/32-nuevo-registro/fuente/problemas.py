"""Los siete problemas, en orden de prioridad."""
from p_teclado import TECLADO
from p_categoria import CATEGORIA
from p_textogrande import TEXTOGRANDE, AXCSS
from p_moneda import MONEDA
from p_voz import VOZ
from p_transferencia import TRANSFERENCIA
from p_favoritos import FAVORITOS

PROBLEMAS = [TECLADO, CATEGORIA, TEXTOGRANDE, MONEDA, VOZ, TRANSFERENCIA, FAVORITOS]
EXTRA_PROBLEMAS_CSS = AXCSS
