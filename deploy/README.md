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

## Upgrading from upstream later

`upstream` = danishashko/sovereign-aeo-tracker. `git fetch upstream && git merge
upstream/main`, resolve, push to `origin` (our fork).
