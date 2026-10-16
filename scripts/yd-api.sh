#!/usr/bin/env bash
# yd-api.sh — Generic Yandex Direct API v5 / v501 wrapper
#
# Usage: ./yd-api.sh <service> <method> [json_params | @file.json | -]
# Example: ./yd-api.sh campaigns get '{"SelectionCriteria":{},"FieldNames":["Id","Name","Type","State"]}'
#
# Environment:
#   YD_SECRETS       credentials file (default: ~/.secrets/yandex-direct.json)
#   YD_TOKEN         OAuth token (overrides oauth_token from the file)
#   YD_CLIENT_LOGIN  client login for agency/representative access (overrides client_login from the file)
#   YD_API_VERSION   v5 | v501. Default: v5, but requests that carry UnifiedCampaign,
#                    UnifiedAdGroup, ShoppingAd or ListingAd structures go to v501 automatically
#                    (Yandex documents creation of Unified Performance Campaign objects on v501).
#   YD_SANDBOX=1     use https://api-sandbox.direct.yandex.com
#   YD_API_HOST      override API host, e.g. for a local mock (default: https://api.direct.yandex.com)
#   YD_VERBOSE=1     print RequestId and Units (spent/rest/limit) to stderr
#
# Exit codes: 0 — ok; 1 — request/API error; 3 — request accepted, but some items
# returned Errors (e.g. AddResults[].Errors) — the full response is still printed.

set -euo pipefail

SECRETS_FILE="${YD_SECRETS:-${HOME}/.secrets/yandex-direct.json}"

if [[ -n "${YD_API_HOST:-}" ]]; then
    API_HOST="${YD_API_HOST%/}"
elif [[ "${YD_SANDBOX:-0}" == "1" ]]; then
    API_HOST="https://api-sandbox.direct.yandex.com"
else
    API_HOST="https://api.direct.yandex.com"
fi

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

SERVICE="${1:?Usage: yd-api.sh <service> <method> [json_params | @file.json | -]}"
METHOD="${2:?Usage: yd-api.sh <service> <method> [json_params | @file.json | -]}"
PARAMS_ARG="${3:-}"

case "$PARAMS_ARG" in
    "")  PARAMS='{}' ;;
    -)   PARAMS=$(cat) ;;
    @*)  PARAMS=$(cat "${PARAMS_ARG#@}") ;;
    *)   PARAMS="$PARAMS_ARG" ;;
esac

if ! echo "$PARAMS" | jq -e 'type == "object"' > /dev/null 2>&1; then
    echo "ERROR: params must be a JSON object" >&2
    exit 1
fi

# Pick API version
API_VERSION="${YD_API_VERSION:-}"
if [[ -z "$API_VERSION" ]]; then
    API_VERSION="v5"
    if [[ "$METHOD" == "add" || "$METHOD" == "update" ]] \
        && echo "$PARAMS" | jq -e '[.. | objects | keys[]] | any(. == "UnifiedCampaign" or . == "UnifiedAdGroup" or . == "ShoppingAd" or . == "ListingAd")' > /dev/null; then
        API_VERSION="v501"
    fi
fi

REQUEST_BODY=$(jq -n --arg method "$METHOD" --argjson params "$PARAMS" '{method: $method, params: $params}')

HEADERS_FILE=$(mktemp)
BODY_FILE=$(mktemp)
trap 'rm -f "$HEADERS_FILE" "$BODY_FILE"' EXIT

CURL_ARGS=(-sS --compressed -X POST "${API_HOST}/json/${API_VERSION}/${SERVICE}"
    -H "Authorization: Bearer ${OAUTH_TOKEN}"
    -H "Content-Type: application/json; charset=utf-8"
    -H "Accept-Language: ru"
    -D "$HEADERS_FILE" -o "$BODY_FILE" -w "%{http_code}"
    --data-binary @-)
[[ -n "$CLIENT_LOGIN" ]] && CURL_ARGS+=(-H "Client-Login: ${CLIENT_LOGIN}")

# Retry transport errors and HTTP 5xx; API-level errors are not retried
HTTP_CODE=""
for attempt in 1 2 3; do
    if HTTP_CODE=$(printf '%s' "$REQUEST_BODY" | curl "${CURL_ARGS[@]}"); then
        [[ "$HTTP_CODE" =~ ^5 ]] || break
    fi
    [[ $attempt -lt 3 ]] && sleep $((attempt * 2))
done

header() { grep -i "^$1:" "$HEADERS_FILE" | tail -1 | cut -d' ' -f2- | tr -d '\r' || true; }

if [[ "${YD_VERBOSE:-0}" == "1" ]]; then
    echo "[yd-api] ${API_VERSION}/${SERVICE}.${METHOD} HTTP ${HTTP_CODE:-?} RequestId=$(header RequestId) Units=$(header Units)" >&2
fi

if ! jq -e . "$BODY_FILE" > /dev/null 2>&1; then
    echo "ERROR: HTTP ${HTTP_CODE:-?}, non-JSON response from ${SERVICE}.${METHOD}:" >&2
    head -c 2000 "$BODY_FILE" >&2
    echo >&2
    if [[ "$HTTP_CODE" == "204" ]]; then
        echo "HINT: an empty HTTP 204 to every request (even with a wrong token) means the Direct API is turned off" >&2
        echo "      on Yandex's side — e.g. the special mode after the October 2026 data-center incident, when only the" >&2
        echo "      web interface works. Not a token or IP problem: https://yandex.ru/support/direct/ru/special-mode" >&2
    fi
    exit 1
fi

if jq -e '.error' "$BODY_FILE" > /dev/null 2>&1; then
    echo "API ERROR (${SERVICE}.${METHOD}):" >&2
    jq '.error' "$BODY_FILE" >&2
    exit 1
fi

jq '.' "$BODY_FILE"

ITEM_ERRORS=$(jq '[.result | .. | objects | select(has("Errors")) | .Errors[]?] | length' "$BODY_FILE")
if [[ "$ITEM_ERRORS" -gt 0 ]]; then
    echo "WARN: ${ITEM_ERRORS} item-level error(s) in ${SERVICE}.${METHOD} response (see .result.*.Errors)" >&2
    exit 3
fi
