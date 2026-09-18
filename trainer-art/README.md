# Crystal Trainer Art (optional)

Full-colour trainer sprites for every Gold/Silver/Crystal trainer class plus the
player's back view, shown in battle (and standing in Terrarium's arena) in place
of Crystal's two-tone pictures.

**No sprites are in this repository.** They are AI-generated renderings of the
games' characters, made with an xAI image model from the outfit descriptions
in `CHARTER.md`; generate your own set:

1. `tools/generate.py` calls the xAI Images API (model `grok-imagine-image`) once
   per row of `classes.tsv`, writing 1024x1024 sources to `work/raw/`. Set your
   API key as the script expects (see its header). Prompts describe outfits, not
   names — names get moderated.
2. `tools/postprocess.py` turns each source into a 64x64 RGBA sprite with its
   feet on the bottom row, in `out/`.
3. Copy `out/trainers/*.png` to `mod/assets/trainers/` and `out/player/*.png`
   to `mod/assets/player/`, run `tools/build_data.py mod`, and install `mod/`
   as `mods/CRYSTAL_TRAINER_ART/`. Enable it under MODS in Crystal.

The mod needs `engine_internals` (the engine has no hook for enemy trainer
pictures; `BattleState.trainerArt` is wrapped) and uses the public
`player.sprite` hook for the back view. It only affects battle pictures.
