//-----------------------------------------------------------------------------
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 EpicBF
//
// Weapon Inspect Ammo Check -- loader
//
// mapspawn_addon.nut is the sanctioned auto-run entry point for VScript
// addons. It runs once per chapter in the root table scope, and it loads
// ALONGSIDE the stock mapspawn.nut rather than replacing it, so this addon
// does not conflict with map fixes, the Community Update, or other mods.
//
// Keep this file tiny. All real work lives in ebf_inspect_ammo.nut.
//-----------------------------------------------------------------------------

try
{
	// getroottable() keeps ::EBFInspectAmmo reachable from the console and
	// from the manager entity's think function.
	IncludeScript("ebf_inspect_ammo", getroottable());
}
catch (e)
{
	error("[InspectAmmo] FAILED to include ebf_inspect_ammo.nut: " + e + "\n");
	error("[InspectAmmo] Check that scripts/vscripts/ebf_inspect_ammo.nut exists inside the VPK.\n");
}
