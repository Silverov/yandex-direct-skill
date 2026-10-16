#!/usr/bin/env bash
# yd-audit.sh — Collect audit data from Yandex Direct API v5 (Unified Performance Campaigns aware)
#
# Usage: ./yd-audit.sh [output_dir] [options]
#   --include-archived   also collect archived campaigns and ads
#   --no-reports         skip statistics reports (API objects only)
#   --goals ID[,ID...]   Metrika goal IDs for reports (default: priority goals of the campaigns, up to 10)
#   --from YYYY-MM-DD    report period start (default: 30 days ending yesterday)
#   --to YYYY-MM-DD      report period end
#
# Collects: campaigns (incl. UnifiedCampaign settings, strategies, priority goals), ad groups,
# keywords and autotargeting settings, ads (text, combinatorial/RESPONSIVE_AD, image, shopping),
# sitelink sets, callouts, negative keyword shared sets, bid modifiers, and 4 reports:
# campaign (by network), criteria, search queries, YAN placements.
#
# Output: <dir>/<object>.json as {"result": {"<Key>": [...]}}, <dir>/reports/*.tsv, <dir>/summary.json
# API limits handled here: CampaignIds <= 10 per get request, pagination by 10 000 objects.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YD_API="${SCRIPT_DIR}/yd-api.sh"
YD_REPORT="${SCRIPT_DIR}/yd-report.sh"

OUTPUT_DIR="" INCLUDE_ARCHIVED=0 WITH_REPORTS=1 GOALS="" DATE_FROM="" DATE_TO=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --include-archived) INCLUDE_ARCHIVED=1; shift ;;
        --no-reports) WITH_REPORTS=0; shift ;;
        --goals) GOALS="$2"; shift 2 ;;
        --from) DATE_FROM="$2"; shift 2 ;;
        --to) DATE_TO="$2"; shift 2 ;;
        -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) echo "ERROR: unknown option '$1'" >&2; exit 1 ;;
        *) OUTPUT_DIR="$1"; shift ;;
    esac
done
OUTPUT_DIR="${OUTPUT_DIR:-${TMPDIR:-/tmp}/yd-audit-$(date +%Y%m%d_%H%M%S)}"
OUTPUT_DIR="${OUTPUT_DIR%/}"
mkdir -p "$OUTPUT_DIR/reports"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
ERRORS="$WORK/errors.ndjson"
: > "$ERRORS"

note_error() { jq -cn --arg s "$1" --arg e "$2" '{section: $s, error: $e}' >> "$ERRORS"; }

# fetch_paged <service> <result_key> <params_json> <out_ndjson>
# Follows LimitedBy → Page.Offset until all objects are returned.
fetch_paged() {
    local service="$1" key="$2" params="$3" out="$4" offset=0 page resp limited
    while :; do
        page=$(jq -c --argjson o "$offset" '. + {Page: {Limit: 10000, Offset: $o}}' <<< "$params")
        if ! resp=$("$YD_API" "$service" get "$page" 2> "$WORK/stderr.txt"); then
            cat "$WORK/stderr.txt" >&2
            note_error "$service" "$(cat "$WORK/stderr.txt")"
            return 1
        fi
        jq -c --arg k "$key" '.result[$k] // [] | .[]' <<< "$resp" >> "$out"
        limited=$(jq -r '.result.LimitedBy // empty' <<< "$resp")
        [[ -z "$limited" ]] && break
        offset="$limited"
    done
}

# fetch_by_ids <service> <result_key> <ids_json> <chunk_size> <jq_params_template using $ids> <out_json>
# Splits ids into chunks (API limits: CampaignIds 10, shared sets 30, Ids 10 000).
fetch_by_ids() {
    local service="$1" key="$2" ids="$3" size="$4" template="$5" outfile="$6" chunk params status=0
    local nd="$WORK/${service}.ndjson"
    : > "$nd"
    while IFS= read -r chunk; do
        [[ -z "$chunk" ]] && continue
        params=$(jq -cn --argjson ids "$chunk" --argjson archived "$INCLUDE_ARCHIVED" "$template")
        fetch_paged "$service" "$key" "$params" "$nd" || status=1
    done < <(jq -c --argjson n "$size" 'range(0; length; $n) as $i | .[$i:$i+$n]' <<< "$ids")
    jq -s --arg k "$key" '{result: {($k): .}}' "$nd" > "$outfile"
    return $status
}

# fetch_all <service> <result_key> <params_json> <out_json>
fetch_all() {
    local nd="$WORK/$1.ndjson" status=0
    : > "$nd"
    fetch_paged "$1" "$2" "$3" "$nd" || status=1
    jq -s --arg k "$2" '{result: {($k): .}}' "$nd" > "$4"
    return $status
}

count() { jq --arg k "$2" '.result[$k] | length' "$OUTPUT_DIR/$1"; }

echo "=== Yandex Direct Audit Data Collection ==="
echo "Output: $OUTPUT_DIR"
echo ""

# 1. Campaigns
echo "[1/8] Campaigns..."
CAMPAIGN_PARAMS=$(jq -cn --argjson archived "$INCLUDE_ARCHIVED" '{
    SelectionCriteria: (if $archived == 1 then {} else {States: ["ON","OFF","SUSPENDED","ENDED","CONVERTED"]} end),
    FieldNames: ["Id","Name","Type","Status","State","StatusPayment","StatusClarification","StartDate","EndDate",
                 "DailyBudget","Statistics","NegativeKeywords","ExcludedSites","BlockedIps","TimeTargeting","TimeZone"],
    TextCampaignFieldNames: ["CounterIds","RelevantKeywords","Settings","BiddingStrategy","PriorityGoals","AttributionModel",
                             "TrackingParams","PackageBiddingStrategy","NegativeKeywordSharedSetIds","WeeklyBudgetRollover"],
    UnifiedCampaignFieldNames: ["CounterIds","Settings","BiddingStrategy","PriorityGoals","AttributionModel",
                                "TrackingParams","PackageBiddingStrategy","NegativeKeywordSharedSetIds","WeeklyBudgetRollover"],
    UnifiedCampaignSearchStrategyPlacementTypesFieldNames: ["SearchResults","ProductGallery","DynamicPlaces","Maps","SearchOrganizationList"],
    DynamicTextCampaignFieldNames: ["CounterIds","Settings","BiddingStrategy","PriorityGoals","AttributionModel",
                                    "TrackingParams","NegativeKeywordSharedSetIds","PlacementTypes"],
    SmartCampaignFieldNames: ["CounterId","Settings","BiddingStrategy","PriorityGoals","AttributionModel","TrackingParams"]
}')
if ! fetch_all campaigns Campaigns "$CAMPAIGN_PARAMS" "$OUTPUT_DIR/campaigns.json"; then
    echo "ERROR: campaigns fetch failed — check token, Client-Login and API access" >&2
    exit 1
fi
CAMPAIGN_IDS=$(jq -c '[.result.Campaigns[].Id]' "$OUTPUT_DIR/campaigns.json")
if [[ $(jq 'length' <<< "$CAMPAIGN_IDS") -eq 0 ]]; then
    echo "ERROR: no campaigns found" >&2
    exit 1
fi
echo "  campaigns: $(jq 'length' <<< "$CAMPAIGN_IDS") — $(jq -r '[.result.Campaigns[].Type] | group_by(.) | map("\(.[0])×\(length)") | join(", ")' "$OUTPUT_DIR/campaigns.json")"

# 2. Ad groups
echo "[2/8] Ad groups..."
fetch_by_ids adgroups AdGroups "$CAMPAIGN_IDS" 10 '{
    SelectionCriteria: {CampaignIds: $ids},
    FieldNames: ["Id","Name","CampaignId","Status","ServingStatus","Type","Subtype","RegionIds","RestrictedRegionIds",
                 "NegativeKeywords","NegativeKeywordSharedSetIds","TrackingParams"],
    UnifiedAdGroupFieldNames: ["OfferRetargeting"]
}' "$OUTPUT_DIR/adgroups.json" || echo "  WARN: ad groups partially failed"
echo "  ad groups: $(count adgroups.json AdGroups)"

# 3. Keywords and autotargeting
echo "[3/8] Keywords and autotargeting..."
fetch_by_ids keywords Keywords "$CAMPAIGN_IDS" 10 '{
    SelectionCriteria: {CampaignIds: $ids},
    FieldNames: ["Id","Keyword","AdGroupId","CampaignId","Status","State","ServingStatus","Bid","ContextBid",
                 "AutotargetingSearchBidIsAuto","StrategyPriority"],
    AutotargetingSettingsCategoriesFieldNames: ["Exact","Narrow","Alternative","Accessory","Broader"],
    AutotargetingSettingsBrandOptionsFieldNames: ["WithoutBrands","WithAdvertiserBrand","WithCompetitorsBrand"]
}' "$OUTPUT_DIR/keywords.json" || echo "  WARN: keywords partially failed"
echo "  keywords: $(count keywords.json Keywords)"

# 4. Ads — combinatorial ads (RESPONSIVE_AD) need ResponsiveAdFieldNames, otherwise the API
#    returns them as TextAd with only the first title/text/image
echo "[4/8] Ads..."
fetch_by_ids ads Ads "$CAMPAIGN_IDS" 10 '{
    SelectionCriteria: ({CampaignIds: $ids}
        + (if $archived == 1 then {} else {States: ["ON","OFF","SUSPENDED","OFF_BY_MONITORING"]} end)),
    FieldNames: ["Id","AdGroupId","CampaignId","Type","Subtype","Status","State","StatusClarification","AgeLabel","AdCategories"],
    TextAdFieldNames: ["Title","Title2","Text","Href","DisplayDomain","DisplayUrlPath","Mobile","VCardId","BusinessId",
                       "SitelinkSetId","AdImageHash","AdExtensions","VideoExtension","SitelinksModeration",
                       "AdImageModeration","ErirAdDescription","AutogeneratedErirAdDescription"],
    ResponsiveAdFieldNames: ["Titles","Texts","Href","DisplayDomain","DisplayUrlPath","AdImages","VideoExtensions",
                             "SitelinkSetId","SitelinksModeration","AdExtensions","PriceExtension","BusinessId","ErirAdDescription"],
    TextImageAdFieldNames: ["AdImageHash","Href","ErirAdDescription"],
    DynamicTextAdFieldNames: ["Text","SitelinkSetId","AdImageHash","AdExtensions"],
    ShoppingAdFieldNames: ["FeedId","FeedFilterConditions","FeedProcessingStatus","TitleSources","TextSources",
                           "DefaultTexts","SitelinkSetId","AdExtensions","BusinessId"],
    ListingAdFieldNames: ["FeedId","FeedFilterConditions","FeedProcessingStatus","TitleSources","TextSources",
                          "DefaultTexts","SitelinkSetId","AdExtensions","BusinessId"]
}' "$OUTPUT_DIR/ads.json" || echo "  WARN: ads partially failed"
echo "  ads: $(count ads.json Ads) — $(jq -r '[.result.Ads[].Type] | group_by(.) | map("\(.[0])×\(length)") | join(", ")' "$OUTPUT_DIR/ads.json")"

# 5. Sitelink sets (all sets of the client; SelectionCriteria omitted on purpose)
echo "[5/8] Sitelink sets..."
fetch_all sitelinks SitelinksSets '{"FieldNames":["Id","Sitelinks"],"SitelinkFieldNames":["Title","Href","Description"]}' \
    "$OUTPUT_DIR/sitelinks.json" || echo "  WARN: sitelinks fetch failed"
echo "  sitelink sets: $(count sitelinks.json SitelinksSets)"

# 6. Callouts used in ads
echo "[6/8] Callouts..."
EXTENSION_IDS=$(jq -c '[.result.Ads[] | (.TextAd, .ResponsiveAd, .DynamicTextAd, .ShoppingAd, .ListingAd)
    | select(. != null) | .AdExtensions[]?.AdExtensionId] | unique' "$OUTPUT_DIR/ads.json")
fetch_by_ids adextensions AdExtensions "$EXTENSION_IDS" 10000 '{
    SelectionCriteria: {Ids: $ids},
    FieldNames: ["Id","Type","State","Status","StatusClarification"],
    CalloutFieldNames: ["CalloutText"]
}' "$OUTPUT_DIR/adextensions.json" || echo "  WARN: callouts fetch failed"
echo "  callouts: $(count adextensions.json AdExtensions)"

# 7. Negative keyword shared sets (all sets of the client)
echo "[7/8] Negative keyword shared sets..."
fetch_all negativekeywordsharedsets NegativeKeywordSharedSets '{"FieldNames":["Id","Name","NegativeKeywords","Associated"]}' \
    "$OUTPUT_DIR/negative_sets.json" || echo "  WARN: negative keyword sets fetch failed"
echo "  shared sets: $(count negative_sets.json NegativeKeywordSharedSets)"

# 8. Bid modifiers (campaign and ad group level)
echo "[8/8] Bid modifiers..."
fetch_by_ids bidmodifiers BidModifiers "$CAMPAIGN_IDS" 10 '{
    SelectionCriteria: {CampaignIds: $ids, Levels: ["CAMPAIGN","AD_GROUP"]},
    FieldNames: ["Id","CampaignId","AdGroupId","Level","Type"],
    MobileAdjustmentFieldNames: ["BidModifier","OperatingSystemType"],
    TabletAdjustmentFieldNames: ["BidModifier","OperatingSystemType"],
    DesktopAdjustmentFieldNames: ["BidModifier"],
    DesktopOnlyAdjustmentFieldNames: ["BidModifier"],
    SmartTvAdjustmentFieldNames: ["BidModifier"],
    DemographicsAdjustmentFieldNames: ["Gender","Age","BidModifier","Enabled"],
    RetargetingAdjustmentFieldNames: ["RetargetingConditionId","BidModifier","Accessible","Enabled"],
    RegionalAdjustmentFieldNames: ["RegionId","BidModifier","Enabled"],
    VideoAdjustmentFieldNames: ["BidModifier"],
    SmartAdAdjustmentFieldNames: ["BidModifier"],
    SerpLayoutAdjustmentFieldNames: ["SerpLayout","BidModifier","Enabled"],
    IncomeGradeAdjustmentFieldNames: ["Grade","BidModifier","Enabled"],
    AdGroupAdjustmentFieldNames: ["BidModifier"]
}' "$OUTPUT_DIR/bidmodifiers.json" || echo "  WARN: bid modifiers partially failed"
echo "  bid modifiers: $(count bidmodifiers.json BidModifiers)"

# Reports
REPORT_GOALS="$GOALS"
if [[ -z "$REPORT_GOALS" ]]; then
    # priority goals of the campaigns, most frequent first, at most 10 (Reports API limit)
    REPORT_GOALS=$(jq -r '[.result.Campaigns[] | (.TextCampaign, .UnifiedCampaign, .DynamicTextCampaign, .SmartCampaign)
        | select(. != null) | .PriorityGoals.Items[]?.GoalId | select(. > 13)]
        | group_by(.) | sort_by(-length) | map(.[0] | tostring) | .[:10] | join(",")' "$OUTPUT_DIR/campaigns.json")
fi

REPORTS_DONE="[]"
if [[ "$WITH_REPORTS" == "1" ]]; then
    echo ""
    echo "Reports (goals: ${REPORT_GOALS:-none — conversions will be summed over all goals})..."
    REPORT_ARGS=()
    [[ -n "$REPORT_GOALS" ]] && REPORT_ARGS+=(--goals "$REPORT_GOALS")
    [[ -n "$DATE_FROM" ]] && REPORT_ARGS+=(--from "$DATE_FROM")
    [[ -n "$DATE_TO" ]] && REPORT_ARGS+=(--to "$DATE_TO")
    for spec in "campaign --by-network" "criteria" "search_query" "placement"; do
        name="${spec%% *}"
        # shellcheck disable=SC2086
        if "$YD_REPORT" $spec ${REPORT_ARGS[@]+"${REPORT_ARGS[@]}"} --out "$OUTPUT_DIR/reports/${name}.tsv" 2> "$WORK/stderr.txt"; then
            REPORTS_DONE=$(jq -c --arg n "$name" '. + [$n]' <<< "$REPORTS_DONE")
            echo "  $name: $(($(wc -l < "$OUTPUT_DIR/reports/${name}.tsv") - 1)) rows"
        else
            cat "$WORK/stderr.txt" >&2
            note_error "report:$name" "$(cat "$WORK/stderr.txt")"
            echo "  WARN: report $name failed"
        fi
    done
fi

jq -n \
    --slurpfile c "$OUTPUT_DIR/campaigns.json" --slurpfile g "$OUTPUT_DIR/adgroups.json" \
    --slurpfile k "$OUTPUT_DIR/keywords.json" --slurpfile a "$OUTPUT_DIR/ads.json" \
    --slurpfile s "$OUTPUT_DIR/sitelinks.json" --slurpfile x "$OUTPUT_DIR/adextensions.json" \
    --slurpfile n "$OUTPUT_DIR/negative_sets.json" --slurpfile b "$OUTPUT_DIR/bidmodifiers.json" \
    --slurpfile errors "$ERRORS" --arg goals "$REPORT_GOALS" --argjson reports "$REPORTS_DONE" \
    --arg collected "$(date +%Y-%m-%dT%H:%M:%S%z)" --argjson archived "$INCLUDE_ARCHIVED" '
    def by_type(arr): arr | map(.Type) | group_by(.) | map({key: .[0], value: length}) | from_entries;
    {
      collected_at: $collected,
      include_archived: ($archived == 1),
      counts: {
        campaigns: ($c[0].result.Campaigns | length),
        adgroups: ($g[0].result.AdGroups | length),
        keywords: ($k[0].result.Keywords | length),
        ads: ($a[0].result.Ads | length),
        sitelink_sets: ($s[0].result.SitelinksSets | length),
        callouts: ($x[0].result.AdExtensions | length),
        negative_keyword_shared_sets: ($n[0].result.NegativeKeywordSharedSets | length),
        bid_modifiers: ($b[0].result.BidModifiers | length)
      },
      campaign_types: by_type($c[0].result.Campaigns),
      ad_types: by_type($a[0].result.Ads),
      report_goals: ($goals | split(",") | map(select(length > 0))),
      reports: $reports,
      errors: $errors
    }' > "$OUTPUT_DIR/summary.json"

echo ""
echo "=== Collection complete ==="
ls -la "$OUTPUT_DIR" "$OUTPUT_DIR/reports"
if [[ $(jq '.errors | length' "$OUTPUT_DIR/summary.json") -gt 0 ]]; then
    echo ""
    echo "Some sections failed — see .errors in $OUTPUT_DIR/summary.json"
fi
