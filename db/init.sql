-- Esquema de la base de datos del Chinchon.
--
-- OJO: Postgres solo ejecuta este fichero la PRIMERA vez, cuando el volumen
-- pg_data esta vacio. Si ya habias levantado la base de datos antes, hay que
-- borrar el volumen para que se vuelva a aplicar:  make clean && make


-- ==========================================================================
-- BARAJAS
-- ==========================================================================

-- Catalogo de barajas. El id coincide con la carpeta de assets/cards/<id>/,
-- que es lo que el juego usa para construir la ruta de las texturas.
-- Es el mismo listado que scripts/rarity__database.gd.
CREATE TABLE IF NOT EXISTS decks (
    id     TEXT PRIMARY KEY,
    name   TEXT NOT NULL,
    rarity TEXT NOT NULL
           CHECK (rarity IN ('first', 'common', 'uncommon', 'rare', 'legendary'))
);

INSERT INTO decks (id, name, rarity) VALUES
    ('española',    'ESPAÑOLA',    'first'),
    ('pixel',       'PIXEL',       'common'),
    ('deck_42',     'DECK_42',     'common'),
    ('luigi',       'LUIGI',       'uncommon'),
    ('pop_stars',   'POP STARS',   'uncommon'),
    ('bichos',      'BICHOS',      'uncommon'),
    ('luigiHD',     'LUIGI_HD',    'rare'),
    ('pajaros',     'PAJAROS',     'rare'),
    ('dark_indie',  'DARK_INDIE',  'rare'),
    ('light_indie', 'LIGHT_INDIE', 'rare'),
    ('cutre',       'CUTRE',       'legendary')
ON CONFLICT (id) DO NOTHING;


-- ==========================================================================
-- USUARIOS
-- ==========================================================================

CREATE TABLE IF NOT EXISTS users (
    id            SERIAL PRIMARY KEY,
    username      TEXT NOT NULL UNIQUE,          -- identificador de login
    name          TEXT NOT NULL,                 -- nombre visible en la mesa
    email         TEXT UNIQUE,
    password_hash TEXT,                          -- NUNCA la password en claro
    avatar_url    TEXT,

    coins         INTEGER NOT NULL DEFAULT 0,    -- monedas para el gachapon
    deck_selected TEXT NOT NULL DEFAULT 'española'
                  REFERENCES decks(id) ON DELETE SET DEFAULT,

    wins          INTEGER NOT NULL DEFAULT 0,
    losses        INTEGER NOT NULL DEFAULT 0,

    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen     TIMESTAMPTZ
);

-- Barajas que tiene cada usuario. Sustituye a los diccionarios en memoria
-- dic_common / dic_uncommon / dic_rare / dic_legen: si hay fila, la tiene.
CREATE TABLE IF NOT EXISTS user_decks (
    user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    deck_id     TEXT    NOT NULL REFERENCES decks(id) ON DELETE CASCADE,
    obtained_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, deck_id)
);


-- ==========================================================================
-- PARTIDAS
-- ==========================================================================

-- Datos de la partida en si. Quien jugo y cuanto puntuo va en match_players,
-- una fila por asiento.
CREATE TABLE IF NOT EXISTS matches (
    id         SERIAL PRIMARY KEY,

    is_online  BOOLEAN NOT NULL DEFAULT FALSE,
    -- Limite de puntos con el que se jugo: al llegar a el un jugador queda
    -- eliminado, y la partida acaba cuando solo queda uno por debajo.
    max_points INTEGER NOT NULL DEFAULT 100,
    deck_id    TEXT REFERENCES decks(id) ON DELETE SET NULL,

    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at   TIMESTAMPTZ
);

-- Un asiento de una partida. Se corresponde con PlayerData del juego:
-- seat es hand_idx + 1, kind es PlayerData.Type y score el acumulado final.
--
-- user_id es NULL si el asiento lo ocupa una IA o un invitado sin cuenta;
-- name guarda siempre el nombre que se mostro en la mesa, asi el historial
-- se lee aunque no haya usuario detras.
--
-- En el Chinchon gana el que MENOS puntos suma, y puede haber empate, por eso
-- el ganador se marca aqui con is_winner en vez de una columna en matches.
CREATE TABLE IF NOT EXISTS match_players (
    match_id  INTEGER  NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    seat      SMALLINT NOT NULL CHECK (seat BETWEEN 1 AND 4),
    user_id   INTEGER  REFERENCES users(id) ON DELETE SET NULL,
    name      TEXT     NOT NULL,
    kind      TEXT     NOT NULL DEFAULT 'human'
              CHECK (kind IN ('human', 'ai', 'network')),
    score     INTEGER,
    is_winner BOOLEAN  NOT NULL DEFAULT FALSE,

    PRIMARY KEY (match_id, seat),
    -- El mismo usuario no puede ocupar dos asientos. Los NULL no chocan entre
    -- si, asi que varias IAs en la misma partida siguen valiendo.
    UNIQUE (match_id, user_id)
);

-- El historial de un usuario es "sus filas en match_players".
CREATE INDEX IF NOT EXISTS idx_match_players_user
    ON match_players (user_id);


-- ==========================================================================
-- MENSAJES PRIVADOS (usuario -> usuario)
-- ==========================================================================

CREATE TABLE IF NOT EXISTS messages (
    id           BIGSERIAL PRIMARY KEY,
    sender_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    recipient_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    body         TEXT NOT NULL,
    sent_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    read_at      TIMESTAMPTZ,                    -- NULL = sin leer
    CHECK (sender_id <> recipient_id)
);

-- Una conversacion son los mensajes en los dos sentidos, por eso hacen falta
-- los dos indices.
CREATE INDEX IF NOT EXISTS idx_messages_sender
    ON messages (sender_id, sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_recipient
    ON messages (recipient_id, sent_at DESC);


-- ==========================================================================
-- CHATS DE GRUPO
-- ==========================================================================

CREATE TABLE IF NOT EXISTS group_chats (
    id         SERIAL PRIMARY KEY,
    name       TEXT NOT NULL,
    owner_id   INTEGER REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Quien esta en cada grupo.
CREATE TABLE IF NOT EXISTS group_members (
    chat_id   INTEGER NOT NULL REFERENCES group_chats(id) ON DELETE CASCADE,
    user_id   INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role      TEXT NOT NULL DEFAULT 'member'
              CHECK (role IN ('owner', 'admin', 'member')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (chat_id, user_id)
);

CREATE TABLE IF NOT EXISTS group_messages (
    id        BIGSERIAL PRIMARY KEY,
    chat_id   INTEGER NOT NULL REFERENCES group_chats(id) ON DELETE CASCADE,
    sender_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    body      TEXT NOT NULL,
    sent_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Leer un grupo es siempre "los ultimos N mensajes de este chat".
CREATE INDEX IF NOT EXISTS idx_group_messages_chat
    ON group_messages (chat_id, sent_at DESC);


-- ==========================================================================
-- DEMO
-- ==========================================================================

-- Tabla de prueba para comprobar que la tuberia de consultas funciona.
CREATE TABLE IF NOT EXISTS demo (
    id         SERIAL PRIMARY KEY,
    name       TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO demo (name) VALUES ('hello'), ('world');
