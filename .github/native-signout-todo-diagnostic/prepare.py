#!/usr/bin/env python3
"""NEVER MERGE: canonical source-only guard; no Swift/project/fixture patches."""
import argparse
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path

SOURCE = '7897d183f061eba8ac0084f8e4bac74a18460c04'
ACCOUNT = 'Tests/Life-USTC-UITests/AccountJourneyTests.swift'
CASE = 'testAccountManagementOpensSupportedWebsitePagesAndRefreshesProfileOnReturn'
METHOD_SHA = 'ab690c6b7f8acb1ee6485a793bd3bbe4d74bed3fc437e7095c943fbefa4ac611'
CODE = {'.swift', '.m', '.mm', '.c', '.cc', '.cpp', '.h', '.hpp', '.metal'}


def git(source, *args):
    return subprocess.check_output(['git', *args], cwd=source)


def guard(source, generated, after_generation):
    subprocess.run(['git', 'diff', '--cached', '--exit-code', 'HEAD', '--', '.'], cwd=source, check=True)
    command = ['git', 'diff', '--exit-code', 'HEAD', '--', '.']
    if after_generation:
        command += [':!' + p for p in generated]
    subprocess.run(command, cwd=source, check=True)
    allowed = set(generated) if after_generation else set()
    untracked = git(source, 'ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')
    assert not [p for p in untracked if p and p not in allowed and not p.startswith('SourcePackages/')], 'Unexpected untracked input'
    tracked = set(git(source, 'ls-files', '-z').decode().split('\0'))
    for directory, children, names in os.walk(source, followlinks=False):
        parent = Path(directory)
        children[:] = [p for p in children if p != '.git' and not
                       (parent == source and p in ['SourcePackages', 'Life-USTC.xcodeproj'])]
        for name in children + names:
            path = parent / name
            if path.is_symlink() or path.suffix.lower() in CODE:
                assert str(path.relative_to(source)) in tracked, f'Unexpected compiler/symlink input: {path}'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--after-generation', action='store_true')
    args = parser.parse_args()
    source = args.source.resolve()
    assert git(source, 'rev-parse', 'HEAD').decode().strip() == SOURCE
    project = git(source, 'show', 'HEAD:project.yml')
    assert (source / 'project.yml').read_bytes() == project
    generated = [p.strip().strip('"') for p in re.findall(
        r'^    (?:info|entitlements):\n      path: ([^\n]+)$', project.decode(), re.M)]
    guard(source, generated, args.after_generation)
    raw = git(source, 'show', 'HEAD:' + ACCOUNT)
    assert (source / ACCOUNT).read_bytes() == raw
    text = raw.decode()
    start = text.index('    @MainActor\n    func ' + CASE + '(')
    end = text.index('\n    @MainActor\n', start + 1)
    assert hashlib.sha256(text[start:end].encode()).hexdigest() == METHOD_SHA
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / 'source-provenance.json').write_text(json.dumps({
        'sourceSHA': SOURCE, 'sourceTree': git(source, 'rev-parse', 'HEAD^{tree}').decode().strip(),
        'originalAccountFileSHA256': hashlib.sha256(raw).hexdigest(), 'originalCaseSHA256': METHOD_SHA,
        'projectSHA256': hashlib.sha256(project).hexdigest(), 'noSwiftFixtureOrProjectChanges': True,
        'allowedXcodegenOutputs': generated,
        'scope': 'No QA copies or API replacements; unit414 then original Account keep/fresh-install lifecycle only.'
    }, indent=2) + '\n')
    if args.after_generation:
        (args.output / 'generated-output.diff').write_bytes(git(source, 'diff', 'HEAD'))


if __name__ == '__main__':
    main()
