-- Migracion 001: tabla friends.
--
-- Para que la usen los que YA tenian la base de datos levantada. db/init.sql
-- solo se ejecuta cuando el volumen esta vacio, asi que si ya habias jugado
-- antes, la tabla friends no aparece sola.
--
-- Dos formas de aplicarla:
--
--   a) Sin perder nada (recomendado). Con el stack levantado:
--        docker compose exec -T postgres \
--          psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" < db/migrations/001_friends.sql
--
--   b) Empezando de cero (borra usuarios y partidas):
--        make clean && make
--
-- Es identica a lo que hay en init.sql y todo es IF NOT EXISTS, asi que
-- ejecutarla dos veces no rompe nada.

BEGIN;

CREATE TABLE IF NOT EXISTS friends (
    user_id   INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    friend_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    added_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, friend_id),
    CHECK (user_id <> friend_id)
);

CREATE INDEX IF NOT EXISTS idx_friends_friend
    ON friends (friend_id);

COMMIT;
