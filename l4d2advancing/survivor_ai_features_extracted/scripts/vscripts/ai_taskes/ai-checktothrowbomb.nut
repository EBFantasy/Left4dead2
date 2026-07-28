class ::AITaskCheckToThrowBomb extends AITaskGroup {

	constructor(orderIn, tickIn, compatibleIn, forceIn) {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }

	updating = false;
	zombieCleaner = null;
	nextThrowTime = 0.0;

	function preCheck() {
		if(!BotAI.NeedThrowPipeBomb) {
			return false;
		}

		if(BotAI.playerFallDown <= 0) {
			return false;
		}

		if(Time() < nextThrowTime || !BotAI.HasIncapacitatedHordePressure()) {
			return false;
		}

		local hasActivePipeBomb = false;
		local pipeBomb = null;
		while(pipeBomb = Entities.FindByClassname(pipeBomb, "pipe_bomb_projectile")) {
			if(BotAI.IsEntityValid(pipeBomb) && BotAI.IsEntityValid(NetProps.GetPropEntity(pipeBomb, "m_hThrower"))) {
				hasActivePipeBomb = true;
				break;
			}
		}

		if(hasActivePipeBomb) {
			if (BotAI.BotDebugMode) {
				printl("contain active pipe")
			}
			return false;
		}

		zombieCleaner = null;
		local bestDistance = 99999.0;

		foreach(player in BotAI.SurvivorBotList) {
			if(!BotAI.IsAlive(player) || player.IsIncapacitated() || player.IsHangingFromLedge() || player.IsDominatedBySpecialInfected() || BotAI.IsPlayerReviving(player)) {
				continue;
			}

			if(!BotAI.HasItem(player, "weapon_pipe_bomb"))
				continue;

			local nearestDown = 99999.0;
			foreach(downed in BotAI.SurvivorList) {
				if(BotAI.IsEntitySurvivor(downed) && (downed.IsIncapacitated() || downed.IsHangingFromLedge())) {
					local distance = BotAI.distanceof(player.GetOrigin(), downed.GetOrigin());
					if(distance < nearestDown)
						nearestDown = distance;
				}
			}
			if(nearestDown < bestDistance) {
				bestDistance = nearestDown;
				zombieCleaner = player;
			}
		}

		return (zombieCleaner != null);
	}

	function GroupUpdateChecker(player) {
		if(BotAI.isChargerWeaponLockout(player))
			return false;

		if(player == zombieCleaner) {
			return true;
		}

		return false;
	}

	function playerUpdate(player) {
		if(BotAI.isChargerWeaponLockout(player)) {
			BotAI.RemoveFlag(player, FL_FROZEN);
			BotAI.UnforceButton(player, 1);
			BotAI.setBotLockTheard(player, -1);
			updating = false;
			return;
		}

		if(player == zombieCleaner && BotAI.HasItem(player, "weapon_pipe_bomb")) {
			local angle = player.EyeAngles();
			angle = QAngle(-30, angle.Yaw(), angle.Roll());
			player.SnapEyeAngles(angle);
			BotAI.AddFlag(player, FL_FROZEN );

			local function RemoveFlag(ent_) {
				if(BotAI.IsEntityValid(ent_))
					BotAI.RemoveFlag(ent_, FL_FROZEN );
			}

			::BotAI.Timers.AddTimerByName("CheckToThrowGen" + player.GetEntityIndex(), 1.0, false, RemoveFlag, player);

			local weapon = player.GetActiveWeapon();
			if(weapon && weapon.GetClassname() == "weapon_pipe_bomb" && NetProps.GetPropFloat(weapon, "m_flNextPrimaryAttack") <= Time()) {
				BotAI.ForceButton(player, 1 , 0.5, true);
				BotAI.setBotLockTheard(player, -1);
				nextThrowTime = Time() + 40.0;
			} else {
				BotAI.ChangeItem(player, 2);
			}
		} else {
			BotAI.setBotLockTheard(player, -1);
		}

		updating = false;
	}

	function taskReset(player = null) {
		base.taskReset(player);
	}
}
