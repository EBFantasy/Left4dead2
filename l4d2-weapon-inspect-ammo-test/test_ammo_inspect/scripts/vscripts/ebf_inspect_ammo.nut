//-----------------------------------------------------------------------------
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 EpicBF
//
// [TEST] Weapon Inspect Ammo Check  --  ebf_inspect_ammo.nut
//
// Hold E (+use) and tap R (+reload) to "inspect" the weapon in your hands.
//
//   * E+R does NOT reload. The weapon's own reload/inspect animation is driven
//     directly on the viewmodel animation layer, and any real reload that the
//     same keypress may have started is aborted, with clip AND reserve ammo
//     restored from a snapshot taken before the press. No ammo is ever spent
//     or gained.
//   * The remaining ammo is reported in the chat area and at screen center.
//
// Loaded from mapspawn_addon.nut so it runs on every map and every game mode
// without replacing any stock VScript file.
//
// Console helpers:
//     script EBFInspectAmmo.Status()      full diagnostic dump
//     script EBFInspectAmmo.Reload()      re-read the EMS settings file
//     script EBFInspectAmmo.TestFire()    run one inspect on the host, verbosely
//-----------------------------------------------------------------------------

if ("EBFInspectAmmo" in getroottable() && EBFInspectAmmo.Loaded)
{
	// Already initialised this session; just make sure the think is alive.
	printl("[InspectAmmo] Already loaded, re-arming manager.");
	EBFInspectAmmo.StartManager();
}
else
{

::EBFInspectAmmo <- {};

EBFInspectAmmo.VERSION <- "1.3.0";
EBFInspectAmmo.TAG <- "[InspectAmmo]";
EBFInspectAmmo.Loaded <- false;
EBFInspectAmmo.Manager <- null;
EBFInspectAmmo.State <- {};

//-----------------------------------------------------------------------------
// Button bits, per CTerrorPlayer::GetButtonMask() documentation.
//-----------------------------------------------------------------------------
EBFInspectAmmo.IN_USE <- 32;
EBFInspectAmmo.IN_RELOAD <- 8192;

// IN_ALT1 (+alt1) exists in L4D2 but is UNBOUND by default, so it collides
// with nothing. This is the dedicated inspect key; bind it with:
//     bind v "+alt1"
// A dedicated key also removes the E+R timing problem entirely: there is no
// modifier to release early and no reload key to fight over.
EBFInspectAmmo.IN_ALT1 <- 16384;
EBFInspectAmmo.IN_ALT2 <- 32768;
EBFInspectAmmo.IN_ZOOM <- 524288;
EBFInspectAmmo.IN_SPEED <- 65536;
EBFInspectAmmo.IN_DUCK <- 4;

// Selectable trigger keys, chosen by the "key" setting.
EBFInspectAmmo.KeyBits <- {
	alt1 = 16384
	alt2 = 32768
	zoom = 524288
	reload = 8192
};

// ClientPrint destinations.
EBFInspectAmmo.HUD_PRINTTALK <- 3;
EBFInspectAmmo.HUD_PRINTCENTER <- 4;

EBFInspectAmmo.SETTINGS_PATH <- "ebf_inspect_ammo/settings.txt";

//-----------------------------------------------------------------------------
// Settings, overridable from left4dead2/ems/ebf_inspect_ammo/settings.txt
//-----------------------------------------------------------------------------
EBFInspectAmmo.Settings <- {
	enable = 1            // Master switch.
	key = "alt1"          // Trigger key: alt1 | alt2 | zoom | reload.
	modifier = "none"     // Extra key to hold: none | use | duck | speed.
	require_use = 0       // Legacy: 1 forces modifier=use (E+R behaviour).
	output_chat = 1       // Print the ammo line to the chat area.
	output_center = 1     // Print the ammo line at screen center.
	play_animation = 1    // Drive the weapon's reload/inspect animation.
	block_reload = 1      // Report a full magazine while E is held.
	spoof_time = 2.50     // Seconds the magazine is held "full" per inspect.
	cooldown = 1.20       // Seconds between inspects, per player.
	melee_ok = 1          // Allow inspecting melee / clipless items.
	debug = 0             // Verbose console diagnostics.
}

EBFInspectAmmo.Bounds <- {
	enable = [0, 1]
	require_use = [0, 1]
	output_chat = [0, 1]
	output_center = [0, 1]
	play_animation = [0, 1]
	block_reload = [0, 1]
	spoof_time = [0.5, 10.0]
	cooldown = [0.0, 10.0]
	melee_ok = [0, 1]
	debug = [0, 1]
}

// Settings whose value is a word, not a number.
EBFInspectAmmo.StringKeys <- {
	key = ["alt1", "alt2", "zoom", "reload"]
	modifier = ["none", "use", "duck", "speed"]
};

// Keys that stay floats; everything else is coerced to int.
EBFInspectAmmo.FloatKeys <- { cooldown = 1, spoof_time = 1 };

// Pristine copy of the defaults, so a reload reverts any key that was removed
// from the settings file instead of silently keeping the previous value.
EBFInspectAmmo.Defaults <- {};
foreach (k, v in EBFInspectAmmo.Settings)
	EBFInspectAmmo.Defaults[k] <- v;

//-----------------------------------------------------------------------------
// Items with no magazine worth reporting.
//-----------------------------------------------------------------------------
EBFInspectAmmo.NoClipWeapons <- {
	weapon_melee = 1
	weapon_pain_pills = 1
	weapon_adrenaline = 1
	weapon_first_aid_kit = 1
	weapon_defibrillator = 1
	weapon_molotov = 1
	weapon_pipe_bomb = 1
	weapon_vomitjar = 1
	weapon_upgradepack_explosive = 1
	weapon_upgradepack_incendiary = 1
	weapon_gascan = 1
	weapon_propanetank = 1
	weapon_oxygentank = 1
	weapon_fireworkcrate = 1
	weapon_cola_bottles = 1
	weapon_gnome = 1
}

EBFInspectAmmo.WeaponNames <- {
	weapon_pistol = "Pistol"
	weapon_pistol_magnum = "Magnum"
	weapon_smg = "SMG"
	weapon_smg_silenced = "Silenced SMG"
	weapon_smg_mp5 = "MP5"
	weapon_pumpshotgun = "Pump Shotgun"
	weapon_shotgun_chrome = "Chrome Shotgun"
	weapon_autoshotgun = "Auto Shotgun"
	weapon_shotgun_spas = "SPAS Shotgun"
	weapon_rifle = "M16 Rifle"
	weapon_rifle_ak47 = "AK-47"
	weapon_rifle_desert = "Desert Rifle"
	weapon_rifle_sg552 = "SG552"
	weapon_rifle_m60 = "M60"
	weapon_hunting_rifle = "Hunting Rifle"
	weapon_sniper_military = "Military Sniper"
	weapon_sniper_scout = "Scout"
	weapon_sniper_awp = "AWP"
	weapon_grenade_launcher = "Grenade Launcher"
	weapon_chainsaw = "Chainsaw"
	weapon_melee = "Melee"
}

//-----------------------------------------------------------------------------
// Logging.
//-----------------------------------------------------------------------------
EBFInspectAmmo.Log <- function (msg)
{
	printl(TAG + " " + msg);
}

EBFInspectAmmo.Dbg <- function (msg)
{
	if (Settings.debug)
		printl(TAG + "[dbg] " + msg);
}

EBFInspectAmmo.Warn <- function (msg)
{
	// error() prints in red and lands in the console log.
	error(TAG + " WARNING: " + msg + "\n");
}

//-----------------------------------------------------------------------------
// EMS settings file.
//-----------------------------------------------------------------------------
EBFInspectAmmo.DefaultSettingsText <- function ()
{
	// NOTE: the value must start on the same line as 'return'. Squirrel ends a
	// statement at the newline, so 'return' alone on a line returns null.
	return "// ============================================================\n" +
		"// [TEST] Weapon Inspect Ammo Check " + VERSION + "\n" +
		"// File: left4dead2/ems/ebf_inspect_ammo/settings.txt\n" +
		"//\n" +
		"// Syntax: one \"key value\" pair per line. // starts a comment.\n" +
		"// After editing, change level or run in the console:\n" +
		"//     script EBFInspectAmmo.Reload()\n" +
		"//\n" +
		"// enable          0 or 1. Master switch. Default 1.\n" +
		"//\n" +
		"// key             Which key inspects: alt1 | alt2 | zoom | reload.\n" +
		"//                 Default alt1. alt1/alt2 are UNBOUND in vanilla L4D2,\n" +
		"//                 so they clash with nothing. Bind one in the console:\n" +
		"//                     bind v \"+alt1\"\n" +
		"//                 Then just tap V to inspect. Put the bind line in\n" +
		"//                 left4dead2/cfg/autoexec.cfg to make it permanent.\n" +
		"// modifier        Extra key to hold: none | use | duck | speed.\n" +
		"//                 Default none. Only needed if your chosen key is\n" +
		"//                 already used for something else.\n" +
		"//                 use = E, duck = Ctrl, speed = Shift.\n" +
		"// require_use     Legacy switch. 1 restores the old E+R binding and\n" +
		"//                 overrides key/modifier. Default 0. Not recommended:\n" +
		"//                 R has to serve two purposes, so quick taps can still\n" +
		"//                 slip a real reload through.\n" +
		"// output_chat     0 or 1. Ammo line in the chat area. Default 1.\n" +
		"// output_center   0 or 1. Ammo line at screen center. Default 1.\n" +
		"// play_animation  0 or 1. Drive the weapon's reload/inspect animation.\n" +
		"//                 Custom weapon models that ship an inspect animation\n" +
		"//                 will show it. Stock models show their reload. Default 1.\n" +
		"// block_reload    0 or 1. While E is held, report the magazine as full\n" +
		"//                 so the engine refuses to reload. Default 1.\n" +
		"//                 The true ammo count is restored when E is released,\n" +
		"//                 and is what the readout always shows.\n" +
		"//                 Requires require_use 1.\n" +

		"// spoof_time      0.5 to 10.0. Seconds the magazine is reported full\n" +
		"//                 after each inspect, covering the animation so no\n" +
		"//                 reload can start. Default 2.50. Raise it if a long\n" +
		"//                 custom inspect animation gets cut short.\n" +
		"// cooldown        0.0 to 10.0. Seconds between inspects. Default 1.20.\n" +
		"// melee_ok        0 or 1. Allow inspecting melee and clipless items.\n" +
		"//                 Default 1.\n" +
		"// debug           0 or 1. Verbose console diagnostics. Default 0.\n" +
		"// ============================================================\n" +
		"enable 1\n" +
		"key alt1\n" +
		"modifier none\n" +
		"require_use 0\n" +
		"output_chat 1\n" +
		"output_center 1\n" +
		"play_animation 1\n" +
		"block_reload 1\n" +

		"spoof_time 2.50\n" +
		"cooldown 1.20\n" +
		"melee_ok 1\n" +
		"debug 0\n";
}

EBFInspectAmmo.LoadSettings <- function ()
{
	local raw = null;

	// Start from the defaults so removing a line from the file restores it.
	foreach (k, v in Defaults)
		Settings[k] = v;

	try
	{
		// FileToString reads relative to left4dead2/ems/, null when missing.
		raw = FileToString(SETTINGS_PATH);
	}
	catch (e)
	{
		Warn("Could not read ems/" + SETTINGS_PATH + " (" + e + ")");
		raw = null;
	}

	if (raw == null || raw.len() == 0)
	{
		try
		{
			StringToFile(SETTINGS_PATH, DefaultSettingsText());
			Log("Created default settings file at ems/" + SETTINGS_PATH);
		}
		catch (e)
		{
			Warn("Could not create ems/" + SETTINGS_PATH + " (" + e + "). Using built-in defaults.");
		}
		return;
	}

	local applied = 0;

	foreach (line in split(raw, "\n\r"))
	{
		line = strip(line);
		if (line.len() == 0)
			continue;
		if (line.len() >= 2 && line.slice(0, 2) == "//")
			continue;

		local parts = split(line, " \t");
		if (parts.len() < 2)
			continue;

		local key = strip(parts[0]);
		local valStr = strip(parts[1]);

		if (!(key in Settings))
		{
			Warn("Unknown key '" + key + "' in ems/" + SETTINGS_PATH + " - ignored.");
			continue;
		}

		// Word-valued settings are validated against their allowed list.
		if (key in StringKeys)
		{
			local lowered = valStr.tolower();
			local ok = false;
			foreach (allowed in StringKeys[key])
				if (lowered == allowed) { ok = true; break; }

			if (ok)
			{
				Settings[key] = lowered;
				applied++;
			}
			else
			{
				local list = "";
				foreach (a in StringKeys[key]) list += (list.len() ? ", " : "") + a;
				Warn("Value '" + valStr + "' for '" + key
					+ "' is not one of: " + list + " - ignored.");
			}
			continue;
		}

		local val = null;
		try
		{
			val = valStr.tofloat();
		}
		catch (e)
		{
			Warn("Non-numeric value '" + valStr + "' for '" + key + "' - ignored.");
			continue;
		}

		local range = Bounds[key];
		if (val < range[0] || val > range[1])
		{
			Warn("Value " + val + " for '" + key + "' is outside "
				+ range[0] + ".." + range[1] + " - ignored.");
			continue;
		}

		Settings[key] = (key in FloatKeys) ? val : val.tointeger();
		applied++;
	}

	Log("Loaded " + applied + " setting(s) from ems/" + SETTINGS_PATH);
}

//-----------------------------------------------------------------------------
// Ammo reading.
//-----------------------------------------------------------------------------
EBFInspectAmmo.PrettyName <- function (classname)
{
	if (classname in WeaponNames)
		return WeaponNames[classname];

	local name = classname;
	if (name.len() > 7 && name.slice(0, 7) == "weapon_")
		name = name.slice(7);

	local out = "";
	local upper = true;
	foreach (ch in name)
	{
		local c = ch.tochar();
		if (c == "_")
		{
			out += " ";
			upper = true;
			continue;
		}
		out += upper ? c.toupper() : c;
		upper = false;
	}
	return out;
}

// Never throws. Returns clip/reserve info for the given weapon.
// realClipOverride: when the magazine is currently spoofed full, pass the true
// value so the readout shows what the player actually has, not the fake.
EBFInspectAmmo.ReadAmmo <- function (player, weapon, realClipOverride = null)
{
	local info = {
		classname = "unknown"
		name = "Unknown"
		hasClip = false
		clip = -1
		maxClip = -1
		reserve = -1
		ammoType = -1
	};

	if (weapon == null || !weapon.IsValid())
		return info;

	info.classname = weapon.GetClassname();
	info.name = PrettyName(info.classname);

	if (info.classname in NoClipWeapons)
		return info;

	try
	{
		if (!NetProps.HasProp(weapon, "m_iClip1"))
			return info;

		info.hasClip = true;
		info.clip = (realClipOverride != null)
			? realClipOverride
			: NetProps.GetPropInt(weapon, "m_iClip1");
	}
	catch (e)
	{
		Dbg("m_iClip1 read failed on " + info.classname + ": " + e);
		return info;
	}

	// GetMaxClip1() honours weapon-script clip size edits.
	try
	{
		if ("GetMaxClip1" in weapon)
			info.maxClip = weapon.GetMaxClip1();
	}
	catch (e) { info.maxClip = -1; }

	// Reserve ammo lives on the player, indexed by the weapon's ammo type.
	try
	{
		if (NetProps.HasProp(weapon, "m_iPrimaryAmmoType"))
		{
			info.ammoType = NetProps.GetPropInt(weapon, "m_iPrimaryAmmoType");
			if (info.ammoType >= 0)
				info.reserve = NetProps.GetPropIntArray(player, "m_iAmmo", info.ammoType);
		}
	}
	catch (e) { info.reserve = -1; }

	return info;
}

EBFInspectAmmo.FormatAmmo <- function (info)
{
	if (!info.hasClip)
		return info.name + ": no magazine";

	local text = info.name + ": " + info.clip;

	if (info.maxClip > 0)
		text += "/" + info.maxClip;

	text += (info.reserve >= 0) ? ("  |  reserve " + info.reserve) : "  |  reserve --";

	return text;
}

//-----------------------------------------------------------------------------
// Animation.
//
// The viewmodel animation layer is the documented VScript route for forcing a
// first person animation, and is what community inspect mods use. We look for
// a dedicated inspect sequence first, then fall back to the reload sequence,
// which is exactly the animation a full magazine R press shows on the custom
// weapon models this feature is meant for.
//-----------------------------------------------------------------------------
EBFInspectAmmo.InspectSeqNames <- [
	"inspect", "ACT_VM_INSPECT", "idle_inspect", "inspect_start", "lookat01"
];

EBFInspectAmmo.ReloadSeqNames <- [
	"ACT_VM_RELOAD", "reload", "ACT_SHOTGUN_RELOAD_START"
];

EBFInspectAmmo.FindSequence <- function (vm, names)
{
	foreach (candidate in names)
	{
		try
		{
			local found = vm.LookupSequence(candidate);
			if (found != null && found > 0)
				return { id = found, name = candidate };
		}
		catch (e) { }
	}
	return null;
}

EBFInspectAmmo.PlayInspectAnim <- function (player, weapon, verbose)
{
	if (!Settings.play_animation)
		return false;

	local vm = null;
	try
	{
		vm = NetProps.GetPropEntity(player, "m_hViewModel");
	}
	catch (e)
	{
		Dbg("m_hViewModel read failed: " + e);
		return false;
	}

	if (vm == null || !vm.IsValid())
	{
		Dbg("viewmodel handle invalid - cannot play animation");
		return false;
	}

	local pick = FindSequence(vm, InspectSeqNames);
	if (pick == null)
		pick = FindSequence(vm, ReloadSeqNames);

	if (pick == null)
	{
		if (verbose || Settings.debug)
			Log("No inspect or reload sequence found on " + vm.GetModelName()
				+ " - the model has no animation to show.");
		return false;
	}

	try
	{
		NetProps.SetPropInt(vm, "m_nLayerSequence", pick.id);
		NetProps.SetPropInt(vm, "m_nLayer", 0);
		NetProps.SetPropFloat(vm, "m_flLayerStartTime", Time());

		// Bumping the animation parity makes the client replay the layer even
		// when the same sequence is requested twice in a row.
		if (NetProps.HasProp(vm, "m_nLayerAnimationParity"))
		{
			local parity = NetProps.GetPropInt(vm, "m_nLayerAnimationParity");
			NetProps.SetPropInt(vm, "m_nLayerAnimationParity", (parity + 1) & 0x3);
		}

		if (verbose || Settings.debug)
			Log("Playing sequence '" + pick.name + "' (id " + pick.id + ") on "
				+ vm.GetModelName());

		return true;
	}
	catch (e)
	{
		Warn("Failed to set viewmodel animation layer: " + e);
		return false;
	}
}

//-----------------------------------------------------------------------------
// The inspect action.
//-----------------------------------------------------------------------------
EBFInspectAmmo.DoInspect <- function (player, state, verbose)
{
	local weapon = null;
	try
	{
		weapon = player.GetActiveWeapon();
	}
	catch (e)
	{
		Dbg("GetActiveWeapon failed: " + e);
		return false;
	}

	if (weapon == null || !weapon.IsValid())
	{
		if (verbose) Log("No active weapon in hand.");
		return false;
	}

	// If this weapon's clip is currently spoofed full, report the real count.
	local realClip = null;
	if (state.spoofActive && state.spoofWeapon == weapon)
		realClip = state.spoofRealClip;

	local info = ReadAmmo(player, weapon, realClip);

	if (!info.hasClip && !Settings.melee_ok)
	{
		Dbg("skipping clipless weapon " + info.classname);
		return false;
	}

	// Spoof the magazine full for the duration of the animation so the engine
	// refuses to start a reload, then release it automatically.
	if (Settings.block_reload && info.hasClip)
	{
		SetClipSpoofed(player, state, true);
		state.spoofUntil = Time() + Settings.spoof_time;
	}

	PlayInspectAnim(player, weapon, verbose);

	local text = FormatAmmo(info);

	if (Settings.output_chat)
		ClientPrint(player, HUD_PRINTTALK, "\x04[Inspect]\x01 " + text);

	if (Settings.output_center)
		ClientPrint(player, HUD_PRINTCENTER, text);

	Dbg(player.GetPlayerName() + " inspected -> " + text);
	if (verbose)
		Log("Inspect result: " + text);

	return true;
}

//-----------------------------------------------------------------------------
// Player state.
//-----------------------------------------------------------------------------
EBFInspectAmmo.GetState <- function (idx)
{
	if (!(idx in State))
	{
		State[idx] <- {
			lastButtons = 0
			lastInspect = 0.0
			spoofActive = false
			spoofWeapon = null
			spoofRealClip = -1
			spoofFakeClip = -1
			spoofUntil = 0.0
		};
	}
	return State[idx];
}


// Resolves the configured trigger key to its button bit.
EBFInspectAmmo.TriggerBit <- function ()
{
	// Legacy compatibility: require_use 1 reproduces the old E+R binding.
	if (Settings.require_use && Settings.key == "alt1" && Settings.modifier == "none")
		return IN_RELOAD;

	if (Settings.key in KeyBits)
		return KeyBits[Settings.key];

	return IN_ALT1;
}

// Resolves the configured modifier to its button bit, 0 when none.
EBFInspectAmmo.ModifierBit <- function ()
{
	if (Settings.require_use && Settings.key == "alt1" && Settings.modifier == "none")
		return IN_USE;

	switch (Settings.modifier)
	{
		case "use":   return IN_USE;
		case "duck":  return IN_DUCK;
		case "speed": return IN_SPEED;
	}
	return 0;
}

// Releases a time-limited spoof once its deadline passes.
//
// The spoof lifetime is driven by a timer, NOT by how long a key is held.
// That is the fix for the E+R timing complaints: tapping the key and holding
// it now behave identically, and letting go early can no longer expose a
// partially empty magazine to the engine mid-animation.
EBFInspectAmmo.UpdateSpoof <- function (player, state)
{
	if (!state.spoofActive)
		return;

	if (state.spoofUntil > 0.0 && Time() >= state.spoofUntil)
	{
		SetClipSpoofed(player, state, false);
		state.spoofUntil = 0.0;
		return;
	}

	// Keep it pinned while it is meant to be active.
	SetClipSpoofed(player, state, true);
}

// Reload prevention: the "already full" trick.
//
// WHY NOT m_afButtonDisabled:
// Setting the IN_RELOAD bit there does stop the reload, but the engine strips
// that bit from the usercmd BEFORE anything else runs
// (player_command.cpp: ucmd->buttons &= ~m_afButtonDisabled), and m_nButtons
// is then assigned from that already-filtered mask
// (baseplayer_shared.cpp: m_nButtons = nUserCmdButtonMask).
// So on the server there is no way to both suppress R and still see R. v1.1.0
// tried exactly that and blinded itself, which is why the readout vanished and
// the weapon stuttered.
//
// WHAT WE DO INSTEAD:
// While the modifier (E) is held we temporarily report the magazine as FULL by
// writing m_iClip1 = GetMaxClip1(). CTerrorGun::Reload() bails out when the
// clip is already full, so pressing R does nothing but play the weapon's
// full-magazine idle/inspect animation -- exactly the behaviour we want.
// The real clip value is restored the instant E is released.
//
// The reserve pool is never touched, and because the weapon never enters a
// reload, no ammo can move. R stays fully functional the moment E is let go.
EBFInspectAmmo.SetClipSpoofed <- function (player, state, spoof)
{
	// --- turn the spoof OFF -------------------------------------------
	if (!spoof)
	{
		if (!state.spoofActive)
			return;

		local w = state.spoofWeapon;
		if (w != null && w.IsValid())
		{
			try
			{
				// Only restore if nothing else changed the clip meanwhile
				// (e.g. the player fired). Never hand out free ammo.
				local now = NetProps.GetPropInt(w, "m_iClip1");
				if (now == state.spoofFakeClip)
					NetProps.SetPropInt(w, "m_iClip1", state.spoofRealClip);
				else
					Dbg("clip changed during spoof, leaving it at " + now);
			}
			catch (e) { Dbg("un-spoof failed: " + e); }
		}

		state.spoofActive = false;
		state.spoofWeapon = null;
		state.spoofRealClip = -1;
		state.spoofFakeClip = -1;
		Dbg("clip spoof OFF for " + player.GetPlayerName());
		return;
	}

	// --- turn the spoof ON --------------------------------------------
	if (state.spoofActive)
	{
		// If the player switched weapons while holding E, restore the old one
		// first so it is never left showing a fake magazine.
		local cur = null;
		try { cur = player.GetActiveWeapon(); } catch (e) { }
		if (cur != state.spoofWeapon)
		{
			SetClipSpoofed(player, state, false);
			// Fall through on the next frame with the new weapon.
			return;
		}

		// Keep it pinned: the weapon may try to start a reload anyway.
		local w = state.spoofWeapon;
		if (w != null && w.IsValid())
		{
			try
			{
				if (NetProps.GetPropInt(w, "m_iClip1") < state.spoofFakeClip)
					NetProps.SetPropInt(w, "m_iClip1", state.spoofFakeClip);
			}
			catch (e) { }
		}
		return;
	}

	local w = null;
	try { w = player.GetActiveWeapon(); } catch (e) { return; }
	if (w == null || !w.IsValid())
		return;

	// Only guns with a magazine make sense here.
	local cls = w.GetClassname();
	if (cls in NoClipWeapons)
		return;

	try
	{
		if (!NetProps.HasProp(w, "m_iClip1"))
			return;

		local maxClip = -1;
		if ("GetMaxClip1" in w)
			maxClip = w.GetMaxClip1();
		if (maxClip == null || maxClip <= 0)
			return;

		local real = NetProps.GetPropInt(w, "m_iClip1");
		if (real >= maxClip)
			return;                       // already full, nothing to fake

		state.spoofWeapon = w;
		state.spoofRealClip = real;
		state.spoofFakeClip = maxClip;
		state.spoofActive = true;

		NetProps.SetPropInt(w, "m_iClip1", maxClip);
		Dbg("clip spoof ON for " + player.GetPlayerName()
			+ " (" + real + " -> " + maxClip + ")");
	}
	catch (e)
	{
		Dbg("spoof failed: " + e);
		state.spoofActive = false;
		state.spoofWeapon = null;
	}
}

// Always restore the true clip; used on death, weapon switch, shutdown, etc.
EBFInspectAmmo.ForceUnspoof <- function (player, state)
{
	if (state.spoofActive)
		SetClipSpoofed(player, state, false);
}

//-----------------------------------------------------------------------------
// Think. One entity drives every player.
//-----------------------------------------------------------------------------
EBFInspectAmmo.ManagerThink <- function ()
{
	if (!Settings.enable)
	{
		// Disabled at runtime: release anyone still holding a blocked key.
		local p = null;
		while (p = Entities.FindByClassname(p, "player"))
		{
			if (p.IsValid())
				ForceUnspoof(p, GetState(p.GetEntityIndex()));
		}
		return 1.0;
	}

	local now = Time();
	local player = null;

	while (player = Entities.FindByClassname(player, "player"))
	{
		if (!player.IsValid())
			continue;

		local state = GetState(player.GetEntityIndex());

		local usable = false;
		try
		{
			usable = player.IsSurvivor()
				&& !player.IsDead()
				&& !player.IsDying()
				&& !player.IsIncapacitated()
				&& !player.IsHangingFromLedge();
		}
		catch (e) { usable = false; }

		if (!usable)
		{
			ForceUnspoof(player, state);
			state.lastButtons = 0;
			continue;
		}

		local buttons = 0;
		try
		{
			buttons = player.GetButtonMask();
		}
		catch (e) { continue; }

		// --- Reload-key suppression -------------------------------------
		// While the modifier (E) is held, the reload key is disabled at the
		// input layer so it can never start a reload. The moment E is
		// released the key is handed straight back.
		//
		// Complication: m_afButtonDisabled strips the bit before it reaches
		// GetButtonMask(), so once we suppress R we can no longer see the R
		// press through the normal mask. m_nButtons carries the unfiltered
		// input, so we read that when it is available.
		local trigBit = TriggerBit();
		local modBit  = ModifierBit();
		local modHeld = (modBit == 0) || ((buttons & modBit) != 0);

		local pressed = buttons & (~state.lastButtons);
		state.lastButtons = buttons;

		// The magazine is spoofed full only while the inspect animation is
		// actually playing. It is armed on the keypress below and released by
		// UpdateSpoof() once spoof_time elapses, so there is no dependency on
		// how long any key stays held. This is what makes a quick tap behave
		// exactly like a long press.
		UpdateSpoof(player, state);

		// Rising edge on the trigger key only, so holding it does not repeat.
		if (!(pressed & trigBit))
			continue;

		if (!modHeld)
			continue;

		if (now - state.lastInspect < Settings.cooldown)
		{
			Dbg("cooldown active for " + player.GetPlayerName());
			continue;
		}

		state.lastInspect = now;
		DoInspect(player, state, false);
	}

	return 0.0; // Next frame.
}

//-----------------------------------------------------------------------------
// Manager lifecycle.
//-----------------------------------------------------------------------------
EBFInspectAmmo.StartManager <- function ()
{
	if (Manager != null && Manager.IsValid())
	{
		Dbg("manager already running");
		return true;
	}

	local ent = null;
	try
	{
		ent = SpawnEntityFromTable("info_target", { targetname = "ebf_inspect_ammo_manager" });
	}
	catch (e)
	{
		Warn("SpawnEntityFromTable threw: " + e);
		return false;
	}

	if (ent == null || !ent.IsValid())
	{
		Warn("Could not spawn the manager entity. The script will NOT run.");
		return false;
	}

	ent.ValidateScriptScope();

	// Resolve through the root table so the think survives scope changes.
	ent.GetScriptScope().Think <- function ()
	{
		return ::EBFInspectAmmo.ManagerThink();
	};

	AddThinkToEnt(ent, "Think");
	Manager = ent;

	Log("Manager entity active (index " + ent.GetEntityIndex() + ").");
	return true;
}

// Restores every spoofed magazine. Called before wiping per-player state so
// no weapon is left showing a fake ammo count.
EBFInspectAmmo.ReleaseAllKeys <- function ()
{
	local player = null;
	while (player = Entities.FindByClassname(player, "player"))
	{
		if (!player.IsValid())
			continue;

		local idx = player.GetEntityIndex();
		if (idx in State)
			ForceUnspoof(player, State[idx]);
	}
}

EBFInspectAmmo.Reload <- function ()
{
	ReleaseAllKeys();
	LoadSettings();
	State.clear();
	StartManager();
	Log("Reloaded. enable=" + Settings.enable
		+ " require_use=" + Settings.require_use
		+ " chat=" + Settings.output_chat
		+ " center=" + Settings.output_center
		+ " anim=" + Settings.play_animation
		+ " block_reload=" + Settings.block_reload
		+ " debug=" + Settings.debug);
}

//-----------------------------------------------------------------------------
// Diagnostics.
//-----------------------------------------------------------------------------
EBFInspectAmmo.Status <- function ()
{
	Log("================ status ================");
	Log("version         : " + VERSION);
	Log("loaded          : " + Loaded);
	Log("manager valid   : " + (Manager != null && Manager.IsValid()));
	Log("settings file   : left4dead2/ems/" + SETTINGS_PATH);
	Log("-- settings --");
	foreach (k, v in Settings)
		Log("  " + k + " = " + v);

	local host = null;
	try { host = GetListenServerHost(); } catch (e) { }

	Log("-- host --");
	if (host == null || !host.IsValid())
	{
		Log("  no listen server host (dedicated server, or not in a map yet)");
		Log("========================================");
		return;
	}

	Log("  name          : " + host.GetPlayerName());
	Log("  survivor      : " + host.IsSurvivor());

	// Clip-spoof state: this is what stops E+R from reloading.
	local hs = GetState(host.GetEntityIndex());
	if (hs.spoofActive)
		Log("  clip spoof    : ACTIVE (real " + hs.spoofRealClip
			+ ", showing " + hs.spoofFakeClip + ")");
	else
		Log("  clip spoof    : inactive (hold E to engage)");
	local tb = TriggerBit();
	local mb = ModifierBit();
	Log("  trigger key   : " + Settings.key + " (bit " + tb + ")"
		+ (Settings.require_use ? "  [require_use 1 -> legacy E+R]" : ""));
	Log("  modifier      : " + (mb ? Settings.modifier : "none"));
	local bm = host.GetButtonMask();
	Log("  buttons now   : " + bm
		+ ((bm & tb) ? "  [trigger DOWN]" : "  [trigger up]")
		+ (mb ? ((bm & mb) ? "  [modifier DOWN]" : "  [modifier up]") : ""));
	if (tb == IN_ALT1 && !Settings.require_use)
		Log("  bind hint     : bind v \"+alt1\"   (then tap V)");

	local wep = null;
	try { wep = host.GetActiveWeapon(); } catch (e) { }

	if (wep == null || !wep.IsValid())
	{
		Log("  weapon        : none");
		Log("========================================");
		return;
	}

	local info = ReadAmmo(host, wep);
	Log("  weapon        : " + info.classname);
	Log("  ammo          : " + FormatAmmo(info));

	local vm = null;
	try { vm = NetProps.GetPropEntity(host, "m_hViewModel"); } catch (e) { }

	if (vm == null || !vm.IsValid())
	{
		Log("  viewmodel     : INVALID  <-- animation cannot play");
		Log("========================================");
		return;
	}

	Log("  viewmodel     : " + vm.GetModelName());

	local pick = FindSequence(vm, InspectSeqNames);
	if (pick != null)
		Log("  inspect anim  : '" + pick.name + "' (id " + pick.id + ")");
	else
		Log("  inspect anim  : none");

	local rel = FindSequence(vm, ReloadSeqNames);
	if (rel != null)
		Log("  reload anim   : '" + rel.name + "' (id " + rel.id + ")");
	else
		Log("  reload anim   : none  <-- nothing to show on this model");

	Log("========================================");
}

// Fires a single inspect on the host with verbose output. Useful to prove the
// script works without having to get the key combination right.
EBFInspectAmmo.TestFire <- function ()
{
	local host = null;
	try { host = GetListenServerHost(); } catch (e) { }

	if (host == null || !host.IsValid())
	{
		Log("TestFire: no listen server host available.");
		return;
	}

	local state = GetState(host.GetEntityIndex());
	state.lastInspect = Time();

	Log("TestFire: running one inspect on " + host.GetPlayerName());
	if (!DoInspect(host, state, true))
		Log("TestFire: inspect did not run. See the lines above for the reason.");
}

//-----------------------------------------------------------------------------
// Boot.
//-----------------------------------------------------------------------------
EBFInspectAmmo.Init <- function ()
{
	LoadSettings();

	if (!Settings.enable)
	{
		Log("Disabled by settings (enable 0). Nothing will run.");
		Loaded = true;
		return;
	}

	if (StartManager())
	{
		Loaded = true;
		Log("Version " + VERSION + " ready. Hold E and tap R to inspect."
			+ (Settings.require_use ? "" : "  (require_use 0: R alone inspects)"));
	}
	else
	{
		Warn("Initialisation failed. Run 'script EBFInspectAmmo.Status()' for details.");
	}
}

EBFInspectAmmo.Init();

} // end of first-load guard
