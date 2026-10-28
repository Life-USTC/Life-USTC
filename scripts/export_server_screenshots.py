#!/usr/bin/env python3
"""Export the named server UI journey attachments without changing PNG bytes."""

import argparse
import hashlib
import html
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from urllib.parse import quote


GENERATED_SUFFIX = re.compile(
    r"_[0-9]+_[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\.png$"
)


def collect_screenshots(attachments, output, coverage):
    """Keep every named PNG and its test/device provenance, including duplicates."""
    manifest_path = attachments / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    if not isinstance(manifest, list):
        raise ValueError("The attachment manifest must be a list of test records")
    shutil.copyfile(manifest_path, output / "attachment-manifest.json")
    images = output / "images"
    images.mkdir(exist_ok=True)
    group_names = {
        name: group["id"] for group in coverage for name in group["required"]
    }
    screenshots, errors = [], []
    attachment_count = 0
    for test in manifest:
        for attachment in test["attachments"]:
            attachment_count += 1
            suggested = attachment["suggestedHumanReadableName"]
            filename = attachment["exportedFileName"]
            if not suggested.startswith("after-") or not filename.lower().endswith(".png"):
                continue
            name = GENERATED_SUFFIX.sub("", suggested)
            try:
                shutil.copyfile(attachments / filename, images / filename)
            except OSError as error:
                errors.append(f"Could not copy {name}: {error}")
                continue
            data = (images / filename).read_bytes()
            screenshots.append({
                "name": name,
                "group": group_names.get(name, "other"),
                "file": "images/" + filename,
                "sha256": hashlib.sha256(data).hexdigest(),
                "bytes": len(data),
                "testIdentifier": test["testIdentifier"],
                "testIdentifierURL": test.get("testIdentifierURL", ""),
                "attachment": attachment,
            })
    screenshots.sort(key=lambda item: (
        item["name"], item["testIdentifier"], item["attachment"]["exportedFileName"]
    ))
    return screenshots, attachment_count, errors


def write_gallery(output, coverage, screenshots, attachment_count, errors,
                  ui_outcome, run_url, revision):
    required = [name for group in coverage for name in group["required"]]
    observed = {item["name"] for item in screenshots}
    missing = [name for name in required if name not in observed]
    complete = bool(screenshots) and not missing and not errors and ui_outcome == "success"
    report = {
        "status": "complete" if complete else "incomplete",
        "ui_test_outcome": ui_outcome,
        "run_url": run_url,
        "revision": revision,
        "attachment_count": attachment_count,
        "screenshot_count": len(screenshots),
        "required_count": len(required),
        "matched_required_count": len(required) - len(missing),
        "missing_required": missing,
        "errors": errors,
        "screenshots": screenshots,
    }
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    escape = html.escape
    status = "Complete" if complete else "Incomplete"
    count = f'{report["matched_required_count"]}/{len(required)} required states'
    parts = ["""<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Server feature screenshots</title>
<style>
body{font:16px system-ui,sans-serif;line-height:1.5;margin:0 auto;padding:24px;max-width:1600px;background:#f5f6f8;color:#17202a}
a{color:#1556a0}nav{display:flex;flex-wrap:wrap;gap:16px}.status{padding:16px;border:2px solid;border-radius:8px}.complete{border-color:#23763b;background:#edf8ef}.incomplete{border-color:#b42318;background:#fff0ee}
.gallery{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:20px}figure{margin:0;padding:16px;background:white;border:1px solid #ccd1d8;border-radius:8px;overflow-wrap:anywhere}figure img{display:block;max-width:100%;max-height:720px;width:auto;height:auto;margin:auto;image-orientation:from-image}figcaption{margin-top:12px}details{font-size:13px}dt{font-weight:600}dd{margin:0 0 8px}code{overflow-wrap:anywhere}section{margin-top:32px}
</style><h1>Server feature screenshots</h1>
<p>Named captures from the existing iPhone fixture UI journeys. Open an image to view its original PNG.</p>"""
    ]
    parts.append(f'<div class="status {report["status"]}"><strong>{status}: {count}</strong>'
                 f'<br>UI test step: {escape(ui_outcome)}. Exported {len(screenshots)} named PNGs'
                 f' from {attachment_count} attachments.</div>')
    if run_url:
        parts.append(f'<p><a href="{escape(run_url, quote=True)}">Workflow run</a></p>')
    if revision:
        parts.append(f'<p>Source revision: <code>{escape(revision)}</code></p>')
    if errors:
        parts.append('<h2>Export errors</h2><ul>' + ''.join(
            f'<li>{escape(error)}</li>' for error in errors) + '</ul>')
    if missing:
        parts.append('<h2>Missing required captures</h2><ul>' + ''.join(
            f'<li><code>{escape(name)}</code></li>' for name in missing) + '</ul>')
    groups = coverage + [{"id": "other", "title": "Additional captures", "required": []}]
    parts.append('<nav>' + ''.join(
        f'<a href="#{escape(group["id"], quote=True)}">{escape(group["title"])}</a>'
        for group in groups if group["required"] or any(
            item["group"] == group["id"] for item in screenshots)) + '</nav>')
    for group in groups:
        items = [item for item in screenshots if item["group"] == group["id"]]
        if not items and not group["required"]:
            continue
        parts.append(f'<section id="{escape(group["id"], quote=True)}">'
                     f'<h2>{escape(group["title"])} ({len(items)})</h2><div class="gallery">')
        for item in items:
            attachment = item["attachment"]
            source = "images/" + quote(attachment["exportedFileName"])
            parts.append(f'<figure><a href="{source}"><img src="{source}" loading="lazy" '
                         f'alt="{escape(item["name"], quote=True)}"></a>'
                         f'<figcaption><strong>{escape(item["name"])}</strong><br>'
                         f'{escape(attachment.get("deviceName", "Unknown device"))}'
                         '<details><summary>Capture provenance</summary><dl>')
            for label, value in [
                ("Test", item["testIdentifier"]),
                ("Device ID", attachment.get("deviceId", "")),
                ("Configuration", attachment.get("configurationName", "")),
                ("Timestamp", attachment.get("timestamp", "")),
                ("Attachment name", attachment["suggestedHumanReadableName"]),
                ("Original filename", attachment["exportedFileName"]),
                ("Associated with a failure", attachment.get("isAssociatedWithFailure", False)),
                ("SHA-256", item["sha256"]),
            ]:
                parts.append(f'<dt>{label}</dt><dd>{escape(str(value))}</dd>')
            parts.append('</dl></details></figcaption></figure>')
        parts.append('</div></section>')
    parts.append('<p><a href="report.json">Coverage and provenance JSON</a></p></html>')
    (output / "index.html").write_text("\n".join(parts) + "\n")
    summary = ["## Server feature screenshots", "", f"**{status}: {count}.**",
               f"UI test step: `{ui_outcome}`. Exported {len(screenshots)} named PNGs.", "",
               "Download the artifact, extract it, and open `index.html`. PNG bytes and metadata are unchanged."]
    if missing:
        summary += ["", "Missing required captures:", ""] + [f"- `{name}`" for name in missing]
    if errors:
        summary += ["", "Export errors:", ""] + [f"- {error}" for error in errors]
    (output / "summary.md").write_text("\n".join(summary) + "\n")
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--xcresult", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--coverage", type=Path,
                        default=Path(__file__).with_name("server_screenshot_coverage.json"))
    parser.add_argument("--ui-outcome", default="unknown",
                        choices=["success", "failure", "cancelled", "skipped", "unknown"])
    parser.add_argument("--run-url", default="")
    parser.add_argument("--revision", default="")
    args = parser.parse_args(argv)
    coverage = json.loads(args.coverage.read_text())
    args.output.mkdir(parents=True, exist_ok=True)
    screenshots, attachment_count, errors = [], 0, []
    with tempfile.TemporaryDirectory(prefix="server-screenshots-") as temporary:
        attachments = Path(temporary)
        try:
            if not args.xcresult.exists():
                raise FileNotFoundError(f"UI result bundle is missing: {args.xcresult}")
            command = ["xcrun", "xcresulttool", "export", "attachments", "--path",
                       str(args.xcresult), "--output-path", str(attachments)]
            process = subprocess.run(command, capture_output=True, text=True)
            (args.output / "export.log").write_text(process.stdout + process.stderr)
            if process.returncode:
                errors.append(f"xcresulttool attachment export exited {process.returncode}; see export.log")
            screenshots, attachment_count, copy_errors = collect_screenshots(
                attachments, args.output, coverage)
            errors.extend(copy_errors)
        except (OSError, ValueError, KeyError) as error:
            errors.append(str(error))
    report = write_gallery(args.output, coverage, screenshots, attachment_count, errors,
                           args.ui_outcome, args.run_url, args.revision)
    print(f'{report["status"]}: {report["matched_required_count"]}/{report["required_count"]}'
          f' required captures; {report["screenshot_count"]} PNGs')
    return 0 if report["status"] == "complete" else 1


if __name__ == "__main__":
    raise SystemExit(main())
