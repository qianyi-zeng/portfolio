USE portfolio_db;

WITH w AS (
  SELECT MAX(`date`) AS max_dt, DATE_SUB(MAX(`date`), INTERVAL 29 DAY) AS min_dt
  FROM `04_douyin_traffic_daily`
),

t AS (
  SELECT
    `date` AS dt,
    channel,
    account_type,
    SUM(exposure) AS exposure,
    SUM(clicks) AS clicks,
    SUM(detail_views) AS detail_views
  FROM `04_douyin_traffic_daily`
  JOIN w ON `date` BETWEEN w.min_dt AND w.max_dt
  GROUP BY dt, channel, account_type
),

o AS (
  SELECT
    DATE(pay_time) AS dt,
    channel,
    account_type,
    COUNT(*) AS orders,
    SUM(user_pay) AS pay_gmv
  FROM `03_douyin_order`
  GROUP BY dt, channel, account_type
),

x AS (
  SELECT
    t.channel,
    t.account_type,
    SUM(t.exposure) AS exposure_30d,
    SUM(t.clicks) AS clicks_30d,
    SUM(t.detail_views) AS detail_views_30d,
    SUM(COALESCE(o.orders, 0)) AS orders_30d,
    SUM(COALESCE(o.pay_gmv, 0)) AS pay_gmv_30d
  FROM t
  LEFT JOIN o
    ON o.dt = t.dt
   AND o.channel = t.channel
   AND o.account_type = t.account_type
  GROUP BY t.channel, t.account_type
)

SELECT
  channel,
  account_type,
  exposure_30d,
  clicks_30d,
  detail_views_30d,
  orders_30d,
  pay_gmv_30d,

  ROUND(clicks_30d / NULLIF(exposure_30d, 0), 4) AS ctr,
  ROUND(detail_views_30d / NULLIF(clicks_30d, 0), 4) AS detail_per_click,
  ROUND(orders_30d / NULLIF(detail_views_30d, 0), 4) AS order_per_detail,
  ROUND(pay_gmv_30d / NULLIF(detail_views_30d, 0), 4) AS pay_gmv_per_detail,
  ROUND(pay_gmv_30d / NULLIF(orders_30d, 0), 2) AS aov
FROM x
ORDER BY pay_gmv_30d DESC;
