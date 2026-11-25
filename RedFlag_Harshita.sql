-- =====================================================================
-- REDFLAG — THE FRAUD FILES
-- Fraud Detection using SQL
-- Student: Harshita Bhingare | Batch: DA-DS-1
-- Database: redflag | SQL  MySQL 8.0+
--
-- ===================================================================

USE redflag;


-- =====================================================================
-- P1 — VELOCITY FRAUD
-- Flag a user who makes 30 or more transactions on one calendar day.
-- Expected result: approximately 45–55 user-days.
-- =====================================================================

SELECT
    user_id,
    DATE(txn_time) AS attack_date,
    COUNT(DISTINCT txn_id) AS daily_txn_count
FROM transactions
GROUP BY user_id, DATE(txn_time)
HAVING COUNT(DISTINCT txn_id) >= 30
ORDER BY daily_txn_count DESC, user_id;



-- =====================================================================
-- P2 — ROUND-AMOUNT CLUSTERING
-- Flag users with 15 or more transactions at the specified exact amounts.
-- Expected result: 25 users.
-- =====================================================================

SELECT
    user_id,
    COUNT(*) AS round_amount_txn_count,
    SUM(amount) AS total_round_amount
FROM transactions
WHERE amount IN (100, 200, 500, 1000, 2000, 5000, 10000)
GROUP BY user_id
HAVING COUNT(*) >= 15
ORDER BY round_amount_txn_count DESC, user_id;



-- =====================================================================
-- P3 — CARD TESTING
-- Flag users with 30 or more transactions below Rs. 10 on one day.
-- Expected result: 20 users.
-- =====================================================================

SELECT
    user_id,
    DATE(txn_time) AS attack_date,
    COUNT(*) AS tiny_txn_count
FROM transactions
WHERE amount < 10
GROUP BY user_id, DATE(txn_time)
HAVING COUNT(*) >= 30
ORDER BY tiny_txn_count DESC, user_id;



-- =====================================================================
-- P4 — FAILED-THEN-SUCCEEDED
-- Advanced signature: at least 20 failed transactions each followed
-- within 2 minutes by a successful transaction of the same amount
-- by the same user.
-- Expected result: 25 users.
-- =====================================================================

SELECT
    f.user_id,
    COUNT(*) AS failed_then_succeeded_pairs
FROM transactions AS f
WHERE f.status = 'FAILED'
  AND EXISTS (
      SELECT 1
      FROM transactions AS s
      WHERE s.user_id = f.user_id
        AND s.status = 'SUCCESS'
        AND s.amount = f.amount
        AND s.txn_time > f.txn_time
        AND TIMESTAMPDIFF(SECOND, f.txn_time, s.txn_time) <= 120
  )
GROUP BY f.user_id
HAVING COUNT(*) >= 20
ORDER BY failed_then_succeeded_pairs DESC, f.user_id;



-- =====================================================================
-- P5 — ODD-HOUR CONCENTRATION
-- Flag users with at least 30 transactions where 80% or more occur
-- during hours 02, 03 or 04.
-- Expected result: 20 users.
-- =====================================================================

SELECT
    user_id,
    COUNT(*) AS total_txns,
    SUM(CASE WHEN HOUR(txn_time) BETWEEN 2 AND 4 THEN 1 ELSE 0 END)
        AS odd_hour_txns,
    ROUND(
        100.0 * SUM(CASE WHEN HOUR(txn_time) BETWEEN 2 AND 4 THEN 1 ELSE 0 END)
        / COUNT(*),
        2
    ) AS odd_hour_percentage
FROM transactions
GROUP BY user_id
HAVING COUNT(*) >= 30
   AND SUM(CASE WHEN HOUR(txn_time) BETWEEN 2 AND 4 THEN 1 ELSE 0 END)
       / COUNT(*) >= 0.80
ORDER BY odd_hour_percentage DESC, total_txns DESC;



-- =====================================================================
-- P6 — MULE ACCOUNTS
-- Advanced signature: at least 5 CREDIT transactions followed within
-- 30 minutes by a DEBIT of at least 70% of the CREDIT amount.
-- The brief describes incoming NETBANKING credits and outgoing UPI debits.
-- Expected result: 30 users.
-- =====================================================================

SELECT
    c.user_id,
    COUNT(*) AS credit_to_debit_matches
FROM transactions AS c
WHERE c.txn_type = 'CREDIT'
  AND c.payment_mode = 'NETBANKING'
  AND EXISTS (
      SELECT 1
      FROM transactions AS d
      WHERE d.user_id = c.user_id
        AND d.txn_type = 'DEBIT'
        AND d.payment_mode = 'UPI'
        AND d.txn_time > c.txn_time
        AND TIMESTAMPDIFF(MINUTE, c.txn_time, d.txn_time) <= 30
        AND d.amount >= 0.70 * c.amount
  )
GROUP BY c.user_id
HAVING COUNT(*) >= 5
ORDER BY credit_to_debit_matches DESC, c.user_id;



-- =====================================================================
-- P7 — REFUND ABUSE
-- Flag users with at least 20 transactions and a refund ratio above 40%.
-- Expected result: approximately 24–25 users.
-- =====================================================================

SELECT
    user_id,
    COUNT(*) AS total_txns,
    SUM(CASE WHEN txn_type = 'REFUND' THEN 1 ELSE 0 END) AS refund_txns,
    ROUND(
        100.0 * SUM(CASE WHEN txn_type = 'REFUND' THEN 1 ELSE 0 END)
        / COUNT(*),
        2
    ) AS refund_percentage
FROM transactions
GROUP BY user_id
HAVING COUNT(*) >= 20
   AND SUM(CASE WHEN txn_type = 'REFUND' THEN 1 ELSE 0 END) / COUNT(*) > 0.40
ORDER BY refund_percentage DESC, total_txns DESC;



-- =====================================================================
-- P8 — MERCHANT COLLUSION
-- Flag merchants where the top 5 users by transaction value contribute
-- more than 60% of the merchant's total transaction value.
-- Expected result: 15 merchants.
-- Requires MySQL 8.0+ (CTEs and ROW_NUMBER).
-- =====================================================================

WITH user_merchant_totals AS (
    SELECT
        merchant_id,
        user_id,
        SUM(amount) AS user_total
    FROM transactions
    GROUP BY merchant_id, user_id
),
ranked_users AS (
    SELECT
        merchant_id,
        user_id,
        user_total,
        ROW_NUMBER() OVER (
            PARTITION BY merchant_id
            ORDER BY user_total DESC, user_id
        ) AS user_rank
    FROM user_merchant_totals
),
top_five_totals AS (
    SELECT
        merchant_id,
        SUM(user_total) AS top_five_value
    FROM ranked_users
    WHERE user_rank <= 5
    GROUP BY merchant_id
),
merchant_totals AS (
    SELECT
        merchant_id,
        SUM(amount) AS merchant_total
    FROM transactions
    GROUP BY merchant_id
)
SELECT
    mt.merchant_id,
    mt.merchant_total,
    tf.top_five_value,
    ROUND(100.0 * tf.top_five_value / mt.merchant_total, 2)
        AS top_five_percentage
FROM merchant_totals AS mt
JOIN top_five_totals AS tf
    ON mt.merchant_id = tf.merchant_id
WHERE tf.top_five_value / mt.merchant_total > 0.60
ORDER BY top_five_percentage DESC, mt.merchant_id;



-- =====================================================================
-- P9 — JUST-UNDER-THRESHOLD (STRUCTURING)
-- Flag users with 10 or more transactions of exactly Rs. 9,999.
-- Expected result: 20 users.
-- =====================================================================

SELECT
    user_id,
    COUNT(*) AS threshold_txn_count,
    SUM(amount) AS total_threshold_value
FROM transactions
WHERE amount = 9999.00
GROUP BY user_id
HAVING COUNT(*) >= 10
ORDER BY threshold_txn_count DESC, user_id;


-- =====================================================================
-- P10 — DORMANT-THEN-ACTIVE
-- Flag users with a gap of at least 90 days between consecutive
-- transactions, followed by at least 15 transactions after that gap.
-- Requires MySQL 8.0+ (LAG).
-- =====================================================================

WITH ordered_transactions AS (
    SELECT
        user_id,
        txn_id,
        txn_time,
        LAG(txn_time) OVER (
            PARTITION BY user_id
            ORDER BY txn_time, txn_id
        ) AS previous_txn_time
    FROM transactions
),
dormancy_gaps AS (
    SELECT
        user_id,
        txn_time AS reactivation_time
    FROM ordered_transactions
    WHERE previous_txn_time IS NOT NULL
      AND TIMESTAMPDIFF(DAY, previous_txn_time, txn_time) >= 90
),
post_gap_activity AS (
    SELECT
        g.user_id,
        g.reactivation_time,
        COUNT(t.txn_id) AS transactions_after_gap
    FROM dormancy_gaps AS g
    JOIN transactions AS t
      ON t.user_id = g.user_id
     AND t.txn_time >= g.reactivation_time
    GROUP BY g.user_id, g.reactivation_time
)
SELECT
    user_id,
    reactivation_time,
    transactions_after_gap
FROM post_gap_activity
WHERE transactions_after_gap >= 15
ORDER BY transactions_after_gap DESC, user_id, reactivation_time;



-- =====================================================================
-- P11 — VELOCITY SPIKE
-- Flag users whose peak monthly transaction count is at least 5 times
-- their average monthly transaction count, with a peak of 20 or more.
-- The average below is across the six calendar months Jan–Jun 2024,
-- including zero-transaction months.
-- Requires MySQL 8.0+ (CTEs).
-- =====================================================================

WITH RECURSIVE months AS (
    SELECT CAST('2024-01-01' AS DATE) AS month_start
    UNION ALL
    SELECT DATE_ADD(month_start, INTERVAL 1 MONTH)
    FROM months
    WHERE month_start < '2024-06-01'
),
monthly_counts AS (
    SELECT
        u.user_id,
        m.month_start,
        COUNT(t.txn_id) AS monthly_txn_count
    FROM (SELECT DISTINCT user_id FROM transactions) AS u
    CROSS JOIN months AS m
    LEFT JOIN transactions AS t
      ON t.user_id = u.user_id
     AND t.txn_time >= m.month_start
     AND t.txn_time < DATE_ADD(m.month_start, INTERVAL 1 MONTH)
    GROUP BY u.user_id, m.month_start
),
user_monthly_stats AS (
    SELECT
        user_id,
        AVG(monthly_txn_count) AS average_monthly_txns,
        MAX(monthly_txn_count) AS peak_monthly_txns
    FROM monthly_counts
    GROUP BY user_id
)
SELECT
    user_id,
    ROUND(average_monthly_txns, 2) AS average_monthly_txns,
    peak_monthly_txns,
    ROUND(peak_monthly_txns / NULLIF(average_monthly_txns, 0), 2)
        AS peak_to_average_ratio
FROM user_monthly_stats
WHERE peak_monthly_txns >= 20
  AND peak_monthly_txns >= 5 * average_monthly_txns
ORDER BY peak_to_average_ratio DESC, peak_monthly_txns DESC;



-- =====================================================================
-- P12 — GEOGRAPHIC IMPOSSIBILITY
-- Flag users with consecutive transactions in different cities within
-- 60 minutes.
-- Requires MySQL 8.0+ (LAG).
-- Expected result: 15 users.
-- =====================================================================

WITH transaction_sequence AS (
    SELECT
        user_id,
        txn_id,
        city,
        txn_time,
        LAG(city) OVER (
            PARTITION BY user_id
            ORDER BY txn_time, txn_id
        ) AS previous_city,
        LAG(txn_time) OVER (
            PARTITION BY user_id
            ORDER BY txn_time, txn_id
        ) AS previous_txn_time
    FROM transactions
)
SELECT
    user_id,
    previous_city,
    city AS current_city,
    previous_txn_time,
    txn_time AS current_txn_time,
    TIMESTAMPDIFF(MINUTE, previous_txn_time, txn_time) AS minutes_apart
FROM transaction_sequence
WHERE previous_city IS NOT NULL
  AND city <> previous_city
  AND TIMESTAMPDIFF(MINUTE, previous_txn_time, txn_time) BETWEEN 0 AND 60
ORDER BY minutes_apart, user_id, current_txn_time;



-- =====================================================================
-- END OF REDFLAG DETECTION QUERIES
-- =====================================================================
