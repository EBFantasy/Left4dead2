// Smooth Recoil - addon autoload entry.
// L4D2 runs this once when a map script VM starts.

printl("[SR] mapspawn_addon entry");

if (!("SmoothRecoil" in getroottable()) || !("_coreReady" in ::SmoothRecoil)) {
	IncludeScript("smooth_recoil/smooth_recoil_core");
}

if ("SmoothRecoil" in getroottable()) {
	::SmoothRecoil.OnMapSpawn("mapspawn_addon");
}

// --- Punch-angle prototype (v0.9.0) -----------------------------------------
// Proof that smooth recoil works without touching eye angles. See
// RECOIL_METHOD_FINDINGS.md.
//
// It is NOT loaded by default, because running it alongside the SnapEyeAngles
// core would apply recoil twice. To try it: set SR_USE_PUNCH to true below,
// and set SmoothRecoil.enabled = false (or unload the old core) first.
SR_USE_PUNCH <- false;

if (SR_USE_PUNCH) {
	if (!("SmoothRecoilPunch" in getroottable())
		|| !("_coreReady" in ::SmoothRecoilPunch)) {
		IncludeScript("smooth_recoil/smooth_recoil_punch");
	}
}
