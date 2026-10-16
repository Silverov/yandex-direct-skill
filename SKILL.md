---
name: direct
description: >
  Yandex Direct (API v5/v501) advertising audit, management, and optimization for
  Unified Performance Campaigns (ЕПК) and combinatorial ads. Full account audits,
  campaign management, keyword and autotargeting operations, reports with Metrika goals,
  weekly budget analysis, and optimization recommendations for Russian market PPC.
  Triggers on: "Яндекс Директ", "Yandex Direct", "директ", "ЕПК", "РСЯ", "YAN",
  "direct audit", "direct campaigns", "direct report", "direct optimize".
argument-hint: "audit | campaigns | create | keywords | report | optimize | budget | negative"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - WebFetch
---

# Yandex Direct — PPC Audit & Management (API v5 / v501)

**Authors:** Nick Serebrov & Kobe 🐍
**Version:** 2.0.1 — актуально на октябрь 2026

Full-cycle Yandex Direct management: account audits, campaign CRUD, keyword
management, reporting, optimization, and budget analysis.

## Quick Reference

| Command | What it does |
|---------|-------------|
| `/direct audit` | Full account audit (all campaigns), scoring 0-100 |
| `/direct campaigns` | List campaigns with type, strategy, weekly budget and stats |
| `/direct create` | Create a Unified Performance Campaign with groups, keywords, combinatorial ads |
| `/direct keywords` | Keywords and autotargeting (list, add, bids, categories, pause) |
| `/direct report` | Performance stats by priority Metrika goals (CTR, CPC, CPA, spend) |
| `/direct optimize` | Optimization recommendations (pause losers, adjust bids and limits) |
| `/direct budget` | Weekly budget spend analysis and forecasting |
| `/direct negative` | Negative keywords (campaign, group, shared sets) from search queries |

## What changed in Direct (know this before acting)

| Date | Change | Consequence for the agent |
|------|--------|---------------------------|
| 2023-11 → 2024 | Unified Performance Campaign (`UNIFIED_CAMPAIGN`, ЕПК) replaced text-image, dynamic and smart-banner campaigns | Read `UnifiedCampaignFieldNames`; search and YAN live in one campaign — split stats by `AdNetworkType` |
| 2024-07-01 | Manual bids in YAN disabled | Manual strategy (`HIGHEST_POSITION`) is search-only |
| 2025-06, 2025-09 | New strategies: `AVERAGE_CPA_MULTIPLE_GOALS`, `PAY_FOR_CONVERSION_MULTIPLE_GOALS`, `MAX_PROFIT` | See `references/bidding-strategies.md` |
| 2025-11-13 | `bidmodifiers.toggle` removed | Use `set` (100 = off) or `delete` |
| 2026-03-20 | Combinatorial ads (`RESPONSIVE_AD`): up to 7 titles, 3 texts, 5 images, 6 videos | Request `ResponsiveAdFieldNames`, otherwise the API returns them as `TextAd` with only the first title/text/image |
| 2026-06-30 / 07-14 | Text-image ads in ЕПК are edit-only; existing ones converted to combinatorial | `ads.add` with `TextAd` creates `RESPONSIVE_AD`; `Title2` is merged into the title (≤ 56 chars) or lost |
| 2026-06-22 / 07-06 | Weekly budgets for manual-bid campaigns and shared account; up to 30% of unspent budget rolls over | Analyse `WeeklySpendLimit`, not a daily budget |
| 2026-03-01 | Russian language rules for consumer information | Flag foreign words without Russian equivalents in ads (`references/compliance.md`) |

## API Configuration

Credentials: `~/.secrets/yandex-direct.json` (`chmod 600`)
```json
{ "client_id": "...", "client_secret": "...", "oauth_token": "...", "client_login": "optional-for-agency" }
```

- Endpoint: `https://api.direct.yandex.com/json/v5/<service>`; Unified-campaign structures
  (`UnifiedCampaign`, `UnifiedAdGroup`, `ShoppingAd`, `ListingAd`) in `add`/`update` go to `/json/v501/` —
  `scripts/yd-api.sh` routes them automatically.
- Auth: `Authorization: Bearer {oauth_token}`; agency or representative access: `Client-Login: {client_login}`.
- Sandbox: `YD_SANDBOX=1`. Env overrides: `YD_TOKEN`, `YD_CLIENT_LOGIN`, `YD_API_VERSION`, `YD_SECRETS`.
- Money in API requests and responses is in micro-units (× 1 000 000). Reports use rubles
  (`returnMoneyInMicros: false`).

API limits that break naive requests:
- `adgroups.get`, `keywords.get`, `ads.get`, `bidmodifiers.get`: `CampaignIds` ≤ 10 per request, `AdGroupIds` ≤ 1000.
- Every `get` returns ≤ 10 000 objects; continue with `Page.Offset` = `LimitedBy`.
- `negativekeywordsharedsets.get`: `Ids` ≤ 30; omit `SelectionCriteria` to get all sets. Same for `sitelinks.get`.
- `ads.get`: `TextAdFieldNames` has `AdExtensions`, not `AdExtensionIds` (that is a filter / an `add` field).
- Reports: `Goals` ≤ 10; `AttributionModels` only `AUTO`, `LSCCD`, `FCCD`, `LC`; ≤ 5 offline reports in queue.
- `keywords.get`: `Productivity` is always `null`; `AutotargetingCategories` is deprecated — use
  `AutotargetingSettings` (`AutotargetingSettingsCategoriesFieldNames`, `AutotargetingSettingsBrandOptionsFieldNames`).

Troubleshooting:
- Empty HTTP 204 to every request, even with a wrong token → the Direct API is turned off on Yandex's side
  (e.g. the special mode after the October 2026 data-center incident: only the web interface and the mobile app
  work, see https://yandex.ru/support/direct/ru/special-mode). Not a token, IP or script problem — wait, and
  meanwhile use the web interface for read-only checks.
- `yd-audit.sh` says «no campaigns found» → all campaigns may be archived; rerun with `--include-archived`
  (the script prints the archived count when it can).
- The campaigns grid labels strategies «Оптимизация кликов» / «Оптимизация конверсий»; the API type is in
  `BiddingStrategyType` (see `references/bidding-strategies.md`).

## Safety rule for changes

Every write call (`add`, `update`, `delete`, `suspend`, `resume`, `archive`, `moderate`, bids, `set`)
is made only after the user approved that exact change: show the request JSON (or a readable diff of
what changes) and wait for an explicit yes. Audit, report and optimize are read-only.

## Orchestration Logic

### `/direct audit`
1. Run `scripts/yd-audit.sh <dir>` — collects all objects (chunked by 10 campaigns, paginated) and 4 reports
   for the last 30 days using the campaigns' priority goals (`--goals` to override).
2. Read `<dir>/summary.json`: errors, campaign and ad types, goals used.
3. Hand the directory to `agents/audit-yandex.md` (or run its steps): 55 checks from
   `references/yandex-audit.md`, scoring from `references/scoring-system.md`.
4. Report in Russian: grade (A–F), findings, Quick Wins, prioritized action plan.

### `/direct campaigns`
1. `campaigns.get`: `FieldNames` Id, Name, Type, State, Status, StatusClarification, Statistics;
   `UnifiedCampaignFieldNames` and `TextCampaignFieldNames`: BiddingStrategy, PriorityGoals, CounterIds.
2. Table: type, state, search/network strategy, weekly limit (`WeeklySpendLimit` / 1 000 000), goals.
3. Spend and conversions — from `scripts/yd-report.sh campaign --by-network --goals <priority goals>`.

### `/direct create`
1. Gather: name, geo, weekly budget, strategy and goal, landing URL, keywords, 3–7 titles, 2–3 texts, images.
2. `adimages.add` (base64, `Type: AUTO`) → image hashes; see `references/image-specs.md`.
3. `campaigns.add` with `UnifiedCampaign` (v501): `BiddingStrategy.Search/Network`, `CounterIds`,
   `PriorityGoals`, `Settings` (`ADD_METRICA_TAG`, `ENABLE_SITE_MONITORING`), `TrackingParams` with UTM.
4. `adgroups.add` with `UnifiedAdGroup` (v501): `RegionIds`, negatives.
5. `keywords.add`: phrases and/or `---autotargeting` with `AutotargetingSettings` (categories, brand options).
6. `sitelinks.add` (up to 8 per set) and `adextensions.add` (CALLOUT).
7. `ads.add` with `ResponsiveAd`: `Titles`, `Texts`, `Href`, `AdImageHashes`, `SitelinkSetId`, `AdExtensionIds`,
   `BusinessId` if there is a Yandex Business profile. Do not use `TextImageAd` for this — it is an image-only banner.
8. `ads.moderate` — only after the user reviewed the drafts.

### `/direct keywords`
1. `keywords.get` by `AdGroupIds` or ≤ 10 `CampaignIds`; include `ServingStatus` and autotargeting settings.
2. Operations: add, suspend, resume, delete, bids (`keywordbids.set` with manual strategy), autotargeting categories.
3. Performance — `scripts/yd-report.sh criteria` (`Criterion`, `CriterionType`), not the deprecated `Productivity`.

### `/direct report`
1. `scripts/yd-report.sh <preset>`: account, campaign, adgroup, ad, criteria, search_query, placement, custom.
2. Always pass `--goals` with priority goals (from `campaigns.get` → `PriorityGoals`): without it conversions
   are summed over ALL Metrika goals, including micro-goals.
3. For Unified campaigns add `--by-network` to separate search and YAN.
4. Dates: `--from/--to` (default: 30 days ending yesterday) or `--period LAST_7_DAYS`. Offline reports are polled
   automatically (`retryIn` header).

### `/direct optimize`
1. Reports for 30 days with goals: criteria, search_query, placement, campaign `--by-network`.
2. Find: conditions and queries with spend > 2× target CPA and no conversions; YAN placements to exclude;
   network vs search CPA gap inside one campaign; groups with `RARELY_SERVED`; rejected ad elements.
3. Compare with the account's own medians first, then `references/benchmarks.md`.
4. Recommendations sorted by impact; 3× Kill Rule: flag anything with CPA > 3× target.
5. Do not touch strategy, its spend-limit type or payment model during learning (`references/bidding-strategies.md`).

### `/direct budget`
1. Weekly limits from `BiddingStrategy.*.WeeklySpendLimit` (or `CustomPeriodBudget` for flights).
2. Spend by day — `yd-report.sh campaign --daily --from <Monday>`; run rate and weekly forecast.
3. Flag: limit hit before the end of the week; spend < 70% of the limit; pay-per-conversion budget < 10 × CPA;
   weekly budget < 300 ₽. Unspent budget of CPC campaigns rolls over (up to 30%) since 06.07.2026.

### `/direct negative`
1. Campaign and group negatives (`NegativeKeywords`) and shared sets (`negativekeywordsharedsets.get`, all sets).
2. `yd-report.sh search_query --goals …` → irrelevant queries with spend and no conversions.
3. Propose negatives (campaign level or shared set); apply via `campaigns.update` / `negativekeywordsharedsets.update`
   after approval.

## Quality Gates

- Write operations only after explicit approval of the exact change.
- Conversion analysis only on priority goals; never on the all-goals sum.
- 3× Kill Rule: flag keywords/groups/placements with CPA > 3× target for pause.
- Strategy learning: goal ≥ 10 conversions a week; don't change strategy, spend-limit type or payment model
  in the first 2–3 weeks; a pause > 7 days restarts learning.
- Budget: weekly budget ≥ 300 ₽; pay-per-conversion ≥ 10 × CPA.
- Moderation: check `Status`/`StatusClarification` of ads and of each combinatorial element before optimizing.
- Tracking: `ADD_METRICA_TAG` on, UTM via `TrackingParams` (campaign or group) or in `Href`.

## Reference Files

Load on-demand, NOT at startup:

- `references/yandex-audit.md` — 55 audit checks (YD01-YD55) with data sources
- `references/scoring-system.md` — Weighted scoring (0-100, grades A-F)
- `references/benchmarks.md` — How to compare metrics; rough Russian market references
- `references/bidding-strategies.md` — ЕПК strategies ↔ API, weekly budgets, learning, bid modifiers
- `references/compliance.md` — Yandex moderation rules, ad marking, Russian language rules
- `references/image-specs.md` — Images and video for combinatorial ads

## Scripts

- `scripts/yd-api.sh` — Generic API call wrapper (v5/v501 routing, Client-Login, item-level error detection)
- `scripts/yd-report.sh` — Reports wrapper (presets, goals, attribution, offline polling)
- `scripts/yd-audit.sh` — Automated audit data collection (all objects + 4 reports)

Requirements: `bash`, `curl`, `jq`.

## Subagents

- `agents/audit-yandex.md` — Audit subagent for parallel campaign analysis
