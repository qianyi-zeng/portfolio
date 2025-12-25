USE portfolio_db;

WITH refund_base AS (
    SELECT
        DATE(o.pay_time) AS dt,
        o.channel,
        o.writeoff_status,
        o.refund_status,
        o.user_pay,
        o.refund_amount
    FROM 03_douyin_order o
),

refund_agg AS (
    SELECT
        dt,
        channel,
        writeoff_status,

        -- 支付与退款规模
        SUM(user_pay) AS pay_gmv,
        SUM(CASE WHEN refund_status = TRUE THEN refund_amount ELSE 0 END) AS refund_amount,

        -- 订单量
        COUNT(*) AS pay_orders,
        SUM(CASE WHEN refund_status = TRUE THEN 1 ELSE 0 END) AS refund_orders
    FROM refund_base
    GROUP BY dt, channel, writeoff_status
)

SELECT
    dt,
    channel,

    -- 履约阶段：未核销 / 已核销
    CASE
        WHEN writeoff_status = TRUE THEN 'after_writeoff'
        ELSE 'before_writeoff'
    END AS refund_stage,

    pay_gmv,
    refund_amount,

    -- 退款率（金额口径）
    CASE WHEN pay_gmv = 0 THEN 0 ELSE refund_amount / pay_gmv END AS refund_rate,

    pay_orders,
    refund_orders,

    -- 7 日均线（退款率）
    AVG(CASE WHEN pay_gmv = 0 THEN 0 ELSE refund_amount / pay_gmv END) OVER (
        PARTITION BY channel, writeoff_status
        ORDER BY dt
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS refund_rate_ma7

FROM refund_agg
ORDER BY dt, channel, refund_stage;
