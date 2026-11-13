#!/usr/bin/env python3
"""Bind this workflow's native, catalog-identity and archive package resolutions."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

FAMILIES = ('iPhone', 'iPad')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def pins(path):
    data = json.loads(Path(path).read_bytes())
    rows = data.get('pins')
    require(isinstance(rows, list) and len(rows) == 12, 'expected 12 pins')
    result = []
    for row in rows:
        require(isinstance(row, dict), 'invalid pin')
        state = row.get('state')
        require(isinstance(state, dict), 'invalid pin state')
        values = (row.get('identity'), row.get('location'), state.get('revision'), state.get('version'))
        require(all(isinstance(v, str) and v for v in values[:3]), 'invalid identity/location/revision')
        require(values[3] is None or isinstance(values[3], str), 'invalid package version')
        result.append(values)
    require(len({row[0] for row in result}) == 12, 'duplicate pin identity')
    return sorted(result)


def context(args, family=False):
    result = {key: str(getattr(args, key)) for key in ('checkout', 'tree', 'run', 'attempt')}
    require(all(re.fullmatch(r'[0-9a-f]{40}', result[k]) for k in ('checkout', 'tree')), 'invalid checkout/tree')
    require(all(v.isdigit() and int(v) > 0 for v in (result['run'], result['attempt'])), 'invalid run/attempt')
    if family:
        require(args.family in FAMILIES, 'invalid family')
        result['family'] = args.family
    return result


def write_sha(path):
    path = Path(path)
    path.with_name(path.name.replace('Package.', 'package-').replace('.resolved', '') + '.sha256').write_text(f'{digest(path)}  {path.name}\n')


def capture(lock, output, expected):
    pins(lock)
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    baseline = output / 'Package.before.resolved'
    shutil.copyfile(lock, baseline)
    write_sha(baseline)
    meta = dict(expected, schema=1, before_sha256=digest(baseline), verified=False)
    (output / 'package-source.json').write_text(json.dumps(meta, sort_keys=True) + '\n')


def metadata(folder, expected, complete=False):
    folder = Path(folder)
    meta = json.loads((folder / 'package-source.json').read_bytes())
    require(meta.get('schema') == 1, 'invalid source schema')
    require(all(meta.get(k) == v for k, v in expected.items()), 'resolution source mismatch')
    baseline = folder / 'Package.before.resolved'
    require(meta.get('before_sha256') == digest(baseline), 'baseline hash mismatch')
    require((folder / 'package-before.sha256').read_text() == f'{digest(baseline)}  Package.before.resolved\n', 'baseline sidecar mismatch')
    pins(baseline)
    if complete:
        actual = folder / 'Package.resolved'
        require(meta.get('verified') is True, 'native resolution not verified')
        require(meta.get('after_sha256') == digest(actual), 'actual hash mismatch')
        require((folder / 'package-resolved.sha256').read_text() == f'{digest(actual)}  Package.resolved\n', 'actual sidecar mismatch')
        require(pins(actual) == pins(baseline), 'native package tuples changed')
    return meta


def finish(lock, output, expected):
    output = Path(output)
    meta = metadata(output, expected)
    actual = output / 'Package.resolved'
    shutil.copyfile(lock, actual)
    write_sha(actual)
    meta.update(after_sha256=digest(actual), verified=False)
    (output / 'package-source.json').write_text(json.dumps(meta, sort_keys=True) + '\n')
    require(pins(actual) == pins(output / 'Package.before.resolved'), 'native package tuples changed')
    meta['verified'] = True
    (output / 'package-source.json').write_text(json.dumps(meta, sort_keys=True) + '\n')


def consume(inputs, lock, baseline, expected):
    inputs = Path(inputs)
    names = {f'native-packages-{expected["run"]}-{expected["attempt"]}-{f}' for f in FAMILIES}
    require({p.name for p in inputs.iterdir()} == names, 'expected exactly both native artifacts')
    files = []
    for family in FAMILIES:
        folder = inputs / f'native-packages-{expected["run"]}-{expected["attempt"]}-{family}'
        require(folder.is_dir(), 'native artifact is not a directory')
        metadata(folder, dict(expected, family=family), complete=True)
        files.append(folder / 'Package.resolved')
    require(pins(files[0]) == pins(files[1]), 'native family package tuples differ')
    # Only choose a representative AFTER proving both families have the same graph.
    for destination in (Path(lock), Path(baseline)):
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(files[0], destination)
    write_sha(baseline)


def compare(lock, baseline, output):
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(lock, output)
    write_sha(output)
    require(pins(output) == pins(baseline), 'consumer package tuples differ from tested native graph')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    for command in ('capture', 'finish', 'consume'):
        sub = commands.add_parser(command)
        for key in ('checkout', 'tree', 'run', 'attempt'):
            sub.add_argument('--' + key, required=True)
        sub.add_argument('--lock', required=True)
        if command == 'consume':
            sub.add_argument('--inputs', required=True)
            sub.add_argument('--baseline', required=True)
        else:
            sub.add_argument('--output', required=True)
            sub.add_argument('--family', choices=FAMILIES, required=True)
    sub = commands.add_parser('compare')
    for key in ('lock', 'baseline', 'output'):
        sub.add_argument('--' + key, required=True)
    args = parser.parse_args()
    if args.command == 'capture':
        capture(args.lock, args.output, context(args, family=True))
    elif args.command == 'finish':
        finish(args.lock, args.output, context(args, family=True))
    elif args.command == 'consume':
        consume(args.inputs, args.lock, args.baseline, context(args))
    else:
        compare(args.lock, args.baseline, args.output)
    print(json.dumps({'command': args.command, 'pins': 12, 'verified': args.command != 'capture'}))


if __name__ == '__main__':
    main()
