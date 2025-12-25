USE portfolio_db;

WITH channel_daily AS (
    SELECT
        DATE(o.pay_time) AS dt,
        o.channel,

        -- 支付侧
        SUM(o.user_pay) AS pay_gmv,
        COUNT(*) AS pay_orders,

        -- 核销侧
        SUM(o.writeoff_gmv) AS writeoff_gmv,
        SUM(CASE WHEN o.writeoff_status = TRUE THEN 1 ELSE 0 END) AS writeoff_orders
    FROM 03_douyin_order o
    GROUP BY DATE(o.pay_time), o.channel
)

SELECT
    dt,
    channel,

    pay_gmv,
    pay_orders,

    -- 支付 AOV
    CASE WHEN pay_orders = 0 THEN 0 ELSE pay_gmv / pay_orders END AS pay_aov,

    writeoff_gmv,
    writeoff_orders,

    -- 核销 AOV（真实完成履约的客单）
    CASE WHEN writeoff_orders = 0 THEN 0 ELSE writeoff_gmv / writeoff_orders END AS writeoff_aov,

    -- 7 日均线（AOV 趋势）
    AVG(CASE WHEN pay_orders = 0 THEN 0 ELSE pay_gmv / pay_orders END) OVER (
        PARTITION BY channel
        ORDER BY dt
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS pay_aov_ma7,

    AVG(CASE WHEN writeoff_orders = 0 THEN 0 ELSE writeoff_gmv / writeoff_orders END) OVER (
        PARTITION BY channel
        ORDER BY dt
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS writeoff_aov_ma7

FROM channel_daily
ORDER BY dt, channel;
