#!/usr/bin/env python3
"""Night City Roguelite - run report.

Reads the mod's saved data (telemetry records and the text log) from one or
more players and prints what happened: run by run, or summed up across runs.

    python3 tools/runreport.py <game folder or .dat> [more ...]
    python3 tools/runreport.py jon.dat me.dat --summary          # everything, summed up
    python3 tools/runreport.py jon.dat me.dat --html report.html # the same as a page
    python3 tools/runreport.py <...> --effects                   # fires and damage per effect
    python3 tools/runreport.py <...> --csv out/                  # runs, floors, picks
    python3 tools/runreport.py <...> --log 80                    # last 80 log lines
    python3 tools/runreport.py <...> --marks                     # every bug mark with its snapshot
    python3 tools/runreport.py <...> --scout                     # arena scout results, best first

Filters (any mode): --kit Brawler, --who Jon, --ver v0.0.19, --last 5 (runs),
--tests (include test runs, left out by default).

Each file is a player: named after the file ("jon.dat" -> jon), the folder a
bare ScriptableServiceContainer.dat sits in, or --as Jon,Me in order.

The data lives in
    <game>/red4ext/plugins/Codeware/Persistent/ScriptableServiceContainer.dat
and is written when the game unloads a world, so quit through the menu: a
crash loses the session. Telemetry format (T1|<seq>|<run>|<kind>|k=v;...):
see r6/scripts/NightCityRoguelite/Core/Telemetry.reds.
"""
import argparse
import csv
import html
import os
import re
import statistics
import sys
from collections import Counter, OrderedDict, defaultdict

DAT = os.path.join('red4ext', 'plugins', 'Codeware', 'Persistent', 'ScriptableServiceContainer.dat')
FLOORS_PER_ACT = 6
WEAPON_EFFECTS = {'TracerRounds', 'Payload', 'ThunderRounds', 'HotBarrel', 'KineticRounds', 'LuckyRound'}


# --- Reading ---------------------------------------------------------------------------------

def load(path):
    """(telemetry lines, log lines) from a game folder or a .dat file."""
    if os.path.isdir(path):
        path = os.path.join(path, DAT)
    data = open(path, 'rb').read()
    # Saved names end with a NUL; one may carry a stray length byte in front,
    # so search rather than anchor. Both kinds are numbered: sort by the
    # number. A long line is saved in pieces (T1+|<seq>| and [<seq>]+ carry
    # on <seq>), joined as bytes so a character cut between two pieces
    # comes back whole.
    telemetry = {}
    log = {}
    for chunk in data.split(b'\x00'):
        m = re.search(rb'T1(\+?)\|(\d+)\|(.*)$', chunk, re.S)
        if m:
            seq = int(m.group(2))
            if m.group(1):
                if seq in telemetry:
                    telemetry[seq] += m.group(3)
            else:
                telemetry[seq] = m.group(3)
            continue
        m = re.search(rb'\[(\d+)\](\+?) (.*)$', chunk, re.S)
        if m:
            seq = int(m.group(1))
            if m.group(2):
                if seq in log:
                    log[seq] += m.group(3)
            else:
                log[seq] = m.group(3)
    decode = lambda store: [text.decode('utf-8', 'replace') for _, text in sorted(store.items())]
    return decode(telemetry), decode(log)


def parse(line):
    """(run id, kind, fields) of a telemetry line."""
    parts = line.split('|', 2)
    if len(parts) < 3:
        return None
    run_id, kind, rest = parts
    fields = OrderedDict()
    for item in rest.split(';'):
        if '=' in item:
            key, value = item.split('=', 1)
            if key == 'dmg' and key in fields and 'dealt' not in fields:
                # Builds before "dealt" wrote damage dealt as a first "dmg".
                fields['dealt'] = fields[key]
            fields[key] = value
    return run_id, kind, fields


def number(value, default=0):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def mean(values, fmt='{:.0f}'):
    return fmt.format(statistics.mean(values)) if values else '-'


class Run:
    def __init__(self, run_id, who):
        self.id = run_id
        self.who = who
        self.records = []

    def all(self, kind):
        return [f for k, f in self.records if k == kind]

    def first(self, kind):
        return next((f for k, f in self.records if k == kind), None)

    @property
    def start(self):
        return self.first('RUN') or {}

    @property
    def end(self):
        return self.first('END')

    @property
    def kit(self):
        return self.start.get('kit', '?')

    @property
    def test(self):
        return self.start.get('test') == '1'

    @property
    def ver(self):
        return self.start.get('ver', 'old')

    @property
    def floors(self):
        return self.all('FLOOR')

    @property
    def result(self):
        return self.end.get('result', '?') if self.end else 'unfinished'

    @property
    def depth(self):
        """The floor the run got to."""
        return max((number(f.get('depth')) for _, f in self.records if f.get('depth')), default=0)


class Player:
    def __init__(self, who, telemetry, log):
        self.who = who
        self.log = log
        self.runs = OrderedDict()
        self.meta = []
        for line in telemetry:
            parsed = parse(line)
            if not parsed:
                continue
            run_id, kind, fields = parsed
            if run_id == '0' and kind in ('META', 'SESSION', 'SCOUT'):
                self.meta.append((kind, fields))
                continue
            self.runs.setdefault(run_id, Run(run_id, who)).records.append((kind, fields))


def player_name(path, given):
    if given:
        return given
    base = os.path.basename(os.path.normpath(path))
    if os.path.isdir(path):
        return base
    stem = os.path.splitext(base)[0]
    if stem.lower().endswith('scriptableservicecontainer'):
        return os.path.basename(os.path.dirname(os.path.abspath(path))) or 'player'
    return stem


def select(players, args):
    runs = []
    for player in players:
        if args.who and player.who.lower() != args.who.lower():
            continue
        for run in player.runs.values():
            if run.test and not args.tests:
                continue
            if args.kit and run.kit.lower() != args.kit.lower():
                continue
            if args.ver and run.ver != args.ver:
                continue
            runs.append(run)
    if args.last:
        runs = runs[-args.last:]
    return runs


# --- One run ---------------------------------------------------------------------------------

def held(floor):
    """The effects held in a fight: what it logged as held, plus anything that fired."""
    ids = {h.rstrip('+') for h in floor.get('held', '').split(',') if h}
    return ids | {e.split(':')[0] for e in floor.get('fx', '').split(',') if e}


def effect_totals(floors):
    """{effect: [fires, damage, floors present]} over FLOOR records; an effect
    held but never fired counts its floors with no fires."""
    totals = {}
    for f in floors:
        for entry in filter(None, f.get('fx', '').split(',')):
            parts = entry.split(':')
            if len(parts) != 3 or not parts[1].isdigit() or not parts[2].isdigit():
                continue
            t = totals.setdefault(parts[0], [0, 0, 0])
            t[0] += int(parts[1])
            t[1] += int(parts[2])
        for name in held(f):
            totals.setdefault(name, [0, 0, 0])[2] += 1
    return totals


def print_run(run):
    start = run.start
    title = f"Run {run.id} ({run.who}): kit {run.kit}, {run.ver}"
    if run.test:
        title += f" (TEST from floor {start.get('from')})"
    end = run.end
    if end:
        title += f" - {end.get('result')} after {end.get('floors')} floors, {end.get('kills')} kills"
        if end.get('mins'):
            title += f", {end.get('mins')} min"
    else:
        title += ' - unfinished'
    print('=' * len(title))
    print(title)
    print('=' * len(title))
    if start.get('patrons'):
        print(f"Patrons: {start['patrons']}")
    if start.get('upgrades'):
        print(f"Upgrades: {start['upgrades']}")
    print(f"{'floor':>5}  {'door':<14} {'objective':<16} {'faction':<12} {'secs':>5} {'dmg%':>5} {'low%':>5}  outcome  picks")
    picks_by_depth = defaultdict(list)
    for p in run.all('PICK'):
        picks_by_depth[p.get('depth')].append(p)
    for f in run.floors:
        depth = f.get('depth')
        door = f.get('patron') if f.get('patron') not in (None, '', 'None') else f.get('door', '')
        taken = [p.get('took', '') for p in picks_by_depth.get(depth, []) if p.get('screen') != 'doors' and p.get('took') != 'reroll']
        print(f"{depth:>5}  {door:<14.14} {f.get('obj', ''):<16.16} {f.get('faction', ''):<12.12} {f.get('secs', ''):>5} "
              f"{f.get('dmg', ''):>5} {f.get('low', ''):>5}  {f.get('outcome', ''):<7}  {' | '.join(taken)}")
    death = run.first('DEATH')
    if death:
        print(f"Killed on floor {death.get('depth')}, wave {death.get('wave')} by {death.get('by') or 'unknown'}")
    if end and end.get('result') == 'quit':
        print(f"Quit on floor {end.get('depth')} ({end.get('state')}, wave {end.get('wave')})")
    builds = run.all('BUILD')
    if builds:
        last = builds[-1]
        print(f"Last build: level {last.get('lvl')}, {last.get('attr')}, OS {last.get('os', '-')}, styles [{last.get('styles', '')}]")
        print(f"            mods [{last.get('mods', '')}], boons [{last.get('boons')}], overclock {last.get('overclock', 0)}, gig {last.get('gig') or '-'}")
    secs = [number(f.get('secs')) for f in run.floors if f.get('secs')]
    if secs:
        print(f"Fighting time {sum(secs) // 60} min {sum(secs) % 60} s over {len(secs)} floors ({sum(secs) // len(secs)} s a floor)")
    kinds = Counter(p.get('took', '').split(':')[0] for p in run.all('PICK')
                    if p.get('screen') in ('reward', 'levelup', 'os', 'fixer') and p.get('took') not in ('reroll', 'skip'))
    if kinds:
        print('Picks by kind: ' + ', '.join(f'{k or "?"} {n}' for k, n in kinds.most_common()))
    ledger = effect_totals(run.floors)
    if ledger:
        top = sorted(ledger.items(), key=lambda kv: -kv[1][1])
        print('Effects (fires, damage): ' + ', '.join(f"{name} {fires}/{dmg}" for name, (fires, dmg, _) in top))
    dealt = [number(f.get('dealt')) for f in run.floors if f.get('dealt')]
    if dealt:
        print(f"Damage dealt {sum(dealt)} ({sum(dealt) // len(dealt)} a floor)")
    hits = [number(f.get('hits')) for f in run.floors if f.get('hits')]
    if hits:
        print(f"Main weapon hits {sum(hits)} ({sum(hits) // len(hits)} a floor)")
    for f in run.all('MARK'):
        where = ', '.join(f"{key} {f[key]}" for key in ('arena', 'at', 'wave', 'obj', 'markers') if f.get(key))
        print(f"Bug mark #{f.get('n')} on floor {f.get('depth')} ({f.get('state') or '?'}){': ' + where if where else ''}")
    ults = run.all('ULT')
    if ults:
        print(f"Overdrive fired {len(ults)} times: " + ', '.join(f"floor {u.get('depth')} ({u.get('os')})" for u in ults))
    print()


# --- Across runs -----------------------------------------------------------------------------

def act_of(depth):
    return min(3, max(1, (number(depth) - 1) // FLOORS_PER_ACT + 1))


def card_parts(card):
    """('Effect', 'Kill Switch') from 'Effect:Kill Switch:4' (older builds left the kind empty)."""
    parts = card.split(':')
    if len(parts) >= 3:
        return parts[0], ':'.join(parts[1:-1])
    return '', card


def rate(part, whole):
    return f"{100 * part / whole:.0f}%" if whole else '-'


def summary(runs, players):
    """The head line and titled tables: [(title, note, headers, rows)]."""
    tables = []
    floors = [(r, f) for r in runs for f in r.floors]

    # Runs by kit.
    rows = []
    for kit in sorted({r.kit for r in runs}):
        kr = [r for r in runs if r.kit == kit]
        results = Counter(r.result for r in kr)
        mins = [number(r.end.get('mins')) for r in kr if r.end and r.end.get('mins')]
        rows.append([kit, len(kr), results.get('won', 0), mean([r.depth for r in kr], '{:.1f}'), max((r.depth for r in kr), default=0),
                     ', '.join(f'{k} {n}' for k, n in results.most_common() if k != 'won') or '-', mean(mins)])
    tables.append(('Runs by kit', 'Depth is the floor a run reached. Quit and crashed runs ended without a death.',
                   ['kit', 'runs', 'won', 'avg depth', 'best', 'other endings', 'avg min'], rows))

    # Where and how runs end.
    deaths = [(r, d) for r in runs for d in r.all('DEATH')]
    by_floor = Counter(number(d.get('depth')) for _, d in deaths)
    rows = [[floor, n, ', '.join(sorted({r.kit for r, d in deaths if number(d.get('depth')) == floor}))]
            for floor, n in sorted(by_floor.items())]
    tables.append(('Deaths by floor', 'Floors 6, 12 and 18 are bosses.', ['floor', 'deaths', 'kits'], rows))
    killers = Counter(re.sub(r'^.*?\(', '(', d.get('by', '')).strip('()') or '?' for _, d in deaths)
    tables.append(('What killed V', "The last enemy to land a hit: what it is, and its affixes.", ['killer', 'deaths'],
                   [[k, n] for k, n in killers.most_common(12)]))

    # Fights by act.
    rows = []
    for act in (1, 2, 3):
        af = [f for _, f in floors if act_of(f.get('depth')) == act]
        if not af:
            continue
        waves = [number(s) for f in af for s in filter(None, f.get('wavesecs', '').split(','))]
        rows.append([act, len(af), mean([number(f.get('secs')) for f in af if f.get('secs')]), mean(waves),
                     mean([number(f.get('dmg')) for f in af if f.get('dmg')], '{:.0f}%'),
                     mean([number(f.get('low')) for f in af if f.get('low')], '{:.0f}%'),
                     sum(1 for f in af if f.get('outcome') == 'lost')])
    tables.append(('Fights by act', 'Damage taken is a share of max health over the fight; lowest is the lowest health reached.',
                   ['act', 'fights', 'avg secs', 'avg wave secs', 'damage taken', 'lowest health', 'lost'], rows))

    # What hurt V.
    hurt = Counter()
    for _, f in floors:
        for entry in filter(None, f.get('hurt', '').split(',')):
            kind, _, dmg = entry.rpartition(':')
            hurt[kind] += number(dmg)
    total = sum(hurt.values())
    tables.append(('What hurts V', "Damage V took by the kind of enemy dealing it (each fight's top three).",
                   ['enemy', 'damage', 'share'], [[k, v, rate(v, total)] for k, v in hurt.most_common(12)]))

    # Arenas and objectives.
    marks = Counter(f.get('arena') for r in runs for f in r.all('MARK') if f.get('arena'))
    rows = []
    for arena in sorted({f.get('arena') for _, f in floors if f.get('arena')}):
        af = [f for _, f in floors if f.get('arena') == arena]
        rows.append([arena, len(af), sum(1 for f in af if f.get('outcome') == 'lost'),
                     mean([number(f.get('secs')) for f in af if f.get('secs')]), marks.get(arena, 0)])
    tables.append(('Arenas', '', ['arena', 'fights', 'lost', 'avg secs', 'bug marks'], rows))
    rows = []
    for obj in sorted({f.get('obj') for _, f in floors if f.get('obj')}):
        of = [f for _, f in floors if f.get('obj') == obj]
        rows.append([obj, len(of), sum(1 for f in of if f.get('outcome') == 'lost'), mean([number(f.get('secs')) for f in of if f.get('secs')])])
    tables.append(('Objectives', '', ['objective', 'fights', 'lost', 'avg secs'], rows))

    # Cards: how often each is offered and taken.
    offered, taken, kinds = Counter(), Counter(), {}
    for r in runs:
        for f in r.all('OFFER'):
            for card in filter(None, f.get('cards', '').split(',')):
                kind, title = card_parts(card)
                offered[title] += 1
                kinds[title] = kind or kinds.get(title, '')
        for p in r.all('PICK'):
            if p.get('screen') in ('reward', 'levelup', 'os', 'fixer', 'gig') and p.get('took') not in (None, 'reroll', 'skip'):
                taken[card_parts(p['took'])[1]] += 1
    rows = [[k, kinds.get(k, ''), offered[k], taken.get(k, 0), rate(taken.get(k, 0), offered[k])]
            for k in sorted(offered, key=lambda k: (-taken.get(k, 0) / offered[k], -offered[k])) if offered[k] >= 2]
    tables.append(('Cards', 'Every card offered at least twice, by how often it was taken. A rerolled screen counts as offered.',
                   ['card', 'kind', 'offered', 'taken', 'rate'], rows))

    # Doors.
    door_offered, door_taken = Counter(), Counter()
    for r in runs:
        for p in r.all('PICK'):
            if p.get('screen') != 'doors' or p.get('took') == 'reroll' or not p.get('offered'):
                continue
            doors = [re.split(r'[:+]', d)[0] for d in p['offered'].split(',')]
            for d in doors:
                door_offered[d] += 1
            idx = number(p.get('idx'), -1)
            if 0 <= idx < len(doors):
                door_taken[doors[idx]] += 1
    rows = [[d, door_offered[d], door_taken.get(d, 0), rate(door_taken.get(d, 0), door_offered[d])]
            for d in sorted(door_offered, key=lambda d: -door_taken.get(d, 0) / door_offered[d])]
    tables.append(('Doors', 'How often each door was picked when it was on offer.', ['door', 'offered', 'taken', 'rate'], rows))

    # Effects.
    totals = effect_totals([f for _, f in floors])
    held_in = Counter(name for r in runs for name in effect_totals(r.floors))
    tables.append(('Effects', 'What each effect added: its own blasts, strikes and statuses, and the extra from its multipliers.',
                   ['effect', 'runs', 'floors', 'fires', 'damage', 'dmg/floor'],
                   [[name, held_in[name], present, fires, dmg, dmg // max(present, 1)]
                    for name, (fires, dmg, present) in sorted(totals.items(), key=lambda kv: -kv[1][1])]))
    rows = []
    for name in sorted(WEAPON_EFFECTS & set(totals)):
        present = [f for _, f in floors if name in held(f)]
        hits = sum(number(f.get('hits')) for f in present)
        fires = totals[name][0]
        rows.append([name, len(present), hits or '-', fires, f"1 in {hits // fires}" if fires and hits else ('never' if hits else '-')])
    tables.append(('Weapon effects per hit', "Fires against the main weapon's hits on the floors that had the effect "
                   "(hits are logged from this build on).", ['effect', 'floors', 'main hits', 'fires', 'rate'], rows))

    # Decision time.
    think = defaultdict(list)
    for r in runs:
        for p in r.all('PICK'):
            if p.get('think'):
                think[p.get('screen')].append(number(p['think']))
    tables.append(('Time to pick', 'Seconds from a screen showing to the pick.', ['screen', 'picks', 'median', 'longest'],
                   [[s, len(t), f"{statistics.median(t):.0f}", max(t)] for s, t in sorted(think.items())]))

    # The meta.
    rows = []
    for player in players:
        for kind, f in player.meta:
            if kind == 'META':
                what = (f.get('row') or f.get('item') or '') + (f" {f['rank']}" if f.get('rank') else '') + (f" -> {f['take']}" if f.get('take') else '')
                rows.append([player.who, f.get('did'), what, f.get('cost', ''), f.get('left', '')])
    tables.append(('Terminal and armory', 'Upgrades bought, takes switched and kits unlocked, in order.',
                   ['player', 'did', 'what', 'cost', 'left'], rows))

    versions = Counter(r.ver for r in runs)
    tests = sum(1 for r in runs if r.test)
    head = (f"{len(runs)} run(s) from {', '.join(p.who for p in players)}" + (f", {tests} of them test runs" if tests else '')
            + f". Builds: {', '.join(f'{v} ({n})' for v, n in versions.most_common()) or '-'}.")
    return head, tables


def print_summary(head, tables):
    print(head)
    for title, note, headers, rows in tables:
        if not rows:
            continue
        print()
        print(title.upper())
        if note:
            print(note)
        widths = [min(48, max(len(str(h)), *(len(str(r[i])) for r in rows))) for i, h in enumerate(headers)]
        print('  '.join(str(h).ljust(w) for h, w in zip(headers, widths)))
        for r in rows:
            print('  '.join(str(c)[:w].ljust(w) for c, w in zip(r, widths)))


def write_html(path, head, tables, runs):
    def cell(value, header):
        text = html.escape(str(value))
        if header in ('rate', 'share') and str(value).endswith('%'):
            pct = min(100, number(str(value)[:-1]))
            return f'<td class="num"><span class="bar" style="width:{pct}%"></span>{text}</td>'
        numeric = re.fullmatch(r'-?[\d.]+%?', str(value)) is not None
        return f'<td class="num">{text}</td>' if numeric else f'<td>{text}</td>'

    def table(headers, rows):
        body = ''.join('<tr>' + ''.join(cell(v, h) for v, h in zip(r, headers)) + '</tr>' for r in rows)
        return ('<div class="scroll"><table><thead><tr>' + ''.join(f'<th>{html.escape(h)}</th>' for h in headers)
                + f'</tr></thead><tbody>{body}</tbody></table></div>')

    sections = []
    for title, note, headers, rows in tables:
        if rows:
            sections.append(f'<section><h2>{html.escape(title)}</h2>'
                            + (f'<p class="note">{html.escape(note)}</p>' if note else '') + table(headers, rows) + '</section>')
    every = [[r.who, r.kit, r.ver, r.result, r.depth, r.start.get('patrons', '')] for r in runs]
    sections.append('<section><h2>Every run</h2>' + table(['player', 'kit', 'build', 'ended', 'depth', 'patrons'], every) + '</section>')
    page = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Run Report</title>
<style>
:root {{ --bg:#f5f5f3; --fg:#1c1c1e; --muted:#6c6c72; --line:#dddcd7; --accent:#c8102e; --card:#ffffff; }}
@media (prefers-color-scheme: dark) {{ :root {{ --bg:#101113; --fg:#ececec; --muted:#9b9ba1; --line:#2b2c30; --accent:#ff3b4f; --card:#17181b; }} }}
* {{ box-sizing:border-box; }}
body {{ margin:0; padding:24px 16px 48px; background:var(--bg); color:var(--fg); font:14px/1.45 system-ui, -apple-system, "Segoe UI", sans-serif; }}
main {{ max-width:1100px; margin:0 auto; }}
h1 {{ font-size:20px; margin:0 0 4px; letter-spacing:.04em; }}
h1 span {{ color:var(--accent); }}
.head {{ color:var(--muted); margin:0 0 20px; }}
section {{ background:var(--card); border:1px solid var(--line); border-radius:8px; padding:16px; margin:0 0 14px; }}
h2 {{ font-size:13px; margin:0 0 4px; text-transform:uppercase; letter-spacing:.08em; }}
.note {{ color:var(--muted); margin:0 0 10px; font-size:13px; }}
.scroll {{ overflow-x:auto; }}
table {{ border-collapse:collapse; width:100%; font-variant-numeric:tabular-nums; }}
th, td {{ text-align:left; padding:5px 12px 5px 0; border-bottom:1px solid var(--line); white-space:nowrap; }}
th {{ color:var(--muted); font-weight:600; font-size:12px; }}
td.num {{ text-align:right; position:relative; }}
.bar {{ position:absolute; right:0; top:4px; bottom:4px; background:var(--accent); opacity:.2; border-radius:2px; }}
</style></head><body><main>
<h1>NIGHT CITY ROGUELITE <span>/</span> RUN REPORT</h1>
<p class="head">{html.escape(head)}</p>
{''.join(sections)}
</main></body></html>
'''
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(page)
    print(f'Wrote {path}')


def write_csv(runs, out):
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, 'runs.csv'), 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['player', 'run', 'kit', 'build', 'test', 'from', 'result', 'depth', 'floors', 'kills', 'mins', 'patrons', 'upgrades'])
        for r in runs:
            end = r.end or {}
            w.writerow([r.who, r.id, r.kit, r.ver, r.start.get('test'), r.start.get('from'), r.result, r.depth, end.get('floors'),
                        end.get('kills'), end.get('mins'), r.start.get('patrons'), r.start.get('upgrades')])
    keys = ['depth', 'outcome', 'door', 'patron', 'obj', 'hot', 'threat', 'arena', 'faction', 'waves', 'wavesecs', 'secs',
            'dealt', 'hits', 'dmg', 'low', 'heals', 'kills', 'cover', 'hurt', 'fx']
    with open(os.path.join(out, 'floors.csv'), 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['player', 'run', 'kit'] + keys)
        for r in runs:
            for f in r.floors:
                w.writerow([r.who, r.id, r.kit] + [f.get(k, '') for k in keys])
    with open(os.path.join(out, 'picks.csv'), 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['player', 'run', 'kit', 'depth', 'screen', 'idx', 'took', 'think', 'offered'])
        for r in runs:
            offered = ''
            for kind, f in r.records:
                if kind == 'OFFER':
                    offered = f.get('cards', '')
                elif kind == 'PICK':
                    w.writerow([r.who, r.id, r.kit, f.get('depth'), f.get('screen'), f.get('idx', ''), f.get('took', ''),
                                f.get('think', ''), f.get('offered', offered)])
    print(f'Wrote runs.csv, floors.csv and picks.csv to {out}')


def print_scout(players):
    """The arena scout's candidates, the most walkable first (the latest scout of each)."""
    latest = OrderedDict()
    for player in players:
        for kind, f in player.meta:
            if kind == 'SCOUT':
                latest[f.get('id')] = f
    rows = sorted(latest.values(), key=lambda f: (-number(f.get('cover40'), -1), -number(f.get('cover30'), -1)))
    headers = ['id', 'kind', 'district', 'place', 'cover30', 'cover40', 'rise', 'roof', 'pin', 'at']
    table = [[f.get(h, '') if f.get('result') == 'ok' or h in ('id', 'kind', 'district', 'place') else (f.get('result') if h == 'cover30' else '')
              for h in headers] for f in rows]
    print_summary(f"{len(rows)} candidate(s) scouted. cover30/cover40: % of a 30/40 m circle V can walk to; "
                  "rise: height range (m); roof: inside; pin: start's distance from the map pin.",
                  [('Arena scout', '', headers, table)])


def print_marks(player):
    showing = False
    for line in player.log:
        if line.startswith('===== BUG MARK'):
            showing = True
            print()
        elif showing and line.startswith('====='):
            showing = False
        if showing:
            print(line)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('paths', nargs='+', help='game folders or ScriptableServiceContainer.dat files, one per player')
    parser.add_argument('--as', dest='names', help='player names, comma-separated, in the order of the files')
    parser.add_argument('--summary', action='store_true', help='everything summed up across runs')
    parser.add_argument('--html', help='write the summary as a page to this file')
    parser.add_argument('--effects', action='store_true', help='fires and damage per effect across runs')
    parser.add_argument('--csv', help='write CSV files to this folder')
    parser.add_argument('--log', type=int, default=0, help='print the last N log lines')
    parser.add_argument('--marks', action='store_true', help='print every bug mark with its snapshot')
    parser.add_argument('--scout', action='store_true', help='arena scout results, best first')
    parser.add_argument('--kit', help='only runs with this kit')
    parser.add_argument('--who', help="only this player's runs")
    parser.add_argument('--ver', help='only runs on this build (v0.0.19, dev, old)')
    parser.add_argument('--last', '--runs', type=int, default=0, help='only the last N runs')
    parser.add_argument('--tests', action='store_true', help='include test runs')
    args = parser.parse_args()

    names = args.names.split(',') if args.names else []
    players = []
    for i, path in enumerate(args.paths):
        telemetry, log = load(path)
        players.append(Player(player_name(path, names[i] if i < len(names) else None), telemetry, log))
    runs = select(players, args)

    if args.log:
        for player in players:
            if len(players) > 1:
                print(f'--- {player.who}')
            print('\n'.join(player.log[-args.log:]))
    elif args.marks:
        for player in players:
            print_marks(player)
    elif args.scout:
        print_scout(players)
    elif args.csv:
        write_csv(runs, args.csv)
    elif args.summary or args.html or args.effects:
        head, tables = summary(runs, players)
        if args.effects:
            tables = [t for t in tables if t[0] in ('Effects', 'Weapon effects per hit')]
        if args.html:
            write_html(args.html, head, tables, runs)
        else:
            print_summary(head, tables)
    else:
        if not runs:
            print('No runs here (telemetry starts with the build that added it; test runs need --tests). Try --log 100.')
        for run in runs:
            print_run(run)


if __name__ == '__main__':
    sys.exit(main())
