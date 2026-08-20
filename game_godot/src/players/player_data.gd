class_name PlayerData
extends Resource

enum Type { HUMAN, AI, NETWORK }

@export var id: int
@export var display_name: String
@export var type: Type
@export var hand_idx: int 
@export var score: int = 0
@export var is_local: bool = false 
@export var network_id: int = -1
@export var eliminated : bool = false
