#!/usr/bin/env python3
"""AEO warehouse writer — owns the `aeo.*` schema (this repo owns all DB).

Standalone: NO dependency on vertical_insights. Callers pass plain values
(vertical_insights' thin wrapper adapts its CI Config; the weekly client routine
passes registry-row fields). Both write to `aeo.coverage`:

    SELECT entity, round(avg(coverage)*100) cov_pct
    FROM aeo.coverage
    WHERE vertical='masonry' AND engine=''
    GROUP BY entity ORDER BY cov_pct DESC;

Connection: AEO_WAREHOUSE_DSN, loaded from THIS repo's .env (so the warehouse
credential lives in one place — the AEO repo — regardless of caller).

Schema is owned by the BACKEND repo (combined/database/postgres/migrations/
002_aeo_schema.sql) — apply that against the warehouse before writing. This
writer only reads/writes rows; it never creates the schema.

CLI:
  python3 py/aeo_warehouse.py --findings <aeo_findings.json> \
      --slug <s> --subject-type client --name "<brand>" \
      --domain <d> --vertical <tag> [--run-date YYYY-MM-DD] [--dry-run]
"""
from __future__ import annotations

import argparse
import json
import os
from datetime import date, datetime
from pathlib import Path

from dotenv import load_dotenv

REPO = Path(__file__).resolve().parents[1]     # the AEO repo root
load_dotenv(REPO / ".env")

SCHEMA = os.environ.get("AEO_WAREHOUSE_SCHEMA", "aeo")
TABLE = f"{SCHEMA}.coverage"     # schema owned by the backend repo; see module docstring

UPSERT = f"""
INSERT INTO {TABLE}
    (slug, run_date, subject_type, vertical, entity, entity_role, entity_domain,
     engine, query, n_answers, mentions, coverage, avg_visibility, raw)
VALUES %s
ON CONFLICT (slug, run_date, entity, engine, query) DO UPDATE SET
    subject_type=EXCLUDED.subject_type, vertical=EXCLUDED.vertical,
    entity_role=EXCLUDED.entity_role, entity_domain=EXCLUDED.entity_domain,
    n_answers=EXCLUDED.n_answers, mentions=EXCLUDED.mentions, coverage=EXCLUDED.coverage,
    avg_visibility=EXCLUDED.avg_visibility, raw=EXCLUDED.raw, captured_at=now();
"""


def connect(dsn: str | None = None):
    import psycopg2
    dsn = dsn or os.environ.get("AEO_WAREHOUSE_DSN")
    if not dsn:
        raise SystemExit(
            "AEO_WAREHOUSE_DSN not set — add it to the AEO repo .env "
            "(the warehouse the postgres MCP reads).")
    return psycopg2.connect(dsn)


def run_date_from_inject(inject_path: str | Path) -> date:
    """True scrape date from an aeo-inject.json first answer; today if unavailable."""
    try:
        runs = json.load(open(inject_path)).get("runs", [])
        return datetime.fromisoformat(runs[0]["createdAt"].replace("Z", "+00:00")).date()
    except Exception:
        return date.today()


def _is_subject(name: str, subject_name: str, subject_aliases: list[str]) -> bool:
    n, subj = name.strip().lower(), subject_name.strip().lower()
    al = {a.strip().lower() for a in subject_aliases}
    return n == subj or n in al or subj.startswith(n) or n.startswith(subj)


def build_rows(*, slug: str, subject_type: str, subject_name: str, subject_domain: str,
               subject_aliases: list[str], vertical: str, findings: dict,
               run_date: date) -> list[tuple]:
    from psycopg2.extras import Json
    N = int(findings.get("n_answers") or 0)
    vertical = (vertical or "").strip()
    rows: list[tuple] = []

    subj_hits = int(findings.get("subject_hits") or 0)
    rows.append((slug, run_date, subject_type, vertical, subject_name, "subject",
                 subject_domain, "", "", N, subj_hits,
                 round(subj_hits / N, 4) if N else 0,
                 findings.get("subject_avg_visibility"), Json(findings)))

    for name, cnt in (findings.get("leaderboard_full") or {}).items():
        if _is_subject(name, subject_name, subject_aliases):
            continue
        cnt = int(cnt)
        rows.append((slug, run_date, subject_type, vertical, name, "competitor", "",
                     "", "", N, cnt, round(cnt / N, 4) if N else 0, None, None))
    return rows


def write_coverage(*, slug: str, subject_type: str, subject_name: str,
                   subject_domain: str = "", subject_aliases: list[str] | None = None,
                   vertical: str, findings: dict, run_date: date,
                   dsn: str | None = None, dry_run: bool = False) -> dict:
    rows = build_rows(slug=slug, subject_type=subject_type, subject_name=subject_name,
                      subject_domain=subject_domain, subject_aliases=subject_aliases or [],
                      vertical=vertical, findings=findings, run_date=run_date)
    if dry_run:
        print(f"[aeo→pg] DRY-RUN {slug} @ {run_date} ({subject_type}) — {len(rows)} rows:")
        for r in rows:
            print(f"    {r[5]:11} {r[4]:<32} {r[10]:>3}/{r[9]:<3}  cov={r[11]}"
                  + (f"  vis={r[12]}" if r[12] is not None else ""))
        return {"rows": len(rows), "dry_run": True}

    from psycopg2.extras import execute_values
    conn = connect(dsn)
    try:
        with conn, conn.cursor() as cur:
            execute_values(cur, UPSERT, rows)
        print(f"[aeo→pg] {slug} @ {run_date}: upserted {len(rows)} rows into {TABLE}")
    finally:
        conn.close()
    return {"rows": len(rows), "run_date": str(run_date)}


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--findings", help="path to aeo_findings.json")
    ap.add_argument("--slug"); ap.add_argument("--subject-type", default="client")
    ap.add_argument("--name"); ap.add_argument("--domain", default="")
    ap.add_argument("--aliases", nargs="*", default=[])
    ap.add_argument("--vertical", default="")
    ap.add_argument("--run-date", help="YYYY-MM-DD (else from sibling aeo-inject.json, else today)")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    if not (a.findings and a.slug and a.name):
        ap.error("--findings, --slug and --name are required unless --init")
    findings = json.load(open(a.findings))
    if a.run_date:
        rd = date.fromisoformat(a.run_date)
    else:
        rd = run_date_from_inject(Path(a.findings).with_name("aeo-inject.json"))
    write_coverage(slug=a.slug, subject_type=a.subject_type, subject_name=a.name,
                   subject_domain=a.domain, subject_aliases=a.aliases, vertical=a.vertical,
                   findings=findings, run_date=rd, dry_run=a.dry_run)


if __name__ == "__main__":
    main()
