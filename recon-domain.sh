#!/usr/bin/env bash
# recon.sh - découverte de sous-domaines (version améliorée)
# Usage: ./recon.sh example.com
set -euo pipefail
IFS=$'\n\t'

# Rappelle: appelé par gogoliomax
if [ "${1:-}" = "" ]; then
  echo "Usage: $0 <domain>"
  exit 1
fi

DOMAIN="$1"
OUTDIR="$(pwd)/SUBRECON_$DOMAIN"
mkdir -p "$OUTDIR"
cd "$OUTDIR"

# Vérifier que les outils nécessaires sont installés (ajoute/supprime selon ton setup)
need() {
  command -v "$1" >/dev/null 2>&1 || { echo "Erreur: $1 introuvable. Installe-le."; exit 2; }
}
for tool in /root/go/bin/subfinder /root/go/bin/assetfinder /root/go/bin/httpx /root/go/bin/dnsx jq sort crtsh /root/go/bin/nuclei; do
  # crtsh dans la liste au cas où tu utilises un wrapper ; retire si non.
  need "$tool"
done
# vérifier que les templates nuclei pour takeovers sont présents
if [ ! -d ~/nuclei-templates/http/takeovers ]; then
  echo "Erreur: Les templates Nuclei pour takeovers sont absents."; exit 3;
fi

echo "[*] Lancement reconnaissance sur $DOMAIN - $(date --iso-8601=seconds)"

# fichiers
RAW_SUBS="subdomains_raw.txt"
SUBS="subs.txt"
RESOLVED="resolved.txt"
ALIVE="alive.txt"
HTTPX_JSON="httpx.json"
TAKEOVERS="subdomain_takeovers.txt"
ALIVE_WITH_CODES="alive_with_codes.txt"

# 1) Collecte multi-source (en parallèle)
> "$RAW_SUBS"
echo "$DOMAIN" >> "$RAW_SUBS"   # si tu veux garder la racine

# démarrer collecteurs en arrière-plan (modifie si tu n'as pas amass etc.)
( /root/go/bin/subfinder -d "$DOMAIN" -silent 2>/dev/null | sed 's/\.$//' >> "$RAW_SUBS" ) &
( /root/go/bin/assetfinder --subs-only "$DOMAIN" 2>/dev/null | sed 's/\.$//' >> "$RAW_SUBS" ) &
( /bin/crtsh "$DOMAIN" 2>/dev/null | sed 's/\.$//' >> "$RAW_SUBS" ) &
# tu peux ajouter crt.sh calls ici si tu as un wrapper ou script pour crt.sh
wait

# 2) dédup + nettoyage de base
sort -u "$RAW_SUBS" > "$SUBS"

# 3) Wildcard detection & résolution (dnsx)
# detect wildcard by resolving a random non-existent subdomain
RND="zzzz-$(date +%s)-$RANDOM"
if command -v /root/go/bin/dnsx >/dev/null 2>&1; then
  WILDCARD_IPS=$(printf "%s\n" "$RND.$DOMAIN" | /root/go/bin/dnsx -a 2>/dev/null | awk '{print $2}' | sort -u || true)
  if [ -n "$WILDCARD_IPS" ]; then
    echo "[!] Wildcard détecté : $WILDCARD_IPS (filtrage nécessaire)"
    # note: n'affiche pas la suppression automatique, on filtrera les entrées qui résolvent vers même IP
  fi

  # Résoudre la liste et garder A records valides
  /root/go/bin/dnsx -l "$SUBS" -a -resp -silent | awk '{print $1 " " $2}' > "$RESOLVED"
  # Filtrer les sous-domaines qui résolvent réellement et enlever l'éventuel wildcard
  awk '{print $1}' "$RESOLVED" | sort -u > "${SUBS}.resolved"
  mv "${SUBS}.resolved" "$SUBS"
else
  echo "[!] dnsx absent - skipping DNS resolution step"
fi

# 4) Probe HTTP (unique passe recommandée)
# OPTION A (recommandée): une seule passe httpx qui produit JSON
if command -v /root/go/bin/httpx >/dev/null 2>&1; then
  # Ajuste -threads / -timeout / -retries selon besoin
  /root/go/bin/httpx -l "$SUBS" -silent -status-code -title -tech-detect -json -o "$HTTPX_JSON" -threads 50 -timeout 3 -retries 1 >/dev/null 2>&1
  # Extraire la liste d'hôtes vivants (hostnames uniquement)
  jq -r '.url' "$HTTPX_JSON" | sort -u > "$ALIVE" || true
  jq -r '.url + "\t" + (."status_code"|tostring)' "$HTTPX_JSON"   | sort -u   | column -t -s $'\t' > "$ALIVE_WITH_CODES" || true

else
  echo "[!] httpx absent - skipping http probe"
fi

# 5) Find Subdomain Takovers
/root/go/bin/nuclei -l "$SUBS" -t ~/nuclei-templates/http/takeovers -timeout 3 -retries 2 -c 50 -silent -o $TAKEOVERS || true

echo "[*] Résumé pour $DOMAIN :"
echo "  raw collected: $(wc -l < "$RAW_SUBS")"
echo "  uniques resolved: $(wc -l < "$SUBS")"
[ -f "$ALIVE" ] && echo "  alive (http): $(wc -l < "$ALIVE")"
[ -f "$TAKEOVERS" ] && echo "  potential takeovers: $(wc -l < "$TAKEOVERS")"

echo "[*] Fichiers : $RAW_SUBS, $SUBS, $RESOLVED, $ALIVE, $HTTPX_JSON, $TAKEOVERS"
echo "[*] Fin reconnaissance $(date --iso-8601=seconds)"
