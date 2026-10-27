# Perk catalogue

`catalog.tsv` lists the perks that Training doors (and the Fixer) can offer.
Each row has five tab-separated columns:

- **game perk enum**: a `gamedataNewPerkType` value.
- **card name** and **card text**: taken from the game's English perk texts.
- **power**:
  - 1 = novice
  - 2 = adept or milestone
  - 3 = expert milestone
  - 4 = master (a signature perk; offered only when the build uses its style)
- **build tags**: comma-separated, matched against `Rewards/BuildProfile.reds`.

To regenerate `r6/scripts/NightCityRoguelite/Rewards/PerkCatalogData.reds` after editing the TSV:

    python3 source/perks/build_catalog.py

Rows whose perk is missing from the game, or has no levels, are skipped at
runtime. Tree prerequisites come from the game's own records
(`RLPerkCatalog.IsOfferable`).
