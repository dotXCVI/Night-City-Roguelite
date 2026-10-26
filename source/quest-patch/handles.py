import json, copy
class Box:
    __slots__=('data',)
    def __init__(self): self.data=None
def load(path):
    raw=json.load(open(path))
    boxes={}
    def get(i):
        if i not in boxes: boxes[i]=Box()
        return boxes[i]
    def conv(o):
        if isinstance(o,dict):
            if 'HandleRefId' in o and len(o)==1:
                return get(o['HandleRefId'])
            if 'HandleId' in o and 'Data' in o and len(o)==2:
                b=get(o['HandleId']); b.data=conv(o['Data']); return b
            return {k:conv(v) for k,v in o.items()}
        if isinstance(o,list): return [conv(v) for v in o]
        return o
    return raw, conv(raw)
def dump(tree):
    ids={}
    def ser(o):
        if isinstance(o,Box):
            if id(o) in ids: return {'HandleRefId':ids[id(o)]}
            ids[id(o)]=str(len(ids))
            return {'HandleId':ids[id(o)],'Data':ser(o.data)}
        if isinstance(o,dict): return {k:ser(v) for k,v in o.items()}
        if isinstance(o,list): return [ser(v) for v in o]
        return o
    return ser(tree)
def clone(box_or_obj, memo=None):
    # deep copy including boxes (new identities)
    if memo is None: memo={}
    o=box_or_obj
    if isinstance(o,Box):
        if id(o) in memo: return memo[id(o)]
        b=Box(); memo[id(o)]=b; b.data=clone(o.data,memo); return b
    if isinstance(o,dict): return {k:clone(v,memo) for k,v in o.items()}
    if isinstance(o,list): return [clone(v,memo) for v in o]
    return o
