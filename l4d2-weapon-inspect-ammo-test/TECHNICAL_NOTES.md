# Technical notes — [TEST] Weapon Inspect Ammo Check

This file records *why* the addon is built the way it is, which alternatives
were rejected, and what to check first when something misbehaves. It is meant
to be read alongside `test_ammo_inspect/scripts/vscripts/ebf_inspect_ammo.nut`.

---

## 1. What the feature actually is

Press **E (`+use`) + R (`+reload`)** while holding a weapon:

1. The weapon's own **reload/inspect animation** plays on the viewmodel.
2. The **remaining ammo** is printed to chat and to the centre of the screen.
3. **No reload happens.** Clip and reserve are identical before and after.

Point 3 is the hard part, and most of this document is about it.

---

## 2. Why VScript (VPK) instead of SourceMod

The sibling project in this repository (`l4d2-ragdoll-force-sourcemod`) is a
SourceMod plugin, which needs MetaMod + SourceMod installed and the game run
with `-insecure`.

This addon is a **plain VScript VPK**:

- drop one `.vpk` into `left4dead2/addons/` and it works,
- no `-insecure`, no MetaMod, no SourceMod, VAC stays on,
- it is exactly the packaging the request asked for.

The trade-off is that VScript is **server-side**. See §7.

---

## 3. Loading without breaking other addons

L4D2 has no "autoexec" folder for scripts. Historically, mods hijacked
`scriptedmode.nut` or `mapspawn.nut`, which made them mutually exclusive and
turned addons red in the addon list.

Valve added `*_addon.nut` variants that load **alongside** the stock file
instead of replacing it. This addon uses:

```
scripts/vscripts/mapspawn_addon.nut     <- 12-line loader, runs once per chapter
scripts/vscripts/ebf_inspect_ammo.nut   <- all the logic
```

`mapspawn_addon.nut` runs in the **root table** scope, on every map, in every
game mode. It does nothing but `IncludeScript("ebf_inspect_ammo", getroottable())`
inside a `try/catch`, so a failure prints a clear reason instead of dying
silently.

Deliberately **not** used:

| Approach | Why rejected |
|---|---|
| Replacing `scriptedmode.nut` | Breaks every other script addon. |
| Replacing `mapspawn.nut` | Overrides the Community Update's map fixes. |
| A mutation / mode script | Would only run in that one mode. |
| `director_base_addon.nut` | Wrong scope, runs twice per round. |

Because `mapspawn_addon.nut` can run more than once per session (and dedicated
servers re-run it per chapter), the script is wrapped in a **load guard**: on a
second execution it re-arms the think entity instead of building a second one.

---

## 4. Reading the input

The polling loop is driven by one `info_target` with a think function attached
via `AddThinkToEnt`, returning `0.0` so it runs every frame. This is the same
pattern used by well-tested community scripts (e.g. samisalreadytaken's ping
system).

Buttons come from `CTerrorPlayer::GetButtonMask()`:

| Bit | Constant |
|---:|---|
| 32 | `IN_USE` (E) |
| 8192 | `IN_RELOAD` (R) |

Edge detection matters. The mask reports keys **held**, so testing it raw would
fire every frame R is down. The script stores `lastButtons` per player and acts
only on the **rising edge**:

```squirrel
local pressed = buttons & (~state.lastButtons);
state.lastButtons = buttons;
if (!(pressed & IN_RELOAD)) continue;      // R must have just gone down
if (Settings.require_use && !(buttons & IN_USE)) continue;   // E must be held
```

E is tested as *held* (level), R as *just pressed* (edge) — which is what
"hold E, tap R" means physically. A per-player cooldown (default 1.2 s) stops
animation spam.

**Why not a bind or `UserConsoleCommand`?** A `bind` would need the user to
edit their config, and `UserConsoleCommand` requires Scripted Mode, which is
mutation-only and conflict-prone. Polling the button mask needs zero setup
from the player.

---

## 5. Playing the animation (the interesting part)

### What "inspect" means in L4D2

Vanilla L4D2 has **no inspect animation**. What players call an inspect
animation comes from custom weapon models ported from other games, where the
author attaches it to an existing activity — very often the **reload**, so it
plays when you press R on a full magazine.

So "trigger the inspect animation" concretely means: **make the weapon play its
reload animation, without reloading.**

### How the animation is forced

The viewmodel exposes an animation *layer* that can be driven directly:

```squirrel
local vm = NetProps.GetPropEntity(player, "m_hViewModel");
NetProps.SetPropInt  (vm, "m_nLayerSequence",  seq);
NetProps.SetPropInt  (vm, "m_nLayer",          0);
NetProps.SetPropFloat(vm, "m_flLayerStartTime", Time());
```

This is the documented community technique for first-person animations in
L4D2 (the same netprops the AlliedModders viewmodel plugins use).

`m_nLayerAnimationParity` is also bumped (`(parity + 1) & 0x3`) so that
requesting the *same* sequence twice in a row still replays it, rather than the
client deciding nothing changed.

### Sequence selection

`LookupSequence()` resolves a name to an ID, or `-1`. The script tries, in
order:

1. **Dedicated inspect names** — `inspect`, `ACT_VM_INSPECT`, `idle_inspect`,
   `inspect_start`, `lookat01`. Custom models that ship a real inspect
   animation get their proper animation.
2. **Reload names** — `ACT_VM_RELOAD`, `reload`, `ACT_SHOTGUN_RELOAD_START`.
   This is the full-magazine-R behaviour the request described, and it is what
   stock weapons fall back to.

If neither exists, the ammo readout still prints and a console line explains
that the model has no animation to show. A missing animation never blocks the
ammo output.

> A model can only play sequences that exist **in that model**. No script can
> make a stock M16 perform an inspect that was never compiled into it. This is
> a hard engine limit, not a bug in the addon.

---

## 6. Making sure it is *not* a reload

This is the requirement that needed the most care, and the first release got
it wrong. Recording both the failure and the fix, because the reasoning
matters.

### What failed in v1.0.0

The original design was *reactive*: let the reload start, then snapshot
`m_iClip1` / `m_iAmmo` and restore them for `guard_ticks` (8) frames.

That cannot work. **An L4D2 reload is not instantaneous** — it completes at
the end of a 2-3 second animation. Eight frames is roughly 0.12 s, so the
guard had long expired by the time the engine actually refilled the magazine.

The bug was invisible on a *full* magazine, because the engine never starts a
reload there, which is exactly the case that got tested first. With a
partially empty magazine, E+R reloaded normally.

### What works now: suppress the key, do not undo the reload

`m_afButtonDisabled` is a per-player bit mask the engine consults while
building the usercmd. Any bit set in it is stripped from the player's input
**before** `CTerrorGun::Reload()` is ever reached.

So while the modifier (E) is held, the script sets the `IN_RELOAD` bit:

```squirrel
mask = NetProps.GetPropInt(player, "m_afButtonDisabled");
NetProps.SetPropInt(player, "m_afButtonDisabled", mask | IN_RELOAD);
```

The reload never begins, so there is nothing to undo and nothing to race.
Releasing E clears the bit immediately.

The bit is only ever OR'd in and AND'd out, so other scripts using
`m_afButtonDisabled` for their own bits are unaffected (verified by test).

### The complication this creates

Once `IN_RELOAD` is suppressed, `GetButtonMask()` no longer reports the R
press — the script would blind itself to the very input it is looking for.

`m_nButtons` holds the **unfiltered** input, so edge detection reads that
instead. Availability is probed once and cached in `HaveRawButtons`.

### Fallback when raw input is unavailable

If `m_nButtons` cannot be read, preemptive suppression is *not* used, because
blocking the key without being able to see it would permanently disable
reloading. The script logs one line and falls back to cancellation:

- clear `m_bInReload` every frame for `cancel_window` seconds (default 3.0,
  covering the whole animation rather than a few frames),
- restore clip and reserve,
- reset the shotgun-specific state (`m_reloadState`, `m_reloadAnimState`,
  `m_reloadNumShells`, `m_shellsInserted`), which shell-by-shell reloads need,
- on the final pass clear `m_bInReload` and reset `m_flNextPrimaryAttack` /
  `m_flTimeWeaponIdle` / `m_flNextAttack` so the weapon is not left stuck
  mid-reload and unable to fire.

Both paths are covered by tests. The design **fails safe**: the worst case is
an ordinary reload, never a weapon that cannot fire or reload.

### Safety: never strand the player

A disabled reload key would be a serious bug if it leaked. The bit is force
cleared when the player dies, is incapacitated, hangs from a ledge, stops
being a survivor, when the addon is disabled at runtime, and on
`Reload()` before per-player state is wiped.

## 7. Multiplayer scope (please read before reporting a bug)

VScript runs **on the server**.

- **Local / listen server (you host):** works for you and everyone connected.
- **Someone else's server:** the server must run the addon. A client-side VPK
  cannot add server behaviour. This is the same limitation every VScript addon
  has, including the popular workshop inspect mods.
- **Dedicated server:** put the VPK in the server's `left4dead2/addons/`.

---

## 8. Diagnostics

Open the developer console (`Options → Keyboard/Mouse → Allow Developer
Console`, then `` ` ``).

On a normal load you will see:

```
[InspectAmmo] Loaded N setting(s) from ems/ebf_inspect_ammo/settings.txt
[InspectAmmo] Manager entity active (index NN).
[InspectAmmo] Version 1.0.0 ready. Hold E and tap R to inspect.
```

If those lines are absent, the script never ran — the VPK is not being loaded.

### Commands

| Command | Purpose |
|---|---|
| `script EBFInspectAmmo.Status()` | Full dump: settings, current weapon, ammo, viewmodel path, **which animation sequences that model actually has**, and the **reload-key suppression state** (`m_afButtonDisabled`). |
| `script EBFInspectAmmo.TestFire()` | Runs one inspect on the host with verbose output. Proves the logic works without needing the key combo. |
| `script EBFInspectAmmo.Reload()` | Re-reads the EMS settings file without a map change. |

`Status()` is the fastest way to answer "is the animation missing, or is the
script broken?" — if it reports `reload anim : none`, the model has nothing to
play and the script is fine.

Set `debug 1` in the settings file for per-press tracing (cooldown hits,
aborted reloads, sequence choices).

### Troubleshooting

| Symptom | Cause / fix |
|---|---|
| No `[InspectAmmo]` lines at all | VPK not loaded. Check it is directly in `left4dead2/addons/`, and enabled in the in-game Add-ons list. |
| `FAILED to include ebf_inspect_ammo.nut` | VPK packed from the wrong folder — `scripts/vscripts/` must be at the VPK root, not nested. |
| Ammo prints, nothing animates | Model has no inspect/reload sequence. Confirm with `Status()`. Expected on stock models. |
| Nothing happens on E+R | Another addon may bind those keys; or you are on someone else's server (§7). Try `TestFire()`. |
| It actually reloads | Run `Status()` and check `reload key`. While E is held it must say `BLOCKED`. If it says `m_nButtons unavailable` the fallback is in use; raise `cancel_window`. |
| Want R alone | Set `require_use 0` — but this interferes with normal reloading. |

---

## 9. Configuration

Generated on first run at `left4dead2/ems/ebf_inspect_ammo/settings.txt`
(a reference copy is in `reference/ems/`). Format: `key value`, `//` comments.

`enable`, `require_use`, `output_chat`, `output_center`, `play_animation`,
`block_reload`, `guard_ticks`, `cancel_window`, `cooldown`, `melee_ok`,
`debug`.

Every value is **range-checked**. Out-of-range, non-numeric, and unknown keys
are rejected with a specific console warning and the default is kept, so a
typo degrades one setting instead of breaking the addon. Deleting a line
restores its default on the next load.

---

## 10. Squirrel gotchas hit while writing this

Recorded because they cost real debugging time:

- **`return` alone on a line returns `null`.** Squirrel terminates the
  statement at the newline, so
  ```squirrel
  return
      "text";
  ```
  silently returns `null`. This bug was caught by the offline test harness —
  it made the settings file write as `null`. The value must start on the same
  line as `return`. There is a comment in the source at that spot.
- **`.tofloat()` throws** on a malformed string rather than returning a
  sentinel, so every parse is wrapped in `try/catch`.
- **`FileToString` returns `null`** for a missing file and reads relative to
  `left4dead2/ems/`. It also *creates missing folders* in the path.
- **Entity handles go stale.** Every stored handle is re-checked with
  `IsValid()` before use; the guard holds a weapon handle across frames and the
  weapon can be dropped in between.

---

## 11. How this was verified without the game

There is no L4D2 in the build environment, so correctness was established by
compiling and executing the script against a mock:

1. **Syntax** — the real Squirrel 3.0.4 compiler (the same language version
   L4D2 embeds, per `_version_`) was built from source and run over both
   `.nut` files with `sq -c`. Both compile clean.
2. **Behaviour** — a mock harness implements `NetProps`, `Entities`,
   `ClientPrint`, `AddThinkToEnt`, `FileToString`/`StringToFile`, `Time`, and
   fake player/weapon/viewmodel entities, then drives the real think function.

Scenarios covered, all passing:

- R alone does **not** inspect when `require_use 1`
- E+R **does** inspect; chat + centre output correct
- correct sequence chosen; parity increments
- **a simulated engine reload is fully undone** — clip `17`, reserve `200`, and
  `m_bInReload 0` all restored
- cooldown suppresses repeats, then allows again
- dead / incapacitated players are skipped
- melee reports "no magazine"
- settings parsing: valid override applied; out-of-range, unknown, and
  non-numeric values each rejected with a warning
- `Reload()` re-reads and reverts removed keys
- double-load guard creates only one manager entity

What the harness **cannot** prove: that the netprop names behave identically
inside the real engine, and how any specific custom model's animation looks.
Those need an in-game check — `Status()` and `TestFire()` exist to make that
check quick.
