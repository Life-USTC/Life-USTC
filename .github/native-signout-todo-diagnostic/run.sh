#!/usr/bin/env bash
# NEVER MERGE: original full cases, A/B once each; no release or runtime retry.
set -euo pipefail
source_dir="$GITHUB_WORKSPACE/source"
carrier_dir="$GITHUB_WORKSPACE/.github/native-signout-todo-diagnostic"
results="$GITHUB_WORKSPACE/InputAPIDiagnosticResults"
mkdir -p "$results/carrier"
test "$(git -C "$source_dir" rev-parse HEAD)" = 7897d183f061eba8ac0084f8e4bac74a18460c04
test "$(git rev-parse HEAD)" = "$GITHUB_SHA"
printf '%s\n' "$GITHUB_SHA" > "$results/carrier-sha.txt"
printf '%s\n' 7897d183f061eba8ac0084f8e4bac74a18460c04 > "$results/source-sha.txt"
# Inherited todo-period.patch is inactive: this source already has the canonical
# Todo precondition. Only these four scripts and two workflows run this carrier.
for file in prepare.py run.sh simulator.py export-results.py; do cp "$carrier_dir/$file" "$results/carrier/"; done
cp .github/workflows/ci.yaml .github/workflows/screenshot.yaml "$results/carrier/"
shasum -a 256 "$results/carrier"/* > "$results/carrier-sha256.txt"
xcodebuild -version > "$results/xcode-version.txt"
xcrun xcresulttool version > "$results/xcresulttool-version.txt"
git -C "$source_dir" ls-tree -r HEAD > "$results/original-source-blobs.txt"
python3 - "$results" <<'PY_RUNTIME'
import json,os,subprocess
from pathlib import Path
out=Path(__import__('sys').argv[1]);owner=json.loads((out/'owned-simulator.json').read_text())
groups=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json']))['devices']
matched=[(key,item)for key,items in groups.items()for item in items if item['udid']==owner['udid']]
assert len(matched)==1 and matched[0][1]['name']==owner['name']
runtimes=json.loads(subprocess.check_output(['xcrun','simctl','list','runtimes','--json']))['runtimes']
runtime=[item for item in runtimes if item['identifier']==matched[0][0]];assert len(runtime)==1
(out/'runtime.json').write_text(json.dumps({'ownedDevice':owner,'runtime':runtime[0],'locale':'en_US','sourceSHA':'7897d183f061eba8ac0084f8e4bac74a18460c04','scope':'iPhone original portrait; iPad QA setUp raw orientation3 and original-case early frame1376x1032 gate in both arms'},indent=2)+'\n')
PY_RUNTIME
case "$DIAGNOSTIC_DEVICE" in
  iPhone) selector='-only-testing:Life-USTC-UITests/AccountJourneyTests/testAccountManagementOpensSupportedWebsitePagesAndRefreshesProfileOnReturn' ;;
  iPad) selector='-only-testing:Life-USTC-UITests/YoungCampusJourneyTests/testActivityFiltersApplyCancelClearAndPreserveUnknownDateContext' ;;
  *) exit 2 ;;
esac
overall_status=0
cd "$source_dir"
for variant in A B; do
  output="$results/$variant"
  mkdir -p "$output"
  args=(--source "$source_dir" --output "$output" --device "$DIAGNOSTIC_DEVICE" --variant "$variant")
  python3 "$carrier_dir/prepare.py" prepare "${args[@]}"
  xcodegen --spec project.yml
  python3 "$carrier_dir/prepare.py" verify "${args[@]}"
  if xcodebuild build-for-testing -project Life-USTC.xcodeproj -scheme Life-USTC-UITests \
    -destination "platform=iOS Simulator,id=$TEST_DEVICE_ID" -parallel-testing-enabled NO "$selector" \
    -clonedSourcePackagesDirPath SourcePackages -derivedDataPath "$RUNNER_TEMP/ios140-input-ab-derived" \
    -resultBundlePath "$output/build.xcresult" -quiet > "$output/build.log" 2>&1; then
    build_status=0
  else
    build_status=$?
    overall_status=1
  fi
  if python3 - "$source_dir" "$output" "$build_status" <<'PY_RESOLUTION'
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
PY_RESOLUTION
  then resolution_status=0; else resolution_status=$?; overall_status=1; fi
  native_status=not_started
  counts_status=not_started
  if [[ "$build_status" == 0 ]]; then
    # Only the owned simulator's app is removed. Verify actual absence before
    # Xcode reinstalls the freshly built app for this independent test runner.
    xcrun simctl uninstall "$TEST_DEVICE_ID" dev.tiankaima.Life-USTC >/dev/null 2>&1 || true
    python3 - "$TEST_DEVICE_ID" <<'PY_APP'
import plistlib,subprocess,sys
raw=subprocess.check_output(['xcrun','simctl','listapps',sys.argv[1]])
xml=subprocess.check_output(['plutil','-convert','xml1','-o','-','-'],input=raw)
apps=plistlib.loads(xml)
assert 'dev.tiankaima.Life-USTC' not in apps,'QA app still installed before original case'
PY_APP
    if xcodebuild test-without-building -project Life-USTC.xcodeproj -scheme Life-USTC-UITests \
      -destination "platform=iOS Simulator,id=$TEST_DEVICE_ID" -parallel-testing-enabled NO "$selector" \
      -clonedSourcePackagesDirPath SourcePackages -derivedDataPath "$RUNNER_TEMP/ios140-input-ab-derived" \
      -resultBundlePath "$output/ui.xcresult" -quiet > "$output/xcodebuild.log" 2>&1; then
      native_status=0
    else
      native_status=$?
      overall_status=1
    fi
    if python3 "$carrier_dir/export-results.py" "$DIAGNOSTIC_DEVICE" "$output" > "$output/export.log" 2>&1; then
      counts_status=0
    else
      counts_status=$?
      overall_status=1
    fi
  fi
  # Persist observed results before a source guard can fail closed.
  python3 - "$output" "$build_status" "$native_status" "$counts_status" "$resolution_status" <<'PY_OUTCOME'
import json,sys
from pathlib import Path
p=Path(sys.argv[1]);values=[int(x)if x!='not_started'else x for x in sys.argv[2:]]
(p/'outcomes.json').write_text(json.dumps(dict(zip(['buildExitCode','xcodebuildExitCode','countsExportExitCode','resolutionExitCode'],values)),indent=2)+'\n')
PY_OUTCOME
  python3 "$carrier_dir/prepare.py" verify "${args[@]}"
  python3 "$carrier_dir/prepare.py" cleanup "${args[@]}"
done
if ! python3 - "$results" <<'PY_PAIR'
import json,sys
from pathlib import Path
p=Path(sys.argv[1]);lists=[]
for variant in ['A','B']:
 rows=json.loads((p/variant/'dependency-resolution/actual-resolution-summary.json').read_text())
 pins=[row['pins']for row in rows if row.get('pins')];assert pins and all(x==pins[0]for x in pins)
 lists.append(pins[0])
assert lists[0]==lists[1],'A/B actual dependency pins differ; no matched input-API comparison'
PY_PAIR
then overall_status=1; fi
exit "$overall_status"
