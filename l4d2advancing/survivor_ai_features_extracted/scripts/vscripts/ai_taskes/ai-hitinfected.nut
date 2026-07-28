class ::AITaskHitInfected extends AITaskSingle {

	constructor(orderIn, tickIn, compatibleIn, forceIn) {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
		name = "hitinfected";
		single = true;
		updating = {};
		playerTick = {};
		infectedList = {}
		danger = {};
    }

	name = "hitinfected";
	single = true;
	updating = {};
	playerTick = {};
	infectedList = {}
	danger = {};

	function singleUpdateChecker(player) {
		this.tick = 8 - BotAI.BotCombatSkill * 3;
		if (this.tick < 2) {
			this.tick = 2;
		}

		danger[player] <- false;
		if(BotAI.isManualKitHealing(player) && !BotAI.HasTank) {
			if(BotAI.shouldPauseManualKit(player)) {
				BotAI.RemoveFlag(player, FL_FROZEN);
				BotAI.UnforceButton(player, 1);
			} else {
				BotAI.protectManualKitAction(player, 0.75);
			}
			BotAI.setBotShoveTarget(player, null);
			BotAI.setBotTarget(player, null);
			infectedList[player] <- null;
			BotAI.botAim[player] <- null;
			return false;
		}

		local dist = 800;

		local rock = null;
		local nearestRock = null;
		local RockDis = 800;

		foreach(idx, pro in BotAI.projectileList) {
			local rock = null;
			if(BotAI.IsEntityValid(pro) && pro.GetClassname() == "tank_rock")
				rock = pro;
			if (BotAI.IsEntityValid(rock) && BotAI.CanHitOtherEntity(rock, player, g_MapScript.TRACE_MASK_SHOT) && BotAI.distanceof(player.GetOrigin(), rock.GetOrigin()) < RockDis) {
				RockDis = BotAI.distanceof(player.GetOrigin(), rock.GetOrigin());
				nearestRock = rock;
			}
		}

		if(nearestRock != null) {
			infectedList[player] <- nearestRock;
			BotAI.setBotTarget(player, nearestRock);
			return true;
		}

		BotAI.EnsureTankPrimaryWeapon(player);

		local bossTarget = BotAI.FindPriorityBossTarget(player);
		if (bossTarget != null) {
			infectedList[player] <- bossTarget;
			BotAI.setBotTarget(player, bossTarget);
			return true;
		}

		local playerNeedSave = null;
		local playerNeedSaveDistance = 99999.0;
		local playerFallingDown = null;
		dist = 80;

		foreach(savePlayer in BotAI.SurvivorList) {
			if(BotAI.IsAlive(savePlayer) && savePlayer != player) {
				if (savePlayer.IsDominatedBySpecialInfected()) {
					local bad = savePlayer.GetSpecialInfectedDominatingMe();
					local rescueDist = dist;
					if (BotAI.IsEntitySI(bad)) {
						if (bad.GetZombieType() == 5)
							rescueDist = 900;
						else if (bad.GetZombieType() == 1 || bad.GetZombieType() == 3 || bad.GetZombieType() == 6)
							rescueDist = 700;
						else if (bad.GetZombieType() == 2)
							rescueDist = 420;
					}
					local saveDistance = BotAI.distanceof(player.GetOrigin(), savePlayer.GetCenter());
					if (BotAI.IsEntitySI(bad) && saveDistance < rescueDist && saveDistance < playerNeedSaveDistance
						&& (bad.GetZombieType() == 1 || bad.GetZombieType() == 2 || bad.GetZombieType() == 3 || bad.GetZombieType() == 5 || bad.GetZombieType() == 6)) {
						playerNeedSave = bad;
						playerNeedSaveDistance = saveDistance;
					}

				} else {
					local dis = BotAI.distanceof(player.GetOrigin(), savePlayer.GetCenter()) < dist;
					if (!BotAI.HasTank && (savePlayer.IsIncapacitated() || savePlayer.IsHangingFromLedge()) && !BotAI.isPlayerBeingRevived(savePlayer) && dis) {
					playerFallingDown = savePlayer;
					}
				}
			}
		}

		if (playerNeedSave != null) {
			local immediateThreat = BotAI.FindImmediateSelfThreat(player);
			if (immediateThreat != null) {
				infectedList[player] <- immediateThreat;
				if (BotAI.distanceof(player.GetOrigin(), immediateThreat.GetOrigin()) < 90)
					danger[player] = true;
			} else {
				infectedList[player] <- playerNeedSave;
			}
			return true;
		}

		local safeBoomer = BotAI.FindSafeBoomerTargetForBot(player);
		if (safeBoomer != null) {
			infectedList[player] <- safeBoomer;
			BotAI.setBotTarget(player, safeBoomer);
			return true;
		}

		if(player in BotAI.targetLocked && BotAI.IsAlive(BotAI.targetLocked[player])) {
			infectedList[player] <- BotAI.targetLocked[player];
			return true;
		}

		local selected = null;
		if(player in BotAI.dangerInfected) {// && playerFallingDown == null
			selected = BotAI.dangerInfected[player];
		}

		local dist = 180 + BotAI.BotCombatSkill * 120;
		local entS = null;
		local highestPriority = -1;
		local awareAngle = 0.9397;

		if (BotAI.BotCombatSkill == 1) {
			awareAngle = 0.707;
		} else if (BotAI.BotCombatSkill == 2) {
			awareAngle = 0.0;
		} else if (BotAI.BotCombatSkill >= 3) {
			awareAngle = -2.0;
		}

		local navigator = BotAI.getNavigator(player);
		if (navigator.moving()) {
			awareAngle = -1.0;
			dist -= 100;
		}

		if(BotAI.BotDebugMode) {
			DebugDrawCircle(player.GetCenter(), Vector(25, 25, 255), 0, dist, false, 0.2);
		}

		foreach(infected in BotAI.SpecialList) {
			if (!BotAI.IsAlive(infected) || infected.IsGhost())
				continue;

			local zombieType = infected.GetZombieType();
			local siVictim = BotAI.getSiVictim(infected);
			local infTarget = BotAI.GetTarget(infected);
			local canEngage = BotAI.CanShotOtherEntityInSight(player, infected, awareAngle) || BotAI.IsEntityValid(siVictim);

			if (!canEngage && zombieType == 5) {
				local jockeyThreatRange = 720 + BotAI.BotCombatSkill * 150;
				if (jockeyThreatRange > 1200)
					jockeyThreatRange = 1200;

				local jockeyDistance = BotAI.nextTickDistance(player, infected, 2.0);
				local targetIsSurvivor = BotAI.IsEntitySurvivor(infTarget);
				local jockeyAngle = 0.25;
				if (BotAI.BotCombatSkill == 1)
					jockeyAngle = 0.0;
				else if (BotAI.BotCombatSkill >= 2)
					jockeyAngle = -0.35;
				if (navigator.moving())
					jockeyAngle = -1.0;

				if ((jockeyDistance <= jockeyThreatRange || infTarget == player || (targetIsSurvivor && BotAI.distanceof(infTarget.GetOrigin(), infected.GetOrigin()) < 820))
					&& BotAI.CanShotOtherEntityInSight(player, infected, jockeyAngle)) {
					canEngage = true;
				}
			}

			if (!BotAI.IsEntitySI(infTarget) && (zombieType != 8 || entS == null) && canEngage) {
				if (zombieType == 1) {
					dist = BotAI.tongueRange*1.2;
				} else if (zombieType == 8) {
					BotAI.BotRetreatFrom(player, infected);
					dist = 800;
				} else if (zombieType == 5) {
					if (BotAI.IsEntityValid(siVictim)) {
						dist = 900;
					} else {
						dist = 650 + BotAI.BotCombatSkill * 140;
						if (dist > 1200)
							dist = 1200;
					}
				} else {
					dist = 180 + BotAI.BotCombatSkill * 120;
				}

				local currentPriority = 0;
				local target = infTarget;

				if (target == player) {
					currentPriority = 3;
				} else if (BotAI.IsEntityValid(siVictim)) {
					currentPriority = zombieType == 5 ? 3 : 2;
				} else {
					currentPriority = 1;
				}

				local infecDis = BotAI.nextTickDistance(player, infected, 5.0);
				local smoker = false;

				if (zombieType == 5 && currentPriority < 2 && (BotAI.IsEntitySurvivor(target) || infecDis < 760)) {
					currentPriority = 2;
				}

				if(zombieType == 1 && NetProps.GetPropFloat(NetProps.GetPropEntity(infected, "m_customAbility"), "m_nextActivationTimer.m_timestamp") <= Time()) {
					smoker = true;
				}

				if (currentPriority > highestPriority ||(currentPriority == highestPriority && (infecDis < dist || BotAI.IsSurvivorTrapped(target) || smoker))) {
					dist = infecDis;
					entS = infected;
					highestPriority = currentPriority;
				}
			}
		}

		dist = 700;
		local witch = null;
		foreach(infected in BotAI.WitchList) {
			if (BotAI.IsAlive(infected) && (BotAI.witchKilling(infected) || (BotAI.witchRunning(infected) && !BotAI.witchRetreat(infected))) && BotAI.CanShotOtherEntityInSight(player, infected)) {
				if (BotAI.distanceof(player.GetOrigin(), infected.GetOrigin()) < dist) {
					dist = BotAI.distanceof(player.GetOrigin(), infected.GetOrigin());
					witch = infected;
				}
			}
		}

		local dangerTarget = null;
		if (witch != null && BotAI.nextTickDistance(player, witch, 5.0) < 400) {
			dangerTarget = witch;
		} else if (entS != null && BotAI.nextTickDistance(player, entS, 5.0) < 400 && BotAI.GetTarget(entS) == player) {
			dangerTarget = entS;
		}

		BotAI.setBotCombatSpecial(player, dangerTarget);

		if(!BotAI.HasTank && entS == null && witch == null && playerFallingDown != null) {
			infectedList[player] <- playerFallingDown;
			return true;
		}

		if (entS != null && selected != null) {
			local finalEntity = null;
			local siDistance = BotAI.nextTickDistance(player, entS, 5.0);
			local coDistance = BotAI.nextTickDistance(player, selected, 5.0);

			if (entS.GetZombieType() == 8) {
				finalEntity = selected;
				if(coDistance < 90) {
					danger[player] = true;
				}
			} else {
				if(siDistance < 270) {
					if(siDistance < 90) {
						danger[player] = true;
					}
					finalEntity = entS;
				} else {
					finalEntity = selected;
					if(coDistance < 90) {
						danger[player] = true;
					}
				}
			}

			infectedList[player] <- finalEntity;
			return true;
		}

		if (entS != null && entS.GetZombieType() != 8) {
			infectedList[player] <- entS;
			local siDistance = BotAI.nextTickDistance(player, entS, 5.0);
			if(siDistance < 90) {
				danger[player] = true;
			}

			return true;
		}

		if (selected != null) {
			infectedList[player] <- selected;
			local coDistance = BotAI.nextTickDistance(player, selected, 5.0);
			if(coDistance < 90) {
				danger[player] = true;
			}

			return true;
		}

		if (witch != null) {
			infectedList[player] <- witch;
			return true;
		}

		BotAI.setBotShoveTarget(player, null);
		infectedList[player] <- null;
		BotAI.botAim[player] <- null;

		return false;
	}

	function playerUpdate(player) {
		if(player in infectedList && infectedList[player] != null) {
			local val = infectedList[player];
			if(BotAI.IsAlive(val)) {// && BotAI.CanShotOtherEntityInSight(player, val)
				if(danger[player]) {
					BotAI.setBotShoveTarget(player, val);
				}

				BotAI.BotAttack(player, val);

				if(BotAI.IsEntityValid(val) && !IsPlayerABot(player)) {
					BotAI.lookAtEntity(player, val);
				}
			} else {
				infectedList[player] <- null;
				BotAI.botAim[player] <- null;
			}
		}

		updating[player] <- false;
	}

	function taskReset(player = null) {
		base.taskReset(player);

		if(player != null)
			infectedList[player] <- null;
		danger = false;
	}
}
