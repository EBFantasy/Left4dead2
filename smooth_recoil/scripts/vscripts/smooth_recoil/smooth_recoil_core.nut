// Smooth Recoil - core.
// Pitch: negative values move the view upward in L4D2.

if (!("SmoothRecoil" in getroottable())) {
	::SmoothRecoil <- {};
}

::SmoothRecoil.rawset("VERSION", "0.8.2-ems");
::SmoothRecoil.rawset("THINK_NAME", "SmoothRecoil_Think");
::SmoothRecoil.rawset("THINK_INTERVAL", 0.03);
::SmoothRecoil.rawset("DEBUG", true);
::SmoothRecoil.rawset("LOG_FIRE_LIMIT_PER_CLASS", 24);
::SmoothRecoil.rawset("LOG_MANUAL_SKIP_LIMIT", 24);
::SmoothRecoil.rawset("LOG_STATUS_INTERVAL", 15.0);

::SmoothRecoil.rawset("kick", {
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

::SmoothRecoil.rawset("yaw", {
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

::SmoothRecoil.rawset("recover", {
	pistol = 3.0,
	magnum = 3.1,
	smg = 3.8,
	smg_silenced = 4.1,
	mp5 = 3.7,
	rifle_m16 = 3.1,
	rifle_desert = 2.7,
	rifle_sg552 = 2.6,
	rifle_ak47 = 2.05,
	pumpshotgun = 2.5,
	chrome_shotgun = 2.6,
	autoshotgun = 2.8,
	shotgun_spas = 2.7,
	hunting_rifle = 3.0,
	sniper_military = 3.1,
	scout = 4.4,
	awp = 5.2,
	m60 = 1.75,
	grenade_launcher = 5.0,
	default_weapon = 3.2
});

::SmoothRecoil.rawset("recoilMultiplier", {});
::SmoothRecoil.rawset("recoveryMultiplier", {});

::SmoothRecoil.rawset("pitchCap", {
	pistol = 8.0,
	magnum = 11.0,
	smg = 9.0,
	smg_silenced = 8.0,
	mp5 = 9.5,
	rifle_m16 = 12.0,
	rifle_desert = 14.0,
	rifle_sg552 = 15.0,
	rifle_ak47 = 18.5,
	pumpshotgun = 16.0,
	chrome_shotgun = 15.0,
	autoshotgun = 14.5,
	shotgun_spas = 15.5,
	hunting_rifle = 14.0,
	sniper_military = 13.5,
	scout = 16.0,
	awp = 23.0,
	m60 = 21.0,
	grenade_launcher = 22.0,
	default_weapon = 12.0
});

::SmoothRecoil.rawset("yawCap", {
	pistol = 1.3,
	magnum = 1.4,
	smg = 2.2,
	smg_silenced = 1.8,
	mp5 = 2.3,
	rifle_m16 = 3.0,
	rifle_desert = 3.5,
	rifle_sg552 = 3.8,
	rifle_ak47 = 5.0,
	pumpshotgun = 3.6,
	chrome_shotgun = 3.4,
	autoshotgun = 3.3,
	shotgun_spas = 3.5,
	hunting_rifle = 2.0,
	sniper_military = 1.9,
	scout = 1.6,
	awp = 1.5,
	m60 = 4.0,
	grenade_launcher = 1.0,
	default_weapon = 2.8
});

::SmoothRecoil.rawset("risePitchSpeed", {
	pistol = 11.0,
	magnum = 15.0,
	smg = 10.5,
	smg_silenced = 10.0,
	mp5 = 11.0,
	rifle_m16 = 11.5,
	rifle_desert = 12.8,
	rifle_sg552 = 13.5,
	rifle_ak47 = 15.5,
	pumpshotgun = 18.0,
	chrome_shotgun = 17.5,
	autoshotgun = 15.0,
	shotgun_spas = 15.8,
	hunting_rifle = 17.0,
	sniper_military = 16.0,
	scout = 24.0,
	awp = 36.0,
	m60 = 16.5,
	grenade_launcher = 38.0,
	default_weapon = 11.0
});

::SmoothRecoil.rawset("adsFactor", 0.38);
::SmoothRecoil.rawset("laserFactor", 0.72);
::SmoothRecoil.rawset("crouchFactor", 0.58);
::SmoothRecoil.rawset("moveFactor", 1.35);
::SmoothRecoil.rawset("airFactor", 1.60);
::SmoothRecoil.rawset("maxPitch", 16.0);
::SmoothRecoil.rawset("maxYaw", 4.0);
::SmoothRecoil.rawset("riseSpeed", 26.0);
::SmoothRecoil.rawset("maxRisePitchSpeed", 11.0);
::SmoothRecoil.rawset("maxRiseYawSpeed", 3.0);
::SmoothRecoil.rawset("returnSpeed", 7.5);
::SmoothRecoil.rawset("recoveryDelay", 0.08);
::SmoothRecoil.rawset("maxReturnPitchSpeed", 5.4);
::SmoothRecoil.rawset("maxReturnYawSpeed", 2.4);
::SmoothRecoil.rawset("manualInputThreshold", 0.12);
::SmoothRecoil.rawset("manualYawBlockThreshold", 0.24);
::SmoothRecoil.rawset("manualYawSoftThreshold", 0.12);
::SmoothRecoil.rawset("manualBlockSeconds", 0.05);
::SmoothRecoil.rawset("manualCameraFactor", 0.45);
::SmoothRecoil.rawset("manualTargetRetainFactor", 0.88);
::SmoothRecoil.rawset("maxStoredManualPitch", 3.0);
::SmoothRecoil.rawset("cameraBlendInSpeed", 4.8);
::SmoothRecoil.rawset("manualReturnFactor", 0.30);
::SmoothRecoil.rawset("cameraYawFactor", 0.0);

::SmoothRecoil.rawset("_players", {});
::SmoothRecoil.rawset("_thinker", null);
::SmoothRecoil.rawset("_started", false);
::SmoothRecoil.rawset("_fireLogsByClass", {});
::SmoothRecoil.rawset("_manualSkipLogs", 0);
::SmoothRecoil.rawset("_lastStatusLog", 0.0);
::SmoothRecoil.rawset("_lastStartSource", "");
::SmoothRecoil.rawset("_setEyeMode", "unknown");
::SmoothRecoil.rawset("_coreReady", true);
::SmoothRecoil.rawset("EmsConfigPath", "smooth_recoil/settings.txt");
::SmoothRecoil.rawset("_emsConfigLoaded", false);

function SmoothRecoil_GetDefaultEmsConfig() {
	return "// Smooth Recoil - per-profile recoil and recovery multipliers.\n"
		+ "// Smooth Recoil - 每个枪械档位的后坐力与回正倍率。\n"
		+ "// Format / 格式: profile recoil_multiplier recovery_multiplier\n"
		+ "// Suggested range / 建议范围: 0.10 through 3.00. Reload the map after editing.\n"
		+ "// 推荐区间：0.10 到 3.00。修改后请重新载入地图。\n"
		+ "// Recoil changes shot kick; recovery changes the return speed.\n"
		+ "// 后坐力倍率控制单发上抬；回正倍率控制恢复速度。\n"
		+ "pistol 1.00 1.00\n"
		+ "magnum 1.00 1.00\n"
		+ "smg 1.00 1.00\n"
		+ "smg_silenced 1.00 1.00\n"
		+ "mp5 1.00 1.00\n"
		+ "rifle_m16 1.00 1.00\n"
		+ "rifle_desert 1.00 1.00\n"
		+ "rifle_sg552 1.00 1.00\n"
		+ "rifle_ak47 1.00 1.00\n"
		+ "pumpshotgun 1.00 0.78\n"
		+ "chrome_shotgun 1.00 0.78\n"
		+ "autoshotgun 1.00 1.00\n"
		+ "shotgun_spas 1.00 1.00\n"
		+ "hunting_rifle 1.00 1.00\n"
		+ "sniper_military 1.00 1.00\n"
		+ "scout 1.00 0.78\n"
		+ "awp 1.00 1.00\n"
		+ "m60 1.00 1.00\n"
		+ "grenade_launcher 1.00 1.00\n"
		+ "default_weapon 1.00 1.00\n";
}

function SmoothRecoil_ResetEmsMultipliers() {
	foreach (weaponClass, ignored in ::SmoothRecoil.kick) {
		::SmoothRecoil.recoilMultiplier[weaponClass] <- 1.0;
		::SmoothRecoil.recoveryMultiplier[weaponClass] <- 1.0;
	}
}

function SmoothRecoil_LoadEmsConfig() {
	SmoothRecoil_ResetEmsMultipliers();
	local content = null;
	try {
		content = FileToString(::SmoothRecoil.EmsConfigPath);
	} catch (exception) {
		SmoothRecoil_Log("EMS config read unavailable: " + exception);
	}

	if (content == null || strip(content) == "") {
		content = SmoothRecoil_GetDefaultEmsConfig();
		try {
			StringToFile(::SmoothRecoil.EmsConfigPath, content);
			SmoothRecoil_Log("created EMS config: ems/" + ::SmoothRecoil.EmsConfigPath);
		} catch (exception) {
			SmoothRecoil_Log("WARNING: EMS config write failed: " + exception);
		}
	}

	local loaded = 0;
	foreach (line in split(content, "\n")) {
		local valueLine = strip(line);
		if (valueLine == "") continue;
		local first = valueLine.slice(0, 1);
		if (first == "/" || first == "#" || first == ";") continue;

		local parts = split(valueLine, " \t");
		if (parts.len() < 3) continue;
		local weaponClass = parts[0];
		if (!(weaponClass in ::SmoothRecoil.kick)) {
			SmoothRecoil_Log("WARNING: unknown EMS profile ignored: " + weaponClass);
			continue;
		}

		local recoilMultiplier = null;
		local recoveryMultiplier = null;
		try {
			recoilMultiplier = parts[1].tofloat();
			recoveryMultiplier = parts[2].tofloat();
		} catch (exception) {
			SmoothRecoil_Log("WARNING: invalid EMS values ignored: " + weaponClass);
			continue;
		}

		if (recoilMultiplier != recoilMultiplier || recoveryMultiplier != recoveryMultiplier
			|| recoilMultiplier < 0.10 || recoilMultiplier > 3.00
			|| recoveryMultiplier < 0.10 || recoveryMultiplier > 3.00) {
			SmoothRecoil_Log("WARNING: EMS values outside 0.10..3.00 ignored: " + weaponClass);
			continue;
		}

		::SmoothRecoil.recoilMultiplier[weaponClass] = recoilMultiplier;
		::SmoothRecoil.recoveryMultiplier[weaponClass] = recoveryMultiplier;
		loaded++;
	}

	::SmoothRecoil._emsConfigLoaded = true;
	SmoothRecoil_Log("loaded EMS recoil config (" + loaded + "/" + ::SmoothRecoil.kick.len() + "): ems/" + ::SmoothRecoil.EmsConfigPath);
}

function SmoothRecoil_Log(msg) {
	printl("[SR] " + msg);
}

function SmoothRecoil_AbsFloat(v) {
	if (v < 0.0) {
		return -v;
	}
	return v;
}

function SmoothRecoil_Clamp(v, lo, hi) {
	if (v < lo) {
		return lo;
	}
	if (v > hi) {
		return hi;
	}
	return v;
}

function SmoothRecoil_MoveToward(current, target, maxStep) {
	if (target > current + maxStep) {
		return current + maxStep;
	}
	if (target < current - maxStep) {
		return current - maxStep;
	}
	return target;
}

function SmoothRecoil_AngleDelta(a, b) {
	local d = a - b;
	while (d > 180.0) {
		d -= 360.0;
	}
	while (d < -180.0) {
		d += 360.0;
	}
	return d;
}

function SmoothRecoil_Contains(haystack, needle) {
	return haystack.find(needle) != null;
}

function SmoothRecoil_GetEntIndex(ent) {
	try {
		return ent.GetEntityIndex();
	} catch (e1) {
		try {
			return ent.GetIndex();
		} catch (e2) {
			return 0;
		}
	}
}

function SmoothRecoil_GetWeaponName(player, weapon) {
	if (weapon == null) {
		return "";
	}
	try {
		local cls = weapon.GetClassname();
		if (cls != null && cls != "") {
			return cls.tolower();
		}
	} catch (e1) {
	}
	try {
		local name = weapon.GetName();
		if (name != null && name != "") {
			return name.tolower();
		}
	} catch (e2) {
	}
	return "";
}

function SmoothRecoil_Classify(weaponName) {
	if (weaponName == "") {
		return "default_weapon";
	}
	if (SmoothRecoil_Contains(weaponName, "magnum")) {
		return "magnum";
	}
	if (SmoothRecoil_Contains(weaponName, "pistol")) {
		return "pistol";
	}
	if (SmoothRecoil_Contains(weaponName, "smg_mp5")) {
		return "mp5";
	}
	if (SmoothRecoil_Contains(weaponName, "smg_silenced")) {
		return "smg_silenced";
	}
	if (SmoothRecoil_Contains(weaponName, "smg")) {
		return "smg";
	}
	if (SmoothRecoil_Contains(weaponName, "m60")) {
		return "m60";
	}
	if (SmoothRecoil_Contains(weaponName, "ak47")) {
		return "rifle_ak47";
	}
	if (SmoothRecoil_Contains(weaponName, "rifle_desert")) {
		return "rifle_desert";
	}
	if (SmoothRecoil_Contains(weaponName, "rifle_sg552")) {
		return "rifle_sg552";
	}
	if (SmoothRecoil_Contains(weaponName, "sniper_scout")) {
		return "scout";
	}
	if (SmoothRecoil_Contains(weaponName, "sniper_awp")) {
		return "awp";
	}
	if (SmoothRecoil_Contains(weaponName, "sniper_military")) {
		return "sniper_military";
	}
	if (SmoothRecoil_Contains(weaponName, "hunting_rifle")) {
		return "hunting_rifle";
	}
	if (SmoothRecoil_Contains(weaponName, "sniper")) {
		return "sniper_military";
	}
	if (SmoothRecoil_Contains(weaponName, "grenade_launcher")) {
		return "grenade_launcher";
	}
	if (SmoothRecoil_Contains(weaponName, "shotgun_spas")) {
		return "shotgun_spas";
	}
	if (SmoothRecoil_Contains(weaponName, "autoshotgun")) {
		return "autoshotgun";
	}
	if (SmoothRecoil_Contains(weaponName, "shotgun_chrome")) {
		return "chrome_shotgun";
	}
	if (SmoothRecoil_Contains(weaponName, "pumpshotgun")) {
		return "pumpshotgun";
	}
	if (SmoothRecoil_Contains(weaponName, "rifle")) {
		return "rifle_m16";
	}
	if (SmoothRecoil_Contains(weaponName, "shotgun")) {
		return "pumpshotgun";
	}
	return "default_weapon";
}

function SmoothRecoil_GetPitchCap(weaponClass) {
	if (weaponClass in ::SmoothRecoil.pitchCap) {
		return ::SmoothRecoil.pitchCap[weaponClass];
	}
	return ::SmoothRecoil.maxPitch;
}

function SmoothRecoil_GetYawCap(weaponClass) {
	if (weaponClass in ::SmoothRecoil.yawCap) {
		return ::SmoothRecoil.yawCap[weaponClass];
	}
	return ::SmoothRecoil.maxYaw;
}

function SmoothRecoil_GetRisePitchSpeed(weaponClass) {
	if (weaponClass in ::SmoothRecoil.risePitchSpeed) {
		return ::SmoothRecoil.risePitchSpeed[weaponClass];
	}
	return ::SmoothRecoil.maxRisePitchSpeed;
}

function SmoothRecoil_GetClip(weapon) {
	if (weapon == null) {
		return -1;
	}
	try {
		return NetProps.GetPropInt(weapon, "m_iClip1");
	} catch (e1) {
	}
	try {
		return weapon.GetInt("m_iClip1");
	} catch (e2) {
	}
	return -1;
}

function SmoothRecoil_IsCrouching(player) {
	try {
		return (NetProps.GetPropInt(player, "m_Local.m_bDucked") != 0 || NetProps.GetPropInt(player, "m_Local.m_bDucking") != 0);
	} catch (e1) {
	}
	try {
		return (NetProps.GetPropInt(player, "m_fFlags") & 2) != 0;
	} catch (e2) {
	}
	return false;
}

function SmoothRecoil_IsOnGround(player) {
	try {
		return (NetProps.GetPropInt(player, "m_fFlags") & 1) != 0;
	} catch (e1) {
	}
	return true;
}

function SmoothRecoil_IsMoving(player) {
	try {
		local vel = player.GetVelocity();
		if (vel == null) {
			return false;
		}
		local speed2d = vel.x * vel.x + vel.y * vel.y;
		return speed2d > 2500.0;
	} catch (e1) {
	}
	return false;
}

function SmoothRecoil_IsAds(player) {
	try {
		local fov = NetProps.GetPropInt(player, "m_iFOV");
		if (fov > 0 && fov < 90) {
			return true;
		}
	} catch (e1) {
	}
	try {
		return player.GetMoveType() == MOVETYPE_OBSOLETE;
	} catch (e2) {
	}
	return false;
}

function SmoothRecoil_HasLaser(weapon) {
	if (weapon == null) {
		return false;
	}
	try {
		return (NetProps.GetPropInt(weapon, "m_upgradeBitVec") & 4) != 0;
	} catch (e1) {
	}
	return false;
}

function SmoothRecoil_GetPlayerName(player) {
	try {
		return player.GetPlayerName();
	} catch (e1) {
	}
	return "player";
}

function SmoothRecoil_GetEye(player) {
	try {
		return player.EyeAngles();
	} catch (e1) {
	}
	try {
		return player.GetAngles();
	} catch (e2) {
	}
	return null;
}

function SmoothRecoil_SetEye(player, ang) {
	if (ang == null) {
		return false;
	}
	try {
		player.SnapEyeAngles(ang);
		::SmoothRecoil._setEyeMode = "SnapEyeAngles(vector)";
		return true;
	} catch (e1) {
	}
	try {
		player.SnapEyeAngles(ang.x, ang.y, ang.z);
		::SmoothRecoil._setEyeMode = "SnapEyeAngles(x,y,z)";
		return true;
	} catch (e2) {
	}
	try {
		player.SetAngles(ang.x, ang.y, ang.z);
		::SmoothRecoil._setEyeMode = "SetAngles";
		return true;
	} catch (e3) {
	}
	if (::SmoothRecoil._setEyeMode != "failed") {
		::SmoothRecoil._setEyeMode = "failed";
		SmoothRecoil_Log("no usable eye-angle setter found yet");
	}
	return false;
}

function SmoothRecoil_EnsureState(player) {
	local id = SmoothRecoil_GetEntIndex(player);
	if (!(id in ::SmoothRecoil._players)) {
		::SmoothRecoil._players[id] <- {
			clip = -2,
			weapon = "",
			targetPitch = 0.0,
			targetYaw = 0.0,
			appliedPitch = 0.0,
			appliedYaw = 0.0,
			shotCount = 0,
			lastShotTime = 0.0,
			lastEyePitch = 0.0,
			lastEyeYaw = 0.0,
			hasLastEye = false,
			manualBlockUntil = 0.0,
			cameraBlend = 1.0,
			lastTime = Time()
		};
	}
	return ::SmoothRecoil._players[id];
}

function SmoothRecoil_ResetState(state, clip, weaponName) {
	state.clip = clip;
	state.weapon = weaponName;
	state.targetPitch = 0.0;
	state.targetYaw = 0.0;
	state.shotCount = 0;
	state.lastShotTime = 0.0;
	state.hasLastEye = false;
	state.manualBlockUntil = 0.0;
	state.cameraBlend = 1.0;
	state.lastTime = Time();
}

function SmoothRecoil_ShouldLogShot(weaponClass) {
	if (!(weaponClass in ::SmoothRecoil._fireLogsByClass)) {
		::SmoothRecoil._fireLogsByClass[weaponClass] <- 0;
	}
	if (::SmoothRecoil._fireLogsByClass[weaponClass] >= ::SmoothRecoil.LOG_FIRE_LIMIT_PER_CLASS) {
		return false;
	}
	::SmoothRecoil._fireLogsByClass[weaponClass] += 1;
	return true;
}

function SmoothRecoil_DecayState(state, dt, weaponClass) {
	local rate = ::SmoothRecoil.recover[weaponClass]
		* ::SmoothRecoil.recoveryMultiplier[weaponClass];
	local decay = 1.0 - (rate * dt);
	if (decay < 0.0) {
		decay = 0.0;
	}
	state.targetPitch *= decay;
	state.targetYaw *= decay;

	if (SmoothRecoil_AbsFloat(state.targetPitch) < 0.01) {
		state.targetPitch = 0.0;
	}
	if (SmoothRecoil_AbsFloat(state.targetYaw) < 0.01) {
		state.targetYaw = 0.0;
	}
	if (SmoothRecoil_AbsFloat(state.appliedPitch) < 0.01) {
		state.appliedPitch = 0.0;
	}
	if (SmoothRecoil_AbsFloat(state.appliedYaw) < 0.01) {
		state.appliedYaw = 0.0;
	}
}

function SmoothRecoil_NoteManualSkip(player, weaponClass, manualPitch, manualYaw) {
	if (!::SmoothRecoil.DEBUG || ::SmoothRecoil._manualSkipLogs >= ::SmoothRecoil.LOG_MANUAL_SKIP_LIMIT) {
		return;
	}
	::SmoothRecoil._manualSkipLogs += 1;
	SmoothRecoil_Log("manual input gate #" + ::SmoothRecoil._manualSkipLogs + " " + SmoothRecoil_GetPlayerName(player) + " class=" + weaponClass + " dPitch=" + manualPitch + " dYaw=" + manualYaw);
}

function SmoothRecoil_ClearCameraRecoil(state) {
	state.targetPitch = 0.0;
	state.targetYaw = 0.0;
	state.appliedPitch = 0.0;
	state.appliedYaw = 0.0;
}

function SmoothRecoil_SoftenStoredRecoil(state) {
	state.targetPitch = SmoothRecoil_Clamp(state.targetPitch, -::SmoothRecoil.maxStoredManualPitch, ::SmoothRecoil.maxStoredManualPitch);
	state.appliedPitch = SmoothRecoil_Clamp(state.appliedPitch, -::SmoothRecoil.maxStoredManualPitch, ::SmoothRecoil.maxStoredManualPitch);
	state.targetYaw = 0.0;
	state.appliedYaw = 0.0;
	if (state.cameraBlend > ::SmoothRecoil.manualCameraFactor) {
		state.cameraBlend = ::SmoothRecoil.manualCameraFactor;
	}
}

function SmoothRecoil_UpdateManualBlock(player, state) {
	local eye = SmoothRecoil_GetEye(player);
	if (eye == null) {
		return false;
	}

	local blocked = false;
	if (state.hasLastEye) {
		local manualPitch = SmoothRecoil_AbsFloat(SmoothRecoil_AngleDelta(eye.x, state.lastEyePitch));
		local manualYaw = SmoothRecoil_AbsFloat(SmoothRecoil_AngleDelta(eye.y, state.lastEyeYaw));
		if (manualYaw > ::SmoothRecoil.manualYawSoftThreshold) {
			local span = ::SmoothRecoil.manualYawBlockThreshold - ::SmoothRecoil.manualYawSoftThreshold;
			if (span < 0.01) {
				span = 0.01;
			}
			local t = SmoothRecoil_Clamp((manualYaw - ::SmoothRecoil.manualYawSoftThreshold) / span, 0.0, 1.0);
			local softBlend = 1.0 - ((1.0 - ::SmoothRecoil.manualCameraFactor) * t * t);
			if (state.cameraBlend > softBlend) {
				state.cameraBlend = softBlend;
			}
			state.targetYaw = 0.0;
			state.appliedYaw = 0.0;
			state.manualBlockUntil = Time() + ::SmoothRecoil.manualBlockSeconds;
			blocked = true;
		}
		if (manualYaw > ::SmoothRecoil.manualYawBlockThreshold) {
			state.manualBlockUntil = Time() + ::SmoothRecoil.manualBlockSeconds;
			state.cameraBlend = ::SmoothRecoil.manualCameraFactor;
			state.targetPitch *= ::SmoothRecoil.manualTargetRetainFactor;
			state.appliedPitch *= ::SmoothRecoil.manualTargetRetainFactor;
			SmoothRecoil_SoftenStoredRecoil(state);
			SmoothRecoil_NoteManualSkip(player, "input", manualPitch, manualYaw);
			blocked = true;
		}
	}

	state.lastEyePitch = eye.x;
	state.lastEyeYaw = eye.y;
	state.hasLastEye = true;
	return blocked;
}

function SmoothRecoil_ApplyShot(player, state, weaponName, weaponClass, weapon) {
	local factor = 1.0;
	local tags = "";
	if (SmoothRecoil_IsAds(player)) {
		factor *= ::SmoothRecoil.adsFactor;
		tags += " ads";
	}
	if (SmoothRecoil_HasLaser(weapon)) {
		factor *= ::SmoothRecoil.laserFactor;
		tags += " laser";
	}
	if (SmoothRecoil_IsCrouching(player)) {
		factor *= ::SmoothRecoil.crouchFactor;
		tags += " crouch";
	}
	if (SmoothRecoil_IsMoving(player)) {
		factor *= ::SmoothRecoil.moveFactor;
		tags += " move";
	}
	if (!SmoothRecoil_IsOnGround(player)) {
		factor *= ::SmoothRecoil.airFactor;
		tags += " air";
	}

	local basePitch = ::SmoothRecoil.kick[weaponClass]
		* ::SmoothRecoil.recoilMultiplier[weaponClass] * factor;
	local baseYaw = 0.0;
	local dir = 1.0;
	state.shotCount += 1;
	state.lastShotTime = Time();
	if ((state.shotCount + SmoothRecoil_GetEntIndex(player)) % 2 == 0) {
		dir = -1.0;
	}

	local pitchCap = SmoothRecoil_GetPitchCap(weaponClass);
	local yawCap = SmoothRecoil_GetYawCap(weaponClass);
	state.targetPitch = SmoothRecoil_Clamp(state.targetPitch + basePitch, -pitchCap, pitchCap);
	state.targetYaw = 0.0;

	if (SmoothRecoil_ShouldLogShot(weaponClass)) {
		SmoothRecoil_Log("shot " + weaponClass + "#" + ::SmoothRecoil._fireLogsByClass[weaponClass] + " " + SmoothRecoil_GetPlayerName(player) + " " + weaponName + " targetPitch=" + state.targetPitch + " targetYaw=" + state.targetYaw + tags);
	}
}

function SmoothRecoil_ApplyView(player, state, dt, weaponClass) {
	if (Time() < state.manualBlockUntil) {
		SmoothRecoil_SoftenStoredRecoil(state);
		SmoothRecoil_DecayState(state, dt, weaponClass);
		return;
	}

	if (SmoothRecoil_AbsFloat(state.targetPitch) < 0.01 && SmoothRecoil_AbsFloat(state.targetYaw) < 0.01 && SmoothRecoil_AbsFloat(state.appliedPitch) < 0.01 && SmoothRecoil_AbsFloat(state.appliedYaw) < 0.01) {
		return;
	}

	local eye = SmoothRecoil_GetEye(player);
	if (eye == null) {
		return;
	}

	local now = Time();
	local recovering = (now - state.lastShotTime) > ::SmoothRecoil.recoveryDelay;
	local manualScale = 1.0;
	local manualPitch = 0.0;
	local manualYaw = 0.0;
	if (state.hasLastEye) {
		manualPitch = SmoothRecoil_AbsFloat(SmoothRecoil_AngleDelta(eye.x, state.lastEyePitch));
		manualYaw = SmoothRecoil_AbsFloat(SmoothRecoil_AngleDelta(eye.y, state.lastEyeYaw));
	}
	if (recovering && state.hasLastEye) {
		if (manualPitch > ::SmoothRecoil.manualInputThreshold || manualYaw > ::SmoothRecoil.manualInputThreshold) {
			manualScale = ::SmoothRecoil.manualReturnFactor;
		}
	}

	local speed = recovering ? ::SmoothRecoil.returnSpeed : ::SmoothRecoil.riseSpeed;
	local alpha = SmoothRecoil_Clamp(speed * dt, 0.03, recovering ? 0.35 : 0.85);
	state.cameraBlend = SmoothRecoil_MoveToward(state.cameraBlend, 1.0, ::SmoothRecoil.cameraBlendInSpeed * dt);
	local oldPitch = state.appliedPitch;
	local oldYaw = state.appliedYaw;

	local nextPitch = state.appliedPitch + ((state.targetPitch - state.appliedPitch) * alpha);
	local nextYaw = state.appliedYaw + ((state.targetYaw - state.appliedYaw) * alpha);
	if (recovering) {
		nextPitch = SmoothRecoil_MoveToward(state.appliedPitch, nextPitch, ::SmoothRecoil.maxReturnPitchSpeed * dt * manualScale);
		nextYaw = SmoothRecoil_MoveToward(state.appliedYaw, nextYaw, ::SmoothRecoil.maxReturnYawSpeed * dt * manualScale);
	} else {
		nextPitch = SmoothRecoil_MoveToward(state.appliedPitch, nextPitch, SmoothRecoil_GetRisePitchSpeed(weaponClass) * dt);
		nextYaw = SmoothRecoil_MoveToward(state.appliedYaw, nextYaw, ::SmoothRecoil.maxRiseYawSpeed * dt);
	}
	state.appliedPitch = nextPitch;
	state.appliedYaw = nextYaw;

	local pitchDelta = (state.appliedPitch - oldPitch) * state.cameraBlend;
	local yawDelta = (state.appliedYaw - oldYaw) * ::SmoothRecoil.cameraYawFactor;
	if (SmoothRecoil_AbsFloat(pitchDelta) < 0.005 && SmoothRecoil_AbsFloat(yawDelta) < 0.005) {
		state.lastEyePitch = eye.x;
		state.lastEyeYaw = eye.y;
		state.hasLastEye = true;
		SmoothRecoil_DecayState(state, dt, weaponClass);
		return;
	}

	eye.x += pitchDelta;
	eye.y += yawDelta;
	if (SmoothRecoil_SetEye(player, eye)) {
		state.lastEyePitch = eye.x;
		state.lastEyeYaw = eye.y;
		state.hasLastEye = true;
	}

	SmoothRecoil_DecayState(state, dt, weaponClass);
}

function SmoothRecoil_ProcessPlayer(player) {
	if (player == null) {
		return;
	}
	try {
		if (!player.IsSurvivor()) {
			return;
		}
	} catch (e1) {
		try {
			if (player.GetTeam() != 2) {
				return;
			}
		} catch (e2) {
			return;
		}
	}
	try {
		if (!player.IsAlive()) {
			return;
		}
	} catch (e3) {
	}

	local weapon = null;
	try {
		weapon = player.GetActiveWeapon();
	} catch (e4) {
		return;
	}

	local weaponName = SmoothRecoil_GetWeaponName(player, weapon);
	local weaponClass = SmoothRecoil_Classify(weaponName);
	local clip = SmoothRecoil_GetClip(weapon);
	local state = SmoothRecoil_EnsureState(player);
	local now = Time();
	local dt = now - state.lastTime;
	if (dt <= 0.0 || dt > 0.25) {
		dt = ::SmoothRecoil.THINK_INTERVAL;
	}
	state.lastTime = now;
	local manualBlocked = SmoothRecoil_UpdateManualBlock(player, state);

	if (weaponName != state.weapon || clip < 0 || state.clip < 0) {
		SmoothRecoil_ResetState(state, clip, weaponName);
		return;
	}

	if (clip < state.clip) {
		local shots = state.clip - clip;
		if (shots > 5) {
			shots = 5;
		}
		for (local s = 0; s < shots; s++) {
			SmoothRecoil_ApplyShot(player, state, weaponName, weaponClass, weapon);
		}
	}
	state.clip = clip;

	if (manualBlocked || Time() < state.manualBlockUntil) {
		SmoothRecoil_SoftenStoredRecoil(state);
		SmoothRecoil_DecayState(state, dt, weaponClass);
		return;
	}

	SmoothRecoil_ApplyView(player, state, dt, weaponClass);
}

function SmoothRecoil_Think() {
	for (local i = 1; i <= 32; i++) {
		local player = null;
		try {
			player = PlayerInstanceFromIndex(i);
		} catch (e1) {
			try {
				player = GetPlayerByIndex(i);
			} catch (e2) {
				player = null;
			}
		}
		if (player != null) {
			SmoothRecoil_ProcessPlayer(player);
		}
	}

	if (::SmoothRecoil.DEBUG) {
		local now = Time();
		if (now - ::SmoothRecoil._lastStatusLog >= ::SmoothRecoil.LOG_STATUS_INTERVAL) {
			::SmoothRecoil._lastStatusLog = now;
			SmoothRecoil_Log("think alive source=" + ::SmoothRecoil._lastStartSource + " setter=" + ::SmoothRecoil._setEyeMode + " tracked=" + ::SmoothRecoil._players.len());
		}
	}
	return ::SmoothRecoil.THINK_INTERVAL;
}

::SmoothRecoil.rawset("OnMapSpawn", function(source) {
	::SmoothRecoil._lastStartSource = source;
	if (!::SmoothRecoil._emsConfigLoaded) {
		SmoothRecoil_LoadEmsConfig();
	}
	SmoothRecoil_Log("core loaded v" + ::SmoothRecoil.VERSION + " from " + source + " t=" + Time());

	if (::SmoothRecoil._started && ::SmoothRecoil._thinker != null) {
		SmoothRecoil_Log("thinker already running");
		return;
	}

	::SmoothRecoil._started = true;
	::SmoothRecoil._players = {};
	::SmoothRecoil._fireLogsByClass = {};
	::SmoothRecoil._manualSkipLogs = 0;
	::SmoothRecoil._lastStatusLog = 0.0;
	::SmoothRecoil._setEyeMode = "unknown";

	local thinker = SpawnEntityFromTable("info_target", { targetname = "smooth_recoil_thinker" });
	if (thinker == null) {
		SmoothRecoil_Log("ERROR: failed to spawn thinker");
		return;
	}

	::SmoothRecoil._thinker = thinker;
	AddThinkToEnt(thinker, ::SmoothRecoil.THINK_NAME);
	SmoothRecoil_Log("thinker started interval=" + ::SmoothRecoil.THINK_INTERVAL);
});
