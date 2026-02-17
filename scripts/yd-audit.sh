#!/usr/bin/env bash
# yd-audit.sh — Collect audit data from Yandex Direct API v5
# Usage: ./yd-audit.sh [output_dir]
# Collects: campaigns, ad groups, ads, keywords, sitelinks, negative keywords

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YD_API="${SCRIPT_DIR}/yd-api.sh"
OUTPUT_DIR="${1:-/tmp/yd-audit-$(date +%Y%m%d_%H%M%S)}"

mkdir -p "$OUTPUT_DIR"
echo "=== Yandex Direct Audit Data Collection ==="
echo "Output: $OUTPUT_DIR"
echo ""

# 1. Get all campaigns
echo "[1/6] Fetching campaigns..."
"$YD_API" campaigns get '{
    "SelectionCriteria": {},
    "FieldNames": ["Id","Name","Status","State","StatusPayment","DailyBudget","StartDate","Statistics","Type"],
    "TextCampaignFieldNames": ["BiddingStrategy","Settings","CounterIds"],
    "DynamicTextCampaignFieldNames": ["BiddingStrategy","Settings","CounterIds"]
}' > "$OUTPUT_DIR/campaigns.json" 2>&1 || echo "WARN: campaigns fetch failed"

# Extract campaign IDs
CAMPAIGN_IDS=$(jq -r '.result.Campaigns[]?.Id // empty' "$OUTPUT_DIR/campaigns.json" 2>/dev/null | tr '\n' ',' | sed 's/,$//')

if [[ -z "$CAMPAIGN_IDS" ]]; then
    echo "ERROR: No campaigns found or API error"
    cat "$OUTPUT_DIR/campaigns.json"
    exit 1
fi

echo "  Found campaigns: $CAMPAIGN_IDS"

# 2. Get ad groups
echo "[2/6] Fetching ad groups..."
"$YD_API" adgroups get "{
    \"SelectionCriteria\": {\"CampaignIds\": [$CAMPAIGN_IDS]},
    \"FieldNames\": [\"Id\",\"Name\",\"CampaignId\",\"Status\",\"Type\",\"RegionIds\"]
}" > "$OUTPUT_DIR/adgroups.json" 2>&1 || echo "WARN: adgroups fetch failed"

# 3. Get keywords
echo "[3/6] Fetching keywords..."
"$YD_API" keywords get "{
    \"SelectionCriteria\": {\"CampaignIds\": [$CAMPAIGN_IDS]},
    \"FieldNames\": [\"Id\",\"Keyword\",\"AdGroupId\",\"CampaignId\",\"Status\",\"State\",\"Bid\",\"ContextBid\",\"StatisticsSearch\",\"StatisticsNetwork\"]
}" > "$OUTPUT_DIR/keywords.json" 2>&1 || echo "WARN: keywords fetch failed"

# 4. Get ads
echo "[4/6] Fetching ads..."
"$YD_API" ads get "{
    \"SelectionCriteria\": {\"CampaignIds\": [$CAMPAIGN_IDS]},
    \"FieldNames\": [\"Id\",\"AdGroupId\",\"CampaignId\",\"Status\",\"State\",\"StatusClarification\",\"Type\"],
    \"TextAdFieldNames\": [\"Title\",\"Title2\",\"Text\",\"Href\",\"DisplayDomain\",\"Mobile\",\"SitelinkSetId\",\"AdExtensionIds\"]
}" > "$OUTPUT_DIR/ads.json" 2>&1 || echo "WARN: ads fetch failed"

# 5. Get sitelink sets
echo "[5/6] Fetching sitelinks..."
"$YD_API" sitelinks get '{
    "SelectionCriteria": {},
    "FieldNames": ["Id","Sitelinks"]
}' > "$OUTPUT_DIR/sitelinks.json" 2>&1 || echo "WARN: sitelinks fetch failed"

# 6. Get negative keyword shared sets
echo "[6/6] Fetching negative keyword sets..."
"$YD_API" negativekeywordsharedsets get '{
    "SelectionCriteria": {},
    "FieldNames": ["Id","Name","NegativeKeywords"]
}' > "$OUTPUT_DIR/negative_sets.json" 2>&1 || echo "WARN: negative sets fetch failed"

echo ""
echo "=== Collection complete ==="
echo "Files:"
ls -la "$OUTPUT_DIR/"
echo ""
echo "Run report collection separately:"
echo "  ${SCRIPT_DIR}/yd-report.sh campaign"
echo "  ${SCRIPT_DIR}/yd-report.sh search_query"
