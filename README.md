# 🎯 Yandex Direct Skill — AI Agent for PPC Management

**The first open-source skill for managing Yandex Direct via AI agents.**

> **v2.0 (October 2026):** updated for Unified Performance Campaigns (ЕПК), combinatorial ads, weekly budgets and the current API. See [Changelog](#-changelog).

Audit, create, optimize, and report on Yandex Direct campaigns — all through natural language commands. Built for [OpenClaw](https://github.com/openclaw/openclaw) and compatible AI agent frameworks.

**Authors:** [Nick Serebrov](https://t.me/nick_kobe_ai) & Kobe 🐍

---

## ✨ Features

| Command | Description |
|---------|-------------|
| `/direct audit` | Full account audit — 55 checks, scoring 0-100, grades A-F |
| `/direct campaigns` | List campaigns with statuses and metrics |
| `/direct create` | Create a Unified Performance Campaign with groups, keywords and combinatorial ads |
| `/direct keywords` | Keywords and autotargeting (add, pause, bids, categories) |
| `/direct report` | Performance stats by priority Metrika goals (CTR, CPC, CPA, spend) |
| `/direct optimize` | Optimization recommendations (pause losers, adjust bids) |
| `/direct budget` | Weekly budget spend analysis and forecasting |
| `/direct negative` | Negative keyword management |

## 🔍 Audit System

55 checks across 6 categories:

- **Conversions & Metrika** (25%) — tracking setup, goals, attribution
- **Wasted Spend / Negatives** (20%) — negative keywords, search query analysis
- **Account Structure** (15%) — campaign organization, naming, geo split
- **Keywords & Autotargeting** (15%) — operators, autotargeting categories, CTR vs account median
- **Ads & Extensions** (15%) — moderation, combinatorial ads, images, sitelinks, callouts, ad marking
- **Settings & Targeting** (10%) — geo, bidding strategy, bid modifiers

Scoring: weighted algorithm → 0-100 score → grade A through F.

## 📦 What's Inside

```
├── SKILL.md                          # Main skill file (agent instructions)
├── references/
│   ├── yandex-audit.md               # 55 audit checks (YD01-YD55) with data sources
│   ├── scoring-system.md             # Weighted scoring algorithm
│   ├── benchmarks.md                 # How to compare metrics + rough market references
│   ├── bidding-strategies.md         # ЕПК strategies ↔ API, weekly budgets, bid modifiers
│   ├── compliance.md                 # FZ-38, ad marking, Russian language rules
│   └── image-specs.md                # Images and video for combinatorial ads
├── scripts/
│   ├── yd-api.sh                     # API v5/v501 wrapper (Client-Login, auto v501 routing)
│   ├── yd-report.sh                  # Reports: presets, Metrika goals, offline polling
│   └── yd-audit.sh                   # Audit data collection (chunked, paginated, 4 reports)
└── agents/
    └── audit-yandex.md               # Audit subagent instructions
```

## 🚀 Quick Start

### 1. Get API Access

Apply for Yandex Direct API access at [direct.yandex.ru](https://direct.yandex.ru) → API settings.

### 2. Get OAuth Token

```
https://oauth.yandex.ru/authorize?response_type=token&client_id=YOUR_CLIENT_ID
```

### 3. Save Credentials

```bash
cat > ~/.secrets/yandex-direct.json << 'EOF'
{
  "client_id": "your_client_id",
  "client_secret": "your_client_secret",
  "oauth_token": "your_oauth_token",
  "client_login": "optional: client login for agency accounts"
}
EOF
chmod 600 ~/.secrets/yandex-direct.json
```

### 4. Install Skill

Clone the repository into your agent's skills directory (requires `bash`, `curl`, `jq`):

```bash
# OpenClaw
git clone https://github.com/Silverov/yandex-direct-skill ~/clawd/skills/direct

# Claude Code
git clone https://github.com/Silverov/yandex-direct-skill ~/.claude/skills/direct
```

### 5. Run Audit

Tell your agent: "Run a Yandex Direct audit" — and watch the magic happen.

## 📊 Russian Market Benchmarks

Rough references for the Russian PPC market (no official source — the audit compares with the account's own medians first):

| Metric | Search | YAN (RSY) |
|--------|--------|-----------|
| CTR | 5-8% | 0.3-0.8% |
| CPC | 30-150₽ | 5-30₽ |
| CVR | 2-5% | 0.5-2% |

Benchmarks vary by industry — see `references/benchmarks.md` for full data.

## 📝 Changelog

### v2.0 — October 2026
- **Fixed:** `yd-api.sh` appended an extra `}` to every params argument (`${3:-{}}`), so no request with parameters could run.
- **Fixed:** audit requests rejected by the API: `AdExtensionIds` in `TextAdFieldNames`, empty `SelectionCriteria` for sitelinks and negative keyword sets, more than 10 `CampaignIds` per request; no pagination.
- **Fixed:** reports were not polled (`retryIn` is an HTTP header) and got a new name on every retry; conversions were summed over all Metrika goals — now priority goals and attribution are passed.
- **New:** Unified Performance Campaigns (`UnifiedCampaignFieldNames`, v501 routing), combinatorial ads (`ResponsiveAdFieldNames`), autotargeting settings, bid modifiers, callouts; `Client-Login`; `summary.json`.
- **Updated:** audit checklist (search/YAN split is no longer Critical, no Google-style Quality Score, combinatorial ads, Yandex Business profile instead of vCard, weekly budgets), current strategies (multi-goal, «Максимум прибыли»), bid modifier ranges, image specs, Russian language rules from 01.03.2026.
- **Safety:** write operations only after the user approves the exact change.

## 🏗 Origin Story

This skill was born in one evening. We needed to set up Yandex Direct campaigns for [stepback.ru](https://stepback.ru). After creating campaigns via API in 3 minutes, we found [claude-ads](https://github.com/AgriciDaniel/claude-ads) — a great skill for Google/Meta/LinkedIn ads, but with zero Yandex support. So we built our own, ran an audit on our account (Grade D → C+), and fixed the issues on the spot.

## 📄 License

MIT — use it, fork it, improve it.

---

# 🎯 Яндекс Директ Скилл — AI-агент для управления рекламой

**Первый open-source скилл для управления Яндекс Директом через AI-агентов.**

> **v2.0 (октябрь 2026):** обновлён под Единую перфоманс-кампанию (ЕПК), комбинаторные объявления, недельные бюджеты и текущий API. См. [историю изменений](#-история-изменений).

Аудит, создание, оптимизация и отчёты по кампаниям Яндекс Директа — всё через команды на естественном языке. Создан для [OpenClaw](https://github.com/openclaw/openclaw) и совместимых AI-агентных фреймворков.

**Авторы:** [Ник Серебров](https://t.me/nick_kobe_ai) & Коби 🐍

---

## ✨ Возможности

| Команда | Описание |
|---------|----------|
| `/direct audit` | Полный аудит аккаунта — 55 проверок, оценка 0-100, грейды A-F |
| `/direct campaigns` | Список кампаний со статусами и метриками |
| `/direct create` | Создание ЕПК с группами, фразами и комбинаторными объявлениями |
| `/direct keywords` | Фразы и автотаргетинг |
| `/direct report` | Статистика по приоритетным целям Метрики (CTR, CPC, CPA, расход) |
| `/direct optimize` | Рекомендации по оптимизации |
| `/direct budget` | Анализ недельного бюджета |
| `/direct negative` | Управление минус-словами |

## 🔍 Система аудита

55 проверок по 6 категориям:

- **Конверсии и Метрика** (25%) — настройка целей, атрибуция, трекинг
- **Слив бюджета / минус-слова** (20%) — минус-слова, анализ поисковых запросов
- **Структура аккаунта** (15%) — организация кампаний, именование, гео
- **Ключевые фразы и автотаргетинг** (15%) — операторы, категории автотаргетинга, CTR против медианы аккаунта
- **Объявления и расширения** (15%) — модерация, комбинаторные объявления, изображения, быстрые ссылки, уточнения, маркировка
- **Настройки и таргетинг** (10%) — гео, стратегии ставок, корректировки

Оценка: взвешенный алгоритм → балл 0-100 → грейд от A до F.

## 🚀 Быстрый старт

### 1. Получите доступ к API

Подайте заявку на доступ к API Яндекс Директа: [direct.yandex.ru](https://direct.yandex.ru) → Настройки API.

### 2. Получите OAuth-токен

```
https://oauth.yandex.ru/authorize?response_type=token&client_id=ВАШ_CLIENT_ID
```

### 3. Сохраните credentials

```bash
cat > ~/.secrets/yandex-direct.json << 'EOF'
{
  "client_id": "ваш_client_id",
  "client_secret": "ваш_client_secret",
  "oauth_token": "ваш_oauth_token",
  "client_login": "необязательно: логин клиента для агентского аккаунта"
}
EOF
chmod 600 ~/.secrets/yandex-direct.json
```

### 4. Установите скилл

Склонируйте репозиторий в директорию скиллов агента (нужны `bash`, `curl`, `jq`):

```bash
# OpenClaw
git clone https://github.com/Silverov/yandex-direct-skill ~/clawd/skills/direct

# Claude Code
git clone https://github.com/Silverov/yandex-direct-skill ~/.claude/skills/direct
```

### 5. Запустите аудит

Скажите агенту: «Проведи аудит Яндекс Директа» — и наблюдайте.

## 📝 История изменений

### v2.0 — октябрь 2026
- **Исправлено:** `yd-api.sh` дописывал лишнюю `}` к любым параметрам (`${3:-{}}`) — ни один запрос с параметрами не выполнялся.
- **Исправлено:** запросы аудита, которые отклонял API: `AdExtensionIds` в `TextAdFieldNames`, пустой `SelectionCriteria` у быстрых ссылок и наборов минус-фраз, больше 10 `CampaignIds` в запросе; не было постраничной выборки.
- **Исправлено:** отчёты не дожидались готовности (`retryIn` — HTTP-заголовок) и при повторе получали новое имя; конверсии суммировались по всем целям Метрики — теперь передаются приоритетные цели и модель атрибуции.
- **Добавлено:** ЕПК (`UnifiedCampaignFieldNames`, маршрутизация на v501), комбинаторные объявления (`ResponsiveAdFieldNames`), настройки автотаргетинга, корректировки ставок, уточнения; `Client-Login`; `summary.json`.
- **Обновлено:** чеклист аудита (разделение Поиск/РСЯ больше не Critical, нет «показателя качества» как в Google, комбинаторные объявления, профиль организации вместо визитки, недельные бюджеты), актуальные стратегии (по нескольким целям, «Максимум прибыли»), диапазоны корректировок, требования к изображениям, правила о русском языке с 01.03.2026.
- **Безопасность:** изменения в кабинете — только после подтверждения конкретного изменения пользователем.

## 🏗 История создания

Этот скилл родился за один вечер. Нам нужно было настроить кампании в Яндекс Директе для [stepback.ru](https://stepback.ru). После создания кампаний через API за 3 минуты мы нашли [claude-ads](https://github.com/AgriciDaniel/claude-ads) — отличный скилл для Google/Meta/LinkedIn, но без поддержки Яндекса. Поэтому мы создали свой, прогнали аудит на своём аккаунте (Грейд D → C+) и исправили проблемы на месте.

## 📄 Лицензия

MIT — используйте, форкайте, улучшайте.
