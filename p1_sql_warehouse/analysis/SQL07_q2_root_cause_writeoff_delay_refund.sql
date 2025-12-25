USE portfolio_db;

WITH
w AS (
  SELECT
    MAX(DATE(pay_time)) AS max_dt,
    DATE_SUB(MAX(DATE(pay_time)), INTERVAL 29 DAY) AS min_dt
  FROM `03_douyin_order`
),

-- 1) 近30天店铺层：规模与核销率（用汇总后相除）
shop_30d AS (
  SELECT
    o.shop_id,
    SUM(o.user_pay) AS pay_gmv_30d,
    SUM(o.writeoff_gmv) AS writeoff_gmv_30d,
    SUM(o.refund_amount) AS refund_amount_30d,
    SUM(o.writeoff_gmv) / NULLIF(SUM(o.user_pay), 0) AS writeoff_rate_30d,
    SUM(o.refund_amount) / NULLIF(SUM(o.user_pay), 0) AS refund_rate_amount_30d
  FROM `03_douyin_order` o
  JOIN w ON DATE(o.pay_time) BETWEEN w.min_dt AND w.max_dt
  GROUP BY o.shop_id
),

-- 2) 中位数阈值（GMV & 核销率）
ordered_gmv AS (
  SELECT pay_gmv_30d AS val,
         ROW_NUMBER() OVER (ORDER BY pay_gmv_30d) AS rn,
         COUNT(*) OVER () AS cnt
  FROM shop_30d
),
gmv_median AS (
  SELECT AVG(val) AS gmv_med
  FROM ordered_gmv
  WHERE rn IN (FLOOR((cnt + 1)/2), FLOOR((cnt + 2)/2))
),
ordered_wr AS (
  SELECT writeoff_rate_30d AS val,
         ROW_NUMBER() OVER (ORDER BY writeoff_rate_30d) AS rn,
         COUNT(*) OVER () AS cnt
  FROM shop_30d
  WHERE writeoff_rate_30d IS NOT NULL
),
wr_median AS (
  SELECT AVG(val) AS wr_med
  FROM ordered_wr
  WHERE rn IN (FLOOR((cnt + 1)/2), FLOOR((cnt + 2)/2))
),

-- 3) 取 Q2 店铺清单：高GMV + 低核销
q2 AS (
  SELECT s.shop_id, s.pay_gmv_30d, s.writeoff_rate_30d, s.refund_rate_amount_30d
  FROM shop_30d s
  CROSS JOIN gmv_median g
  CROSS JOIN wr_median w2
  WHERE s.pay_gmv_30d >= g.gmv_med
    AND (s.writeoff_rate_30d < w2.wr_med OR s.writeoff_rate_30d IS NULL)
),

-- 4) Q2 订单级成因：未核销占比 + 核销时延 + 退款
q2_orders AS (
  SELECT
    o.shop_id,
    COUNT(*) AS orders_30d,
    SUM(CASE WHEN o.writeoff_time IS NULL THEN 1 ELSE 0 END) AS unwriteoff_orders_30d,
    AVG(CASE WHEN o.writeoff_time IS NOT NULL THEN DATEDIFF(DATE(o.writeoff_time), DATE(o.pay_time)) END) AS avg_writeoff_days,
    SUM(CASE WHEN o.refund_time IS NOT NULL THEN 1 ELSE 0 END) AS refund_orders_30d
  FROM `03_douyin_order` o
  JOIN w ON DATE(o.pay_time) BETWEEN w.min_dt AND w.max_dt
  JOIN q2 ON o.shop_id = q2.shop_id
  GROUP BY o.shop_id
)

SELECT
  q2.shop_id,
  sh.shop_name,
  sh.district,
  sh.biz_type,
  sh.is_chain,
  sh.has_agreement,

  q2.pay_gmv_30d,
  ROUND(q2.writeoff_rate_30d, 4) AS writeoff_rate_30d,
  ROUND(q2.refund_rate_amount_30d, 4) AS refund_rate_amount_30d,

  o.orders_30d,
  o.unwriteoff_orders_30d,
  ROUND(o.unwriteoff_orders_30d / NULLIF(o.orders_30d, 0), 4) AS unwriteoff_rate_orders,
  ROUND(o.avg_writeoff_days, 2) AS avg_writeoff_days,
  o.refund_orders_30d,
  ROUND(o.refund_orders_30d / NULLIF(o.orders_30d, 0), 4) AS refund_rate_orders

FROM q2
JOIN q2_orders o ON q2.shop_id = o.shop_id
JOIN `01_douyin_shop` sh ON q2.shop_id = sh.shop_id
ORDER BY q2.pay_gmv_30d DESC;
