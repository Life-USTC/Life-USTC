#!/usr/bin/env python3
"""NEVER MERGE: independent QA copies, exact original source/fixture unchanged."""
import argparse
import difflib
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path

SOURCE = '7f2a63c21b64a6b1958ad4883dd891a268c987b3'
TEST_ROOT = Path('Tests/Life-USTC-UITests')
SIGNOUT = 'testSignOutRemovesPreviouslyVisibleSubscriptions'
TODO = 'testTodoCreateDeleteRefreshesHomeAndCalendar'
QA_FILES = {TEST_ROOT / ('Diagnostic' + name) for name in
            ['ServerJourneyTests.swift', 'WorkspaceJourneyTests.swift']}
CODE_SUFFIXES = {'.swift', '.m', '.mm', '.c', '.cc', '.cpp', '.h', '.hpp', '.metal'}


def guard_source(source, generated_paths, prepared):
    # A clean working tree can still hide staged edits. Both the index and the
    # actual build inputs must be checked against the pinned checkout.
    subprocess.run(['git', 'diff', '--cached', '--exit-code', 'HEAD', '--', '.'],
                   cwd=source, check=True)
    protected = ['git', 'diff', '--exit-code', 'HEAD', '--', '.']
    if prepared:
        protected += [':!project.yml'] + [':!' + path for path in generated_paths]
    subprocess.run(protected, cwd=source, check=True)
    allowed = ({str(path) for path in QA_FILES} | set(generated_paths)) if prepared else set()
    untracked = subprocess.check_output(
        ['git', 'ls-files', '--others', '--exclude-standard', '-z'], cwd=source
    ).decode().split('\0')
    unexpected = [path for path in untracked if path and path not in allowed
                  and not path.startswith('SourcePackages/')]
    assert not unexpected, f'Unexpected untracked source inputs: {unexpected}'
    tracked = set(subprocess.check_output(['git', 'ls-files', '-z'], cwd=source).decode().split('\0'))
    # Also catch ignored compiler inputs. The single declared external SPM
    # cache is not an application-source directory and is attested separately.
    for directory, children, names in os.walk(source, followlinks=False):
        parent = Path(directory)
        children[:] = [name for name in children if name != '.git'
                       and not (parent == source and name == 'SourcePackages')
                       and not name.endswith('.xcodeproj')]
        for name in names:
            path = parent / name
            relative = str(path.relative_to(source))
            if path.suffix in CODE_SUFFIXES:
                assert relative in tracked or (prepared and relative in allowed), \
                    f'Unexpected compiler input: {relative}'


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def method(source, name):
    start = source.index('    @MainActor\n    func ' + name + '(')
    end = source.index('\n    @MainActor\n', start + 1)
    return source[start:end]


OBSERVE = r'''
    // QA-only synchronous observations may change timing; never a product fix.
    @MainActor
    private func diagnosticObserve(_ phase: String) {
        XCTContext.runActivity(named: "diagnostic-observation-\(phase)") { _ in
            let started = ISO8601DateFormatter().string(from: Date())
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "diagnostic-\(phase)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "diagnostic-\(phase)-AX"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            diagnosticRequests("\(phase)-requests")
            let timing = XCTAttachment(string: "started=\(started)\nfinished=\(ISO8601DateFormatter().string(from: Date()))")
            timing.name = "diagnostic-\(phase)-observation-time"
            timing.lifetime = .keepAlways
            add(timing)
        }
    }

    private func diagnosticRequests(_ phase: String) {
        let records: [[String: Any]] = fixture.requests.map { request in
            ["method": request.method, "path": request.path, "query": request.query,
             "headers": request.headers, "jsonBody": request.jsonBody]
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = "diagnostic-\(phase)"
            attachment.lifetime = .keepAlways
            add(attachment)
        } catch {
            XCTFail("Cannot serialize real diagnostic fixture requests: \(error)")
        }
    }
'''

FRESH = r'''
    @MainActor
    func testDiagnosticFreshGuestSubscriptionsEntry() throws {
        app.launch()
        open("home_subscriptions")
        XCTAssertTrue(app.buttons["subscriptions_sign_in"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["subscription_43"].exists)
        XCTAssertFalse(fixture.requests.contains { $0.path.hasPrefix("/api/workspace/") })
        XCTAssertFalse(fixture.requests.contains { $0.headers["authorization"] != nil })
        XCTAssertTrue(fixture.requests.allSatisfy { $0.method == "GET" })
    }
'''


def compile_source(original, variant):
    if variant == 'todo-target':
        # Apply only the reviewed candidate to a temporary copy, never tracked source.
        patch = Path(__file__).with_name('todo-period.patch').read_bytes()
        # Exact hunk application in memory: reject drift/context mismatch.
        lines = original.splitlines(keepends=True)
        output, position = [], 0
        for line in patch.decode().splitlines(keepends=True):
            if line.startswith(('---', '+++')):
                continue
            if line.startswith('@@'):
                start = int(re.match(r'@@ -(\d+)', line).group(1)) - 1
                assert start >= position
                output.extend(lines[position:start]); position = start
            elif line.startswith(' '):
                assert lines[position] == line[1:]
                output.append(line[1:]); position += 1
            elif line.startswith('-'):
                assert lines[position] == line[1:]
                position += 1
            elif line.startswith('+'):
                output.append(line[1:])
            else:
                raise AssertionError(line)
        return ''.join(output + lines[position:])
    assert variant == 'signout'
    compiled = original
    if variant == 'signout':
        compiled = compiled.replace('    private var app: XCUIApplication!\n',
                                    '    private var app: XCUIApplication!\n    private var diagnosticSubscriptionTap = 0\n', 1)
        before = '        button.tap()\n    }\n'
        after = '''        if identifier == "home_subscriptions" {
            diagnosticSubscriptionTap += 1
            diagnosticObserve("subscriptions-\\(diagnosticSubscriptionTap)-before-tap")
        }
        button.tap()
    }
'''
        assert compiled.count(before) == 1
        compiled = compiled.replace(before, after, 1)
    # Retain teardown for success as well; this is after all original assertions.
    before = '        if (testRun?.failureCount ?? 0) > 0 {\n'
    assert compiled.count(before) == 1
    compiled = compiled.replace(before, '        if true { // QA: preserve post-case evidence for success and failure.\n', 1)
    before = '        app?.terminate()\n'
    assert compiled.count(before) == 1
    compiled = compiled.replace(before, '        diagnosticRequests("teardown-requests")\n' + before, 1)
    assert compiled.endswith('}\n')
    compiled = compiled[:-2] + OBSERVE + FRESH + '}\n'
    assert method(compiled, SIGNOUT) == method(original, SIGNOUT)
    return compiled


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--verify-only', action='store_true')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=args.source, text=True).strip() == SOURCE
    original_project = subprocess.check_output(['git', 'show', 'HEAD:project.yml'], cwd=args.source, text=True)
    generated_paths = [path.strip().strip('"') for path in re.findall(
        r'^    (?:info|entitlements):\n      path: ([^\n]+)$', original_project, re.M)]
    guard_source(args.source, generated_paths, args.verify_only)
    marker = '      - path: "Tests/Life-USTC-UITests"\n'
    assert original_project.count(marker) == 1
    project = original_project.replace(marker, marker + '        excludes: ["ServerJourneyTests.swift", "WorkspaceJourneyTests.swift"]\n', 1)
    if args.verify_only:
        (args.output / 'post-build-tracked.diff').write_text(subprocess.check_output(['git', 'diff'], cwd=args.source, text=True))
        assert (args.source / 'project.yml').read_text() == project
        for filename, variant in [('ServerJourneyTests.swift', 'signout'), ('WorkspaceJourneyTests.swift', 'todo-target')]:
            test = TEST_ROOT / filename
            original = subprocess.check_output(['git', 'show', 'HEAD:' + str(test)], cwd=args.source)
            assert (args.source / test).read_bytes() == original
            assert (args.source / test.with_name('Diagnostic' + test.name)).read_text() == compile_source(original.decode(), variant)
        return
    (args.source / 'project.yml').write_text(project)
    records = []
    for filename, variant, name in [('ServerJourneyTests.swift', 'signout', SIGNOUT), ('WorkspaceJourneyTests.swift', 'todo-target', TODO)]:
        test = TEST_ROOT / filename
        qa_test = test.with_name('Diagnostic' + test.name)
        original = subprocess.check_output(['git', 'show', 'HEAD:' + str(test)], cwd=args.source)
        assert (args.source / test).read_bytes() == original
        compiled = compile_source(original.decode(), variant)
        (args.source / qa_test).write_text(compiled)
        record = {'sourceSHA': SOURCE, 'variant': variant, 'originalTestGitBlob': subprocess.check_output(
            ['git', 'rev-parse', 'HEAD:' + str(test)], cwd=args.source, text=True).strip(),
            'originalTestSHA256': digest(original), 'compiledQATestSHA256': digest(compiled.encode()),
            'originalCaseSHA256': digest(method(original.decode(), name).encode()),
            'compiledCaseSHA256': digest(method(compiled, name).encode()),
            'originalCaseByteIdentical': method(original.decode(), name) == method(compiled, name),
            'xcodegenDeclaredOutputs': generated_paths,
            'timingLimitation': 'Pre-tap native PNG+AX reads can alter timing; after-case evidence follows all original assertions. Isolated passes do not establish full-suite cause/fix.',
            'scope': 'Original tracked tests, production/fixtures/owner identity unchanged; QA-copy target membership only.'}
        records.append(record)
        (args.output / ('original-' + test.name)).write_bytes(original)
        (args.output / ('compiled-QA-' + test.name)).write_text(compiled)
        (args.output / ('qa-' + test.name + '.diff')).write_text(''.join(difflib.unified_diff(original.decode().splitlines(True), compiled.splitlines(True), fromfile=str(test), tofile=str(qa_test))))
    (args.output / 'provenance.json').write_text(json.dumps(records, indent=2) + '\n')
    (args.output / 'qa-target-membership.diff').write_text(''.join(difflib.unified_diff(original_project.splitlines(True), project.splitlines(True), fromfile='project.yml', tofile='project.yml')))
    guard_source(args.source, generated_paths, True)
    print(json.dumps(records, indent=2))


if __name__ == '__main__':
    main()
