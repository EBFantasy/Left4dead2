// Smooth Recoil - addon autoload entry.
// L4D2 runs this once when a map script VM starts.

printl("[SR] mapspawn_addon entry");

if (!("SmoothRecoil" in getroottable()) || !("_coreReady" in ::SmoothRecoil)) {
	IncludeScript("smooth_recoil/smooth_recoil_core");
}

if ("SmoothRecoil" in getroottable()) {
	::SmoothRecoil.OnMapSpawn("mapspawn_addon");
}
