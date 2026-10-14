class_name GameConfig
extends Resource

@export var players: Array[PlayerData] = []
@export var deck_name: String = "española"
# La partida se acaba cuando solo queda un jugador por debajo de este
# limite: el que llega a max_points queda eliminado.
@export var max_points: int = 100
@export var is_online: bool = false
@export var is_host:bool =false

# El lobby construye esto y lo pasa al GameManager
# Ejemplo de uso en el lobby:
#
#   var cfg = GameConfig.new()
#   var human = PlayerData.new()
#   human.id = 0
#   human.display_name = "Tú"
#   human.type = PlayerData.Type.HUMAN
#   human.hand_idx = 0
#   human.is_local = true
#   cfg.players.append(human)
#   ...
#   get_node("GameManager").setup(cfg)
