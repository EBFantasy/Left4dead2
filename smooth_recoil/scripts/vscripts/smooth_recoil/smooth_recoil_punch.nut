//-----------------------------------------------------------------------------
// Smooth Recoil - punch-angle prototype (v0.9.0-punch)
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

::SmoothRecoilPunch.rawset("VERSION", "0.9.4-punch");
::SmoothRecoilPunch.rawset("DEBUG", true);

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
::SmoothRecoilPunch.rawset("VEL_ASSIST", 0.18);
::SmoothRecoilPunch.rawset("VEL_CLAMP", 110.0);

// Per-shot climb, in degrees. Negative pitch moves the view UP.
// Reused from the existing core so the feel stays comparable.
::SmoothRecoilPunch.rawset("kick", {
	pistol = -1.15,
	magnum = -2.05,
	smg = -0.95,
	smg_silenced = -0.88,
	mp5 = -1.08,
	rifle_m16 = -1.20,
	rifle_desert = -1.45,
	rifle_sg552 = -1.60,
	rifle_ak47 = -2.35,
	pumpshotgun = -3.65,
	chrome_shotgun = -3.45,
	autoshotgun = -2.80,
	shotgun_spas = -3.00,
	hunting_rifle = -2.60,
	sniper_military = -2.25,
	scout = -3.35,
	awp = -5.75,
	m60 = -2.90,
	grenade_launcher = -5.90,
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
		};
	}
	return ::SmoothRecoilPunch._players[id];
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
		local k = (::SmoothRecoilPunch.RAMP_PER_SHOT * (state.shots - 1)) / span;
		if (k < 0.0) k = 0.0;
		// 1 - 1/(1+k) rises fast initially and eases into the cap.
		ramp = 1.0 + span * (1.0 - (1.0 / (1.0 + k)));
	}

	local pitch = basePitch * ramp;

	// Alternate horizontal direction so a spray snakes instead of drifting
	// one way, and vary it a little so it does not look mechanical.
	local dir = (state.shots % 2 == 0) ? 1.0 : -1.0;
	local jitter = 0.65 + (0.35 * ((state.shots * 37) % 100) / 100.0);
	local yaw = baseYaw * ramp * dir * jitter;

	// Clamp.
	if (pitch < -::SmoothRecoilPunch.MAX_PITCH) {
		pitch = -::SmoothRecoilPunch.MAX_PITCH;
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
		local stepCap = basePitch * ::SmoothRecoilPunch.MAX_STEP_FACTOR;
		if (stepCap > 0.0) stepCap = -stepCap;      // basePitch is negative
		if (step < stepCap) {
			step = stepCap;
		}

		// --- 2. soft ceiling ----------------------------------------------
		// Below SOFT_START the kick applies at full strength. Above it, the
		// kick is scaled by how much headroom is left, so the view keeps
		// creeping upward during a long burst instead of freezing dead.
		local soft = ::SmoothRecoilPunch.SOFT_START;
		local hard = ::SmoothRecoilPunch.MAX_PITCH;
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

	if (::SmoothRecoilPunch.DEBUG && ::SmoothRecoilPunch._shotLogs < 30) {
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
			+ " req=" + pitch + " applied=" + step
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
	L("instant fraction : " + ::SmoothRecoilPunch.INSTANT_FRACTION);
	L("ramp per shot    : " + ::SmoothRecoilPunch.RAMP_PER_SHOT
		+ "  max " + ::SmoothRecoilPunch.RAMP_MAX);

	local host = null;
	try { host = GetListenServerHost(); } catch (e) { }

	if (host == null || !host.IsValid()) {
		L("host             : not available");
		L("======================================");
		return;
	}

	L("host             : " + host.GetPlayerName());

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
		L("weapon           : " + cn + " -> " + ::SmoothRecoilPunch.ClassOf(cn));
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
