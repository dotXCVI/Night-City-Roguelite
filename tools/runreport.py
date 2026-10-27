#!/usr/bin/env python3
"""Night City Roguelite - run report.

Reads the mod's saved data (telemetry records and the text log) and prints a
floor-by-floor report of recent runs, or writes CSV files for charts.

    python3 tools/runreport.py <game folder or ScriptableServiceContainer.dat>
    python3 tools/runreport.py <...> --runs 3          # only the last 3 runs
    python3 tools/runreport.py <...> --csv out/        # runs.csv, floors.csv, picks.csv
    python3 tools/runreport.py <...> --log 80          # last 80 log lines
    python3 tools/runreport.py <...> --marks           # every bug mark with its snapshot

The data lives in
    <game>/red4ext/plugins/Codeware/Persistent/ScriptableServiceContainer.dat
and is written when the game unloads a world or saves, so quit through the menu.
Telemetry format (T1|<seq>|<run>|<kind>|k=v;...): see r6/scripts/NightCityRoguelite/Core/Telemetry.reds.
"""
import argparse
import csv
import os
import re
import sys
from collections import Counter, OrderedDict

DAT = os.path.join('red4ext', 'plugins', 'Codeware', 'Persistent', 'ScriptableServiceContainer.dat')


def load(path):
    if os.path.isdir(path):
        path = os.path.join(path, DAT)
    data = open(path, 'rb').read()
    strings = [m.group().decode('ascii', 'replace') for m in re.finditer(rb'[\x20-\x7e]{4,}', data)]
    # Stored names may carry a printable length byte in front, so search
    # rather than anchor. Both kinds are numbered: sort by the number.
    telemetry = []
    log = []
    for s in strings:
        m = re.search(r'T1\|(\d+)\|(.*)$', s)
        if m:
            telemetry.append((int(m.group(1)), m.group(2)))
            continue
        m = re.search(r'\[(\d+)\] (.*)$', s)
        if m:
            log.append((int(m.group(1)), m.group(2)))
    telemetry.sort()
    log.sort()
    return [line for _, line in telemetry], [line for _, line in log]


def parse(line):
    parts = line.split('|', 2)
    if len(parts) < 3:
        return None
    run_id, kind, rest = parts
    fields = OrderedDict()
    for item in rest.split(';'):
        if '=' in item:
            key, value = item.split('=', 1)
            fields[key] = value
    return run_id, kind, fields


def group_runs(telemetry):
    runs = OrderedDict()
    for line in telemetry:
        parsed = parse(line)
        if not parsed:
            continue
        run_id, kind, fields = parsed
        runs.setdefault(run_id, []).append((kind, fields))
    return runs


def summarize(run_id, records):
    start = next((f for k, f in records if k == 'RUN'), {})
    end = next((f for k, f in records if k == 'END'), None)
    floors = [f for k, f in records if k == 'FLOOR']
    picks = [f for k, f in records if k == 'PICK']
    builds = [f for k, f in records if k == 'BUILD']
    death = next((f for k, f in records if k == 'DEATH'), None)
    return start, end, floors, picks, builds, death


def print_run(run_id, records):
    start, end, floors, picks, builds, death = summarize(run_id, records)
    title = f"Run {run_id}: kit {start.get('kit', '?')}"
    if start.get('test') == '1':
        title += f" (TEST from floor {start.get('from')})"
    if end:
        title += f" - {end.get('result')} after {end.get('floors')} floors, {end.get('kills')} kills, {end.get('mins')} min"
    else:
        title += ' - unfinished'
    print('=' * len(title))
    print(title)
    print('=' * len(title))
    print(f"{'floor':>5}  {'door':<14} {'objective':<16} {'faction':<12} {'secs':>5} {'dmg%':>5} {'low%':>5}  outcome  picks")
    picks_by_depth = {}
    for p in picks:
        picks_by_depth.setdefault(p.get('depth'), []).append(p)
    for f in floors:
        depth = f.get('depth')
        door = f.get('door', '')
        if f.get('patron') not in (None, '', 'None'):
            door = f.get('patron')
        taken = [p.get('took', '') for p in picks_by_depth.get(depth, []) if p.get('screen') != 'doors' and p.get('took') != 'reroll']
        print(f"{depth:>5}  {door:<14.14} {f.get('obj', ''):<16.16} {f.get('faction', ''):<12.12} {f.get('secs', ''):>5} {f.get('dmg', ''):>5} {f.get('low', ''):>5}  {f.get('outcome', ''):<7}  {' | '.join(taken)}")
    if death:
        print(f"Killed on floor {death.get('depth')}, wave {death.get('wave')} by {death.get('by') or 'unknown'}")
    if builds:
        last = builds[-1]
        print(f"Last build: level {last.get('lvl')}, {last.get('attr')}, OS {last.get('os', '-')}, styles [{last.get('styles', '')}]")
        print(f"            mods [{last.get('mods', '')}], boons [{last.get('boons')}], overclock {last.get('overclock', 0)}, gig {last.get('gig') or '-'}")
    secs = [int(f['secs']) for f in floors if f.get('secs', '').isdigit()]
    if secs:
        print(f"Fighting time {sum(secs) // 60} min {sum(secs) % 60} s over {len(secs)} floors ({sum(secs) // len(secs)} s a floor)")
    kinds = Counter(p.get('took', '').split(':')[0] for p in picks
                    if p.get('screen') in ('reward', 'levelup', 'os', 'fixer') and p.get('took') not in ('reroll', 'skip'))
    if kinds:
        print('Picks by kind: ' + ', '.join(f'{k} {n}' for k, n in kinds.most_common()))
    ults = [f for k, f in records if k == 'ULT']
    if ults:
        print(f"Overdrive fired {len(ults)} times: " + ', '.join(f"floor {u.get('depth')} ({u.get('os')})" for u in ults))
    print()


def write_csv(runs, out):
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, 'runs.csv'), 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['run', 'kit', 'test', 'from', 'result', 'floors', 'kills', 'mins'])
        for run_id, records in runs.items():
            start, end, *_ = summarize(run_id, records)
            end = end or {}
            w.writerow([run_id, start.get('kit'), start.get('test'), start.get('from'), end.get('result', 'unfinished'), end.get('floors'), end.get('kills'), end.get('mins')])
    with open(os.path.join(out, 'floors.csv'), 'w', newline='') as fh:
        keys = ['depth', 'outcome', 'door', 'patron', 'obj', 'threat', 'arena', 'faction', 'waves', 'secs', 'dmg', 'low', 'heals', 'kills']
        w = csv.writer(fh)
        w.writerow(['run'] + keys)
        for run_id, records in runs.items():
            for kind, f in records:
                if kind == 'FLOOR':
                    w.writerow([run_id] + [f.get(k, '') for k in keys])
    with open(os.path.join(out, 'picks.csv'), 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['run', 'depth', 'screen', 'idx', 'took', 'offered'])
        for run_id, records in runs.items():
            offered = ''
            for kind, f in records:
                if kind == 'OFFER':
                    offered = f.get('cards', '')
                elif kind == 'PICK':
                    w.writerow([run_id, f.get('depth'), f.get('screen'), f.get('idx', ''), f.get('took', ''), f.get('offered', offered)])
    print(f'Wrote runs.csv, floors.csv and picks.csv to {out}')


def print_marks(log):
    showing = False
    for line in log:
        if line.startswith('===== BUG MARK'):
            showing = True
            print()
        elif showing and line.startswith('====='):
            showing = False
        if showing:
            print(line)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('path', help='game folder or ScriptableServiceContainer.dat')
    parser.add_argument('--runs', type=int, default=0, help='only the last N runs')
    parser.add_argument('--csv', help='write CSV files to this folder')
    parser.add_argument('--log', type=int, default=0, help='print the last N log lines')
    parser.add_argument('--marks', action='store_true', help='print every bug mark')
    args = parser.parse_args()

    telemetry, log = load(args.path)
    runs = group_runs(telemetry)
    if args.runs:
        runs = OrderedDict(list(runs.items())[-args.runs:])
    if args.csv:
        write_csv(runs, args.csv)
    elif args.log:
        print('\n'.join(log[-args.log:]))
    elif args.marks:
        print_marks(log)
    else:
        if not runs:
            print('No telemetry yet (it starts with the build that added it). The log has '
                  f'{len(log)} lines: try --log 100.')
        for run_id, records in runs.items():
            print_run(run_id, records)


if __name__ == '__main__':
    sys.exit(main())
