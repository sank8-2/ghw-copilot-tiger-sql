-- ============================================================
-- 1. Sensor table and TimescaleDB hypertable
-- ============================================================
CREATE TABLE IF NOT EXISTS conditions (
    time        TIMESTAMPTZ NOT NULL,
    device_id   TEXT NOT NULL,
    temperature DOUBLE PRECISION,
    humidity    DOUBLE PRECISION
);

SELECT create_hypertable(
    'conditions',
    'time',
    if_not_exists => TRUE
);

-- ============================================================
-- 2. Seven days of synthetic sensor data (5-minute intervals)
-- ============================================================
INSERT INTO conditions (time, device_id, temperature, humidity)
SELECT
    now() - INTERVAL '7 days' + samples.step * INTERVAL '5 minutes',
    devices.device_id,
    20.0
        + devices.device_num * 1.5
        + 4.0 * sin(samples.step / 36.0)
        + 0.5 * cos(samples.step / 7.0 + devices.device_num),
    50.0
        + devices.device_num * 2.0
        + 10.0 * cos(samples.step / 48.0 + devices.device_num)
FROM generate_series(0, 2015) AS samples(step)
CROSS JOIN (
    VALUES
        ('device-1', 1),
        ('device-2', 2),
        ('device-3', 3),
        ('device-4', 4)
) AS devices(device_id, device_num);

-- ============================================================
-- 3. Hourly continuous aggregate
-- NOTE: CREATE MATERIALIZED VIEW must run outside a transaction.
-- ============================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS conditions_hourly
WITH (timescaledb.continuous) AS
SELECT
    time_bucket(INTERVAL '1 hour', time) AS bucket,
    device_id,
    avg(temperature) AS avg_temperature,
    max(temperature) AS max_temperature
FROM conditions
GROUP BY bucket, device_id
WITH NO DATA;

-- ============================================================
-- 4. Example analytical queries
-- ============================================================

-- Daily maximum temperature for each device.
SELECT
    time_bucket(INTERVAL '1 day', time) AS day,
    device_id,
    max(temperature) AS daily_max_temperature
FROM conditions
GROUP BY day, device_id
ORDER BY day, device_id;

-- Hottest hourly maximum across all devices.
SELECT
    bucket AS hottest_hour,
    max(max_temperature) AS hottest_temperature
FROM conditions_hourly
GROUP BY bucket
ORDER BY hottest_temperature DESC
LIMIT 1;

-- Trailing 24-hour average of hourly average temperature per device.
SELECT
    bucket,
    device_id,
    avg_temperature,
    avg(avg_temperature) OVER (
        PARTITION BY device_id
        ORDER BY bucket
        ROWS BETWEEN 23 PRECEDING AND CURRENT ROW
    ) AS rolling_24h_avg_temperature
FROM conditions_hourly
ORDER BY device_id, bucket;
