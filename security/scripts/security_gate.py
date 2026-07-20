#!/usr/bin/env python3
"""Evaluate security scan outputs against configurable severity thresholds."""

from __future__ import annotations

import json
import os
try:
    import defusedxml.ElementTree as ET
except ImportError:
    import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path
from typing import Any


REPORTS_DIR = Path(os.environ.get("SECURITY_REPORTS_DIR", "reports"))
MAX_CRITICAL = int(os.environ.get("MAX_CRITICAL", "0"))
MAX_HIGH = int(os.environ.get("MAX_HIGH", "0"))
MAX_MEDIUM = int(os.environ.get("MAX_MEDIUM", "999999"))


def add(counter: Counter, severity: str, amount: int = 1) -> None:
    sev = severity.strip().capitalize()
    if sev in {"Critical", "High", "Medium", "Low"}:
        counter[sev] += amount


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def count_trivy(path: Path, counter: Counter) -> None:
    payload = load_json(path)
    for result in payload.get("Results", []):
        for vuln in result.get("Vulnerabilities") or []:
            add(counter, vuln.get("Severity", "Low"))


def count_gitleaks(path: Path, counter: Counter) -> None:
    payload = load_json(path)
    findings = payload if isinstance(payload, list) else payload.get("findings", [])
    # Treat any leaked secret as high severity by default.
    counter["High"] += len(findings)


def count_zap(path: Path, counter: Counter) -> None:
    payload = load_json(path)
    alerts = []
    if isinstance(payload, dict):
        if "site" in payload:
            for site in payload.get("site", []):
                alerts.extend(site.get("alerts", []))
        elif "alerts" in payload:
            alerts.extend(payload.get("alerts", []))

    risk_map = {
        "3": "High",
        "2": "Medium",
        "1": "Low",
        "0": "Low",
        "High": "High",
        "Medium": "Medium",
        "Low": "Low",
        "Informational": "Low",
    }

    for alert in alerts:
        add(counter, risk_map.get(str(alert.get("riskcode", alert.get("risk", "Low"))), "Low"))


def count_dependency_check(path: Path, counter: Counter) -> None:
    tree = ET.parse(path)
    root = tree.getroot()
    for vuln in root.findall(".//vulnerability"):
        severity = vuln.findtext("severity", default="Low")
        add(counter, severity)


def count_snyk(path: Path, counter: Counter) -> None:
    payload = load_json(path)
    # Snyk outputs include metadata fields that also contain "severity" labels.
    # Count only actionable issues to avoid inflating totals.
    if isinstance(payload, list):
        for item in payload:
            if not isinstance(item, dict):
                continue
            for vuln in item.get("vulnerabilities", []) or []:
                if isinstance(vuln, dict):
                    add(counter, str(vuln.get("severity", "Low")))
            for issue in item.get("infrastructureAsCodeIssues", []) or []:
                if isinstance(issue, dict):
                    add(counter, str(issue.get("severity", "Low")))
        return

    if isinstance(payload, dict):
        for vuln in payload.get("vulnerabilities", []) or []:
            if isinstance(vuln, dict):
                add(counter, str(vuln.get("severity", "Low")))
        for issue in payload.get("infrastructureAsCodeIssues", []) or []:
            if isinstance(issue, dict):
                add(counter, str(issue.get("severity", "Low")))


def main() -> int:
    counter: Counter = Counter()

    # Glob patterns allow per-service files such as trivy-image-auth-service.json
    # alongside single-file reports like trivy-config.json.
    glob_parsers = [
        ("trivy-image*.json", count_trivy),
        ("trivy-config.json", count_trivy),
        ("gitleaks.json", count_gitleaks),
        ("zap*.json", count_zap),
        ("dependency-check-report.xml", count_dependency_check),
        ("snyk-oss.json", count_snyk),
        ("snyk-code.json", count_snyk),
        ("snyk-container*.json", count_snyk),
        ("snyk-iac.json", count_snyk),
    ]

    parsed_any = False
    for pattern, parser in glob_parsers:
        for path in sorted(REPORTS_DIR.glob(pattern)):
            parsed_any = True
            try:
                parser(path, counter)
            except Exception as exc:  # pylint: disable=broad-except
                print(f"[WARN] Failed to parse {path.name}: {exc}")

    if not parsed_any:
        print("[SKIP] No security reports found for gate evaluation.")
        return 0

    critical = counter.get("Critical", 0)
    high = counter.get("High", 0)
    medium = counter.get("Medium", 0)

    print(
        f"[INFO] Security gate counts => "
        f"Critical={critical}, High={high}, Medium={medium}, Low={counter.get('Low', 0)}"
    )
    print(
        f"[INFO] Thresholds => "
        f"Critical<={MAX_CRITICAL}, High<={MAX_HIGH}, Medium<={MAX_MEDIUM}"
    )

    if critical > MAX_CRITICAL or high > MAX_HIGH or medium > MAX_MEDIUM:
        print("[FAIL] Security gate thresholds exceeded.")
        return 1

    print("[OK] Security gate passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
