#!/usr/bin/env python3
"""Prepare one bounded QA variant; never modify the tracked Account source."""
import argparse
import difflib
import hashlib
import json
import re
import subprocess
from pathlib import Path

SOURCE = '59771f3c7dfc032cf53796c6df6108977e216286'
TEST = Path('Tests/Life-USTC-UITests/AccountJourneyTests.swift')
QA_TEST = TEST.with_name('AccountQueryDiagnosticTests.swift')


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def positive_method(source):
    start = source.index('    @MainActor\n    func testAccountManagementOpensSupportedWebsitePagesAndRefreshesProfileOnReturn()')
    end = source.index('    @MainActor\n    func testActivityPaginationFailure', start)
    return source[start:end]


def prepare(source, variant, phase):
    compiled = source
    if variant == 'scoped-query':
        before = '''        let done = app.buttons.matching(NSPredicate(format: "label IN %@", ["Done", "Close", "完成", "关闭"])).firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        let browser = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "BrowserView")).firstMatch
        XCTAssertTrue(browser.waitForExistence(timeout: 10))
'''
        after = '''        let browser = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "BrowserView")).firstMatch
        let done = browser.buttons.matching(NSPredicate(format: "label IN %@", ["Done", "Close", "完成", "关闭"])).firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        XCTAssertTrue(browser.waitForExistence(timeout: 10))
'''
        assert compiled.count(before) == 1
        compiled = compiled.replace(before, after, 1)
    elif variant == 'cached-viewport':
        before = '        for (id, path) in pages {\n'
        assert compiled.count(before) == 1
        compiled = compiled.replace(before, '        let applicationFrame = app.frame\n        XCTAssertFalse(applicationFrame.isEmpty)\n' + before, 1)
        before = '            closeWebsite(returningTo: "account_web_\\(id)")'
        assert compiled.count(before) == 1
        compiled = compiled.replace(before, before[:-1] + ', applicationFrame: applicationFrame)', 1)
        before = 'private func closeWebsite(returningTo pageID: String)'
        assert compiled.count(before) == 1
        compiled = compiled.replace(before, 'private func closeWebsite(returningTo pageID: String, applicationFrame: CGRect)', 1)
        before = 'page.frame.intersects(self.app.frame)'
        assert compiled.count(before) == 1
        compiled = compiled.replace(before, 'page.frame.intersects(applicationFrame)', 1)
    else:
        assert variant == 'baseline'
    # All positive interaction and business assertions finish before this hook.
    # Keep the original case/helper bytes for baseline, adding only post-case
    # evidence retention so successful cases also preserve requests and AX/PNG.
    before = '        if (testRun?.failureCount ?? 0) > 0 {\n'
    assert compiled.count(before) == 1
    compiled = compiled.replace(before, '        if true { // QA: retain evidence only after the original case completed.\n', 1)
    before = '        app.terminate()\n        fixture.stop()\n'
    assert compiled.count(before) == 1
    compiled = compiled.replace(before, '''        if let url = Bundle(for: Self.self).url(forResource: "AccountDiagnosticProvenance", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            let provenance = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            provenance.name = "account-diagnostic-provenance"
            provenance.lifetime = .keepAlways
            add(provenance)
        }
''' + before, 1)
    if phase == 'negative':
        template = Path(__file__).with_name('negative-controls.swift').read_text()
        expression_start = compiled.index('        waitUntil {\n            management.exists', compiled.index('private func closeWebsite('))
        expression_end = compiled.index('\n        }\n        // The composite', expression_start)
        expression = compiled[expression_start + len('        waitUntil {\n'):expression_end]
        expression = '\n'.join(line[4:] for line in expression.splitlines())
        template = template.replace('/* RETURN_EXPRESSION */', expression.lstrip())
        call = 'closeWebsite(returningTo: "account_web_profile")'
        if variant == 'cached-viewport':
            call = 'closeWebsite(returningTo: "account_web_profile", applicationFrame: applicationFrame)'
        template = template.replace('/* CLOSE_CALL */', call)
        assert compiled.endswith('}\n')
        compiled = compiled[:-2] + template + '}\n'
    if variant in ['baseline', 'scoped-query']:
        assert positive_method(compiled) == positive_method(source)
    return compiled


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--variant', choices=['baseline', 'scoped-query', 'cached-viewport'], required=True)
    parser.add_argument('--phase', choices=['positive', 'negative'], required=True)
    parser.add_argument('--verify-only', action='store_true')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    actual = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=args.source, text=True).strip()
    assert actual == SOURCE, actual
    original = subprocess.check_output(['git', 'show', 'HEAD:' + str(TEST)], cwd=args.source)
    assert (args.source / TEST).read_bytes() == original
    source = original.decode()
    original_project = subprocess.check_output(['git', 'show', 'HEAD:project.yml'], cwd=args.source, text=True)
    generated_paths = [path.strip().strip('"') for path in re.findall(
        r'^    (?:info|entitlements):\n      path: ([^\n]+)$', original_project, re.M)]
    # XcodeGen owns these declared Info/entitlement outputs. Preserve their
    # actual diff, but reject any other tracked mutation beyond QA membership.
    protected = ['git', 'diff', '--exit-code', '--', '.', ':!project.yml']
    protected += [':!' + path for path in generated_paths]
    subprocess.run(protected, cwd=args.source, check=True)
    if args.verify_only:
        actual_diff = subprocess.check_output(['git', 'diff'], cwd=args.source, text=True)
        (args.output / 'post-build-tracked.diff').write_text(actual_diff)
        assert (args.source / TEST).read_bytes() == original
        return
    compiled = prepare(source, args.variant, args.phase)
    (args.source / QA_TEST).write_text(compiled)
    project = args.source / 'project.yml'
    before = subprocess.check_output(['git', 'show', 'HEAD:project.yml'], cwd=args.source, text=True)
    marker = '      - path: "Tests/Life-USTC-UITests"\n'
    assert before.count(marker) == 1
    after = before.replace(marker, marker + '        excludes: ["AccountJourneyTests.swift"]\n', 1)
    project.write_text(after)
    config = {
        'sourceSHA': SOURCE, 'variant': args.variant, 'phase': args.phase,
        'originalTestGitBlob': subprocess.check_output(['git', 'rev-parse', 'HEAD:' + str(TEST)], cwd=args.source, text=True).strip(),
        'originalTestSHA256': digest(original), 'compiledQATestSHA256': digest(compiled.encode()),
        'originalPositiveMethodSHA256': digest(positive_method(source).encode()),
        'compiledPositiveMethodSHA256': digest(positive_method(compiled).encode()),
        'positiveMethodByteIdentical': positive_method(source) == positive_method(compiled),
        'evidenceHook': 'Post-case tearDown only, identical in all variants; no extra UI reads before/during the positive case',
        'negativePredicate': 'Extracted from the selected positive helper; not a relaxed independent predicate',
        'scope': 'Original tracked test/Swift/fixture bytes unchanged; QA copy selected by temporary target membership only',
        'xcodegenDeclaredOutputs': generated_paths,
    }
    resource = args.source / TEST.parent / 'AccountDiagnosticProvenance.json'
    resource.write_text(json.dumps(config, indent=2) + '\n')
    (args.output / 'provenance.json').write_text(resource.read_text())
    (args.output / 'original-AccountJourneyTests.swift').write_bytes(original)
    (args.output / 'compiled-QA-AccountJourneyTests.swift').write_text(compiled)
    (args.output / 'qa-test.diff').write_text(''.join(difflib.unified_diff(source.splitlines(True), compiled.splitlines(True), fromfile=str(TEST), tofile=str(QA_TEST))))
    (args.output / 'qa-target-membership.diff').write_text(''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile='project.yml', tofile='project.yml')))
    # A separate resource carries hashes without making the source self-referential.
    assert (args.source / TEST).read_bytes() == original
    subprocess.run(protected, cwd=args.source, check=True)
    print(json.dumps(config, indent=2))


if __name__ == '__main__':
    main()
