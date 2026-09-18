#!/usr/bin/env python3
"""AEO tally over a tracker run's aeo-inject.json `runs` — decoupled from any repo.

Mirrors vertical_insights' analyze_aeo but driven by plain params (subject name +
regex, competitor vendor regexes, branded prompt set) so the client weekly path
has no reverse dependency on vertical_insights. Produces the same findings shape
that aeo_warehouse.build_rows() consumes.
"""
from __future__ import annotations

import json
import re
from collections import Counter
from urllib.parse import urlparse


def _sources(r: dict) -> list:
    """aeo-inject stores sources as a list, OR a stringified list ("['http://…']")."""
    s = r.get("sources", [])
    if isinstance(s, str):
        try:
            return json.loads(s.replace("'", '"'))
        except Exception:
            return []
    return s or []


def _leaderboard(subset: list, vendors: dict) -> Counter:
    c: Counter = Counter()
    for r in subset:
        ans = r.get("answer", "")
        for name, pat in vendors.items():
            if pat and re.search(pat, ans, re.I):
                c[name] += 1
    return c


def analyze_runs(runs: list, *, subject_name: str, subject_pattern: str = "",
                 vendors: dict | None = None,
                 branded_prompts=None) -> dict:
    vendors = vendors or {}
    branded = set(branded_prompts or [])
    N = len(runs)
    subj_pat = subject_pattern or re.escape(subject_name)

    subj_hits = [r for r in runs if re.search(subj_pat, r.get("answer", ""), re.I)]
    vis = [float(r.get("visibilityScore") or 0) for r in runs]
    unbranded = [r for r in runs if r.get("prompt") not in branded]

    dom: Counter = Counter()
    total_cites = 0
    for r in runs:
        seen = set()
        for s in _sources(r):
            u = s if isinstance(s, str) else (s.get("url") or s.get("link") or "")
            nl = urlparse(u).netloc.replace("www.", "") if u else ""
            if nl:
                total_cites += 1
                seen.add(nl)
        for nl in seen:
            dom[nl] += 1

    return {
        "channel": "aeo", "n_answers": N, "subject": subject_name,
        "subject_hits": len(subj_hits),
        "subject_avg_visibility": round(sum(vis) / len(vis), 1) if vis else 0,
        "subject_unbranded_hits": sum(1 for r in unbranded
                                      if re.search(subj_pat, r.get("answer", ""), re.I)),
        "n_unbranded": len(unbranded),
        "leaderboard_full": dict(_leaderboard(runs, vendors).most_common()),
        "leaderboard_unbranded": dict(_leaderboard(unbranded, vendors).most_common()),
        "total_citations": total_cites,
        "top_sources": dict(dom.most_common(18)),
    }
