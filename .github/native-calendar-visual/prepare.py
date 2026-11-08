#!/usr/bin/env python3
"""NEVER MERGE: bound both Sunday comparison arms to exact reviewed inputs."""
import argparse
import difflib
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path

QA_HASHES = {
    'CalendarSundayNativeRenderTests.swift': 'a688f2a45d1d17b69a3aa05fb3d8eb2092cd2e4995c813ffb7dd579a93cdc3a8',
    'CalendarSundayVisualCaptureTests.swift': '5760bcf2cde9b89b27fac1317d605d83cdc7b536599af29af9b73eb045493055',
}
UNIT = 'Tests/Life-USTC-Tests'
UI = 'Tests/Life-USTC-UITests'
FIXTURE = UI + '/PublicDiscoveryHTTPState.swift'
CODE = {'.swift', '.m', '.mm', '.c', '.cc', '.cpp', '.h', '.hpp', '.metal'}
CACHES = {'SourcePackages', 'NativeVisualResults'}


def git(source, *args):
    return subprocess.check_output(['git', *args], cwd=source)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def outputs(project):
    return [p.strip().strip('"') for p in re.findall(
        r'^    (?:info|entitlements):\n      path: ([^\n]+)$', project, re.M)]


def guard(source, generated, allowed, prepared):
    subprocess.run(['git', 'diff', '--cached', '--exit-code', 'HEAD', '--', '.'], cwd=source, check=True)
    command = ['git', 'diff', '--exit-code', 'HEAD', '--', '.']
    if prepared:
        command += [':!project.yml'] + [':!' + p for p in generated]
    subprocess.run(command, cwd=source, check=True)
    accepted = set(allowed) | set(generated) if prepared else set()
    untracked = git(source, 'ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')
    unexpected = [p for p in untracked if p and p not in accepted and p.split('/')[0] not in CACHES]
    assert not unexpected, f'Unexpected untracked input: {unexpected}'
    tracked = set(git(source, 'ls-files', '-z').decode().split('\0'))
    for directory, children, names in os.walk(source, followlinks=False):
        parent = Path(directory)
        children[:] = [p for p in children if p != '.git'
                       and not (parent == source and (p in CACHES or p == 'Life-USTC.xcodeproj'))]
        for name in children + names:
            path = parent / name
            relative = str(path.relative_to(source))
            if path.is_symlink() or path.suffix.lower() in CODE:
                assert relative in tracked or (prepared and relative in accepted), \
                    f'Unexpected ignored/compiler input: {relative}'


def inputs(source, carrier, config):
    buffers = {}
    for folder, filename in [(UNIT, 'CalendarSundayNativeRenderTests.swift'),
                             (UI, 'CalendarSundayVisualCaptureTests.swift')]:
        raw = (carrier / filename).read_bytes()
        assert sha(raw) == QA_HASHES[filename], f'Reviewed Swift QA changed: {filename}'
        buffers[folder + '/' + filename] = raw
        buffers[folder + '/CalendarVisualConfig.json'] = (json.dumps(config, indent=2) + '\n').encode()
    original = git(source, 'show', 'HEAD:' + FIXTURE)
    compiled = original.decode()
    for old, new in {
        '2035-09-16T09:00:00+08:00': '2026-10-23T09:00:00+08:00',
        '2035-09-16T11:00:00+08:00': '2026-10-23T11:00:00+08:00',
        '2035-09-10T09:00:00+08:00': '2026-10-20T09:00:00+08:00',
        '2035-09-15T18:00:00+08:00': '2026-10-22T18:00:00+08:00',
    }.items():
        assert compiled.count(old) == 1
        compiled = compiled.replace(old, new)
    marker = 'final class PublicDiscoveryHTTPState {\n'
    assert compiled.count(marker) == 1
    compiled = compiled.replace(marker, marker + '    static let calendarVisualFixtureID = "fixed-public-records-2026-10-23"\n', 1)
    buffers[UI + '/CalendarVisualPublicDiscoveryHTTPState.swift'] = compiled.encode()
    return buffers, original


def project_copy(original):
    text = original
    for marker, addition in [
        ('      - path: "Tests/Life-USTC-UITests"\n', '        excludes: ["PublicDiscoveryHTTPState.swift"]\n'),
        ('      - path: "Views/"\n', '      - path: "Widget/CurriculumWeekWidget.swift"\n'),
        ('  "Life-USTC-Tests":\n    build:\n      targets:\n        Life-USTC-Tests: [test]\n        Life-USTC: [test]\n    test:\n',
         '      environmentVariables:\n        UI_TEST_SERVER_URL: "http://127.0.0.1:9"\n        UI_TEST_SERVER_ACCESS_TOKEN: "native-visual-isolation-token"\n        UI_TEST_SKIP_ONBOARDING: "1"\n'),
    ]:
        assert text.count(marker) == 1, marker
        text = text.replace(marker, marker + addition, 1)
    return text


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['prepare', 'verify', 'cleanup'])
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--carrier', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--expected-source', required=True)
    parser.add_argument('--arm', choices=['before', 'after'], required=True)
    parser.add_argument('--locale', choices=['en', 'zh-Hans'], required=True)
    parser.add_argument('--anchor', required=True)
    args = parser.parse_args()
    source = args.source.resolve()
    assert git(source, 'rev-parse', 'HEAD').decode().strip() == args.expected_source
    config = dict(arm=args.arm, sourceSHA=args.expected_source, locale=args.locale,
                  expectedFirstWeekday=2 if args.arm == 'before' else 1,
                  anchorCivilDay=args.anchor, renderDefaultTimeZone='America/Los_Angeles')
    original_project = git(source, 'show', 'HEAD:project.yml').decode()
    generated = outputs(original_project)
    buffers, original_fixture = inputs(source, args.carrier, config)
    guard(source, generated, buffers, args.mode != 'prepare')
    expected_project = project_copy(original_project)
    args.output.mkdir(parents=True, exist_ok=True)
    if args.mode == 'prepare':
        for filename, raw in buffers.items():
            assert not (source / filename).exists(), f'Preexisting QA input: {filename}'
            (source / filename).write_bytes(raw)
        (source / 'project.yml').write_text(expected_project)
        (args.output / 'fixture-config.json').write_text(json.dumps(config, indent=2) + '\n')
        (args.output / 'original-public-fixture-source.swift').write_bytes(original_fixture)
        (args.output / 'compiled-qa-public-fixture-source.swift').write_bytes(buffers[UI + '/CalendarVisualPublicDiscoveryHTTPState.swift'])
        (args.output / 'qa-target-membership.diff').write_text(''.join(difflib.unified_diff(
            original_project.splitlines(True), expected_project.splitlines(True), fromfile='project.yml', tofile='project.yml')))
        record = {'sourceSHA': args.expected_source, 'sourceTree': git(source, 'rev-parse', 'HEAD^{tree}').decode().strip(),
                  'originalPublicFixtureBlob': git(source, 'rev-parse', 'HEAD:' + FIXTURE).decode().strip(),
                  'originalPublicFixtureSHA256': sha(original_fixture),
                  'compiledPublicFixtureSHA256': sha(buffers[UI + '/CalendarVisualPublicDiscoveryHTTPState.swift']),
                  'inputs': {p: sha(raw) for p, raw in buffers.items()}, 'xcodegenDeclaredOutputs': generated,
                  'scope': 'Unchanged source/regular fixtures; exact reviewed QA/config and target membership only. Widget entry-view is not extension lifecycle.'}
        (args.output / 'input-provenance.json').write_text(json.dumps(record, indent=2) + '\n')
    assert (source / 'project.yml').read_text() == expected_project
    assert (source / FIXTURE).read_bytes() == original_fixture
    for filename, raw in buffers.items():
        assert (source / filename).read_bytes() == raw, f'QA/config input changed: {filename}'
    guard(source, generated, buffers, True)
    if args.mode != 'prepare':
        (args.output / 'post-build-tracked.diff').write_bytes(git(source, 'diff', 'HEAD'))
    if args.mode == 'cleanup':
        # Only declared generated outputs and exact temporary membership/inputs;
        # every other tracked/index/compiler input passed the guard first.
        tracked = set(git(source, 'ls-files', '-z').decode().split('\0'))
        restore = ['project.yml'] + [p for p in generated if p in tracked]
        subprocess.run(['git', 'restore', '--source=HEAD', '--worktree', '--', *restore], cwd=source, check=True)
        for filename in list(buffers) + [p for p in generated if p not in tracked]:
            (source / filename).unlink(missing_ok=True)
        guard(source, generated, buffers, False)
        (args.output / 'source-cleanup.json').write_text(json.dumps({'sourceSHA': args.expected_source,
             'exactTemporaryInputsRemoved': sorted(buffers), 'workingSourceAndIndexCleanAgainstHEAD': True}, indent=2) + '\n')


if __name__ == '__main__':
    main()
