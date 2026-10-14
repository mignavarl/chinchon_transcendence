extends Node

# =============================================================================
# database.gd
#
# Autoload para lo que el juego necesita guardar o leer de la base de datos:
# la ficha corta del usuario, sus barajas, el gachapon y las partidas offline.
#
# Antes esto mandaba SQL en crudo a /db/query y el gateway la ejecutaba tal
# cual, sin token: cualquiera podia darse monedas o borrar tablas desde la
# consola del navegador. Ahora cada cosa es una ruta del db_gateway con su
# consulta escrita en el servidor, y el usuario sale del token, no de lo que
# se mande. Las peticiones pasan por ProfileApi.request(), asi que el token,
# el origen y los mensajes de error son los mismos que en el perfil.
#
# Todas se usan con await y devuelven el mismo diccionario que ProfileApi:
#   { ok = true,  status = 200, data = { ok, rows, rowCount } }
#   { ok = false, status = 409, data = {...}, error = "..." }
#
# Uso:
#   var res = await Database.get_me()
#   if res.ok:
#       print(res.data.rows[0].coins)
#   else:
#       push_warning(res.error)
#
# Las partidas ONLINE no se guardan desde aqui: el anfitrion manda
# "match_result" por el WebSocket y las guarda el servidor.
# =============================================================================


# GET /db/me: id, username, name, avatar_url, coins, deck_selected, wins,
# losses. Es la ficha corta; la de las estadisticas es ProfileApi.get_profile().
func get_me() -> Dictionary:
	return await ProfileApi.request(HTTPClient.METHOD_GET, "/db/me")


# GET /db/me/decks: las barajas que tiene, cada fila { id, name, rarity,
# obtained_at }. La inicial (rarity "first") viene siempre.
func get_my_decks() -> Dictionary:
	return await ProfileApi.request(HTTPClient.METHOD_GET, "/db/me/decks")


# POST /db/me/gacha: gasta una moneda y da una baraja que no tenga. El sorteo
# lo hace el servidor. Si va bien, data.rows[0] = { deck_id, name, rarity,
# coins } con las monedas que quedan. Si no, 409 con data.reason:
#   "no_coins"   -> no le quedan monedas
#   "all_owned"  -> ya las tiene todas (y no se le cobra)
func roll_gacha() -> Dictionary:
	# Cuerpo {} y no vacio: el gateway rechaza un JSON vacio con 400.
	return await ProfileApi.request(HTTPClient.METHOD_POST, "/db/me/gacha", {})


# POST /db/matches: guarda una partida offline. players es un Array con un
# diccionario por asiento, en orden:
#   { name = "Tú", kind = "human", score = 34, is_winner = true, is_me = true }
# kind es "human" o "ai". Tiene que haber exactamente un asiento con is_me: es
# el unico que se apunta a una cuenta, la del token.
# Si va bien, contesta 201 y data.rows[0].match_id es el id de la partida.
func save_offline_match(max_points: int, deck_id, players: Array) -> Dictionary:
	return await ProfileApi.request(HTTPClient.METHOD_POST, "/db/matches", {
		"max_points": max_points,
		"deck_id": deck_id,
		"players": players,
	})
