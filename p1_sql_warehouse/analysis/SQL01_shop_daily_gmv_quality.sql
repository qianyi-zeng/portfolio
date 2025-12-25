USE portfolio_db;

WITH shop_daily AS (
    SELECT
        o.shop_id,
        s.shop_name,
        DATE(o.pay_time) AS dt,

        -- 规模
        SUM(o.user_pay) AS pay_gmv,
        SUM(o.writeoff_gmv) AS writeoff_gmv,
        SUM(CASE WHEN o.refund_status = TRUE THEN o.refund_amount ELSE 0 END) AS refund_amount,

        -- 订单结构
        COUNT(*) AS pay_orders,
        SUM(CASE WHEN o.writeoff_status = TRUE THEN 1 ELSE 0 END) AS writeoff_orders,
        SUM(CASE WHEN o.refund_status  = TRUE THEN 1 ELSE 0 END) AS refund_orders
    FROM 03_douyin_order o
    JOIN 01_douyin_shop s
      ON o.shop_id = s.shop_id
    GROUP BY o.shop_id, s.shop_name, DATE(o.pay_time)
)

SELECT
    shop_id,
    shop_name,
    dt,

    pay_gmv,
    writeoff_gmv,
    refund_amount,

    -- 净 GMV：支付 - 退款（在你当前模型下，退款=用户支付全额回吐）
    (pay_gmv - refund_amount) AS net_gmv,

    -- 质量指标（避免除零）
    CASE WHEN pay_gmv = 0 THEN 0 ELSE writeoff_gmv / pay_gmv END AS writeoff_rate,
    CASE WHEN pay_gmv = 0 THEN 0 ELSE refund_amount / pay_gmv END AS refund_rate,

    pay_orders,
    writeoff_orders,
    refund_orders,

    -- 7 日均线（趋势去噪）
    AVG(pay_gmv) OVER (
        PARTITION BY shop_id
        ORDER BY dt
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS pay_gmv_ma7,

    AVG(writeoff_gmv) OVER (
        PARTITION BY shop_id
        ORDER BY dt
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS writeoff_gmv_ma7,

    AVG(refund_amount) OVER (
        PARTITION BY shop_id
        ORDER BY dt
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS refund_amount_ma7,

    AVG(CASE WHEN pay_gmv = 0 THEN 0 ELSE writeoff_gmv / pay_gmv END) OVER (
        PARTITION BY shop_id
        ORDER BY dt
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS writeoff_rate_ma7,

    AVG(CASE WHEN pay_gmv = 0 THEN 0 ELSE refund_amount / pay_gmv END) OVER (
        PARTITION BY shop_id
        ORDER BY dt
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS refund_rate_ma7

FROM shop_daily
ORDER BY shop_id, dt;
