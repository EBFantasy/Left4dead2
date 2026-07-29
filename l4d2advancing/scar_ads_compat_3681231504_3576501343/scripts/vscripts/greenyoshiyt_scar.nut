// ADS compatibility: single-use token marking a shove that THIS script
// synthesised for its auto/burst rhythm, so the ADS addon can tell it apart
// from a shove the player actually pressed.
//
// v2: this used to be a 0.35s time window (ScarAutoSyntheticShoveUntil).
// A window is wrong for two reasons:
//   - a real right-click landing inside the window was misread as synthetic
//     and swallowed, which is the "shove does nothing" report;
//   - the stale entry survived until it expired, so a later real shove could
//     still be consumed, producing the delayed/chained shoves.
// The token is now set exactly when the synthetic shove bit goes on and
// cleared exactly when it goes off, so one synthetic shove consumes at most
// one check and a real shove is never inside the token's lifetime.
if (!("ScarAutoSyntheticShove" in getroottable()))
    ::ScarAutoSyntheticShove <- {}

// ---------------------------------------------------------------------------
// Shove diagnostics.  Toggle in console:   script ScarShoveDebug <- true
//
// Logs every point on the path a real right-click has to survive, so the next
// console.log shows exactly where it is being lost instead of us guessing.
// Rate-limited so a long session cannot flood the console.
// ---------------------------------------------------------------------------
if (!("ScarShoveDebug" in getroottable()))
    ::ScarShoveDebug <- true

if (!("ScarShoveDebugCount" in getroottable()))
    ::ScarShoveDebugCount <- 0

::ScarDbg <- function (msg)
{
    if (!::ScarShoveDebug) return
    if (::ScarShoveDebugCount >= 400) return
    ::ScarShoveDebugCount++
    printl("[SCARDBG] " + msg)
}

// ---------------------------------------------------------------------------
// v6 instrumentation.
//
// The v5 log was nearly silent - 70 SCAR shots but only 4 diagnostic lines and
// ZERO from the Observe pass - which means the burst pipeline never ran at all
// and the shove problem lives somewhere none of the previous logging covered.
// These trace the paths that were invisible.
// ---------------------------------------------------------------------------

// Rate-limited per-key logger, so a per-tick event reports its first few
// occurrences and then a periodic heartbeat instead of flooding.
if (!("ScarDbgSeen" in getroottable()))
    ::ScarDbgSeen <- {}

::ScarDbgOnce <- function (key, msg, every = 200)
{
    if (!::ScarShoveDebug) return
    if (!(key in ::ScarDbgSeen)) ::ScarDbgSeen[key] <- 0
    ::ScarDbgSeen[key]++
    local n = ::ScarDbgSeen[key]
    if (n <= 3 || (n % every) == 0)
        printl("[SCARDBG] " + msg + "  (#" + n + ")")
}

// Snapshot of everything that can gate a shove, printed only when it changes.
if (!("ScarDbgLastState" in getroottable()))
    ::ScarDbgLastState <- {}

::ScarDbgShoveGates <- function (player, tag)
{
    if (!::ScarShoveDebug) return
    try
    {
        local now = Time()
        local wep = player.GetActiveWeapon()
        if (wep == null) return

        local id       = player.GetEntityIndex()
        local nextAtk  = NetProps.GetPropFloat(player, "m_flNextAttack")
        local nextSec  = NetProps.GetPropFloat(wep, "m_flNextSecondaryAttack")
        local penalty  = NetProps.GetPropInt(player, "m_iShovePenalty")
        local forced   = NetProps.GetPropInt(player, "m_afButtonForced")
        local disabled = NetProps.GetPropInt(player, "m_afButtonDisabled")

        // Which of them would actually stop a right-click this tick.
        local blockers = ""
        if (nextAtk > now)  blockers += "MASTER(+" + (nextAtk - now) + "s) "
        if (nextSec > now)  blockers += "SECONDARY(+" + (nextSec - now) + "s) "
        if (disabled & 2048) blockers += "BUTTON_DISABLED "
        if (penalty > 0)    blockers += "PENALTY(" + penalty + ") "
        if (blockers == "") blockers = "none"

        local sig = blockers + "|" + (forced & 2048)
        if (id in ::ScarDbgLastState && ::ScarDbgLastState[id] == sig) return
        ::ScarDbgLastState[id] <- sig

        ::ScarDbg(tag + " gates -> " + blockers
            + " forcedShoveBit=" + ((forced & 2048) ? 1 : 0))
    }
    catch (e) { }
}

// Reports whether the engine would currently accept a shove, and why not.
::ScarDbgAttackState <- function (player, tag)
{
    if (!::ScarShoveDebug) return
    try
    {
        local now = Time()
        local nextAtk = NetProps.GetPropFloat(player, "m_flNextAttack")
        local wep = player.GetActiveWeapon()
        local nextSec = (wep != null) ? NetProps.GetPropFloat(wep, "m_flNextSecondaryAttack") : -1.0
        local nextPri = (wep != null) ? NetProps.GetPropFloat(wep, "m_flNextPrimaryAttack") : -1.0
        ::ScarDbg(tag
            + " now=" + now
            + " nextAttack=" + nextAtk + (nextAtk > now ? " [BLOCKED +" + (nextAtk - now) + "s]" : " [ok]")
            + " nextSecondary=" + nextSec + (nextSec > now ? " [BLOCKED]" : " [ok]")
            + " nextPrimary=" + nextPri)
    }
    catch (e) { }
}

::greenyoshiyt_scarL_mode <-
{
    Setting =
    [
        "default_fire_mode = 1 //1 = Full auto, 0 = Burst",
        "bot_default_fire_mode = 1 //1 = Full auto, 0 = Burst",
        "switch_delay = 6 //ticks before you can switch again, 0.2 seconds in this case",
        "show_switch_mode = 1 //Showing the switching text on the middle of a screen", 
        "button = \"BUTTON_ZOOM\"",
    ]
    
    Full_auto_to_add = []
    Weapon_mode = {}
    FoundSurvivors = {}
    Shooter = []
    PlayerAttack = {}
    ObserveQueue = {}
    

    // greenyoshiyt =
    // {
    //     PredictMode = 0
    //     Burst_shot_fired = 0
    //     Switching = 0
    // }

    default_player_stat =
    {
        Refired = 0
        PredictMode = 0
        PredictModeTime = 0
        PredictTime = 0
        LastShot = 0.0
        First_fired_time = 0.0
        Switching = 0
        Releasing = 0
    }
    
    default_aspd = 0.07
    custom_aspd = 0.07
    observeTick = 18
    predictTick = 3 //Minimum
    predictModeTick = 6 //Minimum

    //const
    Const =
    {
        default_fire_mode = 1
        bot_default_fire_mode = 1
        switch_delay = 6 //ticks before you can switch again, 0.2 seconds in this 
        show_switch_mode = 1
        button = "BUTTON_ZOOM"
    }
    //Sound index
    burst1 = 0
    burst2 = 0
    button_setting = 524288

    //Load button
    function LoadButton()
    {
        switch(greenyoshiyt_scarL_mode.Const.button)
        {
            case("BUTTON_ATTACK"):
                button_setting = 1
                break;
            case("BUTTON_JUMP"):
                button_setting = 2
                break;
            case("BUTTON_DUCK"):
                button_setting = 4
                break;
            case("BUTTON_FORWARD"):
                button_setting = 8
                break;
            case("BUTTON_BACK"):
                button_setting = 16
                break;
            case("BUTTON_USE"):
                button_setting = 32
                break;
            case("BUTTON_CANCEL"):
                button_setting = 64
                break;
            case("BUTTON_LEFT"):
                button_setting = 128
                break;
            case("BUTTON_RIGHT"):
                button_setting = 256
                break;
            case("BUTTON_MOVELEFT"):
                button_setting = 512
                break;
            case("BUTTON_MOVERIGHT"):
                button_setting = 1024
                break;
            case("BUTTON_SHOVE"):
                button_setting = 2048
                break;
            case("BUTTON_RUN"):
                button_setting = 4096
                break;
            case("BUTTON_RELOAD"):
                button_setting = 8192
                break;
            case("BUTTON_ALT1"):
                button_setting = 16384
                break;
            case("BUTTON_ALT2"):
                button_setting = 32768
                break;
            case("BUTTON_SCORE"):
                button_setting = 65536
                break;
            case("BUTTON_WALK"):
                button_setting = 131072
                break;
            case("BUTTON_ZOOM"):
                button_setting = 524288
                break;
            case("BUTTON_WEAPON1"):
                button_setting = 1048576
                break;
            case("BUTTON_WEAPON2"):
                button_setting = 2097152
                break;
            case("BUTTON_BULLRUSH"):
                button_setting = 4194304
                break;
            case("BUTTON_GRENADE1"):
                button_setting = 8388608
                break;
            case("BUTTON_GRENADE2"):
                button_setting = 16777216
                break;
            case("BUTTON_LOOKSPIN"):
                button_setting = 33554432
                break;
            default:
                button_setting = 524288
                break;
        }
    }

    function DeleteShooterData(greenyoshiyt)
    {
        greenyoshiyt_scarL_mode.FoundSurvivors[greenyoshiyt].First_fired_time = 0.0
        delete greenyoshiyt_scarL_mode.ObserveQueue[greenyoshiyt]

        // array.find() returns an INDEX, and index 0 is falsy in Squirrel.
        // Testing it as a boolean means the first entry in Shooter - which in
        // single player is always the local player - is treated as "not
        // present" and never removed. It then lingers until the Process-shots
        // pass happens to clear it, which is the source of the long delay
        // before a real right-click takes effect.
        local shooterIdx = greenyoshiyt_scarL_mode.Shooter.find(greenyoshiyt)
        if(shooterIdx != null)
        {
            greenyoshiyt_scarL_mode.Shooter.remove(shooterIdx)
        }

    }

    //Think timer
    function createThinkTimer(){
        local timer = null
        while (timer = Entities.FindByName(null, "thinkTimer_scar")){
            timer.Kill()
        }
        timer = SpawnEntityFromTable("logic_timer", { targetname = "thinkTimer_scar", RefireTime = 0.01 })
        timer.ValidateScriptScope()
        timer.GetScriptScope()["scope"] <- this

        timer.GetScriptScope()["func"] <- function (){
            scope.Think()
        }
        timer.ConnectOutput("OnTimer", "func")
        EntFire("!self", "Enable", null, 0, timer)
    }
    //Start of Think function
    function Think()
    {
        // //Observing Queue, to deal with Burst Fire
        foreach(greenyoshiyt, ObserveTime in greenyoshiyt_scarL_mode.ObserveQueue)
        {
            if(greenyoshiyt_scarL_mode.ObserveQueue.len() != 0)
            {
                if(greenyoshiyt != null)
                {   
                    if(!(greenyoshiyt.IsDead()) && !(greenyoshiyt.IsDying()))
                    {
                        if(greenyoshiyt.GetActiveWeapon() != null)
                        {
                            if(greenyoshiyt.GetActiveWeapon().GetClassname() != "weapon_rifle_desert")
                            {
                                DeleteShooterData(greenyoshiyt)
                            }
                            else
                            {
                                if(ObserveTime == 0)
                                {
                                    DeleteShooterData(greenyoshiyt)
                                }
                                else
                                {
                                    greenyoshiyt_scarL_mode.ObserveQueue[greenyoshiyt] -= 1
                                    local button = greenyoshiyt.GetButtonMask()

                                    //In shove that's not from weapon
                                    // Same index-0 pitfall as above: this must
                                    // compare against null, otherwise the very
                                    // player who is mid-burst reads as "not a
                                    // shooter" and their real shove is handled
                                    // on the wrong path.
                                    if(button & 2048 && greenyoshiyt_scarL_mode.Shooter.find(greenyoshiyt) == null && !(greenyoshiyt in greenyoshiyt_scarL_mode.PlayerAttack))
                                    {
                                        DeleteShooterData(greenyoshiyt)

                                        continue;
                                    }

                                    //In reload
                                    if(NetProps.GetPropInt(greenyoshiyt.GetActiveWeapon(), "m_bInReload") == 1)
                                    {
                                        DeleteShooterData(greenyoshiyt)
                                        continue;
                                    }

                                    if(!(button & 1) && NetProps.GetPropInt(greenyoshiyt.GetActiveWeapon(), "m_bInReload") != 1)
                                    {
                                        // ClientPrint(greenyoshiyt, DirectorScript.HUD_PRINTTALK, "\x05 Observer Queue: " + greenyoshiyt_scarL_mode.ObserveQueue[greenyoshiyt])

                                        //Letting the script know that you stopped firing in the queue
                                        if(greenyoshiyt_scarL_mode.ObserveQueue[greenyoshiyt] <= 8)
                                        {
                                            greenyoshiyt_scarL_mode.FoundSurvivors[greenyoshiyt].PredictMode = 1
                                            greenyoshiyt_scarL_mode.FoundSurvivors[greenyoshiyt].PredictModeTime = predictModeTick
                                        }

                                        greenyoshiyt_scarL_mode.FoundSurvivors[greenyoshiyt].Releasing = 1

                                        // THE SHOVE DELAY LIVES HERE.
                                        //
                                        // Parking the attack timers 100s in the
                                        // future is how the script holds a
                                        // semi-auto shot back. But m_flNextAttack
                                        // gates the SECONDARY attack as well, so
                                        // while it is parked the engine silently
                                        // drops the player's right-click too.
                                        //
                                        // Releasing only happens later, in the
                                        // Player-Think pass further down, so the
                                        // press that arrived this tick is already
                                        // gone by then: a tap reads as "nothing
                                        // happened" and a hold needs another tick.
                                        // That is the latency, and it is original
                                        // SCAR behaviour, not something the ADS
                                        // work introduced.
                                        //
                                        // If the player is shoving right now, do
                                        // not park the timers at all - let the
                                        // shove through on this very tick.
                                        // Same correction as the PlayerAttack pass:
                                        // a forced bit reads identically to a real
                                        // press, so the token has to be subtracted
                                        // before this can be called genuine.
                                        if((button & 2048) && !(greenyoshiyt.GetEntityIndex() in ::ScarAutoSyntheticShove))
                                        {
                                            ::ScarDbg("Observe: GENUINE right-click -> clearing any park NOW")
                                            ::ScarDbgAttackState(greenyoshiyt, "  before-clear")

                                            // Skipping the park is not enough on
                                            // its own: an earlier tick may have
                                            // already parked the timers 100s out,
                                            // and the player's shove would still
                                            // be gated by that stale value. Pull
                                            // them back to now so the shove is
                                            // accepted on this very tick.
                                            local nowT = Time()
                                            local wpn = greenyoshiyt.GetActiveWeapon()
                                            if(wpn != null)
                                            {
                                                if(NetProps.GetPropFloat(wpn, "m_flNextSecondaryAttack") > nowT)
                                                    NetProps.SetPropFloat(wpn, "m_flNextSecondaryAttack", nowT)
                                                if(NetProps.GetPropFloat(wpn, "m_flNextPrimaryAttack") > nowT)
                                                    NetProps.SetPropFloat(wpn, "m_flNextPrimaryAttack", nowT)
                                            }
                                            if(NetProps.GetPropFloat(greenyoshiyt, "m_flNextAttack") > nowT)
                                                NetProps.SetPropFloat(greenyoshiyt, "m_flNextAttack", nowT)

                                            ::ScarDbgAttackState(greenyoshiyt, "  after-clear")
                                            greenyoshiyt_scarL_mode.FoundSurvivors[greenyoshiyt].Releasing = 0
                                        }
                                        else
                                        {
                                            // v0.9.4 - PARK THE PRIMARY ONLY.
                                            //
                                            // This is the real cause of the dead
                                            // right-click, and the engine source
                                            // says exactly why:
                                            //
                                            //   CBasePlayer::ItemPostFrame()
                                            //     if (curtime < m_flNextAttack)
                                            //         weapon->ItemBusyFrame();
                                            //     else
                                            //         weapon->ItemPostFrame();
                                            //
                                            // and IN_ATTACK2 is only ever tested
                                            // inside the weapon's ItemPostFrame.
                                            // So m_flNextAttack is a MASTER gate:
                                            // parking it 100s out does not merely
                                            // delay the shove, it stops the engine
                                            // from ever looking at the shove
                                            // button. The old log shows this
                                            // parking happening 33 times while the
                                            // release path ran only 3 times.
                                            //
                                            // Holding back the next semi-auto
                                            // round only requires the weapon's own
                                            // m_flNextPrimaryAttack, which gates
                                            // PrimaryAttack() and nothing else.
                                            // Leaving m_flNextAttack alone keeps
                                            // the shove path - and reload - alive
                                            // with no change to firing behaviour.
                                            //
                                            // v6: logging restored. Dropping it in
                                            // v5 is why the last log could not show
                                            // whether this pass runs at all.
                                            ::ScarDbgOnce("obs_park",
                                                "Observe: parking PRIMARY only (master gate untouched)")
                                            NetProps.SetPropFloat(greenyoshiyt.GetActiveWeapon(), "m_flNextPrimaryAttack", Time() + 100.0);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                else
                {
                    DeleteShooterData(greenyoshiyt)
                }
            }
        }

        //Process players' attack and animation
        foreach(greenyoshiyt, PreviousAttack in greenyoshiyt_scarL_mode.PlayerAttack)
        {
            if(greenyoshiyt != null)
            {
                local NewAttack = PreviousAttack + custom_aspd
                local button = greenyoshiyt.GetButtonMask()
                local weapon = greenyoshiyt.GetActiveWeapon()
                if(weapon != null)
                {
                    // THIS is where a real right-click actually dies.
                    //
                    // The diagnostics settled it: "before-clear" never fired
                    // once (the Observe-pass branch is unreachable, an earlier
                    // "if(button & 2048) ... continue" short-circuits it), while
                    // this line ran 31 times in one session, each time pushing
                    // the timers ~0.133s further out.
                    //
                    // This block exists to drive the synthetic-shove animation,
                    // but it re-parks m_flNextSecondaryAttack unconditionally.
                    // While the player holds shove that parking is renewed every
                    // tick, so the engine never sees a frame where a secondary
                    // attack is allowed - the shove is starved rather than
                    // delayed once.
                    //
                    // Fix: when the player is genuinely holding shove, leave the
                    // secondary-attack gate open. The primary timers still get
                    // the value they need for the animation and the burst
                    // rhythm, so semi-auto behaviour is unchanged.
                    // v0.9.4 - the v0.9.3 test here was matching the WRONG thing.
                    //
                    // The engine ORs the forced bits into the command before the
                    // button state the script can read is assigned:
                    //
                    //   CPlayerMove::RunCommand()
                    //     ucmd->buttons |= player->m_afButtonForced;   // first
                    //   CBasePlayer::UpdateButtonState()
                    //     m_nButtons = nUserCmdButtonMask;             // then
                    //
                    // GetButtonMask() reads the result, so the shove this script
                    // synthesises for its own auto rhythm is indistinguishable
                    // from a right-click the player pressed. That is why the last
                    // log shows "real shove held" 84 times and the Observe-side
                    // "real shove detected" exactly 0 times: all 84 were the
                    // script recognising its own synthetic shove, and a genuine
                    // press was never actually identified even once.
                    //
                    // ::ScarAutoSyntheticShove is the token already set when the
                    // synthetic bit goes on. Subtracting it leaves only presses
                    // that really came from the player's mouse.
                    local synthetic = (greenyoshiyt.GetEntityIndex() in ::ScarAutoSyntheticShove)
                    local realShove = ((button & 2048) && !synthetic) ? true : false

                    if(realShove)
                    {
                        ::ScarDbg("PlayerAttack: GENUINE right-click -> secondary gate left open")
                        // Do not touch the secondary gate or the master gate at
                        // all; the shove is allowed to resolve this tick.
                    }
                    else
                    {
                        NetProps.SetPropFloat(weapon, "m_flNextSecondaryAttack", NewAttack);
                        NetProps.SetPropFloat(greenyoshiyt, "m_flNextAttack", NewAttack);
                    }
                    NetProps.SetPropFloat(weapon, "m_flNextPrimaryAttack", NewAttack);
                    NetProps.SetPropInt(greenyoshiyt, "m_afButtonForced", NetProps.GetPropInt(greenyoshiyt, "m_afButtonForced") &~ 2048)
                    // The synthetic shove is over; drop the token in the same
                    // place the forced bit is cleared so it can never linger
                    // and swallow a later real right-click.
                    if (greenyoshiyt.GetEntityIndex() in ::ScarAutoSyntheticShove)
                        delete ::ScarAutoSyntheticShove[greenyoshiyt.GetEntityIndex()]

                    //Replace the animation after shoving
                    local view_model = NetProps.GetPropEntity(greenyoshiyt, "m_hViewModel");

                    NetProps.SetPropIntArray(greenyoshiyt, "m_NetGestureSequence", 421, 0);
                    NetProps.SetPropIntArray(greenyoshiyt, "m_NetGestureActivity", 947, 0);
                    NetProps.SetPropFloatArray(greenyoshiyt, "m_NetGestureStartTime", PreviousAttack, 0);
                    NetProps.SetPropInt(view_model, "m_nLayer", 0);
                    NetProps.SetPropInt(view_model, "m_nLayerSequence", 6);
                    NetProps.SetPropFloat(view_model, "m_flLayerStartTime", PreviousAttack);

                    //removing shove sound, just in case
                    delete greenyoshiyt_scarL_mode.PlayerAttack[greenyoshiyt]
                    StopSoundOn("Weapon.Swing", greenyoshiyt)
                    StopSoundOn("Weapon.HitWorld", greenyoshiyt)
                }
            }
        }
        //Process shots
        // Iterate BACKWARDS. The body calls Shooter.remove(index) while the
        // list is being walked; going forwards makes the following element
        // shift into the slot just freed and be skipped for a whole tick,
        // adding another frame of latency per queued shooter.
        for(local index = greenyoshiyt_scarL_mode.Shooter.len() - 1; index >= 0; index--)
        {
            local greenyoshiyt = greenyoshiyt_scarL_mode.Shooter[index]
            if(greenyoshiyt != null)
            {
                local weapon = greenyoshiyt.GetActiveWeapon()
                if(weapon != null)
                {
                    if(weapon.GetClassname() == "weapon_rifle_desert")
                    {
                        local NextAttack = NetProps.GetPropFloat(greenyoshiyt.GetActiveWeapon(), "m_flNextPrimaryAttack")
                        local PreviousAttack = NextAttack - default_aspd
                        local NewAttack = PreviousAttack + custom_aspd


                        // Mark this shove as script-synthesised, then force it.
                        ::ScarAutoSyntheticShove[greenyoshiyt.GetEntityIndex()] <- true
                        NetProps.SetPropInt(greenyoshiyt, "m_afButtonForced", NetProps.GetPropInt(greenyoshiyt, "m_afButtonForced") | 2048)
                        greenyoshiyt_scarL_mode.PlayerAttack[greenyoshiyt] <- PreviousAttack

                        greenyoshiyt_scarL_mode.Shooter.remove(index)
                    }
                }

                //removing shove sound, just in case
                StopSoundOn("Weapon.Swing", greenyoshiyt)
                StopSoundOn("Weapon.HitWorld", greenyoshiyt)
            }
        }

        //Player Think
        foreach(greenyoshiyt, stat in greenyoshiyt_scarL_mode.FoundSurvivors)
        {
            if(greenyoshiyt_scarL_mode.FoundSurvivors.len() != 0)
            {
                //for players
                if(greenyoshiyt != null)
                {
                    local weapon = greenyoshiyt.GetActiveWeapon()
                    local button = greenyoshiyt.GetButtonMask()

                    //for weapon
                    if(weapon != null)
                    {
                        if(weapon.GetClassname() == "weapon_rifle_desert")
                        {
                            //Add scarL to control
                            if(!(weapon in greenyoshiyt_scarL_mode.Weapon_mode))
                            {
                                greenyoshiyt_scarL_mode.Weapon_mode[weapon] <- greenyoshiyt_scarL_mode.Const.default_fire_mode
                            }

                            //Switch mode
                            if((button & greenyoshiyt_scarL_mode.button_setting) && stat.Switching == 0)
                            {
                                local currentmode = greenyoshiyt_scarL_mode.GetScarLMode(weapon)
                                switch(currentmode)
                                {
                                    case 0:
                                        {
                                            greenyoshiyt_scarL_mode.Weapon_mode[weapon] = 1
                                            if(greenyoshiyt_scarL_mode.Const.show_switch_mode == 1)
                                            {
                                                ClientPrint(greenyoshiyt, 4, "DESERT RIFLE MODE: FULL AUTO")
                                            }
                                        }
                                        break;
                                    case 1:
                                        {
                                            greenyoshiyt_scarL_mode.Weapon_mode[weapon] = 0
                                            if(greenyoshiyt_scarL_mode.Const.show_switch_mode == 1)
                                            {
                                                ClientPrint(greenyoshiyt, 4, "DESERT RIFLE MODE: BURST")
                                            }
                                        }
                                        break;
                                }
                                stat.Switching = greenyoshiyt_scarL_mode.Const.switch_delay
                                PlaySwitchSound(currentmode, greenyoshiyt)
                            }
                            else if(stat.Switching > 0)
                            {
                                stat.Switching -= 1
                            }

                            //Predict
                            if(stat.PredictTime > 0)
                            {
                                NetProps.SetPropInt(greenyoshiyt, "m_bPredictWeapons", 0)
                                stat.PredictTime -= 1
                            }
                            else
                            {        
                                NetProps.SetPropInt(greenyoshiyt, "m_bPredictWeapons", 1)
                            }

                            //Mode Predict
                            if(stat.PredictModeTime > 0)
                            {
                                stat.PredictModeTime -= 1
                            }
                            else
                            {        
                                stat.PredictMode = 0
                            }

                            //For semi-auto
                            if(stat.Releasing == 1)
                            {
                                if((button & 1) || (button & 2048) || (button & 8192) || NetProps.GetPropInt(greenyoshiyt.GetActiveWeapon(), "m_iClip1") == 0)
                                {
                                    ::ScarDbg("PlayerThink: releasing park -> " + (stat.LastShot + 0.10)
                                        + (((stat.LastShot + 0.10) > Time()) ? " [STILL IN FUTURE +" + ((stat.LastShot + 0.10) - Time()) + "s]" : " [immediate]"))
                                    NetProps.SetPropFloat(greenyoshiyt.GetActiveWeapon(), "m_flNextPrimaryAttack", stat.LastShot + 0.10);
                                    NetProps.SetPropFloat(greenyoshiyt, "m_flNextAttack", stat.LastShot + 0.10);

                                    stat.Releasing = 0
                                }
                            }

                            // v0.9.4 - stale-gate safety net.
                            //
                            // Everything above only runs while Releasing == 1.
                            // If that state is lost while a park is still out -
                            // weapon swap, death, incap, fire-mode change, a
                            // dropped tick - the timers stay 100 seconds in the
                            // future and the player's right-click is dead until
                            // the round ends. This is the failure that survives
                            // every previous fix because it happens outside the
                            // path those fixes touch.
                            //
                            // A parked value is unmistakable: nothing in normal
                            // play schedules an attack more than a couple of
                            // seconds out. Anything beyond that is a leftover, so
                            // pull it back.
                            local nowT3 = Time()

                            // v6: trace every genuine right-click through this
                            // tick, and report what (if anything) is gating it.
                            // The previous logs only ever fired from inside the
                            // burst pipeline, which the last session shows never
                            // ran - so a shove pressed outside it was completely
                            // invisible. This runs every tick for every player
                            // holding a SCAR, independent of fire mode.
                            local syntheticNow = (greenyoshiyt.GetEntityIndex() in ::ScarAutoSyntheticShove)
                            if((button & 2048) && !syntheticNow)
                            {
                                ::ScarDbgOnce("think_real_shove",
                                    "PlayerThink: GENUINE right-click seen", 60)
                                ::ScarDbgShoveGates(greenyoshiyt, "PlayerThink")
                            }

                            if(NetProps.GetPropFloat(greenyoshiyt, "m_flNextAttack") > nowT3 + 5.0)
                            {
                                ::ScarDbg("PlayerThink: STALE master gate found -> clearing")
                                NetProps.SetPropFloat(greenyoshiyt, "m_flNextAttack", nowT3)
                            }
                            if(NetProps.GetPropFloat(weapon, "m_flNextSecondaryAttack") > nowT3 + 5.0)
                            {
                                ::ScarDbg("PlayerThink: STALE secondary gate found -> clearing")
                                NetProps.SetPropFloat(weapon, "m_flNextSecondaryAttack", nowT3)
                            }

                            
                        }
                    }
                }
            }
        }


    }
    //End of think functions


    function GetScarLMode(weapon)
    {
        local mode = 0;
        foreach(scarL, value in greenyoshiyt_scarL_mode.Weapon_mode)
        {
            if(scarL == weapon)
            {
                mode = value;
            }
        }
        return mode
    }
    function PlaySwitchSound(currentmode, greenyoshiyt)
    {
        switch(currentmode)
        {
            case 0:
                //Play Switch sound, taken from lasc's low ammo sound cue
                //doubling it because playing it once is a bit too quiet at times
                for(local i = 1; i <= 2; i++)
                {
                    local p_o = greenyoshiyt.GetOrigin();
                    local click_origin = Vector(p_o.x, p_o.y, p_o.z + 4) + greenyoshiyt.GetVelocity() * 0.15 // offset z upwards a little bit because for some reason the sound might be muffled in some cases. as for GetVelocity(), when the ambient_generic is spawned and the player is running, it may sound like it's coming from behind/somewhere else so we're compensating by doing this
                    
                    // applying Nescius' fix to hopefully prevent crashing/string table overflow
                    burst1 = (burst1 + 1) % 128;
                    local name = "greenyoshiyt_switch_sound2_" + burst1;
                    local snd_ent = SpawnEntityGroupFromTable(
                    {
                        a =
                        {
                            ambient_generic =
                            {
                                targetname = name,
                                origin = click_origin,
                                message = "greenyoshiyt/sliderelease1_scar.mp3",
                                radius = 385,
                                spawnflags = 48,
                                health = 10
                            }
                        }
                    });
                    EntFire(name, "PlaySound", "", 0);
                    EntFire(name, "Kill", "", 0);
                }
                break;
            case 1:
                for(local i = 1; i <= 2; i++)
                {
                    local p_o = greenyoshiyt.GetOrigin();
                    local click_origin = Vector(p_o.x, p_o.y, p_o.z + 4) + greenyoshiyt.GetVelocity() * 0.15 // offset z upwards a little bit because for some reason the sound might be muffled in some cases. as for GetVelocity(), when the ambient_generic is spawned and the player is running, it may sound like it's coming from behind/somewhere else so we're compensating by doing this
                    
                    // applying Nescius' fix to hopefully prevent crashing/string table overflow
                    burst2 = (burst2 + 1) % 128;
                    local name = "greenyoshiyt_switch_sound2_" + burst2;
                    local snd_ent = SpawnEntityGroupFromTable(
                    {
                        a =
                        {
                            ambient_generic =
                            {
                                targetname = name,
                                origin = click_origin,
                                message = "greenyoshiyt/sliderelease2_scar.mp3",
                                radius = 385,
                                spawnflags = 48,
                                health = 10
                            }
                        }
                    });
                    EntFire(name, "PlaySound", "", 0);
                    EntFire(name, "Kill", "", 0);
                }
                break;
        }
    }

    function OnGameEvent_weapon_fire(params)
    {
        local greenyoshiyt = GetPlayerFromUserID(params.userid);
        local weapon = greenyoshiyt.GetActiveWeapon()
        
        if(greenyoshiyt.GetZombieType() == 9 && weapon.GetClassname() == "weapon_rifle_desert" && greenyoshiyt_scarL_mode.Shooter.find(greenyoshiyt) == null)
        {
            local currentmode = greenyoshiyt_scarL_mode.GetScarLMode(weapon)
            if(IsPlayerABot(greenyoshiyt))
            {
                currentmode = greenyoshiyt_scarL_mode.Const.bot_default_fire_mode
            }

            // v6: the v5 log recorded 70 rifle_desert shots and not one single
            // Observe-pass line, which can only happen if this branch is not
            // being taken. Everything the shove fixes touch lives downstream of
            // it, so if the weapon is in BURST mode (currentmode 0) none of
            // that code has ever executed and the shove problem is somewhere
            // else entirely. Report the mode so this stops being a guess.
            ::ScarDbgOnce("firemode", "weapon_fire: fire mode = " + currentmode
                + (currentmode == 1 ? " (FULL AUTO - shove pipeline active)"
                                    : " (BURST - shove pipeline SKIPPED)"))

            if(currentmode == 1)
            {
                // Set Shove Penalty to 0 so you can always shove
                NetProps.SetPropInt(greenyoshiyt, "m_iShovePenalty", 0)
                
                if(IsPlayerABot(greenyoshiyt) == false)
                {
                    greenyoshiyt_scarL_mode.FoundSurvivors[greenyoshiyt].LastShot = Time()

                    //Extending the prediction
                    if(greenyoshiyt_scarL_mode.FoundSurvivors[greenyoshiyt].PredictModeTime > 0)
                    {
                        greenyoshiyt_scarL_mode.FoundSurvivors[greenyoshiyt].PredictModeTime = predictModeTick
                    }
                    
                    //Burst fire
                    if(!(greenyoshiyt in greenyoshiyt_scarL_mode.ObserveQueue))
                    {
                        //The first shot index is 0
                        greenyoshiyt_scarL_mode.FoundSurvivors[greenyoshiyt].First_fired_time = Time()
                        greenyoshiyt_scarL_mode.ObserveQueue[greenyoshiyt] <- observeTick
                    }
                    else if(greenyoshiyt_scarL_mode.ObserveQueue[greenyoshiyt] <= 7) //restart after a 11 ticks loop
                    {
                        greenyoshiyt_scarL_mode.FoundSurvivors[greenyoshiyt].First_fired_time = Time()
                        greenyoshiyt_scarL_mode.ObserveQueue[greenyoshiyt] = observeTick
                    }
                    else
                    {
                        local shot_to_predict = 2
                        local predict_mode = greenyoshiyt_scarL_mode.FoundSurvivors[greenyoshiyt].PredictMode
                        local starting_time = greenyoshiyt_scarL_mode.FoundSurvivors[greenyoshiyt].First_fired_time
                        local current_shot = greenyoshiyt_scarL_mode.GetCurrentShot(starting_time) //custom shot
                        local animation_shot = greenyoshiyt_scarL_mode.GetAnimationShot(starting_time) //the game's shot

                        switch(predict_mode)
                        {
                            case 0:
                                shot_to_predict = 2
                                break;
                            case 1: //Advanced
                                shot_to_predict = 3
                                break;
                        }

                        // ClientPrint(greenyoshiyt, DirectorScript.HUD_PRINTTALK, " Current Shot: " + current_shot)
                        // ClientPrint(greenyoshiyt, DirectorScript.HUD_PRINTTALK, "\x04 Predict mode: " + predict_mode)
                        // ClientPrint(greenyoshiyt, DirectorScript.HUD_PRINTTALK, "\x05 Shot to Predict: " + shot_to_predict)

                        if(current_shot == shot_to_predict)
                        {
                            greenyoshiyt_scarL_mode.FoundSurvivors[greenyoshiyt].PredictTime = predictTick
                        }
                    }
                }

                //removing shove sound, just in case
                StopSoundOn("Weapon.Swing", greenyoshiyt)
                StopSoundOn("Weapon.HitWorld", greenyoshiyt)

                //Append Shooter for control
                greenyoshiyt_scarL_mode.Shooter.append(greenyoshiyt);
            }
        }
    }
    //On map end, saving fire mode in players' inventory
    function OnGameEvent_map_transition(event)
	{
        //Data{player[1]{slot 1 = a}}
        local Data = "";
        local Data_2 = "";
        foreach(greenyoshiyt, stat in FoundSurvivors)
        {
            local userid = greenyoshiyt.GetPlayerUserId().tointeger()
            local playerInv = {}
            GetInvTable(greenyoshiyt, playerInv)
            foreach(slot, weapon in playerInv)
            {
                if(weapon != null)
                {
                    if(weapon.GetClassname() == "weapon_rifle_desert" && (weapon in greenyoshiyt_scarL_mode.Weapon_mode))
                    {
                        Data = Data + userid + "\n"
                    }
                }
            }
        }
		StringToFile("scarL_fire_mode_selector/saved_mode.txt", Data); //Save Full-Auto users
	}
    //For the custom full auto mdoe
    function GetCurrentShot(time)
    {
        local time_difference = Time() - time
        local result = 1
        //change mode
        if(time_difference <= 0.11)
        {
            result = 1
        }
        else if(time_difference > 0.11 && time_difference <= 0.21)
        {
            result = 2
        }
        else if(time_difference > 0.21 && time_difference <= 0.31)
        {
            result = 3
        }
        else
        {
            result = 4
        }
        
        return result
    }

    //For the normal burst mode
    function GetAnimationShot(time)
    {
        local time_difference = Time() - time
        local result = 1
        //change mode
        if(time_difference <= 0.08)
        {
            result = 1
        }
        else if(time_difference > 0.08 && time_difference <= 0.16)
        {
            result = 2
        }
        else if(time_difference > 0.16 && time_difference <= 0.28)
        {
            result = 3
        }
        else
        {
            result = 4
        }

        return result
    }

    //when player spawned
    function OnGameEvent_player_spawn(event)
    {
        local greenyoshiyt = GetPlayerFromUserID(event.userid)

        if(greenyoshiyt.GetClassname() == "player" && greenyoshiyt.IsSurvivor() && IsPlayerABot(greenyoshiyt) == false)
        {
            if(!(greenyoshiyt in ::greenyoshiyt_scarL_mode.FoundSurvivors))
            {
                ::greenyoshiyt_scarL_mode.FoundSurvivors[greenyoshiyt] <- greenyoshiyt_scarL_mode.default_player_stat
            }
        }
    }
    //player replaces a bot
    function OnGameEvent_bot_player_replace(event)
    {
        local greenyoshiyt = GetPlayerFromUserID(event.player)

        if(greenyoshiyt.IsSurvivor())
        {
            //Add player to the list
            if(!(greenyoshiyt in ::greenyoshiyt_scarL_mode.FoundSurvivors))
            {
                ::greenyoshiyt_scarL_mode.FoundSurvivors[greenyoshiyt] <- greenyoshiyt_scarL_mode.default_player_stat
            }
        }
    }
    //bot replaces a player
    function OnGameEvent_player_bot_replace(event)
    {
        local greenyoshiyt = GetPlayerFromUserID(event.player)
        local shou = GetPlayerFromUserID(event.bot)

        if(greenyoshiyt.IsSurvivor() && shou.IsSurvivor())
        {
            //Remove player from list
            if(greenyoshiyt in greenyoshiyt_scarL_mode.FoundSurvivors)
            {
                delete greenyoshiyt_scarL_mode.FoundSurvivors[greenyoshiyt]
            }
            if(greenyoshiyt in greenyoshiyt_scarL_mode.ObserveQueue)
            {
                delete greenyoshiyt_scarL_mode.ObserveQueue[greenyoshiyt]
            }
        }
    }

    function Init()
    {    
		::ScarAutoSyntheticShove.clear()
        EntFire("worldspawn", "RunScriptCode", "DirectorScript.greenyoshiyt_scarL_mode.SlowerInit()", 0.5, null)

        //Timer stuff
        ::greenyoshiyt_scarL_mode.createThinkTimer();
        //Precache Sounds
        ::greenyoshiyt_scarL_mode.PrecacheSwitchSound();
        //Settings Log
        ::greenyoshiyt_scarL_mode.SettingsLog();
        //Load saved mode
        ::greenyoshiyt_scarL_mode.LoadSavedMode();
    }
    function SlowerInit()
    {
        //Find player whenever the round starts
        local player = null;
        while(player = Entities.FindByClassname(player, "player"))
        {
            if(!(player in greenyoshiyt_scarL_mode.FoundSurvivors) && player.IsSurvivor() && IsPlayerABot(player) == false)
            {
                ::greenyoshiyt_scarL_mode.FoundSurvivors[player] <- default_player_stat
            }
        }

        EntFire("worldspawn", "RunScriptCode", "DirectorScript.greenyoshiyt_scarL_mode.FileSetup()", 1, null)
        EntFire("worldspawn", "RunScriptCode", "DirectorScript.greenyoshiyt_scarL_mode.LoadButton()", 2, null)
        EntFire("worldspawn", "RunScriptCode", "DirectorScript.greenyoshiyt_scarL_mode.LoadPlayerMode()", 9, null)
    }
    function SettingsLog()
    {   
        printl("================================[ScarL Mode Selector]===============================")
        printl("=====================================[Settings]=====================================")
        foreach(setting, value in greenyoshiyt_scarL_mode.Const)
        {
            printl("# " + setting + " = " + value)
        }
        printl("========================================================================================")
    }
    // function OnGameEvent_round_start(event)
    // {   
    //     EntFire("worldspawn", "RunScriptCode", "DirectorScript.greenyoshiyt_scarL_mode.SlowerInit()", 10, null)
    // }
    function PrecacheSwitchSound()
	{
		if(!IsSoundPrecached("greenyoshiyt/sliderelease1_scar.mp3")) PrecacheSound("greenyoshiyt/sliderelease1_scar.mp3");
        if(!IsSoundPrecached("greenyoshiyt/sliderelease2_scar.mp3")) PrecacheSound("greenyoshiyt/sliderelease2_scar.mp3");
	}

    //Setting File Setup
    function FileSetup()
    {
        
        local scarL_mode_selector = FileToString("scarL_fire_mode_selector/cfg.txt");
        if(scarL_mode_selector == null)
        {
            printl("[Scar-L Mode Selector] Missing setting files, creating one...")
            local Data = "";
            foreach(index, text in ::greenyoshiyt_scarL_mode.Setting)
            {
                Data = Data + text + "\n"
            }
            StringToFile("scarL_fire_mode_selector/cfg.txt", Data);
            ProcessFile();
        }
        else
        {
            ProcessFile();
        }

    }

    //Processing the file
    function ProcessFile()
    {
        local scarL_mode_selector = FileToString("scarL_fire_mode_selector/cfg.txt");
        //Return them as List, also stripping comments
        scarL_mode_selector = StringReplace(scarL_mode_selector, "\\r", "\n");
        scarL_mode_selector = StringReplace(scarL_mode_selector, "\\n\\n", "\n");
        scarL_mode_selector = StringReplace(scarL_mode_selector, "\\t", "");
        local value = split(scarL_mode_selector, "\n")
        //Loading
        foreach(setting in value)
        {
            try
            {
                local compiledscript = compilestring("greenyoshiyt_scarL_mode.Const." + setting);
                compiledscript();
            }
            catch(exception)
            {
                printl("[Scar-L Mode Selector] Unable to load settings");
            }
        }
    }
    //Weapon from the previous chapter/round
    function LoadSavedMode()
    {
        //Load full auto players
        local full_auto_user = FileToString("scarL_fire_mode_selector/saved_mode.txt");
        if(full_auto_user != null)
        {
            //Return them as List
            full_auto_user = StringReplace(full_auto_user, " ", "");
            local player_list = split(full_auto_user, "\n")
            foreach(player in player_list)
            {
                greenyoshiyt_scarL_mode.Full_auto_to_add.append(player.tointeger())
            }
        }
        EntFire("worldspawn", "RunScriptCode", "DirectorScript.greenyoshiyt_scarL_mode.ClearUsedData()", 5, null)
    }
    function LoadPlayerMode()
    {
        //Load player's mode
        foreach(greenyoshiyt, stat in greenyoshiyt_scarL_mode.FoundSurvivors)
        {
            local invTable = {}
            GetInvTable(greenyoshiyt, invTable)
            local mode = 0
            local userid = greenyoshiyt.GetPlayerUserId().tointeger()
            
            if(greenyoshiyt_scarL_mode.Full_auto_to_add.find(userid) != null)
            {
                foreach(full_auto_index, full_auto_user in greenyoshiyt_scarL_mode.Full_auto_to_add)
                {
                    if(full_auto_user == userid)
                    {
                        mode = 1
                    }
                }
            }
            
            foreach(slot, weapon in invTable)
            {
                if(weapon != null)
                {
                    if(weapon.GetClassname() == "weapon_rifle_desert")
                    {
                        greenyoshiyt_scarL_mode.Weapon_mode[weapon] <- mode
                    }
                }
            }
        }
    }
    function ClearUsedData()
    {
        local Clear = ""
        StringToFile("scarL_fire_mode_selector/saved_mode.txt", Clear);
    }

    //Replacing certain characters(I stole this from L4Lib, could have just used their Library as well but it seems like I only need this for now)
    function StringReplace(str, orig, replace)
    {
            local expr = regexp(orig);
            local ret = "";
            local pos = 0;
            local captures = null;
            
            while (captures = expr.capture(str, pos))
            {
                foreach (i, c in captures)
                {
                    ret += str.slice(pos, c.begin);
                    ret += replace;
                    pos = c.end;
                }
            }
            
            if (pos < str.len())
                ret += str.slice(pos);

            return ret;
    }
}
__CollectEventCallbacks(greenyoshiyt_scarL_mode, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);

::greenyoshiyt_scarL_mode.Init();
