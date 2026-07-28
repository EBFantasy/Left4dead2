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

EBFInspectAmmo.VERSION <- "1.7.0";
EBFInspectAmmo.TAG <- "[InspectAmmo]";
EBFInspectAmmo.Loaded <- false;
EBFInspectAmmo.Manager <- null;
EBFInspectAmmo.State <- {};

//-----------------------------------------------------------------------------
// Button bits, per CTerrorPlayer::GetButtonMask() documentation.
//-----------------------------------------------------------------------------
EBFInspectAmmo.IN_ATTACK <- 1;
EBFInspectAmmo.IN_ATTACK2 <- 2048;
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
// Verified against Source SDK game/shared/in_buttons.h:
//   IN_SCORE = 1<<16 = 65536   (scoreboard)
//   IN_SPEED = 1<<17 = 131072  (the "speed key" - in L4D2 this is Shift,
//                               which makes you WALK slowly, not sprint;
//                               L4D2 has no vanilla sprint)
//   IN_WALK  = 1<<18 = 262144  (unused by L4D2)
//   IN_ZOOM  = 1<<19 = 524288
// v1.5.0 had IN_SPEED set to 65536, i.e. the scoreboard bit, so any combo
// using "speed" could never fire.
EBFInspectAmmo.IN_SCORE <- 65536;
EBFInspectAmmo.IN_SPEED <- 131072;
EBFInspectAmmo.IN_WALK  <- 262144;
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
	// Trigger mode: how the inspect is requested.
	//   combo   - hold a chord of movement keys (default, no binds needed)
	//   key     - a single trigger key (see "key" below)
	//   chat    - type the chat command only
	// Chat always works as a fallback regardless of this setting.
	trigger = "combo"

	// Chord used when trigger = combo. Any two or more of:
	//   speed (Shift = walk slowly) | use (E) | duck (Ctrl) | zoom
	//   reload (R) | jump (Space) | attack2 (RMB)
	// Default speed+use = hold Shift (L4D2's walk key) then press E.
	// Comfortable on the left hand, no odd visual (you simply slow down for a
	// moment), and neither key is a bindable target that script mods fight
	// over the way +alt1 is.
	combo = "speed+use"

	// Seconds the chord must be held before it fires. Prevents accidental
	// triggers while crouch-walking normally.
	hold_time = 0.30

	// Chat command that also triggers an inspect. Type it in chat.
	chat_command = "!ammo"

	key = "alt1"          // Trigger key when trigger = key.
	modifier = "none"     // Extra key to hold: none | use | duck | speed.
	require_use = 0       // Legacy: 1 forces the old E+R behaviour.
	output_chat = 1       // Print the ammo line to the chat area.
	output_center = 1     // Print the ammo line at screen center.
	play_animation = 1    // Drive the weapon's reload/inspect animation.
	anim_source = "auto"  // auto | deploy | idle | reload. Which animation to
	                      // auto | pickup | deploy | idle | reload.
	block_reload = 1      // Report a full magazine while E is held.
	spoof_time = 2.50     // Max seconds an inspect suppresses reloads for.
	cancel_grace = 0.35   // Grace before R cancels, only if R is a trigger key.
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
	cancel_grace = [0.0, 2.0]
	hold_time = [0.0, 3.0]
	cooldown = [0.0, 10.0]
	melee_ok = [0, 1]
	debug = [0, 1]
}

// Settings whose value is a word, not a number.
EBFInspectAmmo.StringKeys <- {
	trigger = ["combo", "key", "chat"]
	anim_source = ["auto", "pickup", "inspect", "deploy", "idle", "reload"]
	key = ["alt1", "alt2", "zoom", "reload"]
	modifier = ["none", "use", "duck", "speed"]
};

// Free-form string settings (validated separately, not against a list).
EBFInspectAmmo.FreeStringKeys <- { combo = 1, chat_command = 1 };

// Keys that stay floats; everything else is coerced to int.
EBFInspectAmmo.FloatKeys <- { cooldown = 1, spoof_time = 1, hold_time = 1, cancel_grace = 1 };

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
		"// trigger         How to inspect: combo | key | chat. Default combo.\n" +
		"//                 combo - hold a chord of keys you already own.\n" +
		"//                         Needs NO bind and takes no bindable key\n" +
		"//                         away from your other script mods.\n" +
		"//                 key   - a single trigger key (see 'key' below).\n" +
		"//                 chat  - chat command only.\n" +
		"//                 The chat command below ALWAYS works as well.\n" +
		"// combo           Chord for trigger=combo. Default speed+use,\n" +
		"//                 i.e. hold Shift and press E.\n" +
		"//                 Valid names, join with +:\n" +
		"//                   duck (Ctrl)   speed (Shift, walks slowly)\n" +
		"//                   use (E)       zoom          jump (Space)\n" +
		"//                   reload (R)   jump (Space)   attack2 (RMB)\n" +
		"//                   alt1  alt2\n" +
		"//                 Examples:  speed+use   duck+zoom   speed+attack2\n" +
		"// hold_time       0.0 to 3.0. Seconds the chord must be held before\n" +
		"//                 it fires. Default 0.30, so simply using E on a door\n" +
		"//                 while running never triggers it. Lower for snappier.\n" +
		"// chat_command    Chat text that inspects. Default !ammo.\n" +
		"//                 Always active, cannot conflict with any bind.\n" +
		"//\n" +
		"// key             Used when trigger = key: alt1 | alt2 | zoom | reload.\n" +
		"//                 Default alt1. alt1/alt2 are UNBOUND in vanilla L4D2,\n" +
		"//                 so they clash with nothing. Bind one in the console:\n" +
		"//                     bind v \"+alt1\"\n" +
		"//                 Then just tap V to inspect. Put the bind line in\n" +
		"//                 left4dead2/cfg/autoexec.cfg to make it permanent.\n" +
		"// modifier        Extra key to hold: none | use | duck | speed.\n" +
		"//                 Default none. Only needed if your chosen key is\n" +
		"//                 already used for something else.\n" +
		"//                 use = E, duck = Ctrl, speed = Shift (walk).\n" +
		"// require_use     Legacy switch. 1 restores the old E+R binding and\n" +
		"//                 overrides key/modifier. Default 0. Not recommended:\n" +
		"//                 R has to serve two purposes, so quick taps can still\n" +
		"//                 slip a real reload through.\n" +
		"// output_chat     0 or 1. Ammo line in the chat area. Default 1.\n" +
		"// output_center   0 or 1. Ammo line at screen center. Default 1.\n" +
		"// anim_source     auto | pickup | deploy | idle | reload.\n" +
		"//                 Default auto. Which animation the inspect plays.\n" +
		"//                 auto   - a real inspect/fidget anim if the model\n" +
		"//                          has one, otherwise the ITEM PICKUP anim.\n" +
		"//                 pickup - force the item-pickup animation. This is\n" +
		"//                          the one you see when staring at a\n" +
		"//                          pickupable item, and is where most weapon\n" +
		"//                          mods put their inspect animation.\n" +
		"//                 deploy - the draw/pull-out animation (different!).\n" +
		"//                 idle   - plain idle.\n" +
		"//                 reload - force the reload animation.\n" +
		"// play_animation  0 or 1. Drive the weapon's reload/inspect animation.\n" +
		"//                 Custom weapon models that ship an inspect animation\n" +
		"//                 will show it. Stock models show their reload. Default 1.\n" +
		"// block_reload    0 or 1. While E is held, report the magazine as full\n" +
		"//                 so the engine refuses to reload. Default 1.\n" +
		"//                 The true ammo count is restored when E is released,\n" +
		"//                 and is what the readout always shows.\n" +
		"//                 Requires require_use 1.\n" +

		"// cancel_grace    0.0 to 2.0. Default 0.35. Only applies when R is\n" +
		"//                 itself part of the trigger, stopping the chord from\n" +
		"//                 cancelling the inspect it just started.\n" +
		"//                 Fire and shove always cancel instantly, and so does\n" +
		"//                 R when it is not a trigger key. Cancelling reloads\n" +
		"//                 normally straight away - no double press needed.\n" +
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
		"trigger combo\n" +
		"combo speed+use\n" +
		"hold_time 0.30\n" +
		"chat_command !ammo\n" +
		"key alt1\n" +
		"modifier none\n" +
		"require_use 0\n" +
		"output_chat 1\n" +
		"output_center 1\n" +
		"play_animation 1\n" +
		"anim_source auto\n" +
		"block_reload 1\n" +

		"spoof_time 2.50\n" +
		"cancel_grace 0.35\n" +
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

		// Free-form strings (chord spec, chat command) are taken as-is.
		if (key in FreeStringKeys)
		{
			Settings[key] = valStr;
			applied++;
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
// Sequence names to try, in priority order.
//
// Most L4D2 "inspect" weapon mods do NOT ship a sequence literally called
// "inspect". They hang the animation off one of:
//   * a dedicated inspect sequence, if the author added one
//   * the DEPLOY / draw animation (very common: the gun is raised and looked
//     over, which is exactly the inspect motion)
//   * an extended IDLE variant that plays on a full magazine
//
// Trying only "inspect" and then falling straight through to the reload
// sequence is what made stock reload animations play instead of the mod's
// inspect animation, which was the reported symptom.
// Sequence names to try, in priority order.
//
// CORRECTED IN v1.6.0 after user feedback, verified against Valve's official
// viewmodel QC prefabs (Mrfunreal/-L4D2_Weapon_Viewmodel_QC_Prefabs).
//
// The "full magazine inspect" that weapon mods ship is almost always attached
// to the ITEM PICKUP animation set - the idle you see when you stand looking
// at a pickupable item and the character holds the gun up and studies it.
// The stock QC defines these as:
//
//   ACT_VM_ITEMPICKUP_EXTEND / _LOOP / _RETRACT     (hidden base sequences)
//   ACT_VM_ITEMPICKUP_EXTEND_LAYER / _LOOP_LAYER    (what actually plays)
//   ACT_VM_ITEMPICKUP_RETRACT_LAYER
//
// This is NOT the deploy/draw animation. v1.5.0 wrongly preferred deploy,
// which is the "pull the weapon out" motion - a different animation entirely.
// That mistake is why mods with a real inspect animation still looked wrong.
//
// IMPORTANT: we drive m_nLayerSequence, which plays a LAYER. The stock model
// marks the non-layer variants "Hidden", so the *_LAYER names must be tried
// first or the animation will not show.
EBFInspectAmmo.PickupSeqNames <- [
	"ACT_VM_ITEMPICKUP_LOOP_LAYER", "item_loop_layer",
	"ACT_VM_ITEMPICKUP_EXTEND_LAYER", "item_extend_layer",
	"ACT_VM_ITEMPICKUP_LOOP", "item_loop",
	"ACT_VM_ITEMPICKUP_EXTEND", "item_extend",
	// Helping-hand set: some mods hang the inspect off this instead.
	"ACT_VM_HELPINGHAND_LOOP_LAYER", "helping_hand_loop_layer",
	"ACT_VM_HELPINGHAND_LOOP", "helping_hand_loop"
];

// A genuinely dedicated inspect/fidget sequence, when the author added one.
// ACT_VM_FIDGET is L4D2's real "inspect" activity.
EBFInspectAmmo.InspectSeqNames <- [
	"ACT_VM_FIDGET_LAYER", "fidget_layer",
	"ACT_VM_FIDGET", "fidget",
	"inspect_layer", "inspect", "ACT_VM_INSPECT",
	"idle_inspect", "inspect_start", "lookat"
];

// Deploy/draw: the "pull the weapon out" motion. Kept only as an opt-in.
EBFInspectAmmo.DeploySeqNames <- [
	"ACT_VM_DEPLOY_LAYER", "deploy_layer",
	"ACT_VM_DEPLOY", "deploy", "ACT_VM_DRAW", "draw"
];

EBFInspectAmmo.IdleSeqNames <- [
	"ACT_VM_IDLE", "idle"
];

EBFInspectAmmo.ReloadSeqNames <- [
	"ACT_VM_RELOAD_LAYER", "reload_layer",
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

	// Priority: real inspect > deploy (where most mods put it) > configured
	// preference > reload as the last resort.
	// Priority (anim_source = auto):
	//   1. a dedicated inspect/fidget sequence, if the model has one
	//   2. the ITEM PICKUP set - where mods actually put the inspect
	//   3. reload, only as a last resort
	// Deploy and idle are opt-in, because they are different motions.
	local pick = null;

	switch (Settings.anim_source)
	{
		case "pickup":
			pick = FindSequence(vm, PickupSeqNames);
			break;

		case "deploy":
			pick = FindSequence(vm, DeploySeqNames);
			break;

		case "idle":
			pick = FindSequence(vm, IdleSeqNames);
			break;

		case "reload":
			pick = FindSequence(vm, ReloadSeqNames);
			break;

		default: // "auto"
			pick = FindSequence(vm, InspectSeqNames);
			if (pick == null)
				pick = FindSequence(vm, PickupSeqNames);
			break;
	}

	// Last resort so something always plays.
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

	// Ammo is never modified any more, so m_iClip1 is always the truth.
	local info = ReadAmmo(player, weapon);

	if (!info.hasClip && !Settings.melee_ok)
	{
		Dbg("skipping clipless weapon " + info.classname);
		return false;
	}

	// Open the "inspect window". For its duration any reload the engine tries
	// to start is cancelled on the spot. No ammo value is ever written.
	if (Settings.block_reload && info.hasClip)
	{
		state.spoofActive = true;
		state.spoofWeapon = weapon;
		state.spoofUntil = Time() + Settings.spoof_time;
		state.inspectStart = Time();
		CancelReload(player, weapon, 0.20);
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
			spoofUntil = 0.0
			spoofWeapon = null
			inspectStart = 0.0
			comboStart = 0.0
			comboFired = false
		};
	}
	return State[idx];
}


// Resolves the configured trigger key to its button bit.
// Named button bits usable in a chord spec.
EBFInspectAmmo.ChordBits <- {
	duck = 4
	use = 32
	reload = 8192
	jump = 2
	speed = 131072
	zoom = 524288
	alt1 = 16384
	alt2 = 32768
	attack2 = 2048
};

// Parses "duck+speed" into a combined bit mask. Cached, since it is read
// every frame. Returns 0 if the spec is empty or unrecognised.
EBFInspectAmmo.ComboMaskCache <- -1;
EBFInspectAmmo.ComboMaskSrc <- "";

EBFInspectAmmo.ComboMask <- function ()
{
	if (ComboMaskSrc == Settings.combo && ComboMaskCache >= 0)
		return ComboMaskCache;

	local mask = 0;
	local bad = "";

	foreach (part in split(Settings.combo, "+ ,"))
	{
		local nm = strip(part).tolower();
		if (nm.len() == 0)
			continue;

		if (nm in ChordBits)
			mask = mask | ChordBits[nm];
		else
			bad += (bad.len() ? ", " : "") + nm;
	}

	if (bad.len())
		Warn("Unknown key(s) in combo '" + Settings.combo + "': " + bad);

	ComboMaskSrc = Settings.combo;
	ComboMaskCache = mask;
	return mask;
}

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

// Reload prevention -- WITHOUT touching ammo.
//
// HISTORY (v1.2-v1.4): the previous approach temporarily wrote
// m_iClip1 = GetMaxClip1() so CTerrorGun::Reload() would bail out on a "full"
// magazine. That was fundamentally unsafe: while the spoof was pinned, any
// shot the player fired was immediately written back to the fake full value,
// producing INFINITE AMMO, and any mismatch on restore left the magazine
// genuinely full. Writing to m_iClip1 at all is too dangerous.
//
// v1.5.0 never writes m_iClip1, m_iAmmo, or any ammo field. Instead it lets
// the engine start the reload, then cancels it on the same frame and holds the
// weapon in a non-reloading state for the duration of the animation:
//
//   m_bInReload         -> 0    cancels the reload in progress
//   m_reloadState etc.  -> 0    shotguns track shell-by-shell reloads
//   m_flNextPrimaryAttack       pushed forward so the weapon stays busy
//   m_flTimeWeaponIdle          pushed forward so it will not re-idle early
//
// Ammo therefore cannot change: no reload ever completes, and nothing writes
// to the clip. The worst possible failure is a reload that visibly starts and
// is cut short, never lost or duplicated ammo.
EBFInspectAmmo.CancelReload <- function (player, weapon, extend)
{
	if (weapon == null || !weapon.IsValid())
		return;

	try
	{
		if (NetProps.HasProp(weapon, "m_bInReload")
			&& NetProps.GetPropInt(weapon, "m_bInReload") != 0)
		{
			NetProps.SetPropInt(weapon, "m_bInReload", 0);
			Dbg("cancelled a reload on " + weapon.GetClassname());
		}

		// Shotguns reload one shell at a time and keep their own state.
		foreach (prop in ["m_reloadState", "m_reloadAnimState",
		                  "m_reloadNumShells", "m_shellsInserted"])
		{
			if (NetProps.HasProp(weapon, prop)
				&& NetProps.GetPropInt(weapon, prop) != 0)
			{
				NetProps.SetPropInt(weapon, prop, 0);
			}
		}

		// Hold off the weapon's own idle logic so it does not restart a reload
		// by itself while the inspect animation plays.
		//
		// IMPORTANT: only m_flTimeWeaponIdle is touched, and only by a short
		// rolling amount. v1.6.0 pushed m_flNextPrimaryAttack forward by the
		// whole spoof_time (2.5s) in one go, which left the weapon "busy" long
		// after the player had asked to reload: the reload animation played but
		// was rejected, so a second press was needed. Never block firing, and
		// never lock the weapon for longer than the current frame needs.
		if (extend > 0.0)
		{
			local until = Time() + extend;
			if (NetProps.HasProp(weapon, "m_flTimeWeaponIdle")
				&& NetProps.GetPropFloat(weapon, "m_flTimeWeaponIdle") < until)
			{
				NetProps.SetPropFloat(weapon, "m_flTimeWeaponIdle", until);
			}
		}
	}
	catch (e) { Dbg("CancelReload error: " + e); }
}

// Runs every frame while an inspect is in progress, suppressing any reload the
// engine tries to begin until the animation window expires.
// Closes the inspect window and returns the weapon to a fully usable state.
//
// Clearing the idle timer matters: if it is left in the future the weapon
// stays "busy" and the next reload press is silently dropped, which is exactly
// the double-press problem reported against v1.6.0.
EBFInspectAmmo.EndInspect <- function (player, state, weapon, why)
{
	state.spoofActive = false;
	state.spoofUntil = 0.0;
	state.spoofWeapon = null;
	state.inspectStart = 0.0;

	if (weapon != null && weapon.IsValid())
	{
		try
		{
			local now = Time();

			// Let the weapon idle (and therefore reload) again right now.
			if (NetProps.HasProp(weapon, "m_flTimeWeaponIdle")
				&& NetProps.GetPropFloat(weapon, "m_flTimeWeaponIdle") > now)
			{
				NetProps.SetPropFloat(weapon, "m_flTimeWeaponIdle", now);
			}

			// Never leave firing blocked by us.
			if (NetProps.HasProp(weapon, "m_flNextPrimaryAttack")
				&& NetProps.GetPropFloat(weapon, "m_flNextPrimaryAttack") > now)
			{
				NetProps.SetPropFloat(weapon, "m_flNextPrimaryAttack", now);
			}
		}
		catch (e) { Dbg("EndInspect error: " + e); }
	}

	Dbg("inspect ended (" + why + ") for " + player.GetPlayerName());
}

EBFInspectAmmo.UpdateSpoof <- function (player, state)
{
	if (!state.spoofActive)
		return;

	if (Time() >= state.spoofUntil)
	{
		EndInspect(player, state, state.spoofWeapon, "window expired");
		return;
	}

	local w = state.spoofWeapon;

	// Weapon swapped mid-inspect: stop guarding the old one.
	local cur = null;
	try { cur = player.GetActiveWeapon(); } catch (e) { }
	if (cur != w)
	{
		EndInspect(player, state, w, "weapon switched");
		return;
	}

	// --- Player-initiated cancel ------------------------------------------
	// Any deliberate action ends the inspect immediately and hands the weapon
	// straight back. Without this the window ran for its full spoof_time and
	// swallowed the player's first reload press: the animation played but the
	// reload was rejected, so a second press was needed.
	//
	// A short grace period stops the trigger chord itself (Shift is still
	// held, E may still be down) from cancelling the inspect on frame one.
	local buttons = 0;
	try { buttons = player.GetButtonMask(); } catch (e) { }

	// Fire and shove are never part of a trigger chord, so they may cancel
	// immediately - no grace period needed.
	if (buttons & (IN_ATTACK | IN_ATTACK2))
	{
		EndInspect(player, state, w, "player cancelled (fire/shove)");
		return;
	}

	// Reload only needs a grace period when R is itself part of the trigger,
	// otherwise the chord that started the inspect would cancel it instantly.
	local reloadIsTrigger = false;
	if (Settings.trigger == "combo")
		reloadIsTrigger = (ComboMask() & IN_RELOAD) != 0;
	else if (Settings.trigger == "key")
		reloadIsTrigger = (TriggerBit() == IN_RELOAD);

	if (buttons & IN_RELOAD)
	{
		if (!reloadIsTrigger
			|| (Time() - state.inspectStart) >= Settings.cancel_grace)
		{
			EndInspect(player, state, w, "player cancelled (reload)");
			return;
		}
	}

	CancelReload(player, w, 0.0);
}

// Kept for the cleanup call sites (death, disconnect, disable, reload).
// There is nothing to restore any more, because nothing was modified.
EBFInspectAmmo.ForceUnspoof <- function (player, state)
{
	state.spoofActive = false;
	state.spoofUntil = 0.0;
	state.spoofWeapon = null;
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
			spoofUntil = 0.0
			spoofWeapon = null
			inspectStart = 0.0
			comboStart = 0.0
			comboFired = false
		};
	}
	return State[idx];
}


// Resolves the configured trigger key to its button bit.
// Named button bits usable in a chord spec.
EBFInspectAmmo.ChordBits <- {
	duck = 4
	use = 32
	reload = 8192
	jump = 2
	speed = 131072
	zoom = 524288
	alt1 = 16384
	alt2 = 32768
	attack2 = 2048
};

// Parses "duck+speed" into a combined bit mask. Cached, since it is read
// every frame. Returns 0 if the spec is empty or unrecognised.
EBFInspectAmmo.ComboMaskCache <- -1;
EBFInspectAmmo.ComboMaskSrc <- "";

EBFInspectAmmo.ComboMask <- function ()
{
	if (ComboMaskSrc == Settings.combo && ComboMaskCache >= 0)
		return ComboMaskCache;

	local mask = 0;
	local bad = "";

	foreach (part in split(Settings.combo, "+ ,"))
	{
		local nm = strip(part).tolower();
		if (nm.len() == 0)
			continue;

		if (nm in ChordBits)
			mask = mask | ChordBits[nm];
		else
			bad += (bad.len() ? ", " : "") + nm;
	}

	if (bad.len())
		Warn("Unknown key(s) in combo '" + Settings.combo + "': " + bad);

	ComboMaskSrc = Settings.combo;
	ComboMaskCache = mask;
	return mask;
}

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
		local pressed = buttons & (~state.lastButtons);
		state.lastButtons = buttons;

		// The magazine is spoofed full only while the inspect animation is
		// actually playing. It is armed on the trigger below and released by
		// UpdateSpoof() once spoof_time elapses, so there is no dependency on
		// how long any key stays held. This is what makes a quick tap behave
		// exactly like a long press.
		UpdateSpoof(player, state);

		local fire = false;

		if (Settings.trigger == "combo")
		{
			// Chord mode: every key in the chord must be held together for
			// hold_time before it fires, and it fires only once per hold.
			local mask = ComboMask();

			if (mask != 0 && (buttons & mask) == mask)
			{
				if (state.comboStart == 0.0)
					state.comboStart = now;

				if (!state.comboFired && (now - state.comboStart) >= Settings.hold_time)
				{
					state.comboFired = true;
					fire = true;
				}
			}
			else
			{
				state.comboStart = 0.0;
				state.comboFired = false;
			}
		}
		else if (Settings.trigger == "key")
		{
			local trigBit = TriggerBit();
			local modBit  = ModifierBit();
			local modHeld = (modBit == 0) || ((buttons & modBit) != 0);

			if ((pressed & trigBit) && modHeld)
				fire = true;
		}
		// trigger == "chat" fires from OnGameEvent_player_say instead.

		if (!fire)
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
// Chat command.
//
// Always available, whatever "trigger" is set to, because it cannot collide
// with anything: it is typed, not bound. This is the guaranteed-working escape
// hatch when every usable button bit is already taken by other script mods.
//-----------------------------------------------------------------------------
EBFInspectAmmo.HandleSay <- function (player, text)
{
	if (player == null || !player.IsValid())
		return;

	local msg = strip(text).tolower();
	local cmd = strip(Settings.chat_command).tolower();

	if (cmd.len() == 0 || msg != cmd)
		return;

	local state = GetState(player.GetEntityIndex());

	// Chat deliberately ignores the cooldown: the player had to type it.
	state.lastInspect = Time();
	DoInspect(player, state, false);
}

// L4D2 fires player_say for every chat line.
::OnGameEvent_player_say <- function (params)
{
	if (!("EBFInspectAmmo" in getroottable()))
		return;

	if (!EBFInspectAmmo.Settings.enable)
		return;

	try
	{
		if (!("text" in params) || !("userid" in params))
			return;

		local player = GetPlayerFromUserID(params.userid);
		EBFInspectAmmo.HandleSay(player, params.text);
	}
	catch (e)
	{
		EBFInspectAmmo.Dbg("player_say handler error: " + e);
	}
}

// Register the event callback without requiring Scripted Mode.
if ("__CollectGameEventCallbacks" in getroottable())
	__CollectGameEventCallbacks(getroottable());

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
		Log("  inspect window: OPEN (" + (hs.spoofUntil - Time())
			+ "s left, reloads suppressed)");
	else
		Log("  inspect window: closed");
	Log("  ammo writes   : none - this build never modifies m_iClip1/m_iAmmo");
	local bm = host.GetButtonMask();
	Log("  trigger mode  : " + Settings.trigger);

	if (Settings.trigger == "combo")
	{
		local cm = ComboMask();
		Log("  combo         : " + Settings.combo + " (mask " + cm + ")"
			+ ", hold " + Settings.hold_time + "s");
		Log("  combo now     : " + ((cm != 0 && (bm & cm) == cm)
			? "ALL KEYS DOWN" : "not held"));
		if (cm == 0)
			Log("  WARNING       : combo parsed to 0 - check the key names!");
	}
	else if (Settings.trigger == "key")
	{
		local tb = TriggerBit();
		local mb = ModifierBit();
		Log("  key           : " + Settings.key + " (bit " + tb + ")"
			+ ((bm & tb) ? "  [DOWN]" : "  [up]"));
		Log("  modifier      : " + (mb ? Settings.modifier : "none"));
	}

	Log("  chat command  : " + Settings.chat_command + "  (always active)");
	Log("  buttons now   : " + bm);

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

	local ins = FindSequence(vm, InspectSeqNames);
	local dep = FindSequence(vm, DeploySeqNames);
	local idl = FindSequence(vm, IdleSeqNames);
	local rel = FindSequence(vm, ReloadSeqNames);

	Log("  anim_source   : " + Settings.anim_source);
	Log("  inspect anim  : " + (ins ? "'" + ins.name + "' (id " + ins.id + ")" : "none"));
	Log("  deploy anim   : " + (dep ? "'" + dep.name + "' (id " + dep.id + ")" : "none"));
	Log("  idle anim     : " + (idl ? "'" + idl.name + "' (id " + idl.id + ")" : "none"));
	Log("  reload anim   : " + (rel ? "'" + rel.name + "' (id " + rel.id + ")" : "none"));

	// Dump every sequence the model actually has, so an unusual name used by
	// a custom weapon can simply be read off and set in anim_source.
	Log("  -- all sequences on this viewmodel --");
	local shown = 0;
	for (local i = 0; i < 128; i++)
	{
		local nm = null;
		try { nm = vm.GetSequenceName(i); } catch (e) { break; }
		if (nm == null || nm == "" || nm == "Unknown")
			continue;
		Log("     [" + i + "] " + nm);
		shown++;
		if (shown >= 64)
		{
			Log("     ... (truncated)");
			break;
		}
	}
	if (shown == 0)
		Log("     (none readable)");

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
