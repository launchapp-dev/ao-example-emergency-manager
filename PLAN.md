# Emergency Manager — Plan

Emergency management pipeline that monitors hazard feeds, classifies disaster severity,
issues public alerts, mobilizes resources, generates situation reports, coordinates
multi-agency response, and produces recovery plans with after-action reviews.

---

## Agents

| Agent | Model | Role |
|---|---|---|
| **hazard-monitor** | claude-haiku-4-5 | Fast hazard ingestion and classification. Reads raw hazard data (weather alerts, seismic sensors, flood gauges, fire reports), deduplicates, classifies by type and severity, outputs structured hazard record. |
| **alert-coordinator** | claude-sonnet-4-6 | Determines alert level and drafts public alert messages. Maps hazard severity to alert tiers (advisory/watch/warning/emergency), drafts multi-channel alert text (EAS, wireless emergency alert, social media), identifies affected zones and populations. |
| **resource-mobilizer** | claude-sonnet-4-6 | Plans resource deployment based on disaster type and scale. Assigns personnel, equipment, shelters, and supply depots. Uses sequential-thinking to optimize logistics given resource constraints and geographic coverage. |
| **situation-reporter** | claude-sonnet-4-6 | Generates structured situation reports (SITREPs) synthesizing all available data — hazard status, alert status, resource deployment, agency coordination, casualty estimates, infrastructure damage. |
| **recovery-planner** | claude-opus-4-6 | Strategic long-term thinker. Designs recovery plans including infrastructure restoration priorities, economic recovery, community support programs, and after-action review. Opus because recovery requires cross-cutting reasoning about cascading effects and long-term trade-offs. |

## MCP Servers

| Server | Package | Purpose |
|---|---|---|
| filesystem | @modelcontextprotocol/server-filesystem | Read/write hazard data, reports, resource inventories, alert drafts |
| sequential-thinking | @modelcontextprotocol/server-sequential-thinking | Structured reasoning for resource logistics optimization and recovery planning |
| fetch | @modelcontextprotocol/server-fetch | Fetch real weather/hazard data from public APIs (NWS, USGS) |

## Phase Pipeline

### Phase 1: `ingest-hazards` (command)
- **Type:** command
- **Script:** `bash scripts/ingest-hazards.sh`
- **Purpose:** Ingest hazard data from monitoring feeds (NWS alerts, USGS earthquakes, NOAA flood gauges)
- **Output:** `data/raw-hazards.json` — array of hazard objects with timestamp, type, location, magnitude, source
- **Notes:** Uses curl to fetch real public data from api.weather.gov and earthquake.usgs.gov; falls back to sample data if offline

### Phase 2: `classify-hazard` (agent: hazard-monitor)
- **Type:** agent
- **Purpose:** Classify hazard events by type, severity, and urgency; correlate related events into a single disaster record
- **Input:** `data/raw-hazards.json`
- **Output:** `data/disaster.json` — structured disaster record
- **Output contract:**
  ```json
  {
    "disaster_id": "DIS-YYYY-MM-DD-NNNN",
    "type": "hurricane|earthquake|flood|wildfire|tornado|hazmat|winter-storm|tsunami",
    "severity": "advisory|watch|warning|emergency",
    "title": "string",
    "affected_area": {
      "regions": ["County A", "County B"],
      "estimated_population": 150000,
      "coordinates": {"lat": 0.0, "lon": 0.0, "radius_miles": 25}
    },
    "hazard_count": 3,
    "correlated_hazards": [...],
    "initial_assessment": "string",
    "recommended_action": "monitor|alert|mobilize"
  }
  ```
- **Decision contract:**
  - `monitor` → skip to generate-sitrep (advisory level — informational, track only)
  - `alert` → proceed to issue-alerts (watch/warning — public notification needed)
  - `mobilize` → proceed to issue-alerts (emergency — full response activation)

### Phase 3: `issue-alerts` (agent: alert-coordinator)
- **Type:** agent
- **Purpose:** Draft public alert messages for multiple channels, determine affected zones, specify protective actions
- **Input:** `data/disaster.json`, `config/alert-templates/`, `config/jurisdiction.yaml`
- **Output:** `data/alerts-issued.json`, `output/alerts/`
- **Output contract:**
  ```json
  {
    "alert_tier": "watch|warning|emergency",
    "channels": [
      {"channel": "eas", "message": "string", "tone_code": "string"},
      {"channel": "wea", "message": "string (max 360 chars)"},
      {"channel": "social", "message": "string"},
      {"channel": "press_release", "message": "string"}
    ],
    "affected_zones": ["Zone A", "Zone B"],
    "protective_actions": ["Evacuate zones A-C", "Shelter in place zone D"],
    "evacuation_routes": ["Route 1 via Highway 101 North", "Route 2 via Interstate 5"],
    "shelter_locations": [{"name": "Central High School", "capacity": 500, "address": "string"}]
  }
  ```

### Phase 4: `mobilize-resources` (agent: resource-mobilizer)
- **Type:** agent (uses sequential-thinking MCP)
- **Purpose:** Plan resource deployment — personnel, equipment, shelters, supplies — optimized for disaster type and geographic coverage
- **Input:** `data/disaster.json`, `data/alerts-issued.json`, `config/resource-inventory.yaml`, `config/staging-areas.yaml`
- **Output:** `data/deployment-plan.json`
- **Output contract:**
  ```json
  {
    "deployment_id": "DEP-YYYY-MM-DD-NNNN",
    "activation_level": "partial|full|mutual-aid",
    "personnel": [
      {"unit": "Fire Station 12", "count": 15, "assignment": "search-and-rescue", "staging_area": "North Staging"}
    ],
    "equipment": [
      {"type": "swift-water-rescue-boat", "quantity": 3, "source": "County Fleet", "destination": "Flood Zone A"}
    ],
    "shelters": [
      {"name": "Central High School", "capacity": 500, "status": "activating", "supplies_eta": "2h"}
    ],
    "supply_depots": [
      {"location": "Warehouse B", "items": ["water", "MREs", "blankets", "first-aid"], "distribution_start": "string"}
    ],
    "mutual_aid_requests": [
      {"agency": "State National Guard", "resource": "helicopters", "quantity": 2, "status": "requested"}
    ],
    "estimated_cost": "$2.5M",
    "logistics_notes": "string"
  }
  ```

### Phase 5: `track-deployment` (command)
- **Type:** command
- **Script:** `bash scripts/track-deployment.sh`
- **Purpose:** Simulate resource deployment tracking — update deployment status, arrival times, utilization
- **Output:** `data/deployment-status.json` — updated status for each deployed resource
- **Notes:** Reads deployment-plan.json and simulates progress updates with randomized arrival/utilization

### Phase 6: `generate-sitrep` (agent: situation-reporter)
- **Type:** agent
- **Purpose:** Produce a comprehensive situation report synthesizing all pipeline data
- **Input:** all data files (disaster, alerts-issued, deployment-plan, deployment-status)
- **Output:** `reports/sitrep-YYYY-MM-DD-NNNN.md`, `reports/latest-sitrep.md`
- **Output structure:**
  1. Situation Overview (disaster type, severity, affected area, timeline)
  2. Hazard Status (current conditions, forecast, trajectory)
  3. Alert Status (alerts issued, channels used, population notified)
  4. Resource Deployment (personnel, equipment, shelters — status and utilization)
  5. Agency Coordination (responding agencies, mutual aid, command structure)
  6. Casualties & Damage (estimated injuries, fatalities, infrastructure damage)
  7. Immediate Needs (resource gaps, pending requests, bottlenecks)
  8. Next Actions (planned operations for next 6/12/24 hours)

### Phase 7: `review-sitrep` (agent: recovery-planner)
- **Type:** agent (decision phase)
- **Purpose:** Evaluate situation report and decide next phase of operation
- **Input:** `reports/latest-sitrep.md`, `data/disaster.json`
- **Decision contract:**
  - `escalate` → rework back to mobilize-resources (situation worsening — need more resources; max 2 rework attempts)
  - `sustain` → proceed to plan-recovery (situation stable — maintain current operations, begin recovery planning)
  - `resolved` → proceed to plan-recovery (immediate threat passed — transition to full recovery)

### Phase 8: `plan-recovery` (agent: recovery-planner)
- **Type:** agent (uses sequential-thinking MCP)
- **Purpose:** Design comprehensive recovery plan and produce after-action review
- **Input:** `reports/latest-sitrep.md`, `data/deployment-plan.json`, `data/disaster.json`
- **Output:** `reports/recovery-plan.md`, `reports/after-action-review.md`, `data/recovery-tasks.json`
- **Output contract (recovery-tasks.json):**
  ```json
  {
    "recovery_phases": [
      {
        "phase": "immediate (0-72h)",
        "tasks": [
          {"id": "REC-001", "title": "string", "priority": "critical|high|medium", "responsible_agency": "string", "estimated_duration": "string"}
        ]
      },
      {"phase": "short-term (1-4 weeks)", "tasks": [...]},
      {"phase": "long-term (1-12 months)", "tasks": [...]}
    ],
    "infrastructure_priorities": [
      {"system": "power-grid", "damage_level": "severe", "estimated_restoration": "72h", "dependencies": ["road-access"]}
    ],
    "cost_estimate": {
      "immediate": "$5M",
      "short_term": "$25M",
      "long_term": "$150M",
      "fema_eligible": "$120M"
    },
    "lessons_learned": [
      {"category": "preparedness|response|communication|logistics", "finding": "string", "recommendation": "string"}
    ]
  }
  ```

## Workflows

### 1. `emergency-response` (default — full pipeline)
Full emergency management lifecycle from hazard detection through recovery planning.

```
ingest-hazards → classify-hazard
  ├─ monitor → generate-sitrep → review-sitrep → plan-recovery
  ├─ alert → issue-alerts → mobilize-resources → track-deployment → generate-sitrep → review-sitrep
  │     ├─ escalate → [rework → mobilize-resources, max 2]
  │     ├─ sustain → plan-recovery
  │     └─ resolved → plan-recovery
  └─ mobilize → issue-alerts → mobilize-resources → track-deployment → generate-sitrep → review-sitrep
        ├─ escalate → [rework → mobilize-resources, max 2]
        ├─ sustain → plan-recovery
        └─ resolved → plan-recovery
```

### 2. `hazard-scan` (quick monitoring only)
Fast hazard check — classify and log, no response activation.

```
ingest-hazards → classify-hazard
```

### 3. `sitrep-only` (situation report update)
For ongoing events — update the situation report and review.

```
generate-sitrep → review-sitrep → plan-recovery
```

## Schedules

| Schedule | Cron | Workflow | Purpose |
|---|---|---|---|
| continuous-hazard-scan | `*/15 * * * *` | hazard-scan | Monitor hazard feeds every 15 minutes |
| hourly-full-response | `0 * * * *` | emergency-response | Full emergency response pipeline every hour |
| sitrep-update | `*/30 * * * *` | sitrep-only | Update situation reports every 30 minutes during active events |

## Supporting Files

### `config/jurisdiction.yaml`
Jurisdiction boundaries, population data, and critical infrastructure locations.
```yaml
jurisdiction:
  name: "Sample County Emergency Management"
  fips_code: "06001"
  population: 1650000
  area_sq_miles: 821
  zones:
    - id: zone-a
      name: "North Valley"
      population: 320000
      flood_risk: high
      fire_risk: moderate
    - id: zone-b
      name: "Downtown Core"
      population: 450000
      flood_risk: low
      fire_risk: low
  critical_infrastructure:
    hospitals: ["General Hospital", "St. Mary's Medical Center"]
    schools: ["Central High", "Valley Elementary", "Westside Middle"]
    utilities: ["Power Plant Alpha", "Water Treatment Facility"]
    evacuation_routes: ["Highway 101 North", "Interstate 5 South", "Route 9 East"]
```

### `config/resource-inventory.yaml`
Available emergency resources — personnel, equipment, supplies, shelters.
```yaml
resources:
  personnel:
    - unit: "Fire Station 12"
      type: fire
      count: 25
      capabilities: [firefighting, search-and-rescue, hazmat]
    - unit: "Police Precinct 3"
      type: law-enforcement
      count: 40
      capabilities: [traffic-control, evacuation, security]
    - unit: "EMS Unit Alpha"
      type: medical
      count: 12
      capabilities: [triage, emergency-transport, field-hospital]
  equipment:
    - type: swift-water-rescue-boat
      quantity: 4
      location: "County Fleet Depot"
    - type: generator-50kw
      quantity: 8
      location: "Warehouse B"
    - type: water-tanker
      quantity: 3
      location: "County Fleet Depot"
  shelters:
    - name: "Central High School"
      capacity: 500
      amenities: [generator, kitchen, showers]
    - name: "Convention Center"
      capacity: 2000
      amenities: [generator, kitchen, medical-station]
  supplies:
    water_gallons: 50000
    mre_count: 25000
    blankets: 10000
    first_aid_kits: 500
    cots: 3000
```

### `config/staging-areas.yaml`
Pre-designated staging and logistics areas.
```yaml
staging_areas:
  - id: north-staging
    name: "North Valley Staging Area"
    location: "Fairgrounds Parking Lot"
    capacity: "200 vehicles"
    coordinates: {lat: 37.85, lon: -122.15}
  - id: south-staging
    name: "South County Staging Area"
    location: "Industrial Park C"
    capacity: "150 vehicles"
    coordinates: {lat: 37.60, lon: -122.10}
  - id: command-post
    name: "Emergency Operations Center"
    location: "County Admin Building, Room 200"
    capacity: "50 personnel"
    coordinates: {lat: 37.72, lon: -122.12}
```

### `config/alert-templates/`
- `eas-template.txt` — Emergency Alert System broadcast template
- `wea-template.txt` — Wireless Emergency Alert template (360-char limit)
- `social-media-template.txt` — Social media alert template
- `press-release-template.txt` — Press release template for media

### `scripts/ingest-hazards.sh`
Fetches real hazard data from public APIs (api.weather.gov for weather alerts, earthquake.usgs.gov for seismic events) with curl. Falls back to sample data from `data/sample-hazards/` if offline.

### `scripts/track-deployment.sh`
Simulates resource deployment progress — reads deployment-plan.json and generates deployment-status.json with randomized arrival times and utilization rates.

### `data/sample-hazards/`
Pre-built hazard scenarios for testing:
- `scenario-hurricane.json` — Category 3 hurricane making landfall
- `scenario-earthquake.json` — 6.2 magnitude earthquake, urban area
- `scenario-flood.json` — Flash flooding from heavy rainfall
- `scenario-wildfire.json` — Fast-moving wildfire approaching residential areas

## Design Decisions

1. **Haiku for hazard monitoring** — Fast classification of incoming hazard data. Keeps cost low for frequent 15-minute scans that usually find nothing actionable.
2. **Sonnet for alert coordination, resource mobilization, and situation reporting** — These require structured analysis and clear writing but follow established emergency management patterns. Good balance of quality and throughput.
3. **Opus for recovery planning and situation review** — Recovery planning requires reasoning about cascading infrastructure dependencies, competing priorities, and long-term economic trade-offs. The review-sitrep decision also uses Opus because escalation decisions are life-safety critical.
4. **Three-tier triage (monitor/alert/mobilize)** — Advisory-level hazards are tracked but don't activate response. Watch/warning triggers public alerts. Emergency triggers full resource mobilization. Maps to real FEMA activation levels.
5. **Escalation rework loop (max 2)** — If the situation worsens during response, the pipeline loops back to mobilize-resources for additional deployment. After 2 escalations, it proceeds to recovery planning regardless (prevents infinite loops).
6. **Real public API data** — The ingest script uses real NWS and USGS APIs (free, no auth required) for authentic hazard data. Sample scenarios are fallback for offline/demo use.
7. **Fetch MCP for real-time data** — The fetch MCP server enables agents to pull live weather forecasts and seismic data during their analysis, not just during the initial ingest phase.
8. **ICS-compliant terminology** — Uses Incident Command System terms (staging areas, mutual aid, SITREP) to match real emergency management practice.
9. **Command phases for data I/O** — Hazard ingestion (curl to public APIs) and deployment tracking (simulation script) are command phases, demonstrating AO's mixed agent+command pipeline capability.
