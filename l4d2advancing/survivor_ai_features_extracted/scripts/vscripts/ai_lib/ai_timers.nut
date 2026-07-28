function BotAI::bestAim() {
	foreach(player in BotAI.SurvivorBotList) {
		local aimTarget = null;
		if(player in BotAI.botAim) {
			aimTarget = BotAI.botAim[player];
		}

		if(BotAI.IsAlive(aimTarget)) {
			CommandABot( { cmd = 0, target = aimTarget, bot = player } );
			BotAI.lookAtEntity(player, aimTarget);
		}
	}

	return 0.01;
}

function BotAI::hasSyncAttackFirearm(player) {
	local weapon = player.GetActiveWeapon();
	if(!BotAI.IsEntityValid(weapon))
		return false;

	local name = weapon.GetClassname();
	return name != "weapon_melee" && name != "weapon_chainsaw" &&
		name != "weapon_first_aid_kit" && name != "weapon_defibrillator" &&
		name != "weapon_pain_pills" && name != "weapon_adrenaline" &&
		name != "weapon_molotov" && name != "weapon_pipe_bomb" &&
		name != "weapon_vomitjar" && name != "weapon_gascan" &&
		name != "weapon_propanetank" && name != "weapon_oxygentank" &&
		name != "weapon_fireworkcrate" && name != "weapon_gnome" &&
		name != "weapon_cola_bottles" && name != "weapon_upgradepack_incendiary" &&
		name != "weapon_upgradepack_explosive" && name != "weapon_ammo_pack";
}

function BotAI::syncAttackThink() {
	foreach(bot, owner in BotAI.syncAttack) {
		if(!BotAI.IsEntitySurvivorBot(bot) || !BotAI.IsAlive(bot) || !BotAI.IsPlayerEntityValid(owner) || !BotAI.IsAlive(owner)) {
			delete BotAI.syncAttack[bot];
			continue;
		}

		local buttons = NetProps.GetPropInt(owner, "m_nButtons");
		if(!(buttons & BUTTON_ATTACK) || !BotAI.hasSyncAttackFirearm(owner) || !BotAI.hasSyncAttackFirearm(bot))
			continue;

		local traceTable = {
			start = owner.EyePosition()
			end = owner.EyePosition() + owner.EyeAngles().Forward().Scale(9999)
			ignore = owner
			mask = g_MapScript.TRACE_MASK_ALL
		}
		TraceLine(traceTable);

		local target = traceTable.hit ? traceTable.pos : traceTable.end;
		BotAI.lookAtPosition(bot, target);
		BotAI.RefreshForceButton(bot, BUTTON_ATTACK, 0.08);
	}

	return 0.05;
}

local syncAttackThinker = SpawnEntityFromTable("info_target", { targetname = "botai_sync_attack" });
if(syncAttackThinker != null) {
	syncAttackThinker.ValidateScriptScope();
	local syncAttackScope = syncAttackThinker.GetScriptScope();
	syncAttackScope["botai_sync_attack_think"] <- function() {
		try {
			return BotAI.syncAttackThink();
		} catch(error) {
			printl("[Bot AI] SyncAttackThink error: " + error);
			return 0.05;
		}
	};
	AddThinkToEnt(syncAttackThinker, "botai_sync_attack_think");
}

function BotAI::moveFunc() {
	foreach(player in BotAI.SurvivorBotList) {
		if(player in BotAI.botMoveMap) {

			if(BotAI.hasContext(player, "BOTAI_KNOCK") || player.IsIncapacitated() || player.IsDominatedBySpecialInfected() || BotAI.isPlayerBeingRevived(player) || BotAI.IsPlayerReviving(player)) {
				NetProps.SetPropVector(player, "m_vecBaseVelocity", Vector(0, 0, 0));
				BotAI.botMoveMap[player] = Vector(0, 0, 0);
				BotAI.getNavigator(player).clearPath("botMove{+");
				continue;
			}

			BotAI.DisableButton(player, BUTTON_WALK, 1.0);

			local vec = BotAI.botMoveMap[player];
			if(BotAI.validVector(vec) && vec.Length() >= 5) {
				if(vec.Length() > 300) {
					vec = BotAI.normalize(vec).Scale(300);
				}

				local appliedVec = vec;

				if (!BotAI.IsOnGround(player)) {
					appliedVec = appliedVec.Scale(0.05);
				}

				if(!BotAI.isEdge(player, appliedVec)) {
					NetProps.SetPropVector(player, "m_vecBaseVelocity", appliedVec);
				}

				local function feelingSafe() {
					local dangerous = BotAI.getBotAvoid(player);

					if(dangerous.len() > 0) {
						return false;
					} else {
						return true;
					}
				}

				BotAI.botRunPos(player, player.GetOrigin() + appliedVec, "botMove{+", 7, feelingSafe);
				BotAI.botMoveMap[player] = vec * 0.8;
			} else if (BotAI.getNavigator(player).hasPath("botMove{+")) {
				NetProps.SetPropVector(player, "m_vecBaseVelocity", Vector(0, 0, 0));
				BotAI.botMoveMap[player] = Vector(0, 0, 0);
				BotAI.getNavigator(player).clearPath("botMove{+");
			}
		}
	}

	return 0.1;
}

	function BotAI::manualLeadThink() {
		foreach(bot, data in BotAI.ManualLead) {
			if(!BotAI.IsEntitySurvivorBot(bot) || !BotAI.IsAlive(bot)) {
				delete BotAI.ManualLead[bot];
			continue;
		}

		local now = Time();
		if("until" in data && data.until > 0 && now >= data.until) {
			BotAI.stopManualLead(bot);
			continue;
		}

		local id = "manualLead$";
		if("mode" in data && data.mode == "scout")
			id = "manualScout$";
		else if(("autonomousLead" in data) && data.autonomousLead)
			id = "manualLeadAuto$";
		local scoutMode = ("mode" in data && data.mode == "scout");
		if(scoutMode) {
			if(!("scoutStartTime" in data))
				data.scoutStartTime <- now;
			if(!("scoutStartPos" in data))
				data.scoutStartPos <- bot.GetOrigin();
			if(!("scoutFallbackCount" in data))
				data.scoutFallbackCount <- 0;
		}

		local navigator = BotAI.getNavigator(bot);
		local manualMoving = navigator.isMoving(id);
		local locked = ("lockUntil" in data && now < data.lockUntil);

		if(("ABA_Spitter_IsManualLeadPaused" in getroottable()) && ::ABA_Spitter_IsManualLeadPaused(bot)) {
			navigator.clearPath(id);
			data.nextPath = now + 0.5;
			BotAI.ManualLead[bot] <- data;
			continue;
		}

		if(bot.IsDominatedBySpecialInfected() || bot.IsIncapacitated() || bot.IsHangingFromLedge() || BotAI.isChargerWeaponLockout(bot) || BotAI.IsInCombat(bot)) {
			navigator.clearPath(id);
			continue;
		}

		local ownerForLead = BotAI.getManualLeadOwner(data);
		// Distance leash. Scout is a short errand and should abort when it gets
		// too far from its owner, but "pathfind" is meant to press on ahead, so
		// leashing it to the player is precisely what made it give up and
		// shuffle on the spot. Give lead a much longer rope.
		local leashRange = (("mode" in data) && data.mode == "scout") ? 1700 : 4200;
		if(BotAI.IsPlayerEntityValid(ownerForLead) && BotAI.distanceof(bot.GetOrigin(), ownerForLead.GetOrigin()) > leashRange) {
			navigator.clearPath(id);
			data.nextPath = now + 1.2;
			BotAI.ManualLead[bot] <- data;
			continue;
		}

		local function applyScoutFallback(reason, runningTarget = null) {
			if(!scoutMode)
				return false;

			local fallbackTarget = null;
			if(BotAI.validVector(runningTarget))
				fallbackTarget = runningTarget;
			else if("currentTarget" in data && BotAI.validVector(data.currentTarget))
				fallbackTarget = data.currentTarget;
			if(BotAI.validVector(fallbackTarget))
				BotAI.rememberManualLeadBadTarget(data, fallbackTarget);

			if("scoutFallbackCount" in data)
				data.scoutFallbackCount = data.scoutFallbackCount + 1;
			else
				data.scoutFallbackCount <- 1;

			if("hint" in data && BotAI.validVector(data.hint))
				data.usedHint = false;

			navigator.clearPath(id);
			BotAI.clearManualLeadCommandSet(bot, 1.0);

			local didTeleport = false;
			if(data.scoutFallbackCount >= 2 && BotAI.IsPlayerEntityValid(ownerForLead) && BotAI.IsAlive(ownerForLead)) {
				local ownerResetPos = ownerForLead.GetOrigin();
				if(("IdleTeleportBot" in getroottable()) && ::IdleTeleportBot != null) {
					::IdleTeleportBot(bot, ownerResetPos);
					didTeleport = true;
				} else {
					try {
						bot.SetOrigin(ownerResetPos + Vector(0, 0, 5));
						didTeleport = true;
					} catch(e) {}
				}
			}

			local resetPos = bot.GetOrigin();
			data.nextPath = now + (didTeleport ? 0.4 : 0.2);
			data.lockUntil = now + 1.0;
			data.scoutStartTime = now;
			data.scoutStartPos = resetPos;
			if("pathStartTime" in data) data.pathStartTime = now; else data.pathStartTime <- now;
			if("pathStartPos" in data) data.pathStartPos = resetPos; else data.pathStartPos <- resetPos;
			if("stuckSince" in data) data.stuckSince = now; else data.stuckSince <- now;
			if("lastMovePos" in data) data.lastMovePos = resetPos; else data.lastMovePos <- resetPos;
			if("lastTargetDist" in data) delete data.lastTargetDist;
			if("currentTarget" in data) delete data.currentTarget;

			if(BotAI.BotDebugMode)
				printl("[BotAI][ManualLead][ScoutFallback] " + BotAI.getPlayerBaseName(bot)
					+ " reason=" + reason
					+ " retry=" + data.scoutFallbackCount
					+ (didTeleport ? " [teleport-reset]" : " [path-refresh]"));

			BotAI.ManualLead[bot] <- data;
			return true;
		}

		if(scoutMode && ("scoutStartTime" in data) && ("scoutStartPos" in data)) {
			local movedFromStart = BotAI.distanceof(bot.GetOrigin(), data.scoutStartPos);
			if(now - data.scoutStartTime >= 3.0 && movedFromStart < 70) {
				if(applyScoutFallback("low-movement-3s"))
					continue;
			}
		}

		// Lead had no low-movement recovery at all: only scout got one, which
		// is why scout recovers from a dead end and pathfind just loiters.
		// Give lead an equivalent, but WITHOUT scout's teleport-to-owner reset -
		// that would defeat the point of sending the bot ahead. Blacklist the
		// target it failed to reach and pick a new one.
		if(!scoutMode) {
			if(!("leadStartTime" in data)) data.leadStartTime <- now;
			if(!("leadStartPos" in data)) data.leadStartPos <- bot.GetOrigin();

			local leadMoved = BotAI.distanceof(bot.GetOrigin(), data.leadStartPos);
			if(now - data.leadStartTime >= 3.5 && leadMoved < 70) {
				if(("currentTarget" in data) && BotAI.validVector(data.currentTarget))
					BotAI.rememberManualLeadBadTarget(data, data.currentTarget);

				navigator.clearPath(id);
				BotAI.clearManualLeadCommandSet(bot, 0.8);

				local leadResetPos = bot.GetOrigin();
				data.nextPath = now + 0.2;
				data.leadStartTime = now;
				data.leadStartPos = leadResetPos;
				if("stuckSince" in data) data.stuckSince = now; else data.stuckSince <- now;
				if("lastMovePos" in data) data.lastMovePos = leadResetPos; else data.lastMovePos <- leadResetPos;
				if("lastTargetDist" in data) delete data.lastTargetDist;
				if("currentTarget" in data) delete data.currentTarget;

				if(BotAI.BotDebugMode)
					printl("[BotAI][ManualLead][LeadRetarget] " + BotAI.getPlayerBaseName(bot)
						+ " stalled 3.5s, blacklisting target and re-picking");

				BotAI.ManualLead[bot] <- data;
				continue;
			}

			// Reset the stall window whenever real progress is made.
			if(leadMoved >= 70) {
				data.leadStartTime = now;
				data.leadStartPos = bot.GetOrigin();
			}
		}

		if(navigator.moving() && !manualMoving) {
			if(locked)
				navigator.stop(false);
			else
				continue;
		}

		if(manualMoving) {
			local runningPath = navigator.getRunningPathData();
			local runningTarget = null;
			if(runningPath != null)
				runningTarget = runningPath.getPos(null);

			if(BotAI.validVector(runningTarget)) {
				local distNow = BotAI.distanceof(bot.GetOrigin(), runningTarget);
				local resetProgress = false;
				if(!("lastTargetDist" in data) || distNow < data.lastTargetDist - 35)
					resetProgress = true;
				else if("lastMovePos" in data && BotAI.distanceof(bot.GetOrigin(), data.lastMovePos) > 90)
					resetProgress = true;

				if(resetProgress) {
					if("lastTargetDist" in data) data.lastTargetDist = distNow; else data.lastTargetDist <- distNow;
					if("lastMovePos" in data) data.lastMovePos = bot.GetOrigin(); else data.lastMovePos <- bot.GetOrigin();
					if("stuckSince" in data) data.stuckSince = now; else data.stuckSince <- now;
				} else if(("stuckSince" in data) && now - data.stuckSince > 4.5) {
					BotAI.rememberManualLeadBadTarget(data, runningTarget);
					navigator.clearPath(id);
					data.nextPath = now + 1.8;
					if(BotAI.BotDebugMode)
						printl("[BotAI][ManualLead] blacklist stuck target " + runningTarget);
					BotAI.ManualLead[bot] <- data;
					continue;
				}
			}
		}

		if(manualMoving) {
			BotAI.ManualLead[bot] <- data;
			continue;
		}

		local target = null;
		local targetFromHint = false;
		local targetFromDirHint = false;
		local autonomousLead = (("autonomousLead" in data) && data.autonomousLead);
		local allowLeadHint = scoutMode && !autonomousLead;

		// "Pathfind" (lead) should navigate the way ABA does when no human is
		// alive: anchored on the bot itself, not tethered to the player.
		// Scout keeps the player-anchored behaviour, which suits it.
		local leadSelfAnchored = !scoutMode;

		local baseFlow = GetFlowDistanceForPosition(bot.GetOrigin());
		local ownerForFlow = ownerForLead;
		// Only fold the player's flow in for scout. For lead this used to raise
		// baseFlow to the player's position, so when the player stood ahead of
		// the bot every area near the bot failed the "flowDelta >= 70" test and
		// the only survivors were areas the bot could not reach cleanly.
		if(!leadSelfAnchored && BotAI.IsPlayerEntityValid(ownerForFlow)) {
			local ownerFlow = GetFlowDistanceForPosition(ownerForFlow.GetOrigin());
			if(ownerFlow > baseFlow)
				baseFlow = ownerFlow;
		}

		if(allowLeadHint && !data.usedHint && "hint" in data && BotAI.isGoodManualLeadHint(bot, data.hint, baseFlow, ownerForLead, ("badTargets" in data) ? data.badTargets : null)) {
			target = data.hint;
			targetFromHint = true;
		}

		if(allowLeadHint && target == null && "hintMeta" in data)
		{
			target = BotAI.findManualLeadDirectionalTarget(bot, ownerForLead,
				("hint" in data) ? data.hint : null,
				data.hintMeta,
				("badTargets" in data) ? data.badTargets : null);
			targetFromDirHint = (target != null);
		}

		if(target == null)
			target = BotAI.findManualLeadTarget(bot, ownerForLead, ("badTargets" in data) ? data.badTargets : null, leadSelfAnchored);

		if(target == null) {
			data.nextPath = now + 1.5;
			BotAI.ManualLead[bot] <- data;
			continue;
		}

		local leadBot = bot;
		local function stopLeadPath() {
			if(!BotAI.isManualLeadRunning(leadBot))
				return true;
			if(leadBot.IsDominatedBySpecialInfected() || leadBot.IsIncapacitated() || leadBot.IsHangingFromLedge())
				return true;
			if(BotAI.isChargerWeaponLockout(leadBot) || BotAI.IsInCombat(leadBot))
				return true;
			return false;
		}

		local priority = (targetFromHint || targetFromDirHint) ? 4 : 1;
		if(locked && priority < 3)
			priority = 3;

		local pathStarted = false;
		if(targetFromHint) {
			pathStarted = BotAI.botStayPos(bot, target, id, priority, 1.0, 90);
			data.usedHint = true;
			if(!pathStarted) {
				BotAI.rememberManualLeadBadTarget(data, target);
				target = BotAI.findManualLeadDirectionalTarget(bot, ownerForLead,
					("hint" in data) ? data.hint : null,
					("hintMeta" in data) ? data.hintMeta : null,
					("badTargets" in data) ? data.badTargets : null);
				targetFromHint = false;
				targetFromDirHint = (target != null);
				if(target == null)
					target = BotAI.findManualLeadTarget(bot, ownerForLead, ("badTargets" in data) ? data.badTargets : null, leadSelfAnchored);
				priority = targetFromDirHint ? 4 : (locked ? 3 : 1);
				if(target != null)
					pathStarted = BotAI.botRunPos(bot, target, id, priority, stopLeadPath, 1700);
			}
		} else {
			pathStarted = BotAI.botRunPos(bot, target, id, priority, stopLeadPath, 1700);
		}

		if(pathStarted) {
			data.nextPath = now + 2.0;
			if("currentTarget" in data) data.currentTarget = target; else data.currentTarget <- target;
			if("lastTargetDist" in data) data.lastTargetDist = BotAI.distanceof(bot.GetOrigin(), target); else data.lastTargetDist <- BotAI.distanceof(bot.GetOrigin(), target);
			if("lastMovePos" in data) data.lastMovePos = bot.GetOrigin(); else data.lastMovePos <- bot.GetOrigin();
			if("stuckSince" in data) data.stuckSince = now; else data.stuckSince <- now;
			if(scoutMode) {
				if("pathStartTime" in data) data.pathStartTime = now; else data.pathStartTime <- now;
				if("pathStartPos" in data) data.pathStartPos = bot.GetOrigin(); else data.pathStartPos <- bot.GetOrigin();
			}
			if(BotAI.BotDebugMode)
				printl("[BotAI][ManualLead] " + BotAI.getPlayerBaseName(bot) + " -> " + target
					+ (targetFromHint ? " [hint]" : (targetFromDirHint ? " [dir-hint]" : "")));
		} else {
			data.nextPath = now + 1.0;
		}

		BotAI.ManualLead[bot] <- data;
	}

	return 0.5;
}

function BotAI::taskTimer::hitinfected() {
	local name = "hitinfected";
	local task = BotAI.timerTask.hitinfected;

	foreach(player in BotAI.SurvivorBotList) {
		if(!BotAI.IsPlayerEntityValid(player)) continue;

		local shouldTick = task.shouldTick(player) && !(name in BotAI.disabledTask);

		if(shouldTick) {
			task.setLastTickTime(player, BotAI.tickExisted + task.tick);
			local shouldUpdate = false;
			shouldUpdate = task.shouldUpdate(player);

			if(shouldUpdate) {
				task.taskUpdate(player);
			}
		}
	}

	return 0.01;
}

function BotAI::taskTimer::updateFireState() {
	local name = "updateFireState";
	local task = BotAI.timerTask.updateFireState;
	foreach(player in BotAI.SurvivorBotList) {
		if(!BotAI.IsPlayerEntityValid(player)) continue;

		local shouldTick = task.shouldTick(player) && !(name in BotAI.disabledTask);

		if(shouldTick) {
			task.setLastTickTime(player, BotAI.tickExisted + task.tick);
			local shouldUpdate = false;
			shouldUpdate = task.shouldUpdate(player);

			if(shouldUpdate) {
				task.taskUpdate(player);
			}
		}
	}

	return 0.01;
}

function BotAI::taskTimer::shoveInfected() {
	local name = "shoveInfected";
	local task = BotAI.timerTask.shoveInfected;
	foreach(player in BotAI.SurvivorBotList) {
		if(!BotAI.IsPlayerEntityValid(player)) continue;

		local shouldTick = task.shouldTick(player) && !(name in BotAI.disabledTask);

		if(shouldTick) {
			task.setLastTickTime(player, BotAI.tickExisted + task.tick);
			local shouldUpdate = false;
			shouldUpdate = task.shouldUpdate(player);

			if(shouldUpdate) {
				task.taskUpdate(player);
			}
		}
	}

	return 0.01;
}

function BotAI::taskTimer::avoidDanger() {
	local name = "avoidDanger";
	local task = BotAI.timerTask.avoidDanger;

	foreach(player in BotAI.SurvivorBotList) {
		if(!BotAI.IsPlayerEntityValid(player)) continue;

		local shouldTick = task.shouldTick(player) && !(name in BotAI.disabledTask);

		if(shouldTick) {
			task.setLastTickTime(player, BotAI.tickExisted + task.tick);
			local shouldUpdate = false;
			shouldUpdate = task.shouldUpdate(player);

			if(shouldUpdate) {
				task.taskUpdate(player);
			}
		}

	}

	return 0.01;
}

function BotAI::resetTaskTimers() {
	BotAI.timerTask <- {};

	BotAI.timerTask.hitinfected <- AITaskHitInfected(0, 2, true, true);
	BotAI.timerTask.updateFireState <- AITaskUpdateBotFireState(0, 1, true, true);
	BotAI.timerTask.shoveInfected <- AITaskShoveInfected(0, 1, true, true);
	BotAI.timerTask.avoidDanger <- AITaskAvoidDanger(0, 2, true, true);

	local _hitinfectedTaskTimer = SpawnEntityFromTable("info_target", { targetname = "botai_task_timer_hitinfected"});

	if (_hitinfectedTaskTimer != null) {
		_hitinfectedTaskTimer.ValidateScriptScope();
		local scrScope = _hitinfectedTaskTimer.GetScriptScope();
		scrScope["botai_think"] <- BotAI.taskTimer.hitinfected;
		AddThinkToEnt(_hitinfectedTaskTimer, "botai_think");
	}

	local _updateFireStateTaskTimer = SpawnEntityFromTable("info_target", { targetname = "botai_task_timer_updateFireState"});

	if (_updateFireStateTaskTimer != null) {
		_updateFireStateTaskTimer.ValidateScriptScope();
		local scrScope = _updateFireStateTaskTimer.GetScriptScope();
		scrScope["botai_think"] <- BotAI.taskTimer.updateFireState;
		AddThinkToEnt(_updateFireStateTaskTimer, "botai_think");
	}

	local _shoveInfectedTaskTimer = SpawnEntityFromTable("info_target", { targetname = "botai_task_timer_shoveInfected"});

	if (_shoveInfectedTaskTimer != null) {
		_shoveInfectedTaskTimer.ValidateScriptScope();
		local scrScope = _shoveInfectedTaskTimer.GetScriptScope();
		scrScope["botai_think"] <- BotAI.taskTimer.shoveInfected;
		AddThinkToEnt(_shoveInfectedTaskTimer, "botai_think");
	}

	local _avoidDangerTaskTimer = SpawnEntityFromTable("info_target", { targetname = "botai_task_timer_avoidDanger"});

	if (_avoidDangerTaskTimer != null) {
		_avoidDangerTaskTimer.ValidateScriptScope();
		local scrScope = _avoidDangerTaskTimer.GetScriptScope();
		scrScope["botai_think"] <- BotAI.taskTimer.avoidDanger;
		AddThinkToEnt(_avoidDangerTaskTimer, "botai_think");
	}
}

function BotAI::createGroundTargetTimer(ground) {
    local _targetTimer = SpawnEntityFromTable("info_target", { targetname = "botai_projectile_timer_" + ground});
    local function findGoundTarget() {
        local danger = null;
	    while(danger = Entities.FindByClassname(danger, ground)) {
		    BotAI.groundList[danger.GetEntityIndex()] <- danger;
	    }
		return 1.0;
    }
    if (_targetTimer != null) {
		_targetTimer.ValidateScriptScope();
		local scrScope = _targetTimer.GetScriptScope();
		scrScope["botai_think"] <- findGoundTarget;
		AddThinkToEnt(_targetTimer, "botai_think");
	}
}

function BotAI::createRockTargetTimer() {
    local _targetTimer = SpawnEntityFromTable("info_target", { targetname = "botai_rock_timer_" + UniqueString()});
    local function findRockTarget() {
        local rock = null;
		local isDanger = false;
	    while(rock = Entities.FindByClassname(rock, "tank_rock")) {
			BotAI.projectileList[rock.GetEntityIndex()] <- rock;
			isDanger = true;
			local function avoidProjectile(rock) {
				foreach(bot in BotAI.SurvivorBotList) {
					if(BotAI.IsPlayerClimb(bot) || bot.IsIncapacitated() || bot.IsDominatedBySpecialInfected() || BotAI.isPlayerBeingRevived(bot))
						continue;

					if(BotAI.xyDotProduct(BotAI.normalize(rock.GetVelocity()), BotAI.normalize(bot.GetOrigin() - rock.GetOrigin())) > 0.5) {
						local vec = BotAI.getDodgeVec(bot, rock, 300, 50, 300, 5000);

						if(BotAI.validVector(vec) && !BotAI.isPlayerNearLadder(bot)) {
							BotAI.botMove(bot, vec);
							bot.OverrideFriction(0.5, 0.2);
							bot.UseAdrenaline(1.0);
							if(BotAI.CanHitOtherEntity(rock, bot, g_MapScript.TRACE_MASK_SHOT)) {
								BotAI.BotAttack(bot, rock);
							}
						}
					}
				}
			}

		    avoidProjectile(rock);
	    }

		if(!isDanger) {
			self.Kill();
		}

		return 0.1;
    }

    local function addTimer() {
		if (_targetTimer != null) {
			_targetTimer.ValidateScriptScope();
			local scrScope = _targetTimer.GetScriptScope();
			scrScope["botai_think"] <- findRockTarget;
			AddThinkToEnt(_targetTimer, "botai_think");
		}
	}

	BotAI.delayTimer(addTimer, 1.5);
}

function BotAI::createProjectileTargetTimer(projectile) {
    local _targetTimer = SpawnEntityFromTable("info_target", { targetname = "botai_projectile_timer_" + projectile});
    local function findProjectileTarget() {
        local danger = null;
		local isDanger = false;
	    while(danger = Entities.FindByClassname(danger, projectile)) {
			if(projectile == "prop_physics") {
				local needContinue;
				foreach(thing in BotAI.takeElse) {
					if(danger.GetModelName().find(thing) != null) {
						needContinue = true;
					}
				}

				if(!(danger.GetEntityIndex() in BotAI.ListAvoidCar)) {
					needContinue = true;
				}

				if(needContinue)
					continue;
			}

			local function avoidProjectile(danger) {
				foreach(bot in BotAI.SurvivorBotList) {
					if(BotAI.IsPlayerClimb(bot) || bot.IsIncapacitated() || bot.IsDominatedBySpecialInfected() || BotAI.isPlayerBeingRevived(bot) || BotAI.distanceof(bot.GetOrigin(), danger.GetOrigin()) > 400)
						continue;

					if(projectile == "spitter_projectile" && ("ABA_Spitter_ShouldOwnAcid" in getroottable()) && ::ABA_Spitter_ShouldOwnAcid(bot))
						continue;

					if(BotAI.xyDotProduct(BotAI.normalize(danger.GetVelocity()), BotAI.normalize(bot.GetOrigin() - danger.GetOrigin())) > 0.5) {
						isDanger = true;
						local vec = BotAI.getDodgeVec(bot, danger, 100, 50, 100, 5000);

						if(danger.GetClassname() == "spitter_projectile") {
							vec = vec.Scale(0.3);
						}

						if(BotAI.validVector(vec) && !BotAI.isPlayerNearLadder(bot)) {
							BotAI.botMove(bot, vec);
						}
					}
				}
			}

		    if(BotAI.GetEntitySpeedVector(danger) > 10 || BotAI.GetEntitySpeedLocalVector(danger) > 10) {
				avoidProjectile(danger);
			} else if(danger.GetEntityIndex() in BotAI.ListAvoidCar) {
			    local time = BotAI.ListAvoidCar[danger.GetEntityIndex()].GetTime();
			    if(time > 0) {
				    if(BotAI.IsOnGround(danger) || BotAI.GetDistanceToGround(danger) < 50)
				    	BotAI.ListAvoidCar[danger.GetEntityIndex()].SetTime(time - 1);

					avoidProjectile(danger);
			    }
		    }
	    }

		if(isDanger) {
			return 0.1;
		} else {
			return 0.5;
		}
    }

    if (_targetTimer != null) {
		_targetTimer.ValidateScriptScope();
		local scrScope = _targetTimer.GetScriptScope();
		scrScope["botai_think"] <- findProjectileTarget;
		AddThinkToEnt(_targetTimer, "botai_think");
	}
}

function BotAI::createPlayerTargetTimer(player) {
    local index = player.GetEntityIndex();
    local _targetTimer = SpawnEntityFromTable("info_target", { targetname = "botai_target_timer_" + index});
    local function findTarget() {
        if(!BotAI.IsAlive(player)) {
            local infoTarget = null;
            while(infoTarget = Entities.FindByName(infoTarget, "botai_target_timer_" + index))
                infoTarget.Kill();
        }

		local selected = null;
		local closestCom = null;
		local selectedDis = 50 + BotAI.BotCombatSkill * 20;
		local closestDis = 120 + BotAI.BotCombatSkill * 25;

		local awareAngle = 0.996;
		local dangerAwareAngle = 0.94;

		if (BotAI.BotCombatSkill == 1) {
			awareAngle = 0.9397;
			dangerAwareAngle = 0.707;
		} else if (BotAI.BotCombatSkill == 2) {
			awareAngle = 0.707;
			dangerAwareAngle = -0.26;
		} else if (BotAI.BotCombatSkill >= 3) {
			awareAngle = -2.0;
			dangerAwareAngle = -2.0;
		}

		local navigator = BotAI.getNavigator(player);
		local moving = navigator.moving();
		local healingAnyOne = BotAI.IsBotHealing(player);
		local takingAidKit = BotAI.isTakingItem(player, "first_aid_kit");
		if (moving || healingAnyOne || takingAidKit) {
			awareAngle -= 2.0;
			selectedDis -= BotAI.BotCombatSkill * 10;
			closestDis -= 75;
		}

		local isShove = BotAI.IsPressingShove(player);
		local isHealing = BotAI.IsBotHealingOthers(player);
		local com = null;

		if (isShove && isHealing) {
			isShove = false;
		}

		if(BotAI.BotDebugMode) {
			DebugDrawCircle(player.GetCenter(), Vector(255, 25, 25), 0, selectedDis, false, 0.2);
			DebugDrawCircle(player.GetCenter(), Vector(25, 255, 25), 0, closestDis, false, 0.2);
		}

		BotAI.setBotCombatCommon(player, null);

		while(com = Entities.FindByClassnameWithin(com, "infected", player.GetCenter(), closestDis)) {
			if(!BotAI.IsAlive(com) || BotAI.IsEntitySI(BotAI.GetTarget(com))) {
				continue;
			}

			local dis = BotAI.nextTickDistance(player, com);
			local isTarget = BotAI.IsTarget(player, com);

			if (isTarget && dis < 150) {
				BotAI.setBotCombatCommon(player, com);
			}

			if (BotAI.IsInfectedBeShoved(com) && isShove && !isHealing) {
				continue;
			}

			if(selected != null && selectedDis < dis) continue;

			if(dis <= selectedDis && isTarget && dis < closestDis && BotAI.CanShotOtherEntityInSight(player, com, dangerAwareAngle)) {
				if (isShove) {
					BotAI.shoveCommon(com);
				}

				selected = com;
				selectedDis = dis;
			} else if(!BotAI.HasTank && BotAI.CanShotOtherEntityInSight(player, com, awareAngle) && dis < closestDis) {
				if (isShove) {
					BotAI.shoveCommon(com);
				}

				closestCom = com;
				closestDis = dis;
			}
		}

		if(selected != null) {
			if(BotAI.BotDebugMode) {
				local headPos = BotAI.getEntityHeadPos(selected);
				DebugDrawBox(headPos, Vector(-5, -5, -5), Vector(5, 5, 5), 0, 255, 200, 0.2, 0.2);
			}

			BotAI.dangerInfected[player] <- selected;
		} else if(closestCom != null) {
			if(BotAI.BotDebugMode) {
				local headPos = BotAI.getEntityHeadPos(closestCom);
				DebugDrawBox(headPos, Vector(-5, -5, -5), Vector(5, 5, 5), 0, 255, 200, 0.2, 0.2);
			}

			BotAI.dangerInfected[player] <- closestCom;
		} else {
			BotAI.dangerInfected[player] <- null;
		}

		return 0.2;
    }

	if (_targetTimer != null) {
		_targetTimer.ValidateScriptScope();
		local scrScope = _targetTimer.GetScriptScope();
		scrScope["botai_think"] <- findTarget;
		AddThinkToEnt(_targetTimer, "botai_think");
	}
}

function BotAI::createNavigatorTimer(player) {
    local index = player.GetEntityIndex();
    local _targetTimer = SpawnEntityFromTable("info_target", { targetname = "botai_navigator_timer_" + index});
    local function navigator() {
        if(!BotAI.IsAlive(player)) {
            local infoTarget = null;
            while(infoTarget = Entities.FindByName(infoTarget, "botai_navigator_timer_" + index))
                infoTarget.Kill();
			delete BotAI.playerNavigator[player];
        }
		local navigator = BotAI.getNavigator(player);
		navigator.onUpdate();
		return 0.1;
    }

	if (_targetTimer != null) {
		_targetTimer.ValidateScriptScope();
		local scrScope = _targetTimer.GetScriptScope();
		scrScope["botai_think"] <- navigator;
		AddThinkToEnt(_targetTimer, "botai_think");
	}
}

function BotAI::createSeacherTimer(player) {
    local index = player.GetEntityIndex();
    local _targetTimer = SpawnEntityFromTable("info_target", { targetname = "botai_item_seacher_timer_" + index});
    local function seacher() {
        if(!BotAI.IsAlive(player)) {
            local infoTarget = null;
            while(infoTarget = Entities.FindByName(infoTarget, "botai_item_seacher_timer_" + index))
                infoTarget.Kill();

			return;
        }

		BotAI.updateSearchedEntity(player);
		return 1.5;
    }

	if (_targetTimer != null) {
		_targetTimer.ValidateScriptScope();
		local scrScope = _targetTimer.GetScriptScope();
		scrScope["botai_think"] <- seacher;
		AddThinkToEnt(_targetTimer, "botai_think");
	}
}

function BotAI::conditionTimer(func, delay) {
    local _targetTimer = SpawnEntityFromTable("info_target", { targetname = "botai_condition_timer_" + UniqueString()});
    local function doFunction() {
        if(func()) {
			self.Kill();
		}

		return delay
    }

	if (_targetTimer != null) {
		_targetTimer.ValidateScriptScope();
		local scrScope = _targetTimer.GetScriptScope();
		scrScope["botai_think"] <- doFunction;
		AddThinkToEnt(_targetTimer, "botai_think");
	}
}

function BotAI::delayTimer(func, delay, uuid = UniqueString()) {
	local timerName = "botai_delay_timer_" + uuid;

	if (Entities.FindByName(null, timerName) != null) {
		return;
	}

    local _targetTimer = SpawnEntityFromTable("info_target", { targetname = timerName});
	local _time = Time() + delay;
    local function doFunction() {
        if(Time() >= _time) {
			func();
			self.Kill();
		}
    }

	if (_targetTimer != null) {
		_targetTimer.ValidateScriptScope();
		local scrScope = _targetTimer.GetScriptScope();
		scrScope["botai_think"] <- doFunction;
		AddThinkToEnt(_targetTimer, "botai_think");
	}
}

function BotAI::throwTask(task, player, check) {
	local errorThinker = SpawnEntityFromTable("info_target", { targetname = "botai_task_throw" + UniqueString() });
	if (errorThinker != null) {
		errorThinker.ValidateScriptScope();
		local scrScope = errorThinker.GetScriptScope();
		local function thrower() {
			if(check) {
				task.singleUpdateChecker(player);
			} else {
				task.taskUpdate(player);
			}
		}
		scrScope["botai_think"] <- thrower;
		AddThinkToEnt(errorThinker, "botai_think");
		DoEntFire("!self", "Kill", "", 1, null, errorThinker);
	}
}

function BotAI::pingSystem() {
	foreach(player in BotAI.SurvivorList) {
		if(BotAI.IsPressingUse(player)) {
			local dot = 0.90;
			local dotThing = null;
			foreach(thing in BotAI.somethingBad) {
				if(!BotAI.IsEntityValid(thing) || BotAI.distanceof(player.GetOrigin(), thing.GetCenter()) > 200) continue;
				local dirction = BotAI.normalize(thing.GetCenter() - player.EyePosition());
				local dotValue = dirction.Dot(player.EyeAngles().Forward());
				if(dotValue >= dot) {
					dotThing = thing;
					dot = dotValue;
				}
			}

			if(BotAI.IsEntityValid(dotThing)) {
				DoEntFire("!self", "Use", "", 0, player, dotThing);
				return 0.5;
			}
		}
		/*
		else if(BotAI.IsPressingShove(player)) {
			local point = BotAI.CanSeeOtherEntityPrintName(player, 250, 0);
			local ename = "";
			if(player.GetActiveWeapon() != null)
				ename = player.GetActiveWeapon().GetClassname();
			printl(ename + " " + point + " " + BotAI.HasItem(point, "pain_pills"));

			if(BotAI.IsEntitySurvivorBot(point) && BotAI.HasItem(point, "pain_pills") && ename == "weapon_adrenaline")
			{
				BotAI.removeItem(player, "adrenaline");
				BotAI.removeItem(point, "pain_pills");
				player.GiveItem("pain_pills");
				point.GiveItem("adrenaline");
				return 1;
			}

			if(BotAI.IsEntitySurvivorBot(point) && BotAI.HasItem(point, "adrenaline") && ename == "weapon_pain_pills")
			{
				BotAI.removeItem(player, "pain_pills");
				BotAI.removeItem(point, "adrenaline");
				player.GiveItem("adrenaline");
				point.GiveItem("pain_pills");
				return 1;
			}
		}
		*/
	}

	return 0.01;
}

	function BotAI::pingShow() {
		foreach(human in BotAI.SurvivorHumanList) {
			if(human in BotAI.pingPoint) {
				local bot = BotAI.pingPoint[human];
				if(BotAI.IsEntityValid(bot) && !IsDedicatedServer()) {
					DebugDrawText(bot.EyePosition() + Vector(0, 0, 20), "♦", false, 0.1);
					DebugDrawCircle(bot.GetOrigin(), Vector(255, 0, 255), 0.15, 17, false, 0.1);
					DebugDrawCircle(bot.GetOrigin(), Vector(255, 0, 255), 0.2, 12.5, false, 0.1);
					DebugDrawCircle(bot.GetOrigin(), Vector(255, 0, 255), 0.25, 9, false, 0.1);
					DebugDrawCircle(bot.GetOrigin(), Vector(255, 0, 255), 0.3, 7, false, 0.1);
				} else {
					delete BotAI.pingPoint[human];
				}
			}
		}
		return 0.05;
	}

	function BotAI::takeThing() {
		if(!BotAI.BackPack && BotAI.needOil) {
			foreach(player in BotAI.SurvivorBotList) {
				if(!BotAI.IsAlive(player)) continue;
				local thing = null;
				if(BotAI.backpack(player) == null)
				while(thing = Entities.FindInSphere(thing, player.GetOrigin(), 100)) {
					if(thing.GetClassname() == BotAI.BotsNeedToFind)
						if(BotAI.BotTakeGasCan(player, thing))
							return 0.01;
				}
			}

			return 1;
		}

		if(!BotAI.BackPack) {
			return 3;
		}

		foreach(player in BotAI.SurvivorBotList) {
			if(!BotAI.IsAlive(player)) continue;
			local thing = null;
			local needGascan = BotAI.needOil && (BotAI.backpack(player) == null || BotAI.backpack(player).GetClassname() != BotAI.BotsNeedToFind);
			if(BotAI.backpack(player) == null || needGascan)
			while(thing = Entities.FindInSphere(thing, player.GetOrigin(), 100)) {
				if(needGascan) {
					if(thing.GetClassname() == BotAI.BotsNeedToFind)
						if(BotAI.BotTakeGasCan(player, thing))
							return 0.01;
				} else {
					if(thing.GetClassname() == BotAI.BotsNeedToFind || thing.GetClassname() == BotAI.ColaBottles) {
						if(BotAI.BotTakeGasCan(player, thing))
							return 0.01;
					} else if(thing.GetClassname() == "prop_physics") {
						foreach(modelName in BotAI.takeElse) {
							if(thing.GetModelName().find(modelName) != null) {
								if(BotAI.BotTakeGasCan(player, thing))
									return 0.01;
							}
						}
					} else {
						foreach(modelName in BotAI.modelMap) {
							if(thing.GetClassname() == modelName) {
								if(BotAI.BotTakeGasCan(player, thing))
									return 0.01;
							}
						}
					}
				}
			}
		}

		return 1;
	}

	function BotAI::createNavigatorTimer(player) {
		local index = player.GetEntityIndex();
		local _targetTimer = SpawnEntityFromTable("info_target", { targetname = "botai_navigator_timer_" + index});
		local function navigator() {
			if(!BotAI.IsAlive(player)) {
				local infoTarget = null;
				while(infoTarget = Entities.FindByName(infoTarget, "botai_navigator_timer_" + index))
					infoTarget.Kill();
				delete BotAI.playerNavigator[player];
			}

			local navigator = BotAI.getNavigator(player);
			navigator.onUpdate();

			return 0.2;
		}

		if (_targetTimer != null) {
			_targetTimer.ValidateScriptScope();
			local scrScope = _targetTimer.GetScriptScope();
			scrScope["botai_think"] <- navigator;
			AddThinkToEnt(_targetTimer, "botai_think");
		}
	}

	::BotAI.enumResource <- {
		weapon_upgradepack_incendiary_spawn = 1
		weapon_upgradepack_explosive_spawn = 1
		weapon_upgradepack_incendiary = 1
		weapon_upgradepack_explosive = 1

		weapon_pistol_magnum_spawn = 1
		weapon_pistol_magnum = 1

		weapon_pain_pills_spawn = 1
		weapon_adrenaline_spawn = 1
		weapon_pain_pills = 1
		weapon_adrenaline = 1

		weapon_pipe_bomb_spawn = 1
		weapon_molotov_spawn = 1
		weapon_vomitjar_spawn = 1
		weapon_pipe_bomb = 1
		weapon_molotov = 1
		weapon_vomitjar = 1

		weapon_defibrillator_spawn = 1
		weapon_defibrillator = 1
	}

	function BotAI::updateSearchedEntity(bot) {
		local map = {};
		local item = null;
		while(item = Entities.FindInSphere(item, bot.GetCenter(), 200)) {
			if(BotAI.IsEntityValid(item) && item.GetClassname() in BotAI.enumResource && item.GetOwnerEntity() == null && NetProps.GetPropEntity(item, "m_hOwnerEntity") == null) {
				if(BotAI.BotDebugMode) {
					DebugDrawBox(Vector(item.GetOrigin().x, item.GetOrigin().y, item.GetOrigin().z), Vector(-5, -5, -5), Vector(5, 5, 5), 100, 255, 0, 0.2, 1.5);
				}
				map[item] <- item;
			}
		}

		BotAI.searchedEntity[bot.GetEntityIndex()] <- map;
	}

	function BotAI::updateHumanSearchedEntity() {
		local map = {};
		foreach(player in BotAI.SurvivorHumanList) {
			local item = null;
			while(item = Entities.FindInSphere(item, player.GetCenter(), 200)) {
				if(BotAI.IsEntityValid(item) && item.GetClassname() in BotAI.enumResource && item.GetOwnerEntity() == null && NetProps.GetPropEntity(item, "m_hOwnerEntity") == null) {
					if(BotAI.BotDebugMode) {
						DebugDrawBox(Vector(item.GetOrigin().x, item.GetOrigin().y, item.GetOrigin().z), Vector(-5, -5, -5), Vector(5, 5, 5), 100, 255, 0, 0.2, 1.5);
					}
					map[item] <- item;
				}
			}
		}

		BotAI.humanSearchedEntity = map;

		return 1.5;
	}

	function BotAI::pickCoolDown() {
		BotAI.updateHumanCarriedBackpackWatches();

		foreach(prop, cooldown in BotAI.waitingToPick) {
			if(!BotAI.IsEntityValid(prop)) {
				delete BotAI.waitingToPick[prop];
				continue;
			}

			if(prop.GetOwnerEntity() != null) {
				if(BotAI.needOil && prop.GetClassname() == BotAI.BotsNeedToFind)
					BotAI.waitingToPick[prop] <- 2;
				else
					BotAI.waitingToPick[prop] <- 4;
			}
			else if(cooldown >= 0)
				BotAI.waitingToPick[prop] <- cooldown - 1;
		}

		foreach(idx, until in BotAI.BackpackPickupBlockUntil) {
			if(Time() >= until)
				delete BotAI.BackpackPickupBlockUntil[idx];
		}

		if("BackpackPickupWatch" in BotAI) {
			foreach(prop, data in BotAI.BackpackPickupWatch) {
				if(!BotAI.IsEntityValid(prop)) {
					BotAI.addBackpackPickupAreaBlock(data.key, data.lastPos, data.duration, data.radius);
					delete BotAI.BackpackPickupWatch[prop];
					continue;
				}

				local owner = prop.GetOwnerEntity();
				if(owner != null && BotAI.IsEntitySurvivor(owner)) {
					data.lastPos = owner.GetOrigin();
					BotAI.BackpackPickupWatch[prop] <- data;
					continue;
				}

				data.lastPos = prop.GetOrigin();
				BotAI.addBackpackPickupAreaBlock(data.key, data.lastPos, data.duration, data.radius);
				delete BotAI.BackpackPickupWatch[prop];
			}
		}

		if("BackpackPickupAreaBlock" in BotAI) {
			foreach(blockId, block in BotAI.BackpackPickupAreaBlock) {
				if(Time() >= block.until)
					delete BotAI.BackpackPickupAreaBlock[blockId];
			}
		}
		return 1.0;
	}

function BotAI::loadTimers() {
	::BotAI._taskTimer <- SpawnEntityFromTable("info_target", { targetname = "botai_task_timer" });
	if (::BotAI._taskTimer != null) {
			::BotAI._taskTimer.ValidateScriptScope();
			local scrScope = ::BotAI._taskTimer.GetScriptScope();
			scrScope["botai_think"] <- ::BotAI.updateAITasks;
			AddThinkToEnt(::BotAI._taskTimer, "botai_think");
	}

	local _singleTaskTimer = SpawnEntityFromTable("info_target", { targetname = "botai_single_task_timer" });
	if (_singleTaskTimer != null) {
			_singleTaskTimer.ValidateScriptScope();
			local scrScope = _singleTaskTimer.GetScriptScope();
			scrScope["botai_think"] <- ::BotAI.updateSingleAITasks;
			AddThinkToEnt(_singleTaskTimer, "botai_think");
	}

	local _groupTaskTimer = SpawnEntityFromTable("info_target", { targetname = "botai_group_task_timer" });
	if (_groupTaskTimer != null) {
			_groupTaskTimer.ValidateScriptScope();
			local scrScope = _groupTaskTimer.GetScriptScope();
			scrScope["botai_think"] <- ::BotAI.updateGroupAITasks;
			AddThinkToEnt(_groupTaskTimer, "botai_think");
	}

	local _aimTimer = SpawnEntityFromTable("info_target", { targetname = "botai_aim_timer" });
	if (_aimTimer != null) {
		_aimTimer.ValidateScriptScope();
		local scrScope = _aimTimer.GetScriptScope();
		scrScope["botai_think"] <- BotAI.bestAim;
		AddThinkToEnt(_aimTimer, "botai_think");
	}

	_aimTimer = SpawnEntityFromTable("info_target", { targetname = "botai_move_func" });
	if (_aimTimer != null) {
		_aimTimer.ValidateScriptScope();
		local scrScope = _aimTimer.GetScriptScope();
		scrScope["botai_think"] <- BotAI.moveFunc;
		AddThinkToEnt(_aimTimer, "botai_think");
	}

	local manualLeadThinker = SpawnEntityFromTable("info_target", { targetname = "botai_manual_lead"});
	if (manualLeadThinker != null) {
		manualLeadThinker.ValidateScriptScope();
		local scrScope = manualLeadThinker.GetScriptScope();
		scrScope["botai_think"] <- BotAI.manualLeadThink;
		AddThinkToEnt(manualLeadThinker, "botai_think");
	}

	local pingThinker = SpawnEntityFromTable("info_target", { targetname = "botai_ping_system"});
	if (pingThinker != null) {
		pingThinker.ValidateScriptScope();
		local scrScope = pingThinker.GetScriptScope();
		scrScope["botai_think"] <- BotAI.pingSystem;
		AddThinkToEnt(pingThinker, "botai_think");
	}

	pingThinker = SpawnEntityFromTable("info_target", { targetname = "botai_ping_show"});
	if (pingThinker != null) {
		pingThinker.ValidateScriptScope();
		local scrScope = pingThinker.GetScriptScope();
		scrScope["botai_think"] <- BotAI.pingShow;
		AddThinkToEnt(pingThinker, "botai_think");
	}

	local takeThinker = SpawnEntityFromTable("info_target", { targetname = "botai_take"});
	if (takeThinker != null) {
		takeThinker.ValidateScriptScope();
		local scrScope = takeThinker.GetScriptScope();
		scrScope["botai_think"] <- BotAI.takeThing;
		AddThinkToEnt(takeThinker, "botai_think");
	}


	local takeThinker = SpawnEntityFromTable("info_target", { targetname = "botai_pick_cooldown"});
	if (takeThinker != null) {
		takeThinker.ValidateScriptScope();
		local scrScope = takeThinker.GetScriptScope();
		scrScope["botai_think"] <- BotAI.pickCoolDown;
		AddThinkToEnt(takeThinker, "botai_think");
	}

	takeThinker = SpawnEntityFromTable("info_target", { targetname = "botai_search_entity"});
	if (takeThinker != null) {
		takeThinker.ValidateScriptScope();
		local scrScope = takeThinker.GetScriptScope();
		scrScope["botai_think"] <- BotAI.updateHumanSearchedEntity;
		AddThinkToEnt(takeThinker, "botai_think");
	}
}
