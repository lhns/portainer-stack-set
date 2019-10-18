#!/bin/bash

# https://github.com/matzegebbe/portainer-service-image-update-bash

set -eu

HOST=$1
USERNAME=$2
PASSWORD=$3
STACKNAME=$4
IMAGE=$5

# GENERATE LOGIN TOKEN
PAYLOAD="{
  \"username\":\"$USERNAME\",
  \"password\":\"$PASSWORD\"
}"

LOGIN_TOKEN=$(
  curl -s -H "Content-Type: application/json" -d "$PAYLOAD" -X POST "$HOST/api/auth" |
    jq -r .jwt
)

# GET STACK ID OF $NAME
ID=$(
  curl -s -H "Authorization: Bearer $LOGIN_TOKEN" "$HOST/api/stacks" |
    jq -c ".[] | select( .Name==(\"$STACKNAME\"))" |
    jq -r .Id
)

STACK=$(curl -s -H "Authorization: Bearer $LOGIN_TOKEN" "$HOST/api/stacks/$ID")

# GET THE ENV
ENV=$(printf '%s' "$STACK" | jq .Env)

# GET THE ENDPOINT ID
ENDPOINT_ID=$(printf '%s' "$STACK" | jq .EndpointId)

# GET THE STACK LIVE FILE
STACKFILE=$(
  curl -s -H "Authorization: Bearer $LOGIN_TOKEN" "$HOST/api/stacks/$ID/file" |
    jq .StackFileContent
)

NEW_STACKFILE=$(
  REGEX='(image: ).*?(\\n)'
  SUBSTITUTION="\${1}$IMAGE\${2}"
  printf '%s' "$STACKFILE" | perl -C -ple "s/${REGEX/\//$(echo '\/')}/${SUBSTITUTION/\//$(echo '\/')}/g"
)

# UPDATE THE STACK > /dev/null beacuse the $ENV contains passwords
PAYLOAD="{
  \"StackFileContent\": ${NEW_STACKFILE},
  \"Env\": ${ENV},
  \"Prune\": true
}"

curl -s -H 'Content-Type: text/json; charset=utf-8' \
        -H "Authorization: Bearer $LOGIN_TOKEN" \
     -d "$PAYLOAD" \
     -X PUT "$HOST/api/stacks/$ID?endpointId=$ENDPOINT_ID" > /dev/null
