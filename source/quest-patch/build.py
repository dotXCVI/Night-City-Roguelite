import sys, json
sys.path.insert(0,'.')
from handles import load, dump, clone, Box
D=lambda b: b.data if isinstance(b,Box) else b
raw,tree=load('../ep1j/q301_hook.questphase.json')
_,sq=load('../ep1j/ep1_standalone.quest.json')
graph=D(tree['Data']['RootChunk']['graph'])
nodes=[D(n) for n in graph['nodes']]
byid={n['id']:n for n in nodes}
def sock(node,name):
    for s in node['sockets']:
        if D(s)['name']['$value']==name: return D(s), s
    raise KeyError((node['id'],name))
def sockbox(node,name):
    for s in node['sockets']:
        if D(s)['name']['$value']==name: return s
    raise KeyError((node['id'],name))
next_id=max(byid)+1
def add_node(src_box, new_type_patch):
    global next_id
    nb=clone(src_box)
    nd=D(nb); nd['id']=next_id; next_id+=1
    for s in nd['sockets']: D(s)['connections']=[]
    new_type_patch(nd)
    graph['nodes'].append(nb)
    return nd
def connect(a,aname,b,bname):
    sa=sockbox(a,aname); sb=sockbox(b,bname)
    c=Box(); c.data={'$type':'graphGraphConnectionDefinition','destination':sb,'source':sa}
    D(sa)['connections'].append(c); D(sb)['connections'].append(c)
def box_of(nid,nodeslist):
    for n in nodeslist:
        if D(n)['id']==nid: return n
sqnodes=D(sq['Data']['RootChunk']['graph'])['nodes']

# 1. Condition: nc_roguelite_start >= 1  (clone of node 26)
cond=add_node(box_of(26,graph['nodes']), lambda nd: None)
ct=D(cond['condition']); ctt=D(ct['type'])
ctt['factName']='nc_roguelite_start'; ctt['value']=1; ctt['comparisonType']='GreaterOrEqual'
# 2. SetTier Tier1 (clone of ep1_standalone.quest node 3)
def pt(nd): D(nd['type'])['tier']='Tier1_FullGameplay'
tier=add_node(box_of(3,sqnodes), pt)
# 3. Fade in (clone of ep1_standalone.quest node 4)
def pf(nd):
    t=D(nd['type']); t['fadeIn']=1; t['duration']=1.0
fade=add_node(box_of(4,sqnodes), pf)
# 4. HUD BasicUI (clone of node 94)
hud=add_node(box_of(94,graph['nodes']), lambda nd: None)
# 5. Fact marker (clone of node 14)
def pv(nd):
    t=D(nd['type']); t['factName']='nc_roguelite_opening_skipped'; t['value']=1; t['setExactValue']=1
mark=add_node(box_of(14,graph['nodes']), pv)

# Rewire: node 2 Out1 -> 26 In  becomes  node 2 Out1 -> cond In
n2=byid[2]; n26=byid[26]
out1=sock(n2,'Out1')[0]; in26b=sockbox(n26,'In')
moved=None
for c in out1['connections']:
    if D(c)['destination'] is in26b: moved=c
assert moved is not None
D(in26b)['connections'].remove(moved)
condIn=sockbox(cond,'In')
D(moved)['destination']=condIn
D(condIn)['connections'].append(moved)
connect(cond,'False',n26,'In')
connect(cond,'True',tier,'In')
connect(tier,'Out',fade,'In')
connect(fade,'Out',hud,'In')
connect(hud,'Out',mark,'In')
print('new nodes', cond['id'],tier['id'],fade['id'],hud['id'],mark['id'])
json.dump(dump(tree),open('q301_hook.questphase.json','w'),indent=1)
