# cosuno-prep

Foodie-Fi (Danny Ma, 8 Week SQL Challenge case study #3) running on PostgreSQL 16
inside GitHub Codespaces. Same shape as the Cosuno live coding challenge.

## Setup, once

1. Create a new repo on GitHub and push this folder to it.
2. On the repo page: green **Code** button, **Codespaces** tab, **Create codespace on main**.
3. Wait for the container to build. It installs Python deps and loads the drill database.
4. Get the Foodie-Fi data:
   - Open https://8weeksqlchallenge.com/case-study-3/
   - Scroll to the embedded DB Fiddle, click **Edit on DB Fiddle**
   - Copy everything from the left-hand **Schema SQL** panel
   - Paste it into `seed/02_foodie_fi.sql`
   - In the Codespace terminal run: `bash .devcontainer/load.sh`

## Daily use

```bash
psql -d foodie_fi              # interactive shell
psql -d foodie_fi -f foodie_fi/q01.sql   # run one answer file
psql -d drill                  # the Cosuno-style marketplace drill set
```

Write each answer in `foodie_fi/qNN.sql`. Run it, check the output, move on.
Official solutions are behind Danny's paid course, but community solutions are on
GitHub if you need to check yourself. Check only after you have an answer.

## Two databases

- `foodie_fi` — Danny Ma case study, subscriptions and churn
- `drill` — construction tendering marketplace, 20 escalating exercises (see the exercises file)

## Rules while practising

- No AI. Not for hints, not for syntax.
- Timer on every question.
- Narrate in English while you type.
- After every join, check the row count did not multiply.
