#!/bin/bash

WEBHOOK="https://discord.com/api/webhooks/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
UPS_DATA=$(upsc eaton@localhost 2>/dev/null)

BATTERY_CHARGE=$(echo "$UPS_DATA" | grep '^battery.charge:' | awk '{print $2}')
RUNTIME=$(echo "$UPS_DATA" | grep '^battery.runtime:' | awk '{print $2}')
LOAD=$(echo "$UPS_DATA" | grep '^ups.load:' | awk '{print $2}')
STATUS=$(echo "$UPS_DATA" | grep '^ups.status:' | awk '{print $2}')
INPUT_VOLT=$(echo "$UPS_DATA" | grep '^input.voltage:' | awk '{print $2}')
OUTPUT_VOLT=$(echo "$UPS_DATA" | grep '^output.voltage:' | awk '{print $2}')
POWER=$(echo "$UPS_DATA" | grep '^ups.power:' | awk '{print $2}')
MODEL=$(echo "$UPS_DATA" | grep '^device.model:' | cut -d ':' -f2- | sed 's/^ *//')

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

MESSAGE="🕓 *État UPS à ${TIMESTAMP}*
🖥️ Modèle : $MODEL
🔋 Charge batterie : ${BATTERY_CHARGE} %
⏳ Autonomie estimée : ${RUNTIME} sec
⚡ Charge appliquée : ${LOAD} %
🔌 Entrée : ${INPUT_VOLT} V → ⚡ Sortie : ${OUTPUT_VOLT} V
🔋 Puissance : ${POWER} VA
💡 Statut UPS : $STATUS"

jq -n --arg content "$MESSAGE" '{content: $content}' | \
  curl -s -H "Content-Type: application/json" -X POST -d @- "$WEBHOOK" > /dev/null
