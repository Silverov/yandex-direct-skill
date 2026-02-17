---
name: direct
description: >
  Yandex Direct (API v5) advertising audit, management, and optimization.
  Full account audits, campaign management, keyword operations, reporting,
  budget analysis, and optimization recommendations for Russian market PPC.
  Triggers on: "Яндекс Директ", "Yandex Direct", "директ", "РСЯ", "YAN",
  "direct audit", "direct campaigns", "direct report", "direct optimize".
argument-hint: "audit | campaigns | create | keywords | report | optimize | budget | negative"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - WebFetch
---

# Yandex Direct — PPC Audit & Management (API v5)

**Authors:** Nick Serebrov & Kobe 🐍

Full-cycle Yandex Direct management: account audits, campaign CRUD, keyword
management, reporting, optimization, and budget analysis.

## Quick Reference

| Command | What it does |
|---------|-------------|
| `/direct audit` | Full account audit (all campaigns), scoring 0-100 |
| `/direct campaigns` | List campaigns with statuses and key metrics |
| `/direct create` | Create campaign (Search/YAN) with ad groups, keywords, ads |
| `/direct keywords` | Keyword management (list, add, update bids, pause) |
| `/direct report` | Performance stats (CTR, CPC, conversions, spend) |
| `/direct optimize` | Optimization recommendations (pause losers, adjust bids) |
| `/direct budget` | Budget spend analysis and forecasting |
| `/direct negative` | Negative keyword management (campaign & shared sets) |

## API Configuration

Credentials: `~/.secrets/yandex-direct.json`
```json
{ "client_id": "...", "client_secret": "...", "oauth_token": "..." }
```

Endpoint: `https://api.direct.yandex.com/json/v5/`
Auth: `Authorization: Bearer {oauth_token}`

API wrapper script: `scripts/yd-api.sh`

## Orchestration Logic

### `/direct audit`
1. Load credentials from `~/.secrets/yandex-direct.json`
2. Fetch all campaigns via API (`campaigns` service)
3. Fetch ad groups, keywords, ads, sitelinks for each campaign
4. Run 50+ checks from `references/yandex-audit.md`
5. Score using `references/scoring-system.md`
6. Compare metrics against `references/benchmarks.md`
7. Generate report with grade (A-F), findings, and prioritized action plan

### `/direct campaigns`
1. Call `campaigns.get` with fields: Id, Name, Status, State, Statistics, DailyBudget, Strategy
2. Format table with status indicators
3. Show key metrics if available (impressions, clicks, spend)

### `/direct create`
1. Gather: campaign name, type (SEARCH/YAN), geo, budget, strategy
2. Create campaign via `campaigns.add`
3. Create ad groups via `adgroups.add`
4. Add keywords via `keywords.add`
5. Create ads via `ads.add` (TextAd for search, TextImageAd for YAN)
6. Add sitelinks and callouts

### `/direct keywords`
1. Fetch keywords via `keywords.get` with campaign/adgroup filter
2. Operations: add, suspend, resume, update bids, delete
3. Show quality metrics where available

### `/direct report`
1. Use Reports service (`/json/v5/reports`)
2. Build TSV report request with selected fields
3. Available presets: campaign, adgroup, keyword, search_query
4. Date ranges: today, yesterday, last7, last30, custom
5. Parse and format results

### `/direct optimize`
1. Run report for last 30 days
2. Identify: zero-conversion keywords (spend > 2x avg CPA), low CTR ads, expensive placements
3. Cross-reference with `references/benchmarks.md`
4. Generate recommendations sorted by impact
5. Apply 3x Kill Rule: flag anything with CPA > 3x target

### `/direct budget`
1. Fetch campaign budgets and daily spend
2. Calculate run rate, projected monthly spend
3. Flag underspending (< 70% of budget) and overspending campaigns
4. Budget sufficiency check vs strategy requirements

### `/direct negative`
1. Fetch negative keywords at campaign and ad group level
2. Fetch shared negative keyword sets (`negativekeywordsharedsets`)
3. Analyze search query report for new negatives
4. Add/remove negatives via API

## Quality Gates

- Never recommend broad match keywords without auto-strategy (Yandex best practice)
- 3x Kill Rule: flag keywords/groups with CPA > 3x target for pause
- Budget sufficiency: daily budget should support ≥10 clicks at current CPC
- Moderation: always check ad moderation status before optimizing
- Learning phase: don't change strategy settings during first 7 days
- UTM: all ads must have UTM parameters for Metrika attribution

## Reference Files

Load on-demand, NOT at startup:

- `references/yandex-audit.md` — 50+ audit checks (YD01-YD55)
- `references/scoring-system.md` — Weighted scoring (0-100, grades A-F)
- `references/benchmarks.md` — Russian market benchmarks (CTR, CPC, CVR)
- `references/bidding-strategies.md` — Yandex Direct bidding strategy guide
- `references/compliance.md` — Yandex moderation rules & ad policies
- `references/image-specs.md` — Image sizes and specs for YAN (RSY) ads

## Scripts

- `scripts/yd-api.sh` — Generic API v5 call wrapper
- `scripts/yd-report.sh` — Reports service wrapper
- `scripts/yd-audit.sh` — Automated audit data collection

## Subagents

- `agents/audit-yandex.md` — Audit subagent for parallel campaign analysis
