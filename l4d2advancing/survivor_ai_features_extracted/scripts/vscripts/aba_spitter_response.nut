// =============================================================================
// aba_spitter_response.nut - ABA mount of Ep1cBF's verified acid evasion module.
//
// This is intentionally self-contained: it does not require BotCore or the
// l4d2aiproject federation. It only takes ownership of Spitter acid / spit
// projectile avoidance, leaving ABA combat, shove, rescue, pickup, and fire
// logic alone.
// =============================================================================

if ("ABA_Spitter_Response_Loaded" in getroottable())
{
    if ("BotModule_ABA_Spitter_Init" in getroottable())
        ::BotModule_ABA_Spitter_Init();
    return;
}
if (("BotCore" in getroottable()) && ("modules" in ::BotCore)
    && ("bot_spitter_response" in ::BotCore.modules))
{
    if (!("ABA_Spitter_MountActive" in getroottable()))
        ::ABA_Spitter_MountActive <- true;
    else
        ::ABA_Spitter_MountActive = true;

    if (!("ABA_Spitter_ShouldOwnAcid" in getroottable()))
    {
        ::ABA_Spitter_ShouldOwnAcid <- function(bot = null)
        {
            if (bot == null) return true;
            if (bot == null || !bot.IsValid()) return false;
            try { if (NetProps.GetPropInt(bot, "m_lifeState") != 0) return false; } catch (e0) { return false; }
            try { if (bot.IsIncapacitated()) return false; } catch (e1) {}
            try { if (bot.IsDominatedBySpecialInfected()) return false; } catch (e2) {}
            return true;
        };
    }

    printl("[ABA-Spitter] skipped: BotCore bot_spitter_response is already active; ABA acid avoidance will stand down");
    return;
}
::ABA_Spitter_Response_Loaded <- true;
::ABA_Spitter_MountActive <- true;

if (!("BotIsAlive" in getroottable()))
{
    ::BotIsAlive <- function(ent)
    {
        if (ent == null || !ent.IsValid()) return false;
        try { return NetProps.GetPropInt(ent, "m_lifeState") == 0; }
        catch (e) { return false; }
    };
}

if (!("EnsureCfgFile" in getroottable()))
{
    ::EnsureCfgFile <- function(relPath, defaultContent)
    {
        local content = null;
        try { content = FileToString(relPath); } catch (e) { content = null; }
        if (content == null || content.len() == 0)
        {
            try { StringToFile(relPath, defaultContent); }
            catch (e2) { printl("[ABA-Spitter][WARN] cfg write failed: " + relPath + " err=" + e2); }
            return defaultContent;
        }
        return content;
    };
}

if (!("ParseSimpleCfg" in getroottable()))
{
    ::ParseSimpleCfg <- function(content, defaults)
    {
        local result = clone defaults;
        local lines = split(content, "\n");
        foreach (line in lines)
        {
            local s = strip(line);
            if (s.len() == 0) continue;
            local first = s.slice(0, 1);
            if (first == "/" || first == ".") continue;
            local parts = split(s, " \t");
            if (parts.len() < 2) continue;
            if (!(parts[0] in result)) continue;
            local raw = parts[1];
            if (typeof(result[parts[0]]) == "integer")
                result[parts[0]] = raw.tointeger();
            else if (typeof(result[parts[0]]) == "float")
                result[parts[0]] = raw.tofloat();
            else
                result[parts[0]] = raw;
        }
        return result;
    };
}

if (!("HasLOS" in getroottable()))
{
    ::HasLOS <- function(observer, target)
    {
        if (observer == null || !observer.IsValid()) return false;
        if (target == null || !target.IsValid()) return false;
        try
        {
            local tr = { start = observer.EyePosition(), end = target.GetCenter(), ignore = observer, mask = 33636363 };
            TraceLine(tr);
            if (tr.fraction >= 0.95) return true;
            if ("enthit" in tr && tr.enthit == target) return true;
        }
        catch (e) { return true; }
        return false;
    };
}

if (!("BotShouldNotJump" in getroottable()))
{
    ::BotShouldNotJump <- function(bot)
    {
        if (!::BotIsAlive(bot)) return true;
        try { if (bot.IsIncapacitated()) return true; } catch (e) {}
        try { if (bot.IsHangingFromLedge()) return true; } catch (e2) {}
        try { if (bot.IsDominatedBySpecialInfected()) return true; } catch (e3) {}
        return false;
    };
}

if (!("ABA_Spitter_ShouldOwnAcid" in getroottable()))
{
    ::ABA_Spitter_ShouldOwnAcid <- function(bot = null)
    {
        if (!("ABA_Spitter_MountActive" in getroottable()) || !::ABA_Spitter_MountActive) return false;
        if (bot == null) return true;
        if (!::BotIsAlive(bot)) return false;
        try { if (bot.IsIncapacitated()) return false; } catch (e) {}
        try { if (bot.IsDominatedBySpecialInfected()) return false; } catch (e2) {}
        return true;
    };
}

if (!("ABA_Spitter_PauseManualLead" in getroottable()))
{
    ::ABA_Spitter_PauseManualLead <- function(bot, duration = 1.2)
    {
        if (bot == null || !bot.IsValid()) return;
        if (!("BotAI" in getroottable())) return;
        try
        {
            if (bot in ::BotAI.ManualLead)
            {
                local data = ::BotAI.ManualLead[bot];
                local until = Time() + duration;
                if ("acidPauseUntil" in data)
                    data.acidPauseUntil = until;
                else
                    data.acidPauseUntil <- until;
                data.nextPath = until;
                ::BotAI.ManualLead[bot] <- data;

                local nav = ::BotAI.getNavigator(bot);
                if (nav != null)
                {
                    nav.clearPath("manualLead$");
                    nav.clearPath("manualLeadAuto$");
                    nav.clearPath("manualScout$");
                    nav.clearPath("manualLead$Stay#");
                    nav.clearPath("manualLeadAuto$Stay#");
                    nav.clearPath("manualScout$Stay#");
                }
            }
        }
        catch (e) {}
    };
}

if (!("ABA_Spitter_IsManualLeadPaused" in getroottable()))
{
    ::ABA_Spitter_IsManualLeadPaused <- function(bot)
    {
        if (bot == null || !bot.IsValid()) return false;
        if (!("BotAI" in getroottable())) return false;
        try
        {
            if (!(bot in ::BotAI.ManualLead)) return false;
            local data = ::BotAI.ManualLead[bot];
            return ("acidPauseUntil" in data && data.acidPauseUntil > Time());
        }
        catch (e) {}
        return false;
    };
}

if (!("ABA_Spitter_ClearABAAcidOrders" in getroottable()))
{
    ::ABA_Spitter_ClearABAAcidOrders <- function(bot)
    {
        if (bot == null || !bot.IsValid()) return;
        ::ABA_Spitter_PauseManualLead(bot, 1.2);
        try
        {
            bot.ValidateScriptScope();
            bot.GetScriptScope()._aba_spitter_own_until <- Time() + 1.0;
        }
        catch (e0) {}
        try
        {
            if ("BotAI" in getroottable())
            {
                ::BotAI.setBotDedgeVector(bot, null);
                local oldAvoid = ::BotAI.getBotAvoid(bot);
                if (oldAvoid != null)
                {
                    local filteredAvoid = {};
                    foreach (k, danger in oldAvoid)
                    {
                        local keep = true;
                        try
                        {
                            if (danger != null && danger.IsValid() && danger.GetClassname() == "insect_swarm")
                                keep = false;
                        }
                        catch (e2) {}
                        if (keep) filteredAvoid[filteredAvoid.len()] <- danger;
                    }
                    ::BotAI.setBotAvoid(bot, filteredAvoid);
                }
                local nav = ::BotAI.getNavigator(bot);
                if (nav != null)
                {
                    nav.clearPath("avoidDanger");
                    nav.clearPath("avoidDanger#%");
                    nav.clearPath("botMove{+");
                }
            }
        }
        catch (e1) {}
    };
}

::ABA_Spitter_ClearPostAcidWatch <- function(scope)
{
    if (scope == null) return;
    local keys = [
        "_acid_post_clear_until", "_acid_post_clear_origin", "_acid_post_clear_t",
        "_acid_post_clear_recent_pos", "_acid_post_clear_recent_t", "_acid_post_clear_recent_displaced",
        "_acid_post_clear_target", "_acid_post_clear_log_t"
    ];
    foreach (k in keys)
    {
        if (k in scope) delete scope[k];
    }
};

// Recovery must never reset a bot while another subsystem owns an action
// animation.  In particular, clearing m_afButtonForced or CommandABot during
// a medkit/revive/use action can leave the weapon/viewmodel state half deployed.
::ABA_Spitter_IsActionBusy <- function(bot)
{
    if (bot == null || !bot.IsValid()) return true;

    local now = Time();
    local engineBusy = false;
    try
    {
        if (bot.IsIncapacitated() || bot.IsHangingFromLedge()
            || bot.IsDominatedBySpecialInfected())
            engineBusy = true;
    }
    catch (e0) {}

    // Stagger/release frames are also engine-owned input windows.  A bot can
    // be no longer dominated while its weapon animation is still settling.
    try { if (bot.IsStaggering()) engineBusy = true; } catch (eStagger) {}

    // Keep a brief grace period after any engine-owned control frame. Smoker,
    // Hunter and Jockey release can clear the dominated flag before the weapon
    // and viewmodel handoff is complete.
    try
    {
        bot.ValidateScriptScope();
        local actionScope = bot.GetScriptScope();
        if (engineBusy)
        {
            local graceUntil = now + 1.0;
            if ("_aba_spitter_action_grace_until" in actionScope)
                actionScope._aba_spitter_action_grace_until = graceUntil;
            else
                actionScope._aba_spitter_action_grace_until <- graceUntil;
            return true;
        }
        if ("_aba_spitter_action_grace_until" in actionScope)
        {
            if (actionScope._aba_spitter_action_grace_until > now) return true;
            delete actionScope._aba_spitter_action_grace_until;
        }
    }
    catch (eGrace)
    {
        if (engineBusy) return true;
    }

    if ("BotAI" in getroottable())
    {
        // Charger release has a short engine/weapon handoff window.  The
        // shared lockout also covers stale carry/pummel props after the
        // Charger dies, when IsDominatedBySpecialInfected() may already be
        // false but the survivor is still not safe to commandeer.
        try
        {
            if ("isChargerWeaponLockout" in ::BotAI
                && ::BotAI.isChargerWeaponLockout(bot)) return true;
        }
        catch (eChargerLock) {}
        try { if ("IsBotHealing" in ::BotAI && ::BotAI.IsBotHealing(bot)) return true; } catch (e1) {}
        try { if ("IsBotHealingOthers" in ::BotAI && ::BotAI.IsBotHealingOthers(bot)) return true; } catch (e2) {}
        try { if ("IsPlayerReviving" in ::BotAI && ::BotAI.IsPlayerReviving(bot)) return true; } catch (e3) {}
        try { if ("isPlayerBeingRevived" in ::BotAI && ::BotAI.isPlayerBeingRevived(bot)) return true; } catch (e4) {}
        try { if ("isManualKitHealing" in ::BotAI && ::BotAI.isManualKitHealing(bot)) return true; } catch (e5) {}
        try { if ("isManualUseActive" in ::BotAI && ::BotAI.isManualUseActive(bot)) return true; } catch (e6) {}
        try { if ("ManualMedical" in ::BotAI && bot in ::BotAI.ManualMedical) return true; } catch (e7) {}
        try { if ("ManualUse" in ::BotAI && bot in ::BotAI.ManualUse) return true; } catch (e8) {}
    }

    return false;
};

::ABA_Spitter_ClearBotAcidState <- function(bot, fs = null, reason = "", flushMove = false, silence = 0.0)
{
    if (bot == null || !bot.IsValid()) return;
    try
    {
        if (fs == null)
        {
            bot.ValidateScriptScope();
            fs = bot.GetScriptScope();
        }
    }
    catch (e0) { return; }

    local oldHadAcidOrder = ("_acid_evac_active" in fs) || ("_acid_evac_target" in fs)
        || ("_acid_last_move_target" in fs) || ("_acid_clear_deferred" in fs);
    local actionBusy = ::ABA_Spitter_IsActionBusy(bot);

    local clearKeys = [
        "_acid_evac_active", "_acid_evac_target", "_acid_evac_target_t",
        "_acid_evac_origin", "_acid_evac_origin_t", "_acid_evac_pool_set",
        "_acid_evac_jump_t", "_acid_evac_log_t", "_acid_evac_last_best_score",
        "_acid_evac_best_nx", "_acid_evac_best_ny", "_acid_evac_best_dist",
        "_acid_evac_second_nx", "_acid_evac_second_ny", "_acid_evac_second_score", "_acid_evac_second_dist",
        "_acid_stage3_n",
        "_acid_evac_pre_only", "_acid_evac_pre_hold_until",
        "_acid_evac_safe_hold", "_acid_evac_safe_hold_origin", "_acid_evac_safe_hold_cmd_t",
        "_acid_safe_stationary_until",
        "_acid_evac_prev_target",
        "_acid_last_move_t", "_acid_last_move_target",
        "_acid_damage_forced_until", "_acid_damage_pos", "_acid_damage_source_pos",
        "_acid_damage_rescore", "_acid_damage_last_t", "_acid_damage_reissue_t", "_acid_damage_log_t",
        "_stuck_origin", "_stuck_origin_t", "_stuck_recovery_log_t",
        "_stuck_recent_pos", "_stuck_recent_t", "_stuck_recent_displaced"
    ];
    foreach (k in clearKeys)
    {
        if (k in fs) delete fs[k];
    }
    ::ABA_Spitter_ClearPostAcidWatch(fs);

    if (silence > 0.0)
        fs._acid_silenced_until <- Time() + silence;

    // Do not interrupt a medkit/revive/use animation just because the acid
    // source disappeared on this tick. The owning task will release its own
    // input and the next normal AI update can issue a fresh movement order.
    if (!actionBusy)
    {
        if ("_acid_clear_deferred" in fs) delete fs._acid_clear_deferred;
        try { NetProps.SetPropVector(bot, "m_vecAbsVelocity", Vector(0, 0, 0)); } catch (e1) {}
        try
        {
            if ("BotAI" in getroottable())
            {
                local nav = ::BotAI.getNavigator(bot);
                if (nav != null)
                {
                    nav.clearPath("avoidDanger");
                    nav.clearPath("avoidDanger#%");
                    nav.clearPath("botMove{+");
                }
            }
        }
        catch (e2) {}

        if (flushMove)
        {
            // cmd=3 releases the persistent CommandABot order. A MOVE to the
            // current position is not a cancel operation and can become stale.
            try { CommandABot({ cmd = 3, bot = bot }); } catch (e3) {}
        }
    }
    else if (::g_StuckRecoveryDebug == 1 && flushMove && oldHadAcidOrder)
    {
        ::ABA_Spitter_SetScopeValue(fs, "_acid_clear_deferred", true);
        printl("[ABA-Spitter][clear-deferred] bot=" + bot.GetPlayerName()
            + " action is busy; skipped velocity/nav/cmd=3 reset (reason=" + reason + ")");
    }
    else if (actionBusy && flushMove && oldHadAcidOrder)
    {
        ::ABA_Spitter_SetScopeValue(fs, "_acid_clear_deferred", true);
    }

    if (::g_AcidDebug == 1 && reason != "")
        printl("[ABA-Spitter][clear] bot=" + bot.GetPlayerName() + " reason=" + reason);
};

::ABA_Spitter_ClearAllBotAcidStates <- function(reason = "global-clear", flushMove = false)
{
    local b = null;
    while (b = Entities.FindByClassname(b, "player"))
    {
        if (!b.IsValid() || !b.IsSurvivor() || !IsPlayerABot(b)) continue;
        b.ValidateScriptScope();
        local fs = b.GetScriptScope();
        if ("_acid_evac_active" in fs || "_acid_evac_target" in fs || "_acid_evac_pre_only" in fs
            || "_acid_clear_deferred" in fs)
            ::ABA_Spitter_ClearBotAcidState(b, fs, reason, flushMove, 0.0);
    }
};

::ABA_Spitter_HasCriticalHuman <- function()
{
    local p = null;
    while (p = Entities.FindByClassname(p, "player"))
    {
        if (!p.IsValid() || !p.IsSurvivor() || IsPlayerABot(p)) continue;
        try { if (NetProps.GetPropInt(p, "m_lifeState") != 0) continue; } catch (e0) { continue; }

        try { if (NetProps.GetPropInt(p, "m_bIsOnThirdStrike") != 0) return true; } catch (e1) {}
        try { if (NetProps.GetPropInt(p, "m_currentReviveCount") >= 2) return true; } catch (e2) {}

        try
        {
            if (p.IsIncapacitated() || p.IsHangingFromLedge())
            {
                local hp = p.GetHealth();
                if (hp <= 90) return true;
            }
        }
        catch (e3) {}
    }
    return false;
};

if (!("SafeCommandBot" in getroottable()))
{
    ::SafeCommandBot <- function(cmd, bot, target_pos, target_ent,
        priority = 3, lock_dur = 0.0, clear_vel = false, source = "ABA-Spitter")
    {
        if (!::BotIsAlive(bot)) return;
        if (::ABA_Spitter_IsActionBusy(bot)) return;
        ::ABA_Spitter_PauseManualLead(bot, 1.2);
        ::ABA_Spitter_ClearABAAcidOrders(bot);
        local tbl = { cmd = cmd, bot = bot };
        if (target_pos != null) tbl.pos <- target_pos;
        if (target_ent != null) tbl.target <- target_ent;
        try { CommandABot(tbl); } catch (e) {}
        if (cmd == 1)
        {
            try { bot.ValidateScriptScope(); bot.GetScriptScope()._last_move_cmd_t <- Time(); } catch (e2) {}
        }
        if (clear_vel)
        {
            try
            {
                local v = NetProps.GetPropVector(bot, "m_vecAbsVelocity");
                NetProps.SetPropVector(bot, "m_vecAbsVelocity", Vector(0, 0, v.z));
            }
            catch (e3) {}
        }
    };
}

if (!("ForceBotEscapeJump" in getroottable()))
{
    ::ForceBotEscapeJump <- function(bot, dirX, dirY)
    {
        if (bot == null || !bot.IsValid()) return;
        if (::BotShouldNotJump(bot)) return;
        ::ABA_Spitter_PauseManualLead(bot, 1.2);
        ::ABA_Spitter_ClearABAAcidOrders(bot);
        try
        {
            local v = NetProps.GetPropVector(bot, "m_vecAbsVelocity");
            local boost = 230.0;
            NetProps.SetPropVector(bot, "m_vecAbsVelocity",
                Vector(v.x + dirX * boost, v.y + dirY * boost, 290.0));
        }
        catch (e) {}
    };
}

if (!("ABA_Spitter_SetScopeValue" in getroottable()))
{
    ::ABA_Spitter_SetScopeValue <- function(scope, key, value)
    {
        if (key in scope)
            scope[key] = value;
        else
            scope[key] <- value;
    };
}

if (!("ABA_Spitter_PointClearOfHazards" in getroottable()))
{
    ::ABA_Spitter_PointClearOfHazards <- function(pos, hazards, minDist = 150.0)
    {
        foreach (h in hazards)
        {
            local dx = pos.x - h.x;
            local dy = pos.y - h.y;
            local r = minDist;
            if ("weight" in h && h.weight >= 1.0)
                r = minDist + 35.0;
            if (dx * dx + dy * dy < r * r)
                return false;
        }
        return true;
    };
}

if (!("ABA_Spitter_GetNearestHazardD2" in getroottable()))
{
    ::ABA_Spitter_GetNearestHazardD2 <- function(pos, hazards)
    {
        local best = 999999999.0;
        foreach (h in hazards)
        {
            local dx = pos.x - h.x;
            local dy = pos.y - h.y;
            local d2 = dx * dx + dy * dy;
            if (d2 < best)
                best = d2;
        }
        return best;
    };
}

if (!("ABA_Spitter_HasSafeHumanAnchor" in getroottable()))
{
    ::ABA_Spitter_HasSafeHumanAnchor <- function(bot, botPos, hazards, maxDistance = 240.0)
    {
        local maxD2 = maxDistance * maxDistance;
        local p = null;
        while (p = Entities.FindByClassname(p, "player"))
        {
            if (!p.IsValid() || p == bot || !p.IsSurvivor() || IsPlayerABot(p)) continue;
            try { if (NetProps.GetPropInt(p, "m_lifeState") != 0) continue; } catch (e0) { continue; }

            local pp = p.GetOrigin();
            if (abs(pp.z - botPos.z) > 96.0) continue;
            try
            {
                local pa = p.GetLastKnownArea();
                if (pa != null && pa.IsDamaging()) continue;
            }
            catch (eArea) {}
            local dx = pp.x - botPos.x;
            local dy = pp.y - botPos.y;
            if (dx * dx + dy * dy > maxD2) continue;
            if (!::ABA_Spitter_PointClearOfHazards(pp, hazards, 90.0)) continue;

            try
            {
                local tr = {
                    start = Vector(botPos.x, botPos.y, botPos.z + 48.0),
                    end = Vector(pp.x, pp.y, pp.z + 48.0),
                    ignore = bot, mask = 33636363
                };
                TraceLine(tr);
                if (!tr.hit || tr.enthit == p) return true;
            }
            catch (e1) { return true; }
        }
        return false;
    };
}

if (!("ABA_Spitter_HasOpenPoolLine" in getroottable()))
{
    ::ABA_Spitter_HasOpenPoolLine <- function(bot, botPos, poolPos)
    {
        local bestFrac = 0.0;
        local heights = [20.0, 48.0];
        foreach (h in heights)
        {
            try
            {
                local tr = {
                    start = Vector(botPos.x, botPos.y, botPos.z + h),
                    end = Vector(poolPos.x, poolPos.y, poolPos.z + h),
                    ignore = bot, mask = 33636363
                };
                TraceLine(tr);
                if (!tr.hit) return true;
                if (tr.fraction > bestFrac) bestFrac = tr.fraction;
            }
            catch (e) { return true; }
        }
        return bestFrac > 0.82;
    };
}

if (!("ABA_Spitter_ProbeJumpObstacle" in getroottable()))
{
    ::ABA_Spitter_ProbeJumpObstacle <- function(bot, botPos, nx, ny)
    {
        local step = 76.0;
        local lowMin = 1.0;
        local highMax = 0.0;
        local lowHeights = [18.0, 34.0, 50.0];
        local highHeights = [82.0, 110.0];

        foreach (h in lowHeights)
        {
            try
            {
                local tr = {
                    start = Vector(botPos.x, botPos.y, botPos.z + h),
                    end = Vector(botPos.x + nx * step, botPos.y + ny * step, botPos.z + h),
                    ignore = bot, mask = 33636363
                };
                TraceLine(tr);
                if (tr.fraction < lowMin) lowMin = tr.fraction;
            }
            catch (e) {}
        }

        foreach (h in highHeights)
        {
            try
            {
                local tr = {
                    start = Vector(botPos.x, botPos.y, botPos.z + h),
                    end = Vector(botPos.x + nx * step, botPos.y + ny * step, botPos.z + h),
                    ignore = bot, mask = 33636363
                };
                TraceLine(tr);
                if (tr.fraction > highMax) highMax = tr.fraction;
            }
            catch (e) { highMax = 1.0; }
        }

        return {
            lowBlocked = lowMin < 0.45,
            highClear = highMax > 0.72,
            fullBlocked = highMax < 0.25,
            lowFrac = lowMin,
            highFrac = highMax
        };
    };
}

if (!("ABA_Spitter_FindHighEscapeTarget" in getroottable()))
{
    ::ABA_Spitter_FindHighEscapeTarget <- function(bot, botPos, hazards)
    {
        local startArea = null;
        try { startArea = bot.GetLastKnownArea(); } catch (e0) {}
        local areas = {};
        try { NavMesh.GetNavAreasInRadius(botPos, 440.0, areas); } catch (e1) { return null; }

        local best = null;
        local bestScore = -999999.0;
        foreach (area in areas)
        {
            if (area == null) continue;
            if (area.IsDamaging() || area.IsBlocked(2, false) || area.IsBlocked(2, true)) continue;

            local pos = area.GetCenter();
            local dz = pos.z - botPos.z;
            if (dz < 18.0 || dz > 150.0) continue;
            if (!::ABA_Spitter_PointClearOfHazards(pos, hazards, 165.0)) continue;

            local dx = pos.x - botPos.x;
            local dy = pos.y - botPos.y;
            local d2 = dx * dx + dy * dy;
            if (d2 < 60.0 * 60.0 || d2 > 440.0 * 440.0) continue;

            if (startArea != null && !NavMesh.NavAreaBuildPath(startArea, area, pos, 760.0, 2, false))
                continue;

            try
            {
                local tr = {
                    start = Vector(botPos.x, botPos.y, botPos.z + 56.0),
                    end = Vector(pos.x, pos.y, pos.z + 56.0),
                    ignore = bot, mask = 33636363
                };
                TraceLine(tr);
                if (tr.fraction < 0.45) continue;
            }
            catch (e2) {}

            local dist = sqrt(d2);
            local score = dz * 2.2 - dist * 0.18;
            if (score > bestScore)
            {
                bestScore = score;
                best = pos;
            }
        }

        return best;
    };
}

if (!("ABA_Spitter_MoveAndJump" in getroottable()))
{
    ::ABA_Spitter_MoveAndJump <- function(bot, target)
    {
        if (target == null || !target) return false;
        local pos = bot.GetOrigin();
        local dx = target.x - pos.x;
        local dy = target.y - pos.y;
        local len = sqrt(dx * dx + dy * dy);
        if (len < 1.0) return false;

        local nx = dx / len;
        local ny = dy / len;
        ::SafeCommandBot(1, bot, target, null);
        ::ForceBotEscapeJump(bot, nx, ny);
        return true;
    };
}

if (!("IdleTeleportBot" in getroottable()))
{
    ::IdleTeleportBot <- function(bot, leaderPos)
    {
        if (!::BotIsAlive(bot)) return;
        local land = leaderPos;
        try
        {
            local tr = { start = Vector(leaderPos.x, leaderPos.y, leaderPos.z + 96.0),
                end = Vector(leaderPos.x, leaderPos.y, leaderPos.z - 256.0),
                ignore = bot, mask = 33636363 };
            TraceLine(tr);
            if (tr.fraction < 1.0)
            {
                local z = (leaderPos.z + 96.0) - 352.0 * tr.fraction;
                land = Vector(leaderPos.x, leaderPos.y, z + 8.0);
            }
        }
        catch (e0) {}
        try { bot.SetOrigin(land); } catch (e1) { try { NetProps.SetPropVector(bot, "m_vecOrigin", land); } catch (e2) {} }
        try { NetProps.SetPropVector(bot, "m_vecAbsVelocity", Vector(0, 0, 0)); } catch (e3) {}
        ::ABA_Spitter_ClearABAAcidOrders(bot);
    };
}

// =========================================================
// bot_spitter_response - bot_module_spitter.nut
//
// 由 bot_ai_lib_supp 的 BotAILib_Bootstrap() 通过 DoIncludeScript 加载.
// 模块包含:
//   [1A] 酸液伤害豁免           cfg: bot acid immunity cfg/bot acid immunity.txt
//   [1B] 主动避酸 (含抛射预警 + 卡死自救 + 悬崖安全检查)
//   [1D] 卡死恢复 (StuckRecovery, 监控 C-full 避酸中的 bot 是否真卡死)
//
// 注: 原 [1C] 防跌落 + 挂边自救 已迁出至独立 addon bot_fall_preventing.
//     spitter 的 IsAcidTargetSafe 仍用 ::g_FallCfg.FallPreventHeight (由 fall_preventing
//     先加载并初始化); 若用户未装 fall_preventing 模块, IsAcidTargetSafe 自动回退到默认 250.
//
// 入口: ::BotModule_Spitter_Init (由 lib 调用)
//
// 依赖 lib 提供:
//   ::EnsureCfgFile / ::ParseSimpleCfg / ::HasLOS / ::SafeCommandBot
//   ::BotShouldNotJump / ::ForceBotEscapeJump
// 可选依赖 bot_fall_preventing:
//   ::g_FallCfg (用于悬崖落差阈值; 不存在时 fallback 250)
// =========================================================

// ---- 配置: 酸液 ----
::ACID_CFG_PATH <- "aba spitter response cfg/aba spitter response.txt";
::DEFAULT_ACID_CFG <- "AcidDamageScale 0.5\nAcidPreEvasionTimeout 1.0\nAcidPoolEvasionTimeout 5.0\nAcidClearGrace 3.0\n.\n.\n// AcidDamageScale = bot acid damage multiplier.\n// 0 = full acid immunity and active acid evasion is disabled.\n// Non-zero values below 0.1 are clamped to 0.1.\n// Examples: 1.0 = normal damage, 0.8 = 80% damage, 0.5 = half damage.\n.\n// ABA mount notes:\n// This module owns insect_swarm and spitter_projectile avoidance. ABA's fire,\n// tank, common/special infected combat, rescue, pickup, and shove tasks remain active.\n.\n// AcidPreEvasionTimeout = Pre-evasion warning timeout in seconds.\n// AcidPoolEvasionTimeout = Pool/projectile evasion timeout in seconds.\n// AcidClearGrace = Grace period before clearing per-bot acid state.\n.\n// Auto-generated. Delete and reload to reset.\n.\n";
::g_AcidCfg <- { AcidImmunity = 0, AcidDamageScale = 0.5, AcidPreEvasionTimeout = 1.0, AcidPoolEvasionTimeout = 5.0, AcidClearGrace = 3.0 };

::LoadAcidCfg <- function()
{
    if (!("EnsureCfgFile" in getroottable())) return; // lib not loaded yet, use defaults
    local content = ::EnsureCfgFile(::ACID_CFG_PATH, ::DEFAULT_ACID_CFG);
    if (content.find("AcidDamageScale") == null)
    {
        local legacy = ::ParseSimpleCfg(content, { AcidImmunity = 0 });
        local migratedScale = (("AcidImmunity" in legacy) && legacy.AcidImmunity == 1) ? "0" : "0.5";
        content = content + "\nAcidDamageScale " + migratedScale + "\n// AcidDamageScale migrated from legacy AcidImmunity. 0 = full acid immunity; non-zero values below 0.1 clamp to 0.1.\n";
        try { StringToFile(::ACID_CFG_PATH, content); }
        catch (e) { printl("[ABA-Spitter][WARN] failed to append AcidDamageScale cfg: " + e); }
    }
    ::g_AcidCfg = ::ParseSimpleCfg(content, { AcidImmunity = 0, AcidDamageScale = 0.5, AcidPreEvasionTimeout = 1.0, AcidPoolEvasionTimeout = 5.0, AcidClearGrace = 3.0 });
};

::GetAcidDamageScale <- function()
{
    local scale = ("AcidDamageScale" in ::g_AcidCfg) ? ::g_AcidCfg.AcidDamageScale.tofloat() : 0.5;
    if (scale < 0.0) scale = 0.0;
    if (scale > 0.0 && scale < 0.1) scale = 0.1;
    return scale;
};

::IsAcidDamageImmune <- function()
{
    return ::GetAcidDamageScale() == 0.0;
};

::ABA_Spitter_RecordAcidDamage <- function(bot, inflictor)
{
    if (bot == null || !bot.IsValid()) return;
    try
    {
        bot.ValidateScriptScope();
        local fs = bot.GetScriptScope();
        local now = Time();
        local botPos = bot.GetOrigin();
        local prevDamage = ("_acid_damage_last_t" in fs) ? fs._acid_damage_last_t : 0.0;
        local shouldRescore = (!("_acid_evac_active" in fs) || !("_acid_evac_target" in fs) || (now - prevDamage) > 0.8);
        fs._acid_damage_forced_until <- now + 1.6;
        fs._acid_damage_pos <- botPos;
        if (inflictor != null && inflictor.IsValid())
            fs._acid_damage_source_pos <- inflictor.GetOrigin();
        if (shouldRescore)
            fs._acid_damage_rescore <- true;
        fs._acid_damage_last_t <- now;
        if ("_acid_silenced_until" in fs)
            delete fs._acid_silenced_until;
        if (shouldRescore)
        {
            if ("_acid_evac_pre_only" in fs)
                delete fs._acid_evac_pre_only;
            if ("_acid_evac_target" in fs)
                delete fs._acid_evac_target;
        }
    }
    catch (e) {}
};

::ABA_Spitter_HasForcedAcidDamage <- function(now)
{
    local b = null;
    while (b = Entities.FindByClassname(b, "player"))
    {
        if (!b.IsValid() || !b.IsSurvivor() || !IsPlayerABot(b)) continue;
        try
        {
            b.ValidateScriptScope();
            local fs = b.GetScriptScope();
            if (("_acid_damage_forced_until" in fs) && fs._acid_damage_forced_until > now)
                return true;
        }
        catch (e) {}
    }
    return false;
};

// =========================================================
// [1A] 酸液伤害豁免 (仅 AcidImmunity=1)
// =========================================================
::HandleBotAcidDamage <- function( dmgTable )
{
    try
    {
        if (!("Victim" in dmgTable)) return true;
        local victim = dmgTable.Victim;
        if (victim == null || !victim.IsValid()) return true;
        if (victim.GetClassname() != "player") return true;
        if (!victim.IsSurvivor()) return true;
        if (!IsPlayerABot(victim)) return true;

        local inflictor = ("Inflictor" in dmgTable) ? dmgTable.Inflictor : null;
        if (inflictor == null || !inflictor.IsValid()) return true;
        local cls = inflictor.GetClassname();

        if (cls != "insect_swarm" && cls != "spitter_projectile")
            return true;

        local scale = ::GetAcidDamageScale();

        if (scale == 0.0)
            return false;

        ::ABA_Spitter_RecordAcidDamage(victim, inflictor);

        if (scale != 1.0 && ("DamageDone" in dmgTable))
            dmgTable.DamageDone *= scale;

        return true;
    }
    catch (err) { return true; }
};
if (("VSLib" in getroottable()) && ("EasyLogic" in ::VSLib) && ("OnTakeDamage" in ::VSLib.EasyLogic))
{
    if ("ABA_Spitter_AcidDamage" in ::VSLib.EasyLogic.OnTakeDamage)
        ::VSLib.EasyLogic.OnTakeDamage.ABA_Spitter_AcidDamage = function(dmgTable) { return ::HandleBotAcidDamage(dmgTable); };
    else
        ::VSLib.EasyLogic.OnTakeDamage.ABA_Spitter_AcidDamage <- function(dmgTable) { return ::HandleBotAcidDamage(dmgTable); };
    if ("ABA_Spitter_DamageHookMode" in getroottable())
        ::ABA_Spitter_DamageHookMode = "VSLib.EasyLogic.OnTakeDamage";
    else
        ::ABA_Spitter_DamageHookMode <- "VSLib.EasyLogic.OnTakeDamage";
}
else
{
    local previousAllowTakeDamage = ("AllowTakeDamage" in getroottable()) ? ::AllowTakeDamage : null;
    local chainedAllowTakeDamage = function(dmgTable)
    {
        if (!::HandleBotAcidDamage(dmgTable)) return false;
        if (previousAllowTakeDamage != null) return previousAllowTakeDamage(dmgTable);
        return true;
    };
    if ("AllowTakeDamage" in getroottable())
        ::AllowTakeDamage = chainedAllowTakeDamage;
    else
        ::AllowTakeDamage <- chainedAllowTakeDamage;
    if ("ABA_Spitter_DamageHookMode" in getroottable())
        ::ABA_Spitter_DamageHookMode = "AllowTakeDamage";
    else
        ::ABA_Spitter_DamageHookMode <- "AllowTakeDamage";
}

// =========================================================
// [1B] 主动避酸 (仅 AcidImmunity=0)
// =========================================================

// 已知的 insect_swarm 实体 idx 集合 -- 用于检测"新出现的酸池"(包括 spitter 死亡池)
::g_SeenAcidPoolIdx <- {};

// 酸池生命周期追踪: { idx -> { birth_t, pos } }
// birth_t = 酸池首次被发现的时间戳
// pos = 酸池位置（用于调试）
::g_AcidPoolLifetime <- {};

// 检查从 botPos 朝 (nx, ny) 方向走 distance 单位是否安全 (无致命落差)
// 复用 FallPreventHeight 阈值, 默认 250 单位
// fallLimit 可选: 传入则覆盖默认 (用于楼梯/井盖 IN_POOL 场景, 宁可摔下楼梯也要逃出酸池)
// 注: g_FallCfg 由独立 addon bot_fall_preventing 提供, 未装时 fallback 到默认 250
::IsAcidTargetSafe <- function( botPos, nx, ny, distance, fallLimit = null )
{
    local cfgLimit = 250;
    if ("g_FallCfg" in getroottable() && "FallPreventHeight" in ::g_FallCfg)
        cfgLimit = ::g_FallCfg.FallPreventHeight;
    local limit = (fallLimit != null) ? fallLimit : cfgLimit;
    local probe_x = botPos.x + nx * distance;
    local probe_y = botPos.y + ny * distance;
    local probe_z = botPos.z + 8.0;
    try
    {
        local trace = {
            start = Vector(probe_x, probe_y, probe_z),
            end = Vector(probe_x, probe_y, probe_z - 2500.0),
            mask = 33636363
        };
        TraceLine(trace);
        local dropDist = 2500.0 * trace.fraction;
        if (dropDist >= limit) return false;
    }
    catch (e) { }
    return true;
};

// 检查从 botPos 朝 (nx, ny) 方向是否被"立即墙"阻挡 (64 单位短程检查).
// 关键: 不做 280u 长程 trace —— 远端撞墙是常态 (室内地图所有方向都会撞墙),
//       bot 寻路器能自动绕过远处障碍 (走门洞/拐弯). 我们只筛掉 bot 紧贴
//       墙根的"无法起步"方向. 64u 大约一个步长.
// 取膝高 (32u) 与胸高 (56u) 两条 trace 中较通畅的一条作为代表.
// 必须传 bot 用作 ignore, 否则 trace 起点位于 bot 碰撞箱内会立即撞自身 (fraction=0).
// 返回值: 0.0~1.0 的最大 fraction. >= 0.7 视为可走.
::IsAcidTargetReachable <- function( bot, botPos, nx, ny )
{
    local STEP = 64.0;
    local heights = [32.0, 56.0];
    local maxFrac = 0.0;
    foreach (h in heights)
    {
        try
        {
            local trace = {
                start = Vector(botPos.x, botPos.y, botPos.z + h),
                end = Vector(botPos.x + nx * STEP, botPos.y + ny * STEP, botPos.z + h),
                ignore = bot,
                mask = 33636363
            };
            TraceLine(trace);
            if (trace.fraction > maxFrac) maxFrac = trace.fraction;
        }
        catch (e) { return 1.0; }
    }
    return maxFrac;
};

// 检查 bot 是否被嵌入实体/几何内. 24 次 TraceLine (3 高度 × 8 角度), 起点都在 bot 当前位置
// (botPos.z + 16/32/56), 朝水平 8 方向各 64u. 若 fraction<0.1 即视为该 trace 一开始就被实体挡住.
// 返回 hit 数 (0~24). 调用方判 >=22 → 嵌入 (留 2 个余量给单边墙角合法卡边).
// 用途: 当 spitter FindSafeAcidTarget 持续返回 null 时, 用这个判断是几何嵌入还是单纯地形复杂.
::IsBotEmbedded <- function( bot, botPos )
{
    local hitCount = 0;
    local PI = 3.14159265;
    local angles = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0];
    local heights = [16.0, 32.0, 56.0];
    foreach (h in heights)
    {
        foreach (angDeg in angles)
        {
            local rad = angDeg * PI / 180.0;
            local nx = cos(rad);
            local ny = sin(rad);
            try
            {
                local trace = {
                    start = Vector(botPos.x, botPos.y, botPos.z + h),
                    end = Vector(botPos.x + nx * 64.0, botPos.y + ny * 64.0, botPos.z + h),
                    ignore = bot,
                    mask = 33636363
                };
                TraceLine(trace);
                if (trace.fraction < 0.1) hitCount++;
            }
            catch (e) { }
        }
    }
    return hitCount;
};

// 给定逃离方向 (nx,ny), 在多个角度方向中找一个安全且可走的目标点.
// expandMode = false (默认): fwd / +60° / -60° 三方向, 用于正常 spitter 抛射逃离.
// expandMode = true: fwd / +60° / -60° / +120° / -120° / 180° 六方向, 用于 IN_POOL 死角逃脱
//   (90° 墙角中, 朝远离酸池中心方向常被墙挡, 唯一可走方向反而是 180° 反向).
// lenientCliff = false (默认): 用 FallPreventHeight (250u) 判悬崖.
// lenientCliff = true: 放宽到 600u, 用于楼梯/井盖等"留酸池更糟"的场景, 允许跳下台阶.
//
// 2026-05-25 P5 修复: 当初始三方向全被崖检测拒绝时, 自动升级搜索:
//   Fallback 1 → 六方向 (不放宽崖)
//   Fallback 2 → 六方向 + 放宽崖 (600u) — 安全斜坡在此通过
//   Fallback 3 → 六方向中选 frac 最高者 (完全忽略崖) — "留酸更糟"原则
// 仅初始调用 (expandMode=false, lenientCliff=false) 触发 fallback, 递归/显式调用不触发.
::FindSafeAcidTarget <- function( bot, botPos, nx, ny, distance, expandMode = false, lenientCliff = false )
{
    local THR = 0.7;
    local cos60 = 0.5;
    local sin60 = 0.866;
    local cos120 = -0.5;
    local sin120 = 0.866;

    local cliffLimit = lenientCliff ? 600 : null;  // null = 走默认 FallPreventHeight

    local dirs = [
        { dx = nx, dy = ny, label = "fwd" },
        { dx = nx * cos60 - ny * sin60, dy = nx * sin60 + ny * cos60, label = "+60" },
        { dx = nx * cos60 + ny * sin60, dy = -nx * sin60 + ny * cos60, label = "-60" }
    ];
    if (expandMode)
    {
        dirs.append({ dx = nx * cos120 - ny * sin120, dy = nx * sin120 + ny * cos120, label = "+120" });
        dirs.append({ dx = nx * cos120 + ny * sin120, dy = -nx * sin120 + ny * cos120, label = "-120" });
        dirs.append({ dx = -nx, dy = -ny, label = "180" });
    }

    local fails = [];
    foreach (d in dirs)
    {
        local cliff = !::IsAcidTargetSafe(botPos, d.dx, d.dy, distance, cliffLimit);
        local frac = ::IsAcidTargetReachable(bot, botPos, d.dx, d.dy);
        if (!cliff && frac >= THR)
        {
            return Vector(botPos.x + d.dx * distance, botPos.y + d.dy * distance, botPos.z);
        }
        fails.append({ label = d.label, cliff = cliff, frac = frac, dx = d.dx, dy = d.dy });
    }

    if (::g_AcidDebug == 1)
    {
        local tag = expandMode ? "六方向皆拒" : "三方向皆拒";
        if (lenientCliff) tag = tag + "(放宽崖)";
        else if (expandMode) tag = tag + "(扩展)";
        local s = "[SpitDbg][findtarget] " + tag + ":";
        foreach (f in fails)
        {
            s = s + " " + f.label + "(" + (f.cliff ? "崖" : "·") + format("%.2f", f.frac) + ")";
        }
        printl(s);
    }

    // ---- FALLBACK 升级 (仅初始默认调用触发, 递归调用直接返回 null) ----
    if (expandMode || lenientCliff) return null;

    // Fallback 1: 扩展到六方向 (保持严格崖检测)
    local fb1 = ::FindSafeAcidTarget(bot, botPos, nx, ny, distance, true, false);
    if (fb1 != null)
    {
        if (::g_AcidDebug == 1)
            printl("[SpitDbg][fallback] 三方向失败 → 六方向成功");
        return fb1;
    }

    // Fallback 2: 六方向 + 放宽崖 (600u) — 安全斜坡在此阶段通过
    local fb2 = ::FindSafeAcidTarget(bot, botPos, nx, ny, distance, true, true);
    if (fb2 != null)
    {
        if (::g_AcidDebug == 1)
            printl("[SpitDbg][fallback] 六方向严格崖失败 → 六方向放宽崖成功");
        return fb2;
    }

    // Fallback 3: 六方向 + 放宽崖全失败 → 从所有六方向中选 frac 最高者, 完全忽略崖
    // "留在酸里更糟"原则: 任何方向都比站着不动好
    local allDirs = [
        { dx = nx, dy = ny, label = "fwd" },
        { dx = nx * cos60 - ny * sin60, dy = nx * sin60 + ny * cos60, label = "+60" },
        { dx = nx * cos60 + ny * sin60, dy = -nx * sin60 + ny * cos60, label = "-60" },
        { dx = nx * cos120 - ny * sin120, dy = nx * sin120 + ny * cos120, label = "+120" },
        { dx = nx * cos120 + ny * sin120, dy = -nx * sin120 + ny * cos120, label = "-120" },
        { dx = -nx, dy = -ny, label = "180" }
    ];
    local bestFrac = -1.0;
    local bestD = null;
    foreach (d in allDirs)
    {
        local frac = ::IsAcidTargetReachable(bot, botPos, d.dx, d.dy);
        if (frac > bestFrac) { bestFrac = frac; bestD = d; }
    }

    if (bestD != null && bestFrac >= 0.2)
    {
        if (::g_AcidDebug == 1)
            printl("[SpitDbg][fallback] 全方向+放宽崖失败, 强制选 " + bestD.label
                + " frac=" + format("%.2f", bestFrac) + " (忽略崖检测, 留酸更糟)");
        return Vector(botPos.x + bestD.dx * distance, botPos.y + bestD.dy * distance, botPos.z);
    }

    if (::g_AcidDebug == 1)
        printl("[SpitDbg][fallback] 全六方向 frac<0.2 — 完全被封 (嵌入几何?), 等待 StuckRecovery");
    return null;
};

// 共用即时响应: 只用于尚未落地的 spit_burst 预警。
// 已落地的 acid pool 必须等待下面的统一评分：它会同时考虑门/墙遮挡、
// 多个酸池和当前安全侧。若在这里先按单池固定距离 MOVE，bot 会被推出
// 安全房间，或直接从一个相邻酸池移到另一个。
::DoImmediateAcidEvasion <- function( landing, source )
{
    if (source != "spit_burst") return 0;

    local IMMEDIATE_R2 = 320 * 320;
    local VERTICAL_LIMIT = 96.0;
    local moveDist = 155.0;
    local b = null;
    local hitCnt = 0;
    while (b = Entities.FindByClassname(b, "player"))
    {
        if (!b.IsValid()) continue;
        if (!b.IsSurvivor()) continue;
        if (!IsPlayerABot(b)) continue;
        try { if (NetProps.GetPropInt(b, "m_lifeState") != 0) continue; } catch(e) { continue; }
        if (::ABA_Spitter_IsActionBusy(b)) continue;

        local bp = b.GetOrigin();
        local dx = bp.x - landing.x;
        local dy = bp.y - landing.y;
        local dz = bp.z - landing.z;
        if (abs(dz) > VERTICAL_LIMIT) continue;
        local d2 = dx*dx + dy*dy;
        if (d2 > IMMEDIATE_R2) continue;

        // A warning behind a closed door/wall is not an immediate threat. The
        // full tick will still score the pool if the bot later enters its area.
        if (!::ABA_Spitter_HasOpenPoolLine(b, bp, landing)) continue;

        local len = sqrt(d2);
        if (len < 1.0) { dx = 64.0; dy = 0.0; len = 64.0; }
        local nx = dx / len;
        local ny = dy / len;
        local target = ::FindSafeAcidTarget(b, bp, nx, ny, moveDist);
        if (target == null)
        {
            if (::g_AcidDebug == 1)
                printl("[SpitDbg]   即时响应跳过: bot=\" + b.GetPlayerName() + \" 三方向皆拒 (见 [findtarget] 行)");
            continue;
        }

        // cmd=1 (MOVE): 强制 bot 去 pos. 不要用 cmd=2 (RETREAT) ——
        // 后者会被 bot 解读为"退回队伍/玩家身边", 经常忽略 pos 参数.
        ::SafeCommandBot(1, b, target, null);

        // 记录本次 MOVE 时刻 / 目标, 让后续 AcidEvasionTick 的节流逻辑能尊重它,
        // 避免下一 tick 立即再次 MOVE 打断寻路.
        b.ValidateScriptScope();
        local sc = b.GetScriptScope();
        sc._acid_last_move_t <- Time();
        sc._acid_last_move_target <- target;
        if (source == "spit_burst")
        {
            sc._acid_evac_active <- true;
            sc._acid_evac_target <- target;
            sc._acid_evac_target_t <- Time();
            sc._acid_evac_origin <- bp;
            sc._acid_evac_origin_t <- Time();
            sc._acid_evac_pool_set <- {};
            sc._acid_evac_pre_only <- true;
        }

        hitCnt++;
    }

    if (::g_AcidDebug == 1)
        printl("[SpitDbg] immediate response[" + source + "]: " + hitCnt + " bot MOVE");
    return hitCnt;
};

// spit_burst 事件触发的预警列表 [{pos, expire}, ...]
::g_ActiveSpits <- [];
::g_AcidDebug <- 0;
::g_AcidTickLogCd <- 0.0;

if (::g_AcidDebug == 1)
    printl("[ABA-Spitter] acid damage hook: " + (("ABA_Spitter_DamageHookMode" in getroottable()) ? ::ABA_Spitter_DamageHookMode : "none"));

// 事件处理 (由 bot_spitter_events.nut 内的 OnGameEvent_spit_burst 调用)
::HandleSpitBurstEvent <- function( event )
{
    if (::g_AcidDebug == 1)
        printl("[SpitDbg] >>>>>> HandleSpitBurstEvent ENTERED <<<<<<");
    if (::g_AcidDebug == 1)
        printl("[SpitDbg] EVENT spit_burst userid=" + (("userid" in event) ? event.userid : "?")
            + " subject=" + (("subject" in event) ? event.subject : "?"));

    if (::IsAcidDamageImmune())
    {
        if (::g_AcidDebug == 1) printl("[ABA-Spitter] skipped spit_burst evasion: AcidDamageScale=0");
        return;
    }

    local landing = null;
    if ("subject" in event)
    {
        try
        {
            local proj = EntIndexToHScript(event.subject);
            if (proj != null && proj.IsValid())
            {
                landing = proj.GetOrigin();
                if (::g_AcidDebug == 1)
                    printl("[SpitDbg]   subject ent ok, classname=" + proj.GetClassname()
                        + " landing=(" + landing.x.tointeger() + "," + landing.y.tointeger() + ")");
            }
        }
        catch (e) { }
    }

    if (landing == null && ("userid" in event))
    {
        local spitter = GetPlayerFromUserID(event.userid);
        if (spitter != null && spitter.IsValid())
        {
            local sPos = spitter.GetOrigin();
            local closestSurv = null;
            local closestD2 = 4000.0 * 4000.0;
            local p = null;
            while (p = Entities.FindByClassname(p, "player"))
            {
                if (!p.IsValid()) continue;
                if (!p.IsSurvivor()) continue;
                try { if (NetProps.GetPropInt(p, "m_lifeState") != 0) continue; } catch(e) { continue; }
                local pp = p.GetOrigin();
                local dx = pp.x - sPos.x;
                local dy = pp.y - sPos.y;
                local dz = pp.z - sPos.z;
                local d2 = dx*dx + dy*dy + dz*dz;
                if (d2 < closestD2) { closestD2 = d2; closestSurv = p; }
            }
            if (closestSurv != null) landing = closestSurv.GetOrigin();
        }
    }

    if (landing == null)
    {
        if (::g_AcidDebug == 1) printl("[SpitDbg]   skipped: 无法解出落点");
        return;
    }

    local now = Time();
    local dup = false;
    foreach (w in ::g_ActiveSpits)
    {
        local dx = w.pos.x - landing.x;
        local dy = w.pos.y - landing.y;
        if (dx*dx + dy*dy < 100.0 && (w.expire - now) > 0.9)
        {
            dup = true;
            break;
        }
    }
    if (!dup)
    {
        ::g_ActiveSpits.append({ pos = landing, expire = now + 1.0 });
    }

    local hitCnt = ::DoImmediateAcidEvasion(landing, "spit_burst");
    if (::g_AcidDebug == 1)
        printl("[SpitDbg]   active=" + ::g_ActiveSpits.len());
};

::AcidEvasionTick <- function()
{
    if (::IsAcidDamageImmune()) return 1.0;
    if (("BotCore" in getroottable()) && ("IsStartupGraceActive" in ::BotCore)
        && ::BotCore.IsStartupGraceActive())
        return ::g_AcidCfg.TickInterval;

    local now = Time();

    // ---- (保留) 清理过期的 spit 警告 ----
    local liveSpits = [];
    foreach (s in ::g_ActiveSpits)
    {
        if (s.expire > now) liveSpits.append(s);
    }
    ::g_ActiveSpits = liveSpits;

    // ---- (保留) 收集 acid_pool 实体, 维护 g_SeenAcidPoolIdx + g_AcidPoolLifetime ----
    local acidPools = [];
    local seenThisTick = {};
    local ent = null;
    while (ent = Entities.FindByClassname(ent, "insect_swarm"))
    {
        if (!ent.IsValid()) continue;
        acidPools.append(ent);
        local idx = ent.GetEntityIndex();
        seenThisTick[idx] <- true;
        if (!(idx in ::g_SeenAcidPoolIdx))
        {
            ::g_SeenAcidPoolIdx[idx] <- true;
            local landing = ent.GetOrigin();
            ::g_AcidPoolLifetime[idx] <- { birth_t = now, pos = landing };
            local dup = false;
            foreach (w in ::g_ActiveSpits)
            {
                local ddx = w.pos.x - landing.x;
                local ddy = w.pos.y - landing.y;
                if (ddx*ddx + ddy*ddy < 100.0 && (w.expire - now) > 0.9) { dup = true; break; }
            }
            if (!dup)
                ::g_ActiveSpits.append({ pos = landing, expire = now + 1.0 });
            if (::g_AcidDebug == 1)
                printl("[SpitDbg] 新酸池检测 idx=\" + idx + \" landing=("
                    + landing.x.tointeger() + "," + landing.y.tointeger() + ")");
            // Do not issue the legacy single-pool immediate MOVE here. The
            // per-bot scoring below sees every nearby pool and the safe side.
        }
    }
    local stale = [];
    foreach (k, v in ::g_SeenAcidPoolIdx)
    {
        if (!(k in seenThisTick)) stale.append(k);
    }
    foreach (k in stale)
    {
        delete ::g_SeenAcidPoolIdx[k];
        if (k in ::g_AcidPoolLifetime) delete ::g_AcidPoolLifetime[k];
    }

    // ---- (保留) 收集 spitter 抛射物 ----
    local projectiles = [];
    local PROJ_CLASSNAMES = ["spitter_projectile", "_spit_projectile", "prop_spitter_projectile", "grenade_spit"];
    foreach (cn in PROJ_CLASSNAMES)
    {
        local pent = null;
        while (pent = Entities.FindByClassname(pent, cn))
        {
            if (pent.IsValid()) projectiles.append(pent);
        }
    }

    // 全局无危险 → 短返
    local forcedDamageActive = ::ABA_Spitter_HasForcedAcidDamage(now);
    if (acidPools.len() == 0 && projectiles.len() == 0 && ::g_ActiveSpits.len() == 0 && !forcedDamageActive)
    {
        ::ABA_Spitter_ClearAllBotAcidStates("no-acid-sources", true);
        return 0.5;
    }

    if (::g_AcidDebug == 1 && now > ::g_AcidTickLogCd)
    {
        printl("[SpitDbg][tick] sources: pools=" + acidPools.len()
            + " projectiles=" + projectiles.len()
            + " spit_warnings=" + ::g_ActiveSpits.len());
        ::g_AcidTickLogCd = now + 2.0;
    }

    // ---- C-full 阈值 ----
    local POOL_R2     = 230 * 230;   // pool triggers evasion inside this radius
    local POOL_SCORE_R2 = 460 * 460; // wider pool set used to score the 200u destination
    local PROJ_R2     = 350 * 350;   // proj 计入 hazard 半径
    local SPIT_R2     = 400 * 400;   // spit 警告计入半径
    local IN_POOL_R2  = 120 * 120;   // bot 已踩在池内
    local EVAC_DIST   = 200.0;       // 评分目标点距离
    local PRE_SAFE_HOLD_R2 = 150 * 150; // 预避酸已到安全位后, 允许优先守住当前位置
    local PRE_TARGET_NEAR_D2 = 120 * 120; // 预避酸时允许在接近目标后就视为已站稳安全点
    local VERTICAL_IGNORE_Z = 96.0;  // ignore acid warnings on a different floor
    local STUCK_TIME  = 2.0;         // 阶段 3 触发: 持续静止时长
    local STUCK_D2    = 30 * 30;     // 阶段 3 触发: 净位移阈值
    local TARGET_REACHED_D2 = 30 * 30;  // 视为已到目标
    local JUMP_CD     = 1.0;         // 阶段 3 ForceJump 节流
    local TICK_RET    = 0.5;         // tick 返回间隔 (旧 0.2s 抽搐元凶, 改 0.5s 给 MOVE 时间生效)

    local bot = null;
    while (bot = Entities.FindByClassname(bot, "player"))
    {
        if (!bot.IsValid()) continue;
        if (bot.GetClassname() != "player") continue;
        if (!bot.IsSurvivor()) continue;
        if (!IsPlayerABot(bot)) continue;
        try { if (NetProps.GetPropInt(bot, "m_lifeState") != 0) continue; } catch(e) { continue; }

        bot.ValidateScriptScope();
        local fs = bot.GetScriptScope();

        // Acid avoidance must yield to control/release animations and the
        // Charger weapon lockout.  Otherwise SafeCommandBot() may reject the
        // MOVE while this loop still records it as a successful evacuation.
        if (::ABA_Spitter_IsActionBusy(bot))
        {
            // Do not let time spent pinned, carried, staggering or using an
            // item accumulate as acid-navigation stall time. Without this,
            // recovery can fire immediately after the animation releases.
            local busyPos = bot.GetOrigin();
            if ("_acid_evac_active" in fs)
            {
                ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_origin", busyPos);
                ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_origin_t", now);
            }
            if ("_stuck_origin" in fs)
            {
                fs._stuck_origin = busyPos;
                fs._stuck_origin_t = now;
            }
            continue;
        }

        // A pool may disappear while control/healing owns the animation. The
        // earlier clear removes acid bookkeeping but deliberately defers cmd=3;
        // finish that release only after the shared busy/grace gate is clear.
        if ("_acid_clear_deferred" in fs)
            ::ABA_Spitter_ClearBotAcidState(bot, fs, "deferred-action-clear", true, 0.0);

        // ---- (保留) Tank evade 互锁 ----
        if (("_tank_evading" in fs) && fs._tank_evading)
        {
            if (::g_AcidDebug == 1)
            {
                local lt = ("_acid_tank_log_t" in fs) ? fs._acid_tank_log_t : 0.0;
                if (now - lt > 2.0)
                {
                    printl("[SpitDbg][tank-evade] bot=\" + bot.GetPlayerName() + \" tank evade 中, 本模块跳过");
                    fs._acid_tank_log_t <- now;
                }
            }
            continue;
        }

        // ---- (保留, 决定 1a) silence 互锁: DoStuckRecovery 后固定 3s ----
        if ("_acid_silenced_until" in fs && fs._acid_silenced_until > now)
        {
            if (::g_AcidDebug == 1)
            {
                local lt = ("_acid_silence_log_t" in fs) ? fs._acid_silence_log_t : 0.0;
                if (now - lt > 2.0)
                {
                    local remain = fs._acid_silenced_until - now;
                    printl("[SpitDbg][silenced] bot=" + bot.GetPlayerName()
                        + " 静默期剩 " + format("%.1f", remain) + "s, 本模块跳过");
                    fs._acid_silence_log_t <- now;
                }
            }
            continue;
        }

        local botPos = bot.GetOrigin();
        local botAreaDamaging = false;
        try
        {
            local botArea = bot.GetLastKnownArea();
            if (botArea != null && botArea.IsDamaging()) botAreaDamaging = true;
        }
        catch (eArea) {}

        // ---- 收集本 bot 周围的 hazard 中心 + pool 集合 (用于路径评分) ----
        local hazards = [];   // all nearby hazards used to score destinations
        local activeHazards = []; // unoccluded hazards that currently threaten this bot
        local poolIdxSet = {}; // 本 tick 该 bot 周围的 pool ent_idx (用于新 pool 检测)
        local nearestRawPoolD2 = 999999999.0;
        local actuallyInPool = false;
        local poolCnt = 0; local poolScoreCnt = 0; local projCnt = 0; local spitCnt = 0;

        foreach (acid in acidPools)
        {
            if (!acid.IsValid()) continue;
            local apos = acid.GetOrigin();
            local dz = apos.z - botPos.z;
            if (abs(dz) > VERTICAL_IGNORE_Z) continue;
            local dx = apos.x - botPos.x;
            local dy = apos.y - botPos.y;
            local d2 = dx*dx + dy*dy;
            if (d2 < POOL_SCORE_R2)
            {
                if (d2 < nearestRawPoolD2) nearestRawPoolD2 = d2;
                local poolHazard = { x = apos.x, y = apos.y, weight = 1.0 };
                hazards.append(poolHazard);
                poolIdxSet[acid.GetEntityIndex()] <- true;
                poolScoreCnt++;
                local openPoolLine = ::ABA_Spitter_HasOpenPoolLine(bot, botPos, apos);
                if (d2 < POOL_R2 && (openPoolLine || botAreaDamaging || d2 < IN_POOL_R2))
                {
                    activeHazards.append(poolHazard);
                    poolCnt++;
                    if (d2 < IN_POOL_R2) actuallyInPool = true;
                }
            }
        }
        foreach (proj in projectiles)
        {
            if (!proj.IsValid()) continue;
            local ppos = proj.GetOrigin();
            local pdz = ppos.z - botPos.z;
            if (abs(pdz) > VERTICAL_IGNORE_Z) continue;
            local dx = ppos.x - botPos.x;
            local dy = ppos.y - botPos.y;
            if (dx*dx + dy*dy < PROJ_R2)
            {
                local projHazard = { x = ppos.x, y = ppos.y, weight = 0.7 };
                hazards.append(projHazard);
                if (::ABA_Spitter_HasOpenPoolLine(bot, botPos, ppos) || botAreaDamaging)
                {
                    activeHazards.append(projHazard);
                    projCnt++;
                }
            }
        }
        foreach (spit in ::g_ActiveSpits)
        {
            local sdz = spit.pos.z - botPos.z;
            if (abs(sdz) > VERTICAL_IGNORE_Z) continue;
            local dx = spit.pos.x - botPos.x;
            local dy = spit.pos.y - botPos.y;
            if (dx*dx + dy*dy < SPIT_R2)
            {
                local spitHazard = { x = spit.pos.x, y = spit.pos.y, weight = 0.2 };
                hazards.append(spitHazard);
                if (::ABA_Spitter_HasOpenPoolLine(bot, botPos, spit.pos) || botAreaDamaging)
                {
                    activeHazards.append(spitHazard);
                    spitCnt++;
                }
            }
        }

        local forcedByDamage = false;
        if (("_acid_damage_forced_until" in fs) && fs._acid_damage_forced_until > now)
        {
            forcedByDamage = true;
            actuallyInPool = true;
            poolCnt++;

            local dmgPos = ("_acid_damage_pos" in fs) ? fs._acid_damage_pos : botPos;
            if (typeof dmgPos != "Vector")
                dmgPos = botPos;
            local damageHazard = { x = dmgPos.x, y = dmgPos.y, weight = 0.8 };
            hazards.append(damageHazard);
            activeHazards.append(damageHazard);

            local srcPos = ("_acid_damage_source_pos" in fs) ? fs._acid_damage_source_pos : null;
            if (srcPos != null && typeof srcPos == "Vector")
            {
                local sourceHazard = { x = srcPos.x, y = srcPos.y, weight = 1.2 };
                hazards.append(sourceHazard);
                activeHazards.append(sourceHazard);
            }

            if ("_acid_evac_pre_only" in fs)
                delete fs._acid_evac_pre_only;

            if (::g_AcidDebug == 1)
            {
                local dlog = ("_acid_damage_log_t" in fs) ? fs._acid_damage_log_t : 0.0;
                if ((now - dlog) > 1.2)
                {
                    printl("[SpitDbg][damage-forced] bot=" + bot.GetPlayerName()
                        + " active acid damage -> force evasion"
                        + " hazards=" + hazards.len());
                    fs._acid_damage_log_t <- now;
                }
            }
        }
        else
        {
            if ("_acid_damage_forced_until" in fs) delete fs._acid_damage_forced_until;
            if ("_acid_damage_pos" in fs) delete fs._acid_damage_pos;
            if ("_acid_damage_source_pos" in fs) delete fs._acid_damage_source_pos;
            if ("_acid_damage_rescore" in fs) delete fs._acid_damage_rescore;
            if ("_acid_damage_log_t" in fs) delete fs._acid_damage_log_t;
        }

        local count = poolCnt + projCnt + spitCnt;
        local trackedPoolAlive = false;
        if ("_acid_evac_pool_set" in fs)
        {
            foreach (trackedIdx, trackedValue in fs._acid_evac_pool_set)
            {
                if (trackedIdx in seenThisTick)
                {
                    trackedPoolAlive = true;
                    break;
                }
            }
        }
        // The warning target may have landed after the bot reached its safe
        // side, before the physical pool index was copied into its scope.
        if (!trackedPoolAlive && poolScoreCnt > 0 && ("_acid_evac_active" in fs))
            trackedPoolAlive = true;
        if (count > 0)
        {
            ::ABA_Spitter_ClearPostAcidWatch(fs);
            ::ABA_Spitter_PauseManualLead(bot, TICK_RET + 0.8);
        }

        // ============================================================
        // [阶段 2] hazard 集合空 → 清状态, 解除干预, L4B 接管
        // ============================================================
        if (count == 0)
        {
            if ("_acid_evac_active" in fs)
            {
                // Losing LOS or walking outside the 230u trigger radius does
                // not mean the separating pool is gone. Keep the bot on its
                // current safe side until the tracked insect_swarm disappears;
                // otherwise ABA follow logic can immediately route it back
                // through the live pool toward the human leader.
                if (trackedPoolAlive && nearestRawPoolD2 >= IN_POOL_R2)
                {
                    ::ABA_Spitter_PauseManualLead(bot, TICK_RET + 1.0);
                    local holdPos = Vector(botPos.x, botPos.y, botPos.z);
                    local enteringTrackedHold = !("_acid_evac_safe_hold" in fs) || !fs._acid_evac_safe_hold;
                    local lastTrackedHold = ("_acid_evac_safe_hold_cmd_t" in fs) ? fs._acid_evac_safe_hold_cmd_t : 0.0;
                    local movedFromTrackedHold = true;
                    if ("_acid_evac_safe_hold_origin" in fs)
                    {
                        local oldHold = fs._acid_evac_safe_hold_origin;
                        local holdDx = botPos.x - oldHold.x;
                        local holdDy = botPos.y - oldHold.y;
                        movedFromTrackedHold = (holdDx * holdDx + holdDy * holdDy) > 24.0 * 24.0;
                    }
                    if (enteringTrackedHold || (movedFromTrackedHold && (now - lastTrackedHold) > 0.75))
                    {
                        ::SafeCommandBot(1, bot, holdPos, null);
                        ::ABA_Spitter_SetScopeValue(fs, "_acid_last_move_t", now);
                        ::ABA_Spitter_SetScopeValue(fs, "_acid_last_move_target", holdPos);
                        ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_safe_hold_origin", holdPos);
                        ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_safe_hold_cmd_t", now);
                    }
                    ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_target", holdPos);
                    ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_target_t", now);
                    ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_pre_only", true);
                    ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_pre_hold_until", now + 0.9);
                    ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_origin", botPos);
                    ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_origin_t", now);
                    ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_safe_hold", true);
                    ::ABA_Spitter_SetScopeValue(fs, "_acid_safe_stationary_until", now + 1.25);
                    if (poolIdxSet.len() > 0)
                        ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_pool_set", clone poolIdxSet);
                    continue;
                }

                if (::g_AcidDebug == 1)
                    printl("[SpitDbg][stage2] bot=" + bot.GetPlayerName()
                        + " hazard 全消失 → 解除避酸状态 (L4B 接管)");
                ::ABA_Spitter_ClearBotAcidState(bot, fs, "stage2-clear", true, 0.0);
            }
            continue;
        }

        // ---- 计算 hazard 加权中心 (用于 stage3 ForceJump 反方向 + 死角 fallback) ----
        local hcx = 0.0; local hcy = 0.0; local wsum = 0.0;
        foreach (h in hazards)
        {
            hcx += h.x * h.weight;
            hcy += h.y * h.weight;
            wsum += h.weight;
        }
        if (wsum > 0.001)
        {
            hcx /= wsum;
            hcy /= wsum;
        }
        else { hcx = botPos.x; hcy = botPos.y; }
        local nearestHazardD2 = ::ABA_Spitter_GetNearestHazardD2(botPos, hazards);
        local nearestActiveHazardD2 = ::ABA_Spitter_GetNearestHazardD2(botPos, activeHazards);

        // ---- 检测新池: 之前在 evac 中, 但 pool 集合发生变化 (新 ent_idx 加入) → 重新评分 ----
        local newPoolDetected = false;
        if (("_acid_evac_active" in fs) && ("_acid_evac_pool_set" in fs))
        {
            foreach (k, v in poolIdxSet)
            {
                if (!(k in fs._acid_evac_pool_set)) { newPoolDetected = true; break; }
            }
        }

        // ---- 是否需要重新评分 (新进入 / 新池 / 已到目标 / 没目标) ----
        local needRescore = false;
        local hasTarget = ("_acid_evac_target" in fs);
        local reachedTarget = false;
        local nearPreTarget = false;
        local nearLastMoveTarget = false;
        if (hasTarget)
        {
            local t = fs._acid_evac_target;
            local tdx = t.x - botPos.x;
            local tdy = t.y - botPos.y;
            local td2 = tdx*tdx + tdy*tdy;
            if (td2 < TARGET_REACHED_D2) reachedTarget = true;
            if (td2 < PRE_TARGET_NEAR_D2) nearPreTarget = true;
        }
        if ("_acid_last_move_target" in fs)
        {
            local lt = fs._acid_last_move_target;
            if (typeof lt == "Vector")
            {
                local ldx = lt.x - botPos.x;
                local ldy = lt.y - botPos.y;
                if (ldx*ldx + ldy*ldy < PRE_TARGET_NEAR_D2)
                    nearLastMoveTarget = true;
            }
        }
        local preOnlyActive = (("_acid_evac_pre_only" in fs) && fs._acid_evac_pre_only);
        local preWarningSafe = (preOnlyActive
            && !forcedByDamage
            && !actuallyInPool
            && ::ABA_Spitter_PointClearOfHazards(botPos, activeHazards, 145.0)
            && nearestActiveHazardD2 >= PRE_SAFE_HOLD_R2);
        local prePoolSafeLock = (preOnlyActive
            && !forcedByDamage
            && !actuallyInPool
            && ::ABA_Spitter_PointClearOfHazards(botPos, activeHazards, 95.0)
            && nearestActiveHazardD2 >= 105.0 * 105.0);
        local preTargetSettled = reachedTarget || nearPreTarget || nearLastMoveTarget;
        local preHoldWindowActive = (("_acid_evac_pre_hold_until" in fs) && fs._acid_evac_pre_hold_until > now);

        local onlyPreWarning = (poolCnt == 0 && projCnt == 0 && spitCnt > 0);
        if (onlyPreWarning && ::ABA_Spitter_HasCriticalHuman())
        {
            if ("_acid_evac_active" in fs)
                ::ABA_Spitter_ClearBotAcidState(bot, fs, "critical-human-during-pre-acid", true, 0.6);
            continue;
        }

        local currentBasicSafe = (!forcedByDamage
            && !actuallyInPool
            && !botAreaDamaging
            && ::ABA_Spitter_PointClearOfHazards(botPos, activeHazards, 90.0));
        if (currentBasicSafe)
            ::ABA_Spitter_SetScopeValue(fs, "_acid_safe_stationary_until", now + 1.25);
        else if ("_acid_safe_stationary_until" in fs)
            delete fs._acid_safe_stationary_until;
        local currentStrongSafe = (currentBasicSafe
            && ::ABA_Spitter_PointClearOfHazards(botPos, activeHazards, 145.0)
            && nearestActiveHazardD2 >= PRE_SAFE_HOLD_R2);
        local safeHumanAnchor = false;
        if (currentBasicSafe && poolCnt > 0)
            safeHumanAnchor = ::ABA_Spitter_HasSafeHumanAnchor(bot, botPos, activeHazards, 240.0);

        local safeCornerLock = false;
        if (currentBasicSafe && ("_acid_evac_active" in fs)
            && ("_acid_evac_origin" in fs) && ("_acid_evac_origin_t" in fs))
        {
            local cornerElapsed = now - fs._acid_evac_origin_t;
            local cdx = botPos.x - fs._acid_evac_origin.x;
            local cdy = botPos.y - fs._acid_evac_origin.y;
            if (cornerElapsed >= 0.8 && cdx * cdx + cdy * cdy < 32.0 * 32.0)
            {
                local ax = botPos.x - hcx;
                local ay = botPos.y - hcy;
                local al = sqrt(ax * ax + ay * ay);
                if (al > 1.0)
                {
                    ax /= al; ay /= al;
                    local c45 = 0.70710678;
                    local f0 = ::IsAcidTargetReachable(bot, botPos, ax, ay);
                    local fl = ::IsAcidTargetReachable(bot, botPos, ax * c45 - ay * c45, ax * c45 + ay * c45);
                    local fr = ::IsAcidTargetReachable(bot, botPos, ax * c45 + ay * c45, -ax * c45 + ay * c45);
                    local bestAwayFrac = f0;
                    if (fl > bestAwayFrac) bestAwayFrac = fl;
                    if (fr > bestAwayFrac) bestAwayFrac = fr;
                    safeCornerLock = (bestAwayFrac < 0.7);
                }
            }
        }

        local safeSideLock = ((currentStrongSafe && (preTargetSettled || preHoldWindowActive))
            || (currentBasicSafe && safeHumanAnchor)
            || safeCornerLock);

        if (safeSideLock)
        {
            local enteringSafeHold = !("_acid_evac_safe_hold" in fs) || !fs._acid_evac_safe_hold;
            local reissueSafeHold = enteringSafeHold;
            if (!reissueSafeHold && ("_acid_evac_safe_hold_origin" in fs))
            {
                local hp = fs._acid_evac_safe_hold_origin;
                local hdx = botPos.x - hp.x;
                local hdy = botPos.y - hp.y;
                local lastHoldCmd = ("_acid_evac_safe_hold_cmd_t" in fs) ? fs._acid_evac_safe_hold_cmd_t : 0.0;
                reissueSafeHold = (hdx * hdx + hdy * hdy > 24.0 * 24.0 && (now - lastHoldCmd) > 0.75);
            }

            local holdPos = Vector(botPos.x, botPos.y, botPos.z);
            if (reissueSafeHold)
            {
                ::SafeCommandBot(1, bot, holdPos, null);
                ::ABA_Spitter_SetScopeValue(fs, "_acid_last_move_t", now);
                ::ABA_Spitter_SetScopeValue(fs, "_acid_last_move_target", holdPos);
                ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_safe_hold_origin", holdPos);
                ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_safe_hold_cmd_t", now);
            }

            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_active", true);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_target", holdPos);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_target_t", now);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_pre_only", true);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_pre_hold_until", now + 0.9);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_origin", botPos);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_origin_t", now);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_pool_set", clone poolIdxSet);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_safe_hold", true);

            if (::g_AcidDebug == 1 && enteringSafeHold)
            {
                printl("[SpitDbg][safe-side-lock] bot=" + bot.GetPlayerName()
                    + " nearest=" + sqrt(nearestActiveHazardD2).tointeger()
                    + " pools=" + poolCnt + "/" + poolScoreCnt
                    + " human_anchor=" + (safeHumanAnchor ? "1" : "0")
                    + " corner=" + (safeCornerLock ? "1" : "0"));
            }
            continue;
        }

        if ("_acid_evac_safe_hold" in fs) delete fs._acid_evac_safe_hold;
        if ("_acid_evac_safe_hold_origin" in fs) delete fs._acid_evac_safe_hold_origin;
        if ("_acid_evac_safe_hold_cmd_t" in fs) delete fs._acid_evac_safe_hold_cmd_t;

        if (onlyPreWarning && ("_acid_evac_active" in fs))
        {
            if (preWarningSafe || preTargetSettled || preHoldWindowActive)
            {
                fs._acid_evac_pre_only <- true;
                fs._acid_evac_pre_hold_until <- now + 0.8;
                fs._acid_evac_origin = botPos;
                fs._acid_evac_origin_t = now;
                continue;
            }
        }

        if (onlyPreWarning && preWarningSafe && (preTargetSettled || preHoldWindowActive))
        {
            local holdPos = Vector(botPos.x, botPos.y, botPos.z);
            local lastMoveT = ("_acid_last_move_t" in fs) ? fs._acid_last_move_t : 0.0;
            if ((now - lastMoveT) > 0.6)
            {
                ::SafeCommandBot(1, bot, holdPos, null);
                fs._acid_last_move_t <- now;
                fs._acid_last_move_target <- holdPos;
            }
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_target", holdPos);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_target_t", now);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_pre_only", true);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_pre_hold_until", now + 0.8);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_origin", botPos);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_origin_t", now);
            if (::g_AcidDebug == 1)
            {
                local lt = ("_acid_evac_log_t" in fs) ? fs._acid_evac_log_t : 0.0;
                if ((now - lt) > 1.0)
                {
                    printl("[SpitDbg][pre-hold] bot=" + bot.GetPlayerName()
                        + " pre-evasion already clear -> hold safe point nearest="
                        + sqrt(nearestHazardD2).tointeger()
                        + " near_target=" + (nearPreTarget ? "1" : "0")
                        + " near_last=" + (nearLastMoveTarget ? "1" : "0"));
                    fs._acid_evac_log_t <- now;
                }
            }
            continue;
        }

        if (!onlyPreWarning && prePoolSafeLock && (preTargetSettled || preHoldWindowActive))
        {
            local holdPos = Vector(botPos.x, botPos.y, botPos.z);
            local lastMoveT = ("_acid_last_move_t" in fs) ? fs._acid_last_move_t : 0.0;
            if ((now - lastMoveT) > 0.6)
            {
                ::SafeCommandBot(1, bot, holdPos, null);
                fs._acid_last_move_t <- now;
                fs._acid_last_move_target <- holdPos;
            }
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_target", holdPos);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_target_t", now);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_pre_only", true);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_pre_hold_until", now + 0.65);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_origin", botPos);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_origin_t", now);
            if (::g_AcidDebug == 1)
            {
                local lt = ("_acid_evac_log_t" in fs) ? fs._acid_evac_log_t : 0.0;
                if ((now - lt) > 1.0)
                {
                    printl("[SpitDbg][pre-safe-lock] bot=" + bot.GetPlayerName()
                        + " landed pool but current side still safe -> hold nearest="
                        + sqrt(nearestHazardD2).tointeger()
                        + " pools=" + poolCnt);
                    fs._acid_evac_log_t <- now;
                }
            }
            continue;
        }

        if (!("_acid_evac_active" in fs)) needRescore = true;
        else if (newPoolDetected) needRescore = true;
        else if (!hasTarget) needRescore = true;
        else if (reachedTarget) needRescore = true;
        else if (forcedByDamage && ("_acid_damage_rescore" in fs)) needRescore = true;

        // ============================================================
        // [阶段 1] 路径评分: 16 方向打分, 取最佳 → 一次 MOVE
        // ============================================================
        if (needRescore)
        {
            local PI = 3.14159265;
            // D: 8 方向 (每 45°) → 16 方向 (每 22.5°), 提升找到狭窄通道 (门框) 的概率
            local angles = [0.0, 22.5, 45.0, 67.5, 90.0, 112.5, 135.0, 157.5,
                            180.0, 202.5, 225.0, 247.5, 270.0, 292.5, 315.0, 337.5];
            local distanceOptions = [110.0, 155.0, 200.0, 260.0];
            local bestScore = -999999;
            local bestNx = 0.0; local bestNy = 0.0;
            local bestDist = EVAC_DIST;
            local secondBestScore = -999999;
            local secondBestNx = 0.0; local secondBestNy = 0.0;
            local secondBestDist = EVAC_DIST;

            // L1: 找最近 human leader (没有则 fallback 任意活着的 survivor),
            // 评分阶段对"朝向 leader"方向加 bonus, 解决"bot↔leader 之间夹酸液时
            // bot 评分选 away-from-hazard 方向 = 朝远离 leader 方向走 = 回踩酸液场景".
            // bonus = dot * 200 (是 away-from-hazard 的 100 的 2x), 让朝 leader 优先,
            // 但仍弱于 hazard 穿心 -800, 所以 bot 不会直接闯酸液, 而是绕路朝 leader.
            local leaderForScore = null;
            {
                local nearestHd2 = 999999999.0;
                local nearestSd2 = 999999999.0;
                local nearestS = null;
                local p = null;
                while (p = Entities.FindByClassname(p, "player"))
                {
                    if (p == bot) continue;
                    if (!p.IsValid()) continue;
                    if (!p.IsSurvivor()) continue;
                    try { if (NetProps.GetPropInt(p, "m_lifeState") != 0) continue; } catch(e) { continue; }
                    local pp = p.GetOrigin();
                    local ldx = pp.x - botPos.x;
                    local ldy = pp.y - botPos.y;
                    local ld2 = ldx*ldx + ldy*ldy;
                    if (!IsPlayerABot(p))
                    {
                        if (ld2 < nearestHd2) { leaderForScore = p; nearestHd2 = ld2; }
                    }
                    else
                    {
                        if (ld2 < nearestSd2) { nearestS = p; nearestSd2 = ld2; }
                    }
                }
                if (leaderForScore == null) leaderForScore = nearestS;
            }
            local toLeaderX = 0.0; local toLeaderY = 0.0;
            local hasLeader = false;
            if (leaderForScore != null && leaderForScore.IsValid())
            {
                local lpos = leaderForScore.GetOrigin();
                local ldx = lpos.x - botPos.x;
                local ldy = lpos.y - botPos.y;
                local llen = sqrt(ldx*ldx + ldy*ldy);
                if (llen > 1.0) { toLeaderX = ldx/llen; toLeaderY = ldy/llen; hasLeader = true; }
            }

            // Door awareness is only a tie-breaker. Endpoint acid clearance still wins.
            local doorDirs = [];
            {
                local d = null;
                while (d = Entities.FindByClassnameWithin(d, "prop_door_rotating", botPos, 256.0))
                {
                    if (!d.IsValid()) continue;
                    local dp = d.GetOrigin();
                    local ddz = dp.z - botPos.z;
                    if (ddz > 100.0 || ddz < -100.0) continue;
                    local ddx = dp.x - botPos.x;
                    local ddy = dp.y - botPos.y;
                    local dlen = sqrt(ddx*ddx + ddy*ddy);
                    if (dlen < 1.0) continue;
                    doorDirs.append({ nx = ddx/dlen, ny = ddy/dlen });
                }
            }

            // P3b: 收集所有方向评分分解 (用于诊断)
            local _scoreDetails = [];
            local preserveSafeSpacing = (!actuallyInPool
                && nearestActiveHazardD2 >= PRE_SAFE_HOLD_R2
                && (preOnlyActive || reachedTarget || nearPreTarget || nearLastMoveTarget));
            local urgentEscape = (actuallyInPool || forcedByDamage || nearestActiveHazardD2 < PRE_SAFE_HOLD_R2);
            local retryPenaltyActive = false;
            local retryPrevDirX = 0.0;
            local retryPrevDirY = 0.0;
            local previousEvacTarget = null;
            if (("_acid_evac_prev_target" in fs) && typeof fs._acid_evac_prev_target == "Vector")
                previousEvacTarget = fs._acid_evac_prev_target;
            if (("_acid_evac_origin" in fs) && ("_acid_evac_origin_t" in fs)
                && ("_acid_evac_best_nx" in fs) && ("_acid_evac_best_ny" in fs))
            {
                local rox = botPos.x - fs._acid_evac_origin.x;
                local roy = botPos.y - fs._acid_evac_origin.y;
                local retryElapsed = now - fs._acid_evac_origin_t;
                local retryDist2 = rox * rox + roy * roy;
                local retryLen = sqrt(fs._acid_evac_best_nx * fs._acid_evac_best_nx + fs._acid_evac_best_ny * fs._acid_evac_best_ny);
                if (retryLen > 0.1)
                {
                    retryPrevDirX = fs._acid_evac_best_nx / retryLen;
                    retryPrevDirY = fs._acid_evac_best_ny / retryLen;
                    retryPenaltyActive = (retryElapsed >= 0.65
                        && retryDist2 < 28.0 * 28.0
                        && (forcedByDamage || actuallyInPool || poolScoreCnt >= 2));
                }
            }

            foreach (angDeg in angles)
            {
                local rad = angDeg * PI / 180.0;
                local nx = cos(rad);
                local ny = sin(rad);
                local s = 0;
                // P3b: 分项追踪
                local _sHazard = 0;
                local _sCliff = 0;
                local _sWall = 0;
                local _sAway = 0;
                local _sLeader = 0;
                local _sDoor = 0;
                local _sSafe = 0;
                local _sExit = 0;
                local _sEndpoint = 0;
                local _sRetry = 0;
                local _sOscillation = 0;

                local candidateDist = EVAC_DIST;
                local distanceChoiceScore = -999999.0;
                foreach (testDist in distanceOptions)
                {
                    local testPos = Vector(botPos.x + nx * testDist, botPos.y + ny * testDist, botPos.z);
                    local testHazardD2 = ::ABA_Spitter_GetNearestHazardD2(testPos, hazards);
                    local testClear = ::ABA_Spitter_PointClearOfHazards(testPos, hazards, 145.0);
                    local testClearance = sqrt(testHazardD2);
                    if (testClearance > 220.0) testClearance = 220.0;
                    local testScore = testClearance * 3.0 - testDist * 0.7;
                    if (testClear) testScore += 1000.0;
                    if (actuallyInPool && testDist < 150.0) testScore -= 300.0;
                    if (currentStrongSafe && testHazardD2 + (35 * 35) < nearestHazardD2) testScore -= 800.0;
                    if (testScore > distanceChoiceScore)
                    {
                        distanceChoiceScore = testScore;
                        candidateDist = testDist;
                    }
                }

                // hazard 穿心 / 擦边惩罚
                foreach (h in hazards)
                {
                    local hdx = h.x - botPos.x;
                    local hdy = h.y - botPos.y;
                    local along = hdx * nx + hdy * ny;
                    local lateral = hdx * (-ny) + hdy * nx;
                    if (lateral < 0) lateral = -lateral;
                    if (along > 0 && along < candidateDist + 50.0)
                    {
                        if (lateral < 80.0)
                        {
                            local pen = (800.0 * h.weight).tointeger();
                            s -= pen; _sHazard -= pen;
                        }
                        else if (lateral < 200.0)
                        {
                            local pen = (200.0 * h.weight).tointeger();
                            s -= pen; _sHazard -= pen;
                        }
                    }
                }

                // 悬崖惩罚
                local _isCliff = !::IsAcidTargetSafe(botPos, nx, ny, candidateDist);
                if (_isCliff)
                {
                    s -= 500; _sCliff = -500;
                }

                // 短程墙惩罚
                local frac = ::IsAcidTargetReachable(bot, botPos, nx, ny);
                if (frac < 0.7)
                {
                    local pen = ((0.7 - frac) * 1000.0).tointeger();
                    s -= pen; _sWall = -pen;
                }

                local targetPos = Vector(botPos.x + nx * candidateDist, botPos.y + ny * candidateDist, botPos.z);
                local targetHazardD2 = ::ABA_Spitter_GetNearestHazardD2(targetPos, hazards);
                local targetClear = ::ABA_Spitter_PointClearOfHazards(targetPos, hazards, 145.0);
                local clearanceDelta = targetHazardD2 - nearestHazardD2;

                if (!targetClear)
                {
                    local endpointPen = 1000;
                    if (poolScoreCnt >= 2) endpointPen += 550;
                    if (currentStrongSafe) endpointPen += 650;
                    s -= endpointPen; _sEndpoint -= endpointPen;
                }

                if (currentStrongSafe && targetHazardD2 + (35 * 35) < nearestHazardD2)
                {
                    s -= 1100; _sEndpoint -= 1100;
                }
                else if (poolScoreCnt >= 2)
                {
                    local multiPoolScore = (clearanceDelta / 100.0).tointeger();
                    if (multiPoolScore > 450) multiPoolScore = 450;
                    if (multiPoolScore < -500) multiPoolScore = -500;
                    s += multiPoolScore; _sEndpoint += multiPoolScore;
                }

                if (poolScoreCnt >= 2 && previousEvacTarget != null)
                {
                    local pdx = targetPos.x - previousEvacTarget.x;
                    local pdy = targetPos.y - previousEvacTarget.y;
                    if (pdx * pdx + pdy * pdy < 130.0 * 130.0
                        && targetHazardD2 < nearestHazardD2 + (60 * 60))
                    {
                        s -= 900; _sOscillation = -900;
                    }
                }

                // bonus: 朝远离 hazard 中心方向
                local awayX = botPos.x - hcx;
                local awayY = botPos.y - hcy;
                local alen = sqrt(awayX*awayX + awayY*awayY);
                if (alen > 1.0)
                {
                    local dot = (awayX/alen) * nx + (awayY/alen) * ny;
                    local bonus = (dot * 100.0).tointeger();
                    s += bonus; _sAway = bonus;
                }

                // L1: bonus 朝向 leader (覆盖 away-from-hazard, 让 bot 绕酸液朝 leader 走)
                if (hasLeader)
                {
                    local ldot = toLeaderX * nx + toLeaderY * ny;
                    local leaderScale = urgentEscape ? 0.35 : 1.0;
                    local bonus = (ldot * 200.0 * leaderScale).tointeger();
                    s += bonus; _sLeader = bonus;
                }

                // Door directions get only a small tie-break bonus, and only when
                // the destination preserves the current minimum acid clearance.
                foreach (dd in doorDirs)
                {
                    local ddot = dd.nx * nx + dd.ny * ny;
                    if (ddot > 0.95)
                    {
                        local doorClearanceOK = targetClear
                            && (targetHazardD2 >= nearestHazardD2 - (20 * 20) || !currentStrongSafe);
                        if (doorClearanceOK)
                        {
                            local doorBonus = urgentEscape ? 260 : 240;
                            s += doorBonus; _sDoor = doorBonus;
                        }
                        break;
                    }
                }

                if (urgentEscape)
                {
                    local deltaHazard = targetHazardD2 - nearestHazardD2;
                    local exitDivisor = (poolScoreCnt >= 2) ? 80.0 : 140.0;
                    local exitScore = (deltaHazard / exitDivisor).tointeger();
                    if (exitScore > 320) exitScore = 320;
                    if (exitScore < -650) exitScore = -650;
                    s += exitScore; _sExit = exitScore;

                    if (targetHazardD2 + (35 * 35) < nearestHazardD2)
                    {
                        s -= 520; _sExit -= 520;
                    }
                    else if (targetHazardD2 < nearestHazardD2 + (40 * 40))
                    {
                        s -= 180; _sExit -= 180;
                    }
                }

                if (preserveSafeSpacing)
                {
                    local safeMargin = ((preOnlyActive && poolCnt > 0) ? (35 * 35) : (70 * 70));
                    if (targetHazardD2 + safeMargin < nearestHazardD2)
                    {
                        local pen = (targetHazardD2 < IN_POOL_R2) ? 1200 : ((preOnlyActive && poolCnt > 0) ? 900 : 450);
                        s -= pen; _sSafe = -pen;
                    }
                }

                if (retryPenaltyActive)
                {
                    local retryDot = retryPrevDirX * nx + retryPrevDirY * ny;
                    if (retryDot > 0.94)
                    {
                        local retryPen = 650;
                        if (_sDoor > 0)
                            retryPen += urgentEscape ? 280 : 520;
                        if (frac < 0.82)
                            retryPen += 260;
                        if (targetHazardD2 >= nearestHazardD2 - (25 * 25))
                            retryPen += 220;
                        s -= retryPen; _sRetry = -retryPen;
                    }
                }

                // P3b: 记录分解
                _scoreDetails.append({
                    ang = angDeg, s = s, nx = nx, ny = ny, dist = candidateDist,
                    hz = _sHazard, cl = _sCliff, wl = _sWall,
                    aw = _sAway, ld = _sLeader, dr = _sDoor, sf = _sSafe,
                    ex = _sExit, ep = _sEndpoint, rt = _sRetry, os = _sOscillation,
                    cliff = _isCliff, frac = frac
                });

                // 选最佳 + 次佳 (死角 fallback 用次佳)
                if (s > bestScore)
                {
                    secondBestScore = bestScore;
                    secondBestNx = bestNx; secondBestNy = bestNy;
                    secondBestDist = bestDist;
                    bestScore = s; bestNx = nx; bestNy = ny;
                    bestDist = candidateDist;
                }
                else if (s > secondBestScore)
                {
                    secondBestScore = s; secondBestNx = nx; secondBestNy = ny;
                    secondBestDist = candidateDist;
                }
            }

            // 死角覆盖: 即便最佳分数 < -300 (穿心+悬崖) 也照走 — 用户要求
            // ("酸液吐到墙角死角时, 即便脱险路径要穿过酸液中心, 也得走")
            local tx = botPos.x + bestNx * bestDist;
            local ty = botPos.y + bestNy * bestDist;
            local tz = botPos.z;

            ::SafeCommandBot(1, bot, Vector(tx, ty, tz), null);

            fs._acid_evac_active <- true;
            fs._acid_evac_target <- Vector(tx, ty, tz);
            fs._acid_evac_target_t <- now;
            fs._acid_evac_origin <- botPos;
            fs._acid_evac_origin_t <- now;
            fs._acid_evac_pool_set <- clone poolIdxSet;
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_last_best_score", bestScore);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_best_nx", bestNx);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_best_ny", bestNy);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_best_dist", bestDist);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_second_nx", secondBestNx);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_second_ny", secondBestNy);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_second_score", secondBestScore);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_second_dist", secondBestDist);
            ::ABA_Spitter_SetScopeValue(fs, "_acid_stage3_n", 0);
            if ("_acid_damage_rescore" in fs)
                delete fs._acid_damage_rescore;
            if (onlyPreWarning)
                fs._acid_evac_pre_only <- true;
            else if ("_acid_evac_pre_only" in fs)
                delete fs._acid_evac_pre_only;
            if ("_acid_evac_pre_hold_until" in fs)
                delete fs._acid_evac_pre_hold_until;
            // _acid_last_move_* 给 DoImmediateAcidEvasion 节流参考用
            if (("_acid_last_move_target" in fs) && typeof fs._acid_last_move_target == "Vector")
                ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_prev_target", fs._acid_last_move_target);
            fs._acid_last_move_t <- now;
            fs._acid_last_move_target <- Vector(tx, ty, tz);

            if (::g_AcidDebug == 1)
            {
                local reason = "首次进入";
                if (newPoolDetected) reason = "新池加入";
                else if (reachedTarget) reason = "已到目标 + pool 仍在";
                else if (!hasTarget) reason = "无目标";
                printl("[SpitDbg][stage1] bot=" + bot.GetPlayerName()
                    + " " + reason + " → 16 方向评分, 最佳=" + bestScore
                    + " dir(" + format("%.2f", bestNx) + "," + format("%.2f", bestNy) + ")"
                    + " dist=" + bestDist.tointeger()
                    + " → MOVE (" + tx.tointeger() + "," + ty.tointeger() + ")"
                    + " hazards=" + hazards.len() + " (pool=" + poolCnt + "/" + poolScoreCnt
                    + " proj=" + projCnt + " spit=" + spitCnt + ")"
                    + (bestScore < -300 ? " [死角覆盖]" : ""));
                // P3b: 输出 top-3 方向的分项分解 + 所有崖方向
                _scoreDetails.sort(function(a,b) { return (b.s - a.s) > 0 ? 1 : (b.s - a.s) < 0 ? -1 : 0; });
                local topN = (_scoreDetails.len() < 3) ? _scoreDetails.len() : 3;
                for (local _i = 0; _i < topN; _i++)
                {
                    local _d = _scoreDetails[_i];
                    printl("[SpitDbg][P3b-rank" + (_i+1) + "] " + _d.ang + "° d=" + _d.dist + " s=" + _d.s
                        + " hz=" + _d.hz + " cl=" + _d.cl + " wl=" + _d.wl
                        + " aw=" + _d.aw + " ld=" + _d.ld + " dr=" + _d.dr + " sf=" + _d.sf
                        + " ex=" + _d.ex + " ep=" + _d.ep + " rt=" + _d.rt + " os=" + _d.os
                        + " cliff=" + (_d.cliff ? "Y" : "N") + " frac=" + format("%.2f", _d.frac));
                }
                // P3b: 如果 bestScore 方向无崖但附近有崖方向, 列出所有崖方向 (帮助分析挂边原因)
                local cliffDirs = "";
                local cliffCnt = 0;
                foreach (_d in _scoreDetails)
                {
                    if (_d.cliff)
                    {
                        cliffDirs += " " + _d.ang + "°";
                        cliffCnt++;
                    }
                }
                if (cliffCnt > 0)
                    printl("[SpitDbg][P3b-cliffs] " + cliffCnt + " 个崖方向:" + cliffDirs
                        + " bot pos=(" + botPos.x.tointeger() + "," + botPos.y.tointeger() + "," + botPos.z.tointeger() + ")");
            }

            // S-G: 卡门兜底跳 — 评分极低 (<50) 且 hazard ≥2 (穿墙穿酸两难) 且 有 leader,
            // 立刻 ForceBotEscapeJump 朝 leader 方向, 不等 2s stuck.
            // 共用 _acid_evac_jump_t 冷却 (JUMP_CD).
            if (bestScore < 50 && hazards.len() >= 2 && hasLeader && ("ForceBotEscapeJump" in getroottable()))
            {
                local lastJ = ("_acid_evac_jump_t" in fs) ? fs._acid_evac_jump_t : 0.0;
                if ((now - lastJ) >= JUMP_CD)
                {
                    ::ForceBotEscapeJump(bot, toLeaderX, toLeaderY);
                    fs._acid_evac_jump_t <- now;
                    if (::g_AcidDebug == 1)
                    {
                        printl("[SpitDbg][stage1+SG] bot=" + bot.GetPlayerName()
                            + " 评分 " + bestScore + "<50 + hazards=" + hazards.len()
                            + " → 立即 ForceBotEscapeJump 朝 leader dir("
                            + format("%.2f", toLeaderX) + "," + format("%.2f", toLeaderY) + ")");
                    }
                }
            }
            continue;
        }

        // ============================================================
        // [阶段 1 继续 → 阶段 3] 已有目标, 检查是否卡死
        // ============================================================
        if (forcedByDamage && ("_acid_evac_target" in fs))
        {
            local lastReissue = ("_acid_damage_reissue_t" in fs) ? fs._acid_damage_reissue_t : 0.0;
            if ((now - lastReissue) > 0.75)
            {
                ::SafeCommandBot(1, bot, fs._acid_evac_target, null);
                fs._acid_damage_reissue_t <- now;
            }
        }

        local elapsed = now - fs._acid_evac_origin_t;
        local stuckTimeNow = forcedByDamage ? 1.0 : STUCK_TIME;
        if (elapsed >= stuckTimeNow)
        {
            local odx = botPos.x - fs._acid_evac_origin.x;
            local ody = botPos.y - fs._acid_evac_origin.y;
            local od2 = odx*odx + ody*ody;
            if (od2 < STUCK_D2)
            {
                if ((("_acid_evac_pre_only" in fs) && fs._acid_evac_pre_only)
                    || (!actuallyInPool && poolCnt < 1 && !trackedPoolAlive))
                {
                    ::ABA_Spitter_ClearBotAcidState(bot, fs, "stuck-away-from-acid", true, 1.0);
                    continue;
                }

                // ---- 阶段 3: 卡死 → ForceBotEscapeJump 沿 hazard 反方向 ----
                local lastJ = ("_acid_evac_jump_t" in fs) ? fs._acid_evac_jump_t : 0.0;
                if ((now - lastJ) >= JUMP_CD && ("ForceBotEscapeJump" in getroottable()))
                {
                    local awayX = botPos.x - hcx;
                    local awayY = botPos.y - hcy;
                    local alen = sqrt(awayX*awayX + awayY*awayY);
                    local jnx = 1.0; local jny = 0.0;
                    if (alen > 1.0) { jnx = awayX / alen; jny = awayY / alen; }

                    // R2': 死角窄地形检测 — stage1 最佳分数 < -300 说明 8 方向皆穿酸/堕崖,
                    // 水平推力只会把 bot 推过崖. 改为垂直 ForceJump (横向归零, 仅 vz=290)
                    // 尝试上跳到更高的 nav, 让 L4B 重新规划.
                    local stage3N = ("_acid_stage3_n" in fs) ? fs._acid_stage3_n + 1 : 1;
                    ::ABA_Spitter_SetScopeValue(fs, "_acid_stage3_n", stage3N);

                    local lastBest = ("_acid_evac_last_best_score" in fs) ? fs._acid_evac_last_best_score : 0;
                    local verticalOnly = (lastBest < -300);
                    local bestDirX = ("_acid_evac_best_nx" in fs) ? fs._acid_evac_best_nx : jnx;
                    local bestDirY = ("_acid_evac_best_ny" in fs) ? fs._acid_evac_best_ny : jny;
                    local bestMoveDist = ("_acid_evac_best_dist" in fs) ? fs._acid_evac_best_dist : EVAC_DIST;
                    local bestLen = sqrt(bestDirX * bestDirX + bestDirY * bestDirY);
                    if (bestLen < 0.1) { bestDirX = jnx; bestDirY = jny; bestLen = 1.0; }
                    bestDirX = bestDirX / bestLen;
                    bestDirY = bestDirY / bestLen;

                    local secondDirX = ("_acid_evac_second_nx" in fs) ? fs._acid_evac_second_nx : 0.0;
                    local secondDirY = ("_acid_evac_second_ny" in fs) ? fs._acid_evac_second_ny : 0.0;
                    local secondScore = ("_acid_evac_second_score" in fs) ? fs._acid_evac_second_score : -999999;
                    local secondMoveDist = ("_acid_evac_second_dist" in fs) ? fs._acid_evac_second_dist : EVAC_DIST;
                    local secondLen = sqrt(secondDirX * secondDirX + secondDirY * secondDirY);
                    local probe = ::ABA_Spitter_ProbeJumpObstacle(bot, botPos, bestDirX, bestDirY);
                    local action = "away-jump";
                    local usedExtendedFallback = false;

                    if (probe.lowBlocked && probe.highClear && stage3N <= 2)
                    {
                        local lowTarget = Vector(botPos.x + bestDirX * bestMoveDist, botPos.y + bestDirY * bestMoveDist, botPos.z);
                        ::SafeCommandBot(1, bot, lowTarget, null);
                        ::ForceBotEscapeJump(bot, bestDirX, bestDirY);
                        ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_target", lowTarget);
                        action = "low-obstacle-jump";
                        usedExtendedFallback = true;
                    }

                    if (!usedExtendedFallback)
                    {
                        local highTarget = ::ABA_Spitter_FindHighEscapeTarget(bot, botPos, hazards);
                        if (highTarget != null)
                        {
                            ::ABA_Spitter_MoveAndJump(bot, highTarget);
                            ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_target", highTarget);
                            action = "high-safe-jump";
                            usedExtendedFallback = true;
                        }
                    }

                    if (!usedExtendedFallback && secondLen > 0.1 && secondScore > -999000)
                    {
                        secondDirX = secondDirX / secondLen;
                        secondDirY = secondDirY / secondLen;
                        local secondTarget = Vector(botPos.x + secondDirX * secondMoveDist, botPos.y + secondDirY * secondMoveDist, botPos.z);
                        ::SafeCommandBot(1, bot, secondTarget, null);
                        ::ForceBotEscapeJump(bot, secondDirX, secondDirY);
                        ::ABA_Spitter_SetScopeValue(fs, "_acid_evac_target", secondTarget);
                        action = "second-best-jump";
                        usedExtendedFallback = true;
                    }

                    if (!usedExtendedFallback && verticalOnly)
                    {
                        ::ForceBotEscapeJump(bot, 0.0, 0.0);
                        action = "vertical-jump";
                    }
                    else if (!usedExtendedFallback)
                    {
                        ::ForceBotEscapeJump(bot, jnx, jny);
                        action = "away-jump";
                    }
                    fs._acid_evac_jump_t <- now;
                    // 重置 origin, 让阶段 1 下个 tick 重新评分
                    fs._acid_evac_origin = botPos;
                    fs._acid_evac_origin_t = now;
                    if ((action == "vertical-jump" || action == "away-jump") && "_acid_evac_target" in fs)
                        delete fs._acid_evac_target;  // force rescore next tick

                    // R2': 同步重置 StuckRecoveryTick 的 _stuck_origin / _stuck_origin_t,
                    // 给跳跃 2s 落地+下一轮评分时间, 避免 StuckRecovery 4s/30u 通道
                    // 在 jump 刚触发时立刻 fire DoStuckRecovery(进入 3s 静默), 把 stage3 打断.
                    fs._stuck_origin <- botPos;
                    fs._stuck_origin_t <- now;
                    if ("_stuck_recovery_log_t" in fs) delete fs._stuck_recovery_log_t;

                    if (::g_AcidDebug == 1)
                    {
                        printl("[SpitDbg][stage3] bot=" + bot.GetPlayerName()
                            + " " + format("%.1f", elapsed) + "s 内净位移仅 "
                            + sqrt(od2).tointeger() + "u (<" + STUCK_D2.tointeger() + " STUCK_D2)"
                            + ((actuallyInPool || poolCnt > 0) ? " [acid-zone]" : "")
                            + " -> " + action
                            + " best=(" + format("%.2f", bestDirX) + "," + format("%.2f", bestDirY) + ")"
                            + " second=(" + format("%.2f", secondDirX) + "," + format("%.2f", secondDirY) + ")"
                            + " probe(low=" + format("%.2f", probe.lowFrac) + " high=" + format("%.2f", probe.highFrac) + ")"
                            + (verticalOnly ? " deadAngle(lastBest=" + lastBest + ")" : ""));
                    }
                }
                continue;
            }
            else
            {
                // bot 真在朝目标走 → 重置 origin 进入下一窗口 (防止刚走起来就被判卡死)
                fs._acid_evac_origin = botPos;
                fs._acid_evac_origin_t = now;
            }
        }

        // ---- 阶段 1 已下发 MOVE, 不重发 ---- (这是 C-full 解决抽搐的关键)
    }

    return TICK_RET;
};


// =========================================================
// [1D] 卡死恢复 (Stuck Recovery)
//
// 背景: C-full 避酸状态机在 stage1 入场时设 _acid_evac_active, stage2 池消失时清除.
// 但 L4D2 的 CommandABot 没有真正的 cancel, 老 MOVE 指令仍在底层队列里.
// 常见症状:
//   - 老指令的目标可能在无 nav area 的死角 (如悬崖外)
//   - FallPrev 每 1.5s RETREAT 50u, 老指令每帧又把 bot 推回
//   - admin teleport 无效 (老指令还在, bot 一释放自由控制就走回去)
//   - 只有被 smoker 舌头/jockey 骑/hunter 扑倒等"强制接管"才能清掉老指令
//
// 方案: 独立 1.0s 周期的 StuckRecoveryTick, 对 C-full 避酸中 (_acid_evac_active) 的 bot
// 做位移检测. 4s 内位移 < 60u 判定卡死, 执行完整恢复流程:
//   1) 清 velocity + 所有 _acid_* 状态 + C-full 避酸中标记
//   2) 用 CommandABot cmd=3 正式释放旧 MOVE 指令, 不再追加 MOVE
//   3) 清 m_afButtonForced / m_afButtonDisabled 的位 2 / 位 2048 等残留锁
//   4) 3s 无有效位移时仅升级一次 forceFullReset + 物理逃逸跳
//   5) 输出 [StuckRecovery] 日志
//
// 触发源: (A) 自身 tick 检测位移卡死  (B) FallPreventionTick 10s 窗口内
// 连续 3 次 RETREAT 命中时主动调用.
// =========================================================

::g_StuckRecoveryDebug <- 1;
// The post-clear heuristic is intentionally off. It could mistake normal
// weapon/medical movement for residual acid MOVE and issue a destructive reset.
::ABA_Spitter_EnablePostClearRecovery <- false;
::g_StuckRecovery_LastFireT <- 0.0;  // B-3: 群体 stuck 错峰 — 同 tick 至多 fire 1 次, 用此戳节流

::ABA_Spitter_ClearResetWatch <- function(scope)
{
    if (scope == null) return;
    local keys = [
        "_acid_reset_watch_until", "_acid_reset_watch_origin", "_acid_reset_watch_t",
        "_acid_reset_watch_escalated", "_acid_reset_watch_log_t"
    ];
    foreach (k in keys)
    {
        if (k in scope) delete scope[k];
    }
};

::ABA_Spitter_ResetBotCommand <- function(bot, source, escalate = false)
{
    if (bot == null || !bot.IsValid()) return false;
    try { if (NetProps.GetPropInt(bot, "m_lifeState") != 0) return false; } catch (e0) { return false; }
    if (::ABA_Spitter_IsActionBusy(bot)) return false;
    try { if (bot.IsIncapacitated() || bot.IsHangingFromLedge() || bot.IsDominatedBySpecialInfected()) return false; } catch (e1) {}

    ::ABA_Spitter_ClearABAAcidOrders(bot);
    try { NetProps.SetPropVector(bot, "m_vecAbsVelocity", Vector(0, 0, 0)); } catch (e2) {}
    try { NetProps.SetPropFloat(bot, "m_flLaggedMovementValue", 1.0); } catch (e3) {}
    try { bot.SetFriction(1.0); } catch (e4) {}
    try { NetProps.SetPropInt(bot, "m_afButtonForced", 0); } catch (e5) {}
    try
    {
        local disabled = NetProps.GetPropInt(bot, "m_afButtonDisabled");
        if (disabled & 2)
            NetProps.SetPropInt(bot, "m_afButtonDisabled", disabled & (~2));
    }
    catch (e6) {}

    local usedFullReset = false;
    if (escalate && ("BotAI" in getroottable()) && ("forceFullReset" in ::BotAI))
    {
        try
        {
            ::BotAI.forceFullReset(bot, "ABA acid reset watchdog: " + source);
            usedFullReset = true;
        }
        catch (e7)
        {
            if (::g_StuckRecoveryDebug == 1)
                printl("[StuckRecovery][reset-error] bot=" + bot.GetPlayerName() + " full reset failed: " + e7);
        }
    }

    if (!usedFullReset)
    {
        // cmd=3 is the engine-supported reset for a previous CommandABot order.
        // Do not replace it with more MOVE commands: MOVE is persistent and can
        // recreate the unreachable-target loop this recovery is meant to stop.
        try { CommandABot({ cmd = 3, bot = bot }); }
        catch (e8)
        {
            if (::g_StuckRecoveryDebug == 1)
                printl("[StuckRecovery][reset-error] bot=" + bot.GetPlayerName() + " cmd=3 failed: " + e8);
            return false;
        }
    }

    if (::g_StuckRecoveryDebug == 1)
        printl("[StuckRecovery][command-reset] bot=" + bot.GetPlayerName()
            + " source=" + source + " level=" + (usedFullReset ? "full" : "soft"));
    return true;
};

::DoStuckRecovery <- function( bot, source, dispersalTarget = null )
{
    if (bot == null || !bot.IsValid()) return;
    try { if (NetProps.GetPropInt(bot, "m_lifeState") != 0) return; } catch(e) { return; }
    if (::ABA_Spitter_IsActionBusy(bot))
    {
        if (::g_StuckRecoveryDebug == 1)
            printl("[StuckRecovery][skip-busy] bot=" + bot.GetPlayerName()
                + " source=" + source + " action/control owns input");
        return;
    }

    local botPos = bot.GetOrigin();
    local botName = bot.GetPlayerName();

    // ---- 循环逃逸 burst 计数 ----
    // 同一 bot 在 15s 窗口内累计触发 >=3 次 recovery → 视为 "这地方过不去" / "recovery↔silence
    // 死循环", 本次直接升级为 ABA 的完整软复位, 但不传送、不处死.
    // 计数键 (_recovery_burst_n / _recovery_burst_t0) 不进 clearKeys, 跨 recovery 持续, 由 15s
    // 窗口自然过期重置. map transition 时 script scope 整体重置, 不会跨图污染.
    bot.ValidateScriptScope();
    local burstScope = bot.GetScriptScope();
    local nowB = Time();
    local bt0 = ("_recovery_burst_t0" in burstScope) ? burstScope._recovery_burst_t0 : 0.0;
    local bn  = ("_recovery_burst_n"  in burstScope) ? burstScope._recovery_burst_n  : 0;
    if (bn == 0 || (nowB - bt0) > 15.0)
    {
        burstScope._recovery_burst_n  <- 1;
        burstScope._recovery_burst_t0 <- nowB;
    }
    else
    {
        burstScope._recovery_burst_n <- bn + 1;
    }
    local burstFire = (burstScope._recovery_burst_n >= 3);

    // 1) 清 velocity (老指令给的推力)
    try
    {
        NetProps.SetPropVector(bot, "m_vecAbsVelocity", Vector(0, 0, 0));
    }
    catch (e) { }

    // 2) 清按键强制/禁用 (FallPrev 的 IN_FORWARD 禁用 / Jockey 的 IN_ATTACK2 强制)
    try
    {
        local forced = NetProps.GetPropInt(bot, "m_afButtonForced");
        if (forced != 0)
            NetProps.SetPropInt(bot, "m_afButtonForced", 0);
    }
    catch (e) { }
    try
    {
        local disabled = NetProps.GetPropInt(bot, "m_afButtonDisabled");
        // 只清 IN_FORWARD (位 2); 保留其他位避免误解某些脚本的刻意禁用
        if (disabled & 2)
            NetProps.SetPropInt(bot, "m_afButtonDisabled", disabled & (~2));
    }
    catch (e) { }

    // 3) 清所有 _acid_* 状态 (含 C-full 状态机的所有键)
    bot.ValidateScriptScope();
    local gs = bot.GetScriptScope();
    local clearKeys = [
        // C-full 状态机键
        "_acid_evac_active", "_acid_evac_target", "_acid_evac_target_t",
        "_acid_evac_origin", "_acid_evac_origin_t", "_acid_evac_pool_set",
        "_acid_evac_jump_t", "_acid_evac_log_t", "_acid_evac_last_best_score",
        "_acid_evac_best_nx", "_acid_evac_best_ny", "_acid_evac_best_dist",
        "_acid_evac_second_nx", "_acid_evac_second_ny", "_acid_evac_second_score", "_acid_evac_second_dist",
        "_acid_stage3_n",
        "_acid_evac_pre_only", "_acid_evac_pre_hold_until",
        "_acid_evac_safe_hold", "_acid_evac_safe_hold_origin", "_acid_evac_safe_hold_cmd_t",
        "_acid_safe_stationary_until",
        "_acid_evac_prev_target",
        // DoImmediateAcidEvasion 的节流戳
        "_acid_last_move_t", "_acid_last_move_target",
        // 跨模块互锁日志戳
        "_acid_damage_forced_until", "_acid_damage_pos", "_acid_damage_source_pos",
        "_acid_damage_rescore", "_acid_damage_last_t", "_acid_damage_reissue_t", "_acid_damage_log_t",
        "_acid_tank_log_t", "_acid_silence_log_t", "_acid_clear_deferred"
    ];
    foreach (k in clearKeys)
    {
        if (k in gs) delete gs[k];
    }
    ::ABA_Spitter_ClearPostAcidWatch(gs);
    // stuck recovery 自身的标记也清, 避免下一轮立即再次触发
    if ("_stuck_origin" in gs) delete gs._stuck_origin;
    if ("_stuck_origin_t" in gs) delete gs._stuck_origin_t;
    if ("_stuck_recovery_log_t" in gs) delete gs._stuck_recovery_log_t;
    // 重置近期位移采样: 恢复后位置可能重置, 旧采样无意义, 让下一周期重新采集
    if ("_stuck_recent_pos" in gs) delete gs._stuck_recent_pos;
    if ("_stuck_recent_t" in gs) delete gs._stuck_recent_t;
    if ("_stuck_recent_displaced" in gs) delete gs._stuck_recent_displaced;

    // 4) Reset the persistent engine order instead of appending more MOVE orders.
    // The first recovery is deliberately light. Repeated recovery inside the
    // burst window upgrades once to ABA's existing full soft reset.
    ::ABA_Spitter_ResetBotCommand(bot, source, burstFire);

    // 5) 设置 5s 静默期: 期间 AcidEvasionTick 完全不接管该 bot, 让 ABA 原生 AI 单独处理.
    //    避免恢复后立刻又因 perm-release / giveup 进入新的抽搐循环.
    //    静默期由 AcidEvasionTick 顶部的 `_acid_silenced_until` 检查实现.
    local nowT = Time();
    gs._acid_silenced_until <- nowT + 5.0;
    if ("_acid_silence_log_t" in gs) delete gs._acid_silence_log_t;

    // Verify that cmd=3 actually released the stale MOVE. If the bot still has
    // no useful displacement after three seconds, StuckRecoveryTick performs
    // one full soft reset. This watchdog works after acid state has been cleared.
    gs._acid_reset_watch_until <- nowT + 9.0;
    gs._acid_reset_watch_origin <- bot.GetOrigin();
    gs._acid_reset_watch_t <- nowT;
    gs._acid_reset_watch_escalated <- burstFire;
    if ("_acid_reset_watch_log_t" in gs) delete gs._acid_reset_watch_log_t;

    // ---- R3' 诊断: 检查本 bot 是否同时是 leader-rescuer ----
    // 若是, StuckRecovery 的 cmd=3 会终止当前 CommandABot 指令,
    // 然后进入 5s 静默. 记录该碰撞以便区分避酸恢复和救援任务中断.
    if ("ReviveCheckSIController" in getroottable())
    {
        local p2 = null;
        while (p2 = Entities.FindByClassname(p2, "player"))
        {
            if (!p2.IsValid()) continue;
            if (!p2.IsSurvivor()) continue;
            try { if (NetProps.GetPropInt(p2, "m_lifeState") != 0) continue; } catch(e) { continue; }
            if (IsPlayerABot(p2)) continue;
            try { if (p2.IsIncapacitated()) continue; } catch (e) { }
            local atk2 = ::ReviveCheckSIController(p2);
            if (atk2 != null)
            {
                printl("[StuckRecovery][rescuer-collision] bot=" + botName
                    + " source=" + source
                    + " 在 leader " + p2.GetPlayerName() + " 被特感 ent"
                    + atk2.GetEntityIndex() + " 站立控制期间触发 recovery"
                    + " → cmd=3 reset + 5s silence may interrupt ReviveInterrupt,"
                    + " 可能造成 bot 不接近 attacker");
                break;
            }
        }
    }

    if (burstFire)
    {
        // Full soft reset has already run; do not teleport or issue another MOVE.
        burstScope._recovery_burst_n  <- 0;
        burstScope._recovery_burst_t0 <- 0.0;
        if (::g_StuckRecoveryDebug == 1)
            printl("[StuckRecovery][burst-full-reset] bot=" + botName
                + " 15s 内累计 3 次 recovery (source=" + source + ") -> full soft reset, no teleport");
    }

    if (::g_StuckRecoveryDebug == 1)
    {
        printl("[StuckRecovery][" + source + "] bot=" + botName
            + " pos=(" + botPos.x.tointeger() + "," + botPos.y.tointeger() + "," + botPos.z.tointeger() + ")"
            + " -> 已清 velocity + buttons + _acid_* 状态 + cmd=3 reset + 进入 5s 静默期");
    }
};

::StuckRecoveryTick <- function()
{
    if (("BotCore" in getroottable()) && ("IsStartupGraceActive" in ::BotCore)
        && ::BotCore.IsStartupGraceActive())
        return 1.0;

    local now = Time();

    // ---- B-1: 第一遍扫描 — 收集所有 _acid_evac_active 的 bot 位置 ----
    // (C-full 替代旧 _acid_released_permanently 门)
    // 用于群体 stuck 检测: 若某 bot 100u 内还有其他 evac-active bot, 视为抱团互堵,
    // 触发降阈 (jitter 4s/30u → 2.5s/40u) + 错峰 firing + 分散 MOVE 三件套.
    local permList = [];
    local scanBot = null;
    while (scanBot = Entities.FindByClassname(scanBot, "player"))
    {
        if (!scanBot.IsValid()) continue;
        if (scanBot.GetClassname() != "player") continue;
        if (!scanBot.IsSurvivor()) continue;
        if (!IsPlayerABot(scanBot)) continue;
        try { if (NetProps.GetPropInt(scanBot, "m_lifeState") != 0) continue; } catch(e) { continue; }
        if (::ABA_Spitter_IsActionBusy(scanBot)) continue;
        scanBot.ValidateScriptScope();
        local sgs = scanBot.GetScriptScope();
        if (("_acid_evac_pre_only" in sgs) && sgs._acid_evac_pre_only) continue;
        if ("_acid_safe_stationary_until" in sgs && sgs._acid_safe_stationary_until > now) continue;
        if ("_acid_evac_active" in sgs)
            permList.append({ idx = scanBot.GetEntityIndex(), pos = scanBot.GetOrigin() });
    }

    local bot = null;
    while (bot = Entities.FindByClassname(bot, "player"))
    {
        if (!bot.IsValid()) continue;
        if (bot.GetClassname() != "player") continue;
        if (!bot.IsSurvivor()) continue;
        if (!IsPlayerABot(bot)) continue;
        try { if (NetProps.GetPropInt(bot, "m_lifeState") != 0) continue; } catch(e) { continue; }
        bot.ValidateScriptScope();
        local gs = bot.GetScriptScope();

        if (::ABA_Spitter_IsActionBusy(bot))
        {
            // Match the old reset-watch behavior: a controlled bot is not
            // evidence that the previous MOVE reset failed.  Drop the watch
            // while control/release owns the input, then let normal AI resume.
            if ("_acid_reset_watch_until" in gs)
                ::ABA_Spitter_ClearResetWatch(gs);
            local busyPos = bot.GetOrigin();
            if ("_acid_evac_active" in gs)
            {
                ::ABA_Spitter_SetScopeValue(gs, "_acid_evac_origin", busyPos);
                ::ABA_Spitter_SetScopeValue(gs, "_acid_evac_origin_t", now);
            }
            if ("_stuck_origin" in gs)
            {
                gs._stuck_origin = busyPos;
                gs._stuck_origin_t = now;
            }
            continue;
        }

        local botPos = bot.GetOrigin();

        // ---- 近期位移采样 (每 1.5s 一次) ----
        // 用近期净位移替代瞬时速度: 瞬时速度在抽搐时会在 0~150 之间剧烈跳变, 不可靠;
        // 1.5s 净位移能稳定区分 — 真正在走 >=80u, 抽搐/原地振荡 <30u, 卡死 ~0u.
        // 这是修复 detect-abs 假阳性的关键 (用户实测 14/16 detect-abs 是误判).
        // 对所有 bot 采样 (不仅 permanent), 让 count==0 path 的 perm-clear 也能用.
        if (!("_stuck_recent_pos" in gs))
        {
            gs._stuck_recent_pos <- botPos;
            gs._stuck_recent_t <- now;
            gs._stuck_recent_displaced <- 0.0;
        }
        else if ((now - gs._stuck_recent_t) >= 1.5)
        {
            local rdx = botPos.x - gs._stuck_recent_pos.x;
            local rdy = botPos.y - gs._stuck_recent_pos.y;
            gs._stuck_recent_displaced <- sqrt(rdx*rdx + rdy*rdy);
            gs._stuck_recent_pos = botPos;
            gs._stuck_recent_t = now;
        }

        // 只对处于 C-full 避酸状态的 bot 做卡死检测
        // (C-full 状态机在 stage1 进入时设 _acid_evac_active, stage2 池消失时清除.
        //  StuckRecoveryTick 监控这些 bot 是否在 stage 1/3 真的卡死.)
        local acidActive = ("_acid_evac_active" in gs);

        // Reset watchdog: DoStuckRecovery clears acidActive, so the old detector
        // cannot prove whether cmd=3 actually released the persistent MOVE.
        // Watch the bot independently and escalate only once if it still makes
        // no useful progress. No teleport is used by either level.
        if (!acidActive && ("_acid_reset_watch_until" in gs))
        {
            local resetBusy = ::ABA_Spitter_IsActionBusy(bot);
            if (resetBusy || gs._acid_reset_watch_until <= now)
            {
                ::ABA_Spitter_ClearResetWatch(gs);
            }
            else
            {
                local resetT = ("_acid_reset_watch_t" in gs) ? gs._acid_reset_watch_t : now;
                local resetElapsed = now - resetT;
                local resetOrigin = ("_acid_reset_watch_origin" in gs) ? gs._acid_reset_watch_origin : botPos;
                if (typeof resetOrigin != "Vector") resetOrigin = botPos;
                local resetDx = botPos.x - resetOrigin.x;
                local resetDy = botPos.y - resetOrigin.y;
                local resetNet = sqrt(resetDx * resetDx + resetDy * resetDy);
                local resetRecent = ("_stuck_recent_displaced" in gs) ? gs._stuck_recent_displaced : 0.0;
                local resetSpeed = 0.0;
                try
                {
                    local resetVel = NetProps.GetPropVector(bot, "m_vecAbsVelocity");
                    resetSpeed = sqrt(resetVel.x * resetVel.x + resetVel.y * resetVel.y);
                }
                catch (eResetSpeed) {}

                if (resetElapsed >= 1.5 && (resetNet >= 80.0 || resetRecent >= 80.0))
                {
                    if (::g_StuckRecoveryDebug == 1)
                        printl("[StuckRecovery][reset-ok] bot=" + bot.GetPlayerName()
                            + " net=" + resetNet.tointeger() + "u recent=" + resetRecent.tointeger() + "u");
                    ::ABA_Spitter_ClearResetWatch(gs);
                }
                else if (resetElapsed >= 3.0 && !("_acid_reset_watch_escalated" in gs && gs._acid_reset_watch_escalated)
                    && ((resetRecent >= 4.0 && resetRecent < 80.0) || resetSpeed > 20.0))
                {
                    local resetWorked = ::ABA_Spitter_ResetBotCommand(bot, "watchdog-no-progress", true);
                    gs._acid_reset_watch_escalated <- true;
                    gs._acid_reset_watch_origin <- bot.GetOrigin();
                    gs._acid_reset_watch_t <- now;
                    gs._acid_reset_watch_until <- now + 6.0;
                    gs._acid_silenced_until <- now + 5.0;

                    // Physical fallback after the full soft reset: one escape
                    // jump toward the nearest living human. This is a one-shot
                    // impulse, not another persistent MOVE or a teleport.
                    local escapeLeader = null;
                    local escapeD2 = 999999999.0;
                    local ep = null;
                    while (ep = Entities.FindByClassname(ep, "player"))
                    {
                        if (!ep.IsValid() || ep == bot || !ep.IsSurvivor() || IsPlayerABot(ep)) continue;
                        try { if (NetProps.GetPropInt(ep, "m_lifeState") != 0) continue; } catch (eLeader) { continue; }
                        local epos = ep.GetOrigin();
                        local edx = epos.x - botPos.x;
                        local edy = epos.y - botPos.y;
                        local ed2 = edx * edx + edy * edy;
                        if (ed2 < escapeD2) { escapeD2 = ed2; escapeLeader = ep; }
                    }
                    if (escapeLeader != null && escapeLeader.IsValid())
                    {
                        local escapePos = escapeLeader.GetOrigin();
                        local escapeX = escapePos.x - botPos.x;
                        local escapeY = escapePos.y - botPos.y;
                        local escapeLen = sqrt(escapeX * escapeX + escapeY * escapeY);
                        if (escapeLen > 1.0)
                            ::ForceBotEscapeJump(bot, escapeX / escapeLen, escapeY / escapeLen);
                    }

                    if (::g_StuckRecoveryDebug == 1)
                        printl("[StuckRecovery][reset-escalate] bot=" + bot.GetPlayerName()
                            + " soft reset made no progress (net=" + resetNet.tointeger()
                            + "u, recent=" + resetRecent.tointeger() + "u, speed=" + resetSpeed.tointeger() + ")"
                            + " -> full soft reset + one escape jump"
                            + (resetWorked ? "" : " [reset call failed]"));
                    continue;
                }
                else if (resetElapsed >= 3.0 && !("_acid_reset_watch_escalated" in gs && gs._acid_reset_watch_escalated))
                {
                    // No net progress is acceptable when the old MOVE has
                    // stopped pulling the bot. Treat a stable idle bot as a
                    // successful command release instead of disturbing it.
                    if (::g_StuckRecoveryDebug == 1)
                        printl("[StuckRecovery][reset-stable] bot=" + bot.GetPlayerName()
                            + " no residual jitter (recent=" + resetRecent.tointeger()
                            + "u, speed=" + resetSpeed.tointeger() + ")");
                    ::ABA_Spitter_ClearResetWatch(gs);
                }
                else if (resetElapsed >= 5.0 && ("_acid_reset_watch_escalated" in gs && gs._acid_reset_watch_escalated))
                {
                    if (::g_StuckRecoveryDebug == 1)
                        printl("[StuckRecovery][reset-unresolved] bot=" + bot.GetPlayerName()
                            + " full soft reset still has no verified progress (net=" + resetNet.tointeger()
                            + "u, recent=" + resetRecent.tointeger() + "u, speed=" + resetSpeed.tointeger()
                            + "); stop ABA recovery loop");
                    ::ABA_Spitter_ClearResetWatch(gs);
                }
            }
        }

        // Post-clear watchdog: acid state is gone, but a stale MOVE may still be
        // keeping the bot pacing around the old evacuation point.
        // Disabled by default: this post-clear heuristic caused false-positive
        // cmd=3 resets during normal item/weapon actions. In-acid recovery below
        // remains active for genuine acid-zone stalls.
        if (::ABA_Spitter_EnablePostClearRecovery && !acidActive && ("_acid_post_clear_until" in gs))
        {
            if (gs._acid_post_clear_until <= now)
            {
                ::ABA_Spitter_ClearPostAcidWatch(gs);
            }
            else
            {
                local postBusy = false;
                try { if (bot.IsDominatedBySpecialInfected() || bot.IsIncapacitated() || bot.IsHangingFromLedge()) postBusy = true; } catch(ePostBusy) {}
                if (postBusy)
                {
                    ::ABA_Spitter_ClearPostAcidWatch(gs);
                    continue;
                }

                local postT = ("_acid_post_clear_t" in gs) ? gs._acid_post_clear_t : now;
                local postElapsed = now - postT;
                local postOrigin = ("_acid_post_clear_origin" in gs) ? gs._acid_post_clear_origin : botPos;
                if (typeof postOrigin != "Vector")
                    postOrigin = botPos;

                local pdx = botPos.x - postOrigin.x;
                local pdy = botPos.y - postOrigin.y;
                local postNet = sqrt(pdx*pdx + pdy*pdy);
                local postRecent = ("_stuck_recent_displaced" in gs) ? gs._stuck_recent_displaced : 0.0;

                local speed2D = 0.0;
                try
                {
                    local pv = NetProps.GetPropVector(bot, "m_vecAbsVelocity");
                    speed2D = sqrt(pv.x*pv.x + pv.y*pv.y);
                }
                catch (eSpeed) {}

                local nearOldTarget = false;
                if (("_acid_post_clear_target" in gs) && typeof gs._acid_post_clear_target == "Vector")
                {
                    local t = gs._acid_post_clear_target;
                    local tdx = botPos.x - t.x;
                    local tdy = botPos.y - t.y;
                    nearOldTarget = (tdx*tdx + tdy*tdy) < 140.0 * 140.0;
                }

                if (postElapsed >= 2.2)
                {
                    local jittering = (postNet < 95.0 && postRecent >= 5.0 && postRecent < 65.0);
                    local speedJitter = (postNet < 70.0 && speed2D > 20.0);
                    local targetJitter = (nearOldTarget && postRecent >= 4.0 && postRecent < 80.0);
                    if (jittering || speedJitter || targetJitter)
                    {
                        if (::g_StuckRecoveryDebug == 1)
                        {
                            local lt = ("_acid_post_clear_log_t" in gs) ? gs._acid_post_clear_log_t : 0.0;
                            if (now - lt > 1.5)
                            {
                                printl("[StuckRecovery][post-clear] bot=" + bot.GetPlayerName()
                                    + " acid cleared " + format("%.1f", postElapsed) + "s ago"
                                    + ", net=" + postNet.tointeger() + "u"
                                    + ", recent=" + postRecent.tointeger() + "u"
                                    + ", speed=" + speed2D.tointeger()
                                    + " -> flush stale MOVE");
                                gs._acid_post_clear_log_t <- now;
                            }
                        }
                        ::DoStuckRecovery(bot, "post-clear-jitter", null);
                        continue;
                    }
                }
            }
        }

        if (!acidActive) continue;
        local safeStationary = ("_acid_safe_stationary_until" in gs
            && gs._acid_safe_stationary_until > now);
        if ((("_acid_evac_pre_only" in gs) && gs._acid_evac_pre_only) || safeStationary)
        {
            // Standing still at a verified safe point is the desired result,
            // not an acid-navigation stall. Keep the detector's clocks fresh
            // so it cannot fire immediately if the hold flag changes next tick.
            ::ABA_Spitter_SetScopeValue(gs, "_stuck_origin", botPos);
            ::ABA_Spitter_SetScopeValue(gs, "_stuck_origin_t", now);
            continue;
        }
        if ("_acid_safe_stationary_until" in gs)
            delete gs._acid_safe_stationary_until;

        // 首次触发: 记录 stuck 起点 (C-full stage1 也会维护 _acid_evac_origin, 这里独立兜底)
        if (!("_stuck_origin" in gs))
        {
            gs._stuck_origin <- botPos;
            gs._stuck_origin_t <- now;
            continue;
        }

        local elapsed = now - gs._stuck_origin_t;
        local recentDist = ("_stuck_recent_displaced" in gs) ? gs._stuck_recent_displaced : 0.0;

        // 计算自 stuck origin 起的总位移 (诊断用)
        local dx = botPos.x - gs._stuck_origin.x;
        local dy = botPos.y - gs._stuck_origin.y;
        local dist2 = dx*dx + dy*dy;

        // ---- B-1: 群体 stuck 检测 — 100u 内是否有其他 permanent bot ----
        local groupStuck = false;
        local groupCx = 0.0; local groupCy = 0.0; local groupN = 0;
        local thisIdx = bot.GetEntityIndex();
        foreach (other in permList)
        {
            if (other.idx == thisIdx) continue;
            local odx = other.pos.x - botPos.x;
            local ody = other.pos.y - botPos.y;
            if (odx*odx + ody*ody < 100.0 * 100.0)
            {
                groupStuck = true;
                groupCx += other.pos.x;
                groupCy += other.pos.y;
                groupN++;
            }
        }

        // ---- B-3: 错峰 gate — 群体 stuck 时同 tick 至多 fire 1 次 ----
        local stagger_block = (groupStuck && (now - ::g_StuckRecovery_LastFireT) < 0.9);

        // ---- B-2: 计算分散 MOVE 目标 (远离群心 120u, IsAcidTargetSafe 兜底) ----
        local dispersalTgt = null;
        if (groupStuck && groupN > 0)
        {
            local cx = groupCx / groupN;
            local cy = groupCy / groupN;
            local awayX = botPos.x - cx;
            local awayY = botPos.y - cy;
            local alen = sqrt(awayX*awayX + awayY*awayY);
            if (alen >= 1.0)
            {
                local nxg = awayX / alen;
                local nyg = awayY / alen;
                if (::IsAcidTargetSafe(botPos, nxg, nyg, 120.0))
                    dispersalTgt = Vector(botPos.x + nxg * 120.0, botPos.y + nyg * 120.0, botPos.z);
            }
        }

        // ---- 绝对超时兜底: permanent 持续 12s+ ----
        // 用近 1.5s 净位移 (recentDist) 区分:
        //   recentDist >= 80u → bot 在持续移动 (不论是直线走还是大幅迂回), 滚动重置
        //   recentDist < 80u  → bot 抽搐或卡死 (净进展不足), 触发恢复
        if (elapsed >= 12.0)
        {
            if (recentDist >= 80.0)
            {
                gs._stuck_origin = botPos;
                gs._stuck_origin_t = now;
                if ("_stuck_recovery_log_t" in gs) delete gs._stuck_recovery_log_t;
                continue;
            }
            if (::g_StuckRecoveryDebug == 1)
                printl("[StuckRecovery][detect-abs" + (groupStuck ? "-grp" : "") + "] bot=" + bot.GetPlayerName()
                    + " C-full 避酸中 " + format("%.1f", elapsed) + "s 兜底超时 (累计位移 "
                    + sqrt(dist2).tointeger() + "u, 近1.5s净位移 " + recentDist.tointeger()
                    + "u → 抽搐/卡死), 触发恢复");
            ::DoStuckRecovery(bot, "tick-abs", dispersalTgt);
            if (groupStuck) ::g_StuckRecovery_LastFireT = now;
            continue;
        }

        // ---- 快通道: 完全静止 (累计位移 < 10u) 持续 2.0s → 立即触发恢复 ----
        // 极端钉死场景, 不需要等满 4s.
        if (elapsed >= 2.0 && dist2 < 10.0 * 10.0)
        {
            if (stagger_block) continue;
            if (::g_StuckRecoveryDebug == 1)
            {
                local lt = ("_stuck_recovery_log_t" in gs) ? gs._stuck_recovery_log_t : 0.0;
                if (now - lt > 2.0)
                {
                    printl("[StuckRecovery][detect-fast" + (groupStuck ? "-grp" : "") + "] bot=" + bot.GetPlayerName()
                        + " C-full 避酸中 " + format("%.1f", elapsed) + "s 完全静止 ("
                        + sqrt(dist2).tointeger() + "u), 快速触发恢复");
                    gs._stuck_recovery_log_t <- now;
                }
            }
            ::DoStuckRecovery(bot, "tick-fast", dispersalTgt);
            if (groupStuck) ::g_StuckRecovery_LastFireT = now;
            continue;
        }

        // ---- 抽搐通道: elapsed >= 4s 且近 1.5s 净位移 < 30u → 抽搐卡死 ----
        // 用户反馈的"前后一步不到的距离一直抽搐"场景:
        //   累计位移可能 100~500u (从 perm 起点走过来), 但近 1.5s 净位移很小 = 抽搐.
        //   旧的 dist2<60² 检测漏掉这种, 因为累计位移已经 >60u.
        // B-1: groupStuck 时阈值降到 2.5s/40u, 抱团互堵需要更快兜底.
        local jitElapsed = groupStuck ? 2.5 : 4.0;
        local jitDistThr = groupStuck ? 40.0 : 30.0;
        if (elapsed >= jitElapsed && recentDist < jitDistThr)
        {
            if (stagger_block) continue;
            if (::g_StuckRecoveryDebug == 1)
            {
                local lt = ("_stuck_recovery_log_t" in gs) ? gs._stuck_recovery_log_t : 0.0;
                if (now - lt > 2.0)
                {
                    printl("[StuckRecovery][detect-jitter" + (groupStuck ? "-grp" : "") + "] bot=" + bot.GetPlayerName()
                        + " C-full 避酸中 " + format("%.1f", elapsed) + "s, 近1.5s净位移仅 "
                        + recentDist.tointeger() + "u (抽搐), 触发恢复");
                    gs._stuck_recovery_log_t <- now;
                }
            }
            ::DoStuckRecovery(bot, "tick-jitter", dispersalTgt);
            if (groupStuck) ::g_StuckRecovery_LastFireT = now;
            continue;
        }

        // ---- 普通通道: elapsed >= 4s 且累计位移 < 60u → 卡死 ----
        if (elapsed >= 4.0 && dist2 < 60.0 * 60.0)
        {
            if (stagger_block) continue;
            if (::g_StuckRecoveryDebug == 1)
            {
                local lt = ("_stuck_recovery_log_t" in gs) ? gs._stuck_recovery_log_t : 0.0;
                if (now - lt > 2.0)
                {
                    printl("[StuckRecovery][detect" + (groupStuck ? "-grp" : "") + "] bot=" + bot.GetPlayerName()
                        + " C-full 避酸中 " + format("%.1f", elapsed) + "s 累计位移仅 "
                        + sqrt(dist2).tointeger() + "u, 触发恢复");
                    gs._stuck_recovery_log_t <- now;
                }
            }
            ::DoStuckRecovery(bot, "tick", dispersalTgt);
            if (groupStuck) ::g_StuckRecovery_LastFireT = now;
        }
    }
    return 1.0;
};


// =========================================================
// 入口: 由 lib BotAILib_Bootstrap() 调用
// =========================================================
::BotModule_Spitter_Init <- function()
{
    ::LoadAcidCfg();

    // 主动避酸 thinker
    local oldA = Entities.FindByName(null, "g_aba_acid_thinker");
    if (oldA != null && oldA.IsValid()) oldA.Kill();
    local tA = SpawnEntityFromTable("info_target", { targetname = "g_aba_acid_thinker" });
    tA.ValidateScriptScope();
    tA.GetScriptScope().AcidThinkFn <- ::AcidEvasionTick;
    AddThinkToEnt(tA, "AcidThinkFn");

    // 卡死恢复 thinker (1.0s 周期, 独立于避酸逻辑)
    local oldR = Entities.FindByName(null, "g_aba_stuck_recovery_thinker");
    if (oldR != null && oldR.IsValid()) oldR.Kill();
    local tR = SpawnEntityFromTable("info_target", { targetname = "g_aba_stuck_recovery_thinker" });
    tR.ValidateScriptScope();
    tR.GetScriptScope().StuckRecoveryThinkFn <- ::StuckRecoveryTick;
    AddThinkToEnt(tR, "StuckRecoveryThinkFn");
        printl(">>>             Dead-angle fallback: choose best scored direction even when every direction has hazard/cliff risk.");
    // spit_burst 事件载体
    local oldEC = Entities.FindByName(null, "g_aba_spitter_event_carrier");
    if (oldEC != null && oldEC.IsValid()) oldEC.Kill();
    SpawnEntityFromTable("info_target", {
        targetname = "g_aba_spitter_event_carrier",
        vscripts = "aba_spitter_events"
    });

    // 启动横幅
    if (::IsAcidDamageImmune())
        printl(">>>        [1A] 酸液: Mode 1 伤害豁免 (bot 完全免疫 spit 伤害, 不触发避酸逻辑)");
    else
    {
        printl(">>>        [1A] 酸液: Mode 0 C-full 主动避酸 (需 L4B dodge_spit=0)");
        printl(">>>             状态机 4 阶段:");
        printl(">>>               [阶段 0] HandleSpitBurstEvent 即时避酸 (spit_burst 事件触发)");
        printl(">>>               [阶段 1] pool 检测 → 16 方向路径评分 (hazard/cliff/wall 综合) → 一次 MOVE 不重发");
        printl(">>>               [阶段 2] pool 消失 → 清状态, 解除干预, L4B 接管");
        printl(">>>               [阶段 3] 2s 内净位移 <30u → ForceBotEscapeJump 沿 hazard 反方向 (CD 1.0s)");
        printl(">>>             死角覆盖: 8 方向皆有 hazard/cliff 时仍选最佳分数, 即穿酸也走");
        printl(">>>             新池检测: pool ent_idx 集合变化 → 重新评分");
        printl(">>>             tick 0.5s (旧 0.2s 每 tick 重发 MOVE 抽搐元凶, 已修)");
    }
    printl(">>>        [1D] 卡死恢复: 监控 _acid_evac_active 的 bot (快通道 2s/10u, 抽搐 4s/30u, 普通 4s/60u, 兜底 12s)");
    printl(">>>                       轻度恢复: 清 velocity/buttons/_acid_* + cmd=3 释放持久 MOVE + 5s silence");
    printl(">>>                       保底恢复: 3s 无有效位移 → 单次 forceFullReset + 朝最近真人物理逃逸跳, 不传送");
    printl(">>>        cfg: ems/" + ::ACID_CFG_PATH);
    printl(">>>        AcidDamageScale=" + ::GetAcidDamageScale() + " (0=full immunity, non-zero min=0.1)");
    printl(">>>        注: [1C] 防跌落/挂边自救 已迁出至独立 addon bot_fall_preventing");
};


// =============================================================================
// ABA mount entry point. No BotCore dependency here.
// =============================================================================

::BotModule_ABA_Spitter_Init <- function()
{
    ::BotModule_Spitter_Init();
    printl("[ABA-Spitter] mounted without BotCore");
    printl("[ABA-Spitter] diagnostics: script ::ABA_SpitterDumpState()");
};

::ABA_SpitterDumpState <- function()
{
    printl("=== ABA-Spitter mounted ===");
    printl("  active=" + (::ABA_Spitter_MountActive ? "1" : "0")
        + " AcidDamageScale=" + ::GetAcidDamageScale()
        + " pools=" + ::g_AcidPoolLifetime.len()
        + " warnings=" + ::g_ActiveSpits.len());

    local b = null;
    while ((b = Entities.FindByClassname(b, "player")) != null)
    {
        if (!b.IsValid() || !b.IsSurvivor() || !IsPlayerABot(b)) continue;
        b.ValidateScriptScope();
        local fs = b.GetScriptScope();
        local active = ("_acid_evac_active" in fs) ? "1" : "0";
        local own = ("_aba_spitter_own_until" in fs && Time() < fs._aba_spitter_own_until) ? "1" : "0";
        printl("  bot=" + b.GetPlayerName() + " acid_active=" + active + " own_window=" + own);
    }
};

::BotModule_ABA_Spitter_Init();
