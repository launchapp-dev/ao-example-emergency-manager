# emergency-manager

AI-powered emergency management pipeline that detects hazards, issues public alerts, mobilizes resources, generates situation reports, and produces recovery plans — from raw sensor data to after-action review, fully automated.

---

## Workflow Diagram

```
[CRON: every 15 min]
         │
         ▼
  ┌─────────────────┐
  │  ingest-hazards  │  (command: curl NWS + USGS APIs → data/raw-hazards.json)
  └────────┬────────┘
           │
           ▼
  ┌──────────────────┐
  │ classify-hazard  │  (agent: hazard-monitor / claude-haiku-4-5)
  │                  │  deduplicates, correlates, classifies
  └────────┬─────────┘
           │
     ┌─────┴──────┐
     │  verdict?  │
     └──┬──┬───┬──┘
   monitor │alert │mobilize
        │  │    │
        │  └────┘
        │     │
        │     ▼
        │  ┌──────────────────┐
        │  │  issue-alerts    │  (agent: alert-coordinator / claude-sonnet-4-6)
        │  │                  │  EAS + WEA + social + press release
        │  └────────┬─────────┘
        │           │
        │           ▼
        │  ┌──────────────────────┐
        │  │  mobilize-resources  │  (agent: resource-mobilizer / claude-sonnet-4-6)
        │  │                      │  ICS-compliant deployment planning
        │  └────────┬─────────────┘
        │           │
        │           ▼
        │  ┌──────────────────────┐
        │  │  track-deployment    │  (command: simulate deployment status)
        │  └────────┬─────────────┘
        │           │
        └─────►─────┘
               │
               ▼
     ┌──────────────────┐
     │ generate-sitrep  │  (agent: situation-reporter / claude-sonnet-4-6)
     │                  │  ICS SITREP — 8 required sections
     └────────┬─────────┘
              │
              ▼
     ┌──────────────────┐
     │  review-sitrep   │  (agent: recovery-planner / claude-opus-4-6)
     │                  │  operational decision gate
     └────────┬─────────┘
              │
        ┌─────┴──────┐
        │  verdict?  │
        └──┬────┬────┘
      escalate │sustain/resolved
           │   │
           │   └──────────────────────────────────┐
           │                                       │
           ▼  (max 2 escalations)                  ▼
  ┌──────────────────────┐              ┌──────────────────┐
  │  mobilize-resources  │◄─(rework)    │  plan-recovery   │
  │  (additional deploy) │              │                  │
  └──────────────────────┘              │ recovery-plan.md │
                                        │ after-action.md  │
                                        └──────────────────┘
```

---

## Workflows

| Workflow | Description | When to Use |
|---|---|---|
| `emergency-response` | Full pipeline from ingestion to recovery | Active emergency response |
| `hazard-scan` | Ingest + classify only | Frequent background monitoring |
| `sitrep-only` | Update SITREP for ongoing events | During sustained operations |

---

## Agents

| Agent | Model | Role |
|---|---|---|
| **hazard-monitor** | claude-haiku-4-5 | Fast hazard classification — deduplicates feeds, correlates events, outputs structured disaster record |
| **alert-coordinator** | claude-sonnet-4-6 | Drafts public alerts for EAS, WEA (wireless), social media, and press — follows IPAWS guidelines |
| **resource-mobilizer** | claude-sonnet-4-6 | ICS-compliant resource deployment planning — personnel, equipment, shelters, mutual aid |
| **situation-reporter** | claude-sonnet-4-6 | Generates comprehensive ICS SITREPs synthesizing all operational data |
| **recovery-planner** | claude-opus-4-6 | Strategic recovery planning with infrastructure dependency analysis and after-action review |

---

## AO Features Demonstrated

- **Multi-phase pipeline** with 8 sequential phases
- **Decision routing** — `classify-hazard` routes to 3 different next phases (monitor/alert/mobilize)
- **Rework loop** — `review-sitrep` can escalate back to `mobilize-resources` up to 2 times
- **Mixed phase types** — command phases (data ingestion, tracking) + agent phases (analysis, planning)
- **Multiple models** — Haiku for fast classification, Sonnet for structured analysis, Opus for strategic reasoning
- **Cron schedules** — continuous hazard scan every 15 minutes
- **MCP servers** — filesystem (data I/O), sequential-thinking (logistics optimization), fetch (live API data)
- **Real public APIs** — NWS weather alerts and USGS earthquake feeds (no auth required)
- **Output contracts** — structured JSON outputs with defined schemas at each phase
- **ICS terminology** — Incident Command System compliant (staging areas, unified command, mutual aid)

---

## Quick Start

```bash
cd workflows/emergency-manager
ao daemon start

# Run a quick hazard scan (every 15 minutes via cron, or manually):
ao workflow run hazard-scan

# Run the full emergency response pipeline:
ao workflow run emergency-response

# Update situation report for ongoing event:
ao workflow run sitrep-only

# Watch logs:
ao daemon stream --pretty

# Check status:
ao status
```

### Test with a specific scenario

The scripts fall back to sample data when APIs are offline. To test with a specific scenario:

```bash
# Use the wildfire scenario
cp data/sample-hazards/scenario-wildfire.json data/raw-hazards.json

# Then run the full pipeline
ao workflow run emergency-response
```

---

## Output Files

After a successful run, you'll find:

```
data/
  raw-hazards.json          # Ingested hazard feed
  disaster.json             # Classified disaster record
  alerts-issued.json        # Alert summary
  deployment-plan.json      # Resource deployment plan
  deployment-status.json    # Live deployment tracking
  recovery-tasks.json       # Structured recovery task list

output/alerts/
  eas-alert.txt             # Emergency Alert System message
  wea-alert.txt             # Wireless Emergency Alert (mobile)
  social-alert.txt          # Social media post
  press-release.txt         # Media press release

reports/
  sitrep-YYYY-MM-DD-DIS-*.md   # Dated situation report
  latest-sitrep.md             # Always the most recent SITREP
  recovery-plan.md             # Comprehensive recovery strategy
  after-action-review.md       # AAR with lessons learned
```

---

## Requirements

### API Keys
None required — uses free public APIs:
- **NWS API** (api.weather.gov) — no auth
- **USGS Earthquake API** (earthquake.usgs.gov) — no auth

### Tools
- `curl` — for API ingestion (included on macOS/Linux)
- `python3` — for JSON processing in scripts (included on macOS)
- `npx` — for MCP servers

### MCP Servers (auto-installed via npx)
- `@modelcontextprotocol/server-filesystem` — file read/write
- `@modelcontextprotocol/server-sequential-thinking` — logistics optimization
- `@modelcontextprotocol/server-fetch` — live data enrichment

### AO
- `ao daemon start` from this directory
- AO version that supports the `on_verdict` routing syntax

---

## Configuration

Edit these files to customize for your jurisdiction:

| File | Purpose |
|---|---|
| `config/jurisdiction.yaml` | Zone boundaries, population, infrastructure, evacuation routes |
| `config/resource-inventory.yaml` | Available personnel, equipment, shelters, supplies |
| `config/staging-areas.yaml` | Pre-designated staging and logistics locations |
| `config/alert-templates/` | EAS, WEA, social media, and press release templates |

---

## Schedules

| Schedule | Cron | Workflow | Default |
|---|---|---|---|
| `continuous-hazard-scan` | `*/15 * * * *` | hazard-scan | enabled |
| `hourly-full-response` | `0 * * * *` | emergency-response | disabled |
| `sitrep-update` | `*/30 * * * *` | sitrep-only | disabled |

Enable/disable schedules in `.ao/workflows/schedules.yaml`.
Activate `hourly-full-response` and `sitrep-update` during active incidents.
