#!/usr/bin/env python3
"""Keep original native metadata; both schemes must execute exact cases, no skips."""
import argparse
import json
import subprocess
from pathlib import Path

EXPECTED = {
    'unit': {'CalendarSundayNativeRenderTests/testFixedCalendarViewsRenderNativeBeforeAfterFixtures'},
    'ui': {'CalendarSundayVisualCaptureTests/testPersonalWeekNativeCapture',
           'CalendarSundayVisualCaptureTests/testPublicYoungWeekAndMonthNativeCapture',
           'CalendarSundayVisualCaptureTests/testYoungDatePickerNativeCapture'},
}


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
    expected = EXPECTED[phase]
    normalized = {test['identifier'].removesuffix('()') for test in tests}
    record = {'phase': phase, 'tests': tests, 'expected': sorted(expected),
              'selectorSetMatches': normalized == expected and len(tests) == len(expected),
              'zeroSkipped': all(test['status'] in ['Success', 'Failure'] for test in tests),
              'allSucceeded': bool(tests) and all(test['status'] == 'Success' for test in tests)}
    return record


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('phase', choices=EXPECTED)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    bundle = args.directory / (args.phase + '.xcresult')
    assert bundle.is_dir(), f'Missing original native bundle: {bundle}'

    def read(identifier=None):
        command = ['xcrun', 'xcresulttool', 'get', '--legacy', '--format', 'json', '--path', str(bundle)]
        if identifier:
            command += ['--id', identifier]
        return json.loads(subprocess.check_output(command))

    root = read()
    (args.directory / (args.phase + '-native-root.json')).write_text(json.dumps(root, indent=2) + '\n')
    tests = []
    for index, action in enumerate(root.get('actions', {}).get('_values', [])):
        reference = action.get('actionResult', {}).get('testsRef', {}).get('id')
        if not reference:
            continue
        plan = read(value(reference))
        (args.directory / f'{args.phase}-native-plan-{index}.json').write_text(json.dumps(plan, indent=2) + '\n')
        for node in walk(plan):
            if node.get('_type', {}).get('_name', node.get('_type', {}).get('_n')) != 'ActionTestMetadata':
                continue
            identifier = value(node['identifier'])
            tests.append({'identifier': identifier, 'status': value(node['testStatus'])})
            summary = read(value(node['summaryRef']['id']))
            target = args.directory / (args.phase + '-native-tests') / identifier.replace('/', '--')
            target.mkdir(parents=True, exist_ok=True)
            (target / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    record = validate(args.phase, tests)
    (args.directory / (args.phase + '-native-counts.json')).write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record, indent=2))
    assert record['selectorSetMatches'] and record['zeroSkipped'] and record['allSucceeded'], \
        'Native results missing, extra, duplicated, skipped or failed'


if __name__ == '__main__':
    main()
