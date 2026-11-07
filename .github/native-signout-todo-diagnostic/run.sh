#!/usr/bin/env bash
# NEVER MERGE: unit414 -> original Account keep -> uninstall -> original Account fresh.
# One attempt per legal lifecycle, no API changes, release, observation or retry.
set -euo pipefail
source_dir="$GITHUB_WORKSPACE/source"
carrier_dir="$GITHUB_WORKSPACE/.github/native-signout-todo-diagnostic"
results="$GITHUB_WORKSPACE/InputAPIDiagnosticResults"
mkdir -p "$results/carrier"
test "$DIAGNOSTIC_DEVICE" = iPhone
test "$(git -C "$source_dir" rev-parse HEAD)" = 7897d183f061eba8ac0084f8e4bac74a18460c04
test "$(git rev-parse HEAD)" = "$GITHUB_SHA"
printf '%s\n' "$GITHUB_SHA" > "$results/carrier-sha.txt"
# Inherited todo-period.patch is inactive; no QA Swift or project patch is used.
for file in prepare.py run.sh simulator.py export-results.py; do cp "$carrier_dir/$file" "$results/carrier/"; done
cp .github/workflows/ci.yaml .github/workflows/screenshot.yaml "$results/carrier/"
shasum -a 256 "$results/carrier"/* > "$results/carrier-sha256.txt"
xcodebuild -version > "$results/xcode-version.txt"
xcrun xcresulttool version > "$results/xcresulttool-version.txt"
python3 - "$results" <<'PY_RUNTIME'
import json,subprocess,sys
from pathlib import Path
out=Path(sys.argv[1]);owner=json.loads((out/'owned-simulator.json').read_text())
assert (out/'xcode-version.txt').read_text().splitlines()==['Xcode 26.6','Build version 17F113']
sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-version'],text=True).strip()
assert sdk=='26.5',f'Unexpected SDK: {sdk}'
groups=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json']))['devices']
matched=[(key,item)for key,items in groups.items()for item in items if item['udid']==owner['udid']]
assert len(matched)==1 and matched[0][1]['name']==owner['name']
assert matched[0][0]=='com.apple.CoreSimulator.SimRuntime.iOS-26-5'
runtimes=json.loads(subprocess.check_output(['xcrun','simctl','list','runtimes','--json']))['runtimes']
runtime=[item for item in runtimes if item['identifier']==matched[0][0]];assert len(runtime)==1
assert runtime[0]['version']=='26.5' and runtime[0]['buildversion']=='23F77'
(out/'runtime.json').write_text(json.dumps({'ownedDevice':owner,'runtime':runtime[0],'sdk':sdk,
 'sourceSHA':'7897d183f061eba8ac0084f8e4bac74a18460c04',
 'scope':'Canonical Swift/project/fixtures unchanged; units then same-app keep then verified uninstall/fresh. Historical canonical pins were not saved; compare actual pins to prior A/B only.'},indent=2)+'\n')
PY_RUNTIME
cd "$source_dir"
python3 "$carrier_dir/prepare.py" --source "$source_dir" --output "$results"
xcodegen --spec project.yml
python3 "$carrier_dir/prepare.py" --source "$source_dir" --output "$results" --after-generation
selector='-only-testing:Life-USTC-UITests/AccountJourneyTests/testAccountManagementOpensSupportedWebsitePagesAndRefreshesProfileOnReturn'
overall_status=0
for phase in unit keep fresh; do
  output="$results/$phase"
  mkdir -p "$output"
  if [[ "$phase" == fresh ]]; then
    # Only this owned device's installed app is removed, not keychain or an erase.
    xcrun simctl uninstall "$TEST_DEVICE_ID" dev.tiankaima.Life-USTC
    python3 - "$TEST_DEVICE_ID" "$output" <<'PY_APP'
import json,plistlib,subprocess,sys
from pathlib import Path
raw=subprocess.check_output(['xcrun','simctl','listapps',sys.argv[1]])
xml=subprocess.check_output(['plutil','-convert','xml1','-o','-','-'],input=raw)
assert 'dev.tiankaima.Life-USTC' not in plistlib.loads(xml),'App remains after uninstall'
(Path(sys.argv[2])/'uninstall.json').write_text(json.dumps({'udid':sys.argv[1],'bundleID':'dev.tiankaima.Life-USTC','verifiedAbsent':True})+'\n')
PY_APP
  fi
  if [[ "$phase" == keep ]]; then
    # Prove this arm inherits the installed unit host, without uninstall/reset.
    python3 - "$TEST_DEVICE_ID" "$output" <<'PY_KEEP'
import json,plistlib,subprocess,sys
from pathlib import Path
raw=subprocess.check_output(['xcrun','simctl','listapps',sys.argv[1]])
xml=subprocess.check_output(['plutil','-convert','xml1','-o','-','-'],input=raw)
assert 'dev.tiankaima.Life-USTC' in plistlib.loads(xml),'Unit host app absent before keep lifecycle'
(Path(sys.argv[2])/'installed-prefix.json').write_text(json.dumps({'udid':sys.argv[1],'bundleID':'dev.tiankaima.Life-USTC','installedBeforeKeep':True})+'\n')
PY_KEEP
  fi
  scheme=Life-USTC-UITests
  bundle=ui
  if [[ "$phase" == unit ]]; then scheme=Life-USTC-Tests; bundle=unit; fi
  # Same canonical xcodebuild test form and default derived data as the full gate.
  # Keep the argument array nonempty: macOS Bash3.2 treats an empty array as
  # unset under nounset. The unit command has no only-testing selector.
  command=(xcodebuild test -project Life-USTC.xcodeproj -scheme "$scheme"
    -destination "platform=iOS Simulator,id=$TEST_DEVICE_ID"
    -clonedSourcePackagesDirPath SourcePackages -resultBundlePath "$output/$bundle.xcresult" -quiet)
  if [[ "$phase" != unit ]]; then command+=("$selector"); fi
  if "${command[@]}" > "$output/xcodebuild.log" 2>&1; then native_status=0; else native_status=$?; overall_status=1; fi
  if python3 "$carrier_dir/export-results.py" "$phase" "$output" > "$output/export.log" 2>&1; then
    counts_status=0
  else counts_status=$?; overall_status=1; fi
  if python3 - "$source_dir" "$output" <<'PY_RESOLUTION'
import hashlib,json,os,shutil,sys
from pathlib import Path
source,results=map(Path,sys.argv[1:3]); records=[]
root=json.loads((results/'native-root.json').read_text())
actions=root.get('actions',{}).get('_values',[])
assert actions,'Native result has no actions'
for action in actions:
    destination=action['runDestination'];device=destination['targetDeviceRecord']
    assert device['identifier']['_value']==os.environ['TEST_DEVICE_ID'],'Native device drift'
    assert device['operatingSystemVersionWithBuildNumber']['_value']=='26.5 (23F77)'
    assert destination['targetSDKRecord']['identifier']['_value']=='iphonesimulator26.5'
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
pins=[sorted(row['pins'],key=lambda pin:pin['identity']) for row in records if row.get('pins')]
assert pins and all(pin==pins[0] for pin in pins),'Missing or inconsistent actual resolution'
assert len(pins[0])==12
digest=hashlib.sha256(json.dumps(pins[0],sort_keys=True,separators=(',',':')).encode()).hexdigest()
assert digest=='cd4230577c4291803ba4bd3e7631601c536a098af430ce77eb0fcc151a1b0308','Actual pins differ from prior A/B; historical canonical pins were not saved'
PY_RESOLUTION
  then resolution_status=0; else resolution_status=$?; overall_status=1; fi
  # Persist all three actual phase exitcodes before the source guard can fail.
  python3 - "$output" "$native_status" "$counts_status" "$resolution_status" <<'PY_OUTCOME'
import json,sys
from pathlib import Path
(Path(sys.argv[1])/'outcomes.json').write_text(json.dumps(dict(zip(
 ['xcodebuildExitCode','countsExportExitCode','resolutionExitCode'],map(int,sys.argv[2:]))),indent=2)+'\n')
PY_OUTCOME
  python3 "$carrier_dir/prepare.py" --source "$source_dir" --output "$output" --after-generation
  # A failed or mismatched prefix is not an interpretable lifecycle comparison.
  # A UI failure still permits its distinct fresh lifecycle arm, never a retry.
  if [[ "$resolution_status" != 0 || ( "$phase" == unit && ( "$native_status" != 0 || "$counts_status" != 0 ) ) ]]; then exit 1; fi
done
exit "$overall_status"
