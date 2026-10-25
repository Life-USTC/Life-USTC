import contextlib
import importlib.util
import io
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zlib


SCRIPT = Path(__file__).resolve().parents[1] / "export_server_screenshots.py"
SPEC = importlib.util.spec_from_file_location("export_server_screenshots", SCRIPT)
exporter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(exporter)
UUID = "12345678-1234-5678-9ABC-123456789ABC"


def png_with_exif():
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(
            ">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    # TIFF orientation 6 exercises preservation of metadata used to display screenshots.
    exif = b"II\x2a\x00\x08\x00\x00\x00\x01\x00\x12\x01\x03\x00\x01\x00\x00\x00\x06\x00\x00\x00\x00\x00\x00\x00"
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 2, 8, 2, 0, 0, 0))
            + chunk(b"eXIf", exif) + chunk(b"iTXt", b"Caption\x00\x00\x00\x00\x00original")
            + chunk(b"IDAT", zlib.compress(b"\x00\xff\x00\x00\x00\x00\xff\x00"))
            + chunk(b"IEND", b""))


def attachment(name, filename="capture.png", **extra):
    return {
        "configurationName": "Test Scheme Action", "deviceId": "device-1",
        "deviceName": "iPhone 17", "exportedFileName": filename,
        "isAssociatedWithFailure": False,
        "suggestedHumanReadableName": f"{name}_0_{UUID}.png", "timestamp": 1234.5,
        **extra,
    }


def test_record(*attachments, identifier="JourneyTests/testFeature()"):
    return {"attachments": list(attachments), "testIdentifier": identifier,
            "testIdentifierURL": "test://project/" + identifier}


class ScreenshotExporterTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.attachments = self.root / "attachments"
        self.attachments.mkdir()
        self.output = self.root / "gallery"
        self.output.mkdir()
        self.coverage = [{"id": "workspace", "title": "Learning workspace",
                          "required": ["after-workspace-Home-iPhone"]}]

    def manifest(self, records):
        (self.attachments / "manifest.json").write_text(json.dumps(records))

    def render(self, outcome="success"):
        captures, count, errors = exporter.collect_screenshots(
            self.attachments, self.output, self.coverage)
        return exporter.write_gallery(self.output, self.coverage, captures, count, errors,
                                      outcome, "https://github.com/org/repo/actions/runs/1", "abc123")

    def run_cli(self, process, outcome="success"):
        bundle = self.root / "ui.xcresult"
        bundle.mkdir(exist_ok=True)
        coverage = self.root / "coverage.json"
        coverage.write_text(json.dumps(self.coverage))
        with patch.object(exporter.subprocess, "run", side_effect=process), contextlib.redirect_stdout(io.StringIO()):
            return exporter.main(["--xcresult", str(bundle), "--output", str(self.output),
                                  "--coverage", str(coverage), "--ui-outcome", outcome])

    def test_real_manifest_shape_groups_captures_and_preserves_original_png_metadata(self):
        self.coverage.append({"id": "catalog", "title": "Catalog",
                              "required": ["after-catalog-Course-iPhone"]})
        records = [
            test_record(attachment("after-workspace-Home-iPhone", "home.png"),
                        attachment("before-workspace-Home-iPhone", "before.png"),
                        attachment("after-workspace-request-log", "requests.txt")),
            test_record(attachment("after-catalog-Course-iPhone", "course.png"),
                        identifier="CatalogTests/testCourse()"),
        ]
        self.manifest(records)
        png = png_with_exif()
        for name in ["home.png", "course.png"]:
            (self.attachments / name).write_bytes(png)
        report = self.render()
        self.assertEqual(report["status"], "complete")
        self.assertEqual(report["attachment_count"], 4)
        self.assertEqual(report["screenshot_count"], 2)
        self.assertEqual({item["group"] for item in report["screenshots"]}, {"workspace", "catalog"})
        self.assertEqual(report["screenshots"][0]["testIdentifier"], "CatalogTests/testCourse()")
        self.assertEqual((self.output / "images/home.png").read_bytes(), png)
        self.assertEqual((self.output / "attachment-manifest.json").read_bytes(),
                         (self.attachments / "manifest.json").read_bytes())
        self.assertIn("image-orientation:from-image", (self.output / "index.html").read_text())

    def test_generated_suffix_is_removed_without_truncating_capture_name(self):
        name = "after-public-schedule-Results_2026-zh-Hans-iPhone"
        self.manifest([test_record(attachment(name))])
        (self.attachments / "capture.png").write_bytes(png_with_exif())
        report = self.render()
        self.assertEqual(report["screenshots"][0]["name"], name)
        self.assertEqual(report["screenshots"][0]["group"], "other")
        self.assertEqual(report["missing_required"], self.coverage[0]["required"])

    def test_same_capture_label_retains_distinct_original_files_and_devices(self):
        name = self.coverage[0]["required"][0]
        self.manifest([test_record(attachment(name, "first.png"), attachment(
            name, "second.png", deviceId="device-2", deviceName="Other iPhone"))])
        for filename in ["first.png", "second.png"]:
            (self.attachments / filename).write_bytes(png_with_exif())
        report = self.render()
        self.assertEqual(report["status"], "complete")
        self.assertEqual(report["matched_required_count"], 1)
        self.assertEqual(report["screenshot_count"], 2)
        self.assertEqual({item["file"] for item in report["screenshots"]},
                         {"images/first.png", "images/second.png"})

    def test_missing_png_preserves_other_captures_and_marks_gallery_incomplete(self):
        self.manifest([test_record(attachment(self.coverage[0]["required"][0]),
                                   attachment("after-extra", "extra.png"))])
        (self.attachments / "extra.png").write_bytes(png_with_exif())
        report = self.render()
        self.assertEqual(report["status"], "incomplete")
        self.assertEqual(report["screenshot_count"], 1)
        self.assertEqual(report["missing_required"], self.coverage[0]["required"])
        self.assertIn("Could not copy", report["errors"][0])
        self.assertTrue((self.output / "index.html").exists())

    def test_html_escapes_capture_test_device_and_group_text(self):
        name = 'after-<script>alert("capture")</script>'
        self.coverage = [{"id": "example", "title": "Files & <uploads>", "required": [name]}]
        self.manifest([test_record(attachment(name, deviceName='<img src=x onerror="boom">'),
                                   identifier='Tests/test<"quoted">&()')])
        (self.attachments / "capture.png").write_bytes(png_with_exif())
        self.render()
        page = (self.output / "index.html").read_text()
        self.assertNotIn("<script>", page)
        self.assertNotIn('<img src=x onerror="boom">', page)
        self.assertIn("Files &amp; &lt;uploads&gt;", page)
        self.assertIn("Tests/test&lt;&quot;quoted&quot;&gt;&amp;()", page)
        self.assertIn("after-&lt;script&gt;", page)

    def test_empty_export_writes_incomplete_gallery_and_returns_failure(self):
        def process(command, **kwargs):
            self.assertEqual(command[:4], ["xcrun", "xcresulttool", "export", "attachments"])
            self.assertEqual(command[-2], "--output-path")
            (Path(command[-1]) / "manifest.json").write_text("[]")
            return subprocess.CompletedProcess(command, 0, "", "")
        self.assertEqual(self.run_cli(process), 1)
        report = json.loads((self.output / "report.json").read_text())
        self.assertEqual(report["status"], "incomplete")
        self.assertEqual(report["screenshot_count"], 0)
        self.assertIn("Missing required captures", (self.output / "index.html").read_text())

    def test_failed_tool_export_keeps_partial_gallery_and_original_error(self):
        def process(command, **kwargs):
            folder = Path(command[-1])
            records = [test_record(attachment(self.coverage[0]["required"][0]))]
            (folder / "manifest.json").write_text(json.dumps(records))
            (folder / "capture.png").write_bytes(png_with_exif())
            return subprocess.CompletedProcess(command, 7, "partial export\n", "export failed\n")
        self.assertEqual(self.run_cli(process), 1)
        report = json.loads((self.output / "report.json").read_text())
        self.assertEqual(report["matched_required_count"], 1)
        self.assertEqual(report["status"], "incomplete")
        self.assertIn("exited 7", report["errors"][0])
        self.assertEqual((self.output / "export.log").read_text(), "partial export\nexport failed\n")

    def test_complete_capture_set_does_not_override_failed_ui_test_outcome(self):
        self.manifest([test_record(attachment(self.coverage[0]["required"][0]))])
        (self.attachments / "capture.png").write_bytes(png_with_exif())
        for outcome in ["failure", "skipped", "unknown"]:
            with self.subTest(outcome=outcome):
                report = self.render(outcome)
                self.assertEqual(report["status"], "incomplete")
                self.assertEqual(report["matched_required_count"], 1)
                self.assertEqual(report["ui_test_outcome"], outcome)

    def test_missing_result_bundle_keeps_report_without_invoking_xcrun(self):
        coverage = self.root / "coverage.json"
        coverage.write_text(json.dumps(self.coverage))
        with patch.object(exporter.subprocess, "run") as process, contextlib.redirect_stdout(io.StringIO()):
            result = exporter.main(["--xcresult", str(self.root / "missing.xcresult"),
                                    "--output", str(self.output), "--coverage", str(coverage)])
        process.assert_not_called()
        self.assertEqual(result, 1)
        report = json.loads((self.output / "report.json").read_text())
        self.assertIn("UI result bundle is missing", report["errors"][0])
        self.assertTrue((self.output / "summary.md").exists())


if __name__ == "__main__":
    unittest.main()
