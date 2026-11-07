#!/usr/bin/env python3
"""Original unit414 identities / single original UI case, fail closed on skips."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

UNIT_IDS_SHA = '4016f2c5fe134a58327ef250abbb798a4db02c39b290a17615cd8822c608e5b4'
ACCOUNT = 'AccountJourneyTests/testAccountManagementOpensSupportedWebsitePagesAndRefreshesProfileOnReturn'


def value(node):
    return node.get('_value', node.get('_v'))


def walk(node):
    if isinstance(node, dict):
        yield node
        for child in node.values():
            yield from walk(child)
    elif isinstance(node, list):
        for child in node:
            yield from walk(child)


def validate(phase, tests):
    ids = [test['identifier'].removesuffix('()') for test in tests]
    identity_sha = hashlib.sha256(json.dumps(sorted(ids), separators=(',', ':')).encode()).hexdigest()
    matches = (len(ids) == 414 and identity_sha == UNIT_IDS_SHA) if phase == 'unit' else ids == [ACCOUNT]
    return {'phase': phase, 'tests': tests, 'identitySHA256': identity_sha,
            'selectorSetMatches': matches and len(set(ids)) == len(ids),
            'zeroSkipped': all(test['status'] in ['Success', 'Failure'] for test in tests),
            'allSucceeded': bool(tests) and all(test['status'] == 'Success' for test in tests)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('phase', choices=['unit', 'keep', 'fresh'])
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    name = 'unit' if args.phase == 'unit' else 'ui'
    bundle = args.directory / (name + '.xcresult')
    assert bundle.is_dir(), f'Missing original result bundle: {bundle}'

    def read(identifier=None):
        command = ['xcrun', 'xcresulttool', 'get', '--legacy', '--format', 'json', '--path', str(bundle)]
        if identifier:
            command += ['--id', identifier]
        return json.loads(subprocess.check_output(command))

    root = read()
    (args.directory / 'native-root.json').write_text(json.dumps(root, indent=2) + '\n')
    tests = []
    for index, action in enumerate(root.get('actions', {}).get('_values', [])):
        reference = action.get('actionResult', {}).get('testsRef', {}).get('id')
        if not reference:
            continue
        plan = read(value(reference))
        (args.directory / f'native-plan-{index}.json').write_text(json.dumps(plan, indent=2) + '\n')
        for node in walk(plan):
            if node.get('_type', {}).get('_name', node.get('_type', {}).get('_n')) != 'ActionTestMetadata':
                continue
            identifier, status = value(node['identifier']), value(node['testStatus'])
            tests.append({'identifier': identifier, 'status': status})
            # Raw bundles already retain every original unit summary. Avoid414
            # redundant subprocess exports; keep UI and failed-unit summaries.
            if args.phase != 'unit' or status != 'Success':
                summary = read(value(node['summaryRef']['id']))
                target = args.directory / 'native-tests' / identifier.replace('/', '--')
                target.mkdir(parents=True, exist_ok=True)
                (target / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    record = validate(args.phase, tests)
    (args.directory / 'native-counts.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record, indent=2))
    assert record['selectorSetMatches'] and record['zeroSkipped'] and record['allSucceeded'], \
        'Missing, extra, duplicate, skipped or failed original cases'


if __name__ == '__main__':
    main()
