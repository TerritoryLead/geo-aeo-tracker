# Deploy — geo-aeo-tracker on the Hetzner box (O1: run as-is)

Runs the tracker as a systemd service on `:3939`. No Docker. `run_aeo.py`
(vertical_insights) drives it over HTTP (`localhost:3939`) and via
`node scripts/run-company.mjs`, so **the tracker must be on the same host as
the Python pipeline** for the current integration.

## 1. Node (pinned by `.nvmrc` -> Node 22 LTS; Next 16 needs >= 20.9)

System install (matches the service's default `ExecStart=/usr/bin/npm`):

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
node -v   # v22.x
```

(Or nvm — then use the nvm `ExecStart` variant commented in the unit.)

## 2. Clone + build

Clone dir name must be `sovereign-aeo-tracker` OR update `AEO_REPO` in
`reports/ci_pipeline/run_aeo.py`. The unit's `WorkingDirectory` is
`/opt/geo-aeo-tracker` — pick one and keep them consistent.

```bash
sudo mkdir -p /opt/geo-aeo-tracker && sudo chown octo:octo /opt/geo-aeo-tracker
git clone git@github.com:TerritoryLead/geo-aeo-tracker.git /opt/geo-aeo-tracker
cd /opt/geo-aeo-tracker
npm ci
npm run build
```

## 3. Secrets

Copy `.env` (NOT in git) to `/opt/geo-aeo-tracker/.env`:
`BRIGHT_DATA_KEY`, `BRIGHT_DATA_DATASET_*`, `SUPABASE_*`, `GEMINI_API_KEY`,
`OPENROUTER_KEY`, `STATE_SYNC_SECRET`. AEO scraping goes out through
Brightdata, so the box's own (data-centre) IP is never used for it.

## 4. Install + start the service

```bash
sudo cp deploy/geo-aeo-tracker.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now geo-aeo-tracker
systemctl status geo-aeo-tracker
curl -sI http://localhost:3939/api/scrape   # 405 = tracker is up (GET not allowed)
```

## 5. Update on new commits

```bash
cd /opt/geo-aeo-tracker && git pull && npm ci && npm run build
sudo systemctl restart geo-aeo-tracker
```

## Weekly client tracking (Phase 2)

Runs `py/weekly_run.py` on a timer: reads active+due rows from `aeo.client`,
scrapes each via `run-company.mjs`, analyses, and writes `aeo.coverage`
(`subject_type='client'`), stamping `last_run_at`.

### Prereqs on the box
- **Warehouse reachable.** The warehouse is GCP Cloud SQL (`app_prod`) and the
  box isn't on GCP, so run `cloud_sql_proxy` as its own service (with a GCP
  service-account key). `AEO_WAREHOUSE_DSN` should include a **host**; if it
  doesn't (e.g. the admin URL), set `PGHOST=127.0.0.1`/`PGPORT=5432` in the unit.
- **Schema exists.** Backend migration applied:
  `combined/database/postgres/migrations/002_aeo_schema.sql`.
- **Python deps:** `pip install -r py/requirements.txt`.
- **Tracker service up** (the weekly runner scrapes against `:3939`).

### Install the timer
```bash
sudo cp deploy/geo-aeo-tracker-weekly.service deploy/geo-aeo-tracker-weekly.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now geo-aeo-tracker-weekly.timer
systemctl list-timers geo-aeo-tracker-weekly.timer      # confirm next run (Sun 04:00)
# manual test of ONE client (metered — costs Brightdata):
sudo -u octo python3 py/weekly_run.py --client dibara_masonry
```

Onboard more clients with the `aeo-client-registry` skill.

## Upgrading from upstream later

`upstream` = danishashko/sovereign-aeo-tracker. `git fetch upstream && git merge
upstream/main`, resolve, push to `origin` (our fork).
