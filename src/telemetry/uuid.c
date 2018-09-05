#include <postgres.h>
#include <utils/timestamp.h>
#include <utils/uuid.h>

#include "compat.h"
#include "telemetry/uuid.h"

#if PG10
#include <utils/backend_random.h>
#endif

/*
 * Generates a v4 UUID. Based on function pg_random_uuid() in the pgcrypto contrib module.
 *
 * Note that clib on Mac has a uuid_generate() function, so we call this uuid_create().
 */
pg_uuid_t *
uuid_create(void)
{
	/*
	 * PG9.6 doesn't expose the internals of pg_uuid_t, so we just treat it as
	 * a byte array
	 */
	unsigned char *gen_uuid = palloc0(UUID_LEN);
	bool		rand_success = false;

#if PG10
	rand_success = pg_backend_random((char *) gen_uuid, UUID_LEN);
#endif

	/*
	 * If pg_backend_random() cannot find sources of randomness, then we use
	 * the current timestamp as a "random source". Note that
	 * pg_backend_random() was added in PG10, so we always use the current
	 * timestamp on PG9.6. Timestamps are 8 bytes, so we copy this into bytes
	 * 9-16 of the UUID. If we see all 0s in bytes 0-8 (other than version +
	 * variant), we know that there is something wrong with the RNG on this
	 * instance.
	 */
	if (!rand_success)
	{
		TimestampTz ts = GetCurrentTimestamp();

		memcpy(&gen_uuid[9], &ts, sizeof(TimestampTz));
	}

	gen_uuid[6] = (gen_uuid[6] & 0x0f) | 0x40;	/* "version" field */
	gen_uuid[8] = (gen_uuid[8] & 0x3f) | 0x80;	/* "variant" field */

	return (pg_uuid_t *) gen_uuid;
}

TS_FUNCTION_INFO_V1(ts_uuid_generate);

Datum
ts_uuid_generate(PG_FUNCTION_ARGS)
{
	return UUIDPGetDatum(uuid_create());
}
