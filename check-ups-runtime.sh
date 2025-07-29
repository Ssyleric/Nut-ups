#!/bin/bash

WEBHOOK="https://discord.com/api/webhooks/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
LOGFILE="/var/log/ups-shutdown.log"

UPS_DATA=$(upsc eaton@localhost 2>/dev/null)
STATUS=$(echo "$UPS_DATA" | grep '^ups.status:' | awk '{print $2}')
RUNTIME=$(echo "$UPS_DATA" | grep '^battery.runtime:' | awk '{print $2}')
BATTERY_CHARGE=$(echo "$UPS_DATA" | grep '^battery.charge:' | awk '{print $2}')
MODEL=$(echo "$UPS_DATA" | grep '^device.model:' | cut -d ':' -f2- | sed 's/^ *//')

if [[ "$STATUS" == "OB" && "$RUNTIME" -lt 300 ]]; then
  MESSAGE="⏱ *$(hostname)* — autonomie critique détectée !\n🔋 Batterie : ${BATTERY_CHARGE}%\n⏳ Autonomie : ${RUNTIME} sec\n🖥️ Modèle : $MODEL"
  echo "$(date '+%F %T') ⚠️ Recheck runtime < 300 sec (batt=$BATTERY_CHARGE%, runtime=$RUNTIME sec)" >> "$LOGFILE"
  jq -n --arg content "$MESSAGE" '{content: $content}' | \
    curl -s -H "Content-Type: application/json" -X POST -d @- "$WEBHOOK" > /dev/null
fi
