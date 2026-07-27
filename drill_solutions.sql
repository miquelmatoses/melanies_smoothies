-- ##1
SELECT company_type, country, COUNT(*) AS n
FROM companies
GROUP BY company_type, country
ORDER BY company_type, n DESC;

-- ##2
SELECT p.project_id, p.name, c.name AS gc_name, p.budget_eur
FROM projects p
JOIN companies c ON c.company_id = p.gc_company_id
WHERE p.budget_eur IS NOT NULL
ORDER BY p.budget_eur DESC
LIMIT 10;

-- ##3
SELECT date_trunc('month', published_at) AS month, COUNT(*) AS tenders
FROM tenders
WHERE published_at IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- ##4
SELECT trade,
       COUNT(*) AS tenders,
       ROUND(AVG(deadline_at - published_at), 1) AS avg_window_days
FROM tenders
WHERE published_at IS NOT NULL
GROUP BY trade
HAVING COUNT(*) >= 20
ORDER BY tenders DESC;

-- ##5
SELECT t.trade,
       COUNT(*) AS sent,
       COUNT(i.opened_at) AS opened,
       COUNT(i.responded_at) AS responded,
       ROUND(100.0 * COUNT(i.opened_at) / COUNT(*), 1) AS open_rate,
       ROUND(100.0 * COUNT(i.responded_at) / NULLIF(COUNT(i.opened_at), 0), 1) AS resp_of_open
FROM invitations i
JOIN tenders t ON t.tender_id = i.tender_id
GROUP BY t.trade
ORDER BY sent DESC;

-- ##6
SELECT c.company_id, c.name,
       COUNT(DISTINCT p.project_id) AS projects,
       COUNT(t.tender_id) AS tenders,
       COUNT(*) FILTER (WHERE t.status = 'awarded') AS awarded,
       ROUND(100.0 * COUNT(*) FILTER (WHERE t.status = 'awarded')
             / NULLIF(COUNT(t.tender_id), 0), 1) AS award_rate
FROM companies c
JOIN projects p ON p.gc_company_id = c.company_id
LEFT JOIN tenders t ON t.project_id = p.project_id
WHERE c.company_type = 'gc'
GROUP BY c.company_id, c.name
ORDER BY award_rate DESC NULLS LAST;

-- ##7
SELECT c.company_id, c.name,
       COUNT(*) AS invitations_received,
       COUNT(*) FILTER (WHERE b.bid_id IS NULL) AS never_bid,
       ROUND(100.0 * COUNT(*) FILTER (WHERE b.bid_id IS NULL) / COUNT(*), 1) AS ghost_rate
FROM invitations i
JOIN companies c ON c.company_id = i.sub_company_id
LEFT JOIN bids b ON b.tender_id = i.tender_id AND b.sub_company_id = i.sub_company_id
GROUP BY c.company_id, c.name
HAVING COUNT(*) >= 20
ORDER BY ghost_rate DESC
LIMIT 15;

-- ##8
SELECT t.trade,
       COUNT(*) AS winning_bids,
       MIN(b.amount_eur) AS min_win,
       ROUND(AVG(b.amount_eur), 2) AS avg_win,
       MAX(b.amount_eur) AS max_win
FROM bids b
JOIN tenders t ON t.tender_id = b.tender_id
WHERE b.is_winner
GROUP BY t.trade
ORDER BY avg_win DESC;

-- ##9
WITH ranked AS (
  SELECT tender_id, sub_company_id, amount_eur,
         ROW_NUMBER() OVER (PARTITION BY tender_id ORDER BY amount_eur) AS rn,
         COUNT(*) OVER (PARTITION BY tender_id) AS n_bids
  FROM bids
)
SELECT w.tender_id, w.n_bids,
       w.sub_company_id AS winner_id, w.amount_eur AS winning_amount,
       r.sub_company_id AS runner_up_id, r.amount_eur AS runner_up_amount,
       ROUND(100.0 * (r.amount_eur - w.amount_eur) / w.amount_eur, 2) AS spread_pct
FROM ranked w
JOIN ranked r ON r.tender_id = w.tender_id AND r.rn = 2
WHERE w.rn = 1
ORDER BY spread_pct DESC
LIMIT 20;

-- ##10
SELECT p.gc_company_id,
       date_trunc('month', t.published_at) AS month,
       COUNT(*) AS tenders_month,
       SUM(COUNT(*)) OVER (PARTITION BY p.gc_company_id
                           ORDER BY date_trunc('month', t.published_at)) AS running_total
FROM tenders t
JOIN projects p ON p.project_id = t.project_id
WHERE t.published_at IS NOT NULL
GROUP BY p.gc_company_id, 2
ORDER BY p.gc_company_id, month;

-- ##11
WITH gaps AS (
  SELECT sub_company_id, submitted_at,
         LAG(submitted_at) OVER (PARTITION BY sub_company_id ORDER BY submitted_at) AS prev_bid
  FROM bids
)
SELECT sub_company_id,
       COUNT(*) AS bids,
       ROUND(AVG(EXTRACT(EPOCH FROM (submitted_at - prev_bid)) / 86400.0), 1) AS avg_gap_days,
       ROUND(MAX(EXTRACT(EPOCH FROM (submitted_at - prev_bid)) / 86400.0), 1) AS max_gap_days
FROM gaps
WHERE prev_bid IS NOT NULL
GROUP BY sub_company_id
ORDER BY max_gap_days DESC
LIMIT 15;

-- ##12
WITH wins AS (
  SELECT pr.region, b.sub_company_id, COUNT(*) AS win_count
  FROM bids b
  JOIN tenders t ON t.tender_id = b.tender_id
  JOIN projects pr ON pr.project_id = t.project_id
  WHERE b.is_winner
  GROUP BY pr.region, b.sub_company_id
), ranked AS (
  SELECT w.*, c.name,
         DENSE_RANK() OVER (PARTITION BY region ORDER BY win_count DESC) AS rnk
  FROM wins w JOIN companies c ON c.company_id = w.sub_company_id
)
SELECT region, name, win_count, rnk
FROM ranked
WHERE rnk <= 3
ORDER BY region, rnk;

-- ##13
WITH dupes AS (
  SELECT bid_id,
         ROW_NUMBER() OVER (PARTITION BY tender_id, sub_company_id, amount_eur, submitted_at
                            ORDER BY bid_id) AS rn
  FROM bids
)
SELECT COUNT(*) AS duplicate_rows FROM dupes WHERE rn > 1;

-- ##14
WITH cohort AS (
  SELECT company_id, date_trunc('month', signed_up_at) AS cohort_month
  FROM companies
), sizes AS (
  SELECT cohort_month, COUNT(*) AS cohort_size FROM cohort GROUP BY cohort_month
), active AS (
  SELECT s.company_id, m.month
  FROM subscriptions s
  CROSS JOIN generate_series(DATE '2024-01-01', DATE '2026-06-01', INTERVAL '1 month') AS m(month)
  WHERE m.month >= date_trunc('month', s.started_on)
    AND (s.ended_on IS NULL OR m.month <= date_trunc('month', s.ended_on))
  GROUP BY s.company_id, m.month
), grid AS (
  SELECT c.cohort_month,
         z.cohort_size,
         (EXTRACT(YEAR FROM a.month) * 12 + EXTRACT(MONTH FROM a.month))
       - (EXTRACT(YEAR FROM c.cohort_month) * 12 + EXTRACT(MONTH FROM c.cohort_month)) AS months_since,
         COUNT(DISTINCT a.company_id) AS still_active
  FROM cohort c
  JOIN sizes z ON z.cohort_month = c.cohort_month
  JOIN active a ON a.company_id = c.company_id AND a.month >= c.cohort_month
  GROUP BY c.cohort_month, z.cohort_size, 3
)
SELECT cohort_month, cohort_size, months_since, still_active,
       ROUND(100.0 * still_active / cohort_size, 1) AS retention_pct
FROM grid
WHERE months_since <= 6
ORDER BY cohort_month, months_since;

-- ##15
WITH mrr AS (
  SELECT m.month, s.company_id, SUM(s.mrr_eur) AS mrr
  FROM generate_series(DATE '2024-01-01', DATE '2026-06-01', INTERVAL '1 month') AS m(month)
  JOIN subscriptions s
    ON m.month >= date_trunc('month', s.started_on)
   AND (s.ended_on IS NULL OR m.month <= date_trunc('month', s.ended_on))
  GROUP BY m.month, s.company_id
), joined AS (
  SELECT month, company_id, mrr,
         LAG(mrr) OVER (PARTITION BY company_id ORDER BY month) AS prev_mrr,
         LAG(month) OVER (PARTITION BY company_id ORDER BY month) AS prev_month
  FROM mrr
)
SELECT month,
       SUM(CASE WHEN prev_mrr IS NULL THEN mrr ELSE 0 END) AS new_mrr,
       SUM(CASE WHEN prev_mrr IS NOT NULL AND mrr > prev_mrr THEN mrr - prev_mrr ELSE 0 END) AS expansion,
       SUM(CASE WHEN prev_mrr IS NOT NULL AND mrr < prev_mrr THEN mrr - prev_mrr ELSE 0 END) AS contraction,
       SUM(mrr) AS total_mrr
FROM joined
GROUP BY month
ORDER BY month;

-- ##16
WITH first_resp AS (
  SELECT i.tender_id, i.sub_company_id, i.responded_at,
         ROW_NUMBER() OVER (PARTITION BY i.tender_id ORDER BY i.responded_at) AS rn
  FROM invitations i
  WHERE i.responded_at IS NOT NULL
)
SELECT f.tender_id, f.sub_company_id,
       ROUND(EXTRACT(EPOCH FROM (f.responded_at - t.published_at::TIMESTAMP)) / 3600.0, 1) AS hours_to_first_response
FROM first_resp f
JOIN tenders t ON t.tender_id = f.tender_id
WHERE f.rn = 1
ORDER BY hours_to_first_response
LIMIT 20;

-- ##17
WITH marked AS (
  SELECT user_id, occurred_at,
         LAG(occurred_at) OVER (PARTITION BY user_id ORDER BY occurred_at) AS prev_at
  FROM events
), flagged AS (
  SELECT user_id, occurred_at,
         CASE WHEN prev_at IS NULL
                OR occurred_at - prev_at > INTERVAL '30 minutes'
              THEN 1 ELSE 0 END AS is_new_session
  FROM marked
), sessions AS (
  SELECT user_id, occurred_at,
         SUM(is_new_session) OVER (PARTITION BY user_id ORDER BY occurred_at
                                   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS session_id
  FROM flagged
), agg AS (
  SELECT user_id, session_id,
         COUNT(*) AS events_in_session,
         EXTRACT(EPOCH FROM (MAX(occurred_at) - MIN(occurred_at))) / 60.0 AS minutes
  FROM sessions
  GROUP BY user_id, session_id
)
SELECT COUNT(*) AS sessions,
       ROUND(AVG(events_in_session), 2) AS avg_events,
       ROUND(AVG(minutes), 2) AS avg_minutes
FROM agg;

-- ##18
WITH days AS (
  SELECT DISTINCT company_id, CAST(occurred_at AS DATE) AS d
  FROM events
), grouped AS (
  SELECT company_id, d,
         d - CAST(ROW_NUMBER() OVER (PARTITION BY company_id ORDER BY d) AS INTEGER) AS grp
  FROM days
), streaks AS (
  SELECT company_id, grp, MIN(d) AS streak_start, MAX(d) AS streak_end, COUNT(*) AS streak_days
  FROM grouped
  GROUP BY company_id, grp
)
SELECT company_id, streak_start, streak_end, streak_days
FROM (
  SELECT s.*, ROW_NUMBER() OVER (PARTITION BY company_id ORDER BY streak_days DESC, streak_start) AS rn
  FROM streaks s
) x
WHERE rn = 1
ORDER BY streak_days DESC
LIMIT 15;

-- ##19
WITH norm AS (
  SELECT company_id, started_on,
         COALESCE(ended_on, DATE '2026-07-25') AS ended_on
  FROM subscriptions
), marked AS (
  SELECT company_id, started_on, ended_on,
         MAX(ended_on) OVER (PARTITION BY company_id ORDER BY started_on
                             ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS prev_max_end
  FROM norm
), flagged AS (
  SELECT *, CASE WHEN prev_max_end IS NULL OR started_on > prev_max_end + 30
                 THEN 1 ELSE 0 END AS new_block
  FROM marked
), blocked AS (
  SELECT *, SUM(new_block) OVER (PARTITION BY company_id ORDER BY started_on
                                 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS block_id
  FROM flagged
), merged AS (
  SELECT company_id, block_id, MIN(started_on) AS block_start, MAX(ended_on) AS block_end
  FROM blocked
  GROUP BY company_id, block_id
)
SELECT company_id,
       COUNT(*) AS active_blocks,
       COUNT(*) - 1 AS churn_episodes,
       SUM(block_end - block_start) AS total_active_days
FROM merged
GROUP BY company_id
ORDER BY churn_episodes DESC, total_active_days DESC
LIMIT 15;

-- ##20
WITH monthly AS (
  SELECT date_trunc('month', t.published_at) AS month,
         t.trade,
         COUNT(*) AS sent,
         COUNT(i.responded_at) AS responded
  FROM invitations i
  JOIN tenders t ON t.tender_id = i.tender_id
  WHERE t.published_at IS NOT NULL
  GROUP BY 1, 2
  HAVING COUNT(*) >= 15
), rates AS (
  SELECT month, trade,
         ROUND(100.0 * responded / sent, 1) AS response_rate,
         RANK() OVER (PARTITION BY month ORDER BY 1.0 * responded / sent DESC) AS rnk
  FROM monthly
), best AS (
  SELECT month, trade, response_rate,
         LAG(trade) OVER (ORDER BY month) AS prev_best_trade
  FROM rates
  WHERE rnk = 1
)
SELECT month, trade AS best_trade, response_rate,
       CASE WHEN prev_best_trade = trade THEN 'held' ELSE 'changed' END AS vs_prev_month
FROM best
ORDER BY month;
