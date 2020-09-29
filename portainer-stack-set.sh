#!/bin/bash

# https://github.com/LolHens/portainer-stack-set
# forked from https://github.com/matzegebbe/portainer-service-image-update-bash

set -eu

HOST="$1"
USERNAME="$2"
PASSWORD="$3"
STACKNAME="$4"
IMAGE="$5"
REGEX="$6"
if [ $# -ge 6 ]
then
  REGEX="$6"
else
  REGEX='(?<=image: ).*?(?=\r?\n|$)'
fi

# GENERATE LOGIN TOKEN
PAYLOAD="$(
  jq -nc \
  --arg username "$USERNAME" \
  --arg password "$PASSWORD" \
  '{
    username: $username,
    password: $password
  }'
)"

LOGIN_TOKEN="$(curl -sSf -H "Content-Type: application/json" -d "$PAYLOAD" -X POST "$HOST/api/auth" | jq -r '.jwt')"

# GET STACK ID OF $NAME
ID="$(
  curl -sSf -H "Authorization: Bearer $LOGIN_TOKEN" "$HOST/api/stacks" |
    jq -r --arg stackname "$STACKNAME" 'map(select(.Name == $stackname).Id)[]'
)"

STACK="$(curl -sSf -H "Authorization: Bearer $LOGIN_TOKEN" "$HOST/api/stacks/$ID")"

# GET THE ENDPOINT ID
ENDPOINT_ID="$(jq -nr --argjson stack "$STACK" '$stack.EndpointId')"

# GET THE STACK LIVE FILE
STACKFILE="$(curl -sSf -H "Authorization: Bearer $LOGIN_TOKEN" "$HOST/api/stacks/$ID/file" | jq -r '.StackFileContent')"

NEW_STACKFILE="$(jq -nr --arg stackfile "$STACKFILE" --arg regex "$REGEX" --arg image "$IMAGE" '$stackfile | sub($regex; $image)')"

PAYLOAD="$(
  jq -nc \
  --arg new_stackfile "$NEW_STACKFILE" \
  --argjson stack "$STACK" \
  '{
    StackFileContent: $new_stackfile,
    Env: $stack.Env,
    Prune: true
  }'
)"

# UPDATE THE STACK > /dev/null beacuse the $ENV contains passwords
curl -sSf \
-H 'Content-Type: text/json; charset=utf-8' \
-H "Authorization: Bearer $LOGIN_TOKEN" \
-d "$PAYLOAD" \
-X PUT "$HOST/api/stacks/$ID?endpointId=$ENDPOINT_ID" >/dev/null
