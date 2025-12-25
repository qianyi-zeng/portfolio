import random
from datetime import datetime, date, timedelta
from decimal import Decimal, ROUND_HALF_UP

import pymysql

DB_CONFIG = {
    "host": "127.0.0.1",
    "port": 3306,
    "user": "root",
    "password": "",
    "database": "portfolio_db",
    "charset": "utf8mb4",
}

START_DATE = date(2025, 1, 1)
DAYS = 60
NUM_SHOPS = 36

RANDOM_SEED = 20251211
random.seed(RANDOM_SEED)


def d_round(x, nd=2):
    return float(
        Decimal(x).quantize(
            Decimal("0." + "0" * (nd - 1) + "1"),
            rounding=ROUND_HALF_UP
        )
    )


def daterange(start: date, days: int):
    for i in range(days):
        yield start + timedelta(days=i)


def random_time_on_day(d: date):
    h = random.randint(8, 22)
    m = random.randint(0, 59)
    s = random.randint(0, 59)
    return datetime(d.year, d.month, d.day, h, m, s)


def main():
    conn = pymysql.connect(**DB_CONFIG)
    cursor = conn.cursor()

    # 清空（已是 v1.0 结构）
    cursor.execute("SET FOREIGN_KEY_CHECKS=0;")
    cursor.execute("TRUNCATE TABLE `05_douyin_shop_metric`;")
    cursor.execute("TRUNCATE TABLE `04_douyin_traffic_daily`;")
    cursor.execute("TRUNCATE TABLE `03_douyin_order`;")
    cursor.execute("TRUNCATE TABLE `02_douyin_sku`;")
    cursor.execute("TRUNCATE TABLE `01_douyin_shop`;")
    cursor.execute("SET FOREIGN_KEY_CHECKS=1;")
    conn.commit()

    # 01 shops
    districts = ["浦东新区", "黄浦区", "静安区", "徐汇区", "杨浦区", "长宁区"]
    biz_types = ["火锅", "烧烤", "海鲜", "地方菜", "自助餐"]

    agreement_shop_ids = set(random.sample(range(1, NUM_SHOPS + 1), k=max(3, NUM_SHOPS // 10)))
    agreement_targets = [1_000_000, 2_000_000, 3_000_000, 4_000_000, 5_000_000]
    rebate_rates = [0.10, 0.15, 0.20, 0.25, 0.30]

    shop_insert_sql = """
        INSERT INTO `01_douyin_shop`
        (shop_id, shop_name, district, biz_type, avg_price, is_chain,
         has_agreement, agreement_target, agreement_rebate_rate, created_at)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,NOW())
    """

    shops = []
    for shop_id in range(1, NUM_SHOPS + 1):
        district = districts[(shop_id - 1) % len(districts)]
        biz_type = random.choice(biz_types)

        if biz_type in ("火锅", "自助餐"):
            avg_price = random.randint(100, 180)
        else:
            avg_price = random.randint(80, 150)

        is_chain = 1 if random.random() < 0.3 else 0

        if shop_id in agreement_shop_ids:
            has_agreement = 1
            agreement_target = random.choice(agreement_targets)
            agreement_rebate_rate = random.choice(rebate_rates)
        else:
            has_agreement = 0
            agreement_target = None
            agreement_rebate_rate = None

        shop_name = f"{district}{biz_type}店_{shop_id}"

        cursor.execute(
            shop_insert_sql,
            (
                shop_id, shop_name, district, biz_type, avg_price, is_chain,
                has_agreement, agreement_target, agreement_rebate_rate
            )
        )

        shops.append({
            "shop_id": shop_id,
            "biz_type": biz_type,
            "has_agreement": has_agreement,
            "agreement_target": agreement_target,
            "agreement_rebate_rate": agreement_rebate_rate
        })

    conn.commit()

    # 02 skus (v1.0: no sku_type)
    sku_insert_sql = """
        INSERT INTO `02_douyin_sku`
        (sku_id, shop_id, sku_name, category,
         original_price, deal_price,
         exclusive_flag, lowest_price_flag, is_activity_sku,
         platform_subsidy_cap, merchant_discount_rate)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
    """

    sku_id_counter = 1
    sku_records = []

    price_band = {
        "超值单品": (80, 120),
        "单人餐": (80, 160),
        "双人餐": (120, 220),
        "3-4人餐": (180, 280),
        "5-6人餐": (220, 300),
    }

    for shop in shops:
        shop_id = shop["shop_id"]
        num_sku = random.randint(5, 10)

        base_types = ["超值单品", "单人餐", "双人餐", "3-4人餐", "5-6人餐"]
        sku_types = ["超值单品", "双人餐", "3-4人餐", "5-6人餐"]
        while len(sku_types) < num_sku:
            sku_types.append(random.choice(base_types))

        category = shop["biz_type"]

        for st in sku_types:
            low, high = price_band[st]
            deal_price = d_round(random.uniform(low, high))
            original_price = d_round(deal_price * random.uniform(1.3, 1.8))

            exclusive_flag = 1 if random.random() < 0.4 else 0
            lowest_price_flag = 1 if random.random() < 0.3 else 0
            is_activity_sku = 1 if random.random() < 0.3 else 0

            platform_subsidy_cap = d_round(original_price * 0.10)
            merchant_discount_rate = d_round(random.uniform(0.10, 0.30), 4)

            sku_name = f"{shop['biz_type']}{st}"

            cursor.execute(
                sku_insert_sql,
                (
                    sku_id_counter, shop_id, sku_name, category,
                    original_price, deal_price,
                    exclusive_flag, lowest_price_flag, is_activity_sku,
                    platform_subsidy_cap, merchant_discount_rate
                )
            )

            sku_records.append({
                "sku_id": sku_id_counter,
                "shop_id": shop_id,
                "category": category,
                "original_price": float(original_price),
                "deal_price": float(deal_price),
                "is_activity_sku": is_activity_sku,
                "platform_subsidy_cap": float(platform_subsidy_cap),
                "merchant_discount_rate": float(merchant_discount_rate),
            })

            sku_id_counter += 1

    conn.commit()

    skus_by_shop = {}
    for sku in sku_records:
        skus_by_shop.setdefault(sku["shop_id"], []).append(sku)

    # 03 orders + 04 traffic + 05 metrics base
    traffic_insert_sql = """
        INSERT INTO `04_douyin_traffic_daily`
        (`date`, shop_id, channel, account_type, creator_level,
         exposure, clicks, detail_views)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
    """

    order_insert_sql = """
        INSERT INTO `03_douyin_order`
        (order_id, shop_id, sku_id, user_id,
         channel, account_type,
         original_price, deal_price,
         merchant_discount, platform_subsidy, user_pay,
         pay_time,
         writeoff_status, writeoff_time,
         refund_status, refund_time, refund_amount,
         writeoff_gmv, refund_reason)
        VALUES
        (%s,%s,%s,%s,%s,%s,
         %s,%s,%s,%s,%s,
         %s,%s,%s,
         %s,%s,%s,
         %s,%s)
    """

    metrics_daily = {}  # key: (date, shop_id)

    agreement_cum_writeoff = {s["shop_id"]: 0.0 for s in shops if s["has_agreement"] == 1}
    agreement_shop_info = {s["shop_id"]: s for s in shops if s["has_agreement"] == 1}
    rebate_posted = {sid: False for sid in agreement_cum_writeoff.keys()}

    base_conv = {
        "search": (0.015, 0.035),
        "short_video": (0.01, 0.02),
        "live": (0.006, 0.012),
    }

    writeoff_rate = {
        "search": 0.90,
        "short_video": 0.70,
        "live": 0.50,
    }

    video_boost_weekdays = [2, 5]
    live_boost_weekdays = [3, 6]

    sale_periods = []
    sale_start = START_DATE
    while sale_start < START_DATE + timedelta(days=DAYS):
        sale_periods.append((sale_start, sale_start + timedelta(days=6)))
        sale_start += timedelta(days=30)

    order_id_counter = 1

    for current_date in daterange(START_DATE, DAYS):
        weekday = current_date.weekday()
        in_super_sale = any(start <= current_date <= end for (start, end) in sale_periods)

        for shop in shops:
            shop_id = shop["shop_id"]

            level = random.choices(["small", "normal", "hot"], weights=[0.4, 0.4, 0.2])[0]
            if level == "small":
                base_exp = {"search": (300, 800), "short_video": (300, 800), "live": (100, 300)}
            elif level == "normal":
                base_exp = {"search": (800, 3000), "short_video": (1000, 5000), "live": (300, 1000)}
            else:
                base_exp = {"search": (3000, 8000), "short_video": (5000, 15000), "live": (1000, 5000)}

            shop_skus = skus_by_shop[shop_id]

            for channel in ["search", "short_video", "live"]:
                if channel == "search":
                    account_type = "merchant_self"
                    creator_level = None
                elif channel == "short_video":
                    account_type = "koc_creator"
                    creator_level = min(8, max(1, int(random.gauss(3, 1.5))))
                else:
                    account_type = random.choices(["agency_official", "merchant_self"], weights=[0.7, 0.3])[0]
                    creator_level = None

                exp_low, exp_high = base_exp[channel]
                exposure = random.randint(exp_low, exp_high)

                if channel == "short_video" and weekday in video_boost_weekdays:
                    exposure = int(exposure * 1.8)
                if channel == "live" and weekday in live_boost_weekdays:
                    exposure = int(exposure * random.uniform(2.5, 3.0))
                if in_super_sale:
                    if channel == "short_video":
                        exposure = int(exposure * 2.0)
                    elif channel == "search":
                        exposure = int(exposure * 1.5)

                if channel == "search":
                    ctr = random.uniform(0.08, 0.12)
                elif channel == "short_video":
                    ctr = random.uniform(0.03, 0.08)
                else:
                    ctr = random.uniform(0.01, 0.03)

                clicks = int(exposure * ctr)

                if channel == "search":
                    detail_rate = 0.6
                elif channel == "short_video":
                    detail_rate = 0.4
                else:
                    detail_rate = 0.35
                detail_views = int(clicks * detail_rate)

                cursor.execute(
                    traffic_insert_sql,
                    (
                        current_date, shop_id, channel, account_type, creator_level,
                        exposure, clicks, detail_views
                    )
                )

                base_min, base_max = base_conv[channel]
                conv_rate = random.uniform(base_min, base_max)

                if channel == "short_video" and weekday in video_boost_weekdays:
                    conv_rate *= 1.5
                if channel == "live" and weekday in live_boost_weekdays:
                    conv_rate *= 1.8
                if in_super_sale and channel == "short_video":
                    conv_rate *= 1.3

                expected_orders = detail_views * conv_rate
                num_orders = random.randint(max(0, int(expected_orders * 0.5)), int(expected_orders * 1.5) + 1)

                for _ in range(num_orders):
                    sku = random.choice(shop_skus)

                    original_price = sku["original_price"]
                    deal_price = sku["deal_price"]

                    merchant_discount = d_round(deal_price * sku["merchant_discount_rate"])
                    if in_super_sale and sku["is_activity_sku"]:
                        platform_subsidy = sku["platform_subsidy_cap"]
                    else:
                        platform_subsidy = random.uniform(0, sku["platform_subsidy_cap"])
                    platform_subsidy = d_round(platform_subsidy)

                    user_pay = max(0.01, deal_price - merchant_discount - platform_subsidy)
                    user_pay = d_round(user_pay)

                    pay_time = random_time_on_day(current_date)

                    p_writeoff = writeoff_rate[channel]
                    is_writeoff = random.random() < p_writeoff

                    if is_writeoff:
                        writeoff_status = 1
                        r = random.random()
                        if r < 0.4:
                            delay_days = 0
                        elif r < 0.7:
                            delay_days = random.randint(1, 3)
                        elif r < 0.9:
                            delay_days = random.randint(4, 7)
                        else:
                            delay_days = random.randint(8, 15)

                        writeoff_time = pay_time + timedelta(days=delay_days)
                        writeoff_gmv = user_pay

                        refund_status = 0
                        refund_time = None
                        refund_amount = 0.0
                        refund_reason = None
                    else:
                        writeoff_status = 0
                        writeoff_time = None
                        writeoff_gmv = 0.0

                        refund_status = 1
                        refund_time = pay_time + timedelta(days=random.randint(0, 7))
                        refund_amount = user_pay
                        refund_reason = "未到店自动退款"

                    user_id = random.randint(1, 200000)

                    cursor.execute(
                        order_insert_sql,
                        (
                            order_id_counter, shop_id, sku["sku_id"], user_id,
                            channel, account_type,
                            d_round(original_price), d_round(deal_price),
                            d_round(merchant_discount), d_round(platform_subsidy), d_round(user_pay),
                            pay_time,
                            writeoff_status, writeoff_time,
                            refund_status, refund_time, d_round(refund_amount),
                            d_round(writeoff_gmv), refund_reason
                        )
                    )

                    key = (current_date, shop_id)
                    if key not in metrics_daily:
                        metrics_daily[key] = {
                            "pay_gmv": 0.0,
                            "writeoff_gmv": 0.0,
                            "refund_amount": 0.0,
                            "commission": 0.0,
                            "payment_fee": 0.0,
                            "rebate_amount": 0.0,
                        }

                    metrics_daily[key]["pay_gmv"] += user_pay
                    metrics_daily[key]["writeoff_gmv"] += writeoff_gmv
                    metrics_daily[key]["refund_amount"] += refund_amount

                    commission = writeoff_gmv * 0.025
                    payment_fee = writeoff_gmv * 0.006
                    metrics_daily[key]["commission"] += commission
                    metrics_daily[key]["payment_fee"] += payment_fee

                    if shop_id in agreement_cum_writeoff:
                        agreement_cum_writeoff[shop_id] += writeoff_gmv

                    order_id_counter += 1

        conn.commit()

        # 达标当天一次性返佣入账（简化）
        for sid, cum_gmv in agreement_cum_writeoff.items():
            if rebate_posted[sid]:
                continue
            info = agreement_shop_info[sid]
            target = info["agreement_target"]
            rate = info["agreement_rebate_rate"]
            if target and cum_gmv >= target:
                key = (current_date, sid)
                if key not in metrics_daily:
                    metrics_daily[key] = {
                        "pay_gmv": 0.0,
                        "writeoff_gmv": 0.0,
                        "refund_amount": 0.0,
                        "commission": 0.0,
                        "payment_fee": 0.0,
                        "rebate_amount": 0.0,
                    }
                est_commission = cum_gmv * 0.025
                rebate = est_commission * float(rate)
                metrics_daily[key]["rebate_amount"] += rebate
                rebate_posted[sid] = True

    # 05 metrics
    metric_insert_sql = """
        INSERT INTO `05_douyin_shop_metric`
        (`date`, shop_id,
         pay_gmv, writeoff_gmv, refund_amount,
         commission, payment_fee, rebate_amount,
         settlement_amount, writeoff_rate, refund_rate)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
    """

    for (d, shop_id), m in metrics_daily.items():
        pay_gmv = m["pay_gmv"]
        writeoff_gmv = m["writeoff_gmv"]
        refund_amount = m["refund_amount"]
        commission = m["commission"]
        payment_fee = m["payment_fee"]
        rebate_amount = m["rebate_amount"]

        settlement_amount = writeoff_gmv - commission - payment_fee - refund_amount + rebate_amount

        if pay_gmv > 0:
            writeoff_rate_v = writeoff_gmv / pay_gmv
            refund_rate_v = refund_amount / pay_gmv
        else:
            writeoff_rate_v = 0.0
            refund_rate_v = 0.0

        cursor.execute(
            metric_insert_sql,
            (
                d, shop_id,
                d_round(pay_gmv),
                d_round(writeoff_gmv),
                d_round(refund_amount),
                d_round(commission),
                d_round(payment_fee),
                d_round(rebate_amount),
                d_round(settlement_amount),
                d_round(writeoff_rate_v, 4),
                d_round(refund_rate_v, 4),
            )
        )

    conn.commit()
    cursor.close()
    conn.close()
    print("Done. v1.0 data generated.")


if __name__ == "__main__":
    main()
