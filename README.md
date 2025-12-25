# Douyin Local Service (Restaurant) Portfolio

This repo contains a simulated Douyin local service dataset (restaurant) and a SQL analysis layer focused on:
- GMV scale and fulfillment quality (writeoff)
- Refund structure
- Channel contribution
- Shop fulfillment segmentation (GMV × writeoff_rate)

## Environment
- macOS
- MySQL database: `portfolio_db`

## Reproducible quick start
1) Create database: `portfolio_db`
2) Run DDL:
   - `p1_sql_warehouse/ddl/create_table_01-05.sql`
3) Generate data:
   - Run `p1_sql_warehouse/etl/generator.py` to load data into MySQL
4) Run analysis SQL (in order):
   - `p1_sql_warehouse/analysis/SQL01_shop_daily_gmv_quality.sql`
   - `p1_sql_warehouse/analysis/SQL02_channel_writeoff_rate.sql`
   - `p1_sql_warehouse/analysis/SQL03_channel_aov.sql`
   - `p1_sql_warehouse/analysis/SQL04_refund_rate_structure.sql`
   - `p1_sql_warehouse/analysis/SQL05_channel_shop_gmv_contribution.sql`
   - `p1_sql_warehouse/analysis/SQL06_shop_fulfillment_quadrant.sql`

## Notes
- Field definitions strictly follow v1.0 DDL.
- No Windows/Power BI dependency.
