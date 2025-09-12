#!/bin/bash
# Reconnaissance automatique Bug Bounty
# Usage: ./recon.sh example.com
set -euo pipefail

if [ -z "$1" ]; then
  echo "Usage: $0 <domain>"
  exit 1
fi

DOMAIN=$1

mkdir -p recon/$DOMAIN
cd recon/$DOMAIN

echo "[*] Lancement de la reconnaissance sur $DOMAIN..."

### 1. Subdomains
echo "[*] Collecte des sous-domaines..."

echo "[+] subfinder -d $DOMAIN -silent"
subfinder -d $DOMAIN -silent | tee subdomains.txt

echo "[+] assetfinder --subs-only $DOMAIN"	
assetfinder --subs-only $DOMAIN | tee -a subdomains.txt

echo "[+] amass enum -passive -d $DOMAIN"
amass enum -passive -d $DOMAIN | tee -a subdomains.txt

cat subdomains.txt | sort -u > subs.txt

### 2. Probe
echo "[*] Vérification des sous-domaines vivants..."

echo "[+] httpx -l subs.txt -silent -status-code -title -tech-detect -json > httpx.json"
cat subs.txt | httpx -silent -status-code -title -tech-detect -json > httpx.json

echo "[+] httpx -l subs.txt -silent > alive.txt"
cat subs.txt | httpx -silent > alive.txt

### 3. Screenshots
echo "[*] Screenshots des cibles vivantes..."

echo "[+] gowitness file -f alive.txt -P screenshots/ --no-http"
gowitness file -f alive.txt -P screenshots/ --no-http

### 4. Crawl + URLs
echo "[*] Récupération des endpoints publics..."

echo "[+] cat alive.txt | gau | tee urls.txt"
cat alive.txt | gau | tee urls.txt

echo "[+] cat alive.txt | waybackurls | tee -a urls.txt"
cat alive.txt | waybackurls | tee -a urls.txt

echo "[+] katana -list alive.txt -silent -o katana.txt"
katana -list alive.txt -silent -o katana.txt

cat urls.txt katana.txt | sort -u > all_urls.txt

### 5. Vulnérabilités de base
echo "[*] Scan nuclei..."

echo "[+] nuclei -l alive.txt -t ~/nuclei-templates/ -o nuclei.txt"
nuclei -l alive.txt -t ~/nuclei-templates/ -o nuclei.txt

### 6. Filtres intéressants
echo "[*] Extraction d’URLs intéressantes (paramètres potentiellement vulnérables)..."

cat all_urls.txt | grep "=" | tee params.txt

echo "[+] cat params.txt | gf xss > xss.txt"
cat params.txt | gf xss > xss.txt

echo "[+] cat params.txt | gf ssti > ssti.txt"
cat params.txt | gf sqli > sqli.txt

echo "[+] cat params.txt | gf lfi > lfi.txt"
cat params.txt | gf lfi > lfi.txt

echo "[*] Recon terminée pour $DOMAIN !"
echo "Résultats dans ./recon/$DOMAIN/"


