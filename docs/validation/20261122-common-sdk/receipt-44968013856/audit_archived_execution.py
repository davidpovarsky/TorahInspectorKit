"""Independently inspect the retained failed-CI artifact; never rerun Swift."""
from collections import Counter
from pathlib import Path
import hashlib
import json
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
EVIDENCE = ROOT / 'evidence'


def read(name):
    return json.loads((EVIDENCE / name).read_bytes())


def main():
    archive = ROOT / 'artifact-original.zip'
    assert archive.stat().st_size == 16140
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == 'c4935cf29a0b9eeb365a806ef5b68969c9395e66cef411002c809d1847eae0cc'
    identity = read('identity.json')
    assert identity['head'] == '23db0f84e88d9ee9c7053c49de86903fc7bb5785'
    assert identity['run_id'] == '44968013856' and identity['run_attempt'] == '1'
    execution = read('execution.json')
    assert execution['exit_code'] == 0 and 'timeout' not in execution
    before, after = read('source-before.json'), read('source-after.json')
    committed = json.loads((ROOT / 'COMMITTED_SOURCE_VERIFICATION.json').read_bytes())
    assert before == after == committed['git_committed_sources']
    assert committed['archive_manifest_matches_exact_commit'] and committed['profile_identity'] == 'PASS'
    profile = read('selection.json')
    assert (profile['expected_methods'], profile['expected_cases']) == (30, 32)
    rows = [json.loads(line) for line in (EVIDENCE / 'events.jsonl').read_text().splitlines() if line.strip()]
    assert all(row['version'] == 0 and row['kind'] in {'test', 'event'} for row in rows)
    declarations = {}
    for row in rows:
        if row['kind'] != 'test':
            continue
        test = row['payload']
        assert test['id'] not in declarations and test['kind'] in {'suite', 'function'}
        declarations[test['id']] = test
    functions = {k: v for k, v in declarations.items() if v['kind'] == 'function'}
    assert len(functions) == 30
    active, runs = None, []
    allowed_events = {'runStarted', 'runEnded', 'testStarted', 'testEnded', 'testCaseStarted', 'testCaseEnded'}
    for index, row in enumerate(rows, 1):
        if row['kind'] != 'event':
            continue
        event = row['payload']
        # An issue, skip, cancellation, or unknown terminal can never be ignored.
        assert event['kind'] in allowed_events, event
        if event['kind'] == 'runStarted':
            assert active is None
            active = {'start_row': index, 'start_event': event, 'events': []}
        elif event['kind'] == 'runEnded':
            assert active is not None
            assert any(m['symbol'] == 'pass' for m in event.get('messages', []))
            active['end_row'], active['end_event'] = index, event
            runs.append(active)
            active = None
        else:
            assert active is not None
            assert event['testID'] in declarations
            active['events'].append(event)
    assert active is None and len(runs) == 2
    expected_targets = {'TorahInspectorUITests': (4, 5), 'TorahInspectorCoreTests': (26, 27)}
    methods, run_reports, all_started = [], [], Counter()
    for run in runs:
        events = run['events']
        starts = Counter(e['testID'] for e in events if e['kind'] == 'testStarted')
        ends = Counter(e['testID'] for e in events if e['kind'] == 'testEnded')
        assert starts == ends and all(n == 1 for n in starts.values())
        # ABI v0 omits human-readable messages on nonparameterized testEnded.
        # The ordered terminal pairs, zero issues, complete passing run and the
        # exact zero-failure JUnit identities below provide their outcome proof.
        assert all(not e.get('messages') or any(m['symbol'] == 'pass' for m in e['messages'])
                   for e in events if e['kind'] == 'testEnded')
        live_tests, live_cases = set(), set()
        for event in events:
            key, kind = event['testID'], event['kind']
            if kind == 'testStarted':
                assert key not in live_tests
                live_tests.add(key)
            elif kind == 'testEnded':
                assert key in live_tests and not any(t == key for t, _ in live_cases)
                live_tests.remove(key)
            elif kind == 'testCaseStarted':
                case_key = (key, event['_testCase']['id'])
                assert key in live_tests and case_key not in live_cases
                live_cases.add(case_key)
            elif kind == 'testCaseEnded':
                case_key = (key, event['_testCase']['id'])
                assert key in live_tests and case_key in live_cases
                live_cases.remove(case_key)
        assert not live_tests and not live_cases
        all_started.update(starts)
        targets = {k.split('/')[0].split('.')[0] for k in starts}
        assert len(targets) == 1
        target = targets.pop()
        assert target in expected_targets and target not in {x['target'] for x in run_reports}
        case_starts = Counter((e['testID'], e['_testCase']['id']) for e in events if e['kind'] == 'testCaseStarted')
        case_ends = Counter((e['testID'], e['_testCase']['id']) for e in events if e['kind'] == 'testCaseEnded')
        assert case_starts == case_ends and all(n == 1 for n in case_starts.values())
        for event in events:
            if event['kind'] == 'testCaseStarted':
                declared = {case['id'] for case in functions[event['testID']]['_testCases']}
                assert event['_testCase']['id'] in declared
        target_methods = []
        for test_id in sorted(k for k in starts if k in functions):
            test = functions[test_id]
            name = test['name'].split('(')[0]
            expected = profile['methods'][name]
            assert test['isParameterized'] == (expected > 1)
            if test['isParameterized']:
                declared = {c['id'] for c in test['_testCases']}
                observed = {case for identity, case in case_ends if identity == test_id}
                assert observed == declared and len(observed) == expected
                cases = [{'id': c['id'], 'display_name': c['displayName'], 'started': 1, 'ended': 1}
                         for c in test['_testCases']]
            else:
                assert not any(identity == test_id for identity, _ in case_ends)
                assert expected == 1
                cases = [{'nonparameterized_function_start_end': True, 'started': 1, 'ended': 1}]
            result = {'id': test_id, 'name': name, 'target': target, 'passed_cases': len(cases), 'cases': cases}
            target_methods.append(result)
            methods.append(result)
        counts = (len(target_methods), sum(x['passed_cases'] for x in target_methods))
        assert counts == expected_targets[target]
        run_reports.append({'target': target, 'methods': counts[0], 'cases': counts[1],
            'run_started_row': run['start_row'], 'run_ended_row': run['end_row'],
            'run_started': run['start_event'], 'run_ended': run['end_event'],
            'suites_started_and_ended_once': len(starts) - counts[0]})
    assert set(all_started) == set(declarations) and all(n == 1 for n in all_started.values())
    assert len(methods) == 30 and sum(m['passed_cases'] for m in methods) == 32
    assert {m['name'] for m in methods} == set(profile['methods'])
    assert len({m['name'] for m in methods}) == 30
    junit = ET.parse(EVIDENCE / 'tests-swift-testing.xml').getroot()
    assert sum(int(s.attrib['tests']) for s in junit) == 30
    assert all(int(s.attrib[k]) == 0 for s in junit for k in ('errors', 'failures', 'skipped'))
    junit_names = Counter(c.attrib['name'].split('(')[0] for s in junit for c in s)
    assert set(junit_names) == set(profile['methods']) and all(n == 1 for n in junit_names.values())
    result = {
        'status': 'ARCHIVED_SWIFT_EXECUTION_VERIFIED_30_METHODS_32_CASES',
        'github_run_status': 'completed', 'github_run_conclusion': 'failure',
        'github_run_url': 'https://github.com/davidpovarsky/TorahInspectorKit/actions/runs/44968013856',
        'exact_failure': 'scripts/CI/verify-common-sdk.py:43 asserts exactly one runStarted; actual original Swift stream contains two complete target runs',
        'source_sha': identity['head'], 'swift_exit_code': 0, 'swift_seconds': execution['seconds'],
        'methods': 30, 'cases': 32, 'runs': run_reports, 'identities': methods,
        'issue_skip_cancellation_events': 0,
        'all_method_suite_and_parameter_case_starts_pair_once': True,
        'source_before_after_and_git_raw_commit_equal': True, 'source_input_files': len(before),
        'artifact_id': 14732457038, 'artifact_bytes': archive.stat().st_size,
        'artifact_sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
        'member_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(EVIDENCE.iterdir()) if p.is_file()},
        'next_action': 'Correct the reporting parser and replay this unchanged authenticated stream; no repeated Swift execution needed',
        'excluded': ['iOS/iPad Native UI acceptance', 'ACL native runtime', 'full package unselected tests', 'Anytype Host native Save/reopen']
    }
    (ROOT / 'INDEPENDENT_AUDIT.json').write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print(json.dumps({k: v for k, v in result.items() if k not in {'runs', 'identities', 'member_sha256'}}))


if __name__ == '__main__':
    main()
