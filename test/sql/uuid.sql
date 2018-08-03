\c single :ROLE_SUPERUSER
CREATE OR REPLACE FUNCTION _timescaledb_internal.test_uuid() RETURNS UUID
    AS :MODULE_PATHNAME, 'test_uuid' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _timescaledb_internal.test_exported_uuid() RETURNS UUID
    AS :MODULE_PATHNAME, 'test_exported_uuid' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _timescaledb_internal.test_install_timestamp() RETURNS TEXT
    AS :MODULE_PATHNAME, 'test_install_timestamp' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
\c single :ROLE_DEFAULT_PERM_USER

-- uuid and install_timestamp should already be in the table before we generate
SELECT COUNT(*) from _timescaledb_catalog.installation_metadata;
SELECT _timescaledb_internal.test_uuid() as uuid_1 \gset
SELECT _timescaledb_internal.test_exported_uuid() as uuid_ex_1 \gset
SELECT _timescaledb_internal.test_install_timestamp() as timestamp_1 \gset
-- Check that there is exactly 1 UUID row 
SELECT COUNT(*) from _timescaledb_catalog.installation_metadata where key='uuid';
-- Check that exported_uuid and timestamp are also generated
SELECT COUNT(*) from _timescaledb_catalog.installation_metadata where key='exported_uuid';
SELECT COUNT(*) from _timescaledb_catalog.installation_metadata where key='install_timestamp';

-- Make sure that the UUID is idempotent
SELECT _timescaledb_internal.test_uuid() = :'uuid_1' as uuids_equal;
SELECT _timescaledb_internal.test_uuid() = :'uuid_1' as uuids_equal;
-- Also make sure install_time and exported_uuid are idempotent
SELECT _timescaledb_internal.test_exported_uuid() = :'uuid_ex_1' as exported_uuids_equal;
SELECT _timescaledb_internal.test_exported_uuid() = :'uuid_ex_1' as exported_uuids_equal;
SELECT _timescaledb_internal.test_install_timestamp() = :'timestamp_1' as timestamps_equal; 
SELECT _timescaledb_internal.test_install_timestamp() = :'timestamp_1' as timestamps_equal; 

-- Now make sure that only the exported_uuid is exported on pg_dump
\c postgres :ROLE_SUPERUSER

\! pg_dump -h localhost -U super_user -Fc single > dump/single.sql
\! dropdb -h localhost -U super_user single
\! createdb -h localhost -U super_user single
ALTER DATABASE single SET timescaledb.restoring='on';
\! pg_restore -h localhost -U super_user -d single dump/single.sql
ALTER DATABASE single SET timescaledb.restoring='off';

\c single :ROLE_DEFAULT_PERM_USER

-- Should have all 3 row, because pg_dump includes the insertion of uuid and timestamp.
SELECT COUNT(*) FROM _timescaledb_catalog.installation_metadata;
-- Verify that this is the old exported_uuid
SELECT _timescaledb_internal.test_exported_uuid() = :'uuid_ex_1' as exported_uuids_equal;
-- Verify that the uuid and timestamp are new
SELECT _timescaledb_internal.test_uuid() = :'uuid_1' as exported_uuids_diff;
SELECT _timescaledb_internal.test_install_timestamp() = :'timestamp_1' as exported_uuids_diff;