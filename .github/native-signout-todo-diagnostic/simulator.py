#!/usr/bin/env python3
"""Create/delete only this exact run/device/variant's simulator."""
import json
import os
import subprocess
import sys
from pathlib import Path

mode = sys.argv[1]
device = os.environ['DIAGNOSTIC_DEVICE']
variant = os.environ['DIAGNOSTIC_VARIANT']
assert device in ['iPhone', 'iPad']
assert variant in ['input-ab']
name = f"Life-USTC input API diagnostic {os.environ['GITHUB_RUN_ID']} {os.environ['GITHUB_RUN_ATTEMPT']} {device} {variant}"
record_path = Path(os.environ['RUNNER_TEMP'], 'ios140-input-ab-owned-simulator.json')
results = Path(os.environ['GITHUB_WORKSPACE'], 'InputAPIDiagnosticResults')
results.mkdir(exist_ok=True)
if mode == 'create':
    record = {'name': name, 'device': device, 'variant': variant, 'udid': None}
    record_path.write_text(json.dumps(record, indent=2) + '\n')  # Before create, including its cancellation window.
    kind = 'iPad Pro 13-inch (M5)' if device == 'iPad' else 'iPhone 17'
    identifier = subprocess.check_output(['xcrun', 'simctl', 'create', name, kind], text=True).strip()
    record['udid'] = identifier
    record_path.write_text(json.dumps(record, indent=2) + '\n')
    (results / 'owned-simulator.json').write_text(record_path.read_text())
    with Path(os.environ['GITHUB_ENV']).open('a') as environment:
        environment.write(f'TEST_DEVICE_ID={identifier}\n')
    subprocess.run(['xcrun', 'simctl', 'boot', identifier], check=True)
    subprocess.run(['xcrun', 'simctl', 'bootstatus', identifier, '-b'], check=True)
    subprocess.run(['xcrun', 'simctl', 'ui', identifier, 'appearance', 'light'], check=True)
    print(json.dumps(record, indent=2))
elif mode == 'cleanup':
    receipt = {'expectedName': name, 'deleted': False}
    try:
        if not record_path.exists():
            receipt['reason'] = 'No owned creation was attempted'
        else:
            record = json.loads(record_path.read_text())
            assert record['name'] == name
            groups = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', '--json']))['devices']
            devices = [item for group in groups.values() for item in group]
            identifier = record.get('udid') or os.environ.get('TEST_DEVICE_ID', '')
            if identifier:
                matches = [item for item in devices if item['udid'] == identifier]
                assert not matches or (len(matches) == 1 and matches[0]['name'] == name)
            else:
                matches = [item for item in devices if item['name'] == name]
                assert len(matches) <= 1, 'Ambiguous exact owned simulator name; refusing deletion'
                identifier = matches[0]['udid'] if matches else ''
            if identifier and matches:
                subprocess.run(['xcrun', 'simctl', 'shutdown', identifier], check=False)
                subprocess.run(['xcrun', 'simctl', 'delete', identifier], check=True)
                remaining = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', '--json']))['devices']
                assert not any(item['udid'] == identifier for group in remaining.values() for item in group), 'Owned simulator still present'
                receipt.update({'udid': identifier, 'deleted': True, 'verifiedAbsentAfterDeletion': True})
            else:
                receipt['reason'] = 'No exact owned simulator remains'
    except Exception as error:
        receipt['error'] = f'{type(error).__name__}: {error}'
        raise
    finally:
        (results / 'simulator-cleanup.json').write_text(json.dumps(receipt, indent=2) + '\n')
        print(json.dumps(receipt, indent=2))
else:
    raise ValueError(mode)
