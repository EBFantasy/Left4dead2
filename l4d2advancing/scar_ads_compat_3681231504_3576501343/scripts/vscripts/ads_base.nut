//------------------------------------------------------
//     Author: 4512369781
//     Steam: https://steamcommunity.com/profiles/76561198052420500/myworkshopfiles/?appid=550
//------------------------------------------------------


/*
// https://github.com/IA-NanaNana/l4d2-aim-down-sight

添加更多activity可用在V模中

ConVars
	ads_holding_key "0" // Enable in ads by holding the zoom key.
	ads_pellet_scatter_modifier "0.5" // Pellet scatter modifier while in ads.
	ads_recoil_modifier "0.5" // Recoil modifier while in ads.
	ads_spread_modifier "0.1" // Spread modifier while in ads.

Activities list:
	ACT_VM_RELOAD 193 // 正常换弹夹
	ACT_VM_RELOAD_EMPTY 180 // 空膛换弹夹
	ACT_VM_DEPLOY 179 // 正常拔出武器
	ACT_VM_DRAW 181 // 空膛拔出武器上膛（一般为捡起后的动画）
	ACT_VM_HOLSTER 182 // 收起武器
	ACT_VM_FIDGET 184 // 检视
	ACT_VM_IDLE 183 // 正常待机
	ACT_VM_DRYFIRE 194 // 最后一发子弹打掉时转空仓挂机的动画
	ACT_VM_IDLE_LOWERED 212 // 空仓挂机
	ACT_VM_PRIMARYATTACK_LAYER 1252 // 开火

Aim down sight activities list:
	ACT_PRIMARY_VM_IDLE_TO_LOWERED 1879 // 进入机瞄
	ACT_PRIMARY_VM_IDLE 1873 // 机瞄-正常待机
	ACT_PRIMARY_VM_DRYFIRE 1878 // 机瞄-最后一发子弹打掉时转空仓待机的动画
	ACT_PRIMARY_VM_IDLE_LOWERED 1880 // 机瞄-空仓待机
	ACT_PRIMARY_VM_PRIMARYATTACK 1875 // 机瞄-开火
	ACT_PRIMARY_VM_SECONDARYATTACK 1876 // 机瞄-推
	ACT_PRIMARY_VM_RELOAD 1877 // 机瞄-换弹
	ACT_PRIMARY_VM_LOWERED_TO_IDLE 1881 // 退出机瞄

致MOD作者关于机瞄的制作说明：
	需要在正常开火动画中（ACT_VM_PRIMARYATTACK_LAYER）使用delta
*/
/*
New/Modify animations:
// Proposed by @Observeye, demo: https://steamcommunity.com/sharedfiles/filedetails/?id=3576614752
	ACT_PRIMARY_VM_RELOAD_EMPTY		// ads - empty reload
	ACT_PRIMARY_VM_MELEE			// ads - shove, replace ACT_PRIMARY_VM_SECONDARYATTACK
	ACT_VM_DRAW_LAYER				// draw weapon animation after switching, the first pikcup animation is ACT_VM_DEPLOY_LAYER
	ACT_VM_HOLSTER_LAYER			// put away weapon animation before switching, replace ACT_VM_HOLSTER

// Shotgun reload - @Observeye & @4512369781
	How to fix the start animations issues:
	Method 1
		modify the start animation in the qc file like this:
		$sequence "ads_reload" {
			...
			activity "ACT_PRIMARY_VM_RELOAD" 1
			...
		}
		$sequence "ads_reload_layer" {
			...
			activity "ACT_PRIMARY_VM_RELOAD_LAYER" 1
			numframes x // "x" according to animation' frames and fps, generally, you can just add the two numbers together
			...
		}
	Method 2
		default reload start animation: set weight to 9999 to avoid the game play another animations
		new added reload start animations: set ACT_VM_RELOAD_LAYER as activity name, and set sequence name as following names to distinguish them
	
	Activity names:
			start					loop					end
	ACT_VM_RELOAD_LAYER, ACT_VM_RELOAD_LOOP_LAYER, ACT_VM_RELOAD_END_LAYER			// hip - default reload, no changes
	ACT_VM_RELOAD_EMPTY_LAYER, ACT_VM_RELOAD_EMPTY_LOOP, ACT_VM_RELOAD_EMPTY_END	// hip - empty reload
	
	ACT_PRIMARY_VM_RELOAD_LAYER, ACT_PRIMARY_VM_RELOAD_LOOP, ACT_PRIMARY_VM_RELOAD_END						// ads - reload
	ACT_PRIMARY_VM_RELOAD_EMPTY_LAYER, ACT_PRIMARY_VM_RELOAD_EMPTY_LOOP, ACT_PRIMARY_VM_RELOAD_EMPTY_END	// ads - empty reload
	
	Sequence names:
		start
	reload_layer				// hip - default reload, no changes
	reload_empty_layer			// hip - empty reload
	
	ads_reload_layer			// ads - reload
	ads_reload_empty_layer		// ads - empty reload

// Dual pistols
	ACT_PRIMARY_VM_DRYFIRE_LEFT		// secondary last fire
	ACT_PRIMARY_VM_SECONDARYATTACK	// second fire, recommend use ACT_PRIMARY_VM_MELEE instead the old ads shove
	ACT_PRIMARY_VM_IDLE_LOWERED		// first pistol empty state

//////// 2026.03.23 v1.90 ////////
// Multi ads
	// ads_2nd
	ACT_SECONDARY_VM_IDLE
	ACT_SECONDARY_VM_IDLE_TO_NEXT	// trans to next ads mode
	ACT_SECONDARY_VM_PRIMARYATTACK	// fire
	...
	
	// ads_3rd
	ACT_TERTIARY_VM_IDLE
	ACT_TERTIARY_VM_IDLE_TO_NEXT	// trans to ads_1st mode
	ACT_TERTIARY_VM_PRIMARYATTACK	// fire
	...

// Melee hit/kill
	// hip
	ACT_VM_MELEE_HIT
	ACT_VM_MELEE_KILL
	
	// ads_1st
	ACT_PRIMARY_VM_MELEE_HIT
	ACT_PRIMARY_VM_MELEE_KILL
	
	// ads_2nd
	ACT_SECONDARY_VM_MELEE_HIT
	ACT_SECONDARY_VM_MELEE_KILL
	
	// ads_3rd
	ACT_TERTIARY_VM_MELEE_HIT
	ACT_TERTIARY_VM_MELEE_KILL

// Empty idle
	// hip
	ACT_VM_IDLE_EMPTY		// idle empty
	ACT_VM_IDLE_TRANS		// set fadein to 0. this fixed the anim issues when play reload_empty anim and transition idle_empty to idle in sametime
	ACT_VM_FIDGET_EMPTY		// empty inspect animation
	
	// ads_1st
	ACT_PRIMARY_VM_IDLE_EMPTY
	ACT_PRIMARY_VM_IDLE_TRANS
	
	// ads_2nd
	ACT_SECONDARY_VM_IDLE_EMPTY
	ACT_SECONDARY_VM_IDLE_TRANS
	
	// ads_3rd
	ACT_TERTIARY_VM_IDLE_EMPTY
	ACT_TERTIARY_VM_IDLE_TRANS

// Scope transform
	// hip
	ACT_VM_MIXED_ON		// scope transform anim
	ACT_VM_MIXED_OFF	// scope transform anim
	MIXED_ACT_VM_IDLE	// mixed on idle,
	MIXED_ACT_VM_PRIMARYATTACK // mixed on fire
	...
	
	// ads_1st
	ACT_PRIMARY_VM_MIXED_ON
	ACT_PRIMARY_VM_MIXED_OFF
	MIXED_ACT_PRIMARY_VM_IDLE	// mixed on idle
	...
	
	// ads_2nd
	ACT_SECONDARY_VM_MIXED_ON
	ACT_SECONDARY_VM_MIXED_OFF
	MIXED_ACT_SECONDARY_VM_IDLE	// mixed on idle
	...
	
	// ads_3rd
	ACT_TERTIARY_VM_MIXED_ON
	ACT_TERTIARY_VM_MIXED_OFF
	MIXED_ACT_TERTIARY_VM_IDLE	// mixed on idle
	...
	
	// if use $bodygroup, then don't need added "MIXED_" animations.
	// choose one of them based on your model, make sure that body group is in the third position or below.
	// this is because the first and second body group cannot be changed.
	
	// used to transform, like pineapple
	$bodygroup "scope_transform"
	{
		studio "mixed_off_scope_off_50.smd" // the number is a switching delay, its a percentage of the duration of the ACT_VM_MIXED_OFF animation
		studio "mixed_off_scope_on.smd"
		studio "mixed_on_scope_off_30.smd"	// the number is a switching delay, its a percentage of the duration of the ACT_VM_MIXED_ON animation
		studio "mixed_on_scope_on.smd"
	}
	
	// used to scaling
	$bodygroup "scope_variable"
	{
		studio "mixed_off_x1_50.smd"
		studio "mixed_on_x4_50.smd"
		//studio "mixed_off_x4.smd"	// optional - enabled if has transform anim
		//studio "mixed_on_x1.smd"	// optional - enabled if has transform anim
	}

// Lever action rifles - for non-shotgun weapon
				start											loop								end
	ACT_VM_RELOAD[_EMPTY]_START_LAYER				ACT_VM_RELOAD[_EMPTY]_LOOP				ACT_VM_RELOAD[_EMPTY]_END				// hip
	ACT_PRIMARY_VM_RELOAD[_EMPTY]_START_LAYER		ACT_PRIMARY_VM_RELOAD[_EMPTY]_LOOP		ACT_PRIMARY_VM_RELOAD[_EMPTY]_END		// ads_1st
	ACT_SECONDARY_VM_RELOAD[_EMPTY]_START_LAYER		ACT_SECONDARY_VM_RELOAD[_EMPTY]_LOOP	ACT_SECONDARY_VM_RELOAD[_EMPTY]_END		// ads_2nd
	ACT_TERTIARY_VM_RELOAD[_EMPTY]_START_LAYER		ACT_TERTIARY_VM_RELOAD[_EMPTY]_LOOP		ACT_TERTIARY_VM_RELOAD[_EMPTY]_END		// ads_3rd

// Shotgun magazine reload
	ACT_VM_RELOAD_MAGAZINE[_EMPTY]_LAYER				// hip
	ACT_PRIMARY_VM_RELOAD_MAGAZINE[_EMPTY]_LAYER		// ads_1st
	ACT_SECONDARY_VM_RELOAD_MAGAZINE[_EMPTY]_LAYER		// ads_2nd
	ACT_TERTIARY_VM_RELOAD_MAGAZINE[_EMPTY]_LAYER		// ads_3rd
*/


::L4D2Lxc_ADS <-
{
	Version = "v1.982"
	SettingsFilePath = "lxc/ads_base/settings.txt"
	InfoFilePath =
	{
		["lxc/ads_base/"] =
		{
			help_doc = "info.txt"
			activity_list = "animations.txt"
		},
	}
	
	BaseGameMode = Director.GetGameModeBase()
	TransitionData = {}
	RestoredData = false
	
	FOV =
	{
		origin = 0	// stored current fov before scaling
		scaling_end_time = 0	// reread the current fov from the console after the timeout
	}
	HumanSurvivors = {}
	GameStarted = false
	ADS_Plugins = false			// you can use them together, but why?
	LastThinkTime = 0
	DeltaTime = 0
	
	ActivateButton = 524288
	SmartHoldingKey = 0.5		// if holding the trigger button over this time, will switch to holding mode. // ads_holding_key "0" // Enable in ads by holding the zoom key.
	CombineButton = 32			// click to toggle aim mode while ads. holding the button to flip the scope if could.
	CombineBtnHolding = 0.5		// holding for a time to flip the scope. otherwise, it is considered a single click.
	AttackRetreatDelay = 1.5
	FovScaling = 0
	FovADS = 75
	FovDefault = -1
	RecoilFactor = 0.5			// same as ads_recoil_modifier "0.5" // Recoil modifier while in ads.
	SpreadReduce = 1			// cannot change spread & pellet scatter with vscript, but I will give you a laser sight.
									// ads_spread_modifier "0.1" // Spread modifier while in ads.
									// ads_pellet_scatter_modifier "0.5" // Pellet scatter modifier while in ads.
	
								// these console commands has hidden flag which mean they can only be modified for the host,
								// cannot set it for clients by "point_clientcommand" entity.
	HideLaserSight = 1			// r_draw_lasersight_1st_person
	HideBulletTracers = 0		// r_drawtracers_firstperson
	
	ForceEmptyReloadAnim = 1	// always play the empty reload anim (if has) after emptying the magazine whatever ADS, not effect pistol.
	ForceWalk = 0
	OffADS_InReload = 1
	OffADS_InShove = 2
	OffADS_Restart = 0
	OldDeployStyle = 0
	DisableInspect = 0
	InspectButton = 8192
	HolsterWeapon = 0
	ManualReload = 2
	PreventShotgunReloadFiring = 0
	IgnoreClient = 0
	StableMode = 1
	
	IsAttackButton = 0			// if use BUTTON_ATTACK, force holding mode.
	IsZoomButton = 0			// if use BUTTON_ZOOM, check zoom for sg552 & sniper.
	
	MODE_NONE = 0
	MODE_TOGGLE = 1
	MODE_HOLDING = 2
	
	BUTTON_ATTACK = 1
	BUTTON_JUMP = 2
	BUTTON_DUCK = 4
	BUTTON_FORWARD = 8
	BUTTON_BACK = 16
	BUTTON_USE = 32
	BUTTON_CANCEL = 64
	BUTTON_LEFT = 128
	BUTTON_RIGHT = 256
	BUTTON_MOVELEFT = 512
	BUTTON_MOVERIGHT = 1024
	BUTTON_SHOVE = 2048
	BUTTON_RUN = 4096
	BUTTON_RELOAD = 8192
	BUTTON_ALT1 = 16384
	BUTTON_ALT2 = 32768
	BUTTON_SCORE = 65536
	BUTTON_WALK = 131072
	BUTTON_ZOOM = 524288
	BUTTON_WEAPON1 = 1048576
	BUTTON_WEAPON2 = 2097152
	BUTTON_BULLRUSH = 4194304
	BUTTON_GRENADE1 = 8388608
	BUTTON_GRENADE2 = 16777216
	BUTTON_LOOKSPIN = 33554432
	
	Activity =
	{
		Deploy = {}
		Shove = {}
	}
	
	ReloadSets = // use only one set at a reload cycle, instead of randomly combining them
	{
		// what if the sequences in qc are not written in order?
		// who cares!
		/*
		[model] =
		{
			["ACT_VM_RELOAD"] = [ sequence id, sequence id ... ],
			["ACT_VM_RELOAD_LAYER"] = [ ... ],
			["ACT_VM_RELOAD_LOOP_LAYER"] = [ ... ],
			["ACT_VM_RELOAD_END_LAYER"] = [ ... ],
		},
		*/
	}
	
	ModelAnimations = // save each v_model's animations, easy to search
	{
		/*
		["v_models\v_rifle.mdl"] =
		{
			hip_idle = "ACT_VM_IDLE",
			mixed_hip_idle = "MIXED_ACT_VM_IDLE",
			ads_1st_idle = "ACT_PRIMARY_VM_IDLE",
			mixed_ads_1st_idle = "MIXED_ACT_PRIMARY_VM_IDLE",
			...
		},
		*/
	}
	
	
	function ADSListener(world = Entities.First())
	{
		local ThinkTime = Time(); // can not get the real global time in EntFire();
		DeltaTime = ThinkTime - LastThinkTime;
		LastThinkTime = ThinkTime;
		
		foreach (id, t in HumanSurvivors)
		{
			if (!t.player || !t.player.IsValid() || !t.ads_allowed)
				continue;
			
			local player = t.player;
			local isHost = t.ishost;
			local debug = t.debug;
			local button = t.button;
			local weapon = t.weapon;
			local body = t.body;
			local action = t.action;
			local anim = t.anim;
			
			local viewModel = NetProps.GetPropEntity(player, "m_hViewModel");
			weapon.current = player.GetActiveWeapon();
			if (!viewModel || !weapon.current || !weapon.current.IsValid() || IsPlayerEmptyHanded(player))
			{
				if (weapon.name)
				{
					if (debug.enable) printl("invalid wepaon：" + weapon.name);
					
					RestoreVisualEffects(isHost, viewModel, weapon, anim.idle);
					
					SetTableValueForAllKey(button, 0);
					SetTableValueForAllKey(weapon, 0);
					SetTableValueForAllKey(body, -1);
					SetTableValueForAllKey(action, 0);
					SetTableValueForAllKey(anim, -1);
				}
				
				continue;
			}
			
			// real global time, local only. // does it work online? hard to say.
			local Time = NetProps.GetPropFloat(viewModel, "m_flAnimTime"); // m_flPrevAnimTime m_flAnimTime
			
			local first_pickup = weapon.pickup && weapon.pickup == weapon.current;
			
			// holster
			if (!first_pickup && PutAwayWeapon(player, viewModel, action, weapon, anim, Time, debug))
				continue;
			
			local idle = viewModel.GetSequence();
			local aw = weapon.current;
			local clip = aw.Clip1();
			local item = GetWeaponItemName(aw);
			local model = aw.GetModelName().tolower();
			local weapon_changed = weapon.ent != aw || !weapon.name || weapon.name != item || !weapon.model || weapon.model != model;
			
			if (weapon_changed)
			{
				SaveModelAnimations(model, viewModel);
				
				if (debug.enable) printl("switch to new weapon: " + item + " - model: " + model);
				
				button.ads_active = false;
				
				if (weapon.fov_scaling)
					SmoothScalingFov(false, Time, 0.15, 0);
				
				if (HasLaserSightFlag(aw))
				{
					RemoveLaserSight(aw);
					UnSetLaserSightFlag(aw);
				}
				
				NetProps.SetPropInt(aw, "m_helpingHandState", 0);
				NetProps.SetPropInt(aw, "m_helpingHandTarget", -1);
				
				switch (clip)
				{
					case 0:
						// play empty reload anim if no bullet in the magazine after switch weapon
						NetProps.SetPropInt(aw, "m_reloadFromEmpty", 1);
						break;
					case 1:
						// fixed "m60 drop fix"
						if (item == "rifle_m60")
							weapon.last_bullet = 1;
						else if (item == "dual_pistols")
						{
							NetProps.SetPropInt(aw, "m_reloadFromEmpty", 1);
							break;
						}
					default:
						NetProps.SetPropInt(aw, "m_reloadFromEmpty", 0);
				}
				
				SetTableValueForAllKey(weapon, 0);
				SetTableValueForAllKey(body, -1);
				SetTableValueForAllKey(action, 0);
				SetTableValueForAllKey(anim, -1);
				
				weapon.ent = aw;
				weapon.name = item;
				weapon.model = model;
				weapon.type = GetWeaponTypeByItemName(item);
				weapon.mixed_mode = GetMixedFlag(aw);
				weapon.ads_aim_mode = "ads_1st_";
				
				RefreshWeaponState(weapon, anim);
				
				if (anim.idle != -1 && idle != anim.idle)
				{
					idle = anim.idle;
					viewModel.SetSequence(idle);
				}
				
				if (weapon.type == "shotgun" || weapon.lever_action_rifle)
					SaveMultiReloadSets(model, weapon.type == "shotgun", viewModel);
				
				if (weapon.magnifier && GetBodyGroupScope(viewModel, body.scope))
				{
					// bodygroup applied to viewModel not single weapon, also 'aw.SetBodygroup(bd_scope, 1)' not working like skin
					body.scope.parts_id = weapon.mixed_mode ? body.scope.mixed_on_scope_off : body.scope.mixed_off_scope_off;
					aw.SetBodygroup(body.scope.group_id, body.scope.parts_id);
					viewModel.SetBodygroup(body.scope.group_id, body.scope.parts_id);
					if (first_pickup && debug.enable)
						printl("Initial pickup, reset body group to " + body.scope.name + " - " + body.scope.group_id + " - " + body.scope.parts_id);
				}
				else
				{
					local weapon_body = NetProps.GetPropInt(aw, "m_nBody");
					if (weapon_body != NetProps.GetPropInt(viewModel, "m_nBody"))
						NetProps.SetPropInt(viewModel, "m_nBody", weapon_body);
				}
				
				// play ACT_VM_DRAW_LAYER, ACT_VM_DRAW anim
				if (!OldDeployStyle && !first_pickup)
				{
					if (debug.enable) printl("Draw weapon: " + item);
					
					SetWeaponDrawAnimation(player, aw, anim);
				}
			}
			
			if (debug.enable)
			{
				if (weapon_changed)
				{
					debug.last_layer_seq = -1;
					
					printl("\nCurrent Weapon: " + item + " - Model: " + model);
					
					local seqid = 0, seqname;
					while (seqid <= 255)
					{
						if ((seqname = viewModel.GetSequenceName(seqid)) != "Unknown")
						{
							printl("Sequence ID = " + seqid);
							printl("    Sequence Name = " + seqname);
							printl("    Activity Name = " + viewModel.GetSequenceActivityName(seqid));
							printl("    Animation Duration = " + viewModel.GetSequenceDuration(seqid));
						}
						else
							break;
						
						seqid++;
					}
					printl("There are " + seqid + " sequences in total");
				}
				
				local seq = NetProps.GetPropInt(viewModel, "m_nLayerSequence");
				if (debug.last_layer_seq != seq)
				{
					debug.last_layer_seq = seq;
					
					printl("\nCurrent Time: " + Time);
					printl("    Layer = " + NetProps.GetPropInt(viewModel, "m_nLayer"));
					printl("    Layer Sequence ID = " + seq);
					printl("    Sequence Name = " + viewModel.GetSequenceName(seq));
					printl("    Activity Name = " + viewModel.GetSequenceActivityName(seq));
					printl("    Animation Duration = " + viewModel.GetSequenceDuration(seq));
					printl("    Animation StartTime = " + NetProps.GetPropFloat(viewModel, "m_flLayerStartTime"));
				}
			}
			
			// any other issues except button detection?
			if (weapon.type == "Unknown" || anim.idle == -1) //!weapon.ads_able
				continue;
			
			// fix for no_fadein fix
			//if (idle == anim.idle_no_fadein || idle == anim.ads_idle_no_fadein)
			if (weapon.idle_state == 3)
			{
				weapon.idle_state = 0;
				idle = weapon.ads_on ? anim.ads_idle : anim.idle;
				viewModel.SetSequence(idle);
			}
			
			anim.is_new = false;
			anim.play_rate = GetAnimationsPlaybackRate(aw);
			local seq = NetProps.GetPropInt(viewModel, "m_nLayerSequence");
			local seq_start_time = NetProps.GetPropFloat(viewModel, "m_flLayerStartTime");
			if (anim.layer_seq == -1 || anim.layer_seq != seq || anim.layer_start_time != seq_start_time)
			{
				anim.is_new = true;
				anim.layer_seq = seq;
				anim.layer_start_time = seq_start_time;
				anim.layer_end_time = (seq_start_time > Time ? Time : seq_start_time) + viewModel.GetSequenceDuration(seq);
				anim.act_name = viewModel.GetSequenceActivityName(seq);
			}
			
			local scope = body.scope;
			local attack = action.attack;
			local reload = action.reload;
			local inspect = action.inspect;
			
			local isShove = IsShoveActivity(anim.act_name, item); if (isShove && anim.is_new) weapon.next_shove = NetProps.GetPropFloat(aw, "m_flNextSecondaryAttack");
			weapon.next_attack = NetProps.GetPropFloat(aw, "m_flNextPrimaryAttack");
			
			local isDeploy = IsDeployActivity(anim.act_name); // && Time <= weapon.next_attack;
			if (isDeploy && anim.is_new)
			{
				weapon.deploy_end = anim.layer_end_time;
				if (!weapon_changed) SetTableValueForAllKey(action, 0);
			}
			
			local isReload = ((weapon.reload = NetProps.GetPropInt(aw, "m_bInReload") > 0) || reload.fix);
			if (attack.next_firing <= 0 || attack.firing || (isShove && anim.is_new) || isReload) attack.next_firing = weapon.next_attack;
			local isIdle = Time >= attack.next_firing && !isReload;
			local isShoving = (weapon.next_shove + DeltaTime >= Time || isShove);
			
			local empty_clip = clip <= 0;
			weapon.clip1 = clip;
			if (weapon.manual_empty_reload)
			{
				if (empty_clip && !isReload)
				{
					if (!attack.firing && IsPlayerPressedButtonInFirstTime(player, BUTTON_ATTACK))
					{
						local clip_snd = weapon.type == "pistol" ? "Default.ClipEmpty_Pistol" : "Default.ClipEmpty_Rifle";
						EmitSoundOnClient(clip_snd, player);
					}
					
					if (IsPlayerPressingButton(player, BUTTON_RELOAD))
						weapon.next_relaod_time = Time + 1.1;
					
					if (weapon.next_relaod_time >= Time)
					{
						if (isIdle)
						{
							weapon.manual_reload_timestamp = 0;
							NetProps.SetPropFloat(aw, "m_flNextPrimaryAttack", (attack.next_firing = Time + 0.1));
						}
					}
					else if (weapon.next_attack <= Time + 0.3)
					{
						weapon.manual_reload_timestamp = Time + 3600;
						NetProps.SetPropFloat(aw, "m_flNextPrimaryAttack", weapon.manual_reload_timestamp);
					}
				}
				else if (weapon.manual_reload_timestamp)
				{
					if (weapon.manual_reload_timestamp == weapon.next_attack)
						NetProps.SetPropFloat(aw, "m_flNextPrimaryAttack", attack.next_firing);
					weapon.manual_reload_timestamp = 0;
				}
			}
			
			// detection combine button
			SwitchCombine(player, button, Time, debug.enable);
			
			// scope transform/scaling
			if (weapon.magnifier && button.combine_mode == 2 && !isReload && Time >= attack.next_firing)
			{
				if (ScopeTransform(viewModel, scope, weapon, anim, Time))
				{
					if (scope.transform_end > attack.next_firing)
					{
						isIdle = false;
						weapon.next_attack = scope.transform_end;
						attack.next_firing = weapon.next_attack;
						NetProps.SetPropFloat(aw, "m_flNextPrimaryAttack", weapon.next_attack);
					}
				}
			}
			
			// detection button
			SwitchADS(player, button, weapon, Time, debug.enable);
			
			// exit ads in these situations.
			if (weapon.ads_on &&
				(
					((!weapon.ads_able
					/*||																		// '<=' fix for weapon.type == "Unknown"
					(isDeploy && (anim.is_new || (button.mode == MODE_HOLDING && button.pressed_time <= seq_start_time)))*/
					||
					(IsZoomButton && weapon.type == "scope" && !NetProps.GetPropInt(player, "m_iFOV"))) && !(button.ads_active = false))
					||
					weapon.deploy_end - 0.2 > Time // not allowed ads during deploy anim
					||
					(idle == anim.idle && (Time < weapon.next_shove - 0.3 || (isReload && (reload.type == "reload" || reload.type == "reload_empty") && Time < reload.end_time - 0.35))) // not allowed ads during the "hip reload/shove" animations, because the animations looks bad
					||
					inspect.state >= 2 // stop inspect first
				)
			)
				weapon.ads_on = false;
			
			if (weapon.ads_on)
			{
				if (idle != anim.ads_idle) // ADS off
				{
					idle = anim.ads_idle;
					viewModel.SetSequence(idle);
					
					if (debug.enable) printl("enter ADS");
					
					if ((isIdle /*isShove ||*/) && anim.ads_in != -1)
					{
						SetViewAnimation(viewModel, anim.ads_in, 0, Time);
					}
					
					if (isHost && FovScaling && !weapon.fov_scaling)
					{
						SmoothScalingFov(true, Time);
						weapon.fov_scaling = 1;
					}
					
					if (SpreadReduce && !HasLaserSight(aw))
					{
						GiveLaserSight(aw);
						SetLaserSightFlag(aw);
					}
					
					weapon.ads_pause_until = 0;
					//SetTableValueForAllKey(attack, 0);
					inspect.state = 0;
				}
				weapon.hide_effects_until = Time;
				
				// switch to another ads mode
				if (button.combine_mode == 1)
				{
					local mode = weapon.ads_aim_mode;
					switch (mode)
					{
						case "ads_1st_":
							if (weapon.ads_2nd)
								mode = "ads_2nd_";
							break;
						case "ads_2nd_":
							if (weapon.ads_3rd)
							{
								mode = "ads_3rd_";
								break;
							}
						case "ads_3rd_":
						default:
							mode = "ads_1st_";
							break;
					}
					if (mode != weapon.ads_aim_mode)
					{
						if (debug.enable) printl("switch "+ weapon.ads_aim_mode + " to " + mode);
						
						if (anim.ads_toggle != -1 && !isReload && Time >= scope.transform_end)
							SetViewAnimation(viewModel, anim.ads_toggle, 0, Time);
						
						weapon.ads_aim_mode = mode;
						RefreshWeaponState(weapon, anim);
						
						idle = anim.ads_idle;
						viewModel.SetSequence(idle);
					}
				}
				
				if (scope.group_id != -1)
				{
					local bd_mode = weapon.mixed_mode ? scope.mixed_on_scope_off : (weapon.ads_aim_mode == "ads_1st_" ? scope.mixed_off_scope_on : scope.mixed_off_scope_off);
					if (bd_mode != viewModel.GetBodygroup(scope.group_id) || bd_mode != scope.parts_id)
					{
						if (scope.delay_switch <= 0)
							scope.delay_switch = Time + 0.1;
						scope.parts_id = bd_mode;
					}
				}
				
				if (ForceWalk)
				{
					local max = NetProps.GetPropFloat(player, "m_flMaxspeed");
					if (max > 85.0 && NetProps.GetPropEntity(player, "m_hGroundEntity") && !player.IsStaggering() && (player.GetButtonMask() & (BUTTON_FORWARD | BUTTON_BACK| BUTTON_MOVELEFT | BUTTON_MOVERIGHT)) && !(player.GetButtonMask() & (BUTTON_DUCK | BUTTON_WALK)))
					{
						local w_friction = Convars.GetFloat("sv_friction");
						if (w_friction > 0 && player.GetVelocity().Length2D() > 0.0)
						{
							button.force_walk = 1;
							player.OverrideFriction(0.1, max / (18.0 * w_friction)); // final speed is 90.
						}
					}
					else if (button.force_walk)
					{
						button.force_walk = 0;
						player.OverrideFriction(0, 1.0);
					}
				}
				
				// ads_idle_empty
				if (anim.ads_idle_empty != -1)
				{
					if (empty_clip && !isReload)
					{
						weapon.idle_state = 2;
						if (idle != anim.ads_idle_empty)
						{
							if (debug.enable) printl("switch to ads idle empty");
							
							RefreshWeaponState(weapon, anim);
							idle = anim.ads_idle;
							viewModel.SetSequence(idle);
						}
					}
					else if (weapon.idle_state /*anim.ads_idle == anim.ads_idle_empty*/)
					{
						if (debug.enable) printl("switch to ads idle");
						
						local last_state = weapon.idle_state;
						weapon.idle_state = 0;
						RefreshWeaponState(weapon, anim);
						
						if (last_state == 1 && anim.idle_no_fadein != -1) // last was anim.idle_empty
							idle = anim.idle_no_fadein;
						else // last was anim.ads_idle_empty
							idle = anim.ads_idle_no_fadein != -1 ? anim.ads_idle_no_fadein : anim.ads_idle;
						viewModel.SetSequence(idle);
						
						if (idle != anim.ads_idle)
							weapon.idle_state = 3;
					}
				}
			}
			else
			{
				if (idle != anim.idle) // ADS on
				//if (idle == anim.ads_idle) // ADS on
				{
					idle = anim.idle;
					viewModel.SetSequence(idle);
					
					if (debug.enable) printl("exit ADS");
					
					if ((isIdle /*|| isShove*/) && anim.ads_out != -1)
					{
						SetViewAnimation(viewModel, anim.ads_out, 0, Time);
					}
					
					if (weapon.fov_scaling)
					{
						SmoothScalingFov(false, Time);
						weapon.fov_scaling = 0;
					}
					
					if (HasLaserSightFlag(aw))
					{
						RemoveLaserSight(aw);
						UnSetLaserSightFlag(aw);
					}
					
					weapon.ads_off_time = 0;
					//SetTableValueForAllKey(attack, 0);
					inspect.state = 0;
					
					weapon.hide_effects_until = Time + 0.2;
				}
				
				if (scope.group_id != -1)
				{
					local bd_mode = weapon.mixed_mode ? scope.mixed_on_scope_off : scope.mixed_off_scope_off;
					if (bd_mode != viewModel.GetBodygroup(scope.group_id) || bd_mode != scope.parts_id)
					{
						if (scope.delay_switch <= 0)
							scope.delay_switch = Time;
						scope.parts_id = bd_mode;
					}
				}
				
				// play inspect animations
				if (weapon.inspect)
				{
					switch (inspect.state)
					{
						case 0:
							if (IsPlayerPressingButton(player, InspectButton, button.inspect_key_pressed) && !isReload)
							{
								local action_end = attack.next_firing;
								if (Time + 1 < action_end)
									break;
								
								inspect.state = 1;
								local fidget = (anim.inspect_empty == -1 || (anim.inspect != -1 && weapon.clip1 > 0)) ? anim.inspect : anim.inspect_empty;
								inspect.anim = viewModel.LookupSequence(fidget);
								inspect.next_time = action_end;
							}
							break;
						case 1:
							if (inspect.next_time != attack.next_firing)
								inspect.state = 0;
							else if (Time >= inspect.next_time)
							{
								inspect.state = 2;
								if (seq != inspect.anim || Time >= inspect.end_time)
								{
									SetViewAnimation(viewModel, inspect.anim, 0, Time);
									
									inspect.start_time = Time;
									inspect.end_time = Time + viewModel.GetSequenceDuration(inspect.anim);
									
									weapon.hide_effects_until = inspect.end_time;
								}
							}
							break;
						case 2:
							if (anim.layer_seq == inspect.anim && Time < inspect.end_time)
							{
								if (button.ads_active) // stop inspect first
								{
									inspect.state = 3;
									inspect.end_time = Time + 0.1;
									SetViewAnimation(viewModel, -1, 0, Time);
								}
								break;
							}
							/*if ((anim.layer_seq == inspect.anim || isShove) && Time < inspect.end_time)
							{
								if (isShove && Time >= weapon.next_shove) //!anim.is_new
								{
									SetViewAnimation(viewModel, inspect.anim, 0, inspect.start_time, anim);
								}
								break;
							}*/
						default:
							if (inspect.state == 3 && Time < inspect.end_time)
								break;
							
							inspect.state = 0;
							weapon.hide_effects_until = Time;
					}
				}
				
				// idle_empty
				if (anim.idle_empty != -1)
				{
					if (empty_clip && !isReload)
					{
						weapon.idle_state = 1;
						if (idle != anim.idle_empty)
						{
							if (debug.enable) printl("switch to hip idle empty");
							
							RefreshWeaponState(weapon, anim);
							idle = anim.idle;
							viewModel.SetSequence(idle);
						}
					}
					else if (weapon.idle_state /*anim.idle == anim.idle_empty*/)
					{
						if (debug.enable) printl("switch to hip idle");
						
						local last_state = weapon.idle_state;
						weapon.idle_state = 0;
						RefreshWeaponState(weapon, anim);
						
						if (last_state == 2 && anim.ads_idle_no_fadein != -1) // last was anim.ads_idle_empty
							idle = anim.ads_idle_no_fadein;
						else // last was anim.idle_empty
							idle = anim.idle_no_fadein != -1 ? anim.idle_no_fadein : anim.idle;
						viewModel.SetSequence(idle);
						
						if (idle != anim.idle)
							weapon.idle_state = 3;
					}
				}
			}
			
			if (scope.delay_switch > 0 && Time >= scope.delay_switch)
			{
				scope.delay_switch = 0;
				
				RefreshWeaponState(weapon, anim);
				idle = weapon.ads_on ? anim.ads_idle : anim.idle;
				viewModel.SetSequence(idle);
				
				if (scope.group_id != -1)
				{
					aw.SetBodygroup(scope.group_id, scope.parts_id);
					viewModel.SetBodygroup(scope.group_id, scope.parts_id);
				}
			}
			
			HandleVisualEffects(isHost, weapon, Time);
			
			// shove will cancel the reload anim while the crosshair is hidden, same for inspect anim.
			if (reload.fix)
			{
				if (weapon.type == "shotgun")
					HandleShotgunReload(player, viewModel, reload, weapon, anim, isShove, Time, debug);
				else if (weapon.lever_action_rifle)
					HandleLeverActionRifleReload(player, viewModel, reload, weapon, anim, isShove, Time, debug);
				
				if (reload.anim == anim.layer_seq)
				{
					if (Time > reload.end_time && reload.state == 3)
					{
						reload.fix = 0;
						attack.next_firing = 0; // reset
						
						// if rate is speed up, and the anim's time differs from the origin one, some weapon' reload animation may cause little glitch at the end.
						if (StableMode && reload.anim_rate != 1)
							NetProps.SetPropInt(viewModel, "m_nLayerSequence", -1);
					}
				}
				else if (/*isShove &&*/ Time < reload.end_time && (reload.state == 1 || reload.state == 3))
				{
					//if (!anim.is_new) // can not apply the fix at this moment
					// fix for Third-person Empty Pistol Reload Fix
																//Time >= anim.layer_end_time
					if ((Time == reload.start_time || (isShove && Time - anim.layer_start_time >= 0.1)) && !weapon.lever_action_rifle)
					{
						SetViewAnimation(viewModel, reload.anim, 0, reload.anim_start_time, anim);
						
						if (weapon.type != "shotgun" && reload.anim_rate != anim.play_rate)
						{
							reload.anim_rate = anim.play_rate;
							reload.anim_duration = (viewModel.GetSequenceDuration(reload.start_dur_anim) / reload.anim_rate) * reload.anim_dur_factor;
							reload.anim_end_time = reload.anim_start_time + reload.anim_duration;
							reload.end_time = reload.anim_end_time;
						}
					}
					if (reload.shotgun_magazine_reload && !weapon.reload && weapon.next_attack < reload.anim_end_time)
					{
						NetProps.SetPropFloat(aw, "m_flNextPrimaryAttack", reload.anim_end_time);
						NetProps.SetPropFloat(player, "m_flNextAttack", reload.anim_end_time);
					}
				}
				else if (reload.state == 3)
				{
					reload.fix = 0;
					attack.next_firing = 0;
				}
				
				// some weapon like shotgun not reset this
				if (!weapon.reload && aw.Clip1() > 0 && NetProps.GetPropInt(aw, "m_reloadFromEmpty") > 0)
				{
					NetProps.SetPropInt(aw, "m_reloadFromEmpty", 0);
				}
			}
			
			// fix deploy anim when pressing func_button_timed
			if (weapon.lever_action_rifle_deploy_fix)
			{
				if (isDeploy)
				{
					if (!anim.is_new)
					{
						weapon.lever_action_rifle_deploy_fix = 0;
						if (weapon.lever_action_rifle_deploy_fix_layer == 3)
						{
							SetViewAnimation(viewModel, -1, 3, Time);
						}
					}
				}
				else if (!anim.is_new)
				{
					if (weapon.lever_action_rifle_deploy_fix_layer == 3 && !isShove)
					{
						SetViewAnimation(viewModel, -1, 3, Time);
					}
					else if (anim.deploy != -1)
					{
						local deploy = viewModel.LookupSequence(anim.deploy);
						SetViewAnimation(viewModel, deploy, 0, weapon.lever_action_rifle_deploy_fix);
					}
					weapon.lever_action_rifle_deploy_fix = 0;
				}
			}
			
			// prevent cover the test anim when ads enabled
			if (/*!weapon.ads_on ||*/ debug.anim_start_time == seq_start_time || !anim.is_new)
				continue;
			
			local curAnim = -1;
			switch (anim.act_name)
			{
				case "ACT_VM_SECONDARYATTACK_LAYER": // dual pistols secondary
					if (attack.firing)
					{
						if (!weapon.ads_on || (curAnim = anim.ads_fire_left) == -1)
							curAnim = anim.fire_left;
					}
					break;
				// vanilla pistol has this anim
				case "ACT_VM_DRYFIRE": // after firing the last bullet, for dual pistols is the second to last bullet.
					if (attack.firing)
					{
						if (weapon.ads_on)
						{
							if ((curAnim = anim.ads_dryfire) == -1)
								curAnim = anim.ads_fire;
						}
						else
						{
							curAnim = anim.dryfire;
						}
						
						/*if (weapon.ads_on)
						{
							if ((curAnim = anim.ads_dryfire) == -1 && item == "dual_pistols" && clip > 0 && (curAnim = anim.ads_fire) == -1)
							{
								if (anim.act_name == anim.dryfire || (curAnim = anim.dryfire) == -1)
									curAnim = anim.fire;
							}
						}
						else
						{
							curAnim = anim.dryfire;
						}*/
						
						/*// if not has ads anim and it's dual pistols, then cancel the current anim
						if ((curAnim = anim.ads_dryfire) == -1 && item == "dual_pistols" && clip > 0)
						{
							if ((curAnim = anim.ads_fire) == -1)
								curAnim = anim.fire;
						}*/
						
						/*if ((curAnim = viewModel.LookupSequence("ACT_PRIMARY_VM_DRYFIRE")) == -1 && item == "dual_pistols" && clip > 0)
						{
							if ((curAnim = viewModel.LookupSequence("ACT_PRIMARY_VM_PRIMARYATTACK")) == -1)
								curAnim = viewModel.LookupSequence("ACT_VM_PRIMARYATTACK_LAYER");
						}*/
						
						/*if (item != "dual_pistols") //&& item != "pistol" && item != "pistol_magnum"
						{
							// plugin not use this animation, should i ignore?
							// COD16 X16 Replace Pistol ADS: https://steamcommunity.com/sharedfiles/filedetails/?id=3517418116
							curAnim = viewModel.LookupSequence("ACT_PRIMARY_VM_DRYFIRE");
						}
						else if (aw.Clip1() > 0)
						{
							// fix dual pistols models like this: [ADS]Glock19 Gen4 & Glock19x: https://steamcommunity.com/sharedfiles/filedetails/?id=3500840858
							// that happened when dual pistols left one bullet
							// "ACT_VM_DRYFIRE_LEFT" after empty the magazine
							curAnim = viewModel.LookupSequence("ACT_VM_PRIMARYATTACK_LAYER");
						}*/
					}
					break;
				case "ACT_VM_DRYFIRE_LEFT": // after dual pistols firing the last bullet
					if (attack.firing)
					{
						if (weapon.ads_on)
						{
							if ((curAnim = anim.ads_dryfire_left) == -1)
								curAnim = anim.ads_fire_left;
						}
						else
						{
							curAnim = anim.dryfire_left;
						}
						
						/*if (weapon.ads_on)
						{
							curAnim = anim.ads_dryfire_left; // maybe use new anim name?
							//curAnim = viewModel.LookupSequence("ACT_PRIMARY_VM_DRYFIRE_LEFT"); // maybe use new anim name?
							if (curAnim == -1 && (curAnim = anim.ads_fire_left) == -1)
								anim.act_name == anim.dryfire_left;
						}
						else
						{
							curAnim = anim.dryfire_left;
						}*/
					}
					break;
				case "ACT_VM_IDLE_LOWERED": // after dual pistols firing the second to last bullet, the first pistol keep this anim until used up ammo or reload.
					if (attack.firing)
					{
						if (!weapon.ads_on || (curAnim = anim.ads_dual_right_empty) == -1)
							curAnim = anim.dual_right_empty;
						
						/*if (weapon.ads_on)
						{
							// if not has ads anim and it's dual pistols, then cancel the current anim
							if ((curAnim = anim.ads_dual_right_empty) == -1 && item == "dual_pistols" && clip > 0)
								NetProps.SetPropInt(viewModel, "m_nLayerSequence", -1);
						}
						else
						{
							curAnim = anim.dual_right_empty;
						}*/
						
						/*if ((curAnim = viewModel.LookupSequence("ACT_PRIMARY_VM_IDLE_LOWERED")) == -1 && item == "dual_pistols" && clip > 0)
							NetProps.SetPropInt(viewModel, "m_nLayerSequence", -1);*/
						
						/*if (aw.Clip1() > 0) // fix again
							NetProps.SetPropInt(viewModel, "m_nLayerSequence", -1);
						else if (item != "dual_pistols") //&& item != "pistol" && item != "pistol_magnum"
							curAnim = viewModel.LookupSequence("ACT_PRIMARY_VM_IDLE_LOWERED"); // plugin not use this animation, should i ignore?
						*/
					}
					break;
				case "ACT_VM_PRIMARYATTACK_LAYER":
				case "ACT_VM_SHOOT_SNIPER_LAYER": // hunting rifle
					if (attack.firing)
					{
						// trigger "ACT_VM_DRYFIRE" for rifle
						local is_dryfire = weapon.clip1 <= 0 || weapon.dryfire;
						if (is_dryfire)
						{
							weapon.dryfire = 0;
							curAnim = weapon.ads_on ? anim.ads_dryfire : anim.dryfire;
						}
						
						if (weapon.ads_on && curAnim == -1)
						{
							// grenade launcher can't play the anim: https://steamcommunity.com/sharedfiles/filedetails/?id=3570295570
							// well, that's bc the ads fire anim are broken.
							// the plugin even not try play it, how did he know it's broken?
							if (!StableMode || item != "grenade_launcher")
							{
								/*local ads_fire = anim.act_name == "ACT_VM_SECONDARYATTACK_LAYER" ? "ACT_PRIMARY_VM_SECONDARYATTACK" : ((clip % 2) == 0 ? "ACT_PRIMARY_VM_DOUBLEFIRE" : "ACT_PRIMARY_VM_PRIMARYATTACK");
								curAnim = viewModel.LookupSequence(ads_fire);
								if (curAnim == -1 && ads_fire == "ACT_PRIMARY_VM_DOUBLEFIRE")
									curAnim = viewModel.LookupSequence("ACT_PRIMARY_VM_PRIMARYATTACK");*/
								
								curAnim = anim.ads_fire_dbl != -1 && (weapon.clip1 % 2) == 0 ? anim.ads_fire_dbl : anim.ads_fire;
							}
						}
						
						if (curAnim == -1 && (!is_dryfire || (curAnim = anim.dryfire) == -1))
							curAnim = anim.fire_dbl != -1 && (weapon.clip1 % 2) == 0 ? anim.fire_dbl : anim.fire;
						
						/*if (curAnim == -1)
						{
							if (weapon.ads_on)
							{
								if (!StableMode || item != "grenade_launcher")
								{
									//local ads_fire = anim.act_name == "ACT_VM_SECONDARYATTACK_LAYER" ? "ACT_PRIMARY_VM_SECONDARYATTACK" : ((clip % 2) == 0 ? "ACT_PRIMARY_VM_DOUBLEFIRE" : "ACT_PRIMARY_VM_PRIMARYATTACK");
									//curAnim = viewModel.LookupSequence(ads_fire);
									//if (curAnim == -1 && ads_fire == "ACT_PRIMARY_VM_DOUBLEFIRE")
									//	curAnim = viewModel.LookupSequence("ACT_PRIMARY_VM_PRIMARYATTACK");
									
									curAnim = anim.ads_fire_dbl != -1 && (clip % 2) == 0 ? anim.ads_fire_dbl : anim.ads_fire;
									if (curAnim == -1)
										curAnim = anim.fire_dbl != -1 && (clip % 2) == 0 ? anim.fire_dbl : anim.fire;
								}
							}
							else
							{
								curAnim = anim.fire_dbl != -1 && (clip % 2) == 0 ? anim.fire_dbl : anim.fire;
							}
						}*/
					}
					break;
				case "ACT_VM_MELEE_LAYER":
				case "ACT_VM_MELEE_SNIPER_LAYER":
					if (weapon.ads_on)
					{
						curAnim = anim.ads_shove;
						
						//if (IsCloseADSWhileAction("shove", weapon, weapon.next_attack))
						if (IsCloseADSWhileAction("shove", weapon, weapon.next_shove, player))
							weapon.ads_on = false;
					}
					else
					{
						curAnim = anim.shove;
					}
					
					/*if ((curAnim = viewModel.LookupSequence("ACT_PRIMARY_VM_MELEE")) == -1 && item != "dual_pistols")
						curAnim = viewModel.LookupSequence("ACT_PRIMARY_VM_SECONDARYATTACK");
					
					if (IsCloseADSWhileAction("shove", weapon, weapon.next_attack))
						weapon.ads_on = false;*/
					
					/*
					// no idea why can't play the "ACT_PRIMARY_VM_MELEE" & "ACT_PRIMARY_VM_SECONDARYATTACK" animations on some models, just do nothing.
					// that's bc set wrong value to fadeout, 10 is too fast, the anim end immediately, why not use the same value as "ACT_VM_MELEE_LAYER"?
					// in fact, the plugin don't play "ACT_PRIMARY_VM_SECONDARYATTACK" even the sequence is, and always play the "ACT_VM_MELEE_LAYER" anim.
					if ((curAnim = viewModel.LookupSequence("ACT_PRIMARY_VM_SECONDARYATTACK")) != -1)
						{
							// fixed the "ACT_PRIMARY_VM_SECONDARYATTACK" anim, not sure for this, i only test on these weapons
							// EFT M4A1 Carbine OBMOD (M16): https://steamcommunity.com/sharedfiles/filedetails/?id=3479177891
							// EFT AK-103 OBMOD (AK): https://steamcommunity.com/sharedfiles/filedetails/?id=3488802501
							NetProps.SetPropInt(viewModel, "m_nLayer", 0);
						}
					*/
					break;
				case "ACT_VM_ITEMPICKUP_EXTEND_LAYER":
				case "ACT_VM_ITEMPICKUP_EXTEND_SNIPER_LAYER":	// hunting_rifle
					curAnim = anim.looking_item_extend;
					break;
				case "ACT_VM_ITEMPICKUP_LOOP_LAYER":
				case "ACT_VM_ITEMPICKUP_LOOP_SNIPER_LAYER":		// hunting_rifle
					curAnim = anim.looking_item_loop;
					break;
				case "ACT_VM_ITEMPICKUP_RETRACT_LAYER":
				case "ACT_VM_ITEMPICKUP_RETRACT_SNIPER_LAYER":	// hunting_rifle
					curAnim = anim.looking_item_retract;
					break;
				case "ACT_VM_HELPINGHAND_EXTEND_LAYER":
				case "ACT_VM_HELPINGHAND_EXTEND_SNIPER_LAYER":	// hunting_rifle
					curAnim = anim.helping_hand_extend;
					break;
				case "ACT_VM_HELPINGHAND_LOOP_LAYER":
				case "ACT_VM_HELPINGHAND_LOOP_SNIPER_LAYER":	// hunting_rifle
					curAnim = anim.helping_hand_loop;
					break;
				case "ACT_VM_HELPINGHAND_RETRACT_LAYER":
				case "ACT_VM_HELPINGHAND_RETRACT_SNIPER_LAYER":	// hunting_rifle
					curAnim = anim.helping_hand_retract;
					break;
			}
			
			if (attack.firing)
			{
				attack.firing = 0;
				if (weapon.ads_on && RecoilFactor != 1 && typeof(attack.last_recoil) == "Vector")
				{
					local PunchAngle = NetProps.GetPropVector(player, "localdata.m_Local.m_vecPunchAngle");
					local gunRecoil = PunchAngle.x - attack.last_recoil.x;
					if (debug.enable) printl("current recoil = " + (PunchAngle - attack.last_recoil));
					
					gunRecoil *= RecoilFactor;
					local Recoil = Vector(attack.last_recoil.x + gunRecoil, PunchAngle.y, PunchAngle.z);
					NetProps.SetPropVector(player, "localdata.m_Local.m_vecPunchAngle", Recoil);
				}
			}
			
			if (curAnim == anim.act_name || curAnim == -1)
				continue;
			
			
			if ((curAnim = viewModel.LookupSequence(curAnim)) != anim.layer_seq)
			{
				local AniParity = NetProps.GetPropInt(viewModel, "m_nAnimationParity") + 1;
				if (AniParity > 7)
					AniParity = 0;
				NetProps.SetPropInt(viewModel, "m_nAnimationParity", AniParity);
			}
			
			SetViewAnimation(viewModel, curAnim, -1, -1, anim);
			
			if (debug.enable) printl("set " + (weapon.ads_on ? "ads" : "hip") + " anim: " + anim.act_name + " - " + curAnim);
		}
		
		if (GameStarted)
			DoEntFire("!self", "RunScriptCode", "::L4D2Lxc_ADS.ADSListener();", 0.001, null, world);
	}
	
	function SplitActivityName(name, rexpMixed = regexp(@"^MIXED_"), rexpIdle = regexp(@"ACT_VM_|ACT_PRIMARY_VM_|ACT_SECONDARY_VM_|ACT_TERTIARY_VM_"))
	{
		if (name == "")
			return false;
		
		local mixed = rexpMixed.search(name) != null ? "mixed_" : "";
		
		local idle_mode = null;
		local findidle = rexpIdle.search(name);
		if (findidle != null)
		{
			switch (name.slice(findidle.begin, findidle.end))
			{
				case "ACT_VM_":
					idle_mode = "hip_"; break;
				case "ACT_PRIMARY_VM_":
					idle_mode = "ads_1st_"; break;
				case "ACT_SECONDARY_VM_":
					idle_mode = "ads_2nd_"; break;
				case "ACT_TERTIARY_VM_":
					idle_mode = "ads_3rd_"; break;
			}
		}
		
		if (!idle_mode)
			return false;
		
		local anim_name = null;
		local islayer = false;
		switch (name.slice(findidle.end))
		{
			case "IDLE":
			case "IDLE_SNIPER":
				anim_name = "idle"; break;
			case "IDLE_EMPTY":
				anim_name = "idle_empty"; break;
			
			// set fadein to 0. this fixed the anim issues when play reload_empty anim and transition idle_empty to idle in sametime
			case "IDLE_TRANS":
				anim_name = "idle_no_fadein"; break;
			
			case "IDLE_TO_LOWERED":
				anim_name = "to_ads"; break;
			case "LOWERED_TO_IDLE":
				anim_name = "to_hip"; break;
			case "IDLE_TO_NEXT":
				anim_name = "to_next"; break;
			
			case "MIXED_OFF":
				anim_name = "scope_on"; break;
			case "MIXED_ON":
				anim_name = "scope_off"; break;
			
			case "FIDGET_LAYER": islayer = true;
			case "FIDGET":
				anim_name = "inspect"; break;
			case "FIDGET_EMPTY_LAYER": islayer = true;
			case "FIDGET_EMPTY":
				anim_name = "inspect_empty"; break;
			
			// unused animations, but...
			case "PICKUP_LAYER": case "PICKUP_SNIPER_LAYER":
			case "PICKUP":
				Activity.Deploy[name] <- 1; break;
			
			case "DEPLOY_LAYER": case "DEPLOY_SNIPER_LAYER": islayer = true;
			case "DEPLOY":
				anim_name = "deploy"; Activity.Deploy[name] <- 1; break;
			case "DRAW_LAYER": islayer = true;
			case "DRAW":
				anim_name = "draw"; Activity.Deploy[name] <- 1; break;
			case "HOLSTER_LAYER":
				anim_name = "holster"; break;
			
			case "MELEE_LAYER": case "MELEE_SNIPER_LAYER": islayer = true;
			case "MELEE":
				anim_name = "shove"; Activity.Shove[name] <- 1; break;
			case "MELEE_HIT":
				anim_name = "shove_hit"; Activity.Shove[name] <- 1; break;
			case "MELEE_KILL":
				anim_name = "shove_kill"; Activity.Shove[name] <- 1; break;
			
			case "PRIMARYATTACK_LAYER": case "SHOOT_SNIPER_LAYER": islayer = true;
			case "PRIMARYATTACK":
				anim_name = "fire"; break;
			case "DOUBLEFIRE":
				anim_name = "fire_dbl"; break;
			case "DRYFIRE":
				anim_name = "dryfire"; break;
			
			case "SECONDARYATTACK_LAYER": islayer = true;
			case "SECONDARYATTACK":
				anim_name = "fire_left"; break;
			case "DRYFIRE_LEFT":
				anim_name = "dryfire_left"; break;
			case "IDLE_LOWERED":
				anim_name = "dual_right_empty"; break;
			
			case "RELOAD_LAYER": case "RELOAD_SNIPER_LAYER": islayer = true;
			case "RELOAD":
				anim_name = "reload"; break;
			case "RELOAD_EMPTY_LAYER": islayer = true;
			case "RELOAD_EMPTY":
				anim_name = "reload_empty"; break;
			
			case "RELOAD_START_LAYER": islayer = true;
			case "RELOAD_START":
				anim_name = "reload_start"; break;
			case "RELOAD_EMPTY_START_LAYER": islayer = true;
			case "RELOAD_EMPTY_START":
				anim_name = "reload_empty_start"; break;
			
			case "RELOAD_MAGAZINE_LAYER": islayer = true;
			case "RELOAD_MAGAZINE":
				anim_name = "reload_magazine"; break;
			case "RELOAD_MAGAZINE_EMPTY_LAYER": islayer = true;
			case "RELOAD_MAGAZINE_EMPTY":
				anim_name = "reload_magazine_empty"; break;
			case "RELOAD_LOOP_LAYER": islayer = true;
			case "RELOAD_LOOP":
				anim_name = "reload_loop"; break;
			case "RELOAD_END_LAYER": islayer = true;
			case "RELOAD_END":
				anim_name = "reload_end"; break;
			case "RELOAD_EMPTY_LOOP_LAYER": islayer = true;
			case "RELOAD_EMPTY_LOOP":
				anim_name = "reload_empty_loop"; break;
			case "RELOAD_EMPTY_END_LAYER": islayer = true;
			case "RELOAD_EMPTY_END":
				anim_name = "reload_empty_end"; break;
			
			case "ITEMPICKUP_EXTEND_LAYER": case "ITEMPICKUP_EXTEND_SNIPER_LAYER": islayer = true;
			case "ITEMPICKUP_EXTEND":
				anim_name = "looking_item_extend"; break;
			case "ITEMPICKUP_LOOP_LAYER": case "ITEMPICKUP_LOOP_SNIPER_LAYER": islayer = true;
			case "ITEMPICKUP_LOOP":
				anim_name = "looking_item_loop"; break;
			case "ITEMPICKUP_RETRACT_LAYER": case "ITEMPICKUP_RETRACT_SNIPER_LAYER": islayer = true;
			case "ITEMPICKUP_RETRACT":
				anim_name = "looking_item_retract"; break;
			
			case "HELPINGHAND_EXTEND_LAYER": case "HELPINGHAND_EXTEND_SNIPER_LAYER": islayer = true;
			case "HELPINGHAND_EXTEND":
				anim_name = "helping_hand_extend"; break;
			case "HELPINGHAND_LOOP_LAYER": case "HELPINGHAND_LOOP_SNIPER_LAYER": islayer = true;
			case "HELPINGHAND_LOOP":
				anim_name = "helping_hand_loop"; break;
			case "HELPINGHAND_RETRACT_LAYER": case "HELPINGHAND_RETRACT_SNIPER_LAYER": islayer = true;
			case "HELPINGHAND_RETRACT":
				anim_name = "helping_hand_retract"; break;
		}
		if (!anim_name)
			return false;
		
		return { name = (mixed + idle_mode + anim_name).tolower(), cover = islayer }
	}
	
	function SaveModelAnimations(model, viewModel)
	{
		if (model in ModelAnimations || model == "" || !viewModel || !viewModel.IsValid())
			return;
		
		ModelAnimations[model] <- {};
		local group = ModelAnimations[model];
		
		local seqid = 0, seqname;
		while (seqid <= 255)
		{
			if ((seqname = viewModel.GetSequenceName(seqid)) != "Unknown")
			{
				local actname = viewModel.GetSequenceActivityName(seqid).toupper();
				local anim = SplitActivityName(actname);
				if (anim && (!(anim.name in group) || anim.cover))
					group[anim.name] <- actname;
			}
			else
				break;
			
			seqid++;
		}
		//__DumpScope(2, group);
	}
	
	function GetAnimationByIdle(AnimGroup, mixed, idle_mode, anim_name, idle_fallback)
	{
		// first check the complete name
		local key = mixed + idle_mode + anim_name;
		if (key in AnimGroup)
			return AnimGroup[key];
		
		// then remove "mixed"
		if (mixed != "")
		{
			key = idle_mode + anim_name;
			if (key in AnimGroup)
				return AnimGroup[key];
			
			// check fallback
			if (idle_mode == idle_fallback)
				return -1;
			
			key = mixed + idle_fallback + anim_name;
			if (key in AnimGroup)
				return AnimGroup[key];
		}
		
		// check fallback
		if (idle_mode == idle_fallback)
			return -1;
		
		key = idle_fallback + anim_name;
		if (key in AnimGroup)
			return AnimGroup[key];
		
		return -1;
	}
	
	// update when switch weapon, toggle mixed, switch ads mode
	function RefreshWeaponState(weapon, anim)
	{
		if (!(weapon.model in ModelAnimations) || weapon.type == "Unknown")
			return;
		
		local _is_new = anim.is_new, _seq = anim.layer_seq, _seq_start_time = anim.layer_start_time, _seq_end_time = anim.layer_end_time, _act_name = anim.act_name, _play_rate = anim.play_rate;
		
		SetTableValueForAllKey(anim, -1);
		
		// restore
		anim.is_new = _is_new;
		anim.layer_seq = _seq;
		anim.layer_start_time = _seq_start_time;
		anim.layer_end_time = _seq_end_time;
		anim.act_name = _act_name;
		anim.play_rate = _play_rate;
		
		
		local animgroup = ModelAnimations[weapon.model];
		local mixed = weapon.mixed_mode ? "mixed_" : "";
		local hip_idle_mode = "hip_";
		
		// save sequence id
		anim.idle = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "idle", hip_idle_mode);
		if (anim.idle == -1)
		{
			weapon.type = "Unknown";
			return;
		}
		
		anim.idle = weapon.ent.LookupSequence(anim.idle);
		anim.idle_empty = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "idle_empty", hip_idle_mode);
		anim.idle_no_fadein = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "idle_no_fadein", hip_idle_mode);
		if (anim.idle_empty != -1) anim.idle_empty = weapon.ent.LookupSequence(anim.idle_empty);
		if (anim.idle_no_fadein != -1) anim.idle_no_fadein = weapon.ent.LookupSequence(anim.idle_no_fadein);
		
		// no longer save sequence id, using activity name, some of them maybe has multi-anim
		anim.scope_on = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "scope_on", hip_idle_mode);
		anim.scope_off = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "scope_off", hip_idle_mode);
		
		anim.inspect = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "inspect", hip_idle_mode);
		anim.inspect_empty = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "inspect_empty", hip_idle_mode);
		anim.deploy = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "deploy", hip_idle_mode);		// (ACT_VM_)DEPLOY_LAYER
		anim.draw = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "draw", hip_idle_mode);			// (ACT_VM_)DRAW_LAYER
		anim.holster = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "holster", hip_idle_mode);	// (ACT_VM_)HOLSTER_LAYER
		
		anim.looking_item_extend = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "looking_item_extend", hip_idle_mode);
		anim.looking_item_loop = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "looking_item_loop", hip_idle_mode);
		anim.looking_item_retract = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "looking_item_retract", hip_idle_mode);
		anim.helping_hand_extend = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "helping_hand_extend", hip_idle_mode);
		anim.helping_hand_loop = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "helping_hand_loop", hip_idle_mode);
		anim.helping_hand_retract = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "helping_hand_retract", hip_idle_mode);
		
		anim.shove = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "shove", hip_idle_mode);
		anim.shove_hit = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "shove_hit", hip_idle_mode);
		anim.shove_kill = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "shove_kill", hip_idle_mode);
		anim.fire = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "fire", hip_idle_mode);
		anim.fire_dbl = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "fire_dbl", hip_idle_mode);			// weapon has two barrels
		anim.dryfire = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "dryfire", hip_idle_mode);
		if (weapon.name == "dual_pistols")
		{
			anim.fire_left = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "fire_left", hip_idle_mode);			// dual pistols 2nd fire
			anim.dryfire_left = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "dryfire_left", hip_idle_mode);		// dual pistols fire last
			anim.dual_right_empty = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "dual_right_empty", hip_idle_mode);		// dual pistols first pistol out of ammo idle (ACT_VM_IDLE_LOWERED)
		}
		anim.reload = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "reload", hip_idle_mode);
		anim.reload_empty = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "reload_empty", hip_idle_mode);
		if (weapon.type == "shotgun")
		{
			anim.reload_magazine = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "reload_magazine", hip_idle_mode);
			anim.reload_magazine_empty = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "reload_magazine_empty", hip_idle_mode);
			if (anim.reload_magazine != -1)
			{
				anim.reload = anim.reload_magazine;
				anim.reload_empty = anim.reload_magazine_empty;
			}
			else
			{
				anim.reload_loop = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "reload_loop", hip_idle_mode);
				anim.reload_end = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "reload_end", hip_idle_mode);
				anim.reload_empty_loop = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "reload_empty_loop", hip_idle_mode);
				anim.reload_empty_end = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "reload_empty_end", hip_idle_mode);
			}
		}
		// lever action rifle
		else if ((anim.reload_start = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "reload_start", hip_idle_mode)) != -1)
		{
			anim.reload_loop = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "reload_loop", hip_idle_mode);
			anim.reload_end = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "reload_end", hip_idle_mode);
			anim.reload_empty_start = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "reload_empty_start", hip_idle_mode);
			anim.reload_empty_loop = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "reload_empty_loop", hip_idle_mode);
			anim.reload_empty_end = GetAnimationByIdle(animgroup, mixed, hip_idle_mode, "reload_empty_end", hip_idle_mode);
		}
		
		// ads
		local ads_idle_mode = weapon.ads_aim_mode;
		local ads_idle_fallback = "ads_1st_";
		
		weapon.ads_1st = GetAnimationByIdle(animgroup, mixed, "ads_1st_", "idle", "ads_1st_") != -1;
		weapon.ads_able = weapon.ads_1st && anim.idle != -1;
		if (weapon.ads_able)
		{
			anim.ads_idle = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "idle", ads_idle_mode);
			anim.ads_idle_empty = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "idle_empty", ads_idle_mode);
			anim.ads_idle_no_fadein = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "idle_no_fadein", ads_idle_mode);
			if (anim.ads_idle != -1) anim.ads_idle = weapon.ent.LookupSequence(anim.ads_idle);
			if (anim.ads_idle_empty != -1) anim.ads_idle_empty = weapon.ent.LookupSequence(anim.ads_idle_empty);
			if (anim.ads_idle_no_fadein != -1) anim.ads_idle_no_fadein = weapon.ent.LookupSequence(anim.ads_idle_no_fadein);
			
			anim.ads_scope_on = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "scope_on", ads_idle_fallback);
			anim.ads_scope_off = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "scope_off", ads_idle_fallback);
			
			anim.ads_in = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "to_ads", ads_idle_fallback);
			anim.ads_out = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "to_hip", ads_idle_fallback);
			anim.ads_toggle = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "to_next", ads_idle_mode);		// toggle to another ads mode
			if (anim.ads_in != -1) anim.ads_in = weapon.ent.LookupSequence(anim.ads_in);
			if (anim.ads_out != -1) anim.ads_out = weapon.ent.LookupSequence(anim.ads_out);
			if (anim.ads_toggle != -1) anim.ads_toggle = weapon.ent.LookupSequence(anim.ads_toggle);
			
			anim.ads_shove = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "shove", ads_idle_fallback);
			anim.ads_shove_hit = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "shove_hit", ads_idle_fallback);
			anim.ads_shove_kill = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "shove_kill", ads_idle_fallback);
			anim.ads_fire = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "fire", ads_idle_fallback);
			anim.ads_fire_dbl = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "fire_dbl", ads_idle_fallback);			// weapon has two barrels
			anim.ads_dryfire = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "dryfire", ads_idle_fallback);
			if (weapon.name == "dual_pistols")
			{
				anim.ads_fire_left = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "fire_left", ads_idle_fallback);			// dual pistols 2nd fire
				anim.ads_dryfire_left = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "dryfire_left", ads_idle_fallback);		// dual pistols fire last
				anim.ads_dual_right_empty = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "dual_right_empty", ads_idle_fallback);		// dual pistols first pistol out of ammo idle (ACT_VM_IDLE_LOWERED)
			}
			anim.ads_reload = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "reload", ads_idle_fallback);
			anim.ads_reload_empty = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "reload_empty", ads_idle_fallback);
			if (weapon.type == "shotgun")
			{
				anim.ads_reload_magazine = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "reload_magazine", ads_idle_fallback);
				anim.ads_reload_magazine_empty = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "reload_magazine_empty", ads_idle_fallback);
				if (anim.ads_reload_magazine != -1)
				{
					anim.ads_reload = anim.ads_reload_magazine;
					anim.ads_reload_empty = anim.ads_reload_magazine_empty;
				}
				else
				{
					anim.ads_reload_loop = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "reload_loop", ads_idle_fallback);
					anim.ads_reload_end = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "reload_end", ads_idle_fallback);
					anim.ads_reload_empty_loop = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "reload_empty_loop", ads_idle_fallback);
					anim.ads_reload_empty_end = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "reload_empty_end", ads_idle_fallback);
				}
			}
			// lever action rifle
			else if ((anim.ads_reload_start = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "reload_start", ads_idle_fallback)) != -1)
			{
				
				anim.ads_reload_loop = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "reload_loop", ads_idle_fallback);
				anim.ads_reload_end = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "reload_end", ads_idle_fallback);
				anim.ads_reload_empty_start = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "reload_empty_start", ads_idle_fallback);
				anim.ads_reload_empty_loop = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "reload_empty_loop", ads_idle_fallback);
				anim.ads_reload_empty_end = GetAnimationByIdle(animgroup, mixed, ads_idle_mode, "reload_empty_end", ads_idle_fallback);
			}
		}
		
		if (weapon.idle_state && weapon.idle_state != 3)
		{
			if (anim.idle_empty != -1)
				anim.idle = anim.idle_empty;
			if (anim.ads_idle_empty != -1)
				anim.ads_idle = anim.ads_idle_empty;
		}
		weapon.manual_empty_reload = ManualReload == 1 || (ManualReload == 2 && (anim.idle_empty != -1 || anim.ads_idle_empty != -1));
		
		// any inspect anim?
		weapon.inspect = IsAllowInspect() && (anim.inspect != -1 || anim.inspect_empty != -1);
		
		// has pineapple magnifier?
		weapon.magnifier = (anim.scope_on != -1 && anim.scope_off != -1) || (anim.ads_scope_on != -1 && anim.ads_scope_off != -1);
		
		// is lever action rifle?
		weapon.lever_action_rifle = anim.reload_start != -1;
		
		if (weapon.ads_able)
		{
			weapon.ads_2nd = GetAnimationByIdle(animgroup, mixed, "ads_2nd_", "idle", "ads_2nd_") != -1;
			weapon.ads_3rd = GetAnimationByIdle(animgroup, mixed, "ads_3rd_", "idle", "ads_3rd_") != -1;
			
			weapon.ads_shove = anim.ads_shove != -1;
			weapon.ads_reload = anim.ads_reload != -1;
			weapon.ads_reload_empty = anim.ads_reload_empty != -1;
		}
	}
	
	function IsReloadAnimation(name, isShotgun, rexpReload = regexp(@"_VM_RELOAD"), rexpShotgun = regexp(@"MAGAZINE|RELOAD|LOOP|END"), rexpLever = regexp(@"START|LOOP|END"))
	{
		if (name == "" || rexpReload.search(name) == null)
			return false;
		
		if (isShotgun)
			return rexpShotgun.search(name) != null;
		
		return rexpLever.search(name) != null;
	}
	
	function SaveMultiReloadSets(model, isShotgun, viewModel)
	{
		if (model in ReloadSets || model == "" || !viewModel || !viewModel.IsValid())
			return;
		
		ReloadSets[model] <- {};
		local group = ReloadSets[model];
		
		local seqid = 0, seqname;
		while (seqid <= 255)
		{
			if ((seqname = viewModel.GetSequenceName(seqid)) != "Unknown")
			{
				local actname = viewModel.GetSequenceActivityName(seqid).toupper();
				if (IsReloadAnimation(actname, isShotgun))
				{
					if (!(actname in group))
						group[actname] <- [];
					group[actname].append(seqid);
				}
			}
			else
				break;
			
			seqid++;
		}
		//__DumpScope(2, group);
	}
	
	// fov_desired ( def. "90" ) min. 75.000000 max. 120.000000
	function SmoothScalingFov(zoom, Time, on_time = 0.15, off_time = 0.1)
	{
		// fix quick switch ads <--> hip
		local max_time = on_time > off_time ? on_time : off_time;
		local max_count = ceil(max_time * 100.0);
		local count = 1;
		
		local cur_fov = Convars.GetFloat("fov_desired");
		local cmd = "";
		
		if (zoom)
		{
			if (Time > FOV.scaling_end_time)
				FOV.origin = cur_fov;
			
			local factor = on_time != 0 ? (FOV.origin - FovADS) / (on_time * 100.0) : 0;
			if (factor > 0.01)
			{
				for (local d_fov = cur_fov - factor; count < max_count && d_fov > FovADS; d_fov -= factor)
				{
					count++;
					cmd += ("wait;fov_desired " + d_fov + ";");
				}
			}
			while (count <= max_count)
			{
				count++;
				cmd += "wait;fov_desired " + FovADS + ";";
			}
		}
		else
		{
			local factor = off_time != 0 ? (FOV.origin - FovADS) / (off_time * 100.0) : 0;
			if (factor > 0.01)
			{
				for (local d_fov = cur_fov + factor; count < max_count && d_fov < FOV.origin; d_fov += factor)
				{
					count++;
					cmd += ("wait;fov_desired " + d_fov + ";");
				}
			}
			while (count <= max_count)
			{
				count++;
				cmd += "wait;fov_desired " + FOV.origin + ";";
			}
		}
		
		if (cmd != "")
		{
			FOV.scaling_end_time = Time + max_time + 0.1;
			SendToServerConsole(cmd);
		}
	}
	
	function PutAwayWeapon(player, viewModel, action, weapon, anim, Time, debug)
	{
		if (!HolsterWeapon)
			return false;
		
		local holster = action.holster;
		if (holster.state > 0 && weapon.ent == weapon.current)
		{
			if (Time >= holster.end_time)
			{
				holster.state = 2;
				local next_wp = holster.next_weapon;
				if (next_wp && next_wp.IsValid() && player.SwitchToItem(next_wp.GetClassname()))
				{
					weapon.current = next_wp;
					if (debug.enable) printl("allow switch to: " + weapon.current);
				}
				else
				{
					if (debug.enable) printl("can not switch to: " + next_wp);
					weapon.ent = 0;
					NetProps.SetPropEntity(player, "m_hActiveWeapon", null);
					player.SwitchToItem(weapon.current.GetClassname());
				}
			}
			else
				return true; //continue;
		}
		// play holster anim
		// holster.state != 2 --- prevent switch until put away weapon
		// holster.state == 0 --- double switch interrupt holster
		if (holster.state == 0 && weapon.ent != weapon.current && weapon.ent && weapon.ent.IsValid())
		{
			local holster_ani = anim.holster; //weapon.ent.LookupSequence("ACT_VM_HOLSTER_LAYER");
			if (holster_ani != -1 && player.SwitchToItem(weapon.ent.GetClassname()))
			{
				if (debug.enable) printl("Holster weapon: " + weapon.name);
				
				holster_ani = weapon.ent.LookupSequence(holster_ani);
				local next_switch = SetWeaponHolsterAnimation(player, weapon.ent, holster_ani, action.reload.anim_layer);
				if (debug.enable) printl("next_switch: " + next_switch);
				if (next_switch <= Time)
					player.SwitchToItem(weapon.current.GetClassname());
				else if (holster.state)
				{
					local idle = viewModel.GetSequence();
					local last_idle = (weapon.ads_on && anim.ads_idle != -1) ? anim.ads_idle : anim.idle;
					if (last_idle != -1 && idle != last_idle)
						viewModel.SetSequence(last_idle);
					
					//NetProps.SetPropFloat(viewModel, "m_flLayerStartTime", holster.start_time);
					holster.end_time = next_switch;
					holster.next_weapon = weapon.current;
					
					if (debug.enable) printl("putting away weapon, not allow switch");
					return true; //continue;
				}
				else
				{
					local idle = viewModel.GetSequence();
					local last_idle = (weapon.ads_on && anim.ads_idle != -1) ? anim.ads_idle : anim.idle;
					if (last_idle != -1 && idle != last_idle)
						viewModel.SetSequence(last_idle);
					
					holster.state = 1;
					holster.start_time = NetProps.GetPropFloat(viewModel, "m_flLayerStartTime");
					holster.end_time = next_switch;
					holster.next_weapon = weapon.current;
					
					if (debug.enable) printl("start holster");
					return true; //continue;
				}
			}
		}
		
		return false;
	}
	
	function SetMixedDelay(viewModel, scope, count, max, rexpDelay = regexp(@"_(\d+)"))
	{
		for (local i = 0; i <= count; i++)
		{
			local name = viewModel.GetBodygroupPartName(scope.group_id, i).tolower();
			local results = rexpDelay.capture(name);
			if (results)
			{
				local delay = name.slice(results[1].begin, results[1].end).tointeger() * 0.01;
				if (i <= max) //name.find("mixed_off") == 0)
				{
					scope.off_delay = delay;
				}
				else //if (name.find("mixed_on") == 0)
				{
					scope.on_delay = delay;
				}
			}
		}
	}
	
	function GetBodyGroupScope(viewModel, scope)
	{
		local bd_scope = viewModel.FindBodygroupByName("scope_transform");
		if (bd_scope != -1)
		{
			scope.name = "scope_transform";
			scope.group_id = bd_scope;
			scope.parts_id = 0;
			scope.mixed_off_scope_off = 0;
			scope.mixed_off_scope_on = 1;
			scope.mixed_on_scope_off = 2;
			scope.mixed_on_scope_on = 3;
			scope.off_delay = 0.5;
			scope.on_delay = 0.3;
			
			scope.fix_mixed_off_scope_off = scope.mixed_off_scope_off;
			scope.fix_mixed_on_scope_off = scope.mixed_on_scope_off;
			scope.fix_mixed_on_scope_on = scope.mixed_on_scope_on;
			
			SetMixedDelay(viewModel, scope, 3, 1);
		}
		else if ((bd_scope = viewModel.FindBodygroupByName("scope_variable")) != -1)
		{
			scope.name = "scope_variable";
			scope.group_id = bd_scope;
			scope.parts_id = 0;
			scope.mixed_off_scope_off = 0;	// mixed_off_scope_x1
			scope.mixed_on_scope_on = 1;	// mixed_on_scope_x4
			scope.mixed_off_scope_on = 0;	// mixed_off_scope_x4
			scope.mixed_on_scope_off = 1;	// mixed_on_scope_x1
			scope.off_delay = 0.5;
			scope.on_delay = 0.5;
			
			scope.fix_mixed_off_scope_off = scope.mixed_on_scope_on;
			scope.fix_mixed_on_scope_off = scope.mixed_off_scope_off;
			scope.fix_mixed_on_scope_on = scope.mixed_off_scope_off;
			if (viewModel.GetBodygroupPartName(bd_scope, 3) != "")
			{
				scope.fix_mixed_off_scope_off = 2;	// mixed_off_scope_on
				scope.fix_mixed_on_scope_off = 3;	// mixed_on_scope_off
				scope.fix_mixed_on_scope_on = 3;	// mixed_on_scope_off
			}
			
			SetMixedDelay(viewModel, scope, 1, 0);
		}
		
		return bd_scope != -1;
	}
	
	function ScopeTransform(viewModel, scope, weapon, anim, Time)
	{
		if (weapon.mixed_mode == 0) // play mixed_on animation, close scope
		{
			local mixed_on = (weapon.ads_on && anim.ads_scope_off != -1) ? anim.ads_scope_off : anim.scope_off;
			if (mixed_on != -1)
			{
				mixed_on = viewModel.LookupSequence(mixed_on);
				SetViewAnimation(viewModel, mixed_on, 0, Time, anim);
				scope.transform_end = Time + viewModel.GetSequenceDuration(mixed_on);
				
				weapon.mixed_mode = 1;
				SetMixedFlag(weapon.ent, "1");
				scope.delay_switch = Time;
				
				//NetProps.SetPropInt(weapon.ent, "m_nSkin", 1);
				//NetProps.SetPropInt(viewModel, "m_nSkin", 1);
				if (scope.group_id != -1)
				{
					// switch immediately to avoid animation issues
					local bd_mode = weapon.ads_on && weapon.ads_aim_mode == "ads_1st_" ? scope.fix_mixed_on_scope_on : scope.fix_mixed_on_scope_off;
					weapon.ent.SetBodygroup(scope.group_id, bd_mode);
					viewModel.SetBodygroup(scope.group_id, bd_mode);
					
					// delay to match the correct animation effect
					scope.delay_switch = Time + viewModel.GetSequenceDuration(mixed_on) * scope.on_delay;
					//scope.parts_id = scope.mixed_on_scope_off;
				}
				return true;
			}
		}
		else // play mixed_off animation, open scope
		{
			local mixed_off = (weapon.ads_on && anim.ads_scope_on != -1) ? anim.ads_scope_on : anim.scope_on;
			if (mixed_off != -1)
			{
				mixed_off = viewModel.LookupSequence(mixed_off);
				SetViewAnimation(viewModel, mixed_off, 0, Time, anim);
				scope.transform_end = Time + viewModel.GetSequenceDuration(mixed_off);
				
				weapon.mixed_mode = 0;
				SetMixedFlag(weapon.ent, "0");
				scope.delay_switch = Time;
				
				//NetProps.SetPropInt(weapon.ent, "m_nSkin", 0);
				//NetProps.SetPropInt(viewModel, "m_nSkin", 0);
				if (scope.group_id != -1)
				{
					// switch immediately to avoid animation issues
					weapon.ent.SetBodygroup(scope.group_id, scope.fix_mixed_off_scope_off);
					viewModel.SetBodygroup(scope.group_id, scope.fix_mixed_off_scope_off);
					
					// delay to match the correct animation effect
					scope.delay_switch = Time + viewModel.GetSequenceDuration(mixed_off) * scope.off_delay;
					//scope.parts_id = (weapon.ads_on && weapon.ads_aim_mode == "ads_1st_" ? scope.mixed_off_scope_on : scope.mixed_off_scope_off);
				}
				return true;
			}
		}
		
		return false;
	}
	
	// ignore the first few seconds of being dragged
	function IsTongueInitialGrab(player)
	{
		local smoker = NetProps.GetPropEntity(player, "m_tongueOwner");
		if (!smoker)
			return false;
		
		local act = player.GetSequenceActivityName(player.GetSequence());
		return act != "ACT_TERROR_DRAGGING_FROM_TONGUE" && NetProps.GetPropInt(player, "m_isHangingFromTongue") <= 0;
	}
	
	function IsPlayerDominatedBySI(player)
	{
		if (player.IsDominatedBySpecialInfected())
			return !IsTongueInitialGrab(player);
		
		local act = player.GetSequenceActivityName(player.GetSequence());
		switch (act)
		{
			// punched by tank, hit by rock
			case "ACT_TERROR_HIT_BY_TANKPUNCH": case "ACT_TERROR_IDLE_FALL_FROM_TANKPUNCH": case "ACT_TERROR_TANKPUNCH_LAND":
			// flung by charger
			case "ACT_TERROR_HIT_BY_CHARGER": case "ACT_TERROR_IDLE_FALL_FROM_CHARGERHIT": case "ACT_TERROR_CHARGERHIT_LAND_SLOW":
			// charger - between carry_end and pummel_start, The result of IsDominatedBySpecialInfected is false
			case "ACT_TERROR_SLAMMED_GROUND": case "ACT_TERROR_SLAMMED_WALL":
				return true;
		}
		return false;
	}
	
	function IsPlayerEmptyHanded(player)
	{
		// 32: "32 - EF_NODRAW: Don't draw entity (entity is fully ignored by clients, NOT server; can cause collision problems)"
		// return !!(NetProps.GetPropInt(viewModel, "m_fEffects") & 32);
		// m_hViewEntity
		
		return !!(IsPlayerDominatedBySI(player) || player.IsHangingFromLedge() /*|| player.IsStaggering()*/ || player.IsGettingUp() /*|| NetProps.GetPropEntity(player, "m_useActionOwner") == player || NetProps.GetPropInt(player, "m_iCurrentUseAction") > 1 || NetProps.GetPropEntity(player, "m_reviveTarget")*/ || NetProps.GetPropInt(player, "m_usingMountedWeapon") > 0 || NetProps.GetPropInt(player, "movetype") == 9);
	}
	
	function SetViewAnimation(viewModel, anim, layer = -1, start_time = -1, scope = -1)
	{
		NetProps.SetPropInt(viewModel, "m_nLayerSequence", anim);
		if (layer != -1) NetProps.SetPropInt(viewModel, "m_nLayer", layer);
		if (start_time != -1) NetProps.SetPropFloat(viewModel, "m_flLayerStartTime", start_time);
		
		if (scope != -1)
		{
			scope.layer_seq = anim;
			scope.act_name = viewModel.GetSequenceActivityName(anim);
			if (start_time != -1) scope.layer_start_time = start_time;
		}
	}
	
	// find idle
	function LookupIdle(viewModel, idle = -1)
	{
		// should be ok, but who knows?
		// return viewModel.GetSequence();
		//printl("idle = " + viewModel.GetSequenceActivityName(viewModel.GetSequence()));
		
		if ((idle = viewModel.LookupSequence("ACT_VM_IDLE")) == -1)
			idle = viewModel.LookupSequence("ACT_VM_IDLE_SNIPER"); // hunting rifle
		return idle;
	}
	
	// check layer first
	function LookupAnimations(viewModel, anim_name, anim = -1)
	{
		if ((anim = viewModel.LookupSequence(anim_name + "_LAYER")) == -1)
			anim = viewModel.LookupSequence(anim_name);
		return anim;
	}
	
	function LookupReloadAnimations(viewModel, name, anim = -1)
	{
		if ((anim = LookupAnimations(viewModel, "ACT_VM_" + name)) == -1)
			anim = LookupAnimations(viewModel, name);
		return anim;
	}
	
	function LookupAdsReloadAnimations(viewModel, name, anim = -1)
	{
		if ((anim = LookupAnimations(viewModel, "ACT_PRIMARY_VM_" + name)) == -1)
			anim = LookupAnimations(viewModel, "ADS_" + name);
		return anim;
	}
	
	function IsPlayerPressedButtonInFirstTime(player, button)
	{
		return !!(NetProps.GetPropInt(player, "m_afButtonPressed") & button);
	}
	
	function IsPlayerPressingButton(player, button, bind_button = 0)
	{
		return button != 0 ? !!(player.GetButtonMask() & button) : bind_button != 0;
	}
	
	function SwitchCombine(player, button, Time, debug)
	{
		local pressing = IsPlayerPressingButton(player, CombineButton, button.combine_key_pressed);
		
		// first time
		if (pressing ? !button.combine_pressed : (button.combine_pressed = 0))
		{
			if (debug) printl("Time: " + Time + " --- pressed combine button: " + (CombineButton != 0 ? GetButtonName(CombineButton) : "custom binding key"));
			
			button.combine_mode = 0;
			button.combine_pressed = 1;
			button.combine_pressed_time = Time;
		}
		
		// only once
		if (button.combine_mode)
		{
			button.combine_mode = 0;
			button.combine_pressed_time = 0;
		}
		
		if (button.combine_pressed_time)
		{
			// holding
			if (Time - button.combine_pressed_time >= CombineBtnHolding)
				button.combine_mode = 2;
			else if (!pressing) // click
				button.combine_mode = 1;
		}
		
		if (!pressing && button.combine_pressed_time)
			button.combine_pressed_time = 0;
	}
	
	function SwitchADS(player, button, state, Time, debug)
	{
		local pressing = IsPlayerPressingButton(player, ActivateButton, button.ads_key_pressed);
		
		// first time
		if (pressing ? !button.pressed : (button.pressed = 0))
		{
			if (debug) printl("Time: " + Time + " --- pressed ads button: " + (ActivateButton != 0 ? GetButtonName(ActivateButton) : "custom binding key"));
			
			button.mode = MODE_NONE;
			button.pressed = 1;
			button.pressed_time = Time;
			if (state.ads_pause_until && OffADS_Restart) // if paused ads, then exit it
				button.ads_active = true;
			state.ads_pause_until = 0;
			state.ads_off_time = 0;
		}
		
		if (IsAttackButton && state.ads_on && !pressing && button.pressed_time && !state.ads_off_time)
			state.ads_off_time = Time + AttackRetreatDelay;
		
		if (button.pressed_time)
		{
			// switch to holding mode
			if (Time - button.pressed_time >= SmartHoldingKey || IsAttackButton)
			{
				button.mode = MODE_HOLDING;
				if (state.ads_off_time && Time < state.ads_off_time)
					pressing = true;
				button.ads_active = pressing;
			}
			//else if (button.pressed_time == Time)
			else if (button.mode == MODE_NONE && button.pressed) // fix can't enable ads on local/dedicated server, because the 'Time' sometimes doesn't change
			{
				button.mode = MODE_TOGGLE;
				// clear the value if we exit ADS, so not enter again if hold the button
				if (!(button.ads_active = !button.ads_active))
					button.pressed_time = 0;
			}
		}
		
		if (!pressing && button.pressed_time)
		{
			button.pressed_time = 0;
			//state.ads_pause_until = 0;
		}
		
		if (state.ads_pause_until)
		{
			button.ads_active = false;
			if (Time >= state.ads_pause_until)
			{
				state.ads_pause_until = 0;
				if (OffADS_Restart && button.mode == MODE_TOGGLE)
					button.ads_active = true;
			}
		}
		
		state.ads_on = button.ads_active;
	}
	
	function IsCloseADSWhileAction(action, state, nextTime, player = null)
	{
		if (action == "shove" && player != null && "ScarAutoSyntheticShoveUntil" in getroottable())
		{
			local playerIndex = player.GetEntityIndex();
			if (playerIndex in ::ScarAutoSyntheticShoveUntil)
			{
				if (Time() <= ::ScarAutoSyntheticShoveUntil[playerIndex])
					return false;
				delete ::ScarAutoSyntheticShoveUntil[playerIndex];
			}
		}

		local off = false;
		local ads_anim = false;
		local setting = 0;
		local endtime = 0;
		
		switch (action)
		{
			case "reload":
			case "ads_reload":
				ads_anim = action == "ads_reload";
				//ads_anim = state.ads_reload;
				setting = OffADS_InReload;
				endtime = nextTime - 0.35;
				break;
			case "reload_empty":
			case "ads_reload_empty":
				ads_anim = action == "ads_reload_empty";
				//ads_anim = state.ads_reload_empty;
				setting = OffADS_InReload;
				endtime = nextTime - 0.35;
				break;
			case "shove":
				ads_anim = state.ads_shove;
				setting = OffADS_InShove;
				endtime = nextTime - 0.3;
				break;
		}
		
		switch (setting)
		{
			case 1: // quit if none ads anim
				if (ads_anim)
					break;
			case 2: // quit always
				off = true;
				break;
		}
		
		state.ads_pause_until = off && (!IsAttackButton || !ads_anim) ? endtime : 0;
		if (IsAttackButton && endtime > state.ads_off_time)
			state.ads_off_time = !ads_anim ? 0 : endtime;
		
		return off;
	}
	
	function GetWeaponTypeByItemName(itemname)
	{
		switch (itemname)
		{
			case "smg":
			case "smg_silenced":
			case "smg_mp5":
				return "smg";
			
			case "pumpshotgun":
			case "shotgun_chrome":
			case "autoshotgun":
			case "shotgun_spas":
				return "shotgun";
			
			case "rifle":
			case "rifle_ak47":
			case "rifle_desert":
			case "rifle_m60":
				return "rifle";
			
			case "rifle_sg552":
			case "hunting_rifle":
			case "sniper_military":
			case "sniper_scout":
			case "sniper_awp":
				return "scope";
			
			case "grenade_launcher":
				return "grenade_launcher";
			
			case "pistol":
			case "dual_pistols":
			case "pistol_magnum":
				return "pistol";
			
			// skip non-firearms
			default:
				return "Unknown";
		}
	}
	
	function GetMeleeItemNameFromModel(melee, rexp = regexp(@"models.*(/v_|/w_)"))
	{
		local model = melee.GetModelName().tolower();
		local Match = rexp.search(model);
		return Match != null ? model.slice(Match.end, model.find(".mdl")) : "";
	}
	
	function GetWeaponItemName(weapon)
	{
		local name = weapon.GetClassname().slice(7);
		if (name == "pistol")
		{
			if (NetProps.GetPropInt(weapon, "m_isDualWielding"))
				name = "dual_pistols";
		}
		else if (name == "melee")
		{
			name = NetProps.GetPropString(weapon, "m_strMapSetScriptName").tolower();
			if (name == "") // riot police drop this empty named tonfa
			{
				name = GetMeleeItemNameFromModel(weapon);
				if (name == "bat")
					name = "baseball_bat";
				else if (name == "knife_t")
					name = "knife";
				
				// fixed empty name
				if (name != "")
				{
					NetProps.SetPropString(weapon, "m_strMapSetScriptName", name);
					printl("fixed empty \"m_strMapSetScriptName\" for melee: " + weapon + " - " + name);
				}
			}
		}
		return name;
	}
	
	function RestoreHostVisualEffects(fov_reset = false)
	{
		// fov
		if (fov_reset)
			SmoothScalingFov(false, Time());
		
		// laser sight
		if (HideLaserSight > 0 && Convars.GetFloat("r_draw_lasersight_1st_person") != 1)
			Convars.SetValue("r_draw_lasersight_1st_person", 1);
		
		// bullet tracers
		if (HideBulletTracers > 0 && Convars.GetFloat("r_drawtracers_firstperson") != 1)
			Convars.SetValue("r_drawtracers_firstperson", 1);
	}
	
	function RestoreVisualEffects(ishost, viewModel, weapon, idle)
	{
		// ads & laser
		if (weapon.ent && weapon.ent.IsValid())
		{
			// ADS on
			if (viewModel && idle != -1 && weapon.ent == NetProps.GetPropEntity(viewModel, "m_hWeapon") && viewModel.GetSequence() != idle)
				viewModel.SetSequence(idle);
			
			// temp laser
			if (HasLaserSightFlag(weapon.ent))
			{
				RemoveLaserSight(weapon.ent);
				UnSetLaserSightFlag(weapon.ent);
			}
		}
		
		if (ishost)
			RestoreHostVisualEffects(weapon.fov_scaling);
	}
	
	function HandleVisualEffects(ishost, weapon, Time)
	{
		local aw = weapon.ent;
		local hidden = Time <= weapon.hide_effects_until;
		local ads_paused = Time < weapon.ads_pause_until && OffADS_Restart;
		
		// crosshair
		if (hidden || ads_paused)
		{
			if (NetProps.GetPropInt(aw, "m_helpingHandState") != 7) // compatible with Inspect Weapon [VScript]
				NetProps.SetPropInt(aw, "m_helpingHandState", 7);
		}
		else if (NetProps.GetPropInt(aw, "m_helpingHandState") == 7)
		{
			NetProps.SetPropInt(aw, "m_helpingHandState", 0);
			NetProps.SetPropInt(aw, "m_helpingHandTarget", -1);
		}
		
		if (!ishost)
			return;
		
		// laser sight
		if (HideLaserSight > 0 && HasLaserSight(aw))
		{
			local hide = false;
			switch (HideLaserSight)
			{
				case 1: // always hide while ads on
					if ((weapon.ads_on && hidden) || ads_paused)
						hide = true;
					break;
				case 2: // only hide temp laser sight
					if (HasLaserSightFlag(aw) && ((weapon.ads_on && hidden) || ads_paused))
						hide = true;
					break;
			}
			
			if (hide)
			{
				if (Convars.GetFloat("r_draw_lasersight_1st_person") != 0)
					Convars.SetValue("r_draw_lasersight_1st_person", 0);
			}
			else if (Convars.GetFloat("r_draw_lasersight_1st_person") != 1)
				Convars.SetValue("r_draw_lasersight_1st_person", 1);
		}
		
		// bullet tracers
		if (HideBulletTracers > 0)
		{
			local hide = false;
			switch (HideBulletTracers)
			{
				case 1: // only hide while ads on
					if (hidden || ads_paused)
						hide = true;
					break;
				case 2: // always hide
					hide = true;
					break;
			}
			
			if (hide)
			{
				if (Convars.GetFloat("r_drawtracers_firstperson") != 0)
					Convars.SetValue("r_drawtracers_firstperson", 0);
			}
			else if (Convars.GetFloat("r_drawtracers_firstperson") != 1)
				Convars.SetValue("r_drawtracers_firstperson", 1);
		}
	}
	
	function HandleShotgunReload(player, viewModel, reload, weapon, anim, isShove, Time, debug)
	{
		local aw = weapon.ent;
		reload.state = reload.shotgun_fake_state > 0 ? reload.shotgun_fake_state : NetProps.GetPropInt(aw, "LocalShotgunData.m_reloadAnimState");
		
		if (reload.shotgun_end_anim_fix && reload.state < 3 && weapon.reload && Time >= weapon.next_shove)
		{
			local goal = NetProps.GetPropInt(aw, "LocalShotgunData.m_reloadNumShells");
			local inserted = NetProps.GetPropInt(aw, "LocalShotgunData.m_shellsInserted");
			// next state is end
			if (goal == inserted)
			{
				if (!reload.shotgun_fake_state) // prevent game play the reload end animation
				{
					reload.shotgun_fake_state = reload.state;
					NetProps.SetPropInt(aw, "LocalShotgunData.m_reloadAnimState", 3);
				}
				if (!anim.is_new) // wait, otherwise will skip the last loop
				{
					local endtime;
					switch (reload.state)
					{
						case 1:
							endtime = NetProps.GetPropFloat(aw, "LocalShotgunData.m_reloadStartTime") + NetProps.GetPropFloat(aw, "LocalShotgunData.m_reloadStartDuration");
							break;
						case 2:
							endtime = reload.anim_start_time + NetProps.GetPropFloat(aw, "LocalShotgunData.m_reloadInsertDuration");
							break;
					}
					if (endtime != null && Time + DeltaTime + 0.001 >= endtime) // last frame
					{
						if (debug.enable) printl("shotgun reload end animation fix, " + (reload.state == 1 ? "start anim finish" : "loop anim finish") + " at " + Time + " - " + endtime);
						
						// ammo fix
						aw.SetClip1(++weapon.clip1);
						local ammoType = NetProps.GetPropInt(aw, "m_iPrimaryAmmoType");
						local ammo = NetProps.GetPropIntArray(player, "m_iAmmo", ammoType) - 1;
						NetProps.SetPropIntArray(player, "m_iAmmo", ammo, ammoType);
						
						// switch to next state
						reload.state = 3;
						//NetProps.SetPropInt(aw, "LocalShotgunData.m_reloadAnimState", 3);
						reload.shotgun_fake_state = 0;
						
						// manually set reload end animation
						anim.is_new = true;
						local seq = viewModel.LookupSequence("ACT_VM_RELOAD_END_LAYER");
						SetViewAnimation(viewModel, seq, 0, Time, anim);
					}
				}
			}
		}
		
		// support shotgun new reload animations
		if ((anim.is_new && (anim.act_name == "ACT_VM_RELOAD_LAYER" || anim.act_name == "ACT_VM_RELOAD_LOOP_LAYER" || anim.act_name == "ACT_VM_RELOAD_END_LAYER")) || (reload.shotgun_last_state && reload.shotgun_last_state != reload.state)) //fix for model not has the activity "ACT_VM_RELOAD_LOOP_LAYER" & "ACT_VM_RELOAD_END_LAYER"
		{
			//if (weapon.ads_on && anim.act_name == "ACT_VM_RELOAD_LAYER" && IsCloseADSWhileAction(reload.type, weapon, weapon.next_attack))
			//	weapon.ads_on = false;
			
			reload.shotgun_last_state = reload.state;
			
			//printl("m_reloadStartTime = " + NetProps.GetPropFloat(aw, "LocalShotgunData.m_reloadStartTime"));
			//printl("m_reloadStartDuration = " + NetProps.GetPropFloat(aw, "LocalShotgunData.m_reloadStartDuration"));
			//printl("m_reloadInsertDuration = " + NetProps.GetPropFloat(aw, "LocalShotgunData.m_reloadInsertDuration"));
			//printl("m_reloadEndDuration = " + NetProps.GetPropFloat(aw, "LocalShotgunData.m_reloadEndDuration"));
			
			/*local dur = GetShotgunReloadStateDuration(aw, reload.state);
			local new_reload_anim = reload_mode <= 1 ? -1 : GetShotgunReloadStateAnim(viewModel, reload_mode, reload.state, anim);
			if (new_reload_anim != -1)
			{
				local seq_name = viewModel.GetSequenceName(new_reload_anim);
				local act_name = viewModel.GetSequenceActivityName(new_reload_anim);
				if (debug.enable) printl("shotgun set reload anim: " + new_reload_anim + " - " + seq_name + " - " + act_name);
				
				SetViewAnimation(viewModel, new_reload_anim, 0, (anim.is_new ? -1 : Time), anim);
				
				// start anim fix, play activity "ACT_PRIMARY_VM_RELOAD_LAYER", get real anim time from activity "ACT_PRIMARY_VM_RELOAD", and so on
				local anim_name = act_name.tolower(); //seq_name.tolower();
				local idx_layer = anim_name.find("_layer");
				if (idx_layer != null)
				{
					local _anim = viewModel.LookupSequence(anim_name.slice(0, idx_layer));
					if (_anim != -1)
						new_reload_anim = _anim;
				}
				
				dur = viewModel.GetSequenceDuration(new_reload_anim) / anim.play_rate;
				switch (reload.state)
				{
					case 1:
						NetProps.SetPropFloat(aw, "LocalShotgunData.m_reloadStartDuration", dur);
						break;
					case 2:
						NetProps.SetPropFloat(aw, "LocalShotgunData.m_reloadInsertDuration", dur);
						break;
					case 3:
						NetProps.SetPropFloat(aw, "LocalShotgunData.m_reloadEndDuration", dur);
						
						local timer = Time + dur;
						NetProps.SetPropFloat(aw, "m_flNextPrimaryAttack", timer);
						NetProps.SetPropFloat(player, "m_flNextAttack", timer);
						break;
				}
			}*/
			
			switch (reload.state)
			{
				case 1:
					reload.anim = reload.start_anim;
					reload.anim_duration = reload.start_anim_dur;
					NetProps.SetPropFloat(aw, "LocalShotgunData.m_reloadStartDuration", reload.anim_duration);
					break;
				case 2:
					reload.anim = reload.insert_anim;
					reload.anim_duration = reload.insert_anim_dur;
					NetProps.SetPropFloat(aw, "LocalShotgunData.m_reloadInsertDuration", reload.anim_duration);
					break;
				case 3:
					reload.anim = reload.end_anim;
					reload.anim_duration = reload.end_anim_dur;
					NetProps.SetPropFloat(aw, "LocalShotgunData.m_reloadEndDuration", reload.anim_duration);
					
					local timer = Time + reload.anim_duration;
					NetProps.SetPropFloat(aw, "m_flNextPrimaryAttack", timer);
					NetProps.SetPropFloat(player, "m_flNextAttack", timer);
					break;
			}
			
			//if (reload.type != "reload")
			if (anim.layer_seq != reload.anim)
			{
				local seq_name = viewModel.GetSequenceName(reload.anim);
				local act_name = viewModel.GetSequenceActivityName(reload.anim);
				if (debug.enable) printl("shotgun set reload anim: " + reload.anim + " - " + seq_name + " - " + act_name);
				
				SetViewAnimation(viewModel, reload.anim, 0, (anim.is_new ? -1 : Time), anim);
			}
			
			/*// update shotgun' reload anim
			if (reload.state == 1)
			{
				reload.start_time = anim.layer_start_time;
				//printl(reload.end_time + " --- " + weapon.next_attack);
				reload.end_time = weapon.next_attack;
			}*/
			reload.anim = anim.layer_seq;
			reload.anim_rate = anim.play_rate;
			reload.anim_start_time = anim.layer_start_time;
			reload.anim_end_time = reload.anim_start_time + reload.anim_duration;
			
			// check magazine reload
			if (reload.state == 1 && reload.shotgun_magazine_reload == 0)
			{
				if (reload.shotgun_magazine_reload = IsMagazineReload(reload))
				{
					if (debug.enable) printl("shotgun has magazine reload");
					
					// some model removed the activity "ACT_VM_RELOAD_LOOP_LAYER" & "ACT_VM_RELOAD_END_LAYER", I don't recommend doing this
					if (NetProps.GetPropFloat(aw, "LocalShotgunData.m_reloadInsertDuration") != 0)
					{
						// check vanilla loop and end animations
						if (IsMissingVanillaReloadLoopEndAnimations(viewModel))
						{
							if (debug.enable) printl("shotgun not has reload loop/end layer");
							
							reload.shotgun_miss_anim = 1;
						}
						
						NetProps.SetPropFloat(aw, "LocalShotgunData.m_reloadInsertDuration", 0);
						NetProps.SetPropFloat(aw, "LocalShotgunData.m_reloadEndDuration", 0);
						
						reload.end_time = reload.anim_end_time;
						NetProps.SetPropFloat(aw, "m_flNextPrimaryAttack", reload.anim_end_time);
						NetProps.SetPropFloat(player, "m_flNextAttack", reload.anim_end_time);
					}
					
					if (reload.shotgun_end_anim_fix)
					{
						reload.shotgun_end_anim_fix = false;
						if (reload.shotgun_fake_state)
						{
							reload.shotgun_fake_state = 0;
							NetProps.SetPropInt(aw, "LocalShotgunData.m_reloadAnimState", 1);
						}
					}
				}
			}
			
			if (reload.shotgun_magazine_reload)
			{
				switch (reload.state)
				{
					case 1:
						// empty clip, nothing can do
						if (weapon.clip1 <= 0)
							break;
						// ensure the start animation can play if "PreventShotgunReloadFiring" is set
						reload.shotgun_magazine_reload_anim_fix = PreventShotgunReloadFiring;
					case 2:
					case 3:
						if (reload.state > 1)
						{
							local goal = NetProps.GetPropInt(aw, "LocalShotgunData.m_reloadNumShells");
							local inserted = NetProps.GetPropInt(aw, "LocalShotgunData.m_shellsInserted");
							if ((reload.state == 2 && goal == 1 && (weapon.reload || inserted == 0)) || reload.state == 3)
							{
								NetProps.SetPropInt(aw, "LocalShotgunData.m_shellsInserted", inserted + 1);
							}
							if (reload.state == 2)
							{
								reload.state = 3;
								reload.shotgun_last_state = 3;
								NetProps.SetPropInt(aw, "LocalShotgunData.m_reloadAnimState", 3);
							}
							reload.shotgun_magazine_reload = false;
							SetShotgunMagazine(player, aw);
							reload.fix = 0;
						}
						
						// prevent player press attack to interrupt the reload animation whne state 1
						// end reload when state 2/3
						if (reload.state > 1 || PreventShotgunReloadFiring)
						{
							weapon.reload = false;
							NetProps.SetPropInt(aw, "m_bInReload", 0);
							NetProps.SetPropInt(aw, "m_reloadState", 0);
						}
						
						if (Time >= weapon.next_shove && (player.GetButtonMask() & BUTTON_SHOVE) == 0)
						{
							NetProps.SetPropFloat(aw, "m_flNextPrimaryAttack", reload.anim_end_time);
							NetProps.SetPropFloat(player, "m_flNextAttack", reload.anim_end_time);
						}
						break;
				}
			}
		}
		
		if (reload.shotgun_magazine_reload_anim_fix && !anim.is_new)
		{
			reload.shotgun_magazine_reload_anim_fix = 0;
			SetViewAnimation(viewModel, reload.anim, 0, reload.anim_start_time + 0.001, anim);
		}
		
		if (reload.shotgun_magazine_reload)
		{
			// force state 2 when "PreventShotgunReloadFiring" enable
			// this will fix the bug where player get stuck in reload loop if he holding the reload button
			if (reload.state == 1 && !weapon.reload)
			{
				if (PreventShotgunReloadFiring)
				{
					//local start = NetProps.GetPropFloat(aw, "LocalShotgunData.m_reloadStartTime");
					//local dur = NetProps.GetPropFloat(aw, "LocalShotgunData.m_reloadStartDuration");
					//local endtime = start + dur;
					//printl(Time - 0.1 >= endtime);
					if (Time + DeltaTime + 0.001 >= reload.anim_end_time)
					{
						if (debug.enable) printl(Time + " - " + reload.anim_end_time + " -- magazine reload is about to end, switching to the next stage");
						
						weapon.reload = true;
						NetProps.SetPropInt(aw, "m_bInReload", 1);
						NetProps.SetPropInt(aw, "m_reloadState", 1);
						
						local goal = NetProps.GetPropInt(aw, "LocalShotgunData.m_reloadNumShells");
						local inserted = NetProps.GetPropInt(aw, "LocalShotgunData.m_shellsInserted");
						
						// otherwise will in state 3, also fix can't fire bug if holding the attack button
						if (goal == 1 && goal == inserted)
							NetProps.SetPropInt(aw, "LocalShotgunData.m_shellsInserted", 0);
						
						reload.state = 2;
						reload.shotgun_last_state = 2 + (reload.shotgun_miss_anim || (player.GetButtonMask() & BUTTON_SHOVE));
						NetProps.SetPropInt(aw, "LocalShotgunData.m_reloadAnimState", 2);
					}
				}
				else
					SetTableValueForAllKey(reload, 0);
			}
		}
		else if (PreventShotgunReloadFiring)
		{
			switch (reload.state)
			{
				case 1:
				case 2:
					if (!(player.GetButtonMask() & BUTTON_ATTACK) || weapon.clip1 <= 0 || Time < weapon.next_shove)
						break;
					
					if (!weapon.reload && debug.enable)
						printl("prevent shotgun firing on reload state " + reload.state);
					
					//reload.state = 3;
					reload.shotgun_last_state = 3;
					reload.shotgun_fake_state = 0;
					NetProps.SetPropInt(aw, "LocalShotgunData.m_reloadAnimState", 3);
					
					//local reload_end = GetShotgunReloadStateAnim(viewModel, reload_mode, 3, anim);
					SetViewAnimation(viewModel, reload.end_anim, 0, Time, anim);
					
					//local dur = NetProps.GetPropFloat(aw, "LocalShotgunData.m_reloadEndDuration");
					if (reload.type != "reload")
					{
						//dur = viewModel.GetSequenceDuration(reload_end) / anim.play_rate;
						NetProps.SetPropFloat(aw, "LocalShotgunData.m_reloadEndDuration", reload.end_anim_dur);
					}
					
					local timer = Time + reload.end_anim_dur;
					NetProps.SetPropFloat(aw, "m_flNextPrimaryAttack", timer);
					NetProps.SetPropFloat(player, "m_flNextAttack", timer);
					
					reload.anim = reload.end_anim;
					reload.anim_rate = anim.play_rate;
					reload.anim_start_time = Time;
					reload.anim_end_time = timer;
					//reload.start_time = Time;
					reload.end_time = timer;
					
					if (weapon.ads_pause_until)
						weapon.ads_pause_until = timer - 0.35;
				case 3:
					if (weapon.reload)
					{
						if (debug.enable) printl("prevent shotgun firing on reload state " + reload.state);
						
						weapon.reload = false;
						NetProps.SetPropInt(aw, "m_bInReload", 0);
						NetProps.SetPropInt(aw, "m_reloadState", 0);
					}
					break;
			}
		}
	}
	
	function HandleLeverActionRifleReload(player, viewModel, reload, weapon, anim, isShove, Time, debug)
	{
		local aw = weapon.ent;
		if (reload.keep_ammo > 0)
		{
			local ammoType = NetProps.GetPropInt(aw, "m_iPrimaryAmmoType");
			local ammo = NetProps.GetPropIntArray(player, "m_iAmmo", ammoType) + weapon.clip1 - reload.keep_ammo;
			NetProps.SetPropIntArray(player, "m_iAmmo", ammo, ammoType);
			aw.SetClip1(weapon.clip1 = reload.keep_ammo);
			
			reload.keep_ammo = 0;
		}
		
		if (!PreventShotgunReloadFiring)
		{
			if ((player.GetButtonMask() & BUTTON_ATTACK) && weapon.clip1 > 0 && Time >= weapon.next_shove)
			{
				reload.state = 3;
				reload.anim = -1;
				reload.end_time = Time;
				if (reload.anim_layer != 0)
					SetViewAnimation(viewModel, -1, reload.anim_layer, Time);
				
				weapon.reload = false;
				NetProps.SetPropInt(aw, "m_bInReload", 0);
				NetProps.SetPropFloat(aw, "m_flNextPrimaryAttack", Time);
				NetProps.SetPropFloat(player, "m_flNextAttack", Time);
			}
		}
		else
		{
			switch (reload.state)
			{
				case 1:
				case 2:
					if (!(player.GetButtonMask() & BUTTON_ATTACK) || weapon.clip1 <= 0 || Time < weapon.next_shove || (reload.anim_layer == 3 && !reload.vanilla_reload_cancelled))
						break;
					
					if (debug.enable)
						printl("prevent lever action rifle firing on reload state " + reload.state);
					
					reload.state = 3;
					reload.anim = reload.end_anim;
					reload.anim_duration = reload.end_anim_dur;
					reload.anim_rate = anim.play_rate;
					reload.anim_start_time = Time;
					reload.anim_end_time = Time + reload.anim_duration;
					reload.end_time = reload.anim_end_time;
					SetViewAnimation(viewModel, reload.end_anim, reload.anim_layer, Time);
					
					weapon.reload = false;
					NetProps.SetPropInt(aw, "m_bInReload", 0);
					NetProps.SetPropFloat(aw, "m_flNextPrimaryAttack", reload.end_time);
					NetProps.SetPropFloat(player, "m_flNextAttack", reload.end_time);
					
					if (weapon.ads_pause_until)
						weapon.ads_pause_until = reload.end_time - 0.35;
				case 3:
					//if (debug.enable) printl("prevent lever action rifle firing on reload state " + reload.state);
					break;
			}
		}
		
		switch (reload.state)
		{
			case 1:
				//if (Time + DeltaTime + 0.001 >= reload.anim_end_time)
				if (Time >= reload.anim_end_time)
				{
					if (reload.inserted == reload.reload_num) // last bullet
					{
						reload.state = 3;
						reload.anim = reload.end_anim;
						reload.anim_duration = reload.end_anim_dur;
						reload.anim_start_time = Time;
						reload.anim_end_time = Time + reload.anim_duration;
						reload.end_time = reload.anim_end_time; // just in case
						
						NetProps.SetPropFloat(aw, "m_flNextPrimaryAttack", reload.end_time);
						NetProps.SetPropFloat(player, "m_flNextAttack", reload.end_time);
					}
					else
					{
						reload.inserted++;
						reload.state = 2;
						reload.anim = reload.insert_anim;
						reload.anim_duration = reload.insert_anim_dur;
						reload.anim_start_time = Time;
						reload.anim_end_time = Time + reload.anim_duration;
					}
					
					if (!isShove || (reload.anim_layer = 0) || !(reload.vanilla_reload_cancelled = 1) || Time > anim.layer_end_time)
						SetViewAnimation(viewModel, reload.anim, reload.anim_layer, Time);
					
					aw.SetClip1(++weapon.clip1);
					local ammoType = NetProps.GetPropInt(aw, "m_iPrimaryAmmoType");
					local ammo = NetProps.GetPropIntArray(player, "m_iAmmo", ammoType) - 1;
					NetProps.SetPropIntArray(player, "m_iAmmo", ammo, ammoType);
				}
				//else if (Time > reload.start_time && anim.layer_seq != reload.anim && (!isShove || Time >= anim.layer_end_time))
				//	SetViewAnimation(viewModel, reload.anim, reload.anim_layer, reload.start_time + 0.2);
				else if (reload.anim_layer == 3 && !reload.vanilla_reload_cancelled && Time - reload.start_time >= 0.1)
				{
					reload.vanilla_reload_cancelled = 1;
					SetViewAnimation(viewModel, -1, 0);
				}
				else if (anim.layer_seq != reload.anim && isShove && Time > anim.layer_end_time) // Time - anim.layer_start_time >= 0.1
					SetViewAnimation(viewModel, reload.anim, reload.anim_layer, reload.start_time);
				break;
			case 2:
				if (Time >= reload.anim_end_time)
				{
					if (reload.inserted == reload.reload_num) // last bullet
					{
						reload.state = 3;
						reload.anim = reload.end_anim;
						reload.anim_duration = reload.end_anim_dur;
						reload.anim_start_time = Time;
						reload.anim_end_time = Time + reload.anim_duration;
						reload.end_time = reload.anim_end_time; // just in case
						
						NetProps.SetPropFloat(aw, "m_flNextPrimaryAttack", reload.end_time);
						NetProps.SetPropFloat(player, "m_flNextAttack", reload.end_time);
						
						// fix not end the relaod loop anim
						if (reload.anim_layer == 0)
						{
							//SetViewAnimation(viewModel, -1, 0, Time);
							SetViewAnimation(viewModel, reload.anim, reload.anim_layer, Time);
						}
					}
					else
					{
						reload.inserted++;
						//reload.state = 2;
						reload.anim = reload.insert_anim;
						reload.anim_duration = reload.insert_anim_dur;
						reload.anim_start_time = Time;
						reload.anim_end_time = Time + reload.anim_duration;
					}
					
					//if (!isShove || /*(reload.anim_layer = 0) ||*/ Time > anim.layer_end_time)
					if (!isShove || (reload.anim_layer = 0) || Time > anim.layer_end_time)
						SetViewAnimation(viewModel, reload.anim, reload.anim_layer, Time);
					
					aw.SetClip1(++weapon.clip1);
					local ammoType = NetProps.GetPropInt(aw, "m_iPrimaryAmmoType");
					local ammo = NetProps.GetPropIntArray(player, "m_iAmmo", ammoType) - 1;
					NetProps.SetPropIntArray(player, "m_iAmmo", ammo, ammoType);
				}
				//else if (anim.layer_seq != reload.anim && (!isShove || (Time > anim.layer_end_time && !(reload.anim_layer = 0))))
				else if (anim.layer_seq != reload.anim && (!isShove || (reload.anim_layer = 0) || Time > anim.layer_end_time))
					SetViewAnimation(viewModel, reload.anim, reload.anim_layer, reload.anim_start_time, anim);
				break;
			case 3:
				//if (anim.layer_seq != reload.anim && reload.anim_layer == 0 && isShove && Time >= anim.layer_end_time)
				//	SetViewAnimation(viewModel, reload.anim, reload.anim_layer, reload.anim_start_time, anim);
				break;
		}
	}
	
	function IsShoveActivity(actname, item)
	{
		return (actname in Activity.Shove);
		
		/*switch (actname)
		{
			//case "ACT_PRIMARY_VM_SECONDARYATTACK": // old ads shove
			//	if (item == "dual_pistols")
			//		break;
			case "ACT_VM_MELEE_LAYER":
			case "ACT_VM_MELEE_SNIPER_LAYER":
			case "ACT_PRIMARY_VM_MELEE":
			case "ACT_SECONDARY_VM_MELEE":
			case "ACT_TERTIARY_VM_MELEE":
			case "ACT_VM_MELEE_HIT":
			case "ACT_PRIMARY_VM_MELEE_HIT":
			case "ACT_SECONDARY_VM_MELEE_HIT":
			case "ACT_TERTIARY_VM_MELEE_HIT":
				return true;
		}
		return false;*/
	}
	
	function IsDeployActivity(actname)
	{
		return (actname in Activity.Deploy);
		
		/*switch (actname)
		{
			case "ACT_VM_DEPLOY_LAYER":
			case "ACT_VM_DEPLOY_SNIPER_LAYER":
			case "ACT_VM_DRAW":
			case "ACT_VM_DRAW_LAYER": // new, replace "ACT_VM_DRAW"
			case "MIXED_ACT_VM_DEPLOY":
			case "MIXED_ACT_VM_DRAW_LAYER":
			
			// unused animations, but...
			case "ACT_VM_PICKUP":
			case "ACT_VM_PICKUP_LAYER":
			case "ACT_VM_PICKUP_SNIPER_LAYER":
				return true;
		}
		return false;*/
	}
	
	function IsMissingVanillaReloadLoopEndAnimations(viewModel)
	{
		local anim_loop = viewModel.LookupSequence("ACT_VM_RELOAD_LOOP_LAYER");
		local anim_end = viewModel.LookupSequence("ACT_VM_RELOAD_END_LAYER");
		
		return (anim_loop == -1 && anim_end == -1);
	}
	
	function IsMagazineReload(reload)
	{
		return (reload.insert_anim == -1 || reload.insert_anim_dur <= 0) && (reload.end_anim == -1 || reload.end_anim_dur <= 0); 
	}
	
	function SetShotgunMagazine(player, weapon)
	{
		local shells = NetProps.GetPropInt(weapon, "LocalShotgunData.m_reloadNumShells") - (NetProps.GetPropInt(weapon, "LocalShotgunData.m_shellsInserted") - 1);
		if (shells > 0)
		{
			weapon.SetClip1(weapon.Clip1() + shells);
			local ammoType = NetProps.GetPropInt(weapon, "m_iPrimaryAmmoType");
			local ammo = NetProps.GetPropIntArray(player, "m_iAmmo", ammoType) - shells;
			NetProps.SetPropIntArray(player, "m_iAmmo", ammo, ammoType);
		}
	}
	
	function GetShotgunReloadStateDuration(weapon, state)
	{
		switch (state)
		{
			case 1: return NetProps.GetPropFloat(weapon, "LocalShotgunData.m_reloadStartDuration");
			case 2: return NetProps.GetPropFloat(weapon, "LocalShotgunData.m_reloadInsertDuration");
			case 3: return NetProps.GetPropFloat(weapon, "LocalShotgunData.m_reloadEndDuration");
			default: return 0;
		}
	}
	
	function GetShotgunReloadStateAnim(viewModel, mode, state, anim)
	{
		/*
		mode:
			reload
			reload_empty
			ads_reload
			ads_reload_empty
		*/
		
		if (state < 1 || state > 3)
			return -1;
		
		// use the same activity name: ACT_VM_RELOAD_LAYER for new reload start animation, according to sequence name to distinguish new added animations
		local ShotgunReloadAnimGroup =
		{
			["reload"] = ["", anim.reload, anim.reload_loop, anim.reload_end],
			["reload_empty"] = ["", anim.reload_empty, anim.reload_empty_loop, anim.reload_empty_end],
			
			["ads_reload"] = ["", anim.ads_reload, anim.ads_reload_loop, anim.ads_reload_end],
			["ads_reload_empty"] = ["", anim.ads_reload_empty, anim.ads_reload_empty_loop, anim.ads_reload_empty_end],
		}
		
		if (!(mode in ShotgunReloadAnimGroup))
			return -1;
		
		local anim_name = ShotgunReloadAnimGroup[mode][state];
		if (anim_name == -1)
			return -1;
		
		return viewModel ? viewModel.LookupSequence(anim_name) : anim_name;
		
		// TODO 目前只支持 activity 名称查找，尚未支持 sequence 名称寻找动画
	}
	
	function GetLeverActionRifleReloadStateAnim(viewModel, mode, state, anim)
	{
		if (state < 1 || state > 3)
			return -1;
		
		// use the same activity name: ACT_VM_RELOAD_LAYER for new reload start animation, according to sequence name to distinguish new added animations
		local LeverActionRifleReloadAnimGroup =
		{
			["reload"] = ["", anim.reload_start, anim.reload_loop, anim.reload_end],
			["reload_empty"] = ["", anim.reload_empty_start, anim.reload_empty_loop, anim.reload_empty_end],
			
			["ads_reload"] = ["", anim.ads_reload_start, anim.ads_reload_loop, anim.ads_reload_end],
			["ads_reload_empty"] = ["", anim.ads_reload_empty_start, anim.ads_reload_empty_loop, anim.ads_reload_empty_end],
		}
		
		if (!(mode in LeverActionRifleReloadAnimGroup))
			return -1;
		
		local anim_name = LeverActionRifleReloadAnimGroup[mode][state];
		if (anim_name == -1)
			return -1;
		
		return viewModel ? viewModel.LookupSequence(anim_name) : anim_name;
	}
	
	function HasMixedFlag(weapon)
	{
		return ResponseCriteria.HasCriterion(weapon, "flag_mixed_mode");
	}
	
	function UnSetMixedFlag(weapon)
	{
		weapon.SetContext("flag_mixed_mode", "0", 0);
		ResponseCriteria.HasCriterion(weapon, "flag_mixed_mode");
	}
	
	function SetMixedFlag(weapon, val)
	{
		weapon.SetContext("flag_mixed_mode", val, -1);
	}
	
	function GetMixedFlag(weapon)
	{
		return StringToInteger2(ResponseCriteria.GetValue(weapon, "flag_mixed_mode"));
	}
	
	function RestoreWeaponDataForPlayer(player)
	{
		if (BaseGameMode != "coop" && BaseGameMode != "realism")
			return;
		
		local steamid = player.GetNetworkIDString();
		if (!(steamid in TransitionData))
			return;
		
		local id = player.GetPlayerUserId();
		if (!(id in HumanSurvivors))
			return;
		
		local weapon_data = TransitionData[steamid];
		local scope = HumanSurvivors[id];
		
		local inv = {};
		GetInvTable(player, inv);
		foreach (slot, item in inv)
		{
			if (!item || !item.IsValid())
				continue;
			
			if (!(slot in weapon_data) || weapon_data[slot] != item.GetClassname())
				continue;
			
			if (item == scope.weapon.current)
			{
				scope.weapon.mixed_mode = 1;
				scope.body.scope.delay_switch = 1;
			}
			SetMixedFlag(item, "1");
		}
	}
	
	function RestoreTransitionData()
	{
		if (BaseGameMode != "coop" && BaseGameMode != "realism")
			return;
		
		RestoreTable("L4D2Lxc_ADS_Trans", TransitionData);
		SaveTable("L4D2Lxc_ADS_Trans", TransitionData);
	}
	
	function SaveTransitionData()
	{
		if (BaseGameMode != "coop" && BaseGameMode != "realism")
			return;
		
		TransitionData.clear();
		
		foreach (id, t in HumanSurvivors)
		{
			if (!t.player || !t.player.IsValid())
				continue;
			
			local trans = {};
			local inv = {};
			GetInvTable(t.player, inv);
			foreach (slot, item in inv)
			{
				if (!item || !item.IsValid() || !GetMixedFlag(item))
					continue;
				
				trans[slot] <- item.GetClassname();
			}
			
			if (trans.len() <= 0)
				continue;
			
			TransitionData[t.player.GetNetworkIDString()] <- trans;
		}
		
		SaveTable("L4D2Lxc_ADS_Trans", TransitionData);
	}
	
	// set flag if give player a temp ads laser sight
	function SetLaserSightFlag(weapon)
	{
		weapon.SetContext("flag_ads_laser_sight", "temp", -1);
	}
	
	function UnSetLaserSightFlag(weapon)
	{
		weapon.SetContext("flag_ads_laser_sight", "temp", 0);
		ResponseCriteria.HasCriterion(weapon, "flag_ads_laser_sight");
	}
	
	function HasLaserSightFlag(weapon)
	{
		return weapon.GetContext("flag_ads_laser_sight") != null;
	}
	
	function HasLaserSight(weapon) // LASER_SIGHT = 4
	{
		return !!(NetProps.GetPropInt(weapon, "m_upgradeBitVec") & 4);
	}
	
	function GiveLaserSight(weapon)
	{
		local upgradeBits = NetProps.GetPropInt(weapon, "m_upgradeBitVec");
		NetProps.SetPropInt(weapon, "m_upgradeBitVec", upgradeBits | 4);
	}
	
	function RemoveLaserSight(weapon)
	{
		local upgradeBits = NetProps.GetPropInt(weapon, "m_upgradeBitVec");
		NetProps.SetPropInt(weapon, "m_upgradeBitVec", upgradeBits & ~4);
	}
	
	function SetFlagForPlayerInventory(player)
	{
		if (!player || !player.IsValid() || !player.IsSurvivor())
			return;
		
		local inv = {};
		GetInvTable(player, inv);
		foreach (slot, item in inv)
		{
			if (!item || !item.IsValid())
				continue;
			
			// what if user has another pistol laser sight mod?
			local cname = item.GetClassname();
			if ((cname == "weapon_pistol" || cname == "weapon_pistol_magnum") ? "RF_Laser" in getroottable() : HasLaserSight(item))
			{
				if (HasLaserSightFlag(item))
					UnSetLaserSightFlag(item);
			}
		}
	}
	
	// fixed temporary laser transition to next map
	// fixed fov not reset
	function RemoveTemporaryEffectsForSurvivors()
	{
		foreach (id, t in HumanSurvivors)
		{
			if (!t.player || !t.player.IsValid())
				continue;
			
			local inv = {};
			GetInvTable(t.player, inv);
			foreach (slot, item in inv)
			{
				if (!item || !item.IsValid())
					continue;
				
				if (HasLaserSightFlag(item))
				{
					RemoveLaserSight(item);
					UnSetLaserSightFlag(item);
				}
			}
			
			if (t.ishost)
				RestoreHostVisualEffects(t.weapon.fov_scaling);
		}
	}
	
	function SetTableValueForAllKey(table, val)
	{
		foreach (key, item in table)
		{
			if (typeof(item) == "table")
				SetTableValueForAllKey(item, val);
			else
				table[key] = val;
		}
	}
	
	function GetAnimationsPlaybackRate(ent)
	{
		local rate = NetProps.GetPropFloat(ent, "m_flPlaybackRate");
		if (rate <= 0.033) // not sure
			rate = 1.0;
		
		return rate;
	}
	
	function GetBestNextPrimaryAttackTimeFactor(weapon, cur_animtime, new_animTime, Time)
	{
		if (new_animTime <= 0)
			return 1.0; //Time;
		
		local cur_next = NetProps.GetPropFloat(weapon, "m_flNextPrimaryAttack");
		local cur_duration = cur_next - Time;
		
		local scale = (cur_animtime <= 0 || cur_duration <= 0) ? 1.0 : cur_duration / cur_animtime;
		return scale < 1.0 ? scale : 1.0;
		
		/*// get the shortest time
		local new_duration = scale < 1.0 ? new_animTime * scale : new_animTime;
		//printl("New NextPrimaryAttackTime = " + (Time + new_duration));
		return Time + new_duration;*/
	}
	
	function SetWeaponDrawAnimation(player, weapon, anim)
	{
		if (!player || !player.IsValid() || !weapon || !weapon.IsValid())
			return;
		
		local viewModel = NetProps.GetPropEntity(player, "m_hViewModel");
		if (!viewModel || weapon != NetProps.GetPropEntity(viewModel, "m_hWeapon") /*|| viewModel.LookupSequence("ACT_PRIMARY_VM_IDLE") == -1*/)
			return;
		
		local seq = NetProps.GetPropInt(viewModel, "m_nLayerSequence");
		local actname = viewModel.GetSequenceActivityName(seq);
		if (actname != "ACT_VM_DEPLOY_LAYER" && actname != "ACT_VM_DEPLOY_SNIPER_LAYER")
			return;
		
		local draw = anim.draw != -1 ? viewModel.LookupSequence(anim.draw) : -1;
		//local draw = LookupAnimations(viewModel, "ACT_VM_DRAW");
		if (draw == -1)
			return;
		
		local playRate = GetAnimationsPlaybackRate(weapon);
		//local old_animTime = viewModel.GetSequenceDuration(seq) / playRate;
		local animTime = viewModel.GetSequenceDuration(draw) / playRate;
		
		local curTime = NetProps.GetPropFloat(viewModel, "m_flLayerStartTime");
		local timestamp = curTime + animTime; //GetBestNextPrimaryAttackTime(weapon, old_animTime, animTime, curTime);
		NetProps.SetPropFloat(weapon, "m_flNextPrimaryAttack", timestamp);
		//NetProps.SetPropFloat(player, "m_flNextAttack", timestamp);
		
		//NetProps.SetPropInt(viewModel, "m_nLayer", 0);
		NetProps.SetPropInt(viewModel, "m_nLayerSequence", draw);
		//NetProps.SetPropFloat(viewModel, "m_flLayerStartTime", curTime);
	}
	
	function SetWeaponHolsterAnimation(player, weapon, ani_holster, ani_layer)
	{
		if (ani_holster == -1 || !player || !player.IsValid() || !weapon || !weapon.IsValid())
			return 0;
		
		local viewModel = NetProps.GetPropEntity(player, "m_hViewModel");
		if (!viewModel || weapon != NetProps.GetPropEntity(viewModel, "m_hWeapon") /*|| viewModel.LookupSequence("ACT_PRIMARY_VM_IDLE") == -1*/)
			return 0;
		
		local seq = NetProps.GetPropInt(viewModel, "m_nLayerSequence");
		local actname = viewModel.GetSequenceActivityName(seq);
		if (actname != "ACT_VM_DEPLOY_LAYER" && actname != "ACT_VM_DEPLOY_SNIPER_LAYER")
			return 0;
		
		local playRate = GetAnimationsPlaybackRate(weapon);
		local animTime = viewModel.GetSequenceDuration(ani_holster) / playRate;
		
		local curTime = NetProps.GetPropFloat(viewModel, "m_flLayerStartTime");
		local timestamp = curTime + animTime;
		NetProps.SetPropFloat(weapon, "m_flNextPrimaryAttack", timestamp);
		NetProps.SetPropFloat(weapon, "m_flNextSecondaryAttack", timestamp);
		//NetProps.SetPropFloat(player, "m_flNextAttack", timestamp);
		
		NetProps.SetPropInt(viewModel, "m_nLayer", ani_layer);
		NetProps.SetPropInt(viewModel, "m_nLayerSequence", ani_holster);
		//NetProps.SetPropFloat(viewModel, "m_flLayerStartTime", curTime);
		
		return timestamp - 0.1; // little earlier in time
	}
	
	function SetInitialPickupAnimation(player, weapon, scope = null)
	{
		if (!scope || !player || !player.IsValid() || !weapon || !weapon.IsValid())
			return;
		
		if (HasLaserSightFlag(weapon))
		{
			RemoveLaserSight(weapon);
			UnSetLaserSightFlag(weapon);
		}
		
		local viewModel = NetProps.GetPropEntity(player, "m_hViewModel");
		if (!viewModel || weapon != NetProps.GetPropEntity(viewModel, "m_hWeapon") /*|| viewModel.LookupSequence("ACT_PRIMARY_VM_IDLE") == -1*/)
			return;
		
		scope.weapon.pickup = weapon;
		
		if (!OldDeployStyle)
			return;
		
		local seq = NetProps.GetPropInt(viewModel, "m_nLayerSequence");
		local actname = viewModel.GetSequenceActivityName(seq);
		if (actname != "ACT_VM_DEPLOY_LAYER" && actname != "ACT_VM_DEPLOY_SNIPER_LAYER")
			return;
		
		local initpick = LookupAnimations(viewModel, "ACT_VM_DRAW");
		if (initpick == -1)
			return;
		
		local playRate = GetAnimationsPlaybackRate(weapon);
		//local old_animTime = viewModel.GetSequenceDuration(seq) / playRate;
		local animTime = viewModel.GetSequenceDuration(initpick) / playRate;
		
		local curTime = Time();
		local timestamp = curTime + animTime; //GetBestNextPrimaryAttackTime(weapon, old_animTime, animTime, curTime);
		NetProps.SetPropFloat(weapon, "m_flNextPrimaryAttack", timestamp);
		//NetProps.SetPropFloat(player, "m_flNextAttack", timestamp);
		
		NetProps.SetPropInt(viewModel, "m_nLayer", 0);
		NetProps.SetPropInt(viewModel, "m_nLayerSequence", initpick);
		NetProps.SetPropFloat(viewModel, "m_flLayerStartTime", curTime);
	}
	
	function IsAllowInspect()
	{
		switch (DisableInspect)
		{
			case 1:
				return false;
			case 2:
				return !("L4D2Lxc_IW" in getroottable());
			default:
				return true;
		}
	}
	
	function UpdateBindKeyPressStatus(player, arg)
	{
		//printl(player + " - " + arg);
		
		if (arg == null || !player || !player.IsValid())
			return;
		
		local args = split(arg, ",");
		if (args.len() != 2)
			return;
		
		local key = args[0];
		local val = args[1];
		
		local id = player.GetPlayerUserId();
		if (id in HumanSurvivors && key in HumanSurvivors[id].button)
			HumanSurvivors[id].button[key] = StringToInteger2(val);
	}
	
	function AddUserConsoleCommandHook()
	{
		if (!("L4D2Lxc_HOOKS" in getroottable()))
			return;
		
		::L4D2Lxc_HOOKS.AddHooks("LXC", "cmd", "ADS", UpdateBindKeyPressStatus.bindenv(::L4D2Lxc_ADS));
	}
	
	function GetPointClientCommandEntity()
	{
		local point_cmd, ent;
		while (ent = Entities.FindByName(ent, "lxc_point_client_cmd"))
		{
			point_cmd = ent;
			break;
		}
		if (!point_cmd)
			point_cmd = SpawnEntityFromTable("point_clientcommand", { targetname = "lxc_point_client_cmd" });
		
		return point_cmd;
	}
	
	function InitializeVariablesAndCommands(client, delay = 0.1)
	{
		local point_cmd = GetPointClientCommandEntity();
		if (point_cmd)
		{
			local log = "Aim Down Sight Addon [VScript]: Initialize keybinds stuffs";
			DoEntFire("!self", "Command", @"
				echo """ + log + @""";
				alias ""+ads_switch"" ""scripted_user_func ads_key_pressed,1"";
				alias ""-ads_switch"" ""scripted_user_func ads_key_pressed,0"";
				alias ""+ads_combine_switch"" ""scripted_user_func combine_key_pressed,1"";
				alias ""-ads_combine_switch"" ""scripted_user_func combine_key_pressed,0"";
				alias ""+ads_inspect_switch"" ""scripted_user_func inspect_key_pressed,1"";
				alias ""-ads_inspect_switch"" ""scripted_user_func inspect_key_pressed,0"";
			", delay, client, point_cmd);
		}
	}
	
	function ReleaseDefaultSettings()
	{
		local defaultContent =
		[
			"\"Settings\"",
			"{",
				"\tActivateButton = BUTTON_ZOOM",
				"\tSmartHoldingKey = 0.5",
				"\tCombineButton = BUTTON_USE",
				"\tCombineBtnHolding = 0.5",
				"\tAttackRetreatDelay = 1.5",
				"\tFovScaling = 0",
				"\tFovADS = 75",
				"\tFovDefault = -1",
				"\tRecoilFactor = 0.5",
				"\tSpreadReduce = 1",
				"\tHideLaserSight = 1",
				"\tHideBulletTracers = 0",
				"\tForceEmptyReloadAnim = 1",
				"\tForceWalk = 0",
				"\tOffADS_InReload = 1",
				"\tOffADS_InShove = 2",
				"\tOffADS_Restart = 0",
				"\tOldDeployStyle = 0",
				"\tDisableInspect = 0",
				"\tInspectButton = BUTTON_RELOAD",
				"\tHolsterWeapon = 0",
				"\tManualReload = 2",
				"\tPreventShotgunReloadFiring = 0",
				"\tIgnoreClient = 0",
				"\tStableMode = 1",
			"}",
			"",
		];
		
		local FileContent = defaultContent.reduce(@(a, b) a + "\n" + b) + "\n";
		StringToFile(SettingsFilePath, FileContent);
		
		printl("Aim Down Sight Addon [VScript]: Default settings file released");
		
		LoadConfig();
	}
	
	function GetButtonName(button_bitfield)
	{
		switch (button_bitfield)
		{
			case 1: return "BUTTON_ATTACK";
			case 2: return "BUTTON_JUMP";
			case 4: return "BUTTON_DUCK";
			case 8: return "BUTTON_FORWARD";
			case 16: return "BUTTON_BACK";
			case 32: return "BUTTON_USE";
			case 64: return "BUTTON_CANCEL";
			case 128: return "BUTTON_LEFT";
			case 256: return "BUTTON_RIGHT";
			case 512: return "BUTTON_MOVELEFT";
			case 1024: return "BUTTON_MOVERIGHT";
			case 2048: return "BUTTON_SHOVE";
			case 4096: return "BUTTON_RUN";
			case 8192: return "BUTTON_RELOAD";
			case 16384: return "BUTTON_ALT1";
			case 32768: return "BUTTON_ALT2";
			case 65536: return "BUTTON_SCORE";
			case 131072: return "BUTTON_WALK";
			case 524288: return "BUTTON_ZOOM";
			case 1048576: return "BUTTON_WEAPON1";
			case 2097152: return "BUTTON_WEAPON2";
			case 4194304: return "BUTTON_BULLRUSH";
			case 8388608: return "BUTTON_GRENADE1";
			case 16777216: return "BUTTON_GRENADE2";
			case 33554432: return "BUTTON_LOOKSPIN";
			default: return button_bitfield;
		}
	}
	
	function GetTableFromKeyName(key, string, rexpTable = regexp(@"{}|{.*}"))
	{
		if (key == "" || string == "")
			return "";
		
		// only search the first match place
		local tbl = "";
		local index = string.find(key);
		if (index != null)
		{
			local findtbl = rexpTable.search(string.slice(index));
			if (findtbl != null)
				tbl = string.slice(index + findtbl.begin, index + findtbl.end);
		}
		return tbl;
	}
	
	function PackageString(text)
	{
		if (typeof(text) != "string")
			return text;
		
		local delDouble = split(text, "\"");
		return "\"" + (delDouble.len() > 0 ? delDouble.reduce(@(a, b) a + b) : "") + "\"";
	}
	
	function DeleteOutdatedSettings(fileContents = "")
	{
		if (fileContents == "")
			return fileContents;
		
		local outdated =
		[
			"ShotgunReloadEndAnimFix",
		]
		
		local del = false;
		foreach (setting in outdated)
		{
			if (fileContents.find(setting) == null)
				continue;
			
			del = true;
			break;
		}
		
		if (!del)
			return fileContents;
		
		local fileArray = split(fileContents, "\r\n");
		foreach (setting in outdated)
			fileArray = fileArray.filter(@(index, value) value.find(setting) == null);
		
		fileContents = fileArray.reduce(@(a, b) a + "\n" + b) + "\n\n";
		StringToFile(SettingsFilePath, fileContents);
		
		printl("Aim Down Sight Addon [VScript]: Remove outdated settings");
		
		return fileContents;
	}
	
	function AddNewSettingsToFile(fileContents = "", settingsContents = "", settingsTable = null)
	{
		if (fileContents == "" || settingsTable == "" || !settingsTable)
			return;
		
		local Order =
		[
			"ActivateButton",
			"SmartHoldingKey",
			"CombineButton",
			"CombineBtnHolding",
			"AttackRetreatDelay",
			"FovScaling",
			"FovADS",
			"FovDefault",
			"RecoilFactor",
			"SpreadReduce",
			"HideLaserSight",
			"HideBulletTracers",
			"ForceEmptyReloadAnim",
			"ForceWalk",
			"OffADS_InReload",
			"OffADS_InShove",
			"OffADS_Restart",
			"OldDeployStyle",
			"DisableInspect",
			"InspectButton",
			"HolsterWeapon",
			"ManualReload",
			"PreventShotgunReloadFiring",
			"IgnoreClient",
			"StableMode",
		]
		
		local miss = {};
		foreach (idx, setting in Order)
		{
			if (!(setting in settingsTable))
			{
				settingsTable[setting] <- this[setting];
				miss[idx] <- setting + " = " + (setting.find("Button") != null ? GetButtonName(this[setting]) : PackageString(this[setting]));
			}
		}
		
		if (miss.len() <= 0)
			return;
		
		local settingsArray = split(settingsContents, "{}\n\t");
		
		local comment = "";
		//local settingsArray = split(settingsContents, "{}\n\t").filter(function(index, value) {return (value.find("//") != 0);});
		if (settingsContents.find("//") != null)
		{
			local i = -1;
			local tmp = "";
			local pos = null;
			foreach (idx, string in clone settingsArray)
			{
				pos = string.find("//");
				if (pos == 0)
				{
					if (tmp == "")
					{
						i = i == -1 ? idx : i + 1;
						tmp += string;
					}
					else
						tmp += "\n\t" + string;
					settingsArray.remove(i);
				}
				else if (tmp != "")
				{
					tmp += "\n\t" + string;
					settingsArray[i] = tmp;
					tmp = "";
				}
				else
					i++;
			}
			if (tmp != "")
			{
				if (pos != 0)
					settingsArray.append(tmp);
				else
					comment = "\n\n\t" + tmp;
			}
		}
		
		local top_pos = -1;
		foreach (idx, key in Order)
		{
			if (idx in miss)
			{
				local setting = miss[idx];
				local max = settingsArray.len() - 1;
				
				if (idx <= max)
					settingsArray.insert(idx, strip(setting));
				else if (idx > top_pos)
					settingsArray.append(strip(setting));
				else
					settingsArray.insert(max, strip(setting));
				
				if (idx > top_pos)
					top_pos = idx;
			}
		}
		
		local begin = fileContents.find(settingsContents);
		local end = begin + settingsContents.len();
		
		local part1 = fileContents.slice(0, begin);
		local part2 = "{\n\t" + settingsArray.reduce(@(a, b) a + "\n\t" + b) + comment + "\n}";
		local part3 = rstrip(fileContents.slice(end)) + "\n\n";
		
		StringToFile(SettingsFilePath, part1 + part2 + part3);
		
		printl("Aim Down Sight Addon [VScript]: Missing settings have been added");
	}
	
	function LoadConfig()
	{
		local data = FileToString(SettingsFilePath);
		if (data && strip(data) != "")
		{
			printl("Aim Down Sight Addon [VScript]: Loading settings file");
			
			data = DeleteOutdatedSettings(data);
			try
			{
				local SettingsTable = GetTableFromKeyName("\"Settings\"", data);
				if (SettingsTable != "")
				{
					local settings = compilestring("return " + SettingsTable)();
					AddNewSettingsToFile(data, SettingsTable, settings);
					
					local lastHideLaserState = HideLaserSight;
					local lastHideTracersState = HideBulletTracers;
					
					foreach (key, val in settings)
					{
						if (key in this)
							this[key] = val;
					}
					IsAttackButton = !!(ActivateButton & BUTTON_ATTACK);
					IsZoomButton = !!(ActivateButton & BUTTON_ZOOM);
					
					if (lastHideLaserState > 0 && HideLaserSight <= 0 && Convars.GetFloat("r_draw_lasersight_1st_person") != 1)
						Convars.SetValue("r_draw_lasersight_1st_person", 1);
					if (lastHideTracersState > 0 && HideBulletTracers <= 0 && Convars.GetFloat("r_drawtracers_firstperson") != 1)
						Convars.SetValue("r_drawtracers_firstperson", 1);
				}
				else
					printl("Not found \"Settings\" table");
			}
			catch(exception)
			{
				error("\n\"Settings\" table load failed\n");
				local funcinfo = LoadConfig.getinfos();
				error("AN ERROR HAS OCCURED [" + exception + "]\n*FUNCTION [" + funcinfo.name + "()] " + funcinfo.src + "\n\n");
			}
			
			return true; // not reset the settings file even has error
		}
		
		return false;
	}
	
	function ReleaseInformation(lang = null)
	{
		foreach (path, files in InfoFilePath)
		{
			foreach (title, filename in files)
			{
				local content = GetInformation(title, lang);
				if (content == null)
					continue;
				
				local filePath = path + filename;
				local fileContents = FileToString(filePath);
				if (fileContents && strip(fileContents) == content)
					continue;
				
				StringToFile(filePath, content + "\n\n");
			}
		}
	}
	
	function StartedADSListener()
	{
		if (!GameStarted)
		{
			GameStarted = true;
			ADSListener();
			printl("Aim Down Sight Addon [VScript]: Started button listener");
		}
	}
	
	function LoadEmsConfigDirectory()
	{
		if (!LoadConfig())
			ReleaseDefaultSettings();
		
		ReleaseInformation();
	}
	
	function OnGameStart()
	{
		ADS_Plugins = Convars.GetFloat("ads_holding_key") != null;
		if (ADS_Plugins)
			printl("Find ADS source plugin.");
		
		AddUserConsoleCommandHook();
		LoadEmsConfigDirectory();
		StartedADSListener();
		
		if (!RestoredData)
		{
			RestoreTransitionData();
			RestoredData = true;
		}
		
		if (FovDefault >= 0 && FovDefault != Convars.GetFloat("fov_desired"))
			SendToServerConsole("fov_desired " + FovDefault + ";");
	}
	
	function OnGameEnd()
	{
		if (GameStarted)
		{
			GameStarted = false;
			RemoveTemporaryEffectsForSurvivors();
			HumanSurvivors.clear();
		}
	}
	
	function StringToInteger(string)
	{
		try
		{
			string = string.tointeger();
		}
		catch(exception)
		{
			// nothing
		}
		return string;
	}
	
	function StringToInteger2(string)
	{
		try
		{
			string = string.tointeger();
		}
		catch(exception)
		{
			string = 0;
		}
		return string;
	}
	
	function StringToBool(string)
	{
		try
		{
			string = string.tointeger() > 0;
		}
		catch(exception)
		{
			string = false;
		}
		return string;
	}
	
	function AddPlayerToADS(userid, player)
	{
		// GetNetworkIDString() in split-screen, the second player is "BOT" -_-
		if (!player || !player.IsValid() || !player.IsSurvivor() || IsPlayerABot(player) /*|| player.GetNetworkIDString() == "BOT"*/)
			return;
		
		if (userid in HumanSurvivors && HumanSurvivors[userid].player == player)
			return;
		
		if (!RestoredData)
		{
			RestoreTransitionData();
			RestoredData = true;
		}
		DoEntFire("!self", "RunScriptCode", "::L4D2Lxc_ADS.RestoreWeaponDataForPlayer(self);", 0.1, null, player);
		
		// client need manually enable, this will avoid animations bug if client use different models with host.
		local isHost = player == GetListenServerHost();
		local ads_default_state = !IgnoreClient || isHost;
		//local pressing = IsPlayerPressingButton(player, isHost); // fixed if ads_state not 0 on game start.
		
		if (isHost)
			InitializeVariablesAndCommands(player);
		
		HumanSurvivors[userid] <-
		{
			player = player,
			ishost = isHost,
			ads_allowed = ads_default_state,
			debug =
			{
				enable = 0
				last_layer_seq = -1
				anim_start_time = 0
			},
			button =
			{
				ads_active = 0
				mode = 0				// 1 = toggle mode, 2 = hold mode
				ads_key_pressed = 0		// check ads bind key press status
				pressed = 0 //pressing
				pressed_time = 0
				//released_time = 0
				//hold_time = 0
				force_walk = 0
				
				combine_mode = 0			// 1 = click, 2 = holding
				combine_key_pressed = 0		// check combine bind key press status
				combine_pressed = 0
				combine_pressed_time = 0
				
				inspect_key_pressed = 0		// check inspect bind key press status
			},
			weapon =
			{
				current = 0
				ent = 0
				name = 0
				model = 0
				type = 0
				
				fov_scaling = 0			// only for host, 0 = hip mode, return to default, 1 = ads mode, scaling to settings
				
				deploy_end = 0
				clip1 = 0
				idle_state = 0			// 0 = normal idle, 1 = switch to idle_empty, 2 = switch to ads_idle_empty, 3 = switch to [ads_]idle_no_fadein
				reload = 0				// m_bInReload
				next_attack = 0
				next_shove = 0			// shove end time
				next_shove_hit = 0		// only set once in each shove
				next_shove_kill = 0		// only set once in each shove
				last_bullet = 0			// for "rifle_m60 drop fix"
				dryfire = 0				// dryfire fix for "rifle_m60 drop fix"
				pickup = 0				// set weapon ent when first pickup
				hide_effects_until = 0	// show crosshair and laser in the time point
				
				mixed_mode = 0
				magnifier = 0
				
				lever_action_rifle = 0		// non-shotgun weapon has reload_(start/loop/end) anim
				lever_action_rifle_deploy_fix = 0		// player_use time
				lever_action_rifle_deploy_fix_layer = 0	// reload.anim_layer
				
				ads_able = 0
				ads_on = 0
				ads_aim_mode = 0		// string: 1st, 2nd, 3rd
				ads_1st = 0
				ads_2nd = 0
				ads_3rd = 0
				ads_pause_until = 0		// quit ads, but restart in the time point
				ads_off_time = 0		// quit ads in the time point
				
				manual_empty_reload = 0
				next_relaod_time = 0	// if pressed reload button while toggle mixed or shove, delay this reload
				manual_reload_timestamp = 0
				
				// only need to know if the anim exist
				inspect = 0
				ads_shove = 0
				ads_reload = 0
				ads_reload_empty = 0
			},
			body =
			{
				scope =
				{
					name = -1		// scope_transform/scope_variable
					group_id = -1	// bodygroup id
					parts_id = -1	// parts id, 0 = mixed_off_scope_off
					mixed_off_scope_off = -1
					mixed_off_scope_on = -1
					mixed_on_scope_off = -1
					mixed_on_scope_on = -1
					fix_mixed_off_scope_off = -1	// fix anim when switch to mixed_off, usually its mixed_off_scope_off
					fix_mixed_on_scope_off = -1		// fix anim when switch to mixed_on, usually its mixed_on_scope_off
					fix_mixed_on_scope_on = -1		// fix anim when switch to mixed_on, usually its mixed_on_scope_on
					off_delay = -1		// when playing mixed_on anim, delay to switch to final parts, default 0.3 if not set
					on_delay = -1		// when playing mixed_off anim, delay to switch to final parts, default 0.5 if not set
					transform_end = -1	// time to complete the scope transformation animation
					delay_switch = -1	// save the time point of the delay switch
				}
			},
			action =
			{
				attack =
				{
					firing = 0
					fire_time = 0
					next_firing = 0
					last_recoil = 0
				}
				reload =
				{
					fix = 0				// when hide crosshair, shove will interrupt reload/deploy/inspect animations
					state = 0			// shotgun has 3 reload state, other guns set to 3
					type = 0
					anim = 0
					anim_duration = 0
					anim_dur_factor = 0	// if reload anim not has both RELOAD and RELOAD_LAYER
					anim_layer = 0
					anim_start_time = 0
					anim_end_time = 0
					anim_rate = 0
					start_time = 0
					end_time = 0
					
					shotgun_end_anim_fix = 0
					shotgun_fake_state = 0
					shotgun_last_state = 0					// fix for model not has the activity "ACT_VM_RELOAD_LOOP_LAYER" & "ACT_VM_RELOAD_END_LAYER"
					shotgun_miss_anim = 0					// fix for model not has the activity "ACT_VM_RELOAD_LOOP_LAYER" & "ACT_VM_RELOAD_END_LAYER"
					shotgun_magazine_reload = 0
					shotgun_magazine_reload_anim_fix = 0
					
					// lever action rifle
					vanilla_reload_cancelled = 0
					keep_ammo = 0
					reload_num = 0
					inserted = 0
					start_anim = 0		// START_LAYER
					start_dur_anim = 0	// START
					insert_anim = 0
					end_anim = 0
					start_anim_dur = 0
					insert_anim_dur = 0
					end_anim_dur = 0
				}
				inspect =
				{
					state = 0
					anim = 0
					next_time = 0
					start_time = 0
					end_time = 0
				}
				// play holster anim when try to switch weapon
				holster =
				{
					state = 0			// 0 = close, 1 = start, 2 = finish
					start_time = 0
					end_time = 0
					next_weapon = 0		// wait holster anim end and switch to this weapon ent
				}
			},
			anim =
			{
				is_new = -1
				layer_seq = -1			// last animation' layer sequence id
				layer_start_time = -1	// last animation' layer start time
				layer_end_time = -1
				act_name = -1			// last animation' activity name
				play_rate = -1
				
				// hip
				// save sequence id
				idle = -1
				idle_empty = -1
				idle_no_fadein = -1
				
				// no longer save sequence id, using activity name, some of them maybe has multi-anim
				inspect = -1
				inspect_empty = -1
				deploy = -1		// (ACT_VM_)DEPLOY_LAYER
				draw = -1		// (ACT_VM_)DRAW_LAYER
				holster = -1	// (ACT_VM_)HOLSTER_LAYER
				
				looking_item_extend = -1
				looking_item_loop = -1
				looking_item_retract = -1
				helping_hand_extend = -1
				helping_hand_loop = -1
				helping_hand_retract = -1
				
				scope_on = -1
				scope_off = -1
				
				shove = -1
				shove_hit = -1
				shove_kill = -1
				fire = -1
				fire_dbl = -1			// weapon has two barrels
				dryfire = -1
				fire_left = -1			// dual pistols 2nd fire
				dryfire_left = -1		// dual pistols fire last
				dual_right_empty = -1		// dual pistols first pistol out of ammo idle (ACT_VM_IDLE_LOWERED)
				
				reload = -1
				reload_empty = -1
				// lever action rifle
				reload_start = -1
				reload_empty_start = -1
				// shotgun
				reload_magazine = -1
				reload_magazine_empty = -1
				reload_loop = -1
				reload_end = -1
				reload_empty_loop = -1
				reload_empty_end = -1
				
				
				// ads
				// save sequence id
				ads_idle = -1
				ads_idle_empty = -1
				ads_idle_no_fadein = -1
				ads_in = -1
				ads_out = -1
				ads_toggle = -1		// toggle to another ads mode
				
				// no longer save sequence id, using activity name, some of them maybe has multi-anim
				ads_scope_on = -1
				ads_scope_off = -1
				
				ads_shove = -1
				ads_shove_hit = -1
				ads_shove_kill = -1
				ads_fire = -1
				ads_fire_dbl = -1			// weapon has two barrels
				ads_dryfire = -1			// weapon has two barrels
				ads_fire_left = -1			// dual pistols 2nd fire
				ads_dryfire_left = -1		// dual pistols fire last
				ads_dual_right_empty = -1		// dual pistols first pistol out of ammo idle (ACT_VM_IDLE_LOWERED)
				
				ads_reload = -1
				ads_reload_empty = -1
				// lever action rifle
				ads_reload_start = -1
				ads_reload_empty_start = -1
				// shotgun
				ads_reload_magazine = -1
				ads_reload_magazine_empty = -1
				ads_reload_loop = -1
				ads_reload_end = -1
				ads_reload_empty_loop = -1
				ads_reload_empty_end = -1
			}
		};
	}
	
	function OnGameEvent_player_spawn(params)
	{
		local id = params["userid"];
		local player = GetPlayerFromUserID(id);
		AddPlayerToADS(id, player);
	}
	
	function OnGameEvent_player_disconnect(params)
	{
		if ("userid" in params && params["userid"] in HumanSurvivors)
			delete HumanSurvivors[params["userid"]];
	}
	
	function OnGameEvent_player_say(params)
	{
		local text = strip(params["text"].tolower());
		if (text.find("!ads ") != 0)
			return;
		
		local args = split(text.slice(5), ", ");
		if (args.len() <= 0)
			return;
		
		local playerid = params["userid"];
		local player = GetPlayerFromUserID(playerid);
		if (!player || !player.IsValid())
			return;
		
		local isAdmin = player == GetListenServerHost();
		
		local cmd = args[0];
		switch (cmd)
		{
			case "debug":
			{
				if (isAdmin && playerid in HumanSurvivors)
				{
					local debug = HumanSurvivors[playerid].debug;
					debug.enable = !debug.enable;
					debug.last_layer_seq = -1;
				}
				break;
			}
			case "reload":
			{
				if (isAdmin)
				{
					LoadEmsConfigDirectory();
				}
				break;
			}
			case "enable":
			{
				if (playerid in HumanSurvivors)
				{
					local scope = HumanSurvivors[playerid];
					local arg = args.len() > 1 ? StringToBool(args[1]) : null;
					switch (arg)
					{
						case false:
							// reset weapon anim
							local aw = player.GetActiveWeapon();
							if (aw && aw.IsValid())
							{
								player.DropItem(aw.GetClassname());
								DoEntFire("!self", "Use", "", 0.1, player, aw);
							}
							if (scope.weapon.name)
							{
								SetTableValueForAllKey(scope.button, 0);
								SetTableValueForAllKey(scope.weapon, 0);
								SetTableValueForAllKey(scope.body, -1);
								SetTableValueForAllKey(scope.action, 0);
								SetTableValueForAllKey(scope.anim, -1);
							}
						case true:
							scope.ads_allowed = arg;
							break;
					}
					printl("ads is " + (scope.ads_allowed ? "enabled" : "disabled") + " for player: " + player.GetPlayerName());
				}
				break;
			}
			case "play": // support sequence id, sequence name, activity name
			{
				if (args.len() > 1)
				{
					local viewModel = NetProps.GetPropEntity(player, "m_hViewModel");
					if (viewModel)
					{
						local ani_id = -1;
						local arg = StringToInteger(args[1]);
						switch (typeof(arg))
						{
							case "integer":
								if (arg != -1 && viewModel.GetSequenceName(arg) != "Unknown")
									ani_id = arg;
								break;
							case "string":
								ani_id = viewModel.LookupSequence(arg);
								break;
						}
						if (ani_id != -1)
						{
							local layer = 0;
							if (args.len() > 2)
								layer = StringToInteger2(args[2]);
							
							NetProps.SetPropInt(viewModel, "m_nLayer", layer);
							NetProps.SetPropInt(viewModel, "m_nLayerSequence", ani_id);
							NetProps.SetPropFloat(viewModel, "m_flLayerStartTime", Time());
							
							if (playerid in HumanSurvivors)
							{
								local scope = HumanSurvivors[playerid];
								scope.debug.anim_start_time = Time();
								SetTableValueForAllKey(scope.action, 0);
							}
						}
					}
				}
				break;
			}
		}
	}
	
	function OnGameEvent_receive_upgrade(params)
	{
		//printl(params["upgrade"]); // LASER_SIGHT INCENDIARY_AMMO EXPLOSIVE_AMMO
		if (params["upgrade"] == "LASER_SIGHT")
		{
			local player = GetPlayerFromUserID(params["userid"]);
			SetFlagForPlayerInventory(player);
		}
	}
	
	function OnGameEvent_item_pickup(params)
	{
		if (!(params["userid"] in HumanSurvivors))
			return;
		
		local player = GetPlayerFromUserID(params["userid"]);
		local item = player.FirstMoveChild();
		
		SetInitialPickupAnimation(player, item, HumanSurvivors[params["userid"]]);
	}
	
	function OnGameEvent_weapon_drop(params)
	{
		if (!("item" in params))
			return;
		
		local item = EntIndexToHScript(params["propid"]);
		if (!item || !item.IsValid())
			return;
		
		if (HasLaserSightFlag(item))
		{
			RemoveLaserSight(item);
			UnSetLaserSightFlag(item);
		}
		
		if (HasMixedFlag(item))
			UnSetMixedFlag(item);
	}
	
	function OnGameEvent_revive_begin(params)
	{
		if (!(params["userid"] in HumanSurvivors))
			return;
		
		local player = GetPlayerFromUserID(params["userid"]);
		local scope = HumanSurvivors[params["userid"]];
		
		local aw = player.GetActiveWeapon();
		if (!aw || !aw.IsValid() || aw != scope.weapon.ent)
			return;
		
		local reload = scope.action.reload;
		if (reload.fix)
		{
			reload.fix = 0;
			
			if (aw.Clip1() > 0 && NetProps.GetPropInt(aw, "m_reloadFromEmpty") > 0)
				NetProps.SetPropInt(aw, "m_reloadFromEmpty", 0);
			
			if (scope.weapon.lever_action_rifle)
			{
				local curTime = Time();
				NetProps.SetPropFloat(aw, "m_flNextPrimaryAttack", curTime + DeltaTime);
				NetProps.SetPropFloat(player, "m_flNextAttack", curTime);
				local viewModel = NetProps.GetPropEntity(player, "m_hViewModel");
				SetViewAnimation(viewModel, -1, reload.anim_layer, curTime);
				scope.action.attack.next_firing = 0;
			}
		}
	}
	
	function OnGameEvent_player_use(params)
	{
		if (!(params["userid"] in HumanSurvivors))
			return;
		
		local player = GetPlayerFromUserID(params["userid"]);
		local target = EntIndexToHScript(params["targetid"]);
		
		if (!target || !target.IsValid())
			return;
		
		local useAction = NetProps.GetPropInt(player, "m_iCurrentUseAction");
		if (useAction > 0)
		{
			local curTime = Time();
			// func_button_timed first pressed																				// point_script_use_target
			if ((useAction == 10 && curTime <= NetProps.GetPropFloat(player, "m_flProgressBarStartTime") + DeltaTime + 0.001) || useAction == 11)
			{
				local scope = HumanSurvivors[params["userid"]];
				if (!scope.action.reload.fix)
					return;
				
				scope.action.reload.fix = 0;
				
				local aw = player.GetActiveWeapon();
				if (!aw || !aw.IsValid() || aw != scope.weapon.ent)
					return;
				
				if (aw.Clip1() > 0 && NetProps.GetPropInt(aw, "m_reloadFromEmpty") > 0)
					NetProps.SetPropInt(aw, "m_reloadFromEmpty", 0);
				
				if (scope.weapon.lever_action_rifle)
				{
					scope.weapon.lever_action_rifle_deploy_fix = curTime;
					scope.weapon.lever_action_rifle_deploy_fix_layer = scope.action.reload.anim_layer;
					return;
				}
				
				if (scope.weapon.type != "shotgun")
					return;
				
				// fix for shotgun magazine reload + "PreventShotgunReloadFiring"
				if (NetProps.GetPropInt(aw, "m_bInReload") != 0)
					return;
				
				if (useAction == 11)
				{
					NetProps.SetPropFloat(aw, "m_flNextPrimaryAttack", curTime + DeltaTime);
					NetProps.SetPropFloat(player, "m_flNextAttack", curTime);
					return;
				}
				
				local viewModel = NetProps.GetPropEntity(player, "m_hViewModel");
				if (viewModel)
				{
					local deploy = scope.anim.deploy; //viewModel.LookupSequence("ACT_VM_DEPLOY_LAYER");
					if (deploy != -1)
					{
						deploy = viewModel.LookupSequence(deploy);
						SetViewAnimation(viewModel, deploy, 0, curTime);
						
						local playRate = GetAnimationsPlaybackRate(aw);
						local timestamp = curTime + (viewModel.GetSequenceDuration(deploy) / playRate);
						NetProps.SetPropFloat(aw, "m_flNextPrimaryAttack", timestamp);
						NetProps.SetPropFloat(player, "m_flNextAttack", curTime);
					}
				}
			}
			return;
		}
		
		if (target.GetClassname() == "upgrade_laser_sight")
		{
			SetFlagForPlayerInventory(player);
			return;
		}
		
		// make sure the player pick it up
		if (target.GetMoveParent() != player)
			return;
		
		SetInitialPickupAnimation(player, target, HumanSurvivors[params["userid"]]);
	}
	
	function OnGameEvent_weapon_fire(params)
	{
		// skip minigun
		if (params["weaponid"] == 54)
			return;
		
		local id = params["userid"];
		if (!(id in HumanSurvivors))
			return;
		
		local player = GetPlayerFromUserID(id);
		if (!player || !player.IsValid())
			return;
		
		local curTime = Time();
		local scope = HumanSurvivors[id];
		
		local state = scope.weapon;
		if (state.ads_pause_until > curTime)
			state.ads_pause_until = curTime;
		
		local aw = player.GetActiveWeapon();
		if (aw && aw.IsValid())
		{
			if (NetProps.GetPropInt(aw, "m_reloadFromEmpty") > 0)
				NetProps.SetPropInt(aw, "m_reloadFromEmpty", 0);
			
			if (params["weapon"] == "rifle_m60" /*&& state.clip1 && state.clip1 == NetProps.GetPropInt(player, "m_iShotsFired")*/) // last bullet
			{
				switch (aw.Clip1())
				{
					case 2:
						if (!state.last_bullet)
						{
							state.last_bullet = 1;
							// fix empty reload anim for another "m60 drop fix" mod, this one empty the clip in the second to last fire.
							NetProps.SetPropInt(aw, "m_reloadFromEmpty", 1);
							break;
						}
						// found "m60 drop fix", this one i used will add one bullet in last fire.
					case 1:
					case 0: // maybe?
						state.last_bullet = 0;
						state.dryfire = 1;
						NetProps.SetPropInt(aw, "m_reloadFromEmpty", 1);
						break;
					default:
						state.last_bullet = 0;
						state.dryfire = 0;
				}
			}
		}
		
		local action = scope.action;
		local attack = action.attack;
		if (attack.fire_time == curTime)
			return;
		
		attack.firing = 1;
		attack.fire_time = curTime;
		attack.last_recoil = NetProps.GetPropVector(player, "localdata.m_Local.m_vecPunchAngle");
		
		local reload = action.reload;
		if (reload.fix)
		{
			reload.fix = 0;
			// Event always triggers before the Entfire, so we need to fix the ammo in here
			if (reload.shotgun_magazine_reload && curTime >= reload.anim_end_time)
			{
				local goal = NetProps.GetPropInt(aw, "LocalShotgunData.m_reloadNumShells");
				local inserted = NetProps.GetPropInt(aw, "LocalShotgunData.m_shellsInserted");
				if (goal == 1 && inserted == 0)
					NetProps.SetPropInt(aw, "LocalShotgunData.m_shellsInserted", 1);
				SetShotgunMagazine(player, aw);
			}
		}
		
		local inspect = action.inspect;
		if (inspect.state > 0)
			inspect.state = -1;
	}
	
	/* // can set anim in here, but this event not always fire if the bullet not hit something or use grenade launcher
	function OnGameEvent_bullet_impact(params)
	{
		local id = params["userid"];
		if (!(id in HumanSurvivors) || !HumanSurvivors[id].weapon.ads_on)
			return;
		
		local player = HumanSurvivors[id].player;
		local viewModel = NetProps.GetPropEntity(player, "m_hViewModel");
		local curAnim = HumanSurvivors[id].anim.ads_attack;
		
		if (curAnim != -1)
			NetProps.SetPropInt(viewModel, "m_nLayerSequence", curAnim);
	}*/
	
	// start anim fix, play activity "ACT_PRIMARY_VM_RELOAD_LAYER", get real anim time from activity "ACT_PRIMARY_VM_RELOAD", and so on.
	// vanilla game playing ACT_VM_RELOAD_LAYER animations, and using ACT_VM_RELOAD duration as m_flNextPrimaryAttack time. 
	function GetCorrectReloadTimeSequence(viewModel, anim)
	{
		//local seq_name = viewModel.GetSequenceName(anim);
		local anim_name = viewModel.GetSequenceActivityName(anim).tolower(); //seq_name.tolower();
		local idx_layer = anim_name.find("_layer");
		if (idx_layer != null)
		{
			local nolayer = anim - 1;
			local _anim = anim_name.slice(0, idx_layer);
			if (_anim == viewModel.GetSequenceActivityName(nolayer).tolower())
				return nolayer;
			
			_anim = viewModel.LookupSequence(_anim);
			if (_anim != -1)
				return _anim;
		}
		return anim;
	}
	
	function GetCorrectReloadTimeAnimation(start_anim)
	{
		local idx_layer = start_anim.find("_LAYER");
		if (idx_layer != null)
			return start_anim.slice(0, idx_layer);
		
		return start_anim;
	}
	
	function SetShotgunReloadAnimations(reload, viewModel, event, weapon, anim, playRate, GetReloadStateAnimFunc)
	{
		if (!(weapon.model in ReloadSets) || ReloadSets[weapon.model].len() <= 0)
		{
			reload.start_anim = GetReloadStateAnimFunc(viewModel, event, 1, anim);
			reload.start_dur_anim = GetCorrectReloadTimeSequence(viewModel, reload.start_anim);
			reload.insert_anim = GetReloadStateAnimFunc(viewModel, event, 2, anim);
			reload.end_anim = GetReloadStateAnimFunc(viewModel, event, 3, anim);
			
			reload.start_anim_dur = reload.start_dur_anim == -1 ? 0 : viewModel.GetSequenceDuration(reload.start_dur_anim) / playRate;
			reload.insert_anim_dur = reload.insert_anim == -1 ? 0 : viewModel.GetSequenceDuration(reload.insert_anim) / playRate;
			reload.end_anim_dur = reload.end_anim == -1 ? 0 : viewModel.GetSequenceDuration(reload.end_anim) / playRate;
			
			return false;
		}
		
		local set_num = 0;
		local scope = ReloadSets[weapon.model];
		
		// start
		local anim_start = -1;
		local anim_start_layer = GetReloadStateAnimFunc(null, event, 1, anim);
		if (anim_start_layer != -1)
		{
			reload.start_anim = viewModel.LookupSequence(anim_start_layer);
			
			local scope_start_layer = anim_start_layer in scope ? scope[anim_start_layer] : null;
			if (scope_start_layer)
				set_num = scope_start_layer.find(reload.start_anim);
			
			anim_start = GetCorrectReloadTimeAnimation(anim_start_layer);
			if (anim_start != anim_start_layer && anim_start in scope && set_num <= scope[anim_start].len() - 1)
				reload.start_dur_anim = scope[anim_start][set_num];
			else
				reload.start_dur_anim = reload.start_anim;
		}
		reload.start_anim_dur = reload.start_dur_anim == -1 ? 0 : viewModel.GetSequenceDuration(reload.start_dur_anim) / playRate;
		
		// loop
		local anim_loop = GetReloadStateAnimFunc(null, event, 2, anim);
		if (anim_loop != -1)
		{
			reload.insert_anim = viewModel.LookupSequence(anim_loop);
			
			local scope_loop = anim_loop in scope ? scope[anim_loop] : null;
			if (scope_loop)
			{
				if (set_num <= scope_loop.len() - 1)
					reload.insert_anim = scope_loop[set_num];
				else
					set_num = scope_loop.find(reload.insert_anim);
			}
		}
		reload.insert_anim_dur = reload.insert_anim == -1 ? 0 : viewModel.GetSequenceDuration(reload.insert_anim) / playRate;
		
		// end
		local anim_end = GetReloadStateAnimFunc(null, event, 3, anim);
		if (anim_end != -1)
		{
			reload.end_anim = viewModel.LookupSequence(anim_end);
			
			local scope_end = anim_end in scope ? scope[anim_end] : null;
			if (scope_end)
			{
				if (set_num <= scope_end.len() - 1)
					reload.end_anim = scope_end[set_num];
			}
		}
		reload.end_anim_dur = reload.end_anim == -1 ? 0 : viewModel.GetSequenceDuration(reload.end_anim) / playRate;
		
		return true;
	}
	
	function Event_reload_shotgun(curTime, player, aw, viewModel, reload, state, anim)
	{
		local event = "reload";
		if (state.ads_on && state.ads_reload)
			event = "ads_reload";
		
		if (NetProps.GetPropInt(aw, "m_reloadFromEmpty") > 0)
		{
			if (state.ads_on && state.ads_reload_empty)
				event = "ads_reload_empty";
			else if (anim.reload_empty != -1 && (event == "reload" || ForceEmptyReloadAnim))
				event = "reload_empty";
		}
		
		local playRate = GetAnimationsPlaybackRate(aw);
		SetShotgunReloadAnimations(reload, viewModel, event, state, anim, playRate, GetShotgunReloadStateAnim);
		
		local clip = aw.Clip1();
		local ammoType = NetProps.GetPropInt(aw, "m_iPrimaryAmmoType");
		local ammo = NetProps.GetPropIntArray(player, "m_iAmmo", ammoType);
		reload.reload_num = aw.GetMaxClip1() - clip;
		if (reload.reload_num > ammo)
			reload.reload_num = ammo;
		
		reload.state = 1;
		reload.inserted = 1;
		
		reload.fix = 1;
		reload.type = event;
		reload.anim = reload.start_anim;
		reload.anim_dur_factor = 1.0;
		reload.anim_duration = reload.start_anim_dur;
		reload.anim_layer = 0;
		reload.anim_start_time = curTime;
		reload.anim_end_time = curTime + reload.anim_duration;
		reload.anim_rate = playRate;
		//reload.start_time = curTime;
		reload.end_time = curTime + reload.start_anim_dur + (reload.insert_anim_dur * (reload.reload_num - 1)) + reload.end_anim_dur;
		
		// reload end animations may flicker or jitter
		reload.shotgun_end_anim_fix = (viewModel.GetSequenceActivityName(reload.end_anim) != "ACT_VM_RELOAD_END_LAYER");
		
		if (state.ads_on && IsCloseADSWhileAction(event, state, reload.end_time))
			state.ads_on = false;
	}
	
	function Event_reload_lever_action_rifle(curTime, player, aw, viewModel, reload, state, anim)
	{
		local event = "reload";
		if (state.ads_on && anim.ads_reload_start != -1)
			event = "ads_reload";
		
		if (NetProps.GetPropInt(aw, "m_reloadFromEmpty") > 0)
		{
			if (state.ads_on && anim.ads_reload_empty_start != -1)
				event = "ads_reload_empty";
			else if (anim.reload_empty_start != -1 && (event == "reload" || ForceEmptyReloadAnim))
				event = "reload_empty";
		}
		
		local playRate = GetAnimationsPlaybackRate(aw);
		SetShotgunReloadAnimations(reload, viewModel, event, state, anim, playRate, GetLeverActionRifleReloadStateAnim);
		
		local clip = aw.Clip1();
		local ammoType = NetProps.GetPropInt(aw, "m_iPrimaryAmmoType");
		local ammo = NetProps.GetPropIntArray(player, "m_iAmmo", ammoType);
		if (clip == 0 && state.clip1 > 0)
		{
			clip = state.clip1;
			reload.keep_ammo = clip;
			ammo -= clip;
		}
		reload.reload_num = aw.GetMaxClip1() - clip;
		if (reload.reload_num > ammo)
			reload.reload_num = ammo;
		
		reload.state = 1;
		reload.inserted = 1;
		
		reload.fix = 1;
		reload.type = event;
		reload.anim = reload.start_anim;
		reload.anim_dur_factor = 1.0;
		reload.anim_duration = reload.start_anim_dur;
		reload.anim_layer = 3;
		reload.anim_start_time = curTime;
		reload.anim_end_time = curTime + reload.anim_duration;
		reload.anim_rate = playRate;
		//reload.start_time = curTime;
		reload.end_time = curTime + reload.start_anim_dur + (reload.insert_anim_dur * (reload.reload_num - 1)) + reload.end_anim_dur;
		
		// must set layer 3 to fix the "delta" animations
		// TODO find a way to use layer 0
		NetProps.SetPropInt(viewModel, "m_nLayer", 3);
		NetProps.SetPropInt(viewModel, "m_nLayerSequence", reload.start_anim);
		//NetProps.SetPropFloat(viewModel, "m_flLayerStartTime", curTime);
		
		//NetProps.SetPropInt(viewModel, "m_nLayer", 0);
		//NetProps.SetPropInt(viewModel, "m_nLayerSequence", -1);
		//NetProps.SetPropFloat(viewModel, "m_flLayerStartTime", curTime);
		
		NetProps.SetPropFloat(aw, "m_flNextPrimaryAttack", reload.end_time);
		NetProps.SetPropFloat(player, "m_flNextAttack", reload.end_time);
		
		if (state.ads_on && IsCloseADSWhileAction(event, state, reload.end_time))
			state.ads_on = false;
	}
	
	function OnGameEvent_weapon_reload(params)
	{
		local id = params["userid"];
		if (!(id in HumanSurvivors))
			return;
		
		local player = GetPlayerFromUserID(id);
		if (!player || !player.IsValid())
			return;
		
		local aw = player.GetActiveWeapon();
		local viewModel = NetProps.GetPropEntity(player, "m_hViewModel");
		
		if (!aw || !aw.IsValid() || !viewModel /*|| viewModel.LookupSequence("ACT_PRIMARY_VM_IDLE") == -1*/)
			return;
		
		local curTime = Time();
		local scope = HumanSurvivors[id];
		
		local reload = scope.action.reload;
		if (reload.start_time == curTime)
			return;
		
		SetTableValueForAllKey(reload, 0);
		reload.start_time = curTime;
		
		local anim = scope.anim;
		local state = scope.weapon;
		
		// manual_empty_reload
		if (state.next_relaod_time)
		{
			state.next_relaod_time = 0;
			state.manual_reload_timestamp = 0;
		}
		
		if (state.type == "shotgun")
		{
			Event_reload_shotgun(curTime, player, aw, viewModel, reload, state, anim);
			return;
		}
		else if (state.lever_action_rifle)
		{
			Event_reload_lever_action_rifle(curTime, player, aw, viewModel, reload, state, anim);
			return;
		}
		
		local seq = NetProps.GetPropInt(viewModel, "m_nLayerSequence");
		local actname = viewModel.GetSequenceActivityName(seq);
		
		local playRate = GetAnimationsPlaybackRate(aw);
		local animTime = viewModel.GetSequenceDuration(seq) / playRate;
		
		local event = "reload";
		local reload_ani = -1;
		if (state.ads_on && state.ads_reload)
		{
			event = "ads_reload";
			reload_ani = anim.ads_reload;
		}
															// pistol, dual pistols, magnum
		if (NetProps.GetPropInt(aw, "m_reloadFromEmpty") > 0 || actname == "ACT_VM_RELOAD_EMPTY_LAYER")
		{
			if (state.ads_on && state.ads_reload_empty)
			{
				event = "ads_reload_empty";
				reload_ani = anim.ads_reload_empty;
			}
			else if (anim.reload_empty != -1 && (reload_ani == -1 || ForceEmptyReloadAnim))
			{
				event = "reload_empty";
				reload_ani = anim.reload_empty;
			}
		}
		
		// fix for Desert Eagle + R8 Revolver (Magnum): https://steamcommunity.com/sharedfiles/filedetails/?id=3568458136
		if (!state.ads_able && (event == "reload" || state.type == "pistol"))
			return;
		
		if (reload_ani != -1)
			reload_ani = viewModel.LookupSequence(reload_ani);
		
		if (reload_ani != -1 && reload_ani != seq)
		{
			seq = reload_ani;
			
			//NetProps.SetPropInt(viewModel, "m_nLayer", 0);
			NetProps.SetPropInt(viewModel, "m_nLayerSequence", seq);
			//NetProps.SetPropFloat(viewModel, "m_flLayerStartTime", curTime);
		}
		
		reload.anim_dur_factor = 1.0;
		reload.start_dur_anim = GetCorrectReloadTimeSequence(viewModel, seq);
		if (reload.start_dur_anim == seq) // fallback
		{
			local old_animTime = animTime;
			animTime = viewModel.GetSequenceDuration(seq) / playRate;
			reload.anim_dur_factor = GetBestNextPrimaryAttackTimeFactor(aw, old_animTime, animTime, curTime);
			//printl("reload.anim_dur_factor = " + reload.anim_dur_factor);
		}
		reload.anim_duration = (viewModel.GetSequenceDuration(reload.start_dur_anim) / playRate) * reload.anim_dur_factor;
		
		reload.fix = 1;
		reload.state = 3;
		reload.type = event;
		reload.anim = seq;
		reload.anim_start_time = curTime;
		reload.anim_end_time = curTime + reload.anim_duration;
		reload.anim_rate = playRate;
		//reload.start_time = curTime;
		reload.end_time = reload.anim_end_time;
		
		NetProps.SetPropFloat(aw, "m_flNextPrimaryAttack", reload.end_time);
		NetProps.SetPropFloat(player, "m_flNextAttack", reload.end_time);
		
		if (state.ads_on && IsCloseADSWhileAction(event, state, reload.end_time))
			state.ads_on = false;
	}
	
	function SetShoveHitAnimation(id)
	{
		if (!(id in HumanSurvivors))
			return;
		
		local player = GetPlayerFromUserID(id);
		if (!player || !player.IsValid())
			return;
		
		local aw = player.GetActiveWeapon();
		if (!aw || !aw.IsValid())
			return;
		
		local swingTime = NetProps.GetPropFloat(aw, "m_swingTimer.m_timestamp");
		local scope = HumanSurvivors[id];
		if (swingTime == scope.weapon.next_shove_hit)
			return;
		
		scope.weapon.next_shove_hit = swingTime;
		
		local anim = scope.anim;
		local shove_anim = scope.weapon.ads_on ? anim.ads_shove_hit : anim.shove_hit;
		if (shove_anim == -1)
			return;
		
		local viewModel = NetProps.GetPropEntity(player, "m_hViewModel");
		if (!viewModel)
			return;
		
		local seq = NetProps.GetPropInt(viewModel, "m_nLayerSequence");
		local actname = viewModel.GetSequenceActivityName(seq);
		if (actname == shove_anim)
			return;
		
		shove_anim = viewModel.LookupSequence(shove_anim);
		SetViewAnimation(viewModel, shove_anim, 3, -1, anim);
	}
	
	function OnGameEvent_entity_shoved(params)
	{
		SetShoveHitAnimation(params["attacker"]);
	}
	
	function OnGameEvent_player_shoved(params)
	{
		SetShoveHitAnimation(params["attacker"]);
	}
	
	function SetShoveKillAnimation(id)
	{
		if (!(id in HumanSurvivors))
			return;
		
		local player = GetPlayerFromUserID(id);
		if (!player || !player.IsValid())
			return;
		
		local aw = player.GetActiveWeapon();
		if (!aw || !aw.IsValid())
			return;
		
		local swingTime = NetProps.GetPropFloat(aw, "m_swingTimer.m_timestamp");
		local scope = HumanSurvivors[id];
		if (swingTime != scope.weapon.next_shove_hit || swingTime == scope.weapon.next_shove_kill)
			return;
		
		scope.weapon.next_shove_kill = swingTime;
		
		local anim = scope.anim;
		local shove_anim = scope.weapon.ads_on ? anim.ads_shove_kill : anim.shove_kill;
		if (shove_anim == -1)
			return;
		
		local viewModel = NetProps.GetPropEntity(player, "m_hViewModel");
		if (!viewModel)
			return;
		
		local seq = NetProps.GetPropInt(viewModel, "m_nLayerSequence");
		local actname = viewModel.GetSequenceActivityName(seq);
		if (actname == shove_anim)
			return;
		
		shove_anim = viewModel.LookupSequence(shove_anim);
		SetViewAnimation(viewModel, shove_anim, 3, -1, anim);
	}
	
	function OnGameEvent_melee_kill(params)
	{
		SetShoveKillAnimation(params["userid"]);
	}
	
	function OnGameEvent_player_death(params)
	{
		if (!("attacker" in params) || !("type" in params) || params["type"] != 128) // 128 DMG_CLUB
			return;
		
		SetShoveKillAnimation(params["attacker"]);
	}
	
	/* // do not trust this event
	function OnGameEvent_weapon_zoom(params)
	{
		//"userid"	"short"
		printl("weapon_zoom");
		
		if (!(params["userid"] in HumanSurvivors))
			return;
		
		local player = HumanSurvivors[params["userid"]].player;
		local viewModel = NetProps.GetPropEntity(player, "m_hViewModel");
		
		//printl(NetProps.GetPropInt(player, "m_hZoomOwner"));
		//printl(NetProps.GetPropInt(player, "m_iFOV"));
		
		if (viewModel.LookupSequence("ACT_PRIMARY_VM_IDLE") == -1)
			return;
		
		if (NetProps.GetPropInt(player, "m_hZoomOwner") > 0 || NetProps.GetPropInt(player, "m_iFOV") != 0)
		{
			local anim = HumanSurvivors[params["userid"]].anim;
			ani.zoom = 1;
		}
	}*/
	
	function OnGameEvent_round_start(params)
	{
		OnGameStart();
	}
	
	function OnGameEvent_map_transition(params)
	{
		SaveTransitionData();
		OnGameEnd();
	}
	
	function OnGameEvent_finale_vehicle_leaving(params)
	{
		OnGameEnd();
	}
	
	function OnGameEvent_finale_win(params)
	{
		OnGameEnd();
	}
	
	function OnGameEvent_round_end(params)
	{
		OnGameEnd();
	}
}
IncludeScript("ads_base_string", ::L4D2Lxc_ADS);
__CollectEventCallbacks(::L4D2Lxc_ADS, "OnGameEvent_", "GameEventCallbacks", ::RegisterScriptGameEventListener);

