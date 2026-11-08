#!/usr/bin/env bash
# NEVER MERGE: fixed-source paired evidence; no release action or runtime retry.
set -euo pipefail
carrier_dir="$RUNNER_TEMP/ios150-native-visual-carrier"
results="$GITHUB_WORKSPACE/NativeVisualResults"
# Old source pins are intentionally unchanged until actual140/151 integration
# identities exist and root separately approves a new pair. Do not dispatch yet.
before_source=15e44f1f98741c880a8d08dd35f92d30fed27fce
after_source=4f2421f201dca4a7a51f30568738fae49807a5a8
anchor_day=$(python3 - <<'PY_ANCHOR'
from datetime import datetime
from zoneinfo import ZoneInfo
print(datetime.now(ZoneInfo('Asia/Shanghai')).date().isoformat())
PY_ANCHOR
)
case "$VISUAL_LOCALE" in
  en) test_region=US ;;
  zh-Hans) test_region=CN ;;
  *) exit 2 ;;
esac
mkdir -p "$results/carrier"
test "$(git rev-parse HEAD)" = "$GITHUB_SHA"
printf '%s\n' "$GITHUB_SHA" > "$results/carrier-workflow-sha.txt"
cp "$carrier_dir"/* "$results/carrier/"
shasum -a 256 "$carrier_dir"/* > "$results/carrier-sha256.txt"
python3 "$carrier_dir/metadata.py" runtime --output "$results"
overall_status=0
for arm in before after; do
  if [[ "$arm" == before ]]; then source_sha="$before_source"; else source_sha="$after_source"; fi
  git fetch --depth=1 origin "$source_sha"
  git checkout --detach FETCH_HEAD
  test "$(git rev-parse HEAD)" = "$source_sha"
  output="$results/$arm"
  mkdir -p "$output"
  printf '%s\n' "$source_sha" > "$output/source-sha.txt"
  git ls-tree -r HEAD > "$output/original-source-blobs.txt"
  printf '{"unit":"not_started","ui":"not_started"}\n' > "$output/outcomes.json"
  prepare_args=(--source "$GITHUB_WORKSPACE" --carrier "$carrier_dir" --output "$output"
    --expected-source "$source_sha" --arm "$arm" --locale "$VISUAL_LOCALE" --anchor "$anchor_day")
  python3 "$carrier_dir/prepare.py" prepare "${prepare_args[@]}"
  xcodegen --spec project.yml
  python3 "$carrier_dir/prepare.py" verify "${prepare_args[@]}"
  xcrun simctl uninstall "$TEST_DEVICE_ID" dev.tiankaima.Life-USTC >/dev/null 2>&1 || true
  for phase in unit ui; do
    if [[ "$phase" == unit ]]; then
      scheme=Life-USTC-Tests
      selector='-only-testing:Life-USTC-Tests/CalendarSundayNativeRenderTests'
    else
      scheme=Life-USTC-UITests
      selector='-only-testing:Life-USTC-UITests/CalendarSundayVisualCaptureTests'
    fi
    python3 "$carrier_dir/prepare.py" verify "${prepare_args[@]}"
    if xcodebuild test -project Life-USTC.xcodeproj -scheme "$scheme" \
      -destination "platform=iOS Simulator,id=$TEST_DEVICE_ID" \
      -testLanguage "$VISUAL_LOCALE" -testRegion "$test_region" "$selector" \
      -clonedSourcePackagesDirPath SourcePackages -derivedDataPath "$RUNNER_TEMP/ios150-derived-$arm" \
      -resultBundlePath "$output/$phase.xcresult" -quiet > "$output/$phase.log" 2>&1; then
      native_status=0
    else
      native_status=$?
      overall_status=1
    fi
    if python3 "$carrier_dir/export-results.py" "$phase" "$output" > "$output/$phase-export.log" 2>&1; then
      counts_status=0
    else
      counts_status=$?
      overall_status=1
    fi
    if python3 "$carrier_dir/metadata.py" resolution --source "$GITHUB_WORKSPACE" \
      --output "$output/dependency-resolution/$phase" --native-exit "$native_status"; then
      metadata_status=0
    else
      metadata_status=$?
      overall_status=1
    fi
    python3 - "$output/outcomes.json" "$phase" "$native_status" "$counts_status" "$metadata_status" <<'PY_OUTCOME'
import json,sys
from pathlib import Path
p=Path(sys.argv[1]);data=json.loads(p.read_text())
data[sys.argv[2]]={'xcodebuildExitCode':int(sys.argv[3]),'countsExportExitCode':int(sys.argv[4]),'metadataExitCode':int(sys.argv[5])}
p.write_text(json.dumps(data,indent=2)+'\n')
PY_OUTCOME
    python3 "$carrier_dir/prepare.py" verify "${prepare_args[@]}"
  done
  python3 "$carrier_dir/prepare.py" cleanup "${prepare_args[@]}"
done
if ! python3 "$carrier_dir/metadata.py" compare --output "$results"; then overall_status=1; fi
exit "$overall_status"
