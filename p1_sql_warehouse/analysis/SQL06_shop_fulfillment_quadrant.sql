USE portfolio_db;

WITH
-- 1) 取近30天窗口（以指标表最大日期为“最新一天”）
date_window AS (
    SELECT
        MAX(`date`) AS max_dt,
        DATE_SUB(MAX(`date`), INTERVAL 29 DAY) AS min_dt
    FROM `05_douyin_shop_metric`
),

-- 2) 店铺近30天聚合（规模 + 履约）
shop_30d AS (
    SELECT
        m.shop_id,
        SUM(m.pay_gmv) AS pay_gmv_30d,
        SUM(m.writeoff_gmv) AS writeoff_gmv_30d,
        SUM(m.refund_amount) AS refund_amount_30d,
        SUM(m.settlement_amount) AS settlement_amount_30d,
        SUM(m.commission) AS commission_30d,
        SUM(m.payment_fee) AS payment_fee_30d,
        SUM(m.rebate_amount) AS rebate_amount_30d,
        -- 用“汇总后再相除”计算核销率，避免日比率平均偏差
        SUM(m.writeoff_gmv) / NULLIF(SUM(m.pay_gmv), 0) AS writeoff_rate_30d
    FROM `05_douyin_shop_metric` m
    JOIN date_window w
      ON m.`date` BETWEEN w.min_dt AND w.max_dt
    GROUP BY m.shop_id
),

-- 3) 计算全店阈值：GMV中位数、核销率中位数（MySQL 8 window）
ordered_gmv AS (
    SELECT
        pay_gmv_30d AS val,
        ROW_NUMBER() OVER (ORDER BY pay_gmv_30d) AS rn,
        COUNT(*) OVER () AS cnt
    FROM shop_30d
),
gmv_median AS (
    SELECT AVG(val) AS pay_gmv_30d_median
    FROM ordered_gmv
    WHERE rn IN (FLOOR((cnt + 1) / 2), FLOOR((cnt + 2) / 2))
),
ordered_wr AS (
    SELECT
        writeoff_rate_30d AS val,
        ROW_NUMBER() OVER (ORDER BY writeoff_rate_30d) AS rn,
        COUNT(*) OVER () AS cnt
    FROM shop_30d
    WHERE writeoff_rate_30d IS NOT NULL
),
wr_median AS (
    SELECT AVG(val) AS writeoff_rate_30d_median
    FROM ordered_wr
    WHERE rn IN (FLOOR((cnt + 1) / 2), FLOOR((cnt + 2) / 2))
),

-- 4) 组装象限标签
scored AS (
    SELECT
        s.shop_id,
        s.pay_gmv_30d,
        s.writeoff_gmv_30d,
        s.writeoff_rate_30d,
        s.refund_amount_30d,
        s.settlement_amount_30d,
        s.commission_30d,
        s.payment_fee_30d,
        s.rebate_amount_30d,
        g.pay_gmv_30d_median,
        w.writeoff_rate_30d_median,
        CASE
            WHEN s.pay_gmv_30d >= g.pay_gmv_30d_median
             AND s.writeoff_rate_30d >= w.writeoff_rate_30d_median
                THEN 'Q1 高GMV·高核销（核心优质）'
            WHEN s.pay_gmv_30d >= g.pay_gmv_30d_median
             AND (s.writeoff_rate_30d < w.writeoff_rate_30d_median OR s.writeoff_rate_30d IS NULL)
                THEN 'Q2 高GMV·低核销（履约短板）'
            WHEN s.pay_gmv_30d < g.pay_gmv_30d_median
             AND s.writeoff_rate_30d >= w.writeoff_rate_30d_median
                THEN 'Q3 低GMV·高核销（增长潜力）'
            ELSE 'Q4 低GMV·低核销（治理/淘汰）'
        END AS quadrant
    FROM shop_30d s
    CROSS JOIN gmv_median g
    CROSS JOIN wr_median w
)

SELECT
    sc.shop_id,
    sh.shop_name,
    sh.district,
    sh.biz_type,
    sh.is_chain,
    sh.has_agreement,

    sc.pay_gmv_30d,
    sc.writeoff_gmv_30d,
    ROUND(sc.writeoff_rate_30d, 4) AS writeoff_rate_30d,

    sc.refund_amount_30d,
    sc.settlement_amount_30d,
    sc.commission_30d,
    sc.payment_fee_30d,
    sc.rebate_amount_30d,

    sc.pay_gmv_30d_median,
    ROUND(sc.writeoff_rate_30d_median, 4) AS writeoff_rate_30d_median,
    sc.quadrant,

    -- 规模优先：先按象限，再按GMV降序
    DENSE_RANK() OVER (
        ORDER BY
            CASE sc.quadrant
                WHEN 'Q1 高GMV·高核销（核心优质）' THEN 1
                WHEN 'Q2 高GMV·低核销（履约短板）' THEN 2
                WHEN 'Q3 低GMV·高核销（增长潜力）' THEN 3
                ELSE 4
            END,
            sc.pay_gmv_30d DESC
    ) AS priority_rank
FROM scored sc
JOIN `01_douyin_shop` sh
  ON sc.shop_id = sh.shop_id
ORDER BY
    CASE sc.quadrant
        WHEN 'Q1 高GMV·高核销（核心优质）' THEN 1
        WHEN 'Q2 高GMV·低核销（履约短板）' THEN 2
        WHEN 'Q3 低GMV·高核销（增长潜力）' THEN 3
        ELSE 4
    END,
    sc.pay_gmv_30d DESC,
    sc.writeoff_rate_30d DESC;
