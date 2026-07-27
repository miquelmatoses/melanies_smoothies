# Cosuno drill set: construction tendering marketplace

Schema deliberately mirrors what Cosuno actually is: general contractors publish
tenders, subcontractors get invited, invitations convert to bids, one bid wins.
Plus a SaaS subscription table and a raw event log.

**Setup (2 minutes, then never touch it again)**

```bash
pip install duckdb
python -c "import duckdb; duckdb.connect('drill.db').execute(open('cosuno_drill_seed.sql').read())"
duckdb drill.db
```

All SQL below is written in strict PostgreSQL-compatible syntax so it transfers
to the real challenge. If you have Postgres handy, `psql -f cosuno_drill_seed.sql` works too.

**Tables**

| table | grain | notes |
|---|---|---|
| `companies` | one row per company | `company_type` is `gc` or `sub` |
| `projects` | one row per project | owned by a GC, `budget_eur` has NULLs |
| `tenders` | one row per tender | `published_at` NULL when status = draft |
| `invitations` | tender x subcontractor | `opened_at` / `responded_at` nullable |
| `bids` | one row per bid | contains 38 planted duplicates |
| `subscriptions` | one row per subscription segment | gaps and reactivations present |
| `events` | raw event log | for sessionisation and streaks |

**How to use this**

Set a timer per question. If you blow through the target time, stop, look at the
solution, close it, and rewrite the query from scratch without looking. Rewriting
from memory is what builds the reflex. Reading solutions builds nothing.

Say the plan out loud in English before you type. That is half of what Bruno is grading.

---

## Level 1: warm-up, no thinking allowed (3 min each)

**1.** Count companies by `company_type` and `country`. Order by type, then count descending.

**2.** Top 10 projects by budget, excluding projects with no budget. Include the GC's name.

**3.** Number of tenders published per month. Drafts do not count.

**4.** Per trade: tender count, and average number of days between publication and deadline. Only trades with at least 20 tenders.

---

## Level 2: joins and conditional aggregation (5 to 7 min each)

**5.** Invitation funnel per trade: invitations sent, opened, responded, open rate, and response-rate-of-opened. One row per trade.

**6.** Per GC: number of projects, number of tenders, number of awarded tenders, and award rate. GCs with zero tenders must still appear.

**7.** Ghost rate: per subcontractor, how many invitations they received and how many of those they never bid on. Only subs with 20+ invitations. Order by ghost rate descending.

**8.** Per trade: count, min, average and max of winning bid amounts only.

---

## Level 3: window functions (7 to 10 min each)

**9.** For every tender with at least 2 bids, return the cheapest bid and the runner-up side by side, with the percentage spread between them. Order by spread descending, top 20.

**10.** Per GC, tenders published per month plus a running cumulative total.

**11.** Per subcontractor: number of bids, average days between consecutive bids, and their longest silence. Top 15 by longest silence.

**12.** Top 3 subcontractors by number of wins in each region. Handle ties explicitly and be ready to say aloud why you chose `DENSE_RANK` over `ROW_NUMBER`.

---

## Level 4: the stuff that actually separates people (10 to 15 min each)

**13.** The `bids` table contains exact duplicate rows. Find how many, then write the query that returns the deduplicated table keeping the lowest `bid_id`.

**14.** Monthly signup cohorts: for each cohort month, cohort size, and the number and percentage of companies with an active subscription 0 to 6 months later. You will need a month spine.

**15.** MRR waterfall by month: new, expansion, contraction, and total MRR. Say out loud which category reactivations are landing in with your logic, and whether that is correct.

**16.** For each tender, the first subcontractor to respond and how many hours after publication that happened. Top 20 fastest.

---

## Level 5: brutal (15 to 25 min each)

**17.** Sessionise the event log. A new session starts after 30 minutes of inactivity for the same `user_id`. Return total sessions, average events per session, and average session length in minutes.

**18.** Gaps and islands: for each company, find the longest unbroken run of consecutive calendar days with at least one event. Return the company, the streak start, end, and length.

**19.** Subscription segments overlap and have gaps. Merge them into continuous active blocks, treating gaps of 30 days or less as continuous. Per company return: number of active blocks, number of real churn episodes, and total active days.

**20.** For each month, the trade with the highest invitation response rate (minimum 15 invitations that month), its rate, and whether it held the top spot from the previous month.

---

## Python tasks (the challenge has one, do all three)

**P1.** Connect to the database, pull the `bids` table into pandas, and return a DataFrame with one row per trade containing bid count, median amount, and the interquartile range. Do the aggregation in pandas, not SQL.

**P2.** Write a function `funnel(conn, trade=None)` that returns invitations sent, opened, responded and the two conversion rates, optionally filtered to one trade. Handle the case where the trade does not exist without raising.

**P3.** Pull invitations and bids, and reconstruct per subcontractor: invitations, bids, wins, win rate, and average days from invitation to bid. Merge in pandas. Watch the join key: it is the pair `(tender_id, sub_company_id)`, not either column alone.

---

## Timing rehearsal (days 8 and 9)

Pick 3 SQL questions from Level 3 or 4 plus one Python task. 50 minutes total,
timer visible, no AI, narrating in English throughout. Read all four first, order
them by points per minute, and do the cheap ones first. That triage habit is worth
more points on the day than any single query you can write.
