# TimescaleDB time-series example

1. **Hypertable:** Creates the `conditions` sensor table and converts it to a TimescaleDB hypertable partitioned by time.
2. **Synthetic data:** Inserts a week of five-minute temperature and humidity readings for four devices.
3. **Hourly aggregate:** Defines a continuous aggregate with per-device hourly average and maximum temperatures. Run its `CREATE MATERIALIZED VIEW` statement outside a transaction.
4. **Analytical queries:** Demonstrates daily device maxima, the hottest hour across devices, and a per-device rolling 24-hour average based on hourly averages.
