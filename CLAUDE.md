# Emergency Manager — Project Context

This is a multi-agent AO workflow for automated emergency management operations.
Agents in this repo participate in an ICS (Incident Command System)-compliant
emergency response pipeline that runs on a cron schedule.

---

## What This System Does

1. **Ingest** raw hazard data from NWS (weather), USGS (earthquakes), and local sensors
2. **Classify** hazards into a structured disaster record with severity tier and recommended action
3. **Issue alerts** across all public notification channels (EAS, WEA, social media, press)
4. **Mobilize resources** — deploy personnel, open shelters, request mutual aid
5. **Track deployment** — simulate and monitor resource status in real time
6. **Generate SITREPs** — comprehensive ICS situation reports synthesizing all data
7. **Review and escalate** — strategic operational decision (monitor/escalate/sustain/resolved)
8. **Plan recovery** — phased recovery strategy with after-action review

---

## File Locations

```
data/
  raw-hazards.json        # Input: hazard feed from APIs or sample scenarios
  disaster.json           # Output of classify-hazard phase
  alerts-issued.json      # Output of issue-alerts phase
  deployment-plan.json    # Output of mobilize-resources phase
  deployment-status.json  # Output of track-deployment script
  recovery-tasks.json     # Output of plan-recovery phase
  sample-hazards/         # Test scenarios (hurricane, earthquake, flood, wildfire)

output/alerts/
  eas-alert.txt           # Emergency Alert System broadcast
  wea-alert.txt           # Wireless Emergency Alert (360 char max)
  social-alert.txt        # Social media post
  press-release.txt       # Media press release

reports/
  sitrep-*.md             # Dated situation reports
  latest-sitrep.md        # Most recent SITREP (always current)
  recovery-plan.md        # Phased recovery strategy
  after-action-review.md  # AAR with lessons learned

config/
  jurisdiction.yaml       # Zone map, population, infrastructure, routes
  resource-inventory.yaml # Personnel, equipment, shelters, supplies
  staging-areas.yaml      # Staging and logistics areas

scripts/
  ingest-hazards.sh       # Fetches NWS + USGS APIs, falls back to sample data
  track-deployment.sh     # Simulates deployment status tracking
```

---

## Decision Logic

### classify-hazard phase
The hazard-monitor agent outputs a verdict that routes the workflow:
- `monitor` → skip to generate-sitrep (advisory — no response activation)
- `alert` → issue-alerts (watch/warning — public notification)
- `mobilize` → issue-alerts (emergency — full resource activation)

### review-sitrep phase
The recovery-planner agent evaluates the SITREP and decides:
- `escalate` → back to mobilize-resources (max 2 rework loops)
- `sustain` → plan-recovery (situation stable, ongoing)
- `resolved` → plan-recovery (threat passed, full recovery)

---

## ICS Terminology Used in This Repo

- **EOC** — Emergency Operations Center (unified command post)
- **SITREP** — Situation Report (ICS standard operational update)
- **EAS** — Emergency Alert System (broadcast radio/TV)
- **WEA** — Wireless Emergency Alert (cell phone push)
- **Mutual aid** — Resource sharing between jurisdictions
- **Staging area** — Pre-designated area for assembling resources before deployment
- **Unified command** — Multi-agency ICS structure for complex incidents
- **USAR** — Urban Search and Rescue
- **AAR** — After-Action Review (lessons learned document)
- **FEMA PA** — Public Assistance (federal reimbursement program)

---

## Agent Models and Why

| Agent | Model | Rationale |
|---|---|---|
| hazard-monitor | claude-haiku-4-5 | Fast, cheap classification — runs every 15 min, usually no-op |
| alert-coordinator | claude-sonnet-4-6 | Structured drafting follows established templates |
| resource-mobilizer | claude-sonnet-4-6 | Logistics optimization via sequential-thinking MCP |
| situation-reporter | claude-sonnet-4-6 | Clear technical writing, data synthesis |
| recovery-planner | claude-opus-4-6 | Cascading infrastructure reasoning, life-safety decisions |

---

## Notes for Agents Working in This Repo

- Always use UTC timestamps in all output files
- All JSON output files must be valid JSON (test with `python3 -m json.tool <file>`)
- Do not overwrite `data/sample-hazards/` — these are test fixtures
- If `data/deployment-plan.json` doesn't exist when `generate-sitrep` runs, skip that section in the SITREP
- WEA messages are strictly 360 characters max — count before writing
- The `reports/` directory is append-only in production; `latest-sitrep.md` is the only file that gets overwritten
- FEMA cost estimates should follow the FEMA Public Assistance category structure (A-G)
