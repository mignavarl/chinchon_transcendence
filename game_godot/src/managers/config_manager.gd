extends Node

# Rutas y constantes
const CONFIG_FILE = "user://config.json"
const STORAGE_KEY = "godot_game_config"

# Datos de configuración
var config_data: Dictionary = {}

# Señales para cambios de configuración
signal config_changed(section: String, key: String, value)
signal config_loaded

func _ready() -> void:
	# Cargar configuración
	load_config()
	
	print("ConfigManager inicializado correctamente")

# =============================================================================
# CARGA Y GUARDADO
# =============================================================================

func load_config() -> void:
	"""Carga la configuración desde archivo (funciona en Web y Desktop)"""
	load_from_file()
	
	# Si no hay datos, usar valores por defecto
	if config_data.is_empty():
		reset_defaults()
	
	config_loaded.emit()

func load_from_file() -> void:
	"""Carga desde archivo JSON (funciona en ambas plataformas)"""
	if FileAccess.file_exists(CONFIG_FILE):
		var file = FileAccess.open(CONFIG_FILE, FileAccess.READ)
		if file:
			var json_str = file.get_as_text()
			config_data = JSON.parse_string(json_str)
			if config_data == null:
				config_data = {}
				print("Advertencia: El archivo de configuración está corrupto")
		else:
			print("Error: No se pudo abrir el archivo de configuración")
	else:
		print("Información: Archivo de configuración no encontrado (se creará al guardar)")

func save_config() -> void:
	"""Guarda la configuración a archivo (funciona en ambas plataformas)"""
	var json_str = JSON.stringify(config_data)
	save_to_file(json_str)

func save_to_file(json_str: String) -> void:
	"""Guarda a archivo JSON (funciona en Web y Desktop)"""
	var file = FileAccess.open(CONFIG_FILE, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
	else:
		print("Error: No se pudo abrir el archivo de configuración para guardar")

# =============================================================================
# VALORES POR DEFECTO
# =============================================================================

func reset_defaults() -> void:
	"""Establece los valores por defecto"""
	config_data = {
		"Game": {
			"language": "es",  # "es" o "en"
		},
		"Gameplay": {
			"selected_bots": 0,  # Número de bots seleccionados
		}
	}
	save_config()

# =============================================================================
# GETTERS Y SETTERS
# =============================================================================

func set_value(section: String, key: String, value) -> void:
	"""Establece un valor y emite señal"""
	if not config_data.has(section):
		config_data[section] = {}
	
	config_data[section][key] = value
	config_changed.emit(section, key, value)

func get_value(section: String, key: String, default = null):
	"""Obtiene un valor con valor por defecto opcional"""
	if config_data.has(section) and config_data[section].has(key):
		return config_data[section][key]
	return default

func has_value(section: String, key: String) -> bool:
	"""Verifica si existe una clave"""
	return config_data.has(section) and config_data[section].has(key)

# =============================================================================
# MÉTODOS ESPECÍFICOS PARA TU JUEGO
# =============================================================================

# --- IDIOMA ---

func set_language(language_code: String) -> void:
	"""Establece el idioma disponible en el catálogo de traducciones."""
	if language_code in ["es", "ca", "eu"]:
		set_value("Game", "language", language_code)
		save_config()
	else:
		print("Error: Idioma no válido. Use 'es', 'ca' o 'eu'")

func get_language() -> String:
	"""Obtiene el idioma actual"""
	return get_value("Game", "language", "es")

# --- BOTS SELECCIONADOS ---

func set_selected_bots(count: int) -> void:
	"""Establece la cantidad de bots seleccionados"""
	if count >= 0:
		set_value("Gameplay", "selected_bots", count)
		save_config()
	else:
		print("Error: El número de bots no puede ser negativo")

func get_selected_bots() -> int:
	"""Obtiene la cantidad de bots seleccionados"""
	return get_value("Gameplay", "selected_bots", 0)

# =============================================================================
# UTILIDADES
# =============================================================================

func print_config() -> void:
	"""Imprime toda la configuración (útil para debug)"""
	print("\n=== Configuración Actual ===")
	print(JSON.stringify(config_data, "\t"))
	print("===========================\n")

func export_config() -> String:
	"""Exporta la configuración como JSON string"""
	return JSON.stringify(config_data)

func import_config(json_str: String) -> bool:
	"""Importa configuración desde un JSON string"""
	var imported = JSON.parse_string(json_str)
	if imported is Dictionary:
		config_data = imported
		save_config()
		config_loaded.emit()
		return true
	return false
