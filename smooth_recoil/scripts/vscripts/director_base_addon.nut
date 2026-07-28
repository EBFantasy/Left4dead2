// Smooth Recoil - fallback addon entry.
// Some script mods rely on this file name, so keep it as a tiny bridge.

printl("[SR] director_base_addon entry");

if (!("SmoothRecoil" in getroottable()) || !("_coreReady" in ::SmoothRecoil)) {
	IncludeScript("smooth_recoil/smooth_recoil_core");
}

if ("SmoothRecoil" in getroottable()) {
	::SmoothRecoil.OnMapSpawn("director_base_addon");
}
