-- Se ejecuta solo la primera vez, cuando el volumen de Postgres esta vacio.
-- Tabla minima para poder probar que la tuberia de consultas funciona.

CREATE TABLE IF NOT EXISTS demo (
    id         SERIAL PRIMARY KEY,
    name       TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO demo (name) VALUES ('hello'), ('world');
