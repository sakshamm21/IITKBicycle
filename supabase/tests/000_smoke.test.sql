-- Proves the local database and pgTAP are wired up. Real tests arrive with the schema.
begin;
select plan(1);

select has_extension('pgtap');

select * from finish();
rollback;
