// Smooth Recoil - addon autoload entry.
// L4D2 runs this once when a map script VM starts.

printl("[SR] mapspawn_addon entry");

//=============================================================================
//  WHICH RECOIL ENGINE TO USE  --  change this one line, nothing else
//=============================================================================
//
//   "punch"  (default) v0.9.0 prototype.
//            Writes only the engine's own punch angle. It never touches your
//            eye angles, so it cannot fight the mouse, and recovery uses the
//            engine's damped spring (~0.77s instead of ~5.4s).
//
//   "legacy" v0.8.2 original core (SnapEyeAngles).
//            Kept only for comparison. This is the build that fights the
//            mouse and recovers slowly.
//
//   "both"   Do not use. Recoil would be applied twice.
//
// The value is read by director_base_addon.nut too, so setting it here is
// enough - there is no second switch to remember.
//
if (!("SR_MODE" in getroottable()))
	::SR_MODE <- "punch";

//=============================================================================

::SR_LoadRecoil <- function (source) {

	if (::SR_MODE == "punch" || ::SR_MODE == "both") {
		if (!("SmoothRecoilPunch" in getroottable())
			|| !("_coreReady" in ::SmoothRecoilPunch)) {
			IncludeScript("smooth_recoil/smooth_recoil_punch");
		}
	}

	if (::SR_MODE == "legacy" || ::SR_MODE == "both") {
		if (!("SmoothRecoil" in getroottable())
			|| !("_coreReady" in ::SmoothRecoil)) {
			IncludeScript("smooth_recoil/smooth_recoil_core");
		}
		if ("SmoothRecoil" in getroottable()) {
			::SmoothRecoil.OnMapSpawn(source);
		}
	}
}

::SR_LoadRecoil("mapspawn_addon");

printl("[SR] mode = " + ::SR_MODE);
