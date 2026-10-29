# Part B: Analysis and commercial recommendation

*Data: Olist Brazilian e-commerce marketplace, from Sept 2016 to Aug 2018 (about 99,000 orders). Figures come from the dbt marts (`fct_order_items`, `dim_customers`); queries are in `sql/analytics_queries.sql`. Amounts are in Brazilian reais (R$).*

## B1. Commercial insights

### Insight 1: Late deliveries are the most evident driver of unsatisfied customers

**Finding 1.** Customers whose order arrives after the promised date rate Olist far lower, and the longer the delay, the worse the score.

| Delivery vs promised date | Orders | Average review (1 to 5) | Share giving 1 or 2 stars |
|---------------------------|--------|-------------------------|---------------------------|
| On time or early          | 89,443 | 4.29                    | 9.3%                      |
| Late by 1 to 3 days       | 1,852  | 3.29                    | 32.1%                     |
| Late by 4 to 7 days       | 1,748  | 2.10                    | 67.7%                     |
| Late by 8+ days           | 2,781  | 1.70                    | 79.3%                     |

About 6.7% of delivered orders (i.e. 6,381 of 95,824 with a review) arrive late. Even a delay of a few days costs around one full star. The problem is concentrated by region: the share of items delivered late is 4.4% in Sao Paulo (state SP) but 11.6% in Rio de Janeiro, 17.9% in Maranhao and 20.8% in Alagoas, and average review scores follow the same pattern (4.18 in SP, 3.87 in RJ, 3.82 in Alagoas).

**Method.** Delivered orders were grouped by how many days after the estimated delivery date they arrived (one row per order), then average review score and the share of 1 to 2 star reviews were compared across groups.

**Why a stakeholder should care.** A late first delivery is the worst possible start to a customer relationship, and it is concentrated in a handful of states where fixing carriers or resetting delivery promises would pay off. The next check would be to test whether customers with late deliveries also rebuy less.

### Insight 2: Almost nobody buys twice

**Finding 2.** Of 94,983 customers, only 2,887 (3.04%) placed a second order. About 97% buy once and never return.

**Method.** Orders were counted per real customer (i.e. `customer_unique_id`). Olist issues a new `customer_id` for every order, so counting that would incorrectly show no repeat buyers. Cancelled and unavailable orders were also excluded.

**Why a stakeholder should care.** Monthly orders grew from about 790 in January 2017 to about 7,200 in January 2018, and then stayed flat at roughly 6,100 to 7,200 a month through August 2018. With growth flattening, getting customers to come back is a boost.

## B2. Recommendation: a “second order” offer for happy first-time customers

**Target segment.** Customers with exactly one order whose delivery arrived on or before the promised date and who did not leave a 1 or 2 star review. They are identified from the marts by counting orders per `customer_key` in `fct_order_items`, then filtering on `is_late` and `review_score`. Late-delivered customers are deliberately excluded: a discount on top of a bad experience is the wrong tool (see: next steps).

**Mechanic.** About two weeks after delivery, send an email or SMS message offering 10% off their next order, valid for 30 days, one use per customer.

**Expected commercial impact (rough, per monthly cohort of new customers).**

| Assumption or step                                              | Value                                                                     | Source                                       |
|-----------------------------------------------------------------|---------------------------------------------------------------------------|----------------------------------------------|
| Orders per month (Jan to Aug 2018 average)                      | about 6,700                                                               | Data                                         |
| Share of customers eligible (93% on time, 91% not 1 to 2 stars) | about 85%, so about 5,700 customers                                       | Data                                         |
| Baseline chance of a second order                               | 3%                                                                        | Data (a floor, see B3)                       |
| Lift from the offer                                             | +2 percentage points                                                      | **Assumption**                               |
| Average order value                                             | R$140                                                                    | Data (2018 monthly average R$126 to R$146) |
| Cost of offer                                                   | 10% = R$14 per redeemed order, paid by all redeemers (5% of 5,700 = 285) | Assumption                                   |

- Extra customers who buy again: 5,700 x 2% = **114**
- Gross extra revenue: 114 x R$140 = about R$16,000
- Discount given away: 285 x R$14 = about R$4,000
- **Net extra revenue: about R$12,000 per monthly cohort**, or about R$144,000 over 12 cohorts (roughly 1.3% of annualised sales of about R$11 million)
- Sensitivity: a +1 point lift gives about R$5,000 per cohort; a +3 point lift gives about R$19,000.

This is revenue, not profit, and the lift is an assumption to be tested, not a finding in this assessment.

**Measurement.** Each month, randomly split the eligible customers 50/50 into an offer group and a holdout group that gets nothing. After 8 weeks, compare:

- Primary: share who placed a second order (offer group vs holdout)
- Net revenue per customer after discount
- Guardrails: review score on the second order and total discount cost

About 1,500 customers per group is enough to detect a move from 3% to 5% (80% power, 5% significance), and one month of eligible customers gives about 2,850 per group. We compare against the holdout, not against last month, because seasonality (for example the November peak) would otherwise distort the result. Roll out if net revenue per customer is higher in the offer group.

**Next steps.** Run a separate service-recovery test (apology plus a voucher) for late-delivered customers, and review delivery promises in the slowest states.

## B3. Assumptions, caveats and data quality

**Assumptions about the messy parts of the data**

- **Customer identity:** `customer_id` is per order; the real person is `customer_unique_id`. Anyone who used two accounts cannot be matched.
- **Duplicates:** order ids are unique. Review ids are not (814 extra rows; 547 orders have more than one review). The model keeps one row per (review_id, order_id) and the fact table uses the latest review per order.
- **Order status:** cancelled and unavailable orders are excluded from the sales trend and repeat rate; the delivery and state analyses use delivered orders only.
- **“Late”** means after the estimated delivery date that was set at purchase, which is a promise, not an objective standard.
- **Partial months:** September to October 2016, December 2016 and September 2018 contain a handful of orders, and November 2016 is missing. Month-on-month growth for these months is meaningless (the query shows huge percentages), so trend conclusions use January 2017 to August 2018.

**What I would flag to a client as a limitation, not present with false precision**

- The campaign uplift is an assumption. The data supports the size of the audience and the baseline, not the effect of an offer.
- The 3% repeat rate is a floor: the data covers only two years, so recent customers have had little time to return.
- Late delivery and low reviews are associated, not proven causal: late orders cluster in remote states and certain sellers, so part of the gap may be product or seller quality.
- All figures are revenue, not profit, across a marketplace of many sellers rather than one retailer.

**Top 3 data quality checks for production**

1. **Key integrity on every build.** dbt `unique`, `not_null`, `relationships` and `accepted_values` tests (order status, review score 1 to 5) on every key, run on each pull request and daily. A failure stops the build so bad data is never published.
2. **Freshness and volume on raw data.** dbt source freshness on `_loaded_at` (warn at 24 hours, error at 48) plus a daily row-count check against the trailing average (alert beyond about +/-30%), to catch silent stops and partial loads.
3. **Reconciliation and business rules.** Fact-table row count and revenue must equal staging (checked manually here: 112,650 rows and R$13,591,643.70), plus rules such as no negative prices, delivery never before purchase, and no order without items, using `dbt_utils` and `dbt_expectations`.

## B4. Client memo

**Subject: Olist order data: what was built and what to do next**

I took Olist’s raw order files, loaded them into Snowflake, and built clean, tested tables with dbt. Every figure below comes from those tables, and row counts match the source files exactly.

Two findings stand out. First, 97% of customers buy only once; just 3.0% ever return. Second, late deliveries wreck satisfaction: orders arriving on time average 4.3 stars, while orders more than a week late average 1.7. About 7% of delivered orders arrive late.

Recommendation: send customers who received their first order on time, and were not unhappy, a 10% offer on a second order, and hold back a random 50% as a comparison group. We estimate each monthly cohort adds roughly R$12,000 net revenue (range R$5,000 to R$19,000), based on an assumed two-point lift in repeat purchasing. That lift is an assumption, so the test will tell us the real figure within eight weeks.

Next step: approve the test. Late-delivery customers should be handled separately through service recovery.

*(WC: 171)*

## B5. LLM use case (bonus)

**Classify review comments into complaint themes with Snowflake Cortex.** Many 1 to 2 star reviews carry free-text comments in Portuguese that nobody reads at scale. A Cortex function would classify each comment into a fixed list of themes (late delivery, damaged item, wrong item, product quality, seller communication, other) and store the label in a table next to `stg_order_reviews`.

- **Example prompt:** “What are the top complaint themes in 1 to 2 star reviews for electronics in Rio de Janeiro last quarter?”
- **Data retrieved:** review comments joined to `fct_order_items` for category, state and date.
- **Output:** a theme count table and a one-line summary per theme, with example comment ids for checking.
- **Main risk:** misclassification or invented themes, plus cost and personal data in free text. **Mitigation:** constrain the model to the fixed theme list, check a labelled sample (say 200 comments) before trusting it, classify each review only once (in increments) then store the result, and mask names or phone numbers before the text goes to the actual model.
