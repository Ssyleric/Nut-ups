# 🔋 Protection Proxmox via Onduleur EATON Ellipse PRO avec NUT

## ✅ Objectif

Assurer un **arrêt automatique propre** de toutes les VMs puis du serveur **Proxmox VE** en cas de coupure de courant, en s'appuyant sur l'onduleur **EATON Ellipse PRO USB** et le logiciel **NUT (Network UPS Tools)**.

---

## ⚡ Composants

* **UPS** : EATON Ellipse PRO 850 VA (USB)
* **Hôte Proxmox VE** (relié physiquement via USB)
* **Logiciel** : `nut`, `nut-client`, `jq`
* **Notifications** : Webhook Discord
* **Scripts personnalisés** : `/etc/nut/upssched-cmd.sh`

---

## 📅 Fonctionnement

| Événement                       | Action                                                       |
| ------------------------------- | ------------------------------------------------------------ |
| Passage sur batterie (`onbatt`) | Envoie un message Discord avec état complet de l'UPS         |
| Retour secteur (`online`)       | Message Discord "Retour secteur"                             |
| Batterie faible (`shutdown`)    | Arrêt propre des VMs (via `qm shutdown`) puis du serveur PVE |

---

## 🔧 Installation & configuration

### 1. Installer les paquets

```bash
apt update -y && apt install -y nut jq
```

### 2. Détection de l'UPS (via USB)

```bash
nut-scanner -U
```

Confirmer que le modèle EATON est bien détecté.

### 3. Fichiers de configuration NUT

#### `/etc/nut/ups.conf`

```ini
[eaton]
  driver = usbhid-ups
  port = auto
  vendorid = 0463
  productid = FFFF
  desc = "Onduleur EATON Ellipse PRO"
```

#### `/etc/nut/nut.conf`

```ini
MODE=standalone
```

#### `/etc/nut/upsd.users`

```ini
[monuser]
  password = secret
  upsmon master
```

#### `/etc/nut/upsmon.conf`

```ini
MONITOR eaton@localhost 1 monuser secret master
NOTIFYCMD /sbin/upssched
```

#### `/etc/nut/upssched.conf`

```ini
CMDSCRIPT /etc/nut/upssched-cmd.sh
PIPEFN /var/run/nut/upssched.pipe
LOCKFN /var/run/nut/upssched.lock

AT COMMBAD * EXECUTE onbatt
AT COMMOK * EXECUTE online
AT LOWBATT * EXECUTE shutdown
```

---

## 🔢 Script `/etc/nut/upssched-cmd.sh`

### Fonctions incluses :

* Lecture de l'état de l'UPS via `upsc`
* Log local horodaté `/var/log/ups-shutdown.log`
* Notification Webhook Discord (format Markdown)
* Arrêt propre de toutes les VMs via `qm shutdown`
* Attente de l'extinction totale avant `shutdown -h now`

### Sécurité :

Le script contient une variable `SIMULATION=false` pour activer le mode production.
Si mise à `true`, aucun arrêt ne sera réellement effectué (mode test).

### Autorisations

```bash
chmod +x /etc/nut/upssched-cmd.sh
```

---

## 🚀 Notifications Discord

Chaque événement envoie un message via Webhook (texte ou bloc `markdown`).

Exemple `onbatt` :

```markdown
🔕 pve est passé sur batterie à 2025-07-29 09:10:22
```

```
🖥️ Modèle : Ellipse PRO 850
🔋 Charge batterie : 46 %
⏳ Autonomie estimée : 168 sec
⚡ Charge appliquée : 47 %
🔌 Entrée : 237.0 V → ⚡ Sortie : 234.0 V
🔋 Puissance : 261 VA
💡 Statut UPS : OL
```

---

## 🛡️ Test manuel sans danger

```bash
/etc/nut/upssched-cmd.sh onbatt
```

Permet de vérifier les logs + Discord sans exécuter d'arrêt.

---

## 🔺 Bascule en production

```bash
nano /etc/nut/upssched-cmd.sh
# Remplacer : SIMULATION=true --> SIMULATION=false
```

Puis redémarrer NUT :

```bash
systemctl restart nut-server
systemctl restart nut-client
```

---

## 📄 Log

Fichier log local : `/var/log/ups-shutdown.log`
Contient tous les événements UPS avec horodatage.

---

## 💼 Auteur : Ssyleric — 2025-07-29
