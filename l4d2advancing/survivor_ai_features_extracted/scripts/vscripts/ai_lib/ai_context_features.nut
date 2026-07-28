if (!("HordeActiveUntil" in BotAI))
	BotAI.HordeActiveUntil <- 0.0;
if (!("SupplySwapHandledUntil" in BotAI))
	BotAI.SupplySwapHandledUntil <- {};

function BotAI::CountNearbyCommons(originOrEntity, radius = 600.0) {
	local origin = originOrEntity;
	if (BotAI.IsEntityValid(originOrEntity))
		origin = originOrEntity.GetOrigin();

	if (origin == null || !("Length" in origin))
		return 0;

	local count = 0;
	local infected = null;
	while (infected = Entities.FindByClassnameWithin(infected, "infected", origin, radius)) {
		if (BotAI.IsAlive(infected))
			count++;
	}
	return count;
}

function BotAI::MarkHordePressure(duration = 30.0) {
	local until = Time() + duration;
	if (until > BotAI.HordeActiveUntil)
		BotAI.HordeActiveUntil = until;
}

function BotAI::ClearHordePressure() {
	BotAI.HordeActiveUntil = 0.0;
}

function BotAI::IsHordeEventActive() {
	if (Time() < BotAI.HordeActiveUntil)
		return true;

	local pendingMob = 0;
	try {
		pendingMob = Director.GetPendingMobCount();
	} catch (exception) {
		pendingMob = 0;
	}

	if (pendingMob > 0) {
		BotAI.MarkHordePressure(12.0);
		return true;
	}
	return false;
}

function BotAI::IsHordePressure(originOrEntity, radius = 600.0, threshold = 20) {
	return BotAI.CountNearbyCommons(originOrEntity, radius) >= threshold || BotAI.IsHordeEventActive();
}

function BotAI::HasIncapacitatedHordePressure() {
	if (BotAI.IsHordeEventActive())
		return true;

	foreach (survivor in BotAI.SurvivorList) {
		if (!BotAI.IsEntitySurvivor(survivor))
			continue;
		if ((survivor.IsIncapacitated() || survivor.IsHangingFromLedge()) && BotAI.CountNearbyCommons(survivor, 600.0) >= 20)
			return true;
	}
	return false;
}

function BotAI::HasActiveTank() {
	foreach (infected in BotAI.SpecialList) {
		if (BotAI.IsAlive(infected) && !infected.IsGhost() && infected.GetZombieType() == 8)
			return true;
	}
	return false;
}

function BotAI::FindPriorityBossTarget(bot) {
	local bestTank = null;
	local bestTankDistance = 1600.0;
	foreach (infected in BotAI.SpecialList) {
		if (!BotAI.IsAlive(infected) || infected.IsGhost() || infected.GetZombieType() != 8)
			continue;
		local distance = BotAI.distanceof(bot.GetOrigin(), infected.GetOrigin());
		if (distance < bestTankDistance && BotAI.CanShotOtherEntityInSight(bot, infected)) {
			bestTank = infected;
			bestTankDistance = distance;
		}
	}
	if (bestTank != null)
		return bestTank;

	local bestWitch = null;
	local bestWitchDistance = 900.0;
	foreach (witch in BotAI.WitchList) {
		if (!BotAI.IsAlive(witch) || !(BotAI.witchKilling(witch) || (BotAI.witchRunning(witch) && !BotAI.witchRetreat(witch))))
			continue;
		local distance = BotAI.distanceof(bot.GetOrigin(), witch.GetOrigin());
		if (distance < bestWitchDistance && BotAI.CanShotOtherEntityInSight(bot, witch)) {
			bestWitch = witch;
			bestWitchDistance = distance;
		}
	}
	return bestWitch;
}

function BotAI::FindImmediateSelfThreat(bot) {
	local nearest = null;
	local nearestDistance = 145.0;
	local common = null;
	while (common = Entities.FindByClassnameWithin(common, "infected", bot.GetOrigin(), 145.0)) {
		if (!BotAI.IsAlive(common))
			continue;
		local distance = BotAI.distanceof(bot.GetOrigin(), common.GetOrigin());
		if (distance < nearestDistance) {
			nearest = common;
			nearestDistance = distance;
		}
	}

	foreach (infected in BotAI.SpecialList) {
		if (!BotAI.IsAlive(infected) || infected.IsGhost() || infected.GetZombieType() == 8)
			continue;
		local distance = BotAI.nextTickDistance(bot, infected, 4.0);
		if (distance < 180.0 && (nearest == null || distance < nearestDistance)) {
			nearest = infected;
			nearestDistance = distance;
		}
	}
	return nearest;
}

function BotAI::EnsureTankPrimaryWeapon(bot) {
	if (!BotAI.IsEntitySurvivorBot(bot) || !BotAI.HasActiveTank())
		return false;
	if (BotAI.CountNearbyCommons(bot, 190.0) >= 4)
		return false;

	local active = bot.GetActiveWeapon();
	if (!BotAI.IsEntityValid(active))
		return false;
	local activeClass = active.GetClassname();
	if (activeClass != "weapon_melee" && activeClass != "weapon_chainsaw")
		return false;

	local held = BotAI.GetHeldItems(bot);
	if (!("slot0" in held) || !BotAI.IsEntityValid(held.slot0))
		return false;

	BotAI.UnforceButton(bot, 1);
	BotAI.ChangeItem(bot, 0);
	return true;
}

function BotAI::IsBoomerSafeToPop(boomer) {
	if (!BotAI.IsEntitySI(boomer) || boomer.GetZombieType() != 2)
		return false;

	foreach (survivor in BotAI.SurvivorList) {
		if (!BotAI.IsEntitySurvivor(survivor))
			continue;
		if (BotAI.distanceof(survivor.GetOrigin(), boomer.GetOrigin()) <= BotAI.splatRange && !BotAI.isVomited(survivor))
			return false;
	}
	return true;
}

function BotAI::IsDesignatedBoomerShooter(bot, boomer) {
	if (!BotAI.IsBoomerSafeToPop(boomer))
		return false;

	local nearest = null;
	local nearestDistance = 99999.0;
	foreach (candidate in BotAI.SurvivorBotList) {
		if (!BotAI.IsEntitySurvivorBot(candidate) || candidate.IsIncapacitated() || candidate.IsHangingFromLedge()
			|| candidate.IsDominatedBySpecialInfected() || BotAI.IsPlayerReviving(candidate))
			continue;
		if (!BotAI.CanShotOtherEntityInSight(candidate, boomer, -1))
			continue;
		local distance = BotAI.distanceof(candidate.GetOrigin(), boomer.GetOrigin());
		if (distance < nearestDistance || (distance == nearestDistance && nearest != null && candidate.GetEntityIndex() < nearest.GetEntityIndex())) {
			nearest = candidate;
			nearestDistance = distance;
		}
	}
	return nearest == bot;
}

function BotAI::FindSafeBoomerTargetForBot(bot) {
	local nearest = null;
	local nearestDistance = 1800.0;
	foreach (infected in BotAI.SpecialList) {
		if (!BotAI.IsBoomerSafeToPop(infected) || !BotAI.IsDesignatedBoomerShooter(bot, infected))
			continue;
		local distance = BotAI.distanceof(bot.GetOrigin(), infected.GetOrigin());
		if (distance < nearestDistance) {
			nearest = infected;
			nearestDistance = distance;
		}
	}
	return nearest;
}

function BotAI::GetSupplySwapSlot(classname) {
	if (classname == "weapon_pipe_bomb" || classname == "weapon_molotov" || classname == "weapon_vomitjar")
		return "slot2";
	if (classname == "weapon_first_aid_kit" || classname == "weapon_defibrillator"
		|| classname == "weapon_upgradepack_incendiary" || classname == "weapon_upgradepack_explosive")
		return "slot3";
	if (classname == "weapon_pain_pills" || classname == "weapon_adrenaline")
		return "slot4";
	return null;
}

function BotAI::SupplyClassToGiveName(classname) {
	if (classname != null && classname.len() > 7 && classname.slice(0, 7) == "weapon_")
		return classname.slice(7);
	return classname;
}

function BotAI::FindSupplySwapBot(human, explicitTarget = null) {
	if (BotAI.IsEntitySurvivorBot(explicitTarget) && BotAI.distanceof(human.GetOrigin(), explicitTarget.GetOrigin()) <= 180.0)
		return explicitTarget;

	local start = human.EyePosition();
	local trace = {
		start = start,
		end = start + human.EyeAngles().Forward().Scale(180.0),
		ignore = human,
		mask = g_MapScript.TRACE_MASK_SHOT
	};
	TraceLine(trace);
	if (trace.hit && "enthit" in trace && BotAI.IsEntitySurvivorBot(trace.enthit))
		return trace.enthit;
	return null;
}

function BotAI::IsSupplySwapUseShoveAtBot(human, explicitTarget = null) {
	if (!BotAI.IsEntitySurvivor(human) || IsPlayerABot(human) || !(human.GetButtonMask() & 32))
		return false;
	return BotAI.FindSupplySwapBot(human, explicitTarget) != null;
}

function BotAI::HandleSupplySwapUseShove(human, explicitTarget = null) {
	if (!BotAI.IsEntitySurvivor(human) || IsPlayerABot(human) || human.IsIncapacitated()
		|| human.IsHangingFromLedge() || human.IsDominatedBySpecialInfected())
		return false;
	if (!(human.GetButtonMask() & 32))
		return false;

	local humanIndex = human.GetEntityIndex();
	if (humanIndex in BotAI.SupplySwapHandledUntil && Time() < BotAI.SupplySwapHandledUntil[humanIndex])
		return true;

	local active = human.GetActiveWeapon();
	if (!BotAI.IsEntityValid(active))
		return false;
	local humanClass = active.GetClassname();
	local slot = BotAI.GetSupplySwapSlot(humanClass);
	if (slot == null)
		return false;

	local bot = BotAI.FindSupplySwapBot(human, explicitTarget);
	if (!BotAI.IsEntitySurvivorBot(bot) || bot.IsIncapacitated() || bot.IsHangingFromLedge() || bot.IsDominatedBySpecialInfected())
		return false;

	local botItems = BotAI.GetHeldItems(bot);
	local botItem = (slot in botItems) ? botItems[slot] : null;
	local botClass = BotAI.IsEntityValid(botItem) ? botItem.GetClassname() : null;
	if (botClass == null || botClass == humanClass)
		return false;

	local botActive = bot.GetActiveWeapon();
	local botActiveClass = BotAI.IsEntityValid(botActive) ? botActive.GetClassname() : null;
	active.Kill();
	botItem.Kill();

	if (slot == "slot2" && "GrenadierMode_PrepareABASupplySwap" in getroottable()) {
		try {
			::GrenadierMode_PrepareABASupplySwap(human, humanClass, bot, botClass);
		} catch (exception) {
			printl("[BotAI][SUPPLY_SWAP] Grenadier bridge failed: " + exception);
		}
	}

	human.GiveItem(BotAI.SupplyClassToGiveName(botClass));
	bot.GiveItem(BotAI.SupplyClassToGiveName(humanClass));
	if (botActiveClass != null && botActiveClass != botClass)
		bot.SwitchToItem(botActiveClass);

	BotAI.SupplySwapHandledUntil[humanIndex] <- Time() + 0.6;
	return true;
}
