import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "package_resolution.py"
SPEC = importlib.util.spec_from_file_location("package_resolution", SCRIPT)
resolution = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(resolution)
capture = resolution.capture
compare = resolution.compare
consume = resolution.consume
finish = resolution.finish
pins = resolution.pins


class PackageResolutionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.lock = self.root / 'input.resolved'
        self.lock.write_text(json.dumps({'pins': [
            {'identity': f'package-{i}', 'location': f'https://example.invalid/{i}',
             'state': {'revision': f'{i:040x}', 'version': '1.0.0'}} for i in range(12)
        ]}))
        self.expected = {'checkout': 'a' * 40, 'tree': 'b' * 40, 'run': '42', 'attempt': '1'}
        self.inputs = self.root / 'inputs'
        for family in ('iPhone', 'iPad'):
            folder = self.inputs / f'native-packages-42-1-{family}'
            expected = dict(self.expected, family=family)
            capture(self.lock, folder, expected)
            finish(self.lock, folder, expected)
        self.phone = self.inputs / 'native-packages-42-1-iPhone'

    def accept(self, expected=None):
        consume(self.inputs, self.root / 'project/Package.resolved', self.root / 'native.resolved', expected or self.expected)

    def alter_source(self, key, value):
        path = self.phone / 'package-source.json'
        data = json.loads(path.read_text()); data[key] = value; path.write_text(json.dumps(data))

    def test_matching_graph_is_consumed_and_compared(self):
        self.accept()
        compare(self.lock, self.root / 'native.resolved', self.root / 'after.resolved')
        self.assertEqual(pins(self.lock), pins(self.root / 'after.resolved'))

    def test_semantic_graph_survives_formatting_changes(self):
        self.lock.write_text(json.dumps(json.loads(self.lock.read_text()), indent=2))
        folder = self.inputs / 'native-packages-42-1-iPad'
        capture(self.lock, folder, dict(self.expected, family='iPad'))
        finish(self.lock, folder, dict(self.expected, family='iPad'))
        self.accept()

    def test_wrong_run_is_rejected(self):
        self.alter_source('run', '41')
        with self.assertRaises(ValueError): self.accept()

    def test_wrong_attempt_is_rejected(self):
        self.alter_source('attempt', '2')
        with self.assertRaises(ValueError): self.accept()

    def test_wrong_tree_is_rejected(self):
        self.alter_source('tree', 'c' * 40)
        with self.assertRaises(ValueError): self.accept()

    def test_wrong_checkout_is_rejected(self):
        self.alter_source('checkout', 'd' * 40)
        with self.assertRaises(ValueError): self.accept()

    def test_wrong_family_is_rejected(self):
        self.alter_source('family', 'iPad')
        with self.assertRaises(ValueError): self.accept()

    def test_duplicate_pin_identity_is_rejected(self):
        data = json.loads(self.lock.read_text()); data['pins'][1] = data['pins'][0]
        self.lock.write_text(json.dumps(data))
        with self.assertRaises(ValueError): pins(self.lock)

    def test_raw_hash_mismatch_is_rejected(self):
        with (self.phone / 'Package.resolved').open('a') as stream: stream.write(' ')
        with self.assertRaises(ValueError): self.accept()

    def test_unverified_native_is_rejected(self):
        self.alter_source('verified', False)
        with self.assertRaises(ValueError): self.accept()

    def test_other_family_graph_is_rejected(self):
        data = json.loads(self.lock.read_text()); data['pins'][0]['state']['revision'] = 'e' * 40
        self.lock.write_text(json.dumps(data))
        folder = self.inputs / 'native-packages-42-1-iPad'
        capture(self.lock, folder, dict(self.expected, family='iPad'))
        finish(self.lock, folder, dict(self.expected, family='iPad'))
        with self.assertRaises(ValueError): self.accept()

    def test_native_resolution_change_is_rejected(self):
        data = json.loads(self.lock.read_text()); data['pins'][0]['state']['revision'] = 'f' * 40
        self.lock.write_text(json.dumps(data))
        with self.assertRaises(ValueError): finish(self.lock, self.phone, dict(self.expected, family='iPhone'))
        self.assertEqual(self.lock.read_bytes(), (self.phone / 'Package.resolved').read_bytes())
        self.assertIs(json.loads((self.phone / 'package-source.json').read_text())['verified'], False)

    def test_missing_family_is_rejected(self):
        import shutil
        shutil.rmtree(self.inputs / 'native-packages-42-1-iPad')
        with self.assertRaises(ValueError): self.accept()

    def test_consumer_drift_is_rejected(self):
        self.accept()
        data = json.loads(self.lock.read_text()); data['pins'][0]['state']['version'] = '2.0.0'
        self.lock.write_text(json.dumps(data))
        with self.assertRaises(ValueError): compare(self.lock, self.root / 'native.resolved', self.root / 'after.resolved')
        self.assertEqual(self.lock.read_bytes(), (self.root / 'after.resolved').read_bytes())


if __name__ == '__main__':
    unittest.main()
