#!/usr/bin/env bash
# Temporary native evidence carrier; never used as the release acceptance gate.
set -euo pipefail

carrier_dir="$RUNNER_TEMP/ios150-native-visual-carrier"
before_source=59f7d14a32a8198c258b10bffe331d0abb668000
after_source=53fec05ff0e90d705f5d81cd8e833644434c42bd
anchor_day=$(python3 - <<'PY'
from datetime import datetime
from zoneinfo import ZoneInfo
print(datetime.now(ZoneInfo('Asia/Shanghai')).date().isoformat())
PY
)
case "$VISUAL_LOCALE" in
  en) test_region=US ;;
  zh-Hans) test_region=CN ;;
  *) exit 2 ;;
esac
overall_status=0

for arm in before after; do
  if [[ "$arm" == before ]]; then
    source_sha="$before_source"
    expected_weekday=2
  else
    source_sha="$after_source"
    expected_weekday=1
  fi
  git fetch --depth=1 origin "$source_sha"
  git checkout --detach FETCH_HEAD
  test "$(git rev-parse HEAD)" = "$source_sha"
  results_dir="$GITHUB_WORKSPACE/NativeVisualResults/$arm"
  mkdir -p "$results_dir"
  git rev-parse HEAD > "$results_dir/source-sha.txt"
  git ls-tree HEAD -- General/Extensions/DateExtension.swift General/Helpers/ProductCalendar.swift \
    Views/Curriculum/CurriculumDetailView.swift Views/Curriculum/CurriculumWeekViewVertical.swift \
    Widget/CurriculumWeekWidget.swift Server/ServerYoungModels.swift > "$results_dir/production-source-blobs.txt"
  printf '%s\n' "$GITHUB_SHA" > "$results_dir/carrier-workflow-sha.txt"
  xcodebuild -version > "$results_dir/xcode-version.txt"
  xcrun simctl list devices available > "$results_dir/simulators.txt"
  shasum -a 256 "$carrier_dir"/*.swift "$carrier_dir/run-pair.sh" > "$results_dir/carrier-sha256.txt"

  cp "$carrier_dir/CalendarSundayNativeRenderTests.swift" Tests/Life-USTC-Tests/
  cp "$carrier_dir/CalendarSundayVisualCaptureTests.swift" Tests/Life-USTC-UITests/
  python3 - "$arm" "$source_sha" "$VISUAL_LOCALE" "$expected_weekday" "$anchor_day" "$results_dir" <<'PY'
import json
from pathlib import Path
import sys
arm, source, locale, weekday, anchor, output = sys.argv[1:]
config = dict(arm=arm, sourceSHA=source, locale=locale, expectedFirstWeekday=int(weekday),
              anchorCivilDay=anchor, renderDefaultTimeZone='America/Los_Angeles')
raw = json.dumps(config, indent=2) + '\n'
for folder in ['Tests/Life-USTC-Tests', 'Tests/Life-USTC-UITests']:
    Path(folder, 'CalendarVisualConfig.json').write_text(raw)
Path(output, 'fixture-config.json').write_text(raw)
# Include the unchanged production Widget view in the QA app module so its
# exact body/query can be rendered natively with a fixed in-memory container.
# This is not a claim to run the WidgetKit extension process or timeline.
p = Path('project.yml')
text = p.read_text()
marker = '      - path: "Views/"\n'
assert text.count(marker) == 1
text = text.replace(marker, marker + '      - path: "Widget/CurriculumWeekWidget.swift"\n', 1)
# Keep any async production-view task in the QA host on loopback, even if a
# task outlives the renderer's scoped demo flag. The native UI suite launches
# its own app with its existing, live loopback fixture URL.
marker = '  "Life-USTC-Tests":\n    build:\n      targets:\n        Life-USTC-Tests: [test]\n        Life-USTC: [test]\n    test:\n'
assert text.count(marker) == 1
text = text.replace(marker, marker + '      environmentVariables:\n        UI_TEST_SERVER_URL: "http://127.0.0.1:9"\n        UI_TEST_SERVER_ACCESS_TOKEN: "native-visual-isolation-token"\n        UI_TEST_SKIP_ONBOARDING: "1"\n', 1)
p.write_text(text)
PY
  git diff -- project.yml > "$results_dir/qa-target-membership.diff"
  # Original production/fixture/test bytes stay untouched. Only the documented
  # temporary source membership above and two extra QA files/resources differ.
  git diff --exit-code -- . ':!project.yml'
  xcodegen --spec project.yml
  xcrun simctl uninstall "$TEST_DEVICE_ID" dev.tiankaima.Life-USTC >/dev/null 2>&1 || true

  unit_status=0
  if xcodebuild test \
    -project Life-USTC.xcodeproj -scheme Life-USTC-Tests \
    -destination "platform=iOS Simulator,id=$TEST_DEVICE_ID" \
    -testLanguage "$VISUAL_LOCALE" -testRegion "$test_region" \
    -only-testing:Life-USTC-Tests/CalendarSundayNativeRenderTests \
    -clonedSourcePackagesDirPath SourcePackages \
    -derivedDataPath "$RUNNER_TEMP/ios150-derived-$arm" \
    -resultBundlePath "$results_dir/unit.xcresult" -quiet \
    2>&1 | tee "$results_dir/unit.log"; then
    unit_status=0
  else
    unit_status=$?
    overall_status=1
  fi

  ui_status=0
  if xcodebuild test \
    -project Life-USTC.xcodeproj -scheme Life-USTC-UITests \
    -destination "platform=iOS Simulator,id=$TEST_DEVICE_ID" \
    -testLanguage "$VISUAL_LOCALE" -testRegion "$test_region" \
    -only-testing:Life-USTC-UITests/CalendarSundayVisualCaptureTests \
    -clonedSourcePackagesDirPath SourcePackages \
    -derivedDataPath "$RUNNER_TEMP/ios150-derived-$arm" \
    -resultBundlePath "$results_dir/ui.xcresult" -quiet \
    2>&1 | tee "$results_dir/ui.log"; then
    ui_status=0
  else
    ui_status=$?
    overall_status=1
  fi
  printf '{"unitExitCode":%s,"uiExitCode":%s}\n' "$unit_status" "$ui_status" > "$results_dir/outcomes.json"

  git restore --source=HEAD --worktree -- project.yml
  rm -f Tests/Life-USTC-Tests/CalendarSundayNativeRenderTests.swift \
    Tests/Life-USTC-UITests/CalendarSundayVisualCaptureTests.swift \
    Tests/Life-USTC-Tests/CalendarVisualConfig.json Tests/Life-USTC-UITests/CalendarVisualConfig.json
done
exit "$overall_status"
