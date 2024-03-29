\set ECHO none
SET client_min_messages TO error;
\t on
\x off
SELECT 'created logical replication slot'
  FROM pg_create_logical_replication_slot('json', 'json-output');

BEGIN;

CREATE SCHEMA IF NOT EXISTS json;
SET LOCAL search_path TO json, public;
CREATE EXTENSION IF NOT EXISTS hstore;

CREATE TABLE IF NOT EXISTS test (
  i   integer PRIMARY KEY,
  h   hstore NOT NULL DEFAULT ''
);

INSERT INTO test (i) SELECT i FROM generate_series(1, 1024) AS i;

CREATE VIEW changedata AS
SELECT data FROM pg_logical_slot_get_changes('json', NULL, NULL);

END;

BEGIN;
SET LOCAL search_path TO json, public;
UPDATE test SET h = hstore('i', i::text)
                 || hstore((SELECT array_agg(n::text)
                              FROM generate_series(1, i) AS n),
                           (SELECT array_agg(n::text)
                              FROM generate_series(1, i) AS n));
DELETE FROM test WHERE i % 2 = 1;
END;

SELECT * FROM json.changedata;

SELECT 'deleted logical replication slot'
  FROM pg_drop_replication_slot('json');

DROP SCHEMA json CASCADE;
