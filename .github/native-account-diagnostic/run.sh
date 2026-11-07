#!/usr/bin/env bash
# NEVER MERGE: no release actions and no assertion-budget or interaction retries.
set -euo pipefail
source_dir="$GITHUB_WORKSPACE/source"
carrier_dir="$GITHUB_WORKSPACE/.github/native-account-diagnostic"
results="$GITHUB_WORKSPACE/AccountDiagnosticResults"
mkdir -p "$results"
test "$(git -C "$source_dir" rev-parse HEAD)" = 59771f3c7dfc032cf53796c6df6108977e216286
git -C "$GITHUB_WORKSPACE" rev-parse HEAD > "$results/carrier-sha.txt"
test "$(cat "$results/carrier-sha.txt")" = "$GITHUB_SHA"
printf '%s\n' 59771f3c7dfc032cf53796c6df6108977e216286 > "$results/source-sha.txt"
shasum -a 256 "$carrier_dir"/* "$GITHUB_WORKSPACE/.github/workflows/ci.yaml" \
  "$GITHUB_WORKSPACE/.github/workflows/screenshot.yaml" > "$results/carrier-sha256.txt"
mkdir -p "$results/carrier"
cp "$carrier_dir"/* "$results/carrier/"
cp "$GITHUB_WORKSPACE/.github/workflows/ci.yaml" "$results/carrier/ci.yaml"
cp "$GITHUB_WORKSPACE/.github/workflows/screenshot.yaml" "$results/carrier/screenshot.yaml"
xcodebuild -version > "$results/xcode-version.txt"
xcrun xcresulttool version > "$results/xcresulttool-version.txt"
git -C "$source_dir" ls-tree -r HEAD -- App General Server Views Tests > "$results/original-source-blobs.txt"
printf '{"positive":"not_started","negative":"not_started"}\n' > "$results/outcomes.json"
overall_status=0

for phase in positive negative; do
  output="$results/$phase"
  mkdir -p "$output"
  python3 "$carrier_dir/prepare.py" --source "$source_dir" --output "$output" \
    --variant "$DIAGNOSTIC_VARIANT" --phase "$phase"
  cd "$source_dir"
  xcodegen --spec project.yml
  selectors=()
  if [[ "$phase" == positive ]]; then
    selectors+=("-only-testing:Life-USTC-UITests/AccountJourneyTests/testAccountManagementOpensSupportedWebsitePagesAndRefreshesProfileOnReturn")
  else
    selectors+=("-only-testing:Life-USTC-UITests/AccountJourneyTests/testAccountDiagnosticRejectsVisibleBrowser")
    selectors+=("-only-testing:Life-USTC-UITests/AccountJourneyTests/testAccountDiagnosticRejectsWrongPageAfterClose")
  fi
  phase_status=0
  if xcodebuild test \
    -project Life-USTC.xcodeproj -scheme Life-USTC-UITests \
    -destination "platform=iOS Simulator,id=$TEST_DEVICE_ID" \
    -parallel-testing-enabled NO \
    "${selectors[@]}" \
    -clonedSourcePackagesDirPath SourcePackages \
    -derivedDataPath "$RUNNER_TEMP/ios140-account-derived" \
    -resultBundlePath "$output/ui.xcresult" -quiet \
    > "$output/xcodebuild.log" 2>&1; then
    phase_status=0
  else
    phase_status=$?
    overall_status=1
  fi
  counts_status=0
  if python3 "$carrier_dir/export-results.py" "$phase" "$output" > "$output/export.log" 2>&1; then
    counts_status=0
  else
    counts_status=$?
    overall_status=1
  fi
  printf '{"xcodebuildExitCode":%s,"countsExportExitCode":%s}\n' "$phase_status" "$counts_status" > "$output/outcomes.json"
  python3 - "$results" "$phase" "$phase_status" "$counts_status" <<'PY'
import json, sys
from pathlib import Path
root, phase, native_status, counts_status = sys.argv[1:]
path = Path(root, 'outcomes.json')
record = json.loads(path.read_text())
record[phase] = {'xcodebuildExitCode': int(native_status), 'countsExportExitCode': int(counts_status)}
path.write_text(json.dumps(record, indent=2) + '\n')
PY
  # Keep the original tracked test/fixture bytes untouched between phases.
  python3 "$carrier_dir/prepare.py" --source "$source_dir" --output "$output" \
    --variant "$DIAGNOSTIC_VARIANT" --phase "$phase" --verify-only
done
exit "$overall_status"
