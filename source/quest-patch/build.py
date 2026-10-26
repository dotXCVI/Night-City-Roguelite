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

# Skip path (roguelite starts only):
#   [nc_roguelite_start >= 1]
#     True -> teleport V to the opener spot (node 32's target: solid ground while
#             the screen is still black) -> fact nc_roguelite_skipping = 1
#             -> wait for nc_roguelite_ready (set by the scripts once V stands in
#                the apartment) -> Tier1 -> fade in -> HUD -> nc_roguelite_opening_skipped
#             -> (in parallel) after 45 s set nc_roguelite_ready anyway, so a
#                script failure can never leave the screen black
#     False -> original opening (node 26)
def setfact(name, value):
    def p(nd):
        t=D(nd['type']); t['factName']=name; t['value']=value; t['setExactValue']=1
    return p
cond=add_node(box_of(26,graph['nodes']), lambda nd: None)
ctt=D(D(cond['condition'])['type'])
ctt['factName']='nc_roguelite_start'; ctt['value']=1; ctt['comparisonType']='GreaterOrEqual'
tele=add_node(box_of(32,graph['nodes']), lambda nd: None)
skipping=add_node(box_of(14,graph['nodes']), setfact('nc_roguelite_skipping', 1))
def pready(nd):
    t=D(D(nd['condition'])['type']); t['factName']='nc_roguelite_ready'; t['value']=1; t['comparisonType']='GreaterOrEqual'
waitready=add_node(box_of(66,graph['nodes']), pready)
def ptimeout(nd):
    t=D(D(nd['condition'])['type']); t['seconds']=45; t['miliseconds']=0; t['minutes']=0; t['hours']=0
timeout=add_node(box_of(30,graph['nodes']), ptimeout)
forceready=add_node(box_of(14,graph['nodes']), setfact('nc_roguelite_ready', 1))
def pt(nd): D(nd['type'])['tier']='Tier1_FullGameplay'
tier=add_node(box_of(3,sqnodes), pt)
def pf(nd):
    t=D(nd['type']); t['fadeIn']=1; t['duration']=1.0
fade=add_node(box_of(4,sqnodes), pf)
hud=add_node(box_of(94,graph['nodes']), lambda nd: None)
mark=add_node(box_of(14,graph['nodes']), setfact('nc_roguelite_opening_skipped', 1))

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
connect(cond,'True',tele,'In')
connect(tele,'Out',skipping,'In')
connect(skipping,'Out',waitready,'In')
connect(skipping,'Out',timeout,'In')
connect(timeout,'Out',forceready,'In')
connect(waitready,'Out',tier,'In')
connect(tier,'Out',fade,'In')
connect(fade,'Out',hud,'In')
connect(hud,'Out',mark,'In')
print('new nodes', [n['id'] for n in (cond,tele,skipping,waitready,timeout,forceready,tier,fade,hud,mark)])
json.dump(dump(tree),open('q301_hook.questphase.json','w'),indent=1)
