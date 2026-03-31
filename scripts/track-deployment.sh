#!/usr/bin/env bash
# track-deployment.sh
# Simulates resource deployment progress tracking.
# Reads deployment-plan.json and generates deployment-status.json
# with realistic arrival times and utilization rates.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAN_FILE="$PROJECT_ROOT/data/deployment-plan.json"
STATUS_FILE="$PROJECT_ROOT/data/deployment-status.json"

echo "=== Emergency Manager: Deployment Tracker ==="
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

if [ ! -f "$PLAN_FILE" ]; then
    echo "ERROR: deployment-plan.json not found at $PLAN_FILE"
    echo "Skipping deployment tracking (no plan available)."
    # Write empty status rather than failing
    cat > "$STATUS_FILE" <<'EOF'
{
  "status": "no-plan",
  "message": "No deployment plan available — skipping tracking",
  "tracked_at": null,
  "summary": {
    "total_units": 0,
    "deployed": 0,
    "en_route": 0,
    "staged": 0,
    "operational": 0
  },
  "units": []
}
EOF
    echo "Wrote empty status to $STATUS_FILE"
    exit 0
fi

echo "Reading deployment plan: $PLAN_FILE"

python3 - <<'PYTHON' "$PLAN_FILE" "$STATUS_FILE"
import json, sys, random, math
from datetime import datetime, timezone, timedelta

plan_file = sys.argv[1]
status_file = sys.argv[2]

with open(plan_file) as f:
    plan = json.load(f)

now = datetime.now(timezone.utc)
now_str = now.isoformat()

def random_minutes_ago(min_m, max_m):
    """Return UTC timestamp for X minutes ago."""
    delta = random.randint(min_m, max_m)
    return (now - timedelta(minutes=delta)).isoformat()

def random_minutes_from_now(min_m, max_m):
    """Return UTC timestamp for X minutes in the future."""
    delta = random.randint(min_m, max_m)
    return (now + timedelta(minutes=delta)).isoformat()

def deployment_status(unit_type="default"):
    """Return a realistic deployment status weighted by unit type."""
    weights = {
        "personnel": ["operational", "en_route", "staged", "operational", "operational"],
        "equipment": ["staged", "en_route", "operational", "staged"],
        "shelter": ["activating", "operational", "operational"],
        "supply": ["en_route", "operational", "staged"],
        "default": ["en_route", "staged", "operational", "operational"]
    }
    return random.choice(weights.get(unit_type, weights["default"]))

units = []

# Track personnel units
for unit in plan.get("personnel", []):
    status = deployment_status("personnel")
    entry = {
        "type": "personnel",
        "unit": unit.get("unit", "Unknown Unit"),
        "count": unit.get("count", 0),
        "assignment": unit.get("assignment", ""),
        "staging_area": unit.get("staging_area", ""),
        "status": status,
        "dispatched_at": random_minutes_ago(45, 90),
        "arrived_at": random_minutes_ago(5, 40) if status in ["operational", "staged"] else None,
        "eta": random_minutes_from_now(10, 45) if status == "en_route" else None,
        "utilization_pct": random.randint(60, 95) if status == "operational" else 0,
        "incidents_handled": random.randint(0, 8) if status == "operational" else 0,
        "notes": ""
    }
    units.append(entry)

# Track equipment
for item in plan.get("equipment", []):
    status = deployment_status("equipment")
    entry = {
        "type": "equipment",
        "equipment_type": item.get("type", "Unknown"),
        "quantity": item.get("quantity", 1),
        "source": item.get("source", ""),
        "destination": item.get("destination", ""),
        "status": status,
        "dispatched_at": random_minutes_ago(30, 75),
        "arrived_at": random_minutes_ago(5, 25) if status in ["operational", "staged"] else None,
        "eta": random_minutes_from_now(15, 60) if status == "en_route" else None,
        "operational_units": item.get("quantity", 1) if status == "operational" else max(0, item.get("quantity", 1) - random.randint(0, 1)),
        "notes": ""
    }
    units.append(entry)

# Track shelters
for shelter in plan.get("shelters", []):
    status = deployment_status("shelter")
    capacity = shelter.get("capacity", 200)
    current_occupancy = int(capacity * random.uniform(0.05, 0.45)) if status == "operational" else 0
    entry = {
        "type": "shelter",
        "name": shelter.get("name", "Unknown Shelter"),
        "capacity": capacity,
        "status": status,
        "activated_at": random_minutes_ago(15, 50) if status in ["operational", "activating"] else None,
        "current_occupancy": current_occupancy,
        "occupancy_pct": round(current_occupancy / capacity * 100, 1) if capacity > 0 else 0,
        "supplies_on_site": status == "operational",
        "medical_staff_present": random.choice([True, False]),
        "notes": ""
    }
    units.append(entry)

# Compute summary
total = len(units)
operational = sum(1 for u in units if u.get("status") == "operational")
en_route = sum(1 for u in units if u.get("status") == "en_route")
staged = sum(1 for u in units if u.get("status") == "staged")
activating = sum(1 for u in units if u.get("status") == "activating")

# Overall operational percentage
operational_pct = round(operational / total * 100) if total > 0 else 0

# Write status output
status_doc = {
    "deployment_id": plan.get("deployment_id", "UNKNOWN"),
    "tracked_at": now_str,
    "elapsed_minutes_since_dispatch": random.randint(45, 90),
    "overall_operational_pct": operational_pct,
    "summary": {
        "total_units": total,
        "operational": operational,
        "en_route": en_route,
        "staged": staged,
        "activating": activating,
        "not_deployed": max(0, total - operational - en_route - staged - activating)
    },
    "resource_utilization": {
        "personnel_utilization_avg_pct": random.randint(55, 85),
        "equipment_deployment_rate_pct": round((operational + staged) / max(total, 1) * 100),
        "shelter_avg_occupancy_pct": round(
            sum(u.get("occupancy_pct", 0) for u in units if u["type"] == "shelter") /
            max(1, sum(1 for u in units if u["type"] == "shelter")), 1
        )
    },
    "critical_gaps": [],
    "units": units
}

# Identify critical gaps (shelters over 80% full, or units not yet operational)
for u in units:
    if u["type"] == "shelter" and u.get("occupancy_pct", 0) > 80:
        status_doc["critical_gaps"].append({
            "type": "shelter-near-capacity",
            "resource": u["name"],
            "detail": f"Shelter at {u['occupancy_pct']}% capacity — activate additional shelter"
        })
    if u["type"] == "personnel" and u.get("status") == "en_route":
        status_doc["critical_gaps"].append({
            "type": "unit-not-deployed",
            "resource": u.get("unit", "unknown"),
            "detail": f"Unit en route, ETA: {u.get('eta', 'unknown')}"
        })

with open(status_file, "w") as f:
    json.dump(status_doc, f, indent=2)

print(f"Tracked {total} deployment units")
print(f"  Operational: {operational} ({operational_pct}%)")
print(f"  En route:    {en_route}")
print(f"  Staged:      {staged}")
print(f"  Activating:  {activating}")
if status_doc["critical_gaps"]:
    print(f"  CRITICAL GAPS: {len(status_doc['critical_gaps'])}")
print(f"\nOutput: {status_file}")
PYTHON

echo "Done."
