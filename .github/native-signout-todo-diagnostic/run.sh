#!/usr/bin/env bash
# NEVER MERGE: one build, independent test processes, no retry/publish.
set -euo pipefail
source_dir="$GITHUB_WORKSPACE/source"
carrier_dir="$GITHUB_WORKSPACE/.github/native-signout-todo-diagnostic"
results="$GITHUB_WORKSPACE/SignOutTodoDiagnosticResults"
mkdir -p "$results"
test "$(git -C "$source_dir" rev-parse HEAD)" = 7f2a63c21b64a6b1958ad4883dd891a268c987b3
git -C "$GITHUB_WORKSPACE" rev-parse HEAD > "$results/carrier-sha.txt"
test "$(cat "$results/carrier-sha.txt")" = "$GITHUB_SHA"
printf '%s\n' 7f2a63c21b64a6b1958ad4883dd891a268c987b3 > "$results/source-sha.txt"
shasum -a 256 "$carrier_dir"/* "$GITHUB_WORKSPACE/.github/workflows/ci.yaml" \
  "$GITHUB_WORKSPACE/.github/workflows/screenshot.yaml" > "$results/carrier-sha256.txt"
mkdir -p "$results/carrier"
cp "$carrier_dir"/* "$results/carrier/"
cp "$GITHUB_WORKSPACE/.github/workflows/ci.yaml" "$results/carrier/ci.yaml"
cp "$GITHUB_WORKSPACE/.github/workflows/screenshot.yaml" "$results/carrier/screenshot.yaml"
xcodebuild -version > "$results/xcode-version.txt"
xcrun xcresulttool version > "$results/xcresulttool-version.txt"
git -C "$source_dir" ls-tree -r HEAD -- App General Server Views Tests > "$results/original-source-blobs.txt"
printf '{"build":"not_started","signout":"not_started","fresh-guest":"not_started","todo-target":"not_started"}\n' > "$results/outcomes.json"
python3 "$carrier_dir/prepare.py" --source "$source_dir" --output "$results/prepared"
cd "$source_dir"
xcodegen --spec project.yml
selectors=(
  '-only-testing:Life-USTC-UITests/ServerJourneyTests/testSignOutRemovesPreviouslyVisibleSubscriptions'
  '-only-testing:Life-USTC-UITests/ServerJourneyTests/testDiagnosticFreshGuestSubscriptionsEntry'
  '-only-testing:Life-USTC-UITests/WorkspaceJourneyTests/testTodoCreateDeleteRefreshesHomeAndCalendar'
)
if xcodebuild build-for-testing -project Life-USTC.xcodeproj -scheme Life-USTC-UITests \
  -destination "platform=iOS Simulator,id=$TEST_DEVICE_ID" -parallel-testing-enabled NO \
  "${selectors[@]}" -clonedSourcePackagesDirPath SourcePackages \
  -derivedDataPath "$RUNNER_TEMP/ios140-signout-todo-derived" \
  -resultBundlePath "$results/build.xcresult" -quiet > "$results/build.log" 2>&1; then
  build_status=0
else
  build_status=$?
fi
# Record the resolution actually used by this build. A project.yml cache key
# alone does not establish dependency equivalence with the failed original run.
python3 - "$source_dir" "$results" "$build_status" <<'PY'
import hashlib,json,shutil,sys
from pathlib import Path
source,results=map(Path,sys.argv[1:3]); records=[]
target=results/'dependency-resolution';target.mkdir(exist_ok=True)
paths=list(source.glob('*.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'))
paths += [source/'Package.resolved',source/'.swiftpm/configuration/Package.resolved',
          source/'SourcePackages/workspace-state.json']
for index,path in enumerate(paths):
    if not path.is_file():continue
    raw=path.read_bytes();row={'path':str(path.relative_to(source)),
                             'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw)}
    value=json.loads(raw)
    if path.name=='Package.resolved':
        pins=value.get('pins',value.get('object',{}).get('pins',[]))
        row['pins']=[{'identity':pin.get('identity',pin.get('package')),
                      'state':{k:v for k,v in pin.get('state',{}).items()
                               if k in ['revision','version','branch']}} for pin in pins]
        shutil.copy2(path,target/f'{index}-Package.resolved')
    else:
        dependencies=value.get('object',{}).get('dependencies',[])
        row['dependencies']=[{'identity':dep.get('packageRef',{}).get('identity'),
                               'checkoutState':{k:v for k,v in dep.get('state',{}).get('checkoutState',{}).items()
                                                if k in ['revision','version','branch']}}
                              for dep in dependencies]
    records.append(row)
(target/'actual-resolution-summary.json').write_text(json.dumps(records,indent=2)+'\n')
if int(sys.argv[3])==0:
    assert any(row.get('pins') for row in records),'Successful build lacks actual Package.resolved pins'
PY
python3 - "$results/outcomes.json" "$build_status" <<'PY'
import json,sys
from pathlib import Path
p=Path(sys.argv[1]);d=json.loads(p.read_text());d['build']={'exitCode':int(sys.argv[2])};p.write_text(json.dumps(d,indent=2)+'\n')
PY
if [[ "$build_status" != 0 ]]; then exit "$build_status"; fi
overall_status=0
for phase in signout fresh-guest todo-target; do
  output="$results/$phase"
  mkdir -p "$output"
  case "$phase" in
    signout) selector="${selectors[0]}" ;;
    fresh-guest) selector="${selectors[1]}" ;;
    todo-target) selector="${selectors[2]}" ;;
  esac
  # Each selector gets its own runner/app lifecycle and xcresult; failures do not
  # prevent other cases. The fixed already-built source/test bundle is shared.
  if xcodebuild test-without-building -project Life-USTC.xcodeproj -scheme Life-USTC-UITests \
    -destination "platform=iOS Simulator,id=$TEST_DEVICE_ID" -parallel-testing-enabled NO \
    "$selector" -clonedSourcePackagesDirPath SourcePackages -derivedDataPath "$RUNNER_TEMP/ios140-signout-todo-derived" \
    -resultBundlePath "$output/ui.xcresult" -quiet > "$output/xcodebuild.log" 2>&1; then
    native_status=0
  else
    native_status=$?
    overall_status=1
  fi
  if python3 "$carrier_dir/export-results.py" "$phase" "$output" > "$output/export.log" 2>&1; then
    counts_status=0
  else
    counts_status=$?
    overall_status=1
  fi
  python3 - "$results/outcomes.json" "$phase" "$native_status" "$counts_status" <<'PY'
import json,sys
from pathlib import Path
p=Path(sys.argv[1]);d=json.loads(p.read_text());d[sys.argv[2]]={'xcodebuildExitCode':int(sys.argv[3]),'countsExportExitCode':int(sys.argv[4])};p.write_text(json.dumps(d,indent=2)+'\n')
PY
  python3 "$carrier_dir/prepare.py" --source "$source_dir" --output "$results/prepared" --verify-only
done
exit "$overall_status"
