// Smooth Recoil - fallback addon entry.
// Some script mods rely on this file name, so keep it as a tiny bridge.
//
// The engine choice lives in mapspawn_addon.nut (::SR_MODE). Do not set it
// here as well - this file only needs to cope with being the entry point that
// happens to run first.

printl("[SR] director_base_addon entry");

if (!("SR_MODE" in getroottable()))
	::SR_MODE <- "punch";

if ("SR_LoadRecoil" in getroottable()) {
	::SR_LoadRecoil("director_base_addon");
} else {
	// mapspawn_addon has not run yet; load it so the shared loader exists.
	IncludeScript("mapspawn_addon");
}
