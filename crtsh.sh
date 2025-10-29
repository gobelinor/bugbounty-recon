# Usage: crtsh_query_append <domain> <output_file> 
domain="$1" 
out="${2:-/dev/stdout}" 
if [ -z "$domain" ]; then echo "Usage: crtsh_query_append <domain> <output_file>" >&2 
	exit 
fi 

url="https://crt.sh/?q=%25.${domain}&output=json" 
curl -sS --fail --retry 10 --retry-delay 2 --retry-all-errors --retry-connrefused --max-time 20 -A "crtsh-query-gogoliomax/1.0" "$url" 2>/dev/null \
	| jq -r '.[].name_value' \
	| sed 's/\*\.//g' \
	| tr '\r' '\n' \
	| awk 'NF' \
	| sort -u >> "$out" 2>/dev/null || true
