// Catalogo de avatares.
//
// Son texturas que ya vienen dentro del export del juego, asi que no hace
// falta subir ficheros a ningun sitio: en users.avatar_url se guarda la ruta
// res:// y el cliente la carga con load().
//
// Se valida siempre contra esta lista: asi en la columna no puede acabar una
// ruta cualquiera que se invente el cliente.
//
// Si se anade uno nuevo, el fichero tiene que existir de verdad en
// game_godot/, o el TextureButton del perfil se quedara en blanco.

export const AVATARS = [
	{ id: "default", url: "res://scenes/1.png", name: "Chinchon" },
	{ id: "chinchon2", url: "res://scenes/1_2.png", name: "Chinchon 2" },
	{ id: "carta", url: "res://assets/carta.png", name: "Carta" },
	{ id: "frente", url: "res://assets/frentecarta.png", name: "Frente de carta" },
	{ id: "reverso", url: "res://assets/reverso.png", name: "Reverso" },
	{ id: "moneda", url: "res://assets/coin.png", name: "Moneda" },
	{ id: "duda", url: "res://assets/emote_question.png", name: "Duda" },
	{ id: "duda_circulo", url: "res://assets/emote_question_circle.png", name: "Duda (circulo)" },
];

export const AVATAR_BY_ID = new Map(AVATARS.map((a) => [a.id, a]));

// El que se ensena cuando avatar_url es NULL. Es el mismo que ya tenia puesto
// el TextureButton en profile.tscn, para que nada cambie de aspecto.
export const DEFAULT_AVATAR_URL = AVATARS[0].url;
