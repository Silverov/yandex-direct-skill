# 🎯 Yandex Direct Skill — AI Agent for PPC Management

**The first open-source skill for managing Yandex Direct via AI agents.**

Audit, create, optimize, and report on Yandex Direct campaigns — all through natural language commands. Built for [OpenClaw](https://github.com/openclaw/openclaw) and compatible AI agent frameworks.

**Authors:** [Nick Serebrov](https://t.me/nick_kobe_ai) & Kobe 🐍

---

## ✨ Features

| Command | Description |
|---------|-------------|
| `/direct audit` | Full account audit — 55 checks, scoring 0-100, grades A-F |
| `/direct campaigns` | List campaigns with statuses and metrics |
| `/direct create` | Create campaigns with ad groups, keywords, and ads |
| `/direct keywords` | Keyword management (add, pause, update bids) |
| `/direct report` | Performance stats (CTR, CPC, conversions, spend) |
| `/direct optimize` | Optimization recommendations (pause losers, adjust bids) |
| `/direct budget` | Budget spend analysis and forecasting |
| `/direct negative` | Negative keyword management |

## 🔍 Audit System

55 checks across 6 categories:

- **Conversions & Metrika** (25%) — tracking setup, goals, attribution
- **Wasted Spend / Negatives** (20%) — negative keywords, search query analysis
- **Account Structure** (15%) — campaign organization, naming, geo split
- **Keywords & Quality** (15%) — match types, quality score, relevance
- **Ads & Extensions** (15%) — moderation, sitelinks, callouts, images
- **Settings & Targeting** (10%) — geo, bidding strategy, bid modifiers

Scoring: weighted algorithm → 0-100 score → grade A through F.

## 📦 What's Inside

```
├── SKILL.md                          # Main skill file (agent instructions)
├── references/
│   ├── yandex-audit.md               # 55 audit checks (YD01-YD55)
│   ├── scoring-system.md             # Weighted scoring algorithm
│   ├── benchmarks.md                 # Russian market benchmarks (CTR, CPC, CVR)
│   ├── bidding-strategies.md         # Bidding strategy decision tree
│   ├── compliance.md                 # FZ-38, ad moderation rules
│   └── image-specs.md               # Image sizes for YAN (RSY) ads
├── scripts/
│   ├── yd-api.sh                     # Generic API v5 wrapper
│   ├── yd-report.sh                  # Reports service wrapper
│   └── yd-audit.sh                   # Automated audit data collection
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
  "oauth_token": "your_oauth_token"
}
EOF
chmod 600 ~/.secrets/yandex-direct.json
```

### 4. Install Skill

Copy the `yandex-direct` folder to your agent's skills directory:

```bash
# OpenClaw
cp -r yandex-direct ~/clawd/skills/

# Claude Code
cp -r yandex-direct ~/.claude/skills/
```

### 5. Run Audit

Tell your agent: "Run a Yandex Direct audit" — and watch the magic happen.

## 📊 Russian Market Benchmarks

Built-in benchmarks for the Russian PPC market:

| Metric | Search | YAN (RSY) |
|--------|--------|-----------|
| CTR | 5-8% | 0.3-0.8% |
| CPC | 30-150₽ | 5-30₽ |
| CVR | 2-5% | 0.5-2% |

Benchmarks vary by industry — see `references/benchmarks.md` for full data.

## 🏗 Origin Story

This skill was born in one evening. We needed to set up Yandex Direct campaigns for [stepback.ru](https://stepback.ru). After creating campaigns via API in 3 minutes, we found [claude-ads](https://github.com/AgriciDaniel/claude-ads) — a great skill for Google/Meta/LinkedIn ads, but with zero Yandex support. So we built our own, ran an audit on our account (Grade D → C+), and fixed the issues on the spot.

## 📄 License

MIT — use it, fork it, improve it.

---

# 🎯 Яндекс Директ Скилл — AI-агент для управления рекламой

**Первый open-source скилл для управления Яндекс Директом через AI-агентов.**

Аудит, создание, оптимизация и отчёты по кампаниям Яндекс Директа — всё через команды на естественном языке. Создан для [OpenClaw](https://github.com/openclaw/openclaw) и совместимых AI-агентных фреймворков.

**Авторы:** [Ник Серебров](https://t.me/nick_kobe_ai) & Коби 🐍

---

## ✨ Возможности

| Команда | Описание |
|---------|----------|
| `/direct audit` | Полный аудит аккаунта — 55 проверок, оценка 0-100, грейды A-F |
| `/direct campaigns` | Список кампаний со статусами и метриками |
| `/direct create` | Создание кампаний с группами, ключами и объявлениями |
| `/direct keywords` | Управление ключевыми словами |
| `/direct report` | Статистика (CTR, CPC, конверсии, расход) |
| `/direct optimize` | Рекомендации по оптимизации |
| `/direct budget` | Анализ расхода бюджета |
| `/direct negative` | Управление минус-словами |

## 🔍 Система аудита

55 проверок по 6 категориям:

- **Конверсии и Метрика** (25%) — настройка целей, атрибуция, трекинг
- **Слив бюджета / минус-слова** (20%) — минус-слова, анализ поисковых запросов
- **Структура аккаунта** (15%) — организация кампаний, именование, гео
- **Ключевые слова и качество** (15%) — типы соответствия, показатель качества
- **Объявления и расширения** (15%) — модерация, быстрые ссылки, уточнения, изображения
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
  "oauth_token": "ваш_oauth_token"
}
EOF
chmod 600 ~/.secrets/yandex-direct.json
```

### 4. Установите скилл

Скопируйте папку `yandex-direct` в директорию скиллов вашего агента:

```bash
# OpenClaw
cp -r yandex-direct ~/clawd/skills/

# Claude Code
cp -r yandex-direct ~/.claude/skills/
```

### 5. Запустите аудит

Скажите агенту: «Проведи аудит Яндекс Директа» — и наблюдайте.

## 🏗 История создания

Этот скилл родился за один вечер. Нам нужно было настроить кампании в Яндекс Директе для [stepback.ru](https://stepback.ru). После создания кампаний через API за 3 минуты мы нашли [claude-ads](https://github.com/AgriciDaniel/claude-ads) — отличный скилл для Google/Meta/LinkedIn, но без поддержки Яндекса. Поэтому мы создали свой, прогнали аудит на своём аккаунте (Грейд D → C+) и исправили проблемы на месте.

## 📄 Лицензия

MIT — используйте, форкайте, улучшайте.
