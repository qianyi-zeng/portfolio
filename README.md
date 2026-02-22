# 抖音本地生活（餐饮）数据体系构建与商业指标诊断

> **项目定位**：本项目数据模型与指标体系，完全基于一线操盘本地生活千万级流量盘子（曾推动单商家月均 GMV 0 突破 300 万）的真实业务逻辑进行逆向还原。旨在通过全链路数据仓库的搭建与 SQL 深度分析，直击商家“高曝光、低核销、高退款、隐性流失”的真实利润痛点。

**核心技术栈：** `MySQL (复杂窗口函数/多表联结)` | `Python (Pandas/ETL)` | `漏斗模型` | `T+1复盘机制`
**完整业务文档：** [docs/P1_case_brief.md](docs/P1_case_brief.md)

---

## 核心商业洞察 (Executive Summary)

**洞察一：高 GMV 掩盖下的履约危机与“超卖”风险**
* **数据反馈：** 基于 `SQL06` 门店履约健康度四象限分析发现，部分头部门店虽然 GMV 贡献占比极高，但核销率仅为 XX%（远低于大盘均值 XX%），处于危险的“高 GMV - 低核销”象限。
* **业务诊断与动作：** 存在严重的线下承载力不足与超卖客诉风险。建议针对该象限商家触发风控预警，实行线上流量熔断机制，并立即派单给线下 BD 介入排查门店接待负荷。

**洞察二：退款结构畸形与渠道流量的“无效狂欢”**
* **数据反馈：** 结合 `SQL04` (退款率结构) 与 `SQL08` (流量到支付漏斗) 显示，XX 渠道带来的流量支付转化率虽高，但 T+7 未核销退款率高达 XX%。
* **业务诊断与动作：** 该渠道流量多为“冲动型秒杀”，用户留存极差。建议优化前端达人带货话术，从“倒计时逼单”向“实景探店种草”转型，预计可挽回约 XX% 的真实核销利润。

**洞察三：结算模式对平台利润的隐性侵蚀**
* **数据反馈：** 通过 `SQL10` 与 `SQL11` 对比连锁门店与单店的业绩及结算差异，发现非协议结算商家隐性流失成本较高，侵蚀平台抽佣净值。
* **业务诊断与动作：** 建议向高潜力的非协议单店倾斜精准补贴（如：定向下发流量券），推动其向连锁协议结算模式转化，以提升全盘结算质量。

---

## 核心分析模块与 SQL 战役 (Analytical Framework)

本项目摒弃了无效的“跑库”动作，将 11 段深度 SQL 划分为三大直击业务痛点的分析战役：

### 战役 1：履约风控与商家分层 (Fulfillment & Risk)
* `SQL06_shop_fulfillment_quadrant.sql`：门店履约健康度四象限切分 (GMV × 核销率)
* `SQL04_refund_rate_structure.sql`：退款率结构拆解
* `SQL07_q2_root_cause_writeoff_delay_refund.sql`：核销延迟与退款的根本原因深挖

### 战役 2：流量漏斗与转化诊断 (Traffic & Conversion)
* `SQL08_channel_funnel_traffic_to_pay.sql`：渠道从流量曝光到支付的漏斗诊断
* `SQL02_channel_writeoff_rate.sql`：渠道最终核销率对比
* `SQL09_sku_pricing_activity_effect.sql`：SKU 定价策略与促销活动效用分析
* `SQL03_channel_aov.sql` & `SQL05_channel_shop_gmv_contribution.sql`：渠道客单价与 GMV 贡献度监控

### 战役 3：利润守护与结算质量 (Settlement & Revenue)
* `SQL10_agreement_vs_non_agreement_settlement.sql`：协议结算与非协议结算对比
* `SQL11_chain_vs_single_shop_performance.sql`：连锁品牌与单店业绩异动追踪
* `SQL01_shop_daily_gmv_quality.sql`：单店日度 GMV 质量监控

---

## 附录：技术环境与快速复现 (Reproducible Quick Start)

* **环境要求：** MySQL database (`portfolio_db`)
* **执行步骤：**
  1. **构建数仓表结构：** 运行 `p1_sql_warehouse/ddl/create_table_01-05.sql` 创建基础 DDL。
  2. **生成业务模拟数据：** 运行 Python 脚本 `p1_sql_warehouse/etl/generator.py`，完成 ETL 清洗并加载至 MySQL。
  3. **调用分析引擎：** 按需执行 `p1_sql_warehouse/analysis/` 目录下的 SQL 文件提取业务洞察。
