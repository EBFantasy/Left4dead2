class ::AITaskUpdateBotFireState extends AITaskSingle
{
	constructor(orderIn, tickIn, compatibleIn, forceIn)
    {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }

	name = "updateFireState";
	single = true;
	updating = {};
	playerTick = {};

	// 实现已提升到 BotAI 级 (ai_utils.nut), 此处保留委托以兼容旧引用 (如 ai-heal.nut)
	function hasStaleChargerLock(player) {
		return BotAI.hasStaleChargerLock(player);
	}

	function clearStaleChargerLock(player) {
		return BotAI.clearStaleChargerLock(player);
	}

	function singleUpdateChecker(player) {
		if(!player.IsDead()) {
			local idx = player.GetEntityIndex();
			local stale = hasStaleChargerLock(player);
			local suspended = (idx in BotAI.FireSuspendUntil && Time() < BotAI.FireSuspendUntil[idx]);
			if(stale && !suspended)
				clearStaleChargerLock(player);
			// [预防] charger 控制态 / 释放缓冲期: fire-state 完全闭嘴, 把武器收起/释放/重建交还引擎
			// (= 原版/L4B 行为). 本 bug 根因是 fire-state 在 charger 释放窗口强切武器+强按攻击,
			// 与引擎武器重建撞车 -> viewmodel/动画状态机损坏. 从源头屏蔽该行为即可预防.
			if(BotAI.isUnderChargerControl(player) || stale
				|| suspended) {
				BotAI.UnforceButton(player, 1);
				BotAI.UnforceButton(player, 2048);
				BotAI.setBotTarget(player, null);
				return false;
			}

			if(player in BotAI.ManualMedical) {
				BotAI.setBotTarget(player, null);
				return false;
			}

			BotAI.EnsureTankPrimaryWeapon(player);

			local startPt = player.EyePosition();
			local endPt = startPt + player.EyeAngles().Forward().Scale(2000);
			local m_trace = { start = startPt, end = endPt, ignore = player, mask = g_MapScript.TRACE_MASK_SHOT };
			TraceLine(m_trace);

			if (m_trace.hit && BotAI.IsAlive(m_trace.enthit)) {
				BotAI.botLookAt[player] <- m_trace.enthit;
			} else
				BotAI.botLookAt[player] <- null;

			local wep = player.GetActiveWeapon();
			local ename = " ";

			if(BotAI.IsEntityValid(wep))
				ename = wep.GetClassname();

			if(ename == "weapon_pipe_bomb" || ename == "weapon_molotov" || ename == "weapon_vomitjar") {
				if(!BotAI.HasFlag(player, FL_FROZEN)) {
					BotAI.ChangeItem(player, 1);
					BotAI.DisableButton(player, 1, 0.5);
				} else {
					NetProps.SetPropFloat(wep, "m_flNextPrimaryAttack", Time() - 1);
					BotAI.ForceButton(player, 1 , 0.5);
				}
			}

			if(ename == "weapon_pain_pills" || ename == "weapon_adrenaline" || ename == "weapon_first_aid_kit") {
				NetProps.SetPropFloat(wep, "m_flNextPrimaryAttack", Time() - 1);
			}

			if(player in BotAI.targetLocked && BotAI.IsAlive(BotAI.targetLocked[player])) {
				BotAI.setBotTarget(player, BotAI.targetLocked[player]);
				return true;
			}

			local target = BotAI.getBotTarget(player);
			if(BotAI.IsEntityValid(target) && target.GetClassname() == "tank_rock")
				return true;

			target = BotAI.getSmokerTarget(player);
			if(BotAI.IsEntityValid(target) && BotAI.IsAlive(target) && target.GetEntityIndex() in BotAI.smokerTongue) {
				return true;
			} else {
				BotAI.setSmokerTarget(player, null);
			}

			if (BotAI.IsEntitySurvivor(BotAI.GetTarget(player))) {
				BotAI.UnforceButton(player, 1 );
			}

			if (!m_trace.hit || m_trace.enthit == null || m_trace.enthit == player) {
				BotAI.UnforceButton(player, 1 );
				BotAI.UnforceButton(player, 2048 );
				BotAI.setBotTarget(player, null);
				return false;
			}

			if (m_trace.enthit.GetClassname() == "worldspawn" || !m_trace.enthit.IsValid()) {
				BotAI.UnforceButton(player, 1 );
				BotAI.UnforceButton(player, 2048 );
				BotAI.setBotTarget(player, null);
				return false;
			}

			BotAI.setBotTarget(player, m_trace.enthit);
			return true;
		}

		BotAI.setBotTarget(player, null);
		return false;
	}

	function playerUpdate(player) {
		// [预防] charger 控制态 / 释放缓冲期: fire-state 完全闭嘴, 武器重建交还引擎 (见 singleUpdateChecker)
		local pidx = player.GetEntityIndex();
		if(BotAI.isUnderChargerControl(player) || hasStaleChargerLock(player)
			|| (pidx in BotAI.FireSuspendUntil && Time() < BotAI.FireSuspendUntil[pidx])) {
			BotAI.UnforceButton(player, 1);
			BotAI.UnforceButton(player, 2048);
			updating[player] <- false;
			return;
		}

		local target = BotAI.getBotTarget(player);
		if(!BotAI.IsEntityValid(target))
			target = BotAI.getSmokerTarget(player);

		BotAI.EnsureTankPrimaryWeapon(player);

		if(!(player in BotAI.FullPress))
			BotAI.FullPress[player] <- 0;

		if(BotAI.FullPress[player] > -10)
			BotAI.FullPress[player]--;

		if(BotAI.IsEntityValid(target)) {
			local HasWitch = false;
			local HasPlayer = false;
			local Shot = false;
			local shotDis = 1800;
			local distance = BotAI.nextTickDistance(target, player);
			local targetName = target.GetClassname();
			local isTank = targetName == "player" && target.GetZombieType() == 8;
			local safeBoomerShot = targetName == "player" && target.GetZombieType() == 2
				&& BotAI.IsBoomerSafeToPop(target) && BotAI.IsDesignatedBoomerShooter(player, target);
			local skillFactor = BotAI.BotCombatSkill * 10;
			local meleeRange = Convars.GetFloat("melee_range") + skillFactor;

			if(safeBoomerShot) {
				local held = BotAI.GetHeldItems(player);
				if("slot0" in held && BotAI.IsEntityValid(held.slot0))
					BotAI.ChangeItem(player, 0);
			}

			if(targetName == "player" && target.IsSurvivor() && target != player) {
				if((target.IsIncapacitated() || target.IsHangingFromLedge()) && !BotAI.isPlayerBeingRevived(target) && !target.IsDominatedBySpecialInfected() && distance < 150 && !BotAI.HasTank) {
					DoEntFire("!self", "Use", "", 0, player, target);
					BotAI.ForceButton(player, 32 , 5);
				}
			}

			local allowMeleeForTank = !BotAI.HasActiveTank() || BotAI.CountNearbyCommons(player, 190.0) >= 4;
			if(distance <= meleeRange && BotAI.HasItem(player, "melee") && allowMeleeForTank && !BotAI.HasFlag(player, FL_FROZEN) && !isTank && !safeBoomerShot && !hasStaleChargerLock(player) && !BotAI.IsSurvivorTrapped(player)) {
				if(BotAI.BotDebugMode)
					printl("[BotAI][SWAP] " + BotAI.getPlayerBaseName(player) + " slot=1 reason=melee dist=" + distance);
				BotAI.ChangeItem(player, 1);
			}

			local wep = player.GetActiveWeapon();

			local ename = " ";

			if(BotAI.IsEntityValid(wep))
				ename = wep.GetClassname();

			local notWeapon = ename == "weapon_defibrillator" || ename == "weapon_first_aid_kit";

			if(notWeapon) {
				shotDis = 0;
			}

			local isShotGun = ename == "weapon_pumpshotgun" || ename == "weapon_shotgun_chrome" || ename == "weapon_autoshotgun" || ename == "weapon_shotgun_spas";

			if(isShotGun) {
				shotDis = 600;
			}

			local isSniper = ename == "weapon_hunting_rifle" || ename == "weapon_sniper_military" || ename == "weapon_sniper_awp" || ename == "weapon_sniper_scout";

			if(isSniper) {
				shotDis = 5000;
			}

			local isMelee = ename == "weapon_melee" || ename == "weapon_chainsaw";
			local mel = isMelee && (distance > (meleeRange + 20) || isTank);

			if(!player.IsIncapacitated() && !BotAI.IsSurvivorTrapped(player) && !BotAI.HasFlag(player, FL_FROZEN) && !hasStaleChargerLock(player) && BotAI.GetPrimaryClipAmmo(player) > 0 && mel) {
				if(BotAI.BotDebugMode)
					printl("[BotAI][SWAP] " + BotAI.getPlayerBaseName(player) + " slot=0 reason=primary dist=" + distance);
				BotAI.ChangeItem(player, 0);
			}

			local modelName = " ";
			if(BotAI.IsEntityValid(wep)) {
				modelName = wep.GetModelName();
			}

			local isKnife = isMelee && (modelName == "models/v_models/v_knife_t.mdl" || modelName == "models/weapons/melee/v_machete.mdl" ||
				modelName == "models/weapons/melee/v_katana.mdl" || modelName == "models/weapons/melee/v_fireaxe.mdl" ||
				modelName == "models/weapons/melee/v_crowbar.mdl" || modelName == "models/v_models/v_pitchfork.mdl");

			if(isMelee || BotAI.IsSurvivorTrapped(player)) {
				shotDis = meleeRange;
			}

			if(isKnife && targetName == "player" && target.GetZombieType() == 1 && target.GetEntityIndex() in BotAI.smokerTongue) {
				local tongueLength = BotAI.tongueSpeed / 9 * BotAI.smokerTongue[target.GetEntityIndex()];
				local hitFactor = 420;
				local tongueRange = BotAI.tongueRange;

				if(distance - tongueLength <= hitFactor) {
					BotAI.setSmokerTarget(player, target);
					BotAI.setBotTarget(player, null);
					shotDis = tongueRange + 100;
				}
			}

			if(isMelee && BotAI.GetPrimaryClipAmmo(player) <= 0) {
				BotAI.ReloadPrimaryClip(player);
			}

			if(player in BotAI.targetLocked && BotAI.targetLocked[player] == target)
				Shot = true;

			if(targetName == "infected" && BotAI.IsAlive(target) && distance < shotDis)
				Shot = true;

			if((targetName == "player" && !target.IsGhost() && !target.IsSurvivor() && target.GetZombieType() != 7) && BotAI.IsAlive(target) && distance < shotDis) {
				if(target.GetZombieType() != 2) {
					Shot = true;
				} else {
					Shot = false;
				}
			}

			if(targetName == "player" && target.GetZombieType() == 2) {
				Shot = false;
				if(safeBoomerShot && distance < 1800) {
					if(BotAI.IsOnGround(player) && !BotAI.hasContext(player, "BOTAI_SAFE_BOOMER_JUMP")) {
						BotAI.ForceButton(player, 2, 0.2);
						BotAI.setContext(player, "BOTAI_SAFE_BOOMER_JUMP", 0.8);
					}
					Shot = true;
				}
			}

			if(targetName == "tank_rock" || isTank) {
				if(BotAI.IsEntityValid(wep) && !isMelee && wep.Clip1() <= 0) {
					local ammoAmount = wep.GetMaxClip1() * 0.3;
					if(ammoAmount < 1)
						ammoAmount = 1;
					wep.SetClip1(ammoAmount);
				}
				Shot = true;
			}

			if(target != player && targetName == "player" && target.IsSurvivor()) {
				if(target.IsDominatedBySpecialInfected()) {
					Shot = true;
				} else if(target.IsIncapacitated()) {
					HasPlayer = true;
				}
			}

			if(BotAI.IsPlayerReviving(player))
				HasPlayer = true;

			if(BotAI.IsAlive(target) && targetName == "witch") {
				local WitchState = NetProps.GetPropInt(target, "m_nSequence");
				if(WitchState != ANIM_WITCH_LOSE_TARGET && WitchState != ANIM_WITCH_RUN_AWAY && WitchState != ANIM_SITTING_CRY && WitchState != ANIM_SITTING_STARTLED && WitchState != ANIM_SITTING_AGGRO && WitchState != ANIM_WALK && WitchState != ANIM_WANDER_WALK)
					Shot = true;
				else
					HasWitch = true;
			}

			if(targetName == "func_button_timed") {
				if(BotAI.FullPress[player] <= -5)
					BotAI.FullPress[player] = 50;
			}

			if(BotAI.FullPress[player] > 0)
				Shot = false;

			local isPistol = ename == "weapon_pistol" || ename == "weapon_pistol_magnum" || ename == "weapon_pumpshotgun" || ename == "weapon_shotgun_chrome" || ename == "weapon_hunting_rifle" || ename == "weapon_sniper_military" || ename == "weapon_grenade_launcher" || ename == "weapon_sniper_awp" || ename == "weapon_sniper_scout";

			if(ename == BotAI.BotsNeedToFind || ("IsGhost" in target && target.IsGhost()))
				Shot = false;

			if(Shot && !HasPlayer) {
				if(BotAI.IsEntityValid(wep) && NetProps.GetPropInt(wep, "m_iClip1") <= 0 && !isMelee && player.GetContext("BOTAI_RELOAD") == null) {
					BotAI.ForceButton(player, 8192, 0.5);
					player.SetContext("BOTAI_RELOAD", "reload", 3);
				} else
					BotAI.UnforceButton(player, 8192 );
			}

			if(((BotAI.IsEntityValid(wep) && NetProps.GetPropInt(wep, "m_iClip1") > 0) || isMelee) && (!HasPlayer || player.IsIncapacitated()) && (Shot && !HasWitch)) {
				if(isPistol || isMelee) {
					if(BotAI.HasForcedButton(player, 1 ))
						BotAI.UnforceButton(player, 1 );
					else
						BotAI.ForceButton(player, 1 , 0.1);
				}
				else
					BotAI.ForceButton(player, 1 );
			} else
				BotAI.UnforceButton(player, 1 );

			updating[player] <- false;
		}
		else {
			BotAI.setBotTarget(player, null);
			updating[player] <- false;
		}
	}

	function taskReset(player = null) {
		base.taskReset(player);

		if(player != null)
			BotAI.setBotTarget(player, null);
	}
}
