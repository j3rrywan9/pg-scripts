select version();

select current_database();

select datname from pg_database;

create schema finance;

select relname from pg_class c join pg_namespace n on c.relnamespace = n.oid where n.nspname = 'test';

select * from information_schema.tables where table_schema = 'test';

-- Commands
\t on

\d+ test.a
