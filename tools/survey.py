#!/usr/bin/env python3
"""Night City Roguelite - city survey results to arenas.

    python3 tools/survey.py <ScriptableServiceContainer.dat> [--places places.json] [--write]

Reads the city survey's records (Dev/CitySurvey.reds: S1|<seq>|i=..;at=..;...)
from a player's saved data, ranks the points and, with --write, generates
r6/scripts/NightCityRoguelite/Data/CityArenas.reds: one arena per good spot.

A spot makes an arena when:
  - the visit woke nothing in the story (no journal entry, no call);
  - enough of it is floor V can walk to: 60% of a 30 m circle, or 70% of a
    20 m one for an interior;
  - the floor is fairly flat (a rise of 6 m or less);
  - it is 120 m from every arena already in the game and every better spot.

Its radius follows how far the walkable floor reaches; its terrain the share
of ground points with cover beside them (CLOSE QUARTERS over half, OPEN
GROUND under a fifth with sky overhead, MIXED otherwise). Its gangs are its
district's. Its name is the place the game shows there (--places: a JSON map
of LocKey number to text, from the localization's onscreens), plus a word
for the ground when the place is a whole subdistrict.
"""
import argparse
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
OUT = os.path.join(ROOT, 'r6', 'scripts', 'NightCityRoguelite', 'Data', 'CityArenas.reds')
ARENAS = os.path.join(ROOT, 'r6', 'scripts', 'NightCityRoguelite', 'Combat', 'Arenas.reds')

# Subdistrict -> (district area, gangs).
DISTRICTS = {
    'Kabuki': ('Watson', ['TygerClaws', 'Maelstrom']),
    'Little China': ('Watson', ['TygerClaws', 'Maelstrom']),
    'Northside': ('Watson', ['Maelstrom', 'Scavengers']),
    'Arasaka Waterfront': ('Watson', ['Maelstrom', 'Arasaka']),
    'Watson': ('Watson', ['Maelstrom', 'TygerClaws']),
    'Japantown': ('Westbrook', ['TygerClaws']),
    'Charter Hill': ('Westbrook', ['TygerClaws', 'Arasaka']),
    'North Oak': ('North Oak', ['Arasaka']),
    'Westbrook': ('Westbrook', ['TygerClaws']),
    'Downtown': ('City Center', ['Animals', 'TygerClaws']),
    'Corpo Plaza': ('City Center', ['Arasaka', 'Militech']),
    'City Center': ('City Center', ['Arasaka', 'Animals']),
    'Wellsprings': ('Heywood', ['Valentinos']),
    'The Glen': ('Heywood', ['Valentinos', 'SixthStreet']),
    'Vista Del Rey': ('Heywood', ['Valentinos']),
    'Heywood': ('Heywood', ['Valentinos']),
    'Arroyo': ('Santo Domingo', ['SixthStreet', 'Maelstrom']),
    'Rancho Coronado': ('Santo Domingo', ['SixthStreet', 'Animals']),
    'Santo Domingo': ('Santo Domingo', ['SixthStreet']),
    'West Wind Estate': ('Pacifica', ['VoodooBoys', 'Animals']),
    'Coastview': ('Pacifica', ['VoodooBoys', 'Animals']),
    'Pacifica': ('Pacifica', ['VoodooBoys']),
    'Dogtown': ('Dogtown', ['Barghest']),
    'Badlands': ('Badlands', ['Wraiths', 'Scavengers']),
    'Rocky Ridge': ('Badlands', ['Wraiths', 'Scavengers']),
    'Vasquez Pass': ('Badlands', ['Wraiths', 'Scavengers']),
    'Jackson Plains': ('Badlands', ['Wraiths', 'Scavengers']),
    'Red Peaks': ('Badlands', ['Wraiths', 'Scavengers']),
    'Biotechnica Flats': ('Badlands', ['Wraiths', 'Militech']),
    'Sierra Sonora': ('Badlands', ['Wraiths', 'Scavengers']),
    'Laguna Bend': ('Badlands', ['Wraiths', 'Scavengers']),
    'Northern Badlands': ('Badlands', ['Wraiths', 'Scavengers']),
    'Southern Badlands': ('Badlands', ['Wraiths', 'Scavengers']),
}

# Survey indexes to leave out (spots that turned out wrong in play).
SKIP = set()

# Words for the ground, by terrain, used after a subdistrict's name.
WORDS = {
    'OPEN GROUND': ['Lots', 'Yard', 'Flats', 'Crossing', 'Plaza', 'Clearing', 'Overpass'],
    'CLOSE QUARTERS': ['Block', 'Alleys', 'Courts', 'Warehouse', 'Arcade', 'Stacks', 'Tunnels'],
    'MIXED': ['Corner', 'Market', 'Strip', 'Underpass', 'Row', 'Depot', 'Terraces'],
}


def number(value, default=0.0):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def load(path):
    """Survey records, oldest first, as dicts (pieces joined)."""
    data = open(path, 'rb').read()
    records = {}
    for chunk in data.split(b'\x00'):
        m = re.search(rb'S1(\+?)\|(\d+)\|(.*)$', chunk, re.S)
        if not m:
            continue
        seq = int(m.group(2))
        if m.group(1):
            if seq in records:
                records[seq] += m.group(3)
        else:
            records[seq] = m.group(3)
    out = []
    for _, raw in sorted(records.items()):
        fields = {}
        for item in raw.decode('utf-8', 'replace').split(';'):
            if '=' in item:
                key, value = item.split('=', 1)
                fields[key] = value
        out.append(fields)
    return out


def point(text):
    m = re.match(r'\((-?[\d.]+), (-?[\d.]+), (-?[\d.]+)\)', text or '')
    return tuple(float(v) for v in m.groups()) if m else None


def existing_arenas():
    """Positions of every arena already defined in Combat/Arenas.reds."""
    found = []
    for m in re.finditer(r'Vector4\((-?[\d.]+), (-?[\d.]+), (-?[\d.]+), 1\.0\)', open(ARENAS).read()):
        found.append(tuple(float(v) for v in m.groups()))
    return found


def place_name(place, places):
    m = re.match(r'LocKey#(\d+)', place or '')
    if m:
        return places.get(m.group(1), '')
    return place or ''


def rate(f):
    """(score, radius, terrain) of a surveyed spot, or None when it's no arena."""
    if f.get('result') != 'ok' or f.get('story'):
        return None
    c20, c30, c40 = (number(f.get(k)) for k in ('cover20', 'cover30', 'cover40'))
    rise = number(f.get('rise'))
    if rise > 6:
        return None
    if c40 >= 75:
        radius = 40
    elif c30 >= 75:
        radius = 35
    elif c30 >= 60:
        radius = 30
    elif c20 >= 70 and f.get('roof') == '1':
        radius = 22
    else:
        return None
    ground = max(1.0, number(f.get('ground'), 1))
    covered = number(f.get('covered')) / ground
    if covered > 0.5:
        terrain = 'CLOSE QUARTERS'
    elif covered < 0.2 and f.get('roof') != '1':
        terrain = 'OPEN GROUND'
    else:
        terrain = 'MIXED'
    perches = number(f.get('perches'))
    # Walkable reach first; cover and perches make a fight more interesting.
    score = c30 + 0.5 * c40 + 0.3 * c20 + 10 * min(covered, 0.5) + 3 * min(perches, 5)
    return score, radius, terrain


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('dat')
    parser.add_argument('--places', help='LocKey number -> text (JSON)')
    parser.add_argument('--write', action='store_true', help='write Data/CityArenas.reds')
    args = parser.parse_args()
    import json
    places = json.load(open(args.places)) if args.places else {}
    records = load(args.dat)
    if not records:
        sys.exit('No survey records in that file.')
    taken = existing_arenas()
    rated = []
    woke = 0
    for f in records:
        if number(f.get('i'), -1) in SKIP:
            continue
        if f.get('story'):
            woke += 1
        r = rate(f)
        at = point(f.get('at'))
        if r and at:
            rated.append((r[0], r[1], r[2], at, f))
    rated.sort(key=lambda x: -x[0])
    picks = []
    for score, radius, terrain, at, f in rated:
        near = lambda p: math.hypot(at[0] - p[0], at[1] - p[1]) < 120 and abs(at[2] - p[2]) < 10
        if any(near(p) for p in taken) or any(near(p[3]) for p in picks):
            continue
        picks.append((score, radius, terrain, at, f))
    print(f'{len(records)} points surveyed, {woke} woke the story, {len(rated)} good enough, {len(picks)} new arenas.')
    used_names = set()
    rows = []
    word_index = {}
    for score, radius, terrain, at, f in picks:
        place = place_name(f.get('place'), places)
        district = DISTRICTS.get(place)
        if district:
            # A whole subdistrict: add a word for the ground.
            words = WORDS[terrain]
            k = word_index.get((place, terrain), 0)
            name = f'{place} {words[k % len(words)]}'
            while name in used_names:
                k += 1
                name = f'{place} {words[k % len(words)]}' if k < len(words) else f'{place} {words[k % len(words)]} {k // len(words) + 1}'
            word_index[(place, terrain)] = k + 1
            area, gangs = district
        else:
            # A named place ("Arasaka Tower: Jungle", "Totentanz"): its own name.
            name = place or f"Site {f.get('i')}"
            area, gangs = guess_district(at)
            n = 2
            base = name
            while name in used_names:
                name = f'{base} {n}'
                n += 1
        used_names.add(name)
        rows.append((f.get('i'), name, area, at, radius, gangs, terrain, score, f))
        print(f"  {name:32} {area:14} r{radius:<3} {terrain:15} cover {f.get('cover20')}/{f.get('cover30')}/{f.get('cover40')} "
              f"perches {f.get('perches')} covered {f.get('covered')}/{f.get('ground')}")
    if args.write:
        write(rows)


def guess_district(at):
    """District of a named place from its position (rough boxes)."""
    x, y, _ = at
    if -1500 < x < -1340 and 40 < y < 260:
        return 'City Center', ['Arasaka']
    if x > 900 or y < -2700:
        return 'Badlands', ['Wraiths', 'Scavengers']
    if y < -1900 and x < -1200:
        return 'Dogtown', ['Barghest']
    if y < -1300:
        return 'Pacifica', ['VoodooBoys', 'Animals']
    if y < -500:
        return ('Santo Domingo', ['SixthStreet', 'Animals']) if x > -800 else ('Heywood', ['Valentinos'])
    if y < 600:
        return 'City Center', ['Animals', 'TygerClaws']
    if x > -900:
        return 'Westbrook', ['TygerClaws']
    return 'Watson', ['Maelstrom', 'TygerClaws']


def write(rows):
    out = [
        '// -----------------------------------------------------------------------------',
        '// Night City Roguelite - arenas from the city survey (generated)',
        '// -----------------------------------------------------------------------------',
        '// Generated by tools/survey.py from the city survey (Dev/CitySurvey.reds):',
        f'// {len(rows)} spots that woke nothing in the story and have room to fight.',
        '// Edit the generator, not this file; to drop one, add its survey index to',
        '// SKIP in tools/survey.py.',
        '// -----------------------------------------------------------------------------',
        '',
        'module NightCityRoguelite',
        '',
        'public abstract class RLCityArenas {',
        '  public static func Add(out list: array<ref<RLArenaDef>>) {',
    ]
    for index, name, area, at, radius, gangs, terrain, score, f in rows:
        factions = ', '.join(f'gamedataAffiliation.{g}' for g in gangs)
        ident = 'city' + str(index)
        out.append(f'    ArrayPush(list, RLArenas.Make(n"{ident}", "{name}", "{area}", Vector4({at[0]:.1f}, {at[1]:.1f}, {at[2] + 0.6:.1f}, 1.0), 0.0, {radius:.1f},')
        out.append(f'      [{factions}], "{terrain}"));')
    out += ['  }', '}', '']
    open(OUT, 'w').write('\n'.join(out))
    print(f'Wrote {OUT}')


if __name__ == '__main__':
    main()
