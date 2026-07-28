class ::AITaskHeal extends AITaskSingle {
	
	constructor(orderIn, tickIn, compatibleIn, forceIn) {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }

	single = true;
	updating = {};
	playerTick = {};

	function singleUpdateChecker(player) {
		if(BotAI.isManualKitHealing(player)) {
			if(BotAI.shouldPauseManualKit(player)) {
				BotAI.RemoveFlag(player, FL_FROZEN);
				BotAI.UnforceButton(player, 1);
			}
			return false;
		}

		if(BotAI.playerDominated > 0 || BotAI.playerFallDown > 0 || BotAI.HasTank || BotAI.IsBotHealing(player)) return false;
		if(BotAI.isChargerWeaponLockout(player)) {
			if(BotAI.BotDebugMode)
				printl("[BotAI][HEAL] blocked heal for " + BotAI.getPlayerBaseName(player) + " (charger lockout)");
			return false;
		}
		local needHealing = BotAI.getPlayerTotalHealth(player) <= 30 || player.IsOnThirdStrike();
		local hasTreatmentItems = BotAI.HasItem(player, "weapon_first_aid_kit");
		local canRest = !BotAI.IsInCombat(player) && player.GetLastKnownArea() != null && !player.GetLastKnownArea().IsDamaging();
		local safeCheck = canRest && !BotAI.validVector(BotAI.getBotDedgeVector(player)) && !BotAI.IsPlayerClimb(player);

		if(needHealing && safeCheck && hasTreatmentItems) {
			printl(BotAI.getPlayerBaseName(player) + " try to heal");
			return true;
		}

		if (!canRest && BotAI.IsBotHealingSelf(player)) {
			BotAI.RemoveFlag(player, FL_FROZEN);
			BotAI.UnforceButton(player, 1);
		}

		return false;
	}

	function playerUpdate(player) {
		if(BotAI.isChargerWeaponLockout(player)) {
			BotAI.RemoveFlag(player, FL_FROZEN);
			BotAI.UnforceButton(player, 1);
			updating[player] <- false;
			return;
		}

		BotAI.AddFlag(player, FL_FROZEN );
		local duration = Convars.GetFloat("first_aid_kit_use_duration") + 1.0;
		local function RemoveFlag(ent_) {
			if(BotAI.IsEntityValid(ent_))
				BotAI.RemoveFlag(ent_, FL_FROZEN );
		}

		::BotAI.Timers.AddTimerByName("[BotAI]Heal" + player.GetEntityIndex(), duration, false, RemoveFlag, player);

		local weapon = player.GetActiveWeapon();
		if(weapon && weapon.GetClassname() == "weapon_first_aid_kit" && NetProps.GetPropFloat(weapon, "m_flNextPrimaryAttack") <= Time()) {
			BotAI.ForceButton(player, 1 , duration, true);
		} else {
			if(!BotAI.isChargerWeaponLockout(player)) {
				BotAI.ChangeItem(player, 3);
				BotAI.ForceButton(player, 1 , duration, true);
			} else if(BotAI.BotDebugMode) {
				printl("[BotAI][HEAL] blocked ChangeItem(3) for " + BotAI.getPlayerBaseName(player) + " (charger lockout)");
			}
		}

		updating[player] <- false;
	}

	function taskReset(player = null) {
		base.taskReset(player);
		if(BotAI.isManualKitHealing(player))
			return;

		if(BotAI.HasFlag(player, FL_FROZEN) && BotAI.IsBotHealingSelf(player)) {
			BotAI.RemoveFlag(player, FL_FROZEN );
			BotAI.UnforceButton(player, 1 );
			//BotAI.ChangeItem(player, 1);
			//BotAI.BotReset(player);
		}
	}
}
