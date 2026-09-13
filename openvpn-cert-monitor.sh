#!/bin/bash

set -u

CONFIG_FILE="/etc/zabbix/openvpn-cert-monitor.conf"

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CONFIG_FILE"
fi

PKI_DIR="${PKI_DIR:-/etc/openvpn/easy-rsa/pki}"
ISSUED_DIR="$PKI_DIR/issued"
INDEX_FILE="$PKI_DIR/index.txt"
EXPIRED_KEEP_DAYS="${EXPIRED_KEEP_DAYS:-30}"

if [ ! -d "$PKI_DIR" ]; then
    echo "ERROR: PKI directory not found: $PKI_DIR" >&2
    exit 1
fi

if [ ! -d "$ISSUED_DIR" ]; then
    echo "ERROR: issued directory not found: $ISSUED_DIR" >&2
    exit 1
fi

if [ ! -f "$INDEX_FILE" ]; then
    echo "ERROR: index.txt not found: $INDEX_FILE" >&2
    exit 1
fi

NOW=$(date +%s)

TOTAL=0
VALID=0
EXPIRED=0
REVOKED=0
ERRORS=0
EXPIRING_60D=0
EXPIRING_30D=0
EXPIRING_15D=0
EXPIRING_7D=0
IGNORED_OLD_EXPIRED=0
IGNORED_REVOKED=0

TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT

FIRST=1

for CERT in "$ISSUED_DIR"/*.crt; do
    [ -e "$CERT" ] || continue

    TOTAL=$((TOTAL + 1))

    CN=$(openssl x509 -in "$CERT" -noout -subject 2>/dev/null \
        | sed -n 's/.*CN *= *//p')

    SERIAL=$(openssl x509 -in "$CERT" -noout -serial 2>/dev/null \
        | cut -d= -f2)

    START_RAW=$(openssl x509 -in "$CERT" -noout -startdate 2>/dev/null \
        | cut -d= -f2)

    END_RAW=$(openssl x509 -in "$CERT" -noout -enddate 2>/dev/null \
        | cut -d= -f2)

    END_EPOCH=$(date -d "$END_RAW" +%s 2>/dev/null || true)

    INDEX_STATUS=$(awk -v s="$SERIAL" '
    {
        for (i=1; i<=NF; i++) {
            if ($i == s) {
                print $1
                exit
            }
        }
    }' "$INDEX_FILE")

    INCLUDE=1

    if [ -z "$CN" ] || [ -z "$SERIAL" ] || [ -z "$END_EPOCH" ]; then
        STATUS="ERROR"
        DAYS_LEFT=-999999
        ERRORS=$((ERRORS + 1))

    elif [ "$INDEX_STATUS" = "R" ]; then
        STATUS="REVOKED"
        DAYS_LEFT=$(( (END_EPOCH - NOW) / 86400 ))
        REVOKED=$((REVOKED + 1))
        INCLUDE=0
        IGNORED_REVOKED=$((IGNORED_REVOKED + 1))

    elif [ "$END_EPOCH" -lt "$NOW" ]; then
        STATUS="EXPIRED"
        DAYS_LEFT=$(( (END_EPOCH - NOW) / 86400 ))
        EXPIRED=$((EXPIRED + 1))

        EXPIRED_AGE_DAYS=$(( (NOW - END_EPOCH) / 86400 ))

        if [ "$EXPIRED_AGE_DAYS" -gt "$EXPIRED_KEEP_DAYS" ]; then
            INCLUDE=0
            IGNORED_OLD_EXPIRED=$((IGNORED_OLD_EXPIRED + 1))
        fi

    else
        STATUS="VALID"
        DAYS_LEFT=$(( (END_EPOCH - NOW) / 86400 ))
        VALID=$((VALID + 1))

        if [ "$DAYS_LEFT" -le 60 ]; then
            EXPIRING_60D=$((EXPIRING_60D + 1))
        fi
        if [ "$DAYS_LEFT" -le 30 ]; then
            EXPIRING_30D=$((EXPIRING_30D + 1))
        fi
        if [ "$DAYS_LEFT" -le 15 ]; then
            EXPIRING_15D=$((EXPIRING_15D + 1))
        fi
        if [ "$DAYS_LEFT" -le 7 ]; then
            EXPIRING_7D=$((EXPIRING_7D + 1))
        fi
    fi

    if [ "$INCLUDE" -eq 0 ]; then
        continue
    fi

    if [ "$FIRST" -eq 0 ]; then
        printf ',\n' >> "$TMP_FILE"
    fi
    FIRST=0

    printf '    {\n' >> "$TMP_FILE"
    printf '      "name": "%s",\n' "$CN" >> "$TMP_FILE"
    printf '      "file": "%s",\n' "$CERT" >> "$TMP_FILE"
    printf '      "serial": "%s",\n' "$SERIAL" >> "$TMP_FILE"
    printf '      "not_before": "%s",\n' "$START_RAW" >> "$TMP_FILE"
    printf '      "not_after": "%s",\n' "$END_RAW" >> "$TMP_FILE"
    printf '      "days_left": %s,\n' "$DAYS_LEFT" >> "$TMP_FILE"
    printf '      "status": "%s",\n' "$STATUS" >> "$TMP_FILE"
    printf '      "index_status": "%s"\n' "$INDEX_STATUS" >> "$TMP_FILE"
    printf '    }' >> "$TMP_FILE"
done

printf '{\n'
printf '  "pki_dir": "%s",\n' "$PKI_DIR"
printf '  "summary": {\n'
printf '    "total": %d,\n' "$TOTAL"
printf '    "valid": %d,\n' "$VALID"
printf '    "expired": %d,\n' "$EXPIRED"
printf '    "revoked": %d,\n' "$REVOKED"
printf '    "errors": %d,\n' "$ERRORS"
printf '    "expiring_60d": %d,\n' "$EXPIRING_60D"
printf '    "expiring_30d": %d,\n' "$EXPIRING_30D"
printf '    "expiring_15d": %d,\n' "$EXPIRING_15D"
printf '    "expiring_7d": %d,\n' "$EXPIRING_7D"
printf '    "ignored_old_expired": %d,\n' "$IGNORED_OLD_EXPIRED"
printf '    "ignored_revoked": %d\n' "$IGNORED_REVOKED"
printf '  },\n'
printf '  "certificates": [\n'
cat "$TMP_FILE"
printf '\n  ]\n'
printf '}\n'
