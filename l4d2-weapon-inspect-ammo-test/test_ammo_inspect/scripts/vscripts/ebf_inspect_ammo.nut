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

EBFInspectAmmo.VERSION <- "1.1.0";
EBFInspectAmmo.TAG <- "[InspectAmmo]";
EBFInspectAmmo.Loaded <- false;
EBFInspectAmmo.Manager <- null;
EBFInspectAmmo.State <- {};

//-----------------------------------------------------------------------------
// Button bits, per CTerrorPlayer::GetButtonMask() documentation.
//-----------------------------------------------------------------------------
EBFInspectAmmo.IN_USE <- 32;
EBFInspectAmmo.IN_RELOAD <- 8192;

// ClientPrint destinations.
EBFInspectAmmo.HUD_PRINTTALK <- 3;
EBFInspectAmmo.HUD_PRINTCENTER <- 4;

EBFInspectAmmo.SETTINGS_PATH <- "ebf_inspect_ammo/settings.txt";

//-----------------------------------------------------------------------------
// Settings, overridable from left4dead2/ems/ebf_inspect_ammo/settings.txt
//-----------------------------------------------------------------------------
EBFInspectAmmo.Settings <- {
	enable = 1            // Master switch.
	require_use = 1       // 1 = E must be held while tapping R.
	output_chat = 1       // Print the ammo line to the chat area.
	output_center = 1     // Print the ammo line at screen center.
	play_animation = 1    // Drive the weapon's reload/inspect animation.
	block_reload = 1      // Suppress the reload key while E is held.
	guard_ticks = 8       // Backup ammo-snapshot window, in frames.
	cancel_window = 3.0   // Seconds the fallback keeps cancelling a reload.
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
	guard_ticks = [1, 40]
	cancel_window = [0.5, 10.0]
	cooldown = [0.0, 10.0]
	melee_ok = [0, 1]
	debug = [0, 1]
}

// Keys that stay floats; everything else is coerced to int.
EBFInspectAmmo.FloatKeys <- { cooldown = 1, cancel_window = 1 };

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
		"// require_use     0 or 1. 1 = hold E while tapping R. Default 1.\n" +
		"//                 0 makes R alone inspect, which fights with normal\n" +
		"//                 reloading. Leave this at 1 unless you are testing.\n" +
		"// output_chat     0 or 1. Ammo line in the chat area. Default 1.\n" +
		"// output_center   0 or 1. Ammo line at screen center. Default 1.\n" +
		"// play_animation  0 or 1. Drive the weapon's reload/inspect animation.\n" +
		"//                 Custom weapon models that ship an inspect animation\n" +
		"//                 will show it. Stock models show their reload. Default 1.\n" +
		"// block_reload    0 or 1. Suppress the reload key while E is held, so\n" +
		"//                 E+R can never start a reload. Default 1.\n" +
		"//                 Requires require_use 1 (the modifier key is what\n" +
		"//                 tells the script when to suppress).\n" +
		"// guard_ticks     1 to 40. Backup only: frames an ammo snapshot is\n" +
		"//                 restored if a reload slips through. Default 8.\n" +
		"// cancel_window   0.5 to 10.0. Seconds the fallback keeps cancelling\n" +
		"//                 a reload, covering the whole reload animation.\n" +
		"//                 Default 3.0. Raise for very slow custom reloads.\n" +
		"// cooldown        0.0 to 10.0. Seconds between inspects. Default 1.20.\n" +
		"// melee_ok        0 or 1. Allow inspecting melee and clipless items.\n" +
		"//                 Default 1.\n" +
		"// debug           0 or 1. Verbose console diagnostics. Default 0.\n" +
		"// ============================================================\n" +
		"enable 1\n" +
		"require_use 1\n" +
		"output_chat 1\n" +
		"output_center 1\n" +
		"play_animation 1\n" +
		"block_reload 1\n" +
		"guard_ticks 8\n" +
		"cancel_window 3.0\n" +
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
EBFInspectAmmo.ReadAmmo <- function (player, weapon)
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
		info.clip = NetProps.GetPropInt(weapon, "m_iClip1");
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

	local info = ReadAmmo(player, weapon);

	if (!info.hasClip && !Settings.melee_ok)
	{
		Dbg("skipping clipless weapon " + info.classname);
		return false;
	}

	// Snapshot clip AND reserve so an accidental real reload can be undone
	// without the player gaining or losing a single round.
	if (Settings.block_reload && info.hasClip)
	{
		state.guardWeapon = weapon;
		state.guardClip = info.clip;
		state.guardReserve = info.reserve;
		state.guardAmmoType = info.ammoType;
		state.guardTicks = 2000;                       // hard safety cap
		state.guardUntil = Time() + Settings.cancel_window;
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
			reloadBlocked = false
			guardWeapon = null
			guardClip = -1
			guardReserve = -1
			guardAmmoType = -1
			guardTicks = 0
			guardUntil = 0.0
		};
	}
	return State[idx];
}

// Secondary safety net.
//
// The primary defence is SetReloadBlocked() below, which stops the reload from
// ever starting. This guard only catches the rare case where a reload slipped
// through anyway (for example require_use 0, or another script forcing one on
// the same frame). It restores clip and reserve for a few frames.
//
// It cannot be the primary mechanism: an L4D2 reload finishes over seconds of
// animation, far beyond any short frame window.
EBFInspectAmmo.RunGuard <- function (player, state)
{
	if (state.guardTicks <= 0)
		return;

	state.guardTicks--;

	local gw = state.guardWeapon;

	// The guard must outlive the reload animation itself (seconds), not just
	// a handful of frames, otherwise the magazine refills after we stop
	// watching. guardUntil is a wall-clock deadline; guardTicks only caps how
	// long we keep checking if the clock never advances.
	local expired = (state.guardTicks <= 0) || (Time() >= state.guardUntil);
	local last = expired;

	if (gw != null && gw.IsValid())
	{
		try
		{
			// Abort the reload in progress.
			if (NetProps.HasProp(gw, "m_bInReload")
				&& NetProps.GetPropInt(gw, "m_bInReload") != 0)
			{
				NetProps.SetPropInt(gw, "m_bInReload", 0);
				Dbg("aborted a real reload on " + gw.GetClassname());
			}

			// Shotguns reload shell by shell and track their own state.
			// Clearing m_bInReload alone would leave them mid-sequence.
			foreach (prop in ["m_reloadState", "m_reloadAnimState",
			                  "m_reloadNumShells", "m_shellsInserted"])
			{
				if (NetProps.HasProp(gw, prop)
					&& NetProps.GetPropInt(gw, prop) != 0)
				{
					NetProps.SetPropInt(gw, prop, 0);
				}
			}

			// Pin the magazine.
			if (state.guardClip >= 0
				&& NetProps.GetPropInt(gw, "m_iClip1") != state.guardClip)
			{
				NetProps.SetPropInt(gw, "m_iClip1", state.guardClip);
			}

			// Pin the reserve pool so nothing is consumed or duplicated.
			if (state.guardReserve >= 0 && state.guardAmmoType >= 0)
			{
				if (NetProps.GetPropIntArray(player, "m_iAmmo", state.guardAmmoType) != state.guardReserve)
					NetProps.SetPropIntArray(player, "m_iAmmo", state.guardReserve, state.guardAmmoType);
			}
		}
		catch (e)
		{
			Dbg("guard error: " + e);
		}
	}

	if (last)
	{
		// Final pass: make sure the weapon is not left stuck mid-reload, or
		// it would refuse to fire until the player reloads again.
		if (gw != null && gw.IsValid())
		{
			try
			{
				if (NetProps.HasProp(gw, "m_bInReload"))
					NetProps.SetPropInt(gw, "m_bInReload", 0);

				// Let the weapon fire again immediately.
				local now = Time();
				foreach (prop in ["m_flNextPrimaryAttack", "m_flTimeWeaponIdle"])
				{
					if (NetProps.HasProp(gw, prop))
						NetProps.SetPropFloat(gw, prop, now);
				}
				if (NetProps.HasProp(player, "m_flNextAttack"))
					NetProps.SetPropFloat(player, "m_flNextAttack", now);
			}
			catch (e) { Dbg("guard finalise error: " + e); }
		}

		state.guardWeapon = null;
		state.guardClip = -1;
		state.guardReserve = -1;
		state.guardAmmoType = -1;
		state.guardUntil = 0.0;
	}
}

//-----------------------------------------------------------------------------
// Reload-key suppression.
//
// This is the mechanism that actually stops E+R from reloading, and it works
// by PREVENTION rather than by cleanup.
//
// m_afButtonDisabled is a per-player bit mask the engine consults while
// building the usercmd. Any bit set there is stripped from the player's input
// before CTerrorGun::Reload() ever sees it. So while E is held we set the
// IN_RELOAD bit, and the reload simply never starts.
//
// This replaces the old snapshot-and-restore approach, which could not work:
// an L4D2 reload completes over ~2-3 seconds of animation, long after a short
// frame-based guard has expired. That is why a partially empty magazine still
// got refilled.
//
// Bits are only ever OR'd in and AND'd out again, so other scripts that use
// m_afButtonDisabled for their own bits are left untouched.
//-----------------------------------------------------------------------------
// Whether m_nButtons (unfiltered input) is readable. Detected once, on the
// first player we look at. Determines which suppression strategy is used.
EBFInspectAmmo.HaveRawButtons <- false;
EBFInspectAmmo.RawButtonsProbed <- false;

// Returns the player's UNFILTERED button mask.
//
// GetButtonMask() reflects m_afButtonDisabled, so once this script suppresses
// IN_RELOAD the press would become invisible to us. m_nButtons holds the input
// before that filtering, which is what edge detection must run on.
EBFInspectAmmo.ReadRawButtons <- function (player, fallback)
{
	try
	{
		if (NetProps.HasProp(player, "m_nButtons"))
		{
			if (!RawButtonsProbed)
			{
				RawButtonsProbed = true;
				HaveRawButtons = true;
				Dbg("m_nButtons available - using preemptive reload suppression");
			}
			return NetProps.GetPropInt(player, "m_nButtons");
		}
	}
	catch (e) { }

	if (!RawButtonsProbed)
	{
		RawButtonsProbed = true;
		HaveRawButtons = false;
		Log("m_nButtons unavailable - falling back to reload cancellation. "
			+ "E+R will still not consume ammo.");
	}

	return fallback;
}

EBFInspectAmmo.SetReloadBlocked <- function (player, state, blocked)
{
	if (state.reloadBlocked == blocked)
		return;

	try
	{
		if (!NetProps.HasProp(player, "m_afButtonDisabled"))
		{
			// Very unlikely, but never leave the player unable to reload.
			Dbg("m_afButtonDisabled missing - cannot suppress the reload key");
			state.reloadBlocked = false;
			return;
		}

		local mask = NetProps.GetPropInt(player, "m_afButtonDisabled");

		if (blocked)
			mask = mask | IN_RELOAD;
		else
			mask = mask & (~IN_RELOAD);

		NetProps.SetPropInt(player, "m_afButtonDisabled", mask);
		state.reloadBlocked = blocked;

		Dbg((blocked ? "blocked" : "released") + " reload key for " + player.GetPlayerName());
	}
	catch (e)
	{
		Dbg("SetReloadBlocked failed: " + e);
	}
}

// Safety net: make sure a player never keeps a disabled reload key when the
// script stops looking after them (death, disconnect, addon disabled...).
EBFInspectAmmo.ForceUnblock <- function (player, state)
{
	if (state.reloadBlocked)
		SetReloadBlocked(player, state, false);
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
				ForceUnblock(p, GetState(p.GetEntityIndex()));
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

		RunGuard(player, state);

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
			ForceUnblock(player, state);
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
		local rawButtons = ReadRawButtons(player, buttons);
		local useHeld = (rawButtons & IN_USE) ? true : false;

		// Preemptive suppression is only safe when we can read raw input;
		// otherwise blocking R would also hide the press we need to see.
		// Without raw input we leave the key alone and rely on RunGuard,
		// which cancels the reload for a full cancel_window instead.
		if (Settings.block_reload && Settings.require_use && HaveRawButtons)
			SetReloadBlocked(player, state, useHeld);

		// Edge detection runs on the raw state, otherwise suppressing the
		// key would also hide the press we are trying to detect.
		local pressed = rawButtons & (~state.lastButtons);
		state.lastButtons = rawButtons;

		// Rising edge on R only, so holding R does not spam.
		if (!(pressed & IN_RELOAD))
			continue;

		// E must be held, unless the user turned that requirement off.
		if (Settings.require_use && !(rawButtons & IN_USE))
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

// Releases every reload key this script has disabled. Called before wiping
// per-player state, so nobody is left unable to reload.
EBFInspectAmmo.ReleaseAllKeys <- function ()
{
	local player = null;
	while (player = Entities.FindByClassname(player, "player"))
	{
		if (!player.IsValid())
			continue;

		local idx = player.GetEntityIndex();
		if (idx in State)
			ForceUnblock(player, State[idx]);
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

	// Reload-key suppression state, the thing to check when E+R still reloads.
	local hs = GetState(host.GetEntityIndex());
	Log("  reload key    : " + (hs.reloadBlocked ? "BLOCKED (E is held)" : "free"));
	try
	{
		if (NetProps.HasProp(host, "m_afButtonDisabled"))
		{
			local mask = NetProps.GetPropInt(host, "m_afButtonDisabled");
			Log("  m_afButtonDisabled = " + mask
				+ ((mask & IN_RELOAD) ? "  (IN_RELOAD bit set)" : "  (IN_RELOAD bit clear)"));
		}
		else
		{
			Log("  m_afButtonDisabled : MISSING  <-- cannot suppress the reload key");
		}
	}
	catch (e) { Log("  m_afButtonDisabled : read failed (" + e + ")"); }

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
