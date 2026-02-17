#!/usr/bin/env bash
# yd-report.sh — Yandex Direct Reports API wrapper
# Usage: ./yd-report.sh <report_type> [date_from] [date_to]
# report_type: campaign | adgroup | keyword | search_query
# Example: ./yd-report.sh campaign 2026-01-01 2026-01-31

set -euo pipefail

SECRETS_FILE="${HOME}/.secrets/yandex-direct.json"
REPORTS_URL="https://api.direct.yandex.com/json/v5/reports"

if [[ ! -f "$SECRETS_FILE" ]]; then
    echo "ERROR: Credentials not found at $SECRETS_FILE" >&2
    exit 1
fi

OAUTH_TOKEN=$(jq -r '.oauth_token' "$SECRETS_FILE")

REPORT_TYPE="${1:?Usage: yd-report.sh <campaign|adgroup|keyword|search_query> [date_from] [date_to]}"
DATE_FROM="${2:-$(date -d '-30 days' +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d)}"
DATE_TO="${3:-$(date +%Y-%m-%d)}"

# Map report type to fields
case "$REPORT_TYPE" in
    campaign)
        FIELD_NAMES='["CampaignName","CampaignId","Impressions","Clicks","Ctr","AvgCpc","Cost","Conversions","CostPerConversion","ConversionRate"]'
        REPORT_NAME="Campaign Report"
        REPORT_PRESET="CAMPAIGN_PERFORMANCE_REPORT"
        ;;
    adgroup)
        FIELD_NAMES='["CampaignName","AdGroupName","AdGroupId","Impressions","Clicks","Ctr","AvgCpc","Cost","Conversions","CostPerConversion"]'
        REPORT_NAME="Ad Group Report"
        REPORT_PRESET="ADGROUP_PERFORMANCE_REPORT"
        ;;
    keyword)
        FIELD_NAMES='["CampaignName","AdGroupName","Criteria","CriteriaId","Impressions","Clicks","Ctr","AvgCpc","Cost","Conversions","CostPerConversion"]'
        REPORT_NAME="Keyword Report"
        REPORT_PRESET="CRITERIA_PERFORMANCE_REPORT"
        ;;
    search_query)
        FIELD_NAMES='["CampaignName","AdGroupName","Query","Impressions","Clicks","Ctr","AvgCpc","Cost","Conversions"]'
        REPORT_NAME="Search Query Report"
        REPORT_PRESET="SEARCH_QUERY_PERFORMANCE_REPORT"
        ;;
    *)
        echo "ERROR: Unknown report type '$REPORT_TYPE'. Use: campaign, adgroup, keyword, search_query" >&2
        exit 1
        ;;
esac

# Build report request
REQUEST_BODY=$(cat <<EOF
{
    "params": {
        "SelectionCriteria": {
            "DateFrom": "$DATE_FROM",
            "DateTo": "$DATE_TO"
        },
        "FieldNames": $FIELD_NAMES,
        "ReportName": "$REPORT_NAME $(date +%s)",
        "ReportType": "$REPORT_PRESET",
        "DateRangeType": "CUSTOM_DATE",
        "Format": "TSV",
        "IncludeVAT": "YES",
        "IncludeDiscount": "NO"
    }
}
EOF
)

# Request report (may need polling for large reports)
HTTP_CODE=$(curl -s -o /tmp/yd-report-response.txt -w "%{http_code}" \
    -X POST "$REPORTS_URL" \
    -H "Authorization: Bearer ${OAUTH_TOKEN}" \
    -H "Content-Type: application/json; charset=utf-8" \
    -H "Accept-Language: ru" \
    -H "processingMode: auto" \
    -H "returnMoneyInMicros: false" \
    -d "$REQUEST_BODY")

case "$HTTP_CODE" in
    200)
        echo "Report ready:"
        cat /tmp/yd-report-response.txt
        ;;
    201)
        echo "Report queued. Retry in 10-20 seconds."
        RETRY_AFTER=$(grep -i 'retryIn' /tmp/yd-report-response.txt || echo "15")
        echo "Retry after: ${RETRY_AFTER}s"
        ;;
    202)
        echo "Report is being generated. Retry in 10-20 seconds."
        ;;
    400)
        echo "ERROR: Bad request" >&2
        cat /tmp/yd-report-response.txt >&2
        exit 1
        ;;
    *)
        echo "ERROR: HTTP $HTTP_CODE" >&2
        cat /tmp/yd-report-response.txt >&2
        exit 1
        ;;
esac
