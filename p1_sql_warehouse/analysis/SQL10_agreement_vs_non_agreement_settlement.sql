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
    SUM(m.rebate_amount) AS rebate_amount_30d,
    SUM(m.settlement_amount) AS settlement_amount_30d,
    SUM(m.commission) AS commission_30d,
    SUM(m.payment_fee) AS payment_fee_30d
  FROM `05_douyin_shop_metric` m
  JOIN w ON m.`date` BETWEEN w.min_dt AND w.max_dt
  GROUP BY m.shop_id
),

joined AS (
  SELECT
    s.has_agreement,
    s.agreement_target,
    s.agreement_rebate_rate,
    x.*
  FROM shop_30d x
  JOIN `01_douyin_shop` s ON x.shop_id = s.shop_id
)

SELECT
  has_agreement,
  COUNT(*) AS shop_cnt,
  SUM(pay_gmv_30d) AS pay_gmv_30d,
  ROUND(SUM(writeoff_gmv_30d) / NULLIF(SUM(pay_gmv_30d), 0), 4) AS writeoff_rate_30d,

  SUM(rebate_amount_30d) AS rebate_amount_30d,
  ROUND(SUM(rebate_amount_30d) / NULLIF(SUM(pay_gmv_30d), 0), 4) AS rebate_rate_by_gmv,

  SUM(settlement_amount_30d) AS settlement_amount_30d,
  ROUND(SUM(settlement_amount_30d) / NULLIF(SUM(pay_gmv_30d), 0), 4) AS settlement_rate_by_gmv,

  ROUND(SUM(commission_30d + payment_fee_30d - rebate_amount_30d) / NULLIF(SUM(pay_gmv_30d), 0), 4) AS platform_take_rate,

  -- 目标达成（只对 agreement_target 非空/非0 的店计算）
  ROUND(
    AVG(CASE WHEN agreement_target IS NOT NULL AND agreement_target <> 0
             THEN pay_gmv_30d / agreement_target END),
    4
  ) AS avg_target_attainment
FROM joined
GROUP BY has_agreement
ORDER BY pay_gmv_30d DESC;
