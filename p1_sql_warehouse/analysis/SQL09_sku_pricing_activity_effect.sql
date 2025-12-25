USE portfolio_db;

WITH w AS (
  SELECT MAX(DATE(pay_time)) AS max_dt, DATE_SUB(MAX(DATE(pay_time)), INTERVAL 29 DAY) AS min_dt
  FROM `03_douyin_order`
),

base AS (
  SELECT
    o.sku_id,
    o.shop_id,
    COUNT(*) AS orders_30d,
    SUM(o.user_pay) AS pay_gmv_30d,
    SUM(o.writeoff_gmv) AS writeoff_gmv_30d,
    SUM(o.refund_amount) AS refund_amount_30d
  FROM `03_douyin_order` o
  JOIN w ON DATE(o.pay_time) BETWEEN w.min_dt AND w.max_dt
  GROUP BY o.sku_id, o.shop_id
),

sku_enriched AS (
  SELECT
    b.shop_id,
    b.sku_id,
    s.sku_name,
    s.category,
    s.original_price,
    s.deal_price,
    s.is_activity_sku,
    s.exclusive_flag,
    s.lowest_price_flag,
    s.platform_subsidy_cap,
    s.merchant_discount_rate,

    b.orders_30d,
    b.pay_gmv_30d,
    b.writeoff_gmv_30d,
    b.refund_amount_30d,

    b.writeoff_gmv_30d / NULLIF(b.pay_gmv_30d, 0) AS writeoff_rate_30d,
    b.refund_amount_30d / NULLIF(b.pay_gmv_30d, 0) AS refund_rate_amount_30d,

    CASE
      WHEN s.deal_price < 20 THEN '<20'
      WHEN s.deal_price < 50 THEN '20-49'
      WHEN s.deal_price < 100 THEN '50-99'
      ELSE '>=100'
    END AS deal_price_band
  FROM base b
  JOIN `02_douyin_sku` s ON b.sku_id = s.sku_id
)

SELECT
  deal_price_band,
  is_activity_sku,
  COUNT(DISTINCT sku_id) AS sku_cnt,
  SUM(orders_30d) AS orders_30d,
  SUM(pay_gmv_30d) AS pay_gmv_30d,
  ROUND(SUM(writeoff_gmv_30d) / NULLIF(SUM(pay_gmv_30d), 0), 4) AS writeoff_rate_30d,
  ROUND(SUM(refund_amount_30d) / NULLIF(SUM(pay_gmv_30d), 0), 4) AS refund_rate_amount_30d
FROM sku_enriched
GROUP BY deal_price_band, is_activity_sku
ORDER BY pay_gmv_30d DESC;
