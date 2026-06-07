#!/bin/sh
set -eu

SYNAPSE="${SYNAPSE_URL:-http://synapse:8008}"
SECRET="${REGISTRATION_SHARED_SECRET:?REGISTRATION_SHARED_SECRET must be set}"
USER="${DEMO_USER:-demo}"
PASS="${DEMO_PASS:-demo}"
DOMAIN="${HOMESERVER_DOMAIN:-localhost}"
AGENTS="${DEMO_AGENTS:-brute echo}"
STATE_DIR="${STATE_DIR:-/state}"

mkdir -p "$STATE_DIR"

echo "==> waiting for synapse at $SYNAPSE"
i=0
until curl -fsS "$SYNAPSE/health" >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -ge 120 ]; then
    echo "synapse never became healthy" >&2
    exit 1
  fi
  sleep 1
done

echo "==> registering $USER (idempotent)"
NONCE=$(curl -fsS "$SYNAPSE/_synapse/admin/v1/register" | jq -r .nonce)
MAC=$(printf '%s\0%s\0%s\0notadmin' "$NONCE" "$USER" "$PASS" \
      | openssl dgst -sha1 -hmac "$SECRET" | awk -F'= ' '{print $2}')
REG_BODY=$(jq -nc \
  --arg nonce "$NONCE" --arg user "$USER" --arg pass "$PASS" --arg mac "$MAC" \
  '{nonce:$nonce, username:$user, password:$pass, admin:false, mac:$mac}')
REG=$(curl -sS -X POST "$SYNAPSE/_synapse/admin/v1/register" \
  -H 'content-type: application/json' -d "$REG_BODY")

if echo "$REG" | jq -e '.user_id' >/dev/null 2>&1; then
  echo "    created $(echo "$REG" | jq -r .user_id)"
elif echo "$REG" | jq -e '.errcode == "M_USER_IN_USE"' >/dev/null 2>&1; then
  echo "    user $USER already exists, skipping"
else
  echo "registration failed: $REG" >&2
  exit 1
fi

echo "==> logging in as $USER"
LOGIN_BODY=$(jq -nc --arg user "$USER" --arg pass "$PASS" \
  '{type:"m.login.password", identifier:{type:"m.id.user", user:$user}, password:$pass}')
TOKEN=$(curl -fsS -X POST "$SYNAPSE/_matrix/client/v3/login" \
  -H 'content-type: application/json' -d "$LOGIN_BODY" | jq -r .access_token)
[ -n "$TOKEN" ] && [ "$TOKEN" != "null" ] || { echo "login failed" >&2; exit 1; }

for AGENT in $AGENTS; do
  MXID="@${AGENT}:${DOMAIN}"
  ROOM_FILE="${STATE_DIR}/room_id_${AGENT}"

  if [ -f "$ROOM_FILE" ]; then
    EXISTING=$(cat "$ROOM_FILE")
    if curl -fsS -H "Authorization: Bearer $TOKEN" \
         "$SYNAPSE/_matrix/client/v3/rooms/$EXISTING/joined_members" >/dev/null 2>&1; then
      echo "==> room with $MXID already exists: $EXISTING"
      continue
    fi
    echo "    recorded room $EXISTING for $AGENT is stale, creating a new one"
  fi

  echo "==> creating 1:1 room with $MXID"
  ROOM_BODY=$(jq -nc --arg name "$AGENT" --arg mxid "$MXID" \
    '{name:$name, invite:[$mxid], preset:"private_chat", is_direct:true}')
  ROOM=$(curl -fsS -X POST "$SYNAPSE/_matrix/client/v3/createRoom" \
    -H "Authorization: Bearer $TOKEN" \
    -H 'content-type: application/json' -d "$ROOM_BODY" | jq -r .room_id)
  [ -n "$ROOM" ] && [ "$ROOM" != "null" ] || { echo "createRoom for $AGENT failed" >&2; exit 1; }

  echo "$ROOM" > "$ROOM_FILE"
  echo "    created room $ROOM"
done

echo "==> bootstrap complete"
