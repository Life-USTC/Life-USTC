#!/usr/bin/env python3
"""Preserve native objects and reject missing selectors/skips, even with exit 0."""
import argparse
import json
import subprocess
from pathlib import Path


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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('phase', choices=['signout', 'fresh-guest', 'todo-target'])
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    bundle = args.directory / 'ui.xcresult'
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
            kind = node.get('_type', {}).get('_name', node.get('_type', {}).get('_n'))
            if kind != 'ActionTestMetadata':
                continue
            identifier = value(node['identifier'])
            status = value(node['testStatus'])
            tests.append({'identifier': identifier, 'status': status})
            result = read(value(node['summaryRef']['id']))
            path = args.directory / 'native-tests' / identifier.replace('/', '--')
            path.mkdir(parents=True, exist_ok=True)
            (path / 'summary.json').write_text(json.dumps(result, indent=2) + '\n')
    expected = {
        'signout': {'ServerJourneyTests/testSignOutRemovesPreviouslyVisibleSubscriptions'},
        'fresh-guest': {'ServerJourneyTests/testDiagnosticFreshGuestSubscriptionsEntry'},
        'todo-target': {'WorkspaceJourneyTests/testTodoCreateDeleteRefreshesHomeAndCalendar'},
    }[args.phase]
    normalized = {test['identifier'].removesuffix('()') for test in tests}
    record = {'phase': args.phase, 'tests': tests, 'expected': sorted(expected),
              'selectorSetMatches': normalized == expected and len(tests) == len(expected),
              'zeroSkipped': all(test['status'] in ['Success', 'Failure'] for test in tests),
              'allSucceeded': all(test['status'] == 'Success' for test in tests)}
    (args.directory / 'native-counts.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record, indent=2))
    assert record['selectorSetMatches'] and record['zeroSkipped'], 'Missing, extra or skipped diagnostic cases'
    assert record['allSucceeded'], 'Native metadata contains a failed diagnostic case'


if __name__ == '__main__':
    main()
