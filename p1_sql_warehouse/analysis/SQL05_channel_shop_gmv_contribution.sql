USE portfolio_db;

WITH channel_shop_daily AS (
    SELECT
        DATE(o.pay_time) AS dt,
        o.channel,
        o.shop_id,
        s.shop_name,

        SUM(o.user_pay) AS shop_pay_gmv
    FROM 03_douyin_order o
    JOIN 01_douyin_shop s
      ON o.shop_id = s.shop_id
    GROUP BY DATE(o.pay_time), o.channel, o.shop_id, s.shop_name
),

channel_total AS (
    SELECT
        dt,
        channel,
        SUM(shop_pay_gmv) AS channel_pay_gmv
    FROM channel_shop_daily
    GROUP BY dt, channel
),

ranked AS (
    SELECT
        c.dt,
        c.channel,
        c.shop_id,
        c.shop_name,
        c.shop_pay_gmv,
        t.channel_pay_gmv,

        -- 渠道内 GMV 占比
        CASE
            WHEN t.channel_pay_gmv = 0 THEN 0
            ELSE c.shop_pay_gmv / t.channel_pay_gmv
        END AS channel_gmv_share,

        -- 渠道内排名
        RANK() OVER (
            PARTITION BY c.dt, c.channel
            ORDER BY c.shop_pay_gmv DESC
        ) AS channel_rank
    FROM channel_shop_daily c
    JOIN channel_total t
      ON c.dt = t.dt
     AND c.channel = t.channel
)

SELECT
    dt,
    channel,
    shop_id,
    shop_name,
    shop_pay_gmv,
    channel_pay_gmv,
    channel_gmv_share,
    channel_rank,

    -- Top10 累计集中度（用于判断头部依赖）
    SUM(channel_gmv_share) OVER (
        PARTITION BY dt, channel
        ORDER BY channel_rank
        ROWS BETWEEN UNBOUNDED PRECEDING AND 9 PRECEDING
    ) AS top10_channel_gmv_share

FROM ranked
ORDER BY dt, channel, channel_rank;
