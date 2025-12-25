USE portfolio_db;

-- 为避免外键冲突，按依赖反向顺序删除
DROP TABLE IF EXISTS 05_douyin_shop_metric;
DROP TABLE IF EXISTS 04_douyin_traffic_daily;
DROP TABLE IF EXISTS 03_douyin_order;
DROP TABLE IF EXISTS 02_douyin_sku;
DROP TABLE IF EXISTS 01_douyin_shop;

-- 01：店铺维度（行政区 + 协议信息）
CREATE TABLE 01_douyin_shop (
    shop_id               BIGINT PRIMARY KEY,
    shop_name             VARCHAR(255) NOT NULL,
    district              VARCHAR(50)  NOT NULL,   -- 按行政区：浦东/静安/黄浦/徐汇等
    biz_type              VARCHAR(100) NOT NULL,   -- 火锅/自助/烧烤/中式正餐/应季品等
    avg_price             DECIMAL(10,2),           -- 人均客单价，便于画像和分层
    is_chain              TINYINT(1) DEFAULT 0,    -- 是否连锁
    has_agreement         TINYINT(1) DEFAULT 0,    -- 是否签季框/KA 协议（约 10%）
    agreement_target      DECIMAL(14,2),           -- 协议季度核销目标（100w–500w 梯度）
    agreement_rebate_rate DECIMAL(5,4),            -- 达标后返佣比例（0.10–0.30 之间的五档）
    created_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 02：SKU 维度（原价 / 团购价 / 活动 & 补贴能力）
CREATE TABLE 02_douyin_sku (
    sku_id                BIGINT PRIMARY KEY,
    shop_id               BIGINT NOT NULL,
    sku_name              VARCHAR(255) NOT NULL,
    sku_type              VARCHAR(50)  NOT NULL,  -- 单品/双人餐/3-4人餐/6人餐
    category              VARCHAR(100) NOT NULL,  -- 火锅/自助/烧烤/应季品 等
    original_price        DECIMAL(10,2) NOT NULL, -- 原价
    deal_price            DECIMAL(10,2) NOT NULL, -- 团购价（80–300 区间）
    exclusive_flag        TINYINT(1) DEFAULT 0,   -- 是否独家
    lowest_price_flag     TINYINT(1) DEFAULT 0,   -- 是否全网最低价
    is_activity_sku       TINYINT(1) DEFAULT 0,   -- 是否参与超值团大促
    platform_subsidy_cap  DECIMAL(10,2),          -- 单 SKU 平台补贴上限（≈ original_price×10%）
    merchant_discount_rate DECIMAL(5,4),          -- 商家对团购价的折上折比例（基于 deal_price）
    created_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_sku_shop
        FOREIGN KEY (shop_id) REFERENCES 01_douyin_shop(shop_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 03：订单事实（支付 → 核销 → 退款，全生命周期 + 价格拆分）
CREATE TABLE 03_douyin_order (
    order_id         BIGINT PRIMARY KEY,

    shop_id          BIGINT NOT NULL,
    sku_id           BIGINT NOT NULL,
    user_id          BIGINT,

    channel          VARCHAR(20)  NOT NULL,  -- search / short_video / live
    account_type     VARCHAR(30)  NOT NULL,  -- koc_creator / agency_official / merchant_self
    creator_level    TINYINT,                -- 达人等级 Lv1–Lv8，仅对达人有意义，可为空

    original_price   DECIMAL(10,2) NOT NULL, -- 原价（单份）
    deal_price       DECIMAL(10,2) NOT NULL, -- 团购价（单份）
    quantity         INT           NOT NULL, -- 份数

    merchant_discount DECIMAL(10,2) DEFAULT 0.00, -- 商家在团购价基础上的折上折总金额
    platform_subsidy DECIMAL(10,2) DEFAULT 0.00,  -- 平台补贴总金额
    user_pay         DECIMAL(10,2) NOT NULL,      -- 用户实付金额 = deal_price×qty - 商家让利 - 平台补贴

    pay_time         DATETIME      NOT NULL,      -- 支付时间

    writeoff_status  TINYINT(1)    DEFAULT 0,     -- 0 未核销 / 1 已核销
    writeoff_time    DATETIME      NULL,
    writeoff_gmv     DECIMAL(10,2) DEFAULT 0.00,  -- 核销 GMV（通常 = user_pay，未核销为 0）

    refund_status    TINYINT(1)    DEFAULT 0,     -- 0 未退款 / 1 已退款
    refund_time      DATETIME      NULL,
    refund_amount    DECIMAL(10,2) DEFAULT 0.00,  -- 退款金额（一般 = user_pay）
    refund_reason    VARCHAR(255)  NULL,

    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_order_shop
        FOREIGN KEY (shop_id) REFERENCES 01_douyin_shop(shop_id),
    CONSTRAINT fk_order_sku
        FOREIGN KEY (sku_id)  REFERENCES 02_douyin_sku(sku_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 04：日流量事实（按店铺 × 渠道 × 账号类型 × 达人等级聚合）
CREATE TABLE 04_douyin_traffic_daily (
    stat_date      DATE        NOT NULL,
    shop_id        BIGINT      NOT NULL,
    channel        VARCHAR(20) NOT NULL,   -- search / short_video / live
    account_type   VARCHAR(30) NOT NULL,   -- koc_creator / agency_official / merchant_self
    creator_level  TINYINT     NULL,       -- 达人等级 Lv1–Lv8，仅短视频和部分直播有意义

    exposure       BIGINT      DEFAULT 0,
    clicks         BIGINT      DEFAULT 0,
    detail_views   BIGINT      DEFAULT 0,

    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (stat_date, shop_id, channel, account_type),

    CONSTRAINT fk_traffic_shop
        FOREIGN KEY (shop_id) REFERENCES 01_douyin_shop(shop_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 05：店铺经营指标（按日汇总：支付 → 核销 → 结算）
CREATE TABLE 05_douyin_shop_metric (
    stat_date        DATE        NOT NULL,
    shop_id          BIGINT      NOT NULL,

    pay_gmv          DECIMAL(14,2) DEFAULT 0.00,  -- 支付 GMV
    writeoff_gmv     DECIMAL(14,2) DEFAULT 0.00,  -- 核销 GMV
    refund_amount    DECIMAL(14,2) DEFAULT 0.00,  -- 退款金额

    commission       DECIMAL(14,2) DEFAULT 0.00,  -- 抽佣：writeoff_gmv × 2.5%
    payment_fee      DECIMAL(14,2) DEFAULT 0.00,  -- 支付通道费：如 ≈ writeoff_gmv × 0.6%
    rebate_amount    DECIMAL(14,2) DEFAULT 0.00,  -- 协议返佣金额（仅协议店铺）

    settlement_amount DECIMAL(14,2) DEFAULT 0.00, -- 结算 GMV = 核销 - 抽佣 - 支付费 - 退款 + 返佣

    writeoff_rate    DECIMAL(5,4)  DEFAULT 0.0000, -- 核销率
    refund_rate      DECIMAL(5,4)  DEFAULT 0.0000, -- 退款率（按支付 or 核销口径自行约定）

    created_at       TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (stat_date, shop_id),
    CONSTRAINT fk_metric_shop
        FOREIGN KEY (shop_id) REFERENCES 01_douyin_shop(shop_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
