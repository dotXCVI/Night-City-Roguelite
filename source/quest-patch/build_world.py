# Gates the base-game quest graph for roguelite characters.
#
# ep1\quest\cyberpunk2077_ep1_standalone.quest starts base\quest\cyberpunk2077.questphase
# (every base-game quest: calls, texts, side jobs, objectives). Patched:
#
#   start -> wait 1 s -> [nc_roguelite_quiet_world >= 1]
#                          False -> base-game quest graph (unchanged)
#                          True  -> nothing
#
# The 1 s wait lets the scripts set the fact at Session/Start first. Normal
# Phantom Liberty starts take the False branch (one second later than before).
# Inputs (WolvenKit JSON): ../ep1j/cyberpunk2077_ep1_standalone.quest.json and
# ../ep1j/q301_hook.questphase.json (node templates).
import sys, json
sys.path.insert(0, '.')
from handles import load, dump, clone, Box
D = lambda b: b.data if isinstance(b, Box) else b

raw, tree = load('../ep1j/cyberpunk2077_ep1_standalone.quest.json')
_, hook = load('../ep1j/q301_hook.questphase.json')
graph = D(tree['Data']['RootChunk']['graph'])
hooknodes = D(hook['Data']['RootChunk']['graph'])['nodes']
byid = {D(n)['id']: D(n) for n in graph['nodes']}

def box_of(nid, nodes):
    for n in nodes:
        if D(n)['id'] == nid:
            return n

def sockbox(node, name):
    for s in node['sockets']:
        if D(s)['name']['$value'] == name:
            return s
    raise KeyError((node['id'], name))

next_id = max(byid) + 1
def add_node(src_box, patch):
    global next_id
    nb = clone(src_box)
    nd = D(nb); nd['id'] = next_id; next_id += 1
    for s in nd['sockets']:
        D(s)['connections'] = []
    patch(nd)
    graph['nodes'].append(nb)
    return nd

def connect(a, aname, b, bname):
    sa = sockbox(a, aname); sb = sockbox(b, bname)
    c = Box(); c.data = {'$type': 'graphGraphConnectionDefinition', 'destination': sb, 'source': sa}
    D(sa)['connections'].append(c); D(sb)['connections'].append(c)

start = [n for n in byid.values() if n['$type'] == 'questStartNodeDefinition'][0]
phase = [n for n in byid.values() if n['$type'] == 'questPhaseNodeDefinition'][0]

def pwait(nd):
    t = D(D(nd['condition'])['type']); t['seconds'] = 1; t['miliseconds'] = 0; t['minutes'] = 0; t['hours'] = 0
wait = add_node(box_of(35, hooknodes), pwait)
def pcond(nd):
    t = D(D(nd['condition'])['type']); t['factName'] = 'nc_roguelite_quiet_world'; t['value'] = 1; t['comparisonType'] = 'GreaterOrEqual'
cond = add_node(box_of(26, hooknodes), pcond)

# Move start -> phase onto start -> wait
out = [D(s) for s in start['sockets'] if D(s)['type'] == 'Output'][0]
phase_in = [s for s in phase['sockets'] if D(s)['type'] == 'Input' and D(s)['connections']][0]
moved = [c for c in out['connections'] if D(c)['destination'] is phase_in]
assert len(moved) == 1
D(phase_in)['connections'].remove(moved[0])
wait_in = sockbox(wait, 'In')
D(moved[0])['destination'] = wait_in
D(wait_in)['connections'].append(moved[0])
connect(wait, 'Out', cond, 'In')
connect(cond, 'False', phase, D(phase_in)['name']['$value'])
print('start', start['id'], 'phase', phase['id'], 'new', wait['id'], cond['id'])
json.dump(dump(tree), open('cyberpunk2077_ep1_standalone.quest.json', 'w'), indent=1)
