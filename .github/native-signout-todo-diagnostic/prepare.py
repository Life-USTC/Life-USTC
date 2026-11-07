#!/usr/bin/env python3
"""NEVER MERGE: four original-case A/B inputs, fixed production source."""
import argparse
import difflib
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path

SOURCE = '7897d183f061eba8ac0084f8e4bac74a18460c04'
ROOT = Path('Tests/Life-USTC-UITests')
CASES = {
    'iPhone': ('AccountJourneyTests.swift', 'testAccountManagementOpensSupportedWebsitePagesAndRefreshesProfileOnReturn'),
    'iPad': ('YoungCampusJourneyTests.swift', 'testActivityFiltersApplyCancelClearAndPreserveUnknownDateContext'),
}
CODE = {'.swift', '.m', '.mm', '.c', '.cc', '.cpp', '.h', '.hpp', '.metal'}


def git(source, *args):
    return subprocess.check_output(['git', *args], cwd=source)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def method(text, name):
    start = text.index('    @MainActor\n    func ' + name + '(')
    end = text.index('\n    @MainActor\n', start + 1)
    return text[start:end]


def guard(source, generated, qa, prepared):
    subprocess.run(['git', 'diff', '--cached', '--exit-code', 'HEAD', '--', '.'], cwd=source, check=True)
    command = ['git', 'diff', '--exit-code', 'HEAD', '--', '.']
    if prepared:
        command += [':!project.yml'] + [':!' + path for path in generated]
    subprocess.run(command, cwd=source, check=True)
    allowed = {str(qa), *generated} if prepared else set()
    untracked = git(source, 'ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')
    assert not [p for p in untracked if p and p not in allowed and not p.startswith('SourcePackages/')], 'Unexpected untracked input'
    tracked = set(git(source, 'ls-files', '-z').decode().split('\0'))
    for directory, children, names in os.walk(source, followlinks=False):
        parent = Path(directory)
        children[:] = [p for p in children if p != '.git' and not
                       (parent == source and (p == 'SourcePackages' or p == 'Life-USTC.xcodeproj'))]
        for name in children + names:
            path = parent / name
            if path.is_symlink() or path.suffix.lower() in CODE:
                relative = str(path.relative_to(source))
                assert relative in tracked or (prepared and relative in allowed), f'Unexpected compiler/symlink input: {relative}'


def compile_source(original, device, variant):
    text = original
    if device == 'iPad':
        # Original run metadata: device/interface orientation raw3, scale2;
        # actual native root frame1376x1032. Same early setup gate in A and B.
        marker = '        app.launchEnvironment["UI_TEST_SERVER_ACCESS_TOKEN"] = ServerJourneyHTTPFixture.token\n'
        assert text.count(marker) == 1
        text = text.replace(marker, marker + '        XCUIDevice.shared.orientation = .landscapeLeft\n        XCTAssertEqual(XCUIDevice.shared.orientation.rawValue, 3)\n', 1)
        marker = '    private func openYoung() {\n'
        assert text.count(marker) == 1
        text = text.replace(marker, marker + '''        let diagnosticFrame = app.frame
        XCTAssertEqual(diagnosticFrame.width, 1376, accuracy: 0.5)
        XCTAssertEqual(diagnosticFrame.height, 1032, accuracy: 0.5)
        let frameEvidence = XCTAttachment(string: "orientation=3;frame=\\(diagnosticFrame)")
        frameEvidence.name = "diagnostic-original-landscape-frame"
        frameEvidence.lifetime = .keepAlways
        add(frameEvidence)
''', 1)
    if variant == 'B' and device == 'iPhone':
        old = '        done.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()\n'
        assert text.count(old) == 1
        text = text.replace(old, '        done.tap()\n', 1)
    elif variant == 'B':
        marker = '    private var app: XCUIApplication!\n'
        assert text.count(marker) == 1
        text = text.replace(marker, marker + '    private var diagnosticActiveTrueOption = false\n', 1)
        marker = '        open("young.filters.\\(field)")\n        open(value)\n'
        assert text.count(marker) == 1
        text = text.replace(marker, '''        open("young.filters.\\(field)")
        diagnosticActiveTrueOption = field == "active" && value == "In source signup list"
        defer { diagnosticActiveTrueOption = false }
        open(value)
''', 1)
        start = text.index('    private func open(_ id: String,')
        end = text.index('\n    @MainActor\n', start + 1)
        original_open = text[start:end]
        marker = '        button.tap()\n    }\n'
        assert original_open.count(marker) == 1
        changed_open = original_open.replace(marker, '''        if diagnosticActiveTrueOption && id == "In source signup list" {
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        } else {
            button.tap()
        }
    }
''', 1)
        text = text[:start] + changed_open + text[end:]
    assert method(text, CASES[device][1]) == method(original, CASES[device][1])
    return text


def main():
    p = argparse.ArgumentParser()
    p.add_argument('mode', choices=['prepare', 'verify', 'cleanup'])
    p.add_argument('--source', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--device', choices=CASES, required=True)
    p.add_argument('--variant', choices=['A', 'B'], required=True)
    args = p.parse_args()
    source = args.source.resolve()
    assert git(source, 'rev-parse', 'HEAD').decode().strip() == SOURCE
    filename, case = CASES[args.device]
    original_path = ROOT / filename
    qa = ROOT / ('Diagnostic' + filename)
    original = git(source, 'show', 'HEAD:' + str(original_path))
    compiled = compile_source(original.decode(), args.device, args.variant).encode()
    project = git(source, 'show', 'HEAD:project.yml').decode()
    generated = [s.strip().strip('"') for s in re.findall(r'^    (?:info|entitlements):\n      path: ([^\n]+)$', project, re.M)]
    guard(source, generated, qa, args.mode != 'prepare')
    marker = '      - path: "Tests/Life-USTC-UITests"\n'
    assert project.count(marker) == 1
    expected = project.replace(marker, marker + f'        excludes: ["{filename}"]\n', 1)
    args.output.mkdir(parents=True, exist_ok=True)
    if args.mode == 'prepare':
        assert not (source / qa).exists()
        (source / qa).write_bytes(compiled)
        (source / 'project.yml').write_text(expected)
        record = {'sourceSHA': SOURCE, 'device': args.device, 'variant': args.variant,
                  'selector': filename.removesuffix('.swift') + '/' + case,
                  'originalTestGitBlob': git(source, 'rev-parse', 'HEAD:' + str(original_path)).decode().strip(),
                  'originalTestSHA256': sha(original), 'compiledQATestSHA256': sha(compiled),
                  'originalCaseSHA256': sha(method(original.decode(), case).encode()),
                  'compiledCaseSHA256': sha(method(compiled.decode(), case).encode()),
                  'originalCaseByteIdentical': True, 'xcodegenDeclaredOutputs': generated,
                  'interpretation': 'One isolated original case per variant. A/B API sensitivity is not a production fix, historical cause or full-suite acceptance.'}
        (args.output / 'provenance.json').write_text(json.dumps(record, indent=2) + '\n')
        (args.output / ('original-' + filename)).write_bytes(original)
        (args.output / ('compiled-QA-' + filename)).write_bytes(compiled)
        (args.output / 'qa-source.diff').write_text(''.join(difflib.unified_diff(original.decode().splitlines(True), compiled.decode().splitlines(True), fromfile=str(original_path), tofile=str(qa))))
        (args.output / 'qa-target-membership.diff').write_text(''.join(difflib.unified_diff(project.splitlines(True), expected.splitlines(True), fromfile='project.yml', tofile='project.yml')))
    assert (source / original_path).read_bytes() == original
    assert (source / qa).read_bytes() == compiled
    assert (source / 'project.yml').read_text() == expected
    guard(source, generated, qa, True)
    if args.mode != 'prepare':
        (args.output / 'post-build-tracked.diff').write_bytes(git(source, 'diff', 'HEAD'))
    if args.mode == 'cleanup':
        tracked = set(git(source, 'ls-files', '-z').decode().split('\0'))
        subprocess.run(['git', 'restore', '--source=HEAD', '--worktree', '--', 'project.yml',
                        *[path for path in generated if path in tracked]], cwd=source, check=True)
        for path in [str(qa)] + [path for path in generated if path not in tracked]:
            (source / path).unlink(missing_ok=True)
        guard(source, generated, qa, False)


if __name__ == '__main__':
    main()
