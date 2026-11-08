#!/usr/bin/env python3
"""Actual resolution/runtime provenance, never a dependency declaration edit."""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
from pathlib import Path


def resolution(source, target, require_pins):
    target.mkdir(parents=True, exist_ok=True)
    paths = list(source.glob('*.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'))
    paths += [source / 'Package.resolved', source / '.swiftpm/configuration/Package.resolved',
              source / 'SourcePackages/workspace-state.json']
    records = []
    for index, path in enumerate(paths):
        if not path.is_file():
            continue
        raw = path.read_bytes()
        row = {'path': str(path.relative_to(source)), 'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw)}
        data = json.loads(raw)
        if path.name == 'Package.resolved':
            pins = data.get('pins', data.get('object', {}).get('pins', []))
            row['pins'] = sorted([{'identity': pin.get('identity', pin.get('package')),
                                  'state': {k: v for k, v in pin.get('state', {}).items()
                                            if k in ['revision', 'version', 'branch']}} for pin in pins],
                                 key=lambda pin: pin['identity'])
            shutil.copy2(path, target / f'{index}-Package.resolved')
        else:
            row['dependencies'] = sorted([
                {'identity': dep.get('packageRef', {}).get('identity'),
                 'checkoutState': {k: v for k, v in dep.get('state', {}).get('checkoutState', {}).items()
                                   if k in ['revision', 'version', 'branch']}}
                for dep in data.get('object', {}).get('dependencies', [])],
                key=lambda dep: dep['identity'] or '')
        records.append(row)
    (target / 'actual-resolution-summary.json').write_text(json.dumps(records, indent=2) + '\n')
    lists = [row['pins'] for row in records if row.get('pins')]
    if require_pins:
        assert lists, 'Successful native build/test lacks actual Package.resolved pins'
        assert all(pins == lists[0] for pins in lists), 'Conflicting actual Package.resolved files'
        assert all(isinstance(pin['identity'], str) and pin['identity'].strip()
                   and isinstance(pin['state'].get('revision'), str) and pin['state']['revision'].strip()
                   for pin in lists[0]), 'Actual dependency identity/revision missing'
        assert len({pin['identity'] for pin in lists[0]}) == len(lists[0]), 'Duplicate dependency identity'
    return lists[0] if lists else None


def compare(results):
    rows = []
    for arm in ['before', 'after']:
        for phase in ['unit', 'ui']:
            path = results / arm / 'dependency-resolution' / phase / 'actual-resolution-summary.json'
            assert path.is_file(), f'Missing scheme resolution receipt: {path}'
            records = json.loads(path.read_text())
            lists = [row['pins'] for row in records if row.get('pins')]
            assert lists and all(pins == lists[0] for pins in lists)
            rows.append({'arm': arm, 'phase': phase, 'pins': lists[0]})
    identical = all(row['pins'] == rows[0]['pins'] for row in rows)
    (results / 'pair-resolution-comparison.json').write_text(json.dumps(
        {'actualAllFourSchemeResolutionsEqual': identical, 'records': rows,
         'scope': 'Actual resolution equality in this pair, not proof of old-run equivalence'}, indent=2) + '\n')
    assert identical, 'Actual before/after or unit/UI dependency resolution differs; inspect before accepting visuals'


def runtime(output):
    identifier = os.environ['TEST_DEVICE_ID']
    devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', '--json']))['devices']
    matches = [(runtime_id, device) for runtime_id, group in devices.items()
               for device in group if device['udid'] == identifier]
    assert len(matches) == 1
    runtime_id, device = matches[0]
    owner = json.loads(Path(os.environ['RUNNER_TEMP'], 'ios150-owned-simulator.json').read_text())
    assert device['name'] == owner['name'] and device['udid'] == owner['udid']
    runtimes = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'runtimes', '--json']))['runtimes']
    matched_runtime = [item for item in runtimes if item['identifier'] == runtime_id]
    assert len(matched_runtime) == 1
    data = {'device': {k: device.get(k) for k in ['name', 'udid', 'state', 'deviceTypeIdentifier']},
            'runtime': {k: matched_runtime[0].get(k) for k in ['identifier', 'name', 'version', 'buildversion']},
            'locale': os.environ['VISUAL_LOCALE'], 'appearance': 'light', 'statusBarTime': '9:41'}
    (output / 'owned-runtime.json').write_text(json.dumps(data, indent=2) + '\n')
    for filename, command in [('xcode-version.txt', ['xcodebuild', '-version']),
                              ('xcresulttool-version.txt', ['xcrun', 'xcresulttool', 'version'])]:
        (output / filename).write_bytes(subprocess.check_output(command))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['runtime', 'resolution', 'compare'])
    parser.add_argument('--source', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--native-exit', type=int)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    if args.mode == 'runtime':
        runtime(args.output)
    elif args.mode == 'resolution':
        assert args.source and args.native_exit is not None
        resolution(args.source, args.output, args.native_exit == 0)
    else:
        compare(args.output)


if __name__ == '__main__':
    main()
