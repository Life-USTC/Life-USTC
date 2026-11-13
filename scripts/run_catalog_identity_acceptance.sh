#!/bin/bash
# Four supplemental method executions; keep the canonical UI phase/gallery separate.
set -euo pipefail
: "${TEST_DEVICE_ID:?Use the simulator created by this workflow}"
[[ "$TEST_DEVICE_ID" =~ ^[0-9A-Fa-f-]{36}$ ]]
mkdir -p TestResults
original=$(xcrun simctl ui "$TEST_DEVICE_ID" content_size)
case "$original" in
  extra-small|small|medium|large|extra-large|extra-extra-large|extra-extra-extra-large|accessibility-medium|accessibility-large|accessibility-extra-large|accessibility-extra-extra-large|accessibility-extra-extra-extra-large) ;;
  *) echo "Cannot preserve content size: $original" >&2; exit 1 ;;
esac
receipt=TestResults/catalog-identity-content-size.txt
printf 'revision=%s\ndevice=%s\noriginal=%s\n' "$(git rev-parse HEAD)" "$TEST_DEVICE_ID" "$original" > "$receipt"
restore_content_size() {
  status=$?
  trap - EXIT
  if ! xcrun simctl ui "$TEST_DEVICE_ID" content_size "$original"; then
    echo 'restore=failed' >> "$receipt"
    exit 1
  fi
  restored=$(xcrun simctl ui "$TEST_DEVICE_ID" content_size) || exit 1
  printf 'restored=%s\n' "$restored" >> "$receipt"
  [[ "$restored" == "$original" ]] || exit 1
  exit "$status"
}
trap restore_content_size EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
failed=0
for condition in normal axxxl; do
  size=large
  if [[ "$condition" == axxxl ]]; then size=accessibility-extra-extra-extra-large; fi
  xcrun simctl ui "$TEST_DEVICE_ID" content_size "$size"
  actual=$(xcrun simctl ui "$TEST_DEVICE_ID" content_size)
  printf '%s.content_size=%s\n' "$condition" "$actual" >> "$receipt"
  [[ "$actual" == "$size" ]]
  started=$(date +%s)
  bundle="TestResults/catalog-identity-$condition.xcresult"
  set +e
  xcodebuild test-without-building \
    -project Life-USTC.xcodeproj \
    -scheme Life-USTC-UITests \
    -destination "platform=iOS Simulator,id=$TEST_DEVICE_ID" \
    -parallel-testing-enabled NO \
    -only-testing:Life-USTC-UITests/CatalogIdentityAcceptanceTests/testEnglishIdentityAcrossNativeAdoptionPoints \
    -only-testing:Life-USTC-UITests/CatalogIdentityAcceptanceTests/testChineseIdentityAcrossNativeAdoptionPoints \
    -clonedSourcePackagesDirPath SourcePackages \
    -disableAutomaticPackageResolution \
    -onlyUsePackageVersionsFromResolvedFile \
    -resultBundlePath "$bundle" \
    -quiet
  result=$?
  set -e
  printf '%s.exit=%s\n%s.seconds=%s\n' "$condition" "$result" "$condition" "$(( $(date +%s) - started ))" >> "$receipt"
  if [[ "$result" != 0 ]]; then failed=1; fi
  if ! xcrun xcresulttool get test-results tests --path "$bundle" --compact > "TestResults/catalog-identity-$condition-tests.json"; then
    failed=1
    continue
  fi
  if ! python3 - "TestResults/catalog-identity-$condition-tests.json" "$TEST_DEVICE_ID" <<'PY'
import json
import sys
report = json.load(open(sys.argv[1]))
expected = {
    'CatalogIdentityAcceptanceTests/testEnglishIdentityAcrossNativeAdoptionPoints()',
    'CatalogIdentityAcceptanceTests/testChineseIdentityAcrossNativeAdoptionPoints()',
}
cases = []
def visit(nodes):
    for node in nodes:
        if node.get('nodeType') == 'Test Case':
            cases.append(node)
        visit(node.get('children', []))
visit(report['testNodes'])
assert len(cases) == 2, cases
assert {case['nodeIdentifier'] for case in cases} == expected, cases
assert all(case['result'] == 'Passed' for case in cases), cases
assert len(report['devices']) == 1, report['devices']
assert report['devices'][0]['deviceId'].lower() == sys.argv[2].lower(), report['devices']
print('Catalog identity: exact two expected cases passed; zero skipped; owned simulator verified.')
PY
  then failed=1; fi
done
cat "$receipt"
exit "$failed"
