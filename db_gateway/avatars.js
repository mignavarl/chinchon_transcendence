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
	{ id: "Avatar00", url: "res://assets/avatar/avatar00.png", name: "Carol" },
	{ id: "Avatar01", url: "res://assets/avatar/avatar01.png", name: "Mistria" },
	{ id: "Avatar02", url: "res://assets/avatar/avatar02.png", name: "Stardew" },
	{ id: "Avatar03", url: "res://assets/avatar/avatar03.png", name: "Concha" },
	{ id: "Avatar04", url: "res://assets/avatar/avatar04.png", name: "Vicenta" },
	{ id: "Avatar05", url: "res://assets/avatar/avatar05.png", name: "Marisa" },
	{ id: "Avatar06", url: "res://assets/avatar/avatar06.png", name: "Valentin" },
];

export const AVATAR_BY_ID = new Map(AVATARS.map((a) => [a.id, a]));

// El que se ensena cuando avatar_url es NULL. Es el mismo que ya tenia puesto
// el TextureButton en profile.tscn, para que nada cambie de aspecto.
export const DEFAULT_AVATAR_URL = AVATARS[0].url;
