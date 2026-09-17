# Install

Two halves: the **engine** (gen1recomp, which on iOS you build yourself) and
the **mod** (Terrarium plus this kit's changes, produced by `apply.sh`).

## 0. Requirements

- Your own **Pokémon Crystal (USA) Rev 1.1** dump. SHA-1 `f2f52230b536214ef7c9924f483392993e226cfb`.
  The engine refuses anything that does not match its list. No ROM is provided here or anywhere by this project.
- `git`, `bash`, `python3`, `zip` (all standard on macOS and Linux).
- **iOS only:** a Mac with **Xcode 26** (or whatever gen1recomp v0.2.60 asks for), an **iPhone** with
  Developer Mode on, and an **Apple ID**:
  - a **free Apple ID** works. Apps signed with it stop launching after **7 days**; re-run the
    install step and they run again, saves kept;
  - a **paid Apple Developer Program** membership (US $99 / year) signs for about a year.
  - There is no way around signing on iOS. Sideloading a prebuilt gen1recomp IPA (AltStore, the
    engine's own releases) does **not** work for this kit: the fix that makes a 3D world render
    correctly on Gold/Crystal lives inside the app, so the app must be built from the patched source.

## 1. Run `apply.sh`

```sh
./apply.sh
```

It clones gen1recomp at v0.2.60 and Terrarium at `ffecfa14` into `work/`, applies the patches, adds
the new files, marks the mod as Gen 2-only, and writes `dist/TERRARIUM/` and `dist/TERRARIUM.zip`.

Options: `--gen1recomp <dir>` / `--terrarium <dir>` reuse checkouts you already have (they must be at
the pinned revisions and clean); `--all-gens` keeps Terrarium's upstream `gen2compat` so the mod also
loads on Red/Blue/Yellow — only do that if no other world-rendering mod (Battle Art, Dramatic Shape…)
is enabled for those games, because only one may own the frame.

## 2. Engine

### iOS (build it)

Follow gen1recomp's own guide, from the patched checkout:

```sh
cd work/gen1recomp
open docs/ios-install.md        # read it once; the steps below are its short form
scripts/build_ios.sh --fetch --package-only
DEVELOPMENT_TEAM=<your team id> scripts/build_ios.sh --device --release --install --version 0.2.60
```

Your team id is in Xcode → Settings → Accounts (a free Apple ID has one too). The script pins a
per-team bundle id, so rebuilding later keeps your saves. The two engine patches are already applied
in `work/gen1recomp`; you can see them with `git diff` there.

### macOS / Windows / Linux

Use the official gen1recomp **v0.2.60** release for your platform. The desktop build needs no engine
patch (the Gold rendering fix only matters where the window and the playfield differ, and the scene
guard is iOS-only). Newer engine releases may work but are untested.

## 3. Import Crystal

Open the app, drop your `.gbc` into it (iPhone: AirDrop or the Files app into the app's folder;
desktop: the launcher's import button). The launcher verifies the SHA-1 and builds its cache. Delete
your copy of the dump afterwards if you like — the app keeps only derived data.

## 4. Install the mod

- **iPhone:** copy the whole `dist/TERRARIUM/` folder into the app's `mods/` folder. In the Files
  app that is *On My iPhone → (the app) → mods*. AirDrop the zip instead if you prefer and unzip it
  there. Xcode users can push it from the Mac:
  ```sh
  xcrun devicectl device copy to --device <name> --domain-type appDataContainer \
    --domain-identifier <bundle id> --source dist/TERRARIUM --destination Documents/mods/TERRARIUM
  ```
  Never pass `--remove-existing-content` to that command: it empties the whole app folder, saves included.
- **Desktop:** launcher → MODS tab → *Import mod .zip* → `dist/TERRARIUM.zip`, or drop the folder
  into the save directory's `mods/` (`~/Library/Application Support/pokemon-love2d/mods/` on macOS).

Grant the `engine_internals` and `filesystem` permissions when asked; they are what the mod needs to
replace the world renderer.

## 5. Turn the diorama on

**Desktop:** boot Crystal and press **`v`** — Terrarium's VOXEL hotkey steps the camera level
(OFF → FULL → 15° → 35° → 50° → 75°); the engine remembers it. Done.

**Phone (no keyboard):** Gold and Crystal keep their settings in the `gold` block of `options.lua`,
and their OPTIONS menu has no row for render pipelines, so set the camera level in the file once:

```lua
  gold = {
    pipelines = {
      terrarium_voxel = 3,
    },
    -- ...whatever else is already there
  },
```

`1` top-down, `2` 15°, `3` 35° (recommended), `4` 50°, `5` 75°, `0` off. The file is in the app's
folder (iPhone: Files app, next to `mods/`; macOS: `~/Library/Application Support/pokemon-love2d/`).
Edit it while the app is **closed**, then launch and choose Crystal. Terrarium's own rows (RES, SHADOWS…)
do appear in Crystal's OPTIONS; RES 1/2 and SHADOWS LOW are the phone defaults and fine.

## 6. Play

Boot Crystal. The first map takes a couple of seconds to mesh; neighbouring maps bake as you walk.
If the world stays flat, see [TESTING.md](TESTING.md) — the mod writes a GPU report next to the save
when its 3D pass cannot start.
