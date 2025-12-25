USE portfolio_db;

WITH channel_daily AS (
    SELECT
        DATE(o.pay_time) AS dt,
        o.channel,

        -- 规模
        SUM(o.user_pay) AS pay_gmv,
        SUM(o.writeoff_gmv) AS writeoff_gmv,

        -- 订单量
        COUNT(*) AS pay_orders,
        SUM(CASE WHEN o.writeoff_status = TRUE THEN 1 ELSE 0 END) AS writeoff_orders
    FROM 03_douyin_order o
    GROUP BY DATE(o.pay_time), o.channel
)

SELECT
    dt,
    channel,

    pay_gmv,
    writeoff_gmv,

    -- 核销率（履约质量）
    CASE WHEN pay_gmv = 0 THEN 0 ELSE writeoff_gmv / pay_gmv END AS writeoff_rate,

    pay_orders,
    writeoff_orders,

    -- 7 日均线（渠道维度）
    AVG(pay_gmv) OVER (
        PARTITION BY channel
        ORDER BY dt
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS pay_gmv_ma7,

    AVG(writeoff_gmv) OVER (
        PARTITION BY channel
        ORDER BY dt
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS writeoff_gmv_ma7,

    AVG(CASE WHEN pay_gmv = 0 THEN 0 ELSE writeoff_gmv / pay_gmv END) OVER (
        PARTITION BY channel
        ORDER BY dt
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS writeoff_rate_ma7

FROM channel_daily
ORDER BY dt, channel;
