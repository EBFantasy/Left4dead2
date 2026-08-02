//-----------------------------------------------------------------------------
// Smooth Recoil - punch-angle engine (v0.9.16-punch)
//
// PURPOSE
// Proves that smooth, COD/Battlefield-style recoil is achievable in pure
// VScript WITHOUT ever writing the player's eye angles, and therefore without
// fighting the mouse.
//
// WHY THE OLD APPROACH FIGHTS THE MOUSE
// smooth_recoil_core.nut does read -> add offset -> SnapEyeAngles(write back).
// The eye angle is the SAME variable the client's mouse input owns. The server
// writes a value derived from a state it saw one round-trip ago, that write is
// authoritative, and it lands on the client several frames later - by which
// time the player has already turned. Everything they aimed in between is
// discarded. That is exactly the "view snaps back to where I fired" symptom,
// and it gets worse the faster you flick, which matches the report.
//
// THE ENGINE ALREADY HAS A RECOIL CHANNEL
// CBasePlayer keeps a punch angle that is layered ON TOP of the eye angle and
// is never owned by mouse input:
//
//   game/shared/gamemovement.cpp
//     v_angle = mv->m_vecAngles + player->m_Local.m_vecPunchAngle;
//
//   game/server/player.cpp
//     AngleVectors(EyeAngles() + m_Local.m_vecPunchAngle, &forward);
//       -> bullets follow the punch, so recoil actually affects aim
//
// It also self-recovers as a damped spring, every tick, in DecayPunchAngle():
//
//   m_vecPunchAngle    += m_vecPunchAngleVel * frametime
//   m_vecPunchAngleVel *= 1 - (9.0 * frametime)          // PUNCH_DAMPING
//   m_vecPunchAngleVel -= m_vecPunchAngle * min(65.0*frametime, 2.0)
//                                                        // PUNCH_SPRING_CONSTANT
//
// So we do not need a think loop to animate the rise or the recovery at all.
// We push velocity once per shot and the engine produces a smooth curve.
// Both fields are reachable from VScript as:
//   localdata.m_Local.m_vecPunchAngle
//   localdata.m_Local.m_vecPunchAngleVel
//
// WHAT THIS MEANS FOR FEEL
// Writing m_vecPunchAngleVel (what ViewPunch does) gives a smooth accelerating
// climb - the modern-FPS feel. Writing m_vecPunchAngle directly is the instant
// jolt that the older workshop mods have. This file uses velocity, with an
// optional small direct component for a crisper "kick" onset.
//
// LIMITATION, STATED HONESTLY
// The spring constants are compiled into the engine and cannot be changed from
// VScript. Recovery therefore always uses Valve's damping curve. We control
// magnitude, direction and per-shot shaping, not the recovery profile itself.
// If you need a fully custom recovery curve, that needs SourceMod.
//-----------------------------------------------------------------------------

if (!("SmoothRecoilPunch" in getroottable())) {
	::SmoothRecoilPunch <- {};
}

::SmoothRecoilPunch.rawset("VERSION", "0.9.16-punch");
::SmoothRecoilPunch.rawset("DEBUG", false);

// Integration contract with ads_base.nut. When this is true, smooth recoil is
// the only writer of aimed punch; the ADS addon keeps its animation/FOV work
// but skips its deferred RecoilFactor rewrite.
::SmoothRecoilPunch.rawset("OWNS_ADS_RECOIL", true);
// ADS strength is selected by weapon group. The released workshop ADS addon's
// delayed punch writer is neutralized below, so these are the final effective
// multipliers rather than values that are halved a second time.
::SmoothRecoilPunch.rawset("ADS_KICK_SCALE", 0.70);
::SmoothRecoilPunch.rawset("ADS_SINGLE_KICK_SCALE", 0.60);
::SmoothRecoilPunch.rawset("ADS_GRENADE_KICK_SCALE", 0.80);
::SmoothRecoilPunch.rawset("_adsCompatibilityLogged", false);

// Player-posture multipliers. Standing run is the existing recoil baseline.
// These scale the shot kick and sustained-fire climb, not the safety ceiling.
::SmoothRecoilPunch.rawset("POSTURE_DEFAULTS", {
	crouch_idle = 0.72,
	crouch_walk = 0.78,
	stand_idle = 0.84,
	stand_walk = 0.92,
	stand_run = 1.00,
	airborne = 1.15
});
::SmoothRecoilPunch.rawset("POSTURE_ORDER", [
	"crouch_idle",
	"crouch_walk",
	"stand_idle",
	"stand_walk",
	"stand_run",
	"airborne"
]);
::SmoothRecoilPunch.rawset("WALK_BUTTON", 1 << 17);
::SmoothRecoilPunch.rawset("MOVE_SPEED_EPSILON_SQ", 400.0);

// Netprop paths. The "localdata." prefix is required: these live in the
// player's private local data table.
::SmoothRecoilPunch.rawset("PROP_PUNCH", "localdata.m_Local.m_vecPunchAngle");
::SmoothRecoilPunch.rawset("PROP_PUNCH_VEL", "localdata.m_Local.m_vecPunchAngleVel");

//-----------------------------------------------------------------------------
// Tuning
//-----------------------------------------------------------------------------
// ViewPunch() multiplies the requested angle by 20 before adding it to the
// velocity. We reproduce that so the numbers below read like degrees.
::SmoothRecoilPunch.rawset("VEL_SCALE", 20.0);

// Fraction of the kick applied as instant angle rather than velocity.
// 0.0 = fully smooth ramp (modern FPS). 0.25 or so adds a crisper onset.
// v0.9.3: the kick is written straight into the punch ANGLE, so there is no
// longer an instant-vs-ramp split. Retained only so old configs do not error.
::SmoothRecoilPunch.rawset("INSTANT_FRACTION", 0.0);

// Extra velocity added alongside the angle.
//
// v0.9.4 - REDUCED, and the clamp tightened from 400 to VEL_CLAMP.
//
// The readback proved this was running away. Across one m60 burst the stored
// velocity went -77 -> -400 and then sat at -400 permanently, never decaying.
// The engine integrates that every tick inside DecayPunchAngle:
//
//     m_vecPunchAngle += m_vecPunchAngleVel * frametime
//     -400 * 0.015 = -6 degrees PER TICK
//
// so between two shots the angle shot far past our ceiling, and the next
// shot's write yanked it back to the clamp. Overshoot, snap back, overshoot -
// that is the "some shots jump hard" feel, and it is why the jump was
// intermittent rather than every shot.
//
// A small bounded value still gives the smooth accelerating onset that makes
// this feel like a modern shooter, but now it decays instead of saturating.
// v0.9.6: DISABLED. This is the cause of the "sudden surge partway through a
// burst" report, and the log is unambiguous about it.
//
// Velocity saturated at the clamp on 47% of all shots. Once pinned, the engine
// keeps integrating a constant -110 into the angle every tick while the spring
// simultaneously pulls back, so how far the view actually moves per shot stops
// depending on the shot at all and starts depending on where in the tick the
// round happened to land. Measured ADS steps ran
//
//     1.22  ->  2.38  ->  0.26  ->  0.35  ->  0.44  ->  1.54  ->  2.60
//
// i.e. step/request wandered between 0.09x and 10.62x - a 117-fold spread.
// That is precisely "it suddenly jumps hard partway through, and it does not
// feel connected to what I am doing".
//
// The angle write alone is smooth, predictable and already produces the climb.
// The velocity assist only ever added noise, so it is off. Kept as a tunable
// rather than deleted so the behaviour can be compared if ever needed.
::SmoothRecoilPunch.rawset("VEL_ASSIST", 0.0);
::SmoothRecoilPunch.rawset("VEL_CLAMP", 110.0);

// Per-shot climb, in degrees. Negative pitch moves the view UP.
// Reused from the existing core so the feel stays comparable.
::SmoothRecoilPunch.rawset("kick", {
	pistol = -1.15,
	magnum = -2.05,
	smg = -0.95,
	smg_silenced = -0.80,
	mp5 = -1.08,
	rifle_m16 = -1.20,
	rifle_desert = -1.45,
	rifle_sg552 = -1.60,
	rifle_ak47 = -2.35,
	pumpshotgun = -7.00,
	chrome_shotgun = -7.00,
	autoshotgun = -2.80,
	shotgun_spas = -4.20,
	hunting_rifle = -2.60,
	sniper_military = -2.25,
	scout = -9.50,
	awp = -12.00,
	m60 = -2.90,
	grenade_launcher = -12.00,
	default_weapon = -1.00
});

// Horizontal sway magnitude per shot, in degrees.
::SmoothRecoilPunch.rawset("yaw", {
	pistol = 0.13,
	magnum = 0.16,
	smg = 0.24,
	smg_silenced = 0.20,
	mp5 = 0.26,
	rifle_m16 = 0.28,
	rifle_desert = 0.34,
	rifle_sg552 = 0.38,
	rifle_ak47 = 0.62,
	pumpshotgun = 0.50,
	chrome_shotgun = 0.48,
	autoshotgun = 0.40,
	shotgun_spas = 0.44,
	hunting_rifle = 0.22,
	sniper_military = 0.20,
	scout = 0.18,
	awp = 0.16,
	m60 = 0.46,
	grenade_launcher = 0.12,
	default_weapon = 0.24
});

// Sustained fire grows the climb, like a real spray pattern.
::SmoothRecoilPunch.rawset("RAMP_PER_SHOT", 0.09);   // +9% per shot in a burst
::SmoothRecoilPunch.rawset("RAMP_MAX", 2.20);        // capped at 220%
::SmoothRecoilPunch.rawset("BURST_RESET", 0.35);     // seconds of quiet to reset

// Safety ceiling so a bad config can never throw the view to the sky.
//
// v0.9.4: this is now a SOFT ceiling, not a wall.
//
// The m60 trace shows exactly why the old hard clamp was wrong. Shots 1-10
// climbed normally, shot 11 hit -24.0, and shots 12 through 22 produced a
// step of EXACTLY 0.00 degrees - eleven consecutive rounds with no visible
// recoil at all. Firing feels like it "locks up" partway through a long burst.
//
// SOFT_START is where compression begins. Between SOFT_START and MAX_PITCH the
// remaining headroom is approached asymptotically, so late shots in a long
// burst still move the view a little instead of doing nothing.
::SmoothRecoilPunch.rawset("MAX_PITCH", 24.0);
::SmoothRecoilPunch.rawset("SOFT_START", 13.0);

//-----------------------------------------------------------------------------
// Sustained-fire climb  (v0.9.5)
//
// WHAT THIS FIXES
// The peak elevation of a long burst was too low, especially while aiming.
//
// WHY RAISING PER-SHOT STRENGTH IS THE WRONG ANSWER
// The engine spring pulls back in proportion to the CURRENT angle:
//
//     m_vecPunchAngleVel -= m_vecPunchAngle * min(65.0*frametime, 2.0)
//
// so during sustained fire the view parks at the equilibrium where per-shot
// push equals spring pull. Measured from the tuning in this file that lands at
// about 3.7 degrees for the SCAR and 6.4 for the m60 - nowhere near MAX_PITCH
// (24). The ceiling was never a clamp; it is the spring balance. Turning up
// the per-shot kick does raise it, but it also makes every individual shot
// snappier, which is not what was asked for.
//
// WHAT THIS DOES INSTEAD
// Adds a small extra pitch that grows with the length of the burst and decays
// once firing stops. Shot 1 is completely untouched, so tap-firing and the
// first round of a burst feel exactly as before, while a held trigger walks
// the view visibly higher.
//
// AIMED FIRE ONLY.
//
// CLIMB_HIP is deliberately 0: hip-fire recoil was reported as already correct,
// so nothing about it changes. Only the aimed case is corrected.
//
// Why the aimed ceiling alone was too low in older builds: ads_base.nut rewrote
// every aimed shot as
//     last_recoil + (thisShot * RecoilFactor)
// with RecoilFactor at its stock 0.5, so half of each aimed shot's climb is
// discarded. The spring then balances that weaker push at a much lower angle -
// about 3.7 degrees aiming against 6.1 hip for the SCAR. Restoring the height
// here, rather than by raising RecoilFactor, is what keeps aimed SINGLE-shot
// recoil at the calmer value the ADS addon is meant to give: this term is zero
// on shot 1 and only grows as a burst is held.
//
// The laser case needs no separate handling. The laser sight is what
// SpreadReduce hands out on entering ADS, so it is the same ads_on state and
// the same halved code path.
::SmoothRecoilPunch.rawset("CLIMB_HIP", 0.0);    // hip-fire: unchanged, do not tune
::SmoothRecoilPunch.rawset("CLIMB_ADS", 0.0);    // see ADS_SMOOTH below
::SmoothRecoilPunch.rawset("CLIMB_SHOTS", 9.0);  // rounds to reach full climb

//-----------------------------------------------------------------------------
// ADS surge suppression  (v0.9.7)
//
// The reported mid-burst surge while aiming is REAL - it is not an illusion.
// Measured from the log, m60 aimed steps ran:
//
//   0.83  0.30  0.48  0.66  0.81  0.92  1.01  1.05  0.48  3.48  3.31
//                                                          ^^^^ 7.2x jump
//
// and note vel was 0.0 on every one of those shots, so unlike the previous
// occurrence this is NOT the velocity assist. The cause is different:
//
// ads_base.nut rewrites the punch angle from an ANIMATION callback, not once
// per shot:
//     Recoil = last_recoil + (PunchAngle - last_recoil) * RecoilFactor
// During sustained fire the animation pass cannot keep up with the rounds, so
// most shots land only 9-19% of what was requested while the addon holds a
// stale last_recoil - then one pass finally observes the whole accumulated
// difference and applies 63% of it in a single frame. That lump is the surge.
//
// Adding CLIMB_ADS on top made it worse: it inflated the very difference the
// addon later dumps in one go. So CLIMB_ADS is now 0 - stacking a second climb
// on a system that is already fighting itself cannot be tuned into smoothness.
//
// v0.9.8 stopped writing in ADS to avoid the two-writer conflict. That removed
// the clustering, but ads_base only scales existing punch and does not create
// any, so aimed recoil disappeared. v0.9.9 instead makes this script the sole
// writer and applies the old 0.5 ADS strength here before the punch is written.
//
// The bullet-hole photo settled this: aimed fire lands in three tight CLUSTERS
// with large gaps between them, not a smooth climb. Replaying the log confirms
// it numerically - shots 1-7 all land inside a 4 degree band, then the view
// jumps 3.48 and 3.31 degrees in consecutive shots.
//
// The cause is two systems writing localdata.m_Local.m_vecPunchAngle at once.
// ads_base.nut does, from an animation callback:
//
//     Recoil = last_recoil + (PunchAngle - last_recoil) * RecoilFactor
//
// It samples last_recoil at fire time and rewrites the angle when the animation
// pass runs. Our per-shot writes land in between. While the animation lags, our
// climb is repeatedly pulled back toward a stale last_recoil - so several shots
// pile up at nearly the same angle, which is one cluster. When the pass finally
// catches up it applies the whole accumulated difference at once - that is the
// gap to the next cluster.
//
// Clamping the symptom cannot fix this. Patched ADS builds observe
// OWNS_ADS_RECOIL; v0.9.12 also forces the released workshop build's public
// RecoilFactor to 1.0. Both routes leave this script as the sole punch writer.
//
// Hip-fire is untouched and keeps the full smooth-recoil behaviour.
::SmoothRecoilPunch.rawset("ADS_HANDS_OFF", false);

::SmoothRecoilPunch.rawset("ADS_SMOOTH", false);
::SmoothRecoilPunch.rawset("ADS_MAX_STEP", 1.60);  // hard ceiling, degrees/frame

// A hard ceiling alone still allows 0.48 -> 1.60, a 3.3x jump that is felt.
// This also caps each frame at a MULTIPLE of the previous one, so the strength
// can only ever grow gradually. Replaying the real logged m60 sequence:
//
//   raw            0.82 0.30 0.48 0.66 0.81 0.92 1.01 1.05 0.48 3.48 3.31
//   ceiling only   ...                                       0.48 1.60 1.60
//   + growth cap   ...                                       0.48 0.72 1.08
//
//   worst adjacent jump:  7.2x raw  ->  3.3x ceiling  ->  1.5x with growth cap
//
// Nothing is discarded in any of these - the excess becomes debt and is repaid
// on later frames, so the burst still tops out at the same height.
::SmoothRecoilPunch.rawset("ADS_GROWTH", 1.50);    // max x previous frame
::SmoothRecoilPunch.rawset("ADS_FLOOR", 0.45);     // always allow at least this

//-----------------------------------------------------------------------------
// Slow recovery for single-shot weapons  (v0.9.6)
//
// THE PROBLEM
// On the AWP, Scout, chrome shotgun and pump shotgun the view snapped back down
// almost immediately, so the recoil barely registered.
//
// WHY THE OBVIOUS FIXES DO NOT WORK
// Recovery is the engine's damped spring, and both of its constants are
// compiled in and unreachable from VScript:
//     PUNCH_DAMPING          9.0
//     PUNCH_SPRING_CONSTANT 65.0
// Measured, every weapon returns to 10% of its peak in the SAME 283ms no matter
// how hard it kicked - the curve's shape is independent of amplitude. So simply
// raising these weapons' recoil makes them climb higher but recover exactly as
// fast, which is not what was asked for.
//
// THE METHOD THAT DOES WORK
// The spring is re-evaluated every tick from the CURRENT angle, so if we give
// a little of it back each frame we flatten the top of the curve without ever
// fighting the mouse - this still only touches the punch angle, never the eye
// angle. For HOLD_FRAMES frames after the shot, HOLD_FRACTION of whatever the
// spring just removed is restored:
//
//     AWP recovery to 10%:  283ms stock  ->  467ms held   (1.6x slower)
//
// The view hangs at the top for a beat and then falls away naturally, which
// reads as a heavy weapon rather than a twitchy one.
//
// Deliberately limited to these four. Pistols are explicitly excluded, as are
// all automatics - on a fast weapon a hold would stack across shots.
// v0.9.7: the hold now FADES OUT instead of ending abruptly.
//
// This was my error and it produced exactly the reported "the view stalls, then
// suddenly starts recovering". With a constant fraction that simply stops at
// HOLD_FRAMES, the AWP recovers at 0.114 deg/frame for 18 frames and then jumps
// straight to 0.463 - a 4.1x discontinuity, and a 6.76x worst-case step between
// two adjacent frames. The stall was real and it was mine.
//
// The give-back now decays along a smoothstep, reaching zero exactly as the
// hold expires, so the curve rejoins the spring with no corner at all:
//
//                       worst adjacent-frame step   recovery to 10%
//   stock, no hold                     1.83x               267ms
//   v0.9.6 (hard cut-off)              6.76x               433ms   <- the stall
//   v0.9.7 (faded)                     1.10x               467ms
//
// So it is now smoother than stock while still recovering 1.75x slower.
::SmoothRecoilPunch.rawset("HOLD_FRAMES", 36);
::SmoothRecoilPunch.rawset("HOLD_FRACTION", 0.90);

// v0.9.11: disabled for release. The hold rewrites the predicted punch angle
// every server frame. On single-shot weapons those corrections arrive during
// the whole return and look like frame drops, while automatic weapons never
// enter this branch. Native DecayPunchAngle recovery is client-predicted and
// smooth, so the release build performs no script writes during recovery.
// Keep the old implementation behind a switch for controlled comparisons.
::SmoothRecoilPunch.rawset("MANUAL_SINGLE_RECOVERY", false);

::SmoothRecoilPunch.rawset("slowRecovery", {
	awp = true,
	scout = true,
	chrome_shotgun = true,
	pumpshotgun = true
});

// Anomaly backstop: the largest single-frame climb allowed, as a MULTIPLE of
// the weapon's own base kick.
//
// This is deliberately relative rather than a fixed number of degrees. A flat
// cap that suits the pistol would erase the m60's spray growth completely, and
// one that suits the m60 would never catch a pistol double-step.
//
// The real double-application is fixed at source (Tick now pays out one round
// per frame), so this only has to catch anything that still slips through -
// a doubled kick would arrive at about 2.0x base, well above this line.
::SmoothRecoilPunch.rawset("MAX_STEP_FACTOR", 1.45);

// v0.9.2: the re-assert experiment is REMOVED.
//
// Your readback log proved the write lands and the client honours it:
//   shot#1 ang=(-2.05)  shot#6 ang=(-8.04)
// so nothing was being overwritten and re-asserting was never needed.
//
// Worse, re-writing the stored velocity every frame stopped the engine from
// damping it. The log shows vel climbing -19 -> -40 -> -63 ... -322 and never
// decaying, which is precisely the reported "climb stutters, then pauses, then
// recovery starts far too late".

::SmoothRecoilPunch.rawset("_players", {});
::SmoothRecoilPunch.rawset("_shotLogs", 0);
::SmoothRecoilPunch.rawset("SHOT_LOG_LIMIT", 180);
::SmoothRecoilPunch.rawset("POSTURE_DIAGNOSTICS", true);
::SmoothRecoilPunch.rawset("POSTURE_LOG_LIMIT_PER_PLAYER", 36);

//-----------------------------------------------------------------------------
// Helpers
//-----------------------------------------------------------------------------
::SmoothRecoilPunch.rawset("Log", function (msg) {
	printl("[SRP] " + msg);
});

::SmoothRecoilPunch.rawset("Dbg", function (msg) {
	if (::SmoothRecoilPunch.DEBUG) {
		printl("[SRP][dbg] " + msg);
	}
});

//-----------------------------------------------------------------------------
// EMS per-weapon tuning
//-----------------------------------------------------------------------------
::SmoothRecoilPunch.rawset("EMS_CONFIG_PATH", "smooth_recoil/punch_settings.txt");
::SmoothRecoilPunch.rawset("_emsConfigLoaded", false);
::SmoothRecoilPunch.rawset("_emsLoadedProfiles", 0);
::SmoothRecoilPunch.rawset("PROFILE_ORDER", [
	"pistol",
	"magnum",
	"smg",
	"smg_silenced",
	"mp5",
	"rifle_m16",
	"rifle_desert",
	"rifle_sg552",
	"rifle_ak47",
	"pumpshotgun",
	"chrome_shotgun",
	"autoshotgun",
	"shotgun_spas",
	"hunting_rifle",
	"sniper_military",
	"scout",
	"awp",
	"m60",
	"grenade_launcher",
	"default_weapon"
]);

::SmoothRecoilPunch.rawset("_factoryKick", {});
foreach (profile, value in ::SmoothRecoilPunch.kick)
	::SmoothRecoilPunch._factoryKick[profile] <- value;

::SmoothRecoilPunch.rawset("profileAdsScale", {});
::SmoothRecoilPunch.rawset("profileMaxPitch", {});
::SmoothRecoilPunch.rawset("profileYawScale", {});
::SmoothRecoilPunch.rawset("profileRampScale", {});
::SmoothRecoilPunch.rawset("postureScale", {});

::SmoothRecoilPunch.rawset("DefaultAdsScale", function (profile) {
	if (profile == "grenade_launcher")
		return ::SmoothRecoilPunch.ADS_GRENADE_KICK_SCALE;
	if (profile in ::SmoothRecoilPunch.slowRecovery)
		return ::SmoothRecoilPunch.ADS_SINGLE_KICK_SCALE;
	return ::SmoothRecoilPunch.ADS_KICK_SCALE;
});

::SmoothRecoilPunch.rawset("ResetEmsProfiles", function () {
	::SmoothRecoilPunch.profileAdsScale.clear();
	::SmoothRecoilPunch.profileMaxPitch.clear();
	::SmoothRecoilPunch.profileYawScale.clear();
	::SmoothRecoilPunch.profileRampScale.clear();
	::SmoothRecoilPunch.postureScale.clear();

	foreach (posture in ::SmoothRecoilPunch.POSTURE_ORDER)
		::SmoothRecoilPunch.postureScale[posture] <- ::SmoothRecoilPunch.POSTURE_DEFAULTS[posture];

	foreach (profile in ::SmoothRecoilPunch.PROFILE_ORDER) {
		if (!(profile in ::SmoothRecoilPunch._factoryKick))
			continue;
		::SmoothRecoilPunch.kick[profile] = ::SmoothRecoilPunch._factoryKick[profile];
		::SmoothRecoilPunch.profileAdsScale[profile] <- ::SmoothRecoilPunch.DefaultAdsScale(profile);
		::SmoothRecoilPunch.profileMaxPitch[profile] <- ::SmoothRecoilPunch.MAX_PITCH;
		::SmoothRecoilPunch.profileYawScale[profile] <- 1.0;
		::SmoothRecoilPunch.profileRampScale[profile] <- 1.0;
	}
});

::SmoothRecoilPunch.rawset("GetDefaultEmsConfig", function () {
	local content =
		"# Smooth Recoil Punch - EMS 武器与姿态调参文件 v2\n"
		+ "#\n"
		+ "# 中文说明（English guide follows below）\n"
		+ "# 文件位置：left4dead2/ems/" + ::SmoothRecoilPunch.EMS_CONFIG_PATH + "\n"
		+ "# 每行格式：武器档位  腰射单发上抬  ADS系数  最大仰角  水平偏移倍率  连射累积倍率\n"
		+ "# 对应字段：profile hip_kick ads_scale max_pitch yaw_scale ramp_scale\n"
		+ "# 姿态格式：posture 姿态名称 后坐力倍率\n"
		+ "#\n"
		+ "# hip_kick：腰射时每发的基础垂直上抬角度，填写正数；越大，上跳越明显。\n"
		+ "# ads_scale：开镜时乘在 hip_kick 上的最终系数；镭射瞄准使用同一 ADS 状态。\n"
		+ "#            实际 ADS 基础上抬 = hip_kick x ads_scale。\n"
		+ "# max_pitch：连续射击允许累积到的最大仰角，不是单发强度。建议至少高于 ADS 单发上抬。\n"
		+ "# yaw_scale：水平左右摆动倍率；0 关闭脚本水平摆动，1 为默认，数值越大摆动越明显。\n"
		+ "# ramp_scale：连射时逐发增强的倍率；0 关闭逐发增强，1 为默认。单发武器第一发不受影响。\n"
		+ "# posture：人物姿态倍率，同时作用于垂直上抬、水平摆动和持续射击爬升。\n"
		+ "#          stand_run=站立跑动，是原有后坐力标准 1.00；airborne=跳跃/离地，不区分是否跑动。\n"
		+ "#          crouch_idle=蹲姿不动，crouch_walk=蹲姿走动，stand_idle=站立不动，stand_walk=站立静步。\n"
		+ "#          姿态倍率不改变 max_pitch，也不改变引擎回正速度。\n"
		+ "#\n"
		+ "# 安全范围：hip_kick 0..20，ads_scale 0..2，max_pitch 1..60，yaw/ramp 0..3，posture 0.25..2。\n"
		+ "# 超出范围、列数不足或未知武器档位的行会被忽略，并在控制台输出 WARNING。\n"
		+ "# 修改后重新载入地图，或在控制台执行：script SmoothRecoilPunch.ReloadEmsConfig()\n"
		+ "# 删除或清空本文件后重新载入地图，可按当前 Mod 默认值重新生成。\n"
		+ "# 本文件一旦生成就优先于 Mod 内置值；Mod 更新后若想采用新默认值，也需要删除本文件再生成。\n"
		+ "# 请不要用 max_pitch 代替单发强度；上抬太低应先增加 hip_kick。\n"
		+ "# 纯 VScript 无法修改引擎内置回正弹簧。本文件不提供回正速度，避免重新引入回正掉帧。\n"
		+ "# 武器档位名称必须保持不变；空格或 Tab 均可分列。以 #、// 或 ; 开头的行是注释。\n"
		+ "# pumpshotgun=木喷，chrome_shotgun=铁喷，shotgun_spas=SPAS，default_weapon=未识别武器后备值。\n"
		+ "#\n"
		+ "# English guide\n"
		+ "# File location: left4dead2/ems/" + ::SmoothRecoilPunch.EMS_CONFIG_PATH + "\n"
		+ "# Row format: profile hip_kick ads_scale max_pitch yaw_scale ramp_scale\n"
		+ "# Posture format: posture posture_name recoil_scale\n"
		+ "# hip_kick: Base vertical kick in degrees per hip-fire shot. Use a positive number.\n"
		+ "# ads_scale: Final ADS multiplier. Laser aiming uses the same ADS state.\n"
		+ "#            Effective ADS base kick = hip_kick x ads_scale.\n"
		+ "# max_pitch: Maximum accumulated upward view angle during a burst, not per-shot kick.\n"
		+ "# yaw_scale: Horizontal sway multiplier. 0 disables scripted yaw; 1 is default.\n"
		+ "# ramp_scale: Per-shot burst growth multiplier. 0 disables growth; 1 is default.\n"
		+ "# posture: Scales pitch, yaw and sustained-fire climb for that player posture.\n"
		+ "#          stand_run is the original 1.00 baseline; airborne covers every in-air movement state.\n"
		+ "#          Posture scaling does not change max_pitch or the engine recovery spring.\n"
		+ "# Safe ranges: hip_kick 0..20, ads_scale 0..2, max_pitch 1..60, yaw/ramp 0..3, posture 0.25..2.\n"
		+ "# Invalid rows are ignored and reported as WARNING in the console.\n"
		+ "# Reload the map after editing, or run: script SmoothRecoilPunch.ReloadEmsConfig()\n"
		+ "# Delete or empty this file and reload the map to regenerate current defaults.\n"
		+ "# Once generated, this file overrides built-in defaults. Delete it after a Mod update to adopt new defaults.\n"
		+ "# Pure VScript cannot change the engine's native recovery spring. Recovery speed is intentionally absent.\n"
		+ "# Keep profile names unchanged. Spaces or tabs separate columns. #, // and ; begin comments.\n"
		+ "# pumpshotgun=wooden shotgun, chrome_shotgun=chrome shotgun, default_weapon=unrecognized fallback.\n"
		+ "#\n"
		+ "# Posture multipliers (smallest to largest by default)\n";

	foreach (posture in ::SmoothRecoilPunch.POSTURE_ORDER)
		content += "posture " + posture + " " + ::SmoothRecoilPunch.POSTURE_DEFAULTS[posture] + "\n";
	content += "#\n# Weapon profiles\n";

	foreach (profile in ::SmoothRecoilPunch.PROFILE_ORDER) {
		if (!(profile in ::SmoothRecoilPunch._factoryKick))
			continue;
		local hipKick = -::SmoothRecoilPunch._factoryKick[profile];
		content += profile + " " + hipKick
			+ " " + ::SmoothRecoilPunch.DefaultAdsScale(profile)
			+ " " + ::SmoothRecoilPunch.MAX_PITCH
			+ " 1.0 1.0\n";
	}
	return content;
});

::SmoothRecoilPunch.rawset("LoadEmsConfig", function () {
	::SmoothRecoilPunch.ResetEmsProfiles();
	local content = null;
	try {
		content = FileToString(::SmoothRecoilPunch.EMS_CONFIG_PATH);
	} catch (e) {
		::SmoothRecoilPunch.Log("EMS config read unavailable: " + e);
	}

	if (content == null || strip(content) == "") {
		content = ::SmoothRecoilPunch.GetDefaultEmsConfig();
		try {
			StringToFile(::SmoothRecoilPunch.EMS_CONFIG_PATH, content);
			::SmoothRecoilPunch.Log("created EMS config: ems/" + ::SmoothRecoilPunch.EMS_CONFIG_PATH);
		} catch (e) {
			::SmoothRecoilPunch.Log("WARNING: EMS config write failed: " + e);
		}
	}

	local loaded = 0;
	local postureLoaded = 0;
	local postureSeen = {};
	foreach (line in split(content, "\n")) {
		local valueLine = strip(line);
		if (valueLine == "")
			continue;
		local first = valueLine.slice(0, 1);
		if (first == "/" || first == "#" || first == ";")
			continue;

		local parts = split(valueLine, " \t");
		if(parts.len() >= 1 && parts[0] == "posture") {
			if(parts.len() < 3) {
				::SmoothRecoilPunch.Log("WARNING: EMS posture row needs 3 columns: " + valueLine);
				continue;
			}
			local posture = parts[1];
			if(!(posture in ::SmoothRecoilPunch.POSTURE_DEFAULTS)) {
				::SmoothRecoilPunch.Log("WARNING: unknown EMS posture ignored: " + posture);
				continue;
			}
			local postureValue = null;
			try {
				postureValue = parts[2].tofloat();
			} catch(e) {
				::SmoothRecoilPunch.Log("WARNING: invalid EMS posture value ignored: " + posture);
				continue;
			}
			if(postureValue != postureValue || postureValue < 0.25 || postureValue > 2.0) {
				::SmoothRecoilPunch.Log("WARNING: EMS posture outside safe range ignored: " + posture);
				continue;
			}
			::SmoothRecoilPunch.postureScale[posture] = postureValue;
			if(!(posture in postureSeen)) {
				postureSeen[posture] <- true;
				postureLoaded++;
			}
			continue;
		}
		if (parts.len() < 6) {
			::SmoothRecoilPunch.Log("WARNING: EMS row needs 6 columns: " + valueLine);
			continue;
		}

		local profile = parts[0];
		if (!(profile in ::SmoothRecoilPunch._factoryKick)) {
			::SmoothRecoilPunch.Log("WARNING: unknown EMS profile ignored: " + profile);
			continue;
		}

		local hipKick = null;
		local adsScale = null;
		local maxPitch = null;
		local yawScale = null;
		local rampScale = null;
		try {
			hipKick = parts[1].tofloat();
			adsScale = parts[2].tofloat();
			maxPitch = parts[3].tofloat();
			yawScale = parts[4].tofloat();
			rampScale = parts[5].tofloat();
		} catch (e) {
			::SmoothRecoilPunch.Log("WARNING: invalid EMS numbers ignored: " + profile);
			continue;
		}

		if (hipKick != hipKick || adsScale != adsScale || maxPitch != maxPitch
			|| yawScale != yawScale || rampScale != rampScale
			|| hipKick < 0.0 || hipKick > 20.0
			|| adsScale < 0.0 || adsScale > 2.0
			|| maxPitch < 1.0 || maxPitch > 60.0
			|| yawScale < 0.0 || yawScale > 3.0
			|| rampScale < 0.0 || rampScale > 3.0) {
			::SmoothRecoilPunch.Log("WARNING: EMS values outside safe ranges ignored: " + profile);
			continue;
		}

		::SmoothRecoilPunch.kick[profile] = -hipKick;
		::SmoothRecoilPunch.profileAdsScale[profile] = adsScale;
		::SmoothRecoilPunch.profileMaxPitch[profile] = maxPitch;
		::SmoothRecoilPunch.profileYawScale[profile] = yawScale;
		::SmoothRecoilPunch.profileRampScale[profile] = rampScale;
		loaded++;
	}

	::SmoothRecoilPunch._emsConfigLoaded = true;
	::SmoothRecoilPunch._emsLoadedProfiles = loaded;
	if(postureLoaded < ::SmoothRecoilPunch.POSTURE_ORDER.len()) {
		local postureRows = "\n# v2 missing posture multipliers (added automatically)\n";
		foreach (posture in ::SmoothRecoilPunch.POSTURE_ORDER) {
			if(posture in postureSeen)
				continue;
			postureRows += "posture " + posture + " " + ::SmoothRecoilPunch.POSTURE_DEFAULTS[posture] + "\n";
		}
		try {
			StringToFile(::SmoothRecoilPunch.EMS_CONFIG_PATH, content + postureRows);
			::SmoothRecoilPunch.Log("upgraded EMS config with missing posture rows");
		} catch(e) {
			::SmoothRecoilPunch.Log("WARNING: EMS posture upgrade write failed: " + e);
		}
	}
	::SmoothRecoilPunch.Log("loaded EMS punch config (" + loaded + "/"
		+ ::SmoothRecoilPunch.PROFILE_ORDER.len() + "): ems/"
		+ ::SmoothRecoilPunch.EMS_CONFIG_PATH + "; posture active="
		+ ::SmoothRecoilPunch.POSTURE_ORDER.len() + "/"
		+ ::SmoothRecoilPunch.POSTURE_ORDER.len());
});

::SmoothRecoilPunch.rawset("ReloadEmsConfig", function () {
	::SmoothRecoilPunch.LoadEmsConfig();
	::SmoothRecoilPunch.Log("EMS config reloaded");
});

::SmoothRecoilPunch.rawset("GetProfileAdsScale", function (profile) {
	if (profile in ::SmoothRecoilPunch.profileAdsScale)
		return ::SmoothRecoilPunch.profileAdsScale[profile];
	return ::SmoothRecoilPunch.DefaultAdsScale(profile);
});

::SmoothRecoilPunch.rawset("GetProfileMaxPitch", function (profile) {
	if (profile in ::SmoothRecoilPunch.profileMaxPitch)
		return ::SmoothRecoilPunch.profileMaxPitch[profile];
	return ::SmoothRecoilPunch.MAX_PITCH;
});

::SmoothRecoilPunch.rawset("GetProfileYawScale", function (profile) {
	if (profile in ::SmoothRecoilPunch.profileYawScale)
		return ::SmoothRecoilPunch.profileYawScale[profile];
	return 1.0;
});

::SmoothRecoilPunch.rawset("GetProfileRampScale", function (profile) {
	if (profile in ::SmoothRecoilPunch.profileRampScale)
		return ::SmoothRecoilPunch.profileRampScale[profile];
	return 1.0;
});

::SmoothRecoilPunch.rawset("IsOnGround", function (player) {
	try {
		return (NetProps.GetPropInt(player, "m_fFlags") & 1) != 0;
	} catch(e) { }
	return true;
});

::SmoothRecoilPunch.rawset("IsCrouching", function (player) {
	try {
		if(NetProps.GetPropInt(player, "m_Local.m_bDucked") != 0
			|| NetProps.GetPropInt(player, "m_Local.m_bDucking") != 0)
			return true;
	} catch(e1) { }
	try {
		return (NetProps.GetPropInt(player, "m_fFlags") & 2) != 0;
	} catch(e2) { }
	return false;
});

::SmoothRecoilPunch.rawset("GetPosture", function (player) {
	if(!::SmoothRecoilPunch.IsOnGround(player))
		return "airborne";

	local moving = false;
	try {
		local vel = player.GetVelocity();
		moving = (vel.x * vel.x + vel.y * vel.y) >= ::SmoothRecoilPunch.MOVE_SPEED_EPSILON_SQ;
	} catch(e1) { }

	if(::SmoothRecoilPunch.IsCrouching(player))
		return moving ? "crouch_walk" : "crouch_idle";
	if(!moving)
		return "stand_idle";

	try {
		if((player.GetButtonMask() & ::SmoothRecoilPunch.WALK_BUTTON) != 0)
			return "stand_walk";
	} catch(e2) { }
	return "stand_run";
});

::SmoothRecoilPunch.rawset("GetPostureScale", function (posture) {
	if(posture in ::SmoothRecoilPunch.postureScale)
		return ::SmoothRecoilPunch.postureScale[posture];
	return 1.0;
});

// Small always-on trace for test builds. It proves which posture was selected
// on a real shot without enabling the much noisier full DEBUG stream.
::SmoothRecoilPunch.rawset("LogPostureShot", function (player, state, posture,
	postureScale, profile, aiming, effectivePitch) {
	if(!::SmoothRecoilPunch.POSTURE_DIAGNOSTICS
		|| state.postureLogs >= ::SmoothRecoilPunch.POSTURE_LOG_LIMIT_PER_PLAYER)
		return;

	if(!(posture in state.postureSeen))
		state.postureSeen[posture] <- 0;
	local changed = state.postureLast != "" && state.postureLast != posture;
	local shouldLog = state.postureSeen[posture] < 2 || changed;
	state.postureLast = posture;
	if(!shouldLog)
		return;

	state.postureSeen[posture] += 1;
	state.postureLogs += 1;
	local speed2d = 0.0;
	try {
		local vel = player.GetVelocity();
		speed2d = sqrt(vel.x * vel.x + vel.y * vel.y);
	} catch(e1) { }
	local walkHeld = false;
	try { walkHeld = (player.GetButtonMask() & ::SmoothRecoilPunch.WALK_BUTTON) != 0; }
	catch(e2) { }
	local playerName = "unknown";
	try { playerName = player.GetPlayerName(); } catch(e3) { }

	printl("[SRP][posture] player=" + playerName
		+ " state=" + posture + " scale=" + postureScale
		+ " ads=" + (aiming ? 1 : 0) + " weapon=" + profile
		+ " effectiveKick=" + (-effectivePitch)
		+ " speed2d=" + speed2d + " walk=" + (walkHeld ? 1 : 0));
});

// Maps a weapon classname onto a tuning key.
::SmoothRecoilPunch.rawset("ClassOf", function (weaponName) {
	local n = weaponName;
	if (n.len() > 7 && n.slice(0, 7) == "weapon_") {
		n = n.slice(7);
	}

	local map = {
		pistol = "pistol",
		pistol_magnum = "magnum",
		smg = "smg",
		smg_silenced = "smg_silenced",
		smg_mp5 = "mp5",
		rifle = "rifle_m16",
		rifle_desert = "rifle_desert",
		rifle_sg552 = "rifle_sg552",
		rifle_ak47 = "rifle_ak47",
		pumpshotgun = "pumpshotgun",
		shotgun_chrome = "chrome_shotgun",
		autoshotgun = "autoshotgun",
		shotgun_spas = "shotgun_spas",
		hunting_rifle = "hunting_rifle",
		sniper_military = "sniper_military",
		sniper_scout = "scout",
		sniper_awp = "awp",
		rifle_m60 = "m60",
		grenade_launcher = "grenade_launcher"
	};

	if (n in map) {
		return map[n];
	}
	return "default_weapon";
});

// True while the player is aiming down sights.
//
// The ADS addon keeps its per-player state at
//     ::L4D2Lxc_ADS.HumanSurvivors[userid].weapon.ads_on
// which is reachable from the root table, so no coupling between the two
// addons is needed beyond this read. Everything is guarded: if the ADS addon
// is not installed, or its internals move in a future version, this simply
// reports false and the hip-fire climb is used. Recoil never breaks because of
// it.
::SmoothRecoilPunch.rawset("IsAdsActive", function (player) {
	try {
		if (!("L4D2Lxc_ADS" in getroottable()))
			return false;

		local ads = ::L4D2Lxc_ADS;
		if (!("HumanSurvivors" in ads))
			return false;

		local id = player.GetPlayerUserId();
		if (!(id in ads.HumanSurvivors))
			return false;

		local scope = ads.HumanSurvivors[id];
		if (!("weapon" in scope))
			return false;

		local w = scope.weapon;
		if (!("ads_on" in w))
			return false;

		// ads_on is written as both a bool and an int in that codebase.
		local v = w.ads_on;
		if (typeof(v) == "bool")
			return v;
		return (v != 0);
	} catch (e) { }
	return false;
});

// The released workshop ADS build does not know OWNS_ADS_RECOIL. Its delayed
// animation callback otherwise rewrites the same punch angle after our shot,
// which erases or clusters automatic ADS recoil. RecoilFactor is a public
// member of its root table, and 1.0 makes that callback leave punch untouched.
// Check continuously because the ADS settings file may load after this addon.
::SmoothRecoilPunch.rawset("EnsureAdsCompatibility", function () {
	try {
		if (!("L4D2Lxc_ADS" in getroottable()))
			return;

		local ads = ::L4D2Lxc_ADS;
		if (!("RecoilFactor" in ads))
			return;

		if (ads.RecoilFactor != 1.0)
			ads.RecoilFactor = 1.0;

		if (!::SmoothRecoilPunch._adsCompatibilityLogged) {
			::SmoothRecoilPunch._adsCompatibilityLogged = true;
			::SmoothRecoilPunch.Log("ADS compatibility active: RecoilFactor=1.0, punch owner=smooth recoil");
		}
	} catch (e) { }
});

::SmoothRecoilPunch.rawset("StateOf", function (player) {
	local id = -1;
	try { id = player.GetEntityIndex(); } catch (e) { return null; }

	if (!(id in ::SmoothRecoilPunch._players)) {
		::SmoothRecoilPunch._players[id] <- {
			shots = 0,
			lastShot = 0.0,
			clip = -1,
			weapon = "",
			pending = 0,     // rounds seen but not yet paid out (one per frame)
			lastAng = 0.0,   // previous punch pitch, for step diagnostics
			ads = false,     // aiming at the time of the last shot
			hold = 0,        // frames of slow-recovery hold remaining
			holdPrev = 0.0,  // punch pitch as we left it last frame
			adsWatch = 0,    // frames left of ADS surge watching
			adsPrev = 0.0,   // punch pitch seen last frame while aiming
			adsDebt = 0.0,   // climb held back this frame, owed to later frames
			adsLast = 0.0,   // per-frame climb actually allowed last frame
			postureSeen = {},
			postureLast = "",
			postureLogs = 0,
		};
	}
	local state = ::SmoothRecoilPunch._players[id];
	// Keep a same-map script reload compatible with states created by v0.9.15.
	if (!("postureSeen" in state)) state.postureSeen <- {};
	if (!("postureLast" in state)) state.postureLast <- "";
	if (!("postureLogs" in state)) state.postureLogs <- 0;
	return state;
});

//-----------------------------------------------------------------------------
// The whole recoil implementation. One function, fired once per shot.
//
// Note there is NO think loop and NO eye-angle write anywhere. The rise and the
// recovery are both produced by the engine's own damped spring.
//-----------------------------------------------------------------------------
::SmoothRecoilPunch.rawset("ApplyShot", function (player, weaponName) {
	local state = ::SmoothRecoilPunch.StateOf(player);
	if (state == null) {
		return false;
	}

	local now = Time();

	// Reset the spray ramp after a pause in fire.
	if ((now - state.lastShot) > ::SmoothRecoilPunch.BURST_RESET) {
		state.shots = 0;
	}
	state.lastShot = now;
	state.shots += 1;

	local cls = ::SmoothRecoilPunch.ClassOf(weaponName);

	local basePitch = ::SmoothRecoilPunch.kick.default_weapon;
	if (cls in ::SmoothRecoilPunch.kick) {
		basePitch = ::SmoothRecoilPunch.kick[cls];
	}

	local baseYaw = ::SmoothRecoilPunch.yaw.default_weapon;
	if (cls in ::SmoothRecoilPunch.yaw) {
		baseYaw = ::SmoothRecoilPunch.yaw[cls];
	}
	baseYaw = baseYaw * ::SmoothRecoilPunch.GetProfileYawScale(cls);

	local posture = ::SmoothRecoilPunch.GetPosture(player);
	local postureScale = ::SmoothRecoilPunch.GetPostureScale(posture);
	basePitch = basePitch * postureScale;
	baseYaw = baseYaw * postureScale;

	local aiming = ::SmoothRecoilPunch.IsAdsActive(player);
	state.ads = aiming;
	if (aiming) {
		local adsScale = ::SmoothRecoilPunch.GetProfileAdsScale(cls);
		basePitch = basePitch * adsScale;
		baseYaw = baseYaw * adsScale;
	}
	::SmoothRecoilPunch.LogPostureShot(player, state, posture, postureScale,
		cls, aiming, basePitch);

	// Spray ramp.
	//
	// v0.9.2: this used to be linear and then hard-clamped, so with the
	// defaults it grew every shot until shot 15 and was flat from then on.
	// That abrupt change from "accelerating" to "constant" is the reported
	// pause partway through a full-auto burst.
	//
	// Now it approaches RAMP_MAX asymptotically: still rising quickly at the
	// start of a spray, still bounded, but with no discontinuity anywhere.
	local span = ::SmoothRecoilPunch.RAMP_MAX - 1.0;
	local ramp = ::SmoothRecoilPunch.RAMP_MAX;
	if (span > 0.0) {
		local k = (::SmoothRecoilPunch.RAMP_PER_SHOT
			* ::SmoothRecoilPunch.GetProfileRampScale(cls)
			* (state.shots - 1)) / span;
		if (k < 0.0) k = 0.0;
		// 1 - 1/(1+k) rises fast initially and eases into the cap.
		ramp = 1.0 + span * (1.0 - (1.0 / (1.0 + k)));
	}

	local pitch = basePitch * ramp;

	// Sustained-fire climb.
	//
	// Raises where a burst TOPS OUT without changing how a single shot feels.
	// The engine spring settles the view at the point where per-shot push
	// balances spring pull, so adding a term that only grows with burst length
	// moves that balance point upward while leaving shot 1 identical.
	// Emergency compatibility switch. Normal operation keeps this false; the
	// runtime compatibility guard leaves this as the sole punch writer.
	if (aiming && ::SmoothRecoilPunch.ADS_HANDS_OFF) {
		state.hold = 0;
		state.adsWatch = 0;
		state.adsDebt = 0.0;
		state.adsLast = 0.0;
		if (::SmoothRecoilPunch.DEBUG && ::SmoothRecoilPunch._shotLogs < ::SmoothRecoilPunch.SHOT_LOG_LIMIT) {
			::SmoothRecoilPunch._shotLogs += 1;
			local ax = 0.0;
			try {
				ax = NetProps.GetPropVector(player, ::SmoothRecoilPunch.PROP_PUNCH).x;
			} catch (e) { }
			::SmoothRecoilPunch.Dbg("shot#" + state.shots + " " + cls
				+ " ADS -> hands off (ADS addon owns the recoil) ang=" + ax);
		}
		return true;
	}

	local climbMax = aiming
		? ::SmoothRecoilPunch.CLIMB_ADS
		: ::SmoothRecoilPunch.CLIMB_HIP;
	climbMax = climbMax * postureScale;

	if (climbMax > 0.0 && state.shots > 1) {
		local prog = (state.shots - 1).tofloat() / ::SmoothRecoilPunch.CLIMB_SHOTS;
		if (prog > 1.0) prog = 1.0;

		// v0.9.6: ease the climb in and out instead of ramping it linearly.
		//
		// A linear ramp adds a constant increment per shot, then stops dead the
		// moment it reaches full. Both the start and the end of that ramp are
		// corners in the curve, and a corner is felt as "the recoil suddenly
		// changes character partway through the burst" - which is the report.
		//
		// smoothstep has zero slope at both ends, so the climb fades in from
		// nothing and settles into its ceiling with no discontinuity anywhere.
		prog = prog * prog * (3.0 - (2.0 * prog));

		pitch = pitch - (climbMax * prog);
	}

	// Alternate horizontal direction so a spray snakes instead of drifting
	// one way, and vary it a little so it does not look mechanical.
	local dir = (state.shots % 2 == 0) ? 1.0 : -1.0;
	local jitter = 0.65 + (0.35 * ((state.shots * 37) % 100) / 100.0);
	local yaw = baseYaw * ramp * dir * jitter;

	local maxPitch = ::SmoothRecoilPunch.GetProfileMaxPitch(cls);

	// Clamp.
	if (pitch < -maxPitch) {
		pitch = -maxPitch;
	}

	// Declared out here so the diagnostic below can report what was actually
	// applied after the soft ceiling and the per-frame step limit had their say.
	local step = pitch;

	local instant = ::SmoothRecoilPunch.INSTANT_FRACTION;
	local viaVel = 1.0 - instant;

	try {
		// v0.9.3 - write the ANGLE, not the velocity.
		//
		// The readback settled this. With INSTANT_FRACTION at 0 the script
		// wrote only m_vecPunchAngleVel, and the log shows that velocity
		// climbing -23, -47, -74 ... -512 while the angle never moved off a
		// handful of values (-0.9 / -1.125 / -1.5 / -1.875) that are just
		// L4D2's own weapon kick. The engine never integrated our velocity
		// into an angle: m_vecPunchAngleVel is owned by client prediction and
		// a server-side write to it is discarded.
		//
		// m_vecPunchAngle itself IS honoured server-side - that is why the
		// earlier build, which wrote a slice of the kick straight into the
		// angle, produced visible climb. So accumulate into the angle and let
		// the client's spring pull it back down.
		local ang = NetProps.GetPropVector(player, ::SmoothRecoilPunch.PROP_PUNCH);
		if (ang == null) {
			ang = Vector(0, 0, 0);
		}

		// --- 1. anomaly backstop -------------------------------------------
		// Scaled to this weapon's own kick so the spray ramp is preserved.
		// Only a genuinely doubled application trips this.
		//
		// The sustained-fire climb is added to the allowance, otherwise this
		// backstop would cap exactly the growth the climb is there to produce
		// and the ceiling would not move at all.
		local stepCap = (basePitch * ::SmoothRecoilPunch.MAX_STEP_FACTOR) - climbMax;
		if (stepCap > 0.0) stepCap = -stepCap;      // basePitch is negative
		if (step < stepCap) {
			step = stepCap;
		}

		// --- 2. soft ceiling ----------------------------------------------
		// Below SOFT_START the kick applies at full strength. Above it, the
		// kick is scaled by how much headroom is left, so the view keeps
		// creeping upward during a long burst instead of freezing dead.
		local hard = maxPitch;
		local soft = ::SmoothRecoilPunch.SOFT_START;
		if (soft >= hard)
			soft = hard * 0.75;
		if (soft < 0.5)
			soft = 0.5;
		local cur  = -ang.x;             // positive = how high the view sits
		if (cur < 0.0) cur = 0.0;

		if (cur > soft) {
			local headroom = hard - soft;
			local used     = cur - soft;
			local left     = 1.0 - (used / headroom);
			if (left < 0.04) left = 0.04;   // never fully zero
			if (left > 1.0)  left = 1.0;
			step = step * left;
		}

		local newX = ang.x + step;
		local newY = ang.y + yaw;

		// Absolute backstop. With the soft curve above this should not be
		// reached in normal play.
		if (newX < -hard) {
			newX = -hard;
		}
		if (newX > 0.0) {
			newX = 0.0;      // never push the view downward
		}

		NetProps.SetPropVector(player, ::SmoothRecoilPunch.PROP_PUNCH,
			Vector(newX, newY, ang.z));

		// Nudge the velocity too. It is ignored on dedicated setups but is
		// free, and where it does apply it softens the per-shot step.
		if (::SmoothRecoilPunch.VEL_ASSIST > 0.0) {
			local vel = NetProps.GetPropVector(player, ::SmoothRecoilPunch.PROP_PUNCH_VEL);
			if (vel == null) {
				vel = Vector(0, 0, 0);
			}
			// Clamp so a discarded write cannot accumulate without bound.
			// v0.9.4: the old 400 limit was far too loose - the log shows the
			// value pinned at -400 for the entire back half of a burst, which
			// the engine kept integrating into the angle at ~6 deg/tick.
			local vc = ::SmoothRecoilPunch.VEL_CLAMP;
			local vx = vel.x + (step * ::SmoothRecoilPunch.VEL_ASSIST * 20.0);
			local vy = vel.y + (yaw  * ::SmoothRecoilPunch.VEL_ASSIST * 20.0);
			if (vx < -vc) { vx = -vc; }
			if (vx >  vc) { vx =  vc; }
			if (vy < -vc) { vy = -vc; }
			if (vy >  vc) { vy =  vc; }
			NetProps.SetPropVector(player, ::SmoothRecoilPunch.PROP_PUNCH_VEL,
				Vector(vx, vy, vel.z));
		}

	} catch (e) {
		::SmoothRecoilPunch.Log("punch write failed: " + e);
		return false;
	}

	// Arm the slow-recovery hold for the heavy single-shot weapons. Tick does
	// the per-frame work; this only starts the timer. Re-arming on every shot
	// is correct: these weapons cannot fire fast enough for holds to stack.
	if (::SmoothRecoilPunch.MANUAL_SINGLE_RECOVERY
		&& cls in ::SmoothRecoilPunch.slowRecovery) {
		state.hold = ::SmoothRecoilPunch.HOLD_FRAMES;
		state.holdPrev = 0.0;      // established on the next frame
	} else {
		state.hold = 0;
	}

	// Watch for the ADS addon's deferred correction for a short window after
	// each aimed shot. Outside that window we must not touch the angle at all.
	if (aiming) {
		if (state.adsWatch <= 0) {
			try {
				state.adsPrev = NetProps.GetPropVector(player,
					::SmoothRecoilPunch.PROP_PUNCH).x;
			} catch (e) { state.adsPrev = 0.0; }
		}
		state.adsWatch = 20;
	} else {
		state.adsWatch = 0;
	}

	if (::SmoothRecoilPunch.DEBUG && ::SmoothRecoilPunch._shotLogs < ::SmoothRecoilPunch.SHOT_LOG_LIMIT) {
		::SmoothRecoilPunch._shotLogs += 1;

		// Read the values straight back. If these come back as zero the write
		// is not landing at all; if they hold the value but the view does not
		// move, the client's prediction is overwriting it.
		// v0.9.4: log the STEP the view actually took, not just the absolute
		// angle. A jolt is a step much larger than its neighbours, and that is
		// impossible to see from absolute values alone - which is why the
		// earlier logs could not settle whether the jumping was real.
		local rbX = 0.0;
		local rbV = 0.0;
		try {
			rbX = NetProps.GetPropVector(player, ::SmoothRecoilPunch.PROP_PUNCH).x;
			rbV = NetProps.GetPropVector(player, ::SmoothRecoilPunch.PROP_PUNCH_VEL).x;
		} catch (e) { }

		local realStep = rbX - state.lastAng;
		state.lastAng = rbX;

		local flag = "";
		if (realStep < -(::SmoothRecoilPunch.MAX_STEP_FACTOR * -basePitch + 0.35)) {
			flag = "  <<JOLT";
		} else if (state.shots > 1 && realStep > -0.05) {
			flag = "  <<FROZEN";
		}

		::SmoothRecoilPunch.Dbg("shot#" + state.shots + " " + cls
			+ (aiming ? " ADS" : " hip") + " req=" + pitch + " applied=" + step
			+ " posture=" + posture + "x" + postureScale
			+ " | ang=" + rbX + " step=" + realStep
			+ " vel=" + rbV + " queued=" + state.pending + flag);
	}

	return true;
});

//-----------------------------------------------------------------------------
// Shot detection
//
// v0.9.1: this used to rely on ::OnGameEvent_weapon_fire plus
// __CollectGameEventCallbacks. Your console.log proved that never fired even
// once - the prototype loaded ("punch-angle prototype 0.9.0-punch loaded") but
// no shot was ever processed, which is exactly why recoil did nothing.
//
// Game-event callbacks registered from a mapspawn_addon-loaded script are not
// reliably collected in this environment. The original core never used events
// at all: it polls each survivor's m_iClip1 from a think and treats any
// decrease as shots fired. That mechanism is already proven to work in your
// setup, so this now uses the same approach.
//-----------------------------------------------------------------------------
::SmoothRecoilPunch.rawset("THINK_NAME", "SmoothRecoilPunch_Think");
::SmoothRecoilPunch.rawset("_thinker", null);
::SmoothRecoilPunch.rawset("_started", false);
::SmoothRecoilPunch.rawset("_tickLogs", 0);

::SmoothRecoilPunch.rawset("GetClip", function (weapon) {
	try {
		return NetProps.GetPropInt(weapon, "m_iClip1");
	} catch (e) { }
	return -1;
});

// Polls every survivor and converts clip decreases into punch.
::SmoothRecoilPunch.rawset("Tick", function () {
	if (!("SmoothRecoilPunch" in getroottable()))
		return;

	::SmoothRecoilPunch.EnsureAdsCompatibility();

	local player = null;
	while (player = Entities.FindByClassname(player, "player")) {
		if (player == null || !player.IsValid())
			continue;

		local ok = false;
		try {
			ok = player.IsSurvivor() && !IsPlayerABot(player);
		} catch (e) { ok = false; }
		if (!ok)
			continue;

		local state = ::SmoothRecoilPunch.StateOf(player);
		if (state == null)
			continue;

		// --- slow-recovery hold -------------------------------------------
		//
		// Runs before shot detection so a hold left over from the previous
		// round can never eat into this frame's kick.
		//
		// The engine decays the punch angle every tick. Here we simply hand a
		// fraction of that decay back, which flattens the top of the curve.
		// Only the punch angle is touched - never the eye angle - so this
		// cannot interfere with the mouse.
		// --- ADS surge suppression ----------------------------------------
		//
		// Runs every frame, because the ADS addon applies its correction from
		// an animation callback that we do not sit inside. Whenever the punch
		// angle moves UPWARD by more than ADS_MAX_STEP in one frame while
		// aiming, the excess is deferred rather than discarded: it is left in
		// the angle to be delivered on following frames. Nothing is lost, so
		// the burst still reaches the same height - it just gets there without
		// the single-frame lump.
		if (::SmoothRecoilPunch.ADS_SMOOTH && state.adsWatch > 0) {
			try {
				local cv = NetProps.GetPropVector(player, ::SmoothRecoilPunch.PROP_PUNCH);
				if (cv != null) {
					local moved = state.adsPrev - cv.x;   // >0 = climbed this frame

					// Ceiling, plus a limit on how fast the per-frame strength
					// may grow relative to the previous frame.
					local lim = ::SmoothRecoilPunch.ADS_MAX_STEP;
					if (state.adsLast > 0.0) {
						local grow = state.adsLast * ::SmoothRecoilPunch.ADS_GROWTH;
						if (grow < ::SmoothRecoilPunch.ADS_FLOOR)
							grow = ::SmoothRecoilPunch.ADS_FLOOR;
						if (grow < lim) lim = grow;
					}
					local newX = cv.x;

					if (moved > lim) {
						// Too violent for one frame. Hold the excess back as a
						// DEBT rather than throwing it away, so the burst still
						// reaches the same height - it just gets there over a
						// few frames instead of in one jolt.
						state.adsDebt += (moved - lim);
						if (state.adsDebt > 8.0) state.adsDebt = 8.0;
						newX = state.adsPrev - lim;
					}
					else if (state.adsDebt > 0.0) {
						// Pay the debt back using whatever headroom this frame
						// has left, so nothing is lost.
						local room = lim - moved;
						if (room > 0.0) {
							local pay = state.adsDebt;
							if (pay > room) pay = room;
							newX = cv.x - pay;
							state.adsDebt -= pay;
						}
					}

					local watchMaxPitch = ::SmoothRecoilPunch.GetProfileMaxPitch(
						::SmoothRecoilPunch.ClassOf(state.weapon));
					if (newX < -watchMaxPitch)
						newX = -watchMaxPitch;
					if (newX > 0.0) newX = 0.0;

					if (newX != cv.x) {
						NetProps.SetPropVector(player,
							::SmoothRecoilPunch.PROP_PUNCH,
							Vector(newX, cv.y, cv.z));
					}
					state.adsPrev = newX;
					state.adsLast = moved;
					if (state.adsLast > lim) state.adsLast = lim;
				}
			} catch (e) { }
			state.adsWatch -= 1;
			if (state.adsWatch <= 0) { state.adsDebt = 0.0; state.adsLast = 0.0; }
		}

		if (::SmoothRecoilPunch.MANUAL_SINGLE_RECOVERY && state.hold > 0) {
			try {
				local hv = NetProps.GetPropVector(player, ::SmoothRecoilPunch.PROP_PUNCH);
				if (hv != null) {
					if (state.holdPrev < 0.0) {
						// How much the spring removed since last frame.
						local recovered = hv.x - state.holdPrev;
						if (recovered > 0.0) {
							// Fade the hold out so it rejoins the spring
							// smoothly. A constant fraction that stops dead
							// leaves a 4x jump in per-frame movement, which
							// reads as the view stalling and then lurching.
							local hf = ::SmoothRecoilPunch.HOLD_FRAMES.tofloat();
							local prog = 1.0 - (state.hold.tofloat() / hf);
							if (prog < 0.0) prog = 0.0;
							if (prog > 1.0) prog = 1.0;
							local ease = 1.0 - (prog * prog * (3.0 - (2.0 * prog)));

							local giveBack = recovered
								* ::SmoothRecoilPunch.HOLD_FRACTION * ease;
							local hx = hv.x - giveBack;
							local holdMaxPitch = ::SmoothRecoilPunch.GetProfileMaxPitch(
								::SmoothRecoilPunch.ClassOf(state.weapon));
							if (hx < -holdMaxPitch)
								hx = -holdMaxPitch;
							if (hx > 0.0)
								hx = 0.0;
							NetProps.SetPropVector(player,
								::SmoothRecoilPunch.PROP_PUNCH,
								Vector(hx, hv.y, hv.z));
							hv = Vector(hx, hv.y, hv.z);
						}
					}
					state.holdPrev = hv.x;
				}
			} catch (e) { }
			state.hold -= 1;
		}

		local weapon = null;
		try { weapon = player.GetActiveWeapon(); } catch (e) { }

		if (weapon == null || !weapon.IsValid()) {
			state.clip = -1;
			state.weapon = "";
			continue;
		}

		local wname = weapon.GetClassname();
		local clip = ::SmoothRecoilPunch.GetClip(weapon);

		// Weapon swap or unreadable clip: resync without firing recoil.
		if (wname != state.weapon || clip < 0 || state.clip < 0) {
			state.clip = clip;
			state.weapon = wname;
			continue;
		}

		if (clip < state.clip) {
			// v0.9.4: apply ONE kick per frame, no matter how many rounds the
			// poll saw leave the magazine.
			//
			// The old loop ran ApplyShot up to five times in a single frame.
			// Every one of those writes landed on the same tick, so the view
			// took one giant step instead of several smooth ones - the
			// intermittent hard jolt in the report. Rounds beyond the first
			// are carried over and paid out on following frames, which keeps
			// the spray ramp honest without ever double-stepping the view.
			state.pending += (state.clip - clip);
			if (state.pending > 5)
				state.pending = 5;   // a resync must not read as a huge burst
		}

		if (state.pending > 0) {
			state.pending -= 1;
			::SmoothRecoilPunch.ApplyShot(player, wname);
		}

		state.clip = clip;

	}
});

// Global think entry point. AddThinkToEnt needs a name resolvable at root.
::SmoothRecoilPunch_Think <- function () {
	::SmoothRecoilPunch.Tick();
	return 0.0;   // every frame
}

::SmoothRecoilPunch.rawset("StartThinker", function () {
	if (::SmoothRecoilPunch._started
		&& ::SmoothRecoilPunch._thinker != null
		&& ::SmoothRecoilPunch._thinker.IsValid()) {
		::SmoothRecoilPunch.Log("thinker already running");
		return true;
	}

	// Clear any leftover thinker from a previous map.
	local old = null;
	while (old = Entities.FindByName(old, "smooth_recoil_punch_thinker")) {
		if (old != null && old.IsValid())
			old.Kill();
	}

	local thinker = SpawnEntityFromTable("info_target",
		{ targetname = "smooth_recoil_punch_thinker" });

	if (thinker == null || !thinker.IsValid()) {
		::SmoothRecoilPunch.Log("ERROR: failed to spawn thinker - recoil will not run");
		return false;
	}

	::SmoothRecoilPunch._thinker = thinker;
	::SmoothRecoilPunch._started = true;
	AddThinkToEnt(thinker, ::SmoothRecoilPunch.THINK_NAME);
	::SmoothRecoilPunch.Log("thinker started (clip-poll shot detection)");
	return true;
});

// Called by the addon entry points on every map spawn.
::SmoothRecoilPunch.rawset("OnMapSpawn", function (source) {
	::SmoothRecoilPunch._players.clear();
	::SmoothRecoilPunch._started = false;
	::SmoothRecoilPunch._thinker = null;
	::SmoothRecoilPunch._adsCompatibilityLogged = false;
	if (!::SmoothRecoilPunch._emsConfigLoaded)
		::SmoothRecoilPunch.LoadEmsConfig();
	::SmoothRecoilPunch.StartThinker();
	::SmoothRecoilPunch.Log("ready from " + source);
});

//-----------------------------------------------------------------------------
// Diagnostics:  script SmoothRecoilPunch.Status()
//-----------------------------------------------------------------------------
::SmoothRecoilPunch.rawset("Status", function () {
	local L = ::SmoothRecoilPunch.Log;
	L("=============== status ===============");
	L("version          : " + ::SmoothRecoilPunch.VERSION);
	L("method           : m_vecPunchAngle / m_vecPunchAngleVel");
	L("eye angle writes : NONE (this is why it cannot fight the mouse)");
	L("ADS punch owner  : " + (::SmoothRecoilPunch.OWNS_ADS_RECOIL ? 1 : 0)
		+ "  auto scale " + ::SmoothRecoilPunch.ADS_KICK_SCALE
		+ "  single scale " + ::SmoothRecoilPunch.ADS_SINGLE_KICK_SCALE
		+ "  grenade scale " + ::SmoothRecoilPunch.ADS_GRENADE_KICK_SCALE);
	L("instant fraction : " + ::SmoothRecoilPunch.INSTANT_FRACTION);
	L("ramp per shot    : " + ::SmoothRecoilPunch.RAMP_PER_SHOT
		+ "  max " + ::SmoothRecoilPunch.RAMP_MAX);
	L("manual single recovery: "
		+ (::SmoothRecoilPunch.MANUAL_SINGLE_RECOVERY ? "ON" : "OFF (native engine decay)"));
	L("EMS config       : ems/" + ::SmoothRecoilPunch.EMS_CONFIG_PATH
		+ "  profiles " + ::SmoothRecoilPunch._emsLoadedProfiles);

	local host = null;
	try { host = GetListenServerHost(); } catch (e) { }

	if (host == null || !host.IsValid()) {
		L("host             : not available");
		L("======================================");
		return;
	}

	L("host             : " + host.GetPlayerName());
	local posture = ::SmoothRecoilPunch.GetPosture(host);
	L("posture          : " + posture + " x"
		+ ::SmoothRecoilPunch.GetPostureScale(posture));

	// Prove the netprops are reachable on this build.
	local okAng = false;
	local okVel = false;
	try {
		okAng = NetProps.HasProp(host, ::SmoothRecoilPunch.PROP_PUNCH);
		okVel = NetProps.HasProp(host, ::SmoothRecoilPunch.PROP_PUNCH_VEL);
	} catch (e) { }

	L("punch prop       : " + (okAng ? "OK" : "MISSING"));
	L("punch vel prop   : " + (okVel ? "OK" : "MISSING"));

	try {
		local a = NetProps.GetPropVector(host, ::SmoothRecoilPunch.PROP_PUNCH);
		local v = NetProps.GetPropVector(host, ::SmoothRecoilPunch.PROP_PUNCH_VEL);
		L("punch now        : " + a);
		L("punch vel now    : " + v);
	} catch (e) {
		L("read failed      : " + e);
	}

	local wep = null;
	try { wep = host.GetActiveWeapon(); } catch (e) { }
	if (wep != null && wep.IsValid()) {
		local cn = wep.GetClassname();
		local profile = ::SmoothRecoilPunch.ClassOf(cn);
		L("weapon           : " + cn + " -> " + profile);
		L("profile tuning   : hip " + (-::SmoothRecoilPunch.kick[profile])
			+ "  ads " + ::SmoothRecoilPunch.GetProfileAdsScale(profile)
			+ "  max " + ::SmoothRecoilPunch.GetProfileMaxPitch(profile)
			+ "  yaw " + ::SmoothRecoilPunch.GetProfileYawScale(profile)
			+ "  ramp " + ::SmoothRecoilPunch.GetProfileRampScale(profile));
	}

	L("======================================");
});

// Fires one shot's worth of recoil on the host, for testing without shooting.
::SmoothRecoilPunch.rawset("TestKick", function () {
	local host = null;
	try { host = GetListenServerHost(); } catch (e) { }
	if (host == null || !host.IsValid()) {
		::SmoothRecoilPunch.Log("TestKick: no host");
		return;
	}

	local wname = "weapon_rifle_ak47";
	try {
		local w = host.GetActiveWeapon();
		if (w != null && w.IsValid()) {
			wname = w.GetClassname();
		}
	} catch (e) { }

	::SmoothRecoilPunch.Log("TestKick using " + wname);
	if (::SmoothRecoilPunch.ApplyShot(host, wname)) {
		::SmoothRecoilPunch.Log("TestKick applied - the view should climb smoothly and settle");
	}
});

::SmoothRecoilPunch.rawset("_coreReady", true);
::SmoothRecoilPunch.Log("punch-angle prototype " + ::SmoothRecoilPunch.VERSION + " loaded");
