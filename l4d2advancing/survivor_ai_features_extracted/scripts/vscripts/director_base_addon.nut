// === PROBE: 验证 director_base_addon 是否被 4 个同名 mod 抢占 ===
// 若控制台出现下面这行, 说明 ABA 的 director_base_addon 确实在跑(没被顶掉)。
printl("[DBA-PROBE-ABA] director_base_addon.nut executing");

// === Smooth Recoil hook (Ep1cBF + Claude) ===
// Place BEFORE AIUpdateHandler include so we don't crash on its internal bugs.
try {
    IncludeScript("smooth_recoil");
} catch (e) {
    printl("[ABA] Smooth Recoil not loaded (probably uninstalled): " + e);
}

// Include the Advanced Bot AI
if ("AdvancedBotAI" in getroottable()) {
    ::AdvancedBotAI = 1;
} else {
    ::AdvancedBotAI <- 0;
}

IncludeScript( "AIUpdateHandler" );

// ABA Spitter acid evasion mount. Loaded after AIUpdateHandler so it can
// cooperate with BotAI while only taking over acid/projectile avoidance.
try {
    IncludeScript("aba_spitter_response");
} catch (e) {
    printl("[ABA-Spitter][ERR] include failed: " + e);
}
