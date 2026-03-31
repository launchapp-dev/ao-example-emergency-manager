#!/usr/bin/env bash
# ingest-hazards.sh
# Fetches hazard data from public APIs (NWS weather alerts, USGS earthquakes)
# Falls back to sample scenario data if network is unavailable.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_FILE="$PROJECT_ROOT/data/raw-hazards.json"

mkdir -p "$PROJECT_ROOT/data"

echo "=== Emergency Manager: Hazard Ingestion ==="
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# --- Fetch NWS Active Weather Alerts (free, no auth required) ---
NWS_URL="https://api.weather.gov/alerts/active?status=actual&message_type=alert,update&urgency=Immediate,Expected&area=CA"
NWS_HAZARDS="[]"

echo "Fetching NWS weather alerts..."
if NWS_RESPONSE=$(curl -sf --max-time 15 \
    -H "Accept: application/geo+json" \
    -H "User-Agent: SampleCountyEMS/1.0 (emergency-manager@example.gov)" \
    "$NWS_URL" 2>/dev/null); then
    # Extract relevant fields from NWS GeoJSON format
    NWS_HAZARDS=$(echo "$NWS_RESPONSE" | python3 -c "
import json, sys, re
from datetime import datetime, timezone

data = json.load(sys.stdin)
hazards = []
for feature in data.get('features', [])[:10]:  # cap at 10 alerts
    props = feature.get('properties', {})
    geom  = feature.get('geometry') or {}
    sent  = props.get('sent', '')

    hazards.append({
        'source': 'NWS',
        'source_id': props.get('id', ''),
        'type': 'weather-alert',
        'sub_type': props.get('event', 'Unknown'),
        'severity': props.get('severity', 'Unknown').lower(),
        'urgency': props.get('urgency', 'Unknown').lower(),
        'certainty': props.get('certainty', 'Unknown').lower(),
        'headline': props.get('headline', ''),
        'description': (props.get('description', '') or '')[:500],
        'instruction': (props.get('instruction', '') or '')[:300],
        'area_desc': props.get('areaDesc', ''),
        'sent_utc': sent,
        'effective_utc': props.get('effective', sent),
        'expires_utc': props.get('expires', ''),
        'geometry': geom
    })
print(json.dumps(hazards))
" 2>/dev/null) || NWS_HAZARDS="[]"
    COUNT=$(echo "$NWS_HAZARDS" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
    echo "  Fetched $COUNT NWS weather alerts"
else
    echo "  NWS API unavailable — will use sample data"
fi

# --- Fetch USGS Earthquake Feed (free, no auth required) ---
# Last hour, magnitude 2.5+, global
USGS_URL="https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/2.5_hour.geojson"
USGS_HAZARDS="[]"

echo "Fetching USGS earthquake data..."
if USGS_RESPONSE=$(curl -sf --max-time 15 "$USGS_URL" 2>/dev/null); then
    USGS_HAZARDS=$(echo "$USGS_RESPONSE" | python3 -c "
import json, sys
from datetime import datetime, timezone

data = json.load(sys.stdin)
hazards = []
for feature in data.get('features', [])[:5]:  # cap at 5 quakes
    props = feature.get('properties', {})
    geom  = feature.get('geometry', {})
    coords = geom.get('coordinates', [None, None, None])
    mag = props.get('mag', 0)
    if mag is None:
        mag = 0

    # Classify severity by magnitude
    if mag >= 7.0:
        severity = 'emergency'
    elif mag >= 6.0:
        severity = 'warning'
    elif mag >= 5.0:
        severity = 'watch'
    else:
        severity = 'advisory'

    ts = props.get('time', 0)
    dt = datetime.fromtimestamp(ts / 1000, tz=timezone.utc).isoformat() if ts else ''

    hazards.append({
        'source': 'USGS',
        'source_id': feature.get('id', ''),
        'type': 'earthquake',
        'sub_type': props.get('type', 'earthquake'),
        'magnitude': mag,
        'severity': severity,
        'urgency': 'immediate' if mag >= 6.0 else 'expected',
        'certainty': 'observed',
        'headline': props.get('title', ''),
        'description': f\"Magnitude {mag} {props.get('type','earthquake')} at depth {coords[2] if len(coords)>2 else 'unknown'} km\",
        'instruction': 'Drop, Cover, and Hold On. Expect aftershocks. Avoid damaged structures.',
        'area_desc': props.get('place', ''),
        'sent_utc': dt,
        'effective_utc': dt,
        'expires_utc': '',
        'geometry': geom
    })
print(json.dumps(hazards))
" 2>/dev/null) || USGS_HAZARDS="[]"
    COUNT=$(echo "$USGS_HAZARDS" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
    echo "  Fetched $COUNT USGS earthquake events"
else
    echo "  USGS API unavailable — will use sample data"
fi

# --- Combine API results ---
COMBINED=$(python3 -c "
import json, sys
nws = json.loads('''$NWS_HAZARDS''')
usgs = json.loads('''$USGS_HAZARDS''')
combined = nws + usgs
print(json.dumps(combined, indent=2))
" 2>/dev/null) || COMBINED="[]"

TOTAL=$(echo "$COMBINED" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

# --- Fall back to sample data if nothing retrieved ---
if [ "$TOTAL" -eq "0" ]; then
    echo ""
    echo "No live hazard data retrieved. Loading sample scenario for demonstration..."
    SCENARIO_DIR="$PROJECT_ROOT/data/sample-hazards"
    # Pick the scenario with the most recent modification time
    SAMPLE_FILE=$(ls -t "$SCENARIO_DIR"/scenario-*.json 2>/dev/null | head -1)
    if [ -n "$SAMPLE_FILE" ]; then
        echo "  Using sample: $(basename "$SAMPLE_FILE")"
        COMBINED=$(cat "$SAMPLE_FILE")
    else
        echo "  No sample files found. Writing empty hazard array."
        COMBINED="[]"
    fi
fi

# --- Write output ---
echo "$COMBINED" > "$OUTPUT_FILE"
FINAL_COUNT=$(echo "$COMBINED" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else 1)" 2>/dev/null || echo "?")
echo ""
echo "Output: $OUTPUT_FILE"
echo "Hazard records: $FINAL_COUNT"
echo "Done."
