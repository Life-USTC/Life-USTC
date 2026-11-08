#!/usr/bin/env python3
"""Only exact run/attempt/device/locale-owned simulator creation and cleanup."""
import json
import os
import subprocess
import sys
from pathlib import Path


def owned_matches(devices, record, expected):
    assert record['name'] == expected
    identifier = record.get('udid')
    if identifier:
        matches = [device for device in devices if device['udid'] == identifier]
        assert not matches or (len(matches) == 1 and matches[0]['name'] == expected), 'Owned UUID/name mismatch'
    else:
        matches = [device for device in devices if device['name'] == expected]
        assert len(matches) <= 1, 'Ambiguous exact owned name; refusing deletion'
    return matches


def all_devices():
    groups = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', '--json']))['devices']
    return [device for group in groups.values() for device in group]


def main():
    mode = sys.argv[1]
    device, locale = os.environ['VISUAL_DEVICE'], os.environ['VISUAL_LOCALE']
    assert device in ['iPhone', 'iPad'] and locale in ['en', 'zh-Hans']
    name = f"Life-USTC visual {os.environ['GITHUB_RUN_ID']} {os.environ['GITHUB_RUN_ATTEMPT']} {device} {locale}"
    record_path = Path(os.environ['RUNNER_TEMP'], 'ios150-owned-simulator.json')
    results = Path(os.environ['GITHUB_WORKSPACE'], 'NativeVisualResults')
    results.mkdir(exist_ok=True)
    if mode == 'create':
        assert not record_path.exists(), 'Do not overwrite prior ownership record'
        record = {'name': name, 'device': device, 'locale': locale, 'udid': None}
        record_path.write_text(json.dumps(record, indent=2) + '\n')
        (results / 'owned-simulator.json').write_text(record_path.read_text())
        kind = 'iPad Pro 13-inch (M5)' if device == 'iPad' else 'iPhone 17'
        identifier = subprocess.check_output(['xcrun', 'simctl', 'create', name, kind], text=True).strip()
        record['udid'] = identifier
        record_path.write_text(json.dumps(record, indent=2) + '\n')
        (results / 'owned-simulator.json').write_text(record_path.read_text())
        with Path(os.environ['GITHUB_ENV']).open('a') as environment:
            environment.write(f'TEST_DEVICE_ID={identifier}\n')
        for arguments in [['boot', identifier], ['bootstatus', identifier, '-b'],
                          ['ui', identifier, 'appearance', 'light'],
                          ['status_bar', identifier, 'override', '--time', '9:41', '--batteryState', 'charged', '--batteryLevel', '100']]:
            subprocess.run(['xcrun', 'simctl', *arguments], check=True)
        print(json.dumps(record, indent=2))
    elif mode == 'cleanup':
        receipt = {'expectedName': name, 'deleted': False}
        try:
            if not record_path.exists():
                receipt['reason'] = 'No owned creation attempted'
            else:
                record = json.loads(record_path.read_text())
                matches = owned_matches(all_devices(), record, name)
                if matches:
                    identifier = matches[0]['udid']
                    subprocess.run(['xcrun', 'simctl', 'shutdown', identifier], check=False)
                    subprocess.run(['xcrun', 'simctl', 'delete', identifier], check=True)
                    assert not owned_matches(all_devices(), record, name), 'Exact owned simulator still exists after deletion'
                    receipt.update({'udid': identifier, 'deleted': True, 'verifiedAbsentAfterDeletion': True})
                else:
                    receipt.update({'udid': record.get('udid'), 'reason': 'No exact owned simulator remains'})
        except Exception as error:
            receipt['error'] = f'{type(error).__name__}: {error}'
            raise
        finally:
            (results / 'simulator-cleanup.json').write_text(json.dumps(receipt, indent=2) + '\n')
            print(json.dumps(receipt, indent=2))
    else:
        raise ValueError(mode)


if __name__ == '__main__':
    main()
