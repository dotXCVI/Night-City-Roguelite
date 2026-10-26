# Quest patch (NightCityRoguelite.archive)

`archive/pc/mod/NightCityRoguelite.archive` holds one file, a patched copy of
`ep1\quest\main_quests\q301\phases\q301_hook.questphase` (the Phantom Liberty
standalone opening). Five nodes are added right after the phase's setup node:

    hook_setup -> [nc_roguelite_start >= 1] --False--> original opening (unchanged)
                                            --True---> Tier1_FullGameplay -> fade in
                                                       -> BasicUI HUD
                                                       -> fact nc_roguelite_opening_skipped = 1

The scripts set `nc_roguelite_start` at Session/Start only for characters made
from the ROGUELITE menu entry, so normal Phantom Liberty starts are untouched.

## Rebuilding (after a game patch changes q301_hook)

Needs the WolvenKit CLI 10 nightly (2.5 support) and Python 3.

    # 1. extract both originals from the game's archive/pc/ep1 archives
    #    (WolvenKit.CLI extract <archive> --regex "q301_hook\.questphase$|ep1_standalone\.quest$")
    #    and convert them to JSON in ../ep1j/
    WolvenKit.CLI convert serialize <extracted folder> -o ../ep1j
    # 2. patch
    python3 build.py                          # writes q301_hook.questphase.json
    # 3. back to binary, at the original depot path, and pack
    WolvenKit.CLI convert deserialize q301_hook.questphase.json -o bin
    P=pack/NightCityRoguelite/ep1/quest/main_quests/q301/phases
    mkdir -p $P && cp bin/q301_hook.questphase $P/
    WolvenKit.CLI pack pack/NightCityRoguelite -o packout   # -> packout/NightCityRoguelite.archive

`handles.py` loads WolvenKit's JSON with its shared handles as real object
references, so cloned nodes and new connections serialize back correctly.
