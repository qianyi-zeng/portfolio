USE portfolio_db;

WITH w AS (
  SELECT MAX(`date`) AS max_dt, DATE_SUB(MAX(`date`), INTERVAL 29 DAY) AS min_dt
  FROM `05_douyin_shop_metric`
),

shop_30d AS (
  SELECT
    m.shop_id,
    SUM(m.pay_gmv) AS pay_gmv_30d,
    SUM(m.writeoff_gmv) AS writeoff_gmv_30d,
    SUM(m.refund_amount) AS refund_amount_30d,
    SUM(m.commission) AS commission_30d,
    SUM(m.payment_fee) AS payment_fee_30d,
    SUM(m.rebate_amount) AS rebate_amount_30d,
    SUM(m.settlement_amount) AS settlement_amount_30d
  FROM `05_douyin_shop_metric` m
  JOIN w ON m.`date` BETWEEN w.min_dt AND w.max_dt
  GROUP BY m.shop_id
)

SELECT
  x.shop_id,
  s.shop_name,
  s.district,
  s.biz_type,
  s.is_chain,
  s.has_agreement,

  x.pay_gmv_30d,
  x.writeoff_gmv_30d,
  ROUND(x.writeoff_gmv_30d / NULLIF(x.pay_gmv_30d, 0), 4) AS writeoff_rate_30d,

  x.refund_amount_30d,
  ROUND(x.refund_amount_30d / NULLIF(x.pay_gmv_30d, 0), 4) AS refund_rate_amount_30d,

  x.commission_30d,
  x.payment_fee_30d,
  x.rebate_amount_30d,
  x.settlement_amount_30d,

  ROUND(x.commission_30d / NULLIF(x.pay_gmv_30d, 0), 4) AS commission_rate,
  ROUND(x.payment_fee_30d / NULLIF(x.pay_gmv_30d, 0), 4) AS fee_rate,
  ROUND(x.rebate_amount_30d / NULLIF(x.pay_gmv_30d, 0), 4) AS rebate_rate,
  ROUND(x.settlement_amount_30d / NULLIF(x.pay_gmv_30d, 0), 4) AS settlement_rate,

  -- 平台侧综合抽成（抽佣+手续费-返利）/ GMV
  ROUND((x.commission_30d + x.payment_fee_30d - x.rebate_amount_30d) / NULLIF(x.pay_gmv_30d, 0), 4) AS platform_take_rate

FROM shop_30d x
JOIN `01_douyin_shop` s ON x.shop_id = s.shop_id
ORDER BY x.settlement_amount_30d DESC;
