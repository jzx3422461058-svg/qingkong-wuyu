"""Verify GUI-created records in the isolated QA workspace; never modify user data."""
import base64
import hashlib
import json
from pathlib import Path

path = Path('/tmp/qingyu-ui-tests/workspace.json')
envelope = json.loads(path.read_text())
payload = base64.b64decode(envelope['payload'])
assert hashlib.sha256(payload).hexdigest() == envelope['checksum']
data = json.loads(payload)
assert any(c['name'] == 'GUI course verified' and c['location'] == 'Room 308' for c in data['courses'])
assert any(a['title'] == 'GUI activity verified' and a['location'] == 'Library Hall' for a in data['activities'])
assert any(g['title'] == 'GUI goal verified' for g in data['goals'])
assert any(s['name'] == 'GUI training verified' for s in data['trainingSchedule'])
imports = [c for c in data['courses'] if c['name'] == 'GUI CSV import']
assert len(imports) == 1 and imports[0]['pattern'] == '双周' and imports[0]['location'] == 'Room 507'
assert list((path.parent / 'Backups').glob('manual-*.campusbackup'))
print('PASS: GUI-created course, activity, goal, workout arrangement, CSV import, manual backup, checksum')
