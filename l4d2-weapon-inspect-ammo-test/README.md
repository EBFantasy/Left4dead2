# [TEST] Weapon Inspect Ammo Check

Current version: `1.7.0`. **This is a test project.**

A standalone Left 4 Dead 2 **VScript addon**. Hold **Shift** and press **E** (or type `!ammo` in chat) to "inspect" the weapon in your hands:

- the weapon plays its own **reload / inspect animation**,
- the **remaining ammo** is printed to chat and to the centre of the screen,
- **no reload happens** — clip and reserve ammo are unchanged.

No MetaMod, no SourceMod, no `-insecure`. Just one `.vpk` in your addons
folder.

> Chinese version: [README_zh-CN.md](README_zh-CN.md) ·
> Design and debugging notes: [TECHNICAL_NOTES.md](TECHNICAL_NOTES.md)

---

## Install

### Option A — build the VPK on Windows (recommended)

1. Download or clone this folder.
2. Double-click **`build_vpk.bat`**.
   It finds `vpk.exe` in your Left 4 Dead 2 install, packs the source folder,
   and produces `test_ammo_inspect.vpk`.
3. Copy that file into:

   ```text
   ...\Steam\steamapps\common\Left 4 Dead 2\left4dead2\addons\
   ```

4. Start the game. The addon appears in the in-game **Add-ons** list.

### Option B — pack manually

Drag the **`test_ammo_inspect`** folder onto `Left 4 Dead 2\bin\vpk.exe`.
`vpk.exe` writes `test_ammo_inspect.vpk` next to the folder you dragged. Copy
it to `left4dead2\addons\`.

That is all there is to it — **only the source folder gets packed**. The
`README`, `TECHNICAL_NOTES.md`, `LICENSE`, `build_vpk.bat` and `reference/`
folder stay out of the VPK; they are repository documentation, not game content.

> The VPK's internal layout must be exactly this — `scripts` at the root:
>
> ```text
> addoninfo.txt
> scripts/vscripts/mapspawn_addon.nut
> scripts/vscripts/ebf_inspect_ammo.nut
> ```
>
> If you pack the *parent* folder by mistake, the game will not find the
> scripts.

#### Renaming the folder

You can rename `test_ammo_inspect` to anything you like. The VPK takes its
name from the folder, and nothing inside the scripts depends on that name —
only the internal `scripts/vscripts/...` layout matters. `build_vpk.bat`
auto-detects the source folder (it looks for whichever neighbouring folder
contains `addoninfo.txt`), so it keeps working after a rename.

The name shown in the in-game Add-ons list comes from `addontitle` inside
`addoninfo.txt`, not from the filename, so change that too if you want the
list entry to match.

### Option C — loose files (no VPK, for quick testing)

Copy the two `.nut` files to:

```text
...\Left 4 Dead 2\left4dead2\scripts\vscripts\
```

Note that `mapspawn_addon.nut` is a shared filename — if another loose script
already uses it, merge the contents rather than overwriting.

---

## Use

**Works out of the box. No binds required.**

In game, **hold Shift and press E** (about 0.3 s).

The inspect can be **interrupted at any time**: pressing R reloads immediately
(single press), and firing or shoving cancels it at once. The weapon is handed
straight back.

Or type in chat:

```text
!ammo
```

> **Why Shift+E?**
> "Spare" input bits like `+alt1`/`+alt2` are usually already bound on heavy
> script users' setups. Shift and E are existing actions, so this **consumes no
> bindable key at all**, sits comfortably under the left hand, and looks natural
> on screen (no crouching first). Shift alone (walk) or E alone (use) does
> nothing — Shift must be held while E is pressed, past `hold_time`.

Prefer something else? Any chord works:

```text
combo duck+zoom          // Ctrl + aim
combo speed+attack2      // Shift + right mouse
```

Or go back to a single key if you have one free:

```text
trigger key
key alt1
```

## Verify it is working

Open the developer console. On load you should see:

```text
[InspectAmmo] Loaded N setting(s) from ems/ebf_inspect_ammo/settings.txt
[InspectAmmo] Manager entity active (index NN).
[InspectAmmo] Version 1.7.0 ready. Hold E and tap R to inspect.
```

Diagnostic commands:

| Command | What it does |
|---|---|
| `script EBFInspectAmmo.Status()` | Dumps settings, your current weapon, its ammo, the viewmodel path, and **which animations that model actually has**. |
| `script EBFInspectAmmo.TestFire()` | Performs one inspect on you with verbose output — proves the script works without the key combo. |
| `script EBFInspectAmmo.Reload()` | Re-reads the settings file without changing level. |

---

## Configuration

Created automatically on first run:

```text
left4dead2\ems\ebf_inspect_ammo\settings.txt
```

A reference copy is included at `reference/ems/ebf_inspect_ammo/settings.txt`.

| Key | Range | Default | Meaning |
|---|---|---|---|
| `enable` | 0/1 | 1 | Master switch. |
| `trigger` | combo/key/chat | combo | How to inspect. combo needs no bind at all. |
| `combo` | see below | speed+use | Chord. Names: duck(Ctrl), speed(Shift 静步), zoom, use(E), reload(R), jump, attack2(RMB), alt1, alt2 — joined with `+`. |
| `hold_time` | 0.0–3.0 | 0.30 | How long the chord must be held, preventing accidental triggers. |
| `chat_command` | any text | !ammo | Chat trigger. **Always active**, never conflicts. |
| `key` | alt1/alt2/zoom/reload | alt1 | Only used when trigger = key. |
| `modifier` | none/use/duck/speed | none | Only used when trigger = key. |
| `require_use` | 0/1 | 0 | Legacy: 1 restores E+R. Not recommended. |
| `output_chat` | 0/1 | 1 | Print ammo to the chat area. |
| `output_center` | 0/1 | 1 | Print ammo at screen centre. |
| `play_animation` | 0/1 | 1 | Drive the reload/inspect animation. |
| `anim_source` | auto/pickup/deploy/idle/reload | auto | Which animation plays. auto = a real inspect/fidget anim if present, else the **item-pickup** idle (the one shown while staring at a pickupable item). |
| `block_reload` | 0/1 | 1 | While E is held, report the magazine as full so the engine refuses to reload. True ammo is restored on release. |
| `spoof_time` | 0.5–10.0 | 2.50 | Seconds the magazine is reported full after each inspect, covering the animation. |
| `cancel_grace` | 0.0–2.0 | 0.35 | Grace period, only when R is itself a trigger key. Fire/shove always cancel instantly. |
| `cooldown` | 0.0–10.0 | 1.20 | Seconds between inspects. |
| `melee_ok` | 0/1 | 1 | Allow inspecting melee / clipless items. |
| `debug` | 0/1 | 0 | Verbose console diagnostics. |

Invalid values are rejected individually with a console warning, and the
default is kept — a typo cannot break the addon. After editing, run
`script EBFInspectAmmo.Reload()` or change level.

---

## Multiplayer

VScript runs **server-side**:

- **You host (local/listen server):** works for you and everyone connected.
- **Someone else's server:** that server must have the addon installed. A
  client-side VPK cannot add server behaviour.
- **Dedicated server:** place the VPK in the server's `left4dead2/addons/`.

---

## Compatibility

Loads through `mapspawn_addon.nut`, the sanctioned auto-run hook that runs
*alongside* stock scripts. It does **not** replace `scriptedmode.nut`,
`mapspawn.nut`, or `director_base.nut`, so it coexists with map fixes, the
Community Update, and other script addons.

If you also run another inspect addon, disable one of them — otherwise both
will react to the same keypress.

---

## Uninstall

Delete the `.vpk` from `left4dead2\addons\`. Optionally remove
`left4dead2\ems\ebf_inspect_ammo\`.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| No `[InspectAmmo]` console lines | VPK not loaded. Check it is directly in `left4dead2\addons\` and enabled in the Add-ons list. |
| `FAILED to include ebf_inspect_ammo.nut` | Packed from the wrong folder; `scripts/` must be at the VPK root. |
| Ammo prints but nothing animates | The model has no inspect/reload sequence. Confirm with `Status()`. |
| Chord does nothing | Try `!ammo` in chat first: if that works the script is fine and the chord is either taken or not held long enough. Run `Status()` and watch `combo now`. |
| It really reloads | Run `Status()` and check `trigger mode`. Raise `spoof_time` if a long inspect animation is cut short. |

More detail in [TECHNICAL_NOTES.md](TECHNICAL_NOTES.md) §8.

---

## Layout

```text
test_ammo_inspect/                       <- THIS is what gets packed into the VPK
  addoninfo.txt                          Workshop / add-on list metadata
  scripts/vscripts/mapspawn_addon.nut    Loader (runs every map)
  scripts/vscripts/ebf_inspect_ammo.nut  All logic

build_vpk.bat                            One-click Windows VPK builder
reference/ems/ebf_inspect_ammo/settings.txt   Copy of the generated settings
TECHNICAL_NOTES.md                       Design rationale + debugging notes
README.md / README_zh-CN.md
LICENSE
```

Everything below the blank line is repository documentation and is **not**
part of the VPK.

## License

GNU General Public License v3.0 or later (`GPL-3.0-or-later`), matching the
other project in this repository.
