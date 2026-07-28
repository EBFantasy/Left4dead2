# Smooth recoil: verdict after reading your console.log

Short answer: **the current VScript design cannot be fixed by tuning.** Its two
faults — fighting the mouse, and slow recovery — are the same fault. But this
does **not** mean you need SourceMod. The punch-angle prototype avoids both by
construction. Details and numbers below.

---

## 1. Your log confirms the diagnosis

From `smooth_recoil/console.log`:

```
setter=SnapEyeAngles(vector)          <- confirmed: the script writes eye angles
manual input gate ... x24             <- 24 recorded script-vs-mouse conflicts
```

The conflict samples, in degrees of view movement in a single frame:

| | dYaw |
|---|---|
| min | 0.31 |
| median | 5.07 |
| max | **15.69** |

`manual input gate` only fires when the script notices the player has moved the
view and backs off. 24 hits in one session, peaking at 15.7°/frame, is the
"fights for the mouse" symptom recorded directly.

It also loaded cleanly (`core loaded v0.8.2-ems`, `thinker started
interval=0.03`, `20/20` weapon profiles), so this is not a config problem.

---

## 2. Why it feels *worse* than before, and why recovery is slow

These are the same bug wearing two hats.

The mitigation for mouse-fighting is:

```squirrel
manualReturnFactor = 0.30      // if the player is moving the view,
                               // recover at 30% speed
maxReturnPitchSpeed = 5.4      // hard ceiling, degrees per second
```

So the harder you fight the recoil, the slower it recovers. Measured, recovering
from a 5-round AK burst (peak −8.6°) down to under 0.05°:

| | time to recentre |
|---|---|
| current VScript, mouse still | 1.80 s |
| current VScript, **moving the mouse** | **5.37 s** |
| engine punch spring | **0.77 s** |

The arithmetic is not subtle: 8.6° at a 5.4°/s ceiling is 1.59 s minimum, and
with `manualReturnFactor` applied that ceiling drops to 1.62°/s, i.e. 5.3 s.

That is the whole complaint. And the two settings cannot simply be raised:
`maxReturnPitchSpeed` and `manualReturnFactor` exist *because* the script writes
eye angles. Raise them and every recovery frame yanks the mouse harder. The
design is stuck between "fights the mouse" and "recovers too slowly", and there
is no value that is good at both.

---

## 3. So: is SourceMod required?

**No.** But the current approach must be abandoned, not tuned.

`smooth_recoil_punch.nut` (already in this folder, from last round) writes only:

```
localdata.m_Local.m_vecPunchAngle
localdata.m_Local.m_vecPunchAngleVel
```

Punch is layered *on top of* the eye angle by the engine
(`v_angle = mv->m_vecAngles + m_vecPunchAngle`), and bullets follow it
(`AngleVectors(EyeAngles() + m_vecPunchAngle, ...)`). Since the eye angle is
never written:

- there is nothing to fight over — `manual input gate` cannot occur at all,
  so `manualReturnFactor` is unnecessary and recovery is never slowed;
- recovery is the engine's damped spring: **0.77 s**, versus your 5.37 s;
- the climb is still smooth — measured peak at frame 8 (133 ms) on a
  decelerating curve, not an instant jolt.

### What punch genuinely cannot do

- **The spring constants are compiled in** (`PUNCH_DAMPING 9.0`,
  `PUNCH_SPRING_CONSTANT 65.0`). You get Valve's recovery *shape*. You control
  magnitude, direction and per-shot ramp, not the curve.
- **~0.3° of overshoot** is inherent to a damped spring.
- **No aim-point compensation.** COD returns the view to where you were aiming
  before the burst. Punch returns to zero, which is the same thing only if you
  did not move the mouse.

If the recovery curve or true aim-point compensation is a hard requirement,
that is the point where SourceMod becomes justified — because it can hook
`OnPlayerRunCmd` and modify the usercmd angles *before* prediction, which is
the one thing VScript cannot do and the reason your SourceMod build feels
right.

---

## 4. How to test it (read this before packing)

**The punch prototype is now the default.** Pack and play - there is no
console command to type and no cvar to set.

`mapspawn_addon.nut` has a single switch near the top:

```squirrel
::SR_MODE <- "punch";     // default: the new punch-angle engine
// ::SR_MODE <- "legacy"; // the old SnapEyeAngles core, for comparison
```

`director_base_addon.nut` reads the same value, so there is only one place to
change and no way to accidentally load both cores at once (which would apply
recoil twice).

On load the console prints which engine is active:

```
[SR] mode = punch
[SRP] punch-angle prototype 0.9.0-punch loaded
```

Optional sanity check in the developer console:

```
script SmoothRecoilPunch.Status()    // expect "punch prop : OK"
script SmoothRecoilPunch.TestKick()  // one shot's recoil, without firing
```

If you want to compare against the old behaviour, set `SR_MODE` to `"legacy"`
and repack.

## 5. Recommendation
Judge the feel. If Valve's recovery shape is acceptable, this is a complete
pure-workshop solution and no SourceMod is needed. If you specifically want
your own recovery curve or true aim-point compensation, upload the SourceMod
version and we optimise that instead.

I would not spend more time tuning the `SnapEyeAngles` core. Every knob there
trades one of your two complaints against the other.
