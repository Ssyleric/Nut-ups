#!/bin/bash

LOGFILE="/var/log/ups-shutdown.log"
WEBHOOK="https://discord.com/api/webhooks/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
SIMULATION=false  # ✅ mode production (⚠️ coupe vraiment les VMs et le serveur)

send_discord() {
  MESSAGE="$1"
  curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"$MESSAGE\"}" "$WEBHOOK" > /dev/null
}

send_log_discord() {
  LOG_CONTENT=$(tail -n 50 "$LOGFILE" | head -c 1900 | jq -Rs .)
  jq -n --arg text "🔻 \`$(hostname)\` extinction imminente — $(date '+%F %T')\n\n" \
        --arg log "$LOG_CONTENT" \
        '{content: ($text + "```" + $log + "```")}' |
  curl -s -H "Content-Type: application/json" -X POST -d @- "$WEBHOOK" > /dev/null
}

send_discord_onbatt() {
  UPS_DATA=$(upsc eaton@localhost 2>/dev/null)

  BATTERY_CHARGE=$(echo "$UPS_DATA" | grep '^battery.charge:' | awk '{print $2}')
  RUNTIME=$(echo "$UPS_DATA" | grep '^battery.runtime:' | awk '{print $2}')
  LOAD=$(echo "$UPS_DATA" | grep '^ups.load:' | awk '{print $2}')
  STATUS=$(echo "$UPS_DATA" | grep '^ups.status:' | awk '{print $2}')
  INPUT_VOLT=$(echo "$UPS_DATA" | grep '^input.voltage:' | awk '{print $2}')
  OUTPUT_VOLT=$(echo "$UPS_DATA" | grep '^output.voltage:' | awk '{print $2}')
  POWER=$(echo "$UPS_DATA" | grep '^ups.power:' | awk '{print $2}')
  MODEL=$(echo "$UPS_DATA" | grep '^device.model:' | cut -d ':' -f2- | sed 's/^ *//')

  LOG_FORMAT=$(cat <<EOF
🖥️ Modèle : $MODEL
🔋 Charge batterie : ${BATTERY_CHARGE} %
⏳ Autonomie estimée : ${RUNTIME} sec
⚡ Charge appliquée : ${LOAD} %
🔌 Entrée : ${INPUT_VOLT} V → ⚡ Sortie : ${OUTPUT_VOLT} V
🔋 Puissance : ${POWER} VA
💡 Statut UPS : $STATUS
EOF
)

  PAYLOAD=$(jq -n \
    --arg msg "⚠️ *$(hostname)* est passé sur **batterie** à **$(date '+%Y-%m-%d %H:%M:%S')** 🔋" \
    --arg log "$LOG_FORMAT" \
    '{content: ($msg + "\n```" + $log + "```")}'
  )

  curl -s -H "Content-Type: application/json" -X POST -d "$PAYLOAD" "$WEBHOOK" > /dev/null
}

case $1 in
  onbatt)
    logger "[NUT] ⚠️ Passage sur batterie détecté"
    echo "$(date '+%F %T') ⚠️ UPS on battery" >> "$LOGFILE"
    send_discord_onbatt
    ;;

  online)
    logger "[NUT] 🔌 Retour à l'alimentation secteur"
    echo "$(date '+%F %T') 🔌 Retour secteur" >> "$LOGFILE"
    send_discord "🔌 **$(hostname)** est revenu sur **secteur** à **$(date '+%Y-%m-%d %H:%M:%S')** ⚡"
    ;;

  shutdown)
    logger "[NUT] 🛑 Batterie faible — extinction imminente (simulation=$SIMULATION)"
    echo "$(date '+%F %T') 🛑 Batterie faible — arrêt des VMs + Proxmox (simulation=$SIMULATION)" >> "$LOGFILE"
    send_discord "🛑 **$(hostname)** — batterie faible détectée à **$(date '+%Y-%m-%d %H:%M:%S')** ⚡\nArrêt des VMs en cours (simulation=$SIMULATION)..."

    for vmid in $(qm list | awk 'NR>1 {print $1}'); do
      echo "$(date '+%F %T') → Arrêt VM $vmid" >> "$LOGFILE"
      if [[ "$SIMULATION" != "true" ]]; then
        qm shutdown $vmid --timeout 300
      fi
    done

    echo "$(date '+%F %T') ⏳ Attente extinction des VMs…" >> "$LOGFILE"
    if [[ "$SIMULATION" != "true" ]]; then
      while qm list | awk 'NR>1 {print $2}' | grep -q running; do
        sleep 5
      done
    fi

    echo "$(date '+%F %T') ✅ VMs arrêtées" >> "$LOGFILE"
    echo "$(date '+%F %T') 🔻 Shutdown final (simulation=$SIMULATION)" >> "$LOGFILE"
    send_log_discord

    if [[ "$SIMULATION" != "true" ]]; then
      shutdown -h now
    fi
    ;;
esac
root@pve:~# 
