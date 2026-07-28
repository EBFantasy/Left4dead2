if (!("ScarAutoSyntheticShoveUntil" in getroottable()))
    ::ScarAutoSyntheticShoveUntil <- {}

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

        if(greenyoshiyt_scarL_mode.Shooter.find(greenyoshiyt))
        {
            greenyoshiyt_scarL_mode.Shooter.remove(greenyoshiyt_scarL_mode.Shooter.find(greenyoshiyt))
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
                                    if(button & 2048 && !(greenyoshiyt_scarL_mode.Shooter.find(greenyoshiyt)) && !(greenyoshiyt in greenyoshiyt_scarL_mode.PlayerAttack))
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

                                        NetProps.SetPropFloat(greenyoshiyt.GetActiveWeapon(), "m_flNextPrimaryAttack", Time() + 100.0);
                                        NetProps.SetPropFloat(greenyoshiyt, "m_flNextAttack", Time() + 100.0);
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
                    NetProps.SetPropFloat(weapon, "m_flNextSecondaryAttack", NewAttack);
                    NetProps.SetPropFloat(weapon, "m_flNextPrimaryAttack", NewAttack);
                    NetProps.SetPropFloat(greenyoshiyt, "m_flNextAttack", NewAttack);
                    NetProps.SetPropInt(greenyoshiyt, "m_afButtonForced", NetProps.GetPropInt(greenyoshiyt, "m_afButtonForced") &~ 2048)

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
        foreach(index, greenyoshiyt in greenyoshiyt_scarL_mode.Shooter)
        {
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


                        ::ScarAutoSyntheticShoveUntil[greenyoshiyt.GetEntityIndex()] <- Time() + 0.35
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
                                    NetProps.SetPropFloat(greenyoshiyt.GetActiveWeapon(), "m_flNextPrimaryAttack", stat.LastShot + 0.10);
                                    NetProps.SetPropFloat(greenyoshiyt, "m_flNextAttack", stat.LastShot + 0.10);

                                    stat.Releasing = 0
                                }
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
		::ScarAutoSyntheticShoveUntil.clear()
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
