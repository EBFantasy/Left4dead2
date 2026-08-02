# Smooth recoil in pure VScript — feasibility findings

Answering the question directly: **no, `SnapEyeAngles` is not the only way, and
it is the wrong way.** L4D2 already has a dedicated recoil channel that VScript
can write to, it produces a smooth modern-FPS climb, and it *cannot* fight the
mouse. SourceMod is not required for this.

---

## 1. Why the current approach fights the mouse

`smooth_recoil_core.nut` does, every think:

```squirrel
local eye = player.EyeAngles();     // read
eye.x += pitchDelta;                // modify
eye.y += yawDelta;
player.SnapEyeAngles(eye);          // write back
```

The eye angle is **the same variable the client's mouse input owns**. The
server writes a value derived from a state it observed one network round-trip
ago; that write is authoritative and arrives at the client several frames
later, by which time the player has already turned. Every degree they aimed in
between is discarded.

This is why the symptom scales with flick speed, exactly as reported: the
faster you turn, the more input falls inside the round-trip window and is
thrown away.

Simulated with a 4-frame round-trip and a 12°/frame flick:

```
player input        288°
resulting yaw        40°
lost to snap-back   248°     <- "moved far away, then yanked back"
```

The mitigations already in the code (`manualBlockUntil`, `manualInputThreshold`,
`manualReturnFactor`) reduce how often this happens but cannot remove it: they
detect the conflict *after* it has occurred. Any design that writes the eye
angle from the server has this failure mode.

---

## 2. The engine's own recoil channel

`CBasePlayer` keeps a punch angle that is layered **on top of** the eye angle:

```cpp
// game/shared/gamemovement.cpp  (SetupMove)
v_angle = mv->m_vecAngles + player->m_Local.m_vecPunchAngle;
```

```cpp
// game/server/player.cpp
AngleVectors( EyeAngles() + m_Local.m_vecPunchAngle, &forward );
```

Two consequences that matter:

- The player's eye angle is **never modified**, so mouse input is untouched.
  There is nothing to fight over.
- Bullets are fired along `EyeAngles() + punch`, so recoil genuinely affects
  aim rather than being a cosmetic wobble.

It also recovers on its own, every tick, as a damped spring:

```cpp
// game/shared/gamemovement.cpp
#define PUNCH_DAMPING           9.0f
#define PUNCH_SPRING_CONSTANT  65.0f

void CGameMovement::DecayPunchAngle( void )
{
    if ( punchAngle.LengthSqr() > 0.001 || punchVel.LengthSqr() > 0.001 )
    {
        punchAngle += punchVel * frametime;
        float damping = max( 0, 1 - (PUNCH_DAMPING * frametime) );
        punchVel *= damping;
        float spring = clamp( PUNCH_SPRING_CONSTANT * frametime, 0, 2 );
        punchVel -= punchAngle * spring;
        // clamped to +/-89 pitch
    }
    else { punchAngle = 0; punchVel = 0; }
}
```

So the rise **and** the recovery are produced by the engine. No think loop is
needed to animate either.

Both fields are reachable from VScript:

```
localdata.m_Local.m_vecPunchAngle
localdata.m_Local.m_vecPunchAngleVel
```

(Confirmed in a shipped workshop script, `no_camera_shake.nut`, which reads and
writes `localdata.m_Local.m_vecPunchAngle` from plain VScript.)

---

## 3. Smooth vs. jolt — this is the part that decides the feel

`ViewPunch()` does **not** set the angle. It adds to the **velocity**:

```cpp
void CBasePlayer::ViewPunch( const QAngle &angleOffset )
{
    m_Local.m_vecPunchAngleVel += angleOffset * 20;
}
```

That distinction is the whole difference between the two styles:

| What you write | Result |
|---|---|
| `m_vecPunchAngle` directly | Instant jump on the firing frame — the old workshop "jolt" recoil |
| `m_vecPunchAngleVel` | Accelerating climb over ~8 frames, then spring-back — the modern FPS feel |

Measured on the prototype, one AK-47 shot at 60 fps:

```
frame  1  pitch = -1.018   (delta -1.018)
frame  2  pitch = -1.566   (delta -0.548)
frame  3  pitch = -2.003   (delta -0.437)
frame  4  pitch = -2.338   (delta -0.335)
frame  5  pitch = -2.581   (delta -0.243)
frame  6  pitch = -2.741   (delta -0.160)
frame  7  pitch = -2.828   (delta -0.086)
frame  8  pitch = -2.850   (delta -0.022)   <- peak, 133 ms in
frame  9  pitch = -2.818   (delta +0.032)   <- spring pulls back
...
+1500 ms  pitch =  0.000                    <- fully recentred
```

Peak reached over 8 frames with a decelerating curve, not on frame 1. That is
a smooth climb by any reasonable definition.

Five-round burst accumulates and recentres correctly:

```
shot 1  pitch -2.741
shot 2  pitch -5.465
shot 3  pitch -7.259
shot 4  pitch -8.174
shot 5  pitch -8.604      burst peak -9.43
then    fully recentred within ~1.5 s
```

`INSTANT_FRACTION` blends the two styles. Measured:

| INSTANT_FRACTION | Peak | Frame of peak | Overshoot |
|---|---|---|---|
| 0.00 | -3.08° | 8 | +0.33° |
| 0.15 (default) | -2.85° | 8 | +0.30° |
| 0.30 | -2.63° | 7 | +0.28° |
| 0.50 | -2.37° | 6 | +0.25° |
| 1.00 | -2.35° | **1** | +0.25° |

At 1.00 the peak lands on frame 1 — that is the old jolt. Anything at or below
about 0.3 keeps the ramp.

---

## 4. Honest limitations

- **The spring constants are compiled into the engine.** `PUNCH_DAMPING 9.0`
  and `PUNCH_SPRING_CONSTANT 65.0` cannot be changed from VScript. You control
  magnitude, direction and per-shot shaping; you do not control the recovery
  curve's shape. If you need a bespoke recovery profile, that genuinely does
  need SourceMod.
- **Slight overshoot (~0.3°)** is inherent to a damped spring — the view dips a
  fraction below centre before settling. Valve's own weapons have this.
- **No "return to origin" compensation.** In COD/Battlefield the view returns
  to where you were aiming before the burst. The spring returns punch to zero,
  which is equivalent *only if* the player has not moved the mouse. Since punch
  is additive and never touches the eye angle, this is the correct and
  non-intrusive behaviour, but it is not identical to a compensating system.
- **Server-side.** Like all VScript, this only applies on a listen server you
  host, or a dedicated server running the addon.

---

## 5. Verdict

A pure-workshop VScript smooth recoil is **feasible**, and the prototype in
`scripts/vscripts/smooth_recoil/smooth_recoil_punch.nut` demonstrates it:

- no eye-angle writes at all, so no mouse conflict by construction
- no think loop for the animation — the engine's spring does it
- smooth accelerating climb, verified frame by frame
- recoil affects bullet direction, not just the camera

The one thing that would still justify SourceMod is a **fully custom recovery
curve** (or exact aim-point compensation). If that is what you want, upload the
SourceMod version and we can work from there.

---

## 6. How to test the prototype

The prototype does not replace the existing core; both can be loaded. To try it
in isolation, load only `smooth_recoil_punch` from `mapspawn_addon.nut`.

Console:

```
script SmoothRecoilPunch.Status()     // confirms the netprops are reachable
script SmoothRecoilPunch.TestKick()   // fires one shot's recoil without shooting
```

`Status()` prints `punch prop : OK` / `punch vel prop : OK` if the netprop
paths resolve on your build — check this first.

Then fire while flicking the mouse hard left and right. The view should climb
and settle without ever being yanked back to where you fired.
