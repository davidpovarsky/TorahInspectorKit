#!/usr/bin/env python3
"""Run the existing affected tests; retain the original Swift Testing event ABI."""
from pathlib import Path
from collections import Counter
import hashlib
import json
import os
import signal
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / '.build/common-sdk-evidence'
PROFILE = ROOT / 'docs/validation/20261122-common-sdk/selection.json'
PARENTS = ('19d1b35397af4f10ae70cfb3f444c9de87383b53', '511454e49450cb2581ddf77f644146ff3e30dbef')

def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args])

def save(name, value):
    (OUT / name).write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')

def source_inputs():
    paths = git('ls-files', '-z', '--', 'Package.swift', 'Sources', 'Tests').split(b'\0')
    for flags in [('-o', '--exclude-standard'), ('-o', '-i', '--exclude-standard')]:
        assert not git('ls-files', *flags, '--', 'Sources', 'Tests').strip(), 'Unexpected source/test input'
    result = {}
    for item in paths:
        if not item:
            continue
        path = item.decode()
        data = (ROOT / path).read_bytes()
        assert data == git('show', 'HEAD:' + path), 'Working input changed: ' + path
        result[path] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
                        'blob': git('rev-parse', 'HEAD:' + path).decode().strip()}
    return result

def verify_events(path, profile):
    records = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    functions = {r['payload']['id']: r['payload'] for r in records
                 if r.get('kind') == 'test' and r['payload'].get('kind') == 'function'}
    events = [r['payload'] for r in records if r.get('kind') == 'event']
    assert sum(e['kind'] == 'runStarted' for e in events) == 1
    assert sum(e['kind'] == 'runEnded' for e in events) == 1
    assert not any(e['kind'] in {'issueRecorded', 'testSkipped', 'testCancelled', 'testCaseCancelled'} for e in events)
    started = Counter(e['testID'] for e in events if e['kind'] == 'testStarted' and e.get('testID') in functions)
    ended = Counter(e['testID'] for e in events if e['kind'] == 'testEnded' and e.get('testID') in functions)
    assert started == ended and all(n == 1 for n in started.values())
    assert len(started) == profile['expected_methods']
    names = {identity: functions[identity]['name'].split('(')[0] for identity in started}
    assert len(set(names.values())) == len(names)
    assert set(names.values()) == set(profile['methods'])
    case_started = Counter(e['testID'] for e in events if e['kind'] == 'testCaseStarted')
    case_ended = Counter(e['testID'] for e in events if e['kind'] == 'testCaseEnded')
    cases = []
    for identity, name in sorted(names.items(), key=lambda x: x[1]):
        expected = profile['methods'][name]
        assert functions[identity]['isParameterized'] == (expected > 1)
        assert case_started[identity] == case_ended[identity]
        # ABI versions may omit case events for nonparameterized functions.
        actual = case_ended[identity] or (1 if expected == 1 else 0)
        assert actual == expected, (name, expected, actual)
        cases.append({'id': identity, 'name': name, 'cases': actual,
                      'case_started': case_started[identity], 'case_ended': case_ended[identity]})
    assert sum(x['cases'] for x in cases) == profile['expected_cases']
    return {'methods': len(cases), 'cases': sum(x['cases'] for x in cases), 'identities': cases}

def main():
    OUT.mkdir(parents=True, exist_ok=False)
    profile = json.loads(PROFILE.read_text())
    head = git('rev-parse', 'HEAD').decode().strip()
    assert head == os.environ['GITHUB_SHA']
    for parent in PARENTS:
        subprocess.run(['git', '-C', str(ROOT), 'merge-base', '--is-ancestor', parent, head], check=True)
    before = source_inputs()
    save('source-before.json', before)
    save('selection.json', profile)
    save('identity.json', {'head': head, 'parents_required': PARENTS, 'run_id': os.environ['GITHUB_RUN_ID'],
         'run_attempt': os.environ['GITHUB_RUN_ATTEMPT'], 'ref': os.environ['GITHUB_REF'],
         'profile_sha256': hashlib.sha256(PROFILE.read_bytes()).hexdigest()})
    for name, command in [('swift-version', ['swift', '--version']), ('xcode-version', ['xcodebuild', '-version'])]:
        result = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=30)
        (OUT / (name + '.log')).write_bytes(result.stdout + result.stderr)
        assert result.returncode == 0
    command = ['swift', 'test', '--jobs', '2', '--filter', profile['filter'],
               '--event-stream-output-path', str(OUT / 'events.jsonl'), '--event-stream-version', '0',
               '--xunit-output', str(OUT / 'tests.xml')]
    save('command.json', {'argv': command, 'timeout_seconds': 1800})
    start = time.monotonic()
    with (OUT / 'swift-test.log').open('wb') as log:
        process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            exit_code = process.wait(timeout=1800)
            save('execution.json', {'exit_code': exit_code, 'seconds': time.monotonic() - start})
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait(timeout=10)
            save('execution.json', {'timeout': True, 'seconds': time.monotonic() - start})
            raise
    after = source_inputs()
    save('source-after.json', after)
    assert after == before
    assert exit_code == 0
    verified = verify_events(OUT / 'events.jsonl', profile)
    save('result.json', {'status': 'PASS_AFFECTED_ORIGINAL_PACKAGE_CASES', **verified,
        'source_bytes_unchanged': True, 'native_ui_acceptance': 'NOT_RUN', 'native_acl_runtime': 'NOT_RUN'})
    print(json.dumps({'head': head, 'methods': verified['methods'], 'cases': verified['cases']}))

if __name__ == '__main__':
    main()
