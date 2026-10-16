#!/usr/bin/env bash
# yd-report.sh — Yandex Direct Reports API wrapper (TSV), with offline-report polling
#
# Usage: ./yd-report.sh <preset> [options]
#
# Presets:
#   account       ACCOUNT_PERFORMANCE_REPORT — totals for the account
#   campaign      CAMPAIGN_PERFORMANCE_REPORT
#   adgroup       ADGROUP_PERFORMANCE_REPORT
#   ad            AD_PERFORMANCE_REPORT
#   criteria      CRITERIA_PERFORMANCE_REPORT — keywords, autotargeting, audiences (alias: keyword)
#   search_query  SEARCH_QUERY_PERFORMANCE_REPORT — real search queries
#   placement     CUSTOM_REPORT by YAN placements (AdNetworkType = AD_NETWORK)
#   custom        CUSTOM_REPORT, fields from --fields
#
# Options:
#   --from YYYY-MM-DD       start date (default: 30 days before --to)
#   --to YYYY-MM-DD         end date (default: yesterday)
#   --period NAME           DateRangeType instead of dates: LAST_7_DAYS, LAST_30_DAYS, LAST_90_DAYS, ...
#   --goals ID[,ID...]      Metrika goal IDs (up to 10). Without goals, Conversions/CostPerConversion
#                           are summed over ALL goals — use only priority goals for CPA/CR analysis.
#   --attribution MODEL     AUTO | LSCCD | FCCD | LC (only with --goals; default: AUTO)
#   --campaigns ID[,ID...]  filter by CampaignId
#   --fields F1,F2,...      replace preset fields (required for 'custom')
#   --by-network            add AdNetworkType (search vs networks split, important for Unified campaigns)
#   --by-device             add Device
#   --daily                 add Date
#   --vat yes|no            include VAT in money fields (default: yes)
#   --mode auto|online|offline   processingMode header (default: auto)
#   --max-wait SECONDS      how long to poll an offline report (default: 600)
#   --out FILE              write TSV to FILE instead of stdout
#
# Environment: YD_SECRETS, YD_TOKEN, YD_CLIENT_LOGIN, YD_SANDBOX, YD_API_HOST — same as yd-api.sh
#
# Example: ./yd-report.sh search_query --from 2026-09-01 --to 2026-09-30 --goals 123456 --out sq.tsv

set -euo pipefail

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-1}"; }

SECRETS_FILE="${YD_SECRETS:-${HOME}/.secrets/yandex-direct.json}"
if [[ -n "${YD_API_HOST:-}" ]]; then
    API_HOST="${YD_API_HOST%/}"
elif [[ "${YD_SANDBOX:-0}" == "1" ]]; then
    API_HOST="https://api-sandbox.direct.yandex.com"
else
    API_HOST="https://api.direct.yandex.com"
fi
REPORTS_URL="${API_HOST}/json/v5/reports"

OAUTH_TOKEN="${YD_TOKEN:-}"
CLIENT_LOGIN="${YD_CLIENT_LOGIN:-}"
if [[ -f "$SECRETS_FILE" ]]; then
    [[ -z "$OAUTH_TOKEN" ]] && OAUTH_TOKEN=$(jq -r '.oauth_token // empty' "$SECRETS_FILE")
    [[ -z "$CLIENT_LOGIN" ]] && CLIENT_LOGIN=$(jq -r '.client_login // empty' "$SECRETS_FILE")
fi
if [[ -z "$OAUTH_TOKEN" ]]; then
    echo "ERROR: OAuth token not found (set YD_TOKEN or oauth_token in $SECRETS_FILE)" >&2
    exit 1
fi

# date helpers (GNU date or BSD/macOS date)
days_ago() { date -d "-$1 days" +%Y-%m-%d 2>/dev/null || date -v-"$1"d +%Y-%m-%d; }
shift_date() { date -d "$1 -$2 days" +%Y-%m-%d 2>/dev/null || date -j -v-"$2"d -f %Y-%m-%d "$1" +%Y-%m-%d; }

PRESET="${1:-}"
[[ -z "$PRESET" || "$PRESET" == "-h" || "$PRESET" == "--help" ]] && usage 0
shift

DATE_FROM="" DATE_TO="" PERIOD="" GOALS="" ATTRIBUTION="" CAMPAIGNS="" FIELDS_OVERRIDE=""
BY_NETWORK=0 BY_DEVICE=0 DAILY=0 VAT="YES" MODE="auto" MAX_WAIT=600 OUT=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --from) DATE_FROM="$2"; shift 2 ;;
        --to) DATE_TO="$2"; shift 2 ;;
        --period) PERIOD="$2"; shift 2 ;;
        --goals) GOALS="$2"; shift 2 ;;
        --attribution) ATTRIBUTION="$2"; shift 2 ;;
        --campaigns) CAMPAIGNS="$2"; shift 2 ;;
        --fields) FIELDS_OVERRIDE="$2"; shift 2 ;;
        --by-network) BY_NETWORK=1; shift ;;
        --by-device) BY_DEVICE=1; shift ;;
        --daily) DAILY=1; shift ;;
        --vat) VAT=$(echo "$2" | tr '[:lower:]' '[:upper:]'); shift 2 ;;
        --mode) MODE="$2"; shift 2 ;;
        --max-wait) MAX_WAIT="$2"; shift 2 ;;
        --out) OUT="$2"; shift 2 ;;
        # backward compatibility: yd-report.sh <preset> <date_from> <date_to>
        [0-9][0-9][0-9][0-9]-*) if [[ -z "$DATE_FROM" ]]; then DATE_FROM="$1"; else DATE_TO="$1"; fi; shift ;;
        *) echo "ERROR: unknown option '$1'" >&2; usage 1 ;;
    esac
done

METRICS='["Impressions","Clicks","Ctr","AvgCpc","Cost","Conversions","ConversionRate","CostPerConversion","Revenue"]'
FILTERS='[]'
case "$PRESET" in
    account)
        REPORT_TYPE="ACCOUNT_PERFORMANCE_REPORT"; DIMS='[]' ;;
    campaign)
        REPORT_TYPE="CAMPAIGN_PERFORMANCE_REPORT"; DIMS='["CampaignId","CampaignName","CampaignType"]' ;;
    adgroup)
        REPORT_TYPE="ADGROUP_PERFORMANCE_REPORT"; DIMS='["CampaignId","CampaignName","AdGroupId","AdGroupName"]' ;;
    ad)
        REPORT_TYPE="AD_PERFORMANCE_REPORT"; DIMS='["CampaignId","AdGroupId","AdId","AdFormat"]' ;;
    criteria|keyword)
        REPORT_TYPE="CRITERIA_PERFORMANCE_REPORT"
        DIMS='["CampaignId","CampaignName","AdGroupId","AdGroupName","CriterionId","Criterion","CriterionType"]' ;;
    search_query)
        REPORT_TYPE="SEARCH_QUERY_PERFORMANCE_REPORT"
        DIMS='["CampaignId","CampaignName","AdGroupId","AdGroupName","Query","CriterionId","Criterion","CriterionType"]'
        METRICS='["Impressions","Clicks","Ctr","AvgCpc","Cost","Conversions","CostPerConversion"]' ;;
    placement)
        REPORT_TYPE="CUSTOM_REPORT"; DIMS='["CampaignId","CampaignName","Placement"]'
        FILTERS='[{"Field":"AdNetworkType","Operator":"EQUALS","Values":["AD_NETWORK"]}]' ;;
    custom)
        REPORT_TYPE="CUSTOM_REPORT"; DIMS='[]'
        [[ -z "$FIELDS_OVERRIDE" ]] && { echo "ERROR: preset 'custom' requires --fields" >&2; exit 1; } ;;
    *)
        echo "ERROR: unknown preset '$PRESET'" >&2; usage 1 ;;
esac

if [[ "$REPORT_TYPE" == "SEARCH_QUERY_PERFORMANCE_REPORT" && $((BY_NETWORK + BY_DEVICE)) -gt 0 ]]; then
    echo "ERROR: AdNetworkType and Device are not available in SEARCH_QUERY_PERFORMANCE_REPORT" >&2; exit 1
fi

if [[ -n "$FIELDS_OVERRIDE" ]]; then
    FIELD_NAMES=$(jq -cn --arg f "$FIELDS_OVERRIDE" '$f | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))')
else
    FIELD_NAMES=$(jq -cn --argjson d "$DIMS" --argjson m "$METRICS" \
        --argjson net "$BY_NETWORK" --argjson dev "$BY_DEVICE" --argjson day "$DAILY" \
        '(if $day == 1 then ["Date"] else [] end) + $d
         + (if $net == 1 then ["AdNetworkType"] else [] end)
         + (if $dev == 1 then ["Device"] else [] end) + $m')
fi

if [[ -n "$CAMPAIGNS" ]]; then
    FILTERS=$(jq -cn --argjson f "$FILTERS" --arg c "$CAMPAIGNS" \
        '$f + [{"Field":"CampaignId","Operator":"IN","Values":($c | split(","))}]')
fi

if [[ -z "$PERIOD" ]]; then
    [[ -z "$DATE_TO" ]] && DATE_TO=$(days_ago 1)
    [[ -z "$DATE_FROM" ]] && DATE_FROM=$(shift_date "$DATE_TO" 29)
fi

GOALS_JSON='null'
if [[ -n "$GOALS" ]]; then
    GOALS_JSON=$(jq -cn --arg g "$GOALS" '$g | split(",") | map(select(length > 0))')
    if [[ $(jq 'length' <<< "$GOALS_JSON") -gt 10 ]]; then
        echo "ERROR: --goals accepts at most 10 goal IDs" >&2; exit 1
    fi
    [[ -z "$ATTRIBUTION" ]] && ATTRIBUTION="AUTO"
else
    case " $(jq -r '.[]' <<< "$FIELD_NAMES" | tr '\n' ' ') " in
        *" Conversions "*|*" CostPerConversion "*|*" ConversionRate "*)
            echo "NOTE: --goals not set — Conversions/CPA are summed over ALL Metrika goals (incl. micro-goals)." >&2 ;;
    esac
fi
if [[ -n "$ATTRIBUTION" && -z "$GOALS" ]]; then
    echo "ERROR: --attribution requires --goals" >&2; exit 1
fi

# ReportName must stay the same while polling one offline report, and be unique per parameter set
REPORT_NAME="yd-${PRESET}-$(date +%Y%m%d%H%M%S)-$$"

REQUEST_BODY=$(jq -n \
    --arg from "$DATE_FROM" --arg to "$DATE_TO" --arg period "$PERIOD" \
    --argjson filters "$FILTERS" --argjson fields "$FIELD_NAMES" --argjson goals "$GOALS_JSON" \
    --arg attribution "$ATTRIBUTION" --arg name "$REPORT_NAME" --arg type "$REPORT_TYPE" --arg vat "$VAT" '
    {params: (
        {SelectionCriteria: (
            (if $period == "" then {DateFrom: $from, DateTo: $to} else {} end)
            + (if ($filters | length) > 0 then {Filter: $filters} else {} end))}
        + (if $goals != null then {Goals: $goals, AttributionModels: [$attribution]} else {} end)
        + {FieldNames: $fields,
           ReportName: $name,
           ReportType: $type,
           DateRangeType: (if $period == "" then "CUSTOM_DATE" else $period end),
           Format: "TSV",
           IncludeVAT: $vat})}')

HEADERS_FILE=$(mktemp)
BODY_FILE=$(mktemp)
trap 'rm -f "$HEADERS_FILE" "$BODY_FILE"' EXIT

CURL_ARGS=(-sS --compressed -X POST "$REPORTS_URL"
    -H "Authorization: Bearer ${OAUTH_TOKEN}"
    -H "Content-Type: application/json; charset=utf-8"
    -H "Accept-Language: ru"
    -H "processingMode: ${MODE}"
    -H "returnMoneyInMicros: false"
    -H "skipReportHeader: true"
    -H "skipReportSummary: true"
    -D "$HEADERS_FILE" -o "$BODY_FILE" -w "%{http_code}"
    --data-binary @-)
[[ -n "$CLIENT_LOGIN" ]] && CURL_ARGS+=(-H "Client-Login: ${CLIENT_LOGIN}")

header() { grep -i "^$1:" "$HEADERS_FILE" | tail -1 | cut -d' ' -f2- | tr -d '\r' || true; }

WAITED=0
SERVER_ERRORS=0
while :; do
    HTTP_CODE=$(printf '%s' "$REQUEST_BODY" | curl "${CURL_ARGS[@]}") || HTTP_CODE="000"
    case "$HTTP_CODE" in
        200)
            if [[ -n "$OUT" ]]; then
                cat "$BODY_FILE" > "$OUT"
                echo "Report saved: $OUT ($(($(wc -l < "$OUT") - 1)) rows)" >&2
            else
                cat "$BODY_FILE"
            fi
            exit 0
            ;;
        201|202)
            RETRY_IN=$(header retryIn); [[ "$RETRY_IN" =~ ^[0-9]+$ ]] || RETRY_IN=10
            if [[ $((WAITED + RETRY_IN)) -gt "$MAX_WAIT" ]]; then
                echo "ERROR: report '$REPORT_NAME' is not ready after ${WAITED}s (HTTP $HTTP_CODE). Increase --max-wait." >&2
                exit 2
            fi
            echo "Report queued (HTTP $HTTP_CODE, reportsInQueue=$(header reportsInQueue)), retry in ${RETRY_IN}s..." >&2
            sleep "$RETRY_IN"; WAITED=$((WAITED + RETRY_IN))
            ;;
        204)
            echo "ERROR: empty HTTP 204 from Reports API — the Direct API is turned off on Yandex's side" >&2
            echo "       (e.g. special mode after the October 2026 data-center incident). Not a token or IP problem:" >&2
            echo "       https://yandex.ru/support/direct/ru/special-mode" >&2
            exit 1
            ;;
        5*|000)
            SERVER_ERRORS=$((SERVER_ERRORS + 1))
            if [[ $SERVER_ERRORS -ge 3 ]]; then
                echo "ERROR: HTTP $HTTP_CODE from Reports API" >&2; cat "$BODY_FILE" >&2; exit 1
            fi
            sleep $((SERVER_ERRORS * 5)); WAITED=$((WAITED + SERVER_ERRORS * 5))
            ;;
        *)
            echo "ERROR: HTTP $HTTP_CODE from Reports API (RequestId=$(header RequestId))" >&2
            if jq -e '.error' "$BODY_FILE" > /dev/null 2>&1; then jq '.error' "$BODY_FILE" >&2; else cat "$BODY_FILE" >&2; fi
            exit 1
            ;;
    esac
done
