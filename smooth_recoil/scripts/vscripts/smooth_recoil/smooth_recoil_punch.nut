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

::SmoothRecoilPunch.rawset("VERSION", "0.9.0-punch");
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
::SmoothRecoilPunch.rawset("INSTANT_FRACTION", 0.15);

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

// Safety clamp so a bad config can never throw the view to the sky.
::SmoothRecoilPunch.rawset("MAX_PITCH", 24.0);

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
			lastShot = 0.0
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
	local ramp = 1.0 + (::SmoothRecoilPunch.RAMP_PER_SHOT * (state.shots - 1));
	if (ramp > ::SmoothRecoilPunch.RAMP_MAX) {
		ramp = ::SmoothRecoilPunch.RAMP_MAX;
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

	local instant = ::SmoothRecoilPunch.INSTANT_FRACTION;
	local viaVel = 1.0 - instant;

	try {
		// --- velocity component: the smooth accelerating climb -------------
		local vel = NetProps.GetPropVector(player, ::SmoothRecoilPunch.PROP_PUNCH_VEL);
		if (vel == null) {
			vel = Vector(0, 0, 0);
		}
		NetProps.SetPropVector(player, ::SmoothRecoilPunch.PROP_PUNCH_VEL,
			Vector(vel.x + (pitch * viaVel * ::SmoothRecoilPunch.VEL_SCALE),
			       vel.y + (yaw   * viaVel * ::SmoothRecoilPunch.VEL_SCALE),
			       vel.z));

		// --- optional instant component: a crisper onset -------------------
		if (instant > 0.0) {
			local ang = NetProps.GetPropVector(player, ::SmoothRecoilPunch.PROP_PUNCH);
			if (ang == null) {
				ang = Vector(0, 0, 0);
			}
			local nx = ang.x + (pitch * instant);
			if (nx < -::SmoothRecoilPunch.MAX_PITCH) {
				nx = -::SmoothRecoilPunch.MAX_PITCH;
			}
			NetProps.SetPropVector(player, ::SmoothRecoilPunch.PROP_PUNCH,
				Vector(nx, ang.y + (yaw * instant), ang.z));
		}
	} catch (e) {
		::SmoothRecoilPunch.Log("punch write failed: " + e);
		return false;
	}

	if (::SmoothRecoilPunch.DEBUG && ::SmoothRecoilPunch._shotLogs < 30) {
		::SmoothRecoilPunch._shotLogs += 1;
		::SmoothRecoilPunch.Dbg("shot#" + state.shots + " " + cls
			+ " pitch=" + pitch + " yaw=" + yaw + " ramp=" + ramp);
	}

	return true;
});

//-----------------------------------------------------------------------------
// Event hook
//-----------------------------------------------------------------------------
::OnGameEvent_weapon_fire <- function (params) {
	if (!("SmoothRecoilPunch" in getroottable())) {
		return;
	}

	try {
		if (!("userid" in params)) {
			return;
		}

		local player = GetPlayerFromUserID(params.userid);
		if (player == null || !player.IsValid()) {
			return;
		}

		// Bots do not have a view to disturb.
		if (IsPlayerABot(player)) {
			return;
		}
		if (!player.IsSurvivor()) {
			return;
		}

		local wname = ("weapon" in params) ? params.weapon : "";
		if (wname == "") {
			try {
				local w = player.GetActiveWeapon();
				if (w != null && w.IsValid()) {
					wname = w.GetClassname();
				}
			} catch (e) { }
		}

		::SmoothRecoilPunch.ApplyShot(player, wname);
	} catch (e) {
		::SmoothRecoilPunch.Dbg("weapon_fire handler error: " + e);
	}
}

if ("__CollectGameEventCallbacks" in getroottable()) {
	__CollectGameEventCallbacks(getroottable());
}

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
