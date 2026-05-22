from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
SCAN_DIRS = [
    ROOT / "flutter_app" / "lib",
    ROOT / "supabase" / "functions",
]

BLOCKED_TERMS = [
    "masked_phone",
    "last_four",
    "plain_phone",
    "customer_phone",
    "mobile_number",
    "tel:",
    "wa.me",
    "api.whatsapp.com",
    "console.log(phone",
    "console.log(payload",
    "raw_provider_payload",
    "broker_phone",
]

BLOCKED_PATTERNS = [
    (re.compile(r"console\.(log|debug|info|warn|error)\s*\("), "runtime logging is forbidden in frontend and Edge Functions"),
    (re.compile(r"https://wa\.me|https://api\.whatsapp\.com|tel:", re.IGNORECASE), "direct calling or WhatsApp links are forbidden"),
    (re.compile(r"last\s*4|last\s*four|masked\s*number", re.IGNORECASE), "partial or masked contact display is forbidden"),
]

EDGE_FUNCTION_RAW_ERROR_PATTERNS = [
    (re.compile(r"reason:\s*(err|error)\.message", re.IGNORECASE), "raw internal error messages must not be returned to clients"),
    (re.compile(r"const\s+msg\s*=\s*error\s+instanceof\s+Error\s*\?\s*error\.message\s*:", re.IGNORECASE), "raw internal error aliases must not be returned to clients"),
    (re.compile(r"reason:\s*msg\b", re.IGNORECASE), "raw internal error aliases must not be returned to clients"),
    (re.compile(r"unknown_error", re.IGNORECASE), "generic internal failures should use stable public reason codes"),
]

CONTACT_WORD_ALLOWED = {
    "flutter_app/lib/screens/broker_upload.dart",
    "supabase/functions/broker-upload-lead/index.ts",
    "supabase/functions/manage-external-broker/index.ts",
    "supabase/functions/flag-abuse-event/index.ts",
    "flutter_app/lib/screens/add_broker_screen.dart",
    "flutter_app/lib/screens/broker_crm_list.dart",
    "flutter_app/lib/screens/broker_detail_screen.dart",
    "flutter_app/lib/screens/broker_followup_queue.dart",
    "flutter_app/lib/screens/activation_pipeline_board.dart",
    "flutter_app/lib/screens/add_lead_from_broker.dart",
    "flutter_app/lib/screens/sourcing_manager_dashboard.dart",
    "flutter_app/lib/screens/broker_sourced_site_visits.dart",
    "flutter_app/lib/screens/caller_dashboard_screen.dart",
    "flutter_app/lib/screens/caller_lead_queue_screen.dart",
    "supabase/functions/lead-from-broker/index.ts",
    "supabase/functions/manage-caller-workflow/index.ts",
    "supabase/functions/ai-lead-response/index.ts",
}


def iter_source_files():
    for scan_dir in SCAN_DIRS:
        if not scan_dir.exists():
            continue
        for path in scan_dir.rglob("*"):
            if path.suffix in {".dart", ".ts"} and path.is_file():
                yield path


def main() -> int:
    violations = []

    config_path = ROOT / "supabase" / "config.toml"
    if config_path.exists():
        config_text = config_path.read_text(encoding="utf-8")
        for match in re.finditer(r'^\s*secret\s*=\s*"([^"]*)"', config_text, re.IGNORECASE | re.MULTILINE):
            value = match.group(1).strip()
            if value and not value.startswith("env(") and not value.startswith("encrypted:"):
                violations.append("supabase/config.toml: OAuth provider secrets must use env(...) or encrypted: values")
                break

    for path in iter_source_files():
        rel = path.relative_to(ROOT).as_posix()
        text = path.read_text(encoding="utf-8")
        lowered = text.lower()

        for term in BLOCKED_TERMS:
            if term.lower() in lowered:
                violations.append(f"{rel}: blocked term '{term}'")

        for pattern, reason in BLOCKED_PATTERNS:
            if pattern.search(text):
                violations.append(f"{rel}: {reason}")

        if rel.startswith("supabase/functions/"):
            for pattern, reason in EDGE_FUNCTION_RAW_ERROR_PATTERNS:
                if pattern.search(text):
                    violations.append(f"{rel}: {reason}")

        if rel not in CONTACT_WORD_ALLOWED and re.search(r"\b(phone|mobile|whatsapp)\b", text, re.IGNORECASE):
            violations.append(f"{rel}: contact wording outside broker upload flow")

    if violations:
        print("Security constitution scan failed:", file=sys.stderr)
        for violation in violations:
            print(f"- {violation}", file=sys.stderr)
        return 1

    print("Security constitution scan passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
