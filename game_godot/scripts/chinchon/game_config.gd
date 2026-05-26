class_name GameConfig
extends Resource

@export var players: Array[PlayerData] = []
@export var deck_name: String = "española"
@export var max_rounds: int = 1

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
