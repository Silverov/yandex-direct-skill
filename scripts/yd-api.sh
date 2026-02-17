#!/usr/bin/env bash
# yd-api.sh — Generic Yandex Direct API v5 wrapper
# Usage: ./yd-api.sh <service> <method> [json_params]
# Example: ./yd-api.sh campaigns get '{"SelectionCriteria":{},"FieldNames":["Id","Name","Status"]}'

set -euo pipefail

SECRETS_FILE="${HOME}/.secrets/yandex-direct.json"
API_BASE="https://api.direct.yandex.com/json/v5"

if [[ ! -f "$SECRETS_FILE" ]]; then
    echo "ERROR: Credentials not found at $SECRETS_FILE" >&2
    exit 1
fi

OAUTH_TOKEN=$(jq -r '.oauth_token' "$SECRETS_FILE")

if [[ -z "$OAUTH_TOKEN" || "$OAUTH_TOKEN" == "null" ]]; then
    echo "ERROR: oauth_token not found in $SECRETS_FILE" >&2
    exit 1
fi

SERVICE="${1:?Usage: yd-api.sh <service> <method> [json_params]}"
METHOD="${2:?Usage: yd-api.sh <service> <method> [json_params]}"
PARAMS="${3:-{}}"

# Build request body
REQUEST_BODY=$(jq -n \
    --arg method "$METHOD" \
    --argjson params "$PARAMS" \
    '{method: $method, params: $params}')

# Make API call
RESPONSE=$(curl -s -X POST \
    "${API_BASE}/${SERVICE}" \
    -H "Authorization: Bearer ${OAUTH_TOKEN}" \
    -H "Content-Type: application/json; charset=utf-8" \
    -H "Accept-Language: ru" \
    -d "$REQUEST_BODY")

# Check for errors
if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
    echo "API ERROR:" >&2
    echo "$RESPONSE" | jq '.error' >&2
    exit 1
fi

echo "$RESPONSE" | jq '.'
