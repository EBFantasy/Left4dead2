class ::ChunkMap {
	map = {}
	dimension = 150

	constructor(dimensionIn) {
		map = {}
		dimension = dimensionIn;
	}

	function put(entity) {
		if(!BotAI.IsEntityValid(entity)) return;
		local key = createKey(entity);
		if(!(key in map)) {
			map[key] <- [];
		}
		if(map[key].find(entity) == null)
			map[key].append(entity);
	}

	function get(object, scale = 1) {
		if(scale <= 0) return [];

		local pos = null;
		if(typeof object == "Vector") {
			pos = object;
		} else if(BotAI.IsEntityValid(object)) {
			pos = object.GetOrigin();
		}

		if(typeof pos != "Vector") return [];

		local baseChunkX = int(pos.x) * dimension;
		local baseChunkY = int(pos.y) * dimension;
		local baseChunkZ = int(pos.z) * dimension;

		local chunk = [];

		for(local x = -scale; x <= scale; ++x) {
			for(local y = -scale; y <= scale; ++y) {
				for(local z = -scale; z <= scale; ++z) {
					local chunkPos = Vector(
						baseChunkX + x * dimension,
						baseChunkY + y * dimension,
						baseChunkZ + z * dimension
					);

					local key = createKey(chunkPos);
					if(key in map) {
						foreach(entity in map[key]) {
							chunk.append(entity);
						}
					}
				}
			}
		}

		return chunk;
	}

	function createKey(object) {
		local key = "";
		if(typeof object == "Vector") {
			key = "X" + int(object.x).tostring() + "Y" + int(object.y).tostring() + "Z" + int(object.z).tostring();
		} else if(BotAI.IsEntityValid(object)) {
			local pos = object.GetOrigin();
			key = "X" + int(pos.x).tostring() + "Y" + int(pos.y).tostring() + "Z" + int(pos.z).tostring();
		}
		return key;
	}

	function int(i, z = false) {
		local dim = dimension;
		return (i / dim).tointeger();
	}

	function all() {
		local list = [];
		foreach(idx, chunk in map) {
			foreach(entity in chunk) {
				if(BotAI.IsEntityValid(entity))
					list.append(entity);
			}
		}
	}
}

function BotAI::playerKey(player) {
	if(BotAI.IsEntityValid(player)) {
		local character = NetProps.GetPropInt(player, "m_survivorCharacter").tostring();
		local health = player.GetHealth().tostring();

		local inventory = BotAI.GetHeldItems(player);
		local weapon = "";
		for(local i = 0; i < 5; ++i) {
			local idx = "slot" + i.tostring();
			if(idx in inventory) {
				weapon += "&" + inventory[idx].GetClassname();
			}
		}

		return character + "&" + health + weapon;
	}
	return null;
}

function BotAI::saveBackpack(roundEnd = false) {
	local props = {};

	if (roundEnd) {
		Msg("[Bot AI] Saving props backup.\n");
		props = BotAI.mapTransPackBackup;
	} else {
		foreach(bot, prop in BotAI.BotLinkGasCan) {
			if(BotAI.IsEntityValid(bot) && BotAI.IsEntityValid(prop)) {
				local key = BotAI.playerKey(bot);
				local value = {
					modelName = prop.GetModelName()
					clazz = prop.GetClassname()
				}


				Msg("[Bot AI] Saving props " + value.clazz + " with model " + value.modelName + "\n");
				props[key] <- value;
			}
		}
	}

	SaveTable("botai_backpack", props);
}

function BotAI::loadBackpack() {
	local map = {};
	RestoreTable("botai_backpack", map);
	if(typeof map == "table") {
		BotAI.mapTransPack = map;
		foreach (key, value in map) {
			BotAI.mapTransPackBackup[key] <- value;
		}
	}
	SaveTable("botai_backpack", {});
}

function BotAI::BotPerformanceCmd() {
	foreach(name, value in BotAI.debugCallCount) {
		printl("Method " + name + " use cache " + value + " times.");
	}
}

function BotAI::backpack(bot) {
	if(bot in BotAI.BotLinkGasCan) {
		if(!BotAI.IsEntityValid(BotAI.BotLinkGasCan[bot]) || BotAI.BotLinkGasCan[bot].GetOwnerEntity() != null) {
			if(BotAI.IsEntityValid(BotAI.BotLinkGasCan[bot]))
				BotAI.blockBackpackPickup(BotAI.BotLinkGasCan[bot], 5.0);
			delete BotAI.BotLinkGasCan[bot];
		} else
			return BotAI.BotLinkGasCan[bot];
	}

	return null;
}

function BotAI::getBackpackPickupKey(prop) {
	if(!BotAI.IsEntityValid(prop)) return "";

	local className = prop.GetClassname();
	if(className == BotAI.BotsNeedToFind || className == BotAI.ColaBottles)
		return className;

	foreach(modelToken, mappedClass in BotAI.modelMap) {
		if(className == mappedClass)
			return mappedClass;
	}

	if(className == "prop_physics") {
		local modelName = prop.GetModelName();
		foreach(modelToken, needle in BotAI.takeElse) {
			if(modelName.find(needle) != null) {
				if(modelToken in BotAI.modelMap)
					return BotAI.modelMap[modelToken];
				return needle;
			}
		}
	}

	return className;
}

function BotAI::addBackpackPickupAreaBlock(key, pos, duration = 5.0, radius = 220.0) {
	if(key == "" || !BotAI.validVector(pos)) return;
	if(!("BackpackPickupAreaBlock" in BotAI)) BotAI.BackpackPickupAreaBlock <- {};
	if(!("BackpackPickupAreaNextId" in BotAI)) BotAI.BackpackPickupAreaNextId <- 0;

	BotAI.BackpackPickupAreaNextId++;
	BotAI.BackpackPickupAreaBlock[BotAI.BackpackPickupAreaNextId] <- {
		key = key
		pos = pos
		until = Time() + duration
		radius = radius
	};
}

function BotAI::watchHumanCarriedBackpackItem(prop, owner, duration = 5.0) {
	if(!BotAI.IsEntityValid(prop) || !BotAI.IsEntitySurvivor(owner) || IsPlayerABot(owner)) return;
	if(!("BackpackPickupWatch" in BotAI)) BotAI.BackpackPickupWatch <- {};

	local data = {
		key = BotAI.getBackpackPickupKey(prop)
		lastPos = owner.GetOrigin()
		duration = duration
		radius = 220.0
	};

	if(prop in BotAI.BackpackPickupWatch)
		BotAI.BackpackPickupWatch[prop] = data;
	else
		BotAI.BackpackPickupWatch[prop] <- data;
}

function BotAI::updateHumanCarriedBackpackWatches() {
	local classes = {};
	classes[BotAI.BotsNeedToFind] <- 1;
	classes[BotAI.ColaBottles] <- 1;
	foreach(modelToken, mappedClass in BotAI.modelMap) {
		if(!(mappedClass in classes))
			classes[mappedClass] <- 1;
	}

	foreach(className, val in classes) {
		local prop = null;
		while(prop = Entities.FindByClassname(prop, className)) {
			if(!BotAI.IsEntityValid(prop)) continue;
			local owner = prop.GetOwnerEntity();
			if(owner != null && BotAI.IsEntitySurvivor(owner) && !IsPlayerABot(owner))
				BotAI.watchHumanCarriedBackpackItem(prop, owner, 5.0);
		}
	}
}

function BotAI::blockBackpackPickup(prop, duration = 5.0) {
	if(!BotAI.IsEntityValid(prop)) return;
	if(duration < 0.1)
		duration = 0.1;

	local idx = prop.GetEntityIndex();
	if(idx in BotAI.BackpackPickupBlockUntil)
		BotAI.BackpackPickupBlockUntil[idx] = Time() + duration;
	else
		BotAI.BackpackPickupBlockUntil[idx] <- Time() + duration;

	if(prop in BotAI.waitingToPick)
		BotAI.waitingToPick[prop] = duration.tointeger() + 1;
	else
		BotAI.waitingToPick[prop] <- duration.tointeger() + 1;
	local key = BotAI.getBackpackPickupKey(prop);
	local pos = prop.GetOrigin();
	BotAI.addBackpackPickupAreaBlock(key, pos, duration, 220.0);
	local data = {
		key = key
		lastPos = pos
		duration = duration
		radius = 220.0
	};
	if(prop in BotAI.BackpackPickupWatch)
		BotAI.BackpackPickupWatch[prop] = data;
	else
		BotAI.BackpackPickupWatch[prop] <- data;

	if(BotAI.BotDebugMode) {
		printl("[BotAI][Backpack] block auto pickup for " + prop + " " + duration + "s");
	}
}

function BotAI::isBackpackPickupBlocked(prop) {
	if(!BotAI.IsEntityValid(prop)) return false;

	local idx = prop.GetEntityIndex();
	if(idx in BotAI.BackpackPickupBlockUntil) {
		if(Time() < BotAI.BackpackPickupBlockUntil[idx])
			return true;

		delete BotAI.BackpackPickupBlockUntil[idx];
	}

	local key = BotAI.getBackpackPickupKey(prop);
	local pos = prop.GetOrigin();
	if("BackpackPickupAreaBlock" in BotAI) {
		local expired = [];
		foreach(blockId, block in BotAI.BackpackPickupAreaBlock) {
			if(Time() >= block.until) {
				expired.append(blockId);
				continue;
			}

			if(key == block.key && BotAI.distanceof(pos, block.pos) <= block.radius)
				return true;
		}

		foreach(blockId in expired)
			delete BotAI.BackpackPickupAreaBlock[blockId];
	}

	return false;
}

function BotAI::BotTakeGasCan(bot, gascan) {
	if(!BotAI.IsEntityValid(bot) || !BotAI.IsEntityValid(gascan)) return false;
	if(BotAI.isBackpackPickupBlocked(gascan)) return false;
	if(BotAI.IsEntitySurvivor(gascan.GetOwnerEntity())) {
		local owner = gascan.GetOwnerEntity();
		if(!IsAlive(owner))
			NetProps.SetPropInt(gascan, "m_hOwnerEntity", -1);
		local hasOne = false;
		foreach(thing in BotAI.modelMap) {
			if(BotAI.HasItem(owner, thing)) {
				hasOne = true;
			}
		}
		if(!hasOne)
			NetProps.SetPropInt(gascan, "m_hOwnerEntity", -1);
	}

	foreach(thing in BotAI.BotLinkGasCan) {
		if(thing == gascan)
			return false;
	}

	if(gascan.GetOwnerEntity() == null && BotAI.backpack(bot) != gascan && (!(gascan in BotAI.waitingToPick) || BotAI.waitingToPick[gascan] < 0)) {
		DoEntFire("!self", "SetParent", "!activator", 0.0, bot, gascan);
		BotAI.attachmentProp(bot, gascan);
		BotAI.BotLinkGasCan[bot] <- gascan;
		if(!(gascan in BotAI.waitingToPick))
			BotAI.waitingToPick[gascan] <- -1;
		return true;
	}

	return false;
}

function BotAI::attachmentProp(bot, prop, healing = false) {
	prop.SetOrigin(bot.GetCenter());
	if (healing) {
		if (bot.LookupAttachment("legL") != 0) {
			DoEntFire("!self", "SetParentAttachment", "legL", 0.02, bot, prop);
		} else if (bot.LookupAttachment("L_weapon_bone") != 0) {
			DoEntFire("!self", "SetParentAttachment", "L_weapon_bone", 0.02, bot, prop);
		}
	} else {
		if (bot.LookupAttachment("medkit") != 0) {
			DoEntFire("!self", "SetParentAttachment", "medkit", 0.02, bot, prop);
		} else if (bot.LookupAttachment("molotov") != 0) {
			DoEntFire("!self", "SetParentAttachment", "molotov", 0.02, bot, prop);
		} else if (bot.LookupAttachment("pills") != 0) {
			DoEntFire("!self", "SetParentAttachment", "pills", 0.02, bot, prop);
		} else {
			DoEntFire("!self", "SetParentAttachment", "attach_R_shoulderBladeAim", 0.02, bot, prop);
		}
	}
}

function BotAI::getMeleeSound(modelName) {
	local num = RandomInt(1, 2);
	local suffix = num.tostring() + ".wav";
	if(modelName.find("tonfa") != null)
		return "weapons/tonfa/melee_tonfa_0" + suffix;
	if(modelName.find("machete") != null)
		return "weapons/machete/machete_impact_flesh" + suffix;
	if(modelName.find("katana") != null)
		return "weapons/katana/melee_katana_0" + suffix;
	if(modelName.find("pan") != null)
		return "weapons/pan/melee_frying_pan_0" + suffix;
	if(modelName.find("fireaxe") != null)
		return "weapons/axe/axe_impact_flesh" + suffix;
	if(modelName.find("guitar") != null)
		return "weapons/guitar/melee_guitar_0" + suffix;
	if(modelName.find("crowbar") != null)
		return "weapons/crowbar/crowbar_impact_flesh" + suffix;
	if(modelName.find("bat") != null)
		return "weapons/bat/melee_cricket_bat_0" + suffix;
	if(modelName.find("golfclub") != null)
		return "weapons/golf_club/wpn_golf_club_melee_0" + suffix;
	if(modelName.find("knife") != null)
		return "weapons/knife/melee_knife_0" + suffix;
	if(modelName.find("chainsaw") != null)
		return "weapons/chainsaw/chainsaw_high_speed_lp_01.wav";

	return "weapons/machete/machete_impact_flesh" + suffix;
}

function BotAI::isUsableTriggerEntity(trigger) {
	if(!BotAI.IsEntityValid(trigger))
		return false;

	local cls = trigger.GetClassname();
	return cls == "func_button" || cls == "func_button_timed" || cls == "trigger_finale";
}

function BotAI::IsTriggerUsable(trigger) {
	if(BotAI.isUsableTriggerEntity(trigger)) {
		local cls = trigger.GetClassname();

		if(cls == "func_button") {
			local m_usable = NetProps.GetPropInt(trigger, "m_usable");
			local glowEntity = NetProps.GetPropEntity(trigger, "m_glowEntity");

			if (m_usable == 1 && BotAI.IsEntityValid(glowEntity))
				return true;
		} else if(cls == "func_button_timed") {
			local m_usable = NetProps.GetPropInt(trigger, "m_usable");
			if (m_usable == 1 && !BotAI.IsButtonPressed(trigger))
				return true;
		} else if(cls == "trigger_finale") {
			if(!BotAI.FinaleStart && !BotAI.IsButtonPressed(trigger))
				return true;
		}
	}

	return false;
}

function BotAI::debugCall(name) {
	/*
	if(name in BotAI.debugCallCount)
		debugCallCount[name] = debugCallCount[name] + 1;
	else
		debugCallCount[name] <- 1;
	*/
}

function BotAI::callCacheBoolean(tag, boolean, set = false, check = false) {
	if(set) {
		BotAI.callCache[tag] <- boolean;
		return true;
	}

	if(check)
		return tag in BotAI.callCache;

	return BotAI.callCache[tag];
}

function BotAI::playSound(entity, sound)
{
	if(sound == "") return;
	if(!IsSoundPrecached(sound)) {
		PrecacheSound(sound);
		entity.PrecacheScriptSound(sound);
	}
	if(BotAI.IsEntityValid(entity))
		EmitAmbientSoundOn(sound, 0.5, 350, 100, entity);
}

function BotAI::HasHoldButton(player, button )
{
	if (!BotAI.IsPlayerEntityValid(player))
	{
		return;
	}

	local buttons = NetProps.GetPropInt(player, "m_nButtons" );

	return buttons == ( buttons | button );
}

function BotAI::isChargerActionButton(button) {
	return button == 1 || button == 2 || button == 32 || button == 2048 || button == 8192;
}

function BotAI::HoldButton(player, button, time = 999, force = false)
{
	if (!BotAI.IsPlayerEntityValid(player))
	{
		return;
	}
	if(BotAI.isChargerWeaponLockout(player) && BotAI.isChargerActionButton(button))
		return;

	local buttons = NetProps.GetPropInt(player, "m_nButtons" );

	if ( BotAI.HasHoldButton(player, button) )
		return;

	NetProps.SetPropInt(player, "m_nButtons", ( buttons | button ) );

	if(force)
		BotAI.holdButton[button] <- true;

	local function RemoveButtonHold(args)
	{
		local buttons = NetProps.GetPropInt(args.ent_, "m_nButtons" );
		local button = args.but;
		NetProps.SetPropInt(args.ent_, "m_nButtons", ( buttons & ~button ) );
		if(args.forc && button in BotAI.holdButton)
			BotAI.holdButton[button] <- false;
	}

	::BotAI.Timers.AddTimerByName("RemoveButtonHold" + player.GetEntityIndex() + button, time, false, RemoveButtonHold, {ent_ = player, but = button, forc = force});
}

function BotAI::HasForcedButton(player, button ) {
	if (!BotAI.IsPlayerEntityValid(player))
	{
		return;
	}

	local buttons = NetProps.GetPropInt(player, "m_afButtonForced" );

	return buttons == ( buttons | button );
}

function BotAI::setContext(entity, context, duration) {
	if(!BotAI.IsEntityValid(entity)) {
		return;
	}
	entity.SetContext(context, context, duration);

	local function deleteContext() {
		if(BotAI.IsEntityValid(entity))
			entity.SetContext(context, ">null<", -1);
	}

	if(duration > 0) {
		BotAI.delayTimer(deleteContext, duration);
	}
}

function BotAI::hasContext(entity, context) {
	if(!BotAI.IsEntityValid(entity)) {
		return false;
	}
	if(entity.GetContext(context) == null || entity.GetContext(context) == ">null<")
		return false;
	return true;
}

function BotAI::isChargerWeaponLockout(player) {
	if(!BotAI.IsPlayerEntityValid(player) || !IsPlayerABot(player))
		return false;

	local idx = player.GetEntityIndex();
	if((idx in BotAI.FireSuspendUntil && Time() < BotAI.FireSuspendUntil[idx])
		|| BotAI.isUnderChargerControl(player)
		|| BotAI.hasStaleChargerLock(player))
		return true;

	return false;
}

function BotAI::beginChargerWeaponLockout(player, duration = 4.0) {
	if(!BotAI.IsEntitySurvivorBot(player))
		return;

	local idx = player.GetEntityIndex();
	local until = Time() + duration;
	if(!(idx in BotAI.FireSuspendUntil) || BotAI.FireSuspendUntil[idx] < until)
		BotAI.FireSuspendUntil[idx] <- until;

	NetProps.SetPropInt(player, "m_afButtonForced", 0);
	BotAI.UnforceButton(player, 1);
	BotAI.UnforceButton(player, 2048);
	BotAI.UnforceButton(player, 8192);

	if("setBotTarget" in BotAI) BotAI.setBotTarget(player, null);
	if("setBotShoveTarget" in BotAI) BotAI.setBotShoveTarget(player, null);
	if("setSmokerTarget" in BotAI) BotAI.setSmokerTarget(player, null);
	if("setBotLockTheard" in BotAI) BotAI.setBotLockTheard(player, -1);
	if("targetLocked" in BotAI && player in BotAI.targetLocked) delete BotAI.targetLocked[player];
	if("FullPress" in BotAI && player in BotAI.FullPress) BotAI.FullPress[player] <- 0;
	if("botMoveMap" in BotAI && player in BotAI.botMoveMap) BotAI.botMoveMap[player] <- Vector(0, 0, 0);
}

function BotAI::ForceButton(player, button, time = 999, force = false) {
	if (!BotAI.IsPlayerEntityValid(player) || BotAI.IsPlayerClimb(player) || BotAI.IsBotHealingOthers(player))
		return;
	if(BotAI.isChargerWeaponLockout(player) && BotAI.isChargerActionButton(button))
		return;
	if (!BotAI.IsOnGround(player) && button == 2)
		return;

	local buttons = NetProps.GetPropInt(player, "m_afButtonForced" );
	if(button == 2) {
		BotAI.setContext(player, "BOTAI_JUMP", 1);
	}
	if ( BotAI.HasForcedButton(player, button) )
		return;

	NetProps.SetPropInt(player, "m_afButtonForced", ( buttons | button ) );

	if(force)
		BotAI.forceButton[button] <- true;

	local function RemoveButtonForece(args) {
		local buttons = NetProps.GetPropInt(args.ent_, "m_afButtonForced" );
		local button = args.but;
		NetProps.SetPropInt(args.ent_, "m_afButtonForced", ( buttons & ~button ) );
		if(args.forc && button in BotAI.forceButton)
			BotAI.forceButton[button] <- false;
	}

	::BotAI.Timers.AddTimerByName("RemoveButtonForece" + player.GetEntityIndex() + button, time, false, RemoveButtonForece, {ent_ = player, but = button, forc = force});
}

function BotAI::RefreshForceButton(player, button, time = 999, force = false) {
	if (!BotAI.IsPlayerEntityValid(player) || BotAI.IsPlayerClimb(player) || BotAI.IsBotHealingOthers(player))
		return false;
	if(BotAI.isChargerWeaponLockout(player) && BotAI.isChargerActionButton(button))
		return false;
	if (!BotAI.IsOnGround(player) && button == 2)
		return false;

	local buttons = NetProps.GetPropInt(player, "m_afButtonForced" );
	if(button == 2)
		BotAI.setContext(player, "BOTAI_JUMP", 1);

	NetProps.SetPropInt(player, "m_afButtonForced", ( buttons | button ) );

	if(force)
		BotAI.forceButton[button] <- true;

	local function RemoveButtonForece(args) {
		if(!BotAI.IsPlayerEntityValid(args.ent_))
			return;
		local buttons = NetProps.GetPropInt(args.ent_, "m_afButtonForced" );
		local button = args.but;
		NetProps.SetPropInt(args.ent_, "m_afButtonForced", ( buttons & ~button ) );
		if(args.forc && button in BotAI.forceButton)
			BotAI.forceButton[button] <- false;
	}

	::BotAI.Timers.AddTimerByName("RemoveButtonForece" + player.GetEntityIndex() + button, time, false, RemoveButtonForece, {ent_ = player, but = button, forc = force});
	return true;
}

function BotAI::UnforceButton(player, button ) {
	if (!BotAI.IsPlayerEntityValid(player))
	{
		return;
	}

	if(button == 1 && BotAI.isManualKitHealing(player) && !BotAI.shouldPauseManualKit(player))
		return;

	if(button == 32 && BotAI.isManualUseHolding(player) && !BotAI.shouldPauseManualUse(player))
		return;

	local weapon = player.GetActiveWeapon();
	if(weapon && weapon.GetClassname() == "weapon_defibrillator" && button == 1)
		return;

	local buttons = NetProps.GetPropInt(player, "m_afButtonForced" );

	if ( !BotAI.HasForcedButton(player, button) )
		return;

	if(button in BotAI.forceButton && BotAI.forceButton[button])
		return;

	NetProps.SetPropInt(player, "m_afButtonForced", ( buttons & ~button ) );
}

function BotAI::ClearForcedButton(player, button) {
	if (!BotAI.IsPlayerEntityValid(player))
		return;
	if(button in BotAI.forceButton)
		BotAI.forceButton[button] <- false;

	local buttons = NetProps.GetPropInt(player, "m_afButtonForced" );
	NetProps.SetPropInt(player, "m_afButtonForced", ( buttons & ~button ) );
}

function BotAI::HasDisabledButton(player, button ) {
	if (!BotAI.IsPlayerEntityValid(player))
	{
		return;
	}

	local buttons = NetProps.GetPropInt(player, "m_afButtonDisabled" );

	return buttons == ( buttons | button );
}

function BotAI::DisableButton(player, button, time = 999, force = false) {
	if (!BotAI.IsPlayerEntityValid(player)) {
		return;
	}
	if(BotAI.isChargerWeaponLockout(player) && BotAI.isChargerActionButton(button))
		return;

	local buttons = NetProps.GetPropInt(player, "m_afButtonDisabled" );

	if ( BotAI.HasDisabledButton(player, button) )
		return;

	NetProps.SetPropInt(player, "m_afButtonDisabled", ( buttons | button ) );

	if(force)
		BotAI.disableButton[button] <- true;

	local function RemoveButtonDisable(args) {
		local buttons = NetProps.GetPropInt(args.ent_, "m_afButtonDisabled" );
		local button = args.but;
		NetProps.SetPropInt(args.ent_, "m_afButtonDisabled", ( buttons & ~button ) );
		if(args.forc && button in BotAI.disableButton)
			BotAI.disableButton[button] <- false;
	}

	::BotAI.Timers.AddTimerByName("RemoveButtonDisable" + player.GetEntityIndex() + button, time, false, RemoveButtonDisable, {ent_ = player, but = button, forc = force});
}

function BotAI::EnableButton(player, button )
{
	if (!BotAI.IsPlayerEntityValid(player))
	{
		return;
	}

	local buttons = NetProps.GetPropInt(player, "m_afButtonDisabled" );

	if ( !BotAI.HasDisabledButton(player, button) )
		return;

	if(button in BotAI.disableButton && BotAI.disableButton[button])
		return;

	NetProps.SetPropInt(player, "m_afButtonDisabled", ( buttons & ~button ) );
}

function BotAI::ChangeItem(p, slot) {
	if(BotAI.isManualKitHealing(p) && !BotAI.shouldPauseManualKit(p)) return;
	if(BotAI.IsPlayerClimb(p)) return;
	if(BotAI.isChargerWeaponLockout(p)) return;

	local wep = p.GetActiveWeapon();
	local ename = " ";
	if(BotAI.IsEntityValid(wep))
		ename = wep.GetClassname();

	if (BotAI.IsBotHealingOthers(p)) return;

	if (!BotAI.IsInCombat(p) && (ename == "weapon_first_aid_kit" ||
	ename == "weapon_defibrillator" || ename == "weapon_pain_pills" || ename == "weapon_adrenaline")) return;

	local t = BotAI.GetHeldItems(p);

	if (t && ("slot" + slot.tostring()) in t) {
		local weapon = t[("slot" + slot.tostring())];

		if (weapon.GetClassname() != ename) {
			p.SwitchToItem(weapon.GetClassname());
			if(BotAI.BotDebugMode) {
				local str = BotAI.getPlayerBaseName(p) + " change: " + ename + " -> "+ weapon.GetClassname();
				DebugDrawText(p.EyePosition(), str, true, 0.8);
				printl(str)
			}
			NetProps.SetPropFloat(weapon, "m_flNextPrimaryAttack", Time() - 1);
			NetProps.SetPropFloat(weapon, "m_flNextSecondaryAttack", Time() - 1);
		}
	}
}

function BotAI::isNearCheckPoint(player, distance = 250) {
	local areas = {};
	NavMesh.GetNavAreasInRadius(player.GetOrigin(), distance, areas);
	foreach(area in areas) {
		//                                                         CHECKPOINT ||                 DOOR or DESTROYED_DOOR
		if ("HasSpawnAttributes" in area && (area.HasSpawnAttributes(1 << 11) || area.HasSpawnAttributes(1 << 18))) {
			return true;
		}
	}

	return false;
}

::BotAI.GetPrimaryClipAmmo <- function(p) {
	local t = BotAI.GetHeldItems(p);

	if (t && "slot0" in t) {
		return NetProps.GetPropInt(t["slot0"], "m_iClip1")
	}

	return 0;
}

::BotAI.ReloadPrimaryClip <- function(p) {
	local t = BotAI.GetHeldItems(p);

	if (t && "slot0" in t && t["slot0"]) {
		local wep = t["slot0"];
		local ammoAmount = wep.GetMaxClip1() * 0.3;
		if(ammoAmount < 1)
			ammoAmount = 1;
		wep.SetClip1(ammoAmount);
	}
}

function BotAI::versusWeaponCheck(wep) {
	if(wep.find("shotgun") != null || wep.find("smg") != null || wep.find("melee") != null || wep.find("weapon_pistol") != null)
		return true;
	return false;
}

function BotAI::getDamage(wep) {
	switch(wep)
	{
		case "weapon_pistol":
			return 36;
		case "weapon_pistol_magnum":
			return 80;
		case "weapon_smg":
			return 20;
		case "weapon_pumpshotgun":
			return 25;
		case "weapon_autoshotgun":
			return 23;
		case "weapon_rifle":
			return 33;
		case "weapon_hunting_rifle":
			return 90;
		case "weapon_smg_silenced":
			return 25;
		case "weapon_shotgun_chrome":
			return 31;
		case "weapon_sniper_military":
			return 90;
		case "weapon_shotgun_spas":
			return 28;
		case "weapon_rifle_desert":
			return 44;
		case "weapon_rifle_ak47":
			return 58;
		case "weapon_smg_mp5":
			return 24;
		case "weapon_rifle_sg552":
			return 33;
		case "weapon_sniper_awp":
			return 115;
		case "weapon_sniper_scout":
			return 90;
		case "weapon_rifle_m60":
			return 50;
		default :
			return 20;
	}
}

function BotAI::getNavigator(player) {
	if(!(player in BotAI.playerNavigator)) {
		BotAI.playerNavigator[player] <- Navigator(player);
		BotAI.createNavigatorTimer(player);
	}

	return BotAI.playerNavigator[player];
}

function BotAI::clearManualLeadCommandSet(bot, lockDuration = 3.0) {
	if(!BotAI.IsEntitySurvivorBot(bot)) return;

	local navigator = BotAI.getNavigator(bot);
	navigator.movingID = null;
	foreach(id, path in navigator.pathCache) {
		delete navigator.pathCache[id];
	}

	if(bot in BotAI.targetLocked)
		delete BotAI.targetLocked[bot];
	if(bot in BotAI.botMoveMap)
		BotAI.botMoveMap[bot] <- Vector(0, 0, 0);

	BotAI.BotReset(bot);

	local lock = 3;
	BotAI.setBotLockTheard(bot, lock);
	local function unlock(args) {
		if(BotAI.IsPlayerEntityValid(args.bot))
			BotAI.expiredBotTheard(args.bot, args.lock);
	}
	BotAI.Timers.AddTimerByName("manualLeadLock" + bot.GetEntityIndex(), lockDuration, false, unlock, {bot = bot, lock = lock});
}

function BotAI::stopManualLead(bot) {
	if(!BotAI.IsEntitySurvivorBot(bot)) return;

	if(bot in BotAI.ManualLead)
		delete BotAI.ManualLead[bot];

	local navigator = BotAI.getNavigator(bot);
	navigator.clearPath("manualLead$");
	navigator.clearPath("manualLeadAuto$");
	navigator.clearPath("manualScout$");
	navigator.clearPath("manualLead$Stay#");
	navigator.clearPath("manualLeadAuto$Stay#");
	navigator.clearPath("manualScout$Stay#");

	if(BotAI.BotDebugMode)
		printl("[BotAI][ManualLead] stop " + BotAI.getPlayerBaseName(bot));
}

function BotAI::isManualLeadRunning(bot) {
	if(!BotAI.IsEntitySurvivorBot(bot)) return false;
	if(!(bot in BotAI.ManualLead)) return false;

	local data = BotAI.ManualLead[bot];
	if("until" in data && data.until > 0 && Time() >= data.until)
		return false;

	return true;
}

function BotAI::getManualLeadOwner(data) {
	if(("autonomousLead" in data) && data.autonomousLead)
		return null;

	if("owner" in data && BotAI.IsPlayerEntityValid(data.owner) && !IsPlayerABot(data.owner) && BotAI.IsAlive(data.owner))
		return data.owner;

	foreach(player in BotAI.SurvivorHumanList) {
		if(BotAI.IsPlayerEntityValid(player) && BotAI.IsAlive(player))
			return player;
	}

	return null;
}

function BotAI::hasAliveHumanSurvivor() {
	foreach(player in BotAI.SurvivorHumanList) {
		if(BotAI.IsPlayerEntityValid(player) && player.IsSurvivor() && BotAI.IsAlive(player))
			return true;
	}

	return false;
}

function BotAI::isNearAliveHumanSurvivor(pos, radius = 600) {
	if(!BotAI.hasAliveHumanSurvivor())
		return true;

	foreach(player in BotAI.SurvivorHumanList) {
		if(BotAI.IsPlayerEntityValid(player) && player.IsSurvivor() && BotAI.IsAlive(player) && BotAI.distanceof(pos, player.GetOrigin()) <= radius)
			return true;
	}

	return false;
}

function BotAI::isGoodManualLeadHint(bot, hint, baseFlow = null, owner = null, badTargets = null) {
	if(!BotAI.validVector(hint) || !BotAI.IsEntitySurvivorBot(bot))
		return false;

	local hintArea = NavMesh.GetNearestNavArea(hint + Vector(0, 0, 40), 300, true, true);
	if(hintArea == null || hintArea.IsDamaging() || hintArea.IsBlocked(2, false) || hintArea.IsBlocked(2, true))
		return false;

	if(BotAI.isManualLeadTargetBlocked(hintArea.GetCenter(), badTargets))
		return false;

	local startArea = bot.GetLastKnownArea();
	if(startArea == null)
		return false;

	local botPos = bot.GetOrigin();
	local distBot = BotAI.distanceof(botPos, hintArea.GetCenter());
	if(distBot < 90 || distBot > 2300)
		return false;

	if(BotAI.IsPlayerEntityValid(owner) && BotAI.IsAlive(owner)) {
		local ownerPos = owner.GetOrigin();
		local distOwner = BotAI.distanceof(ownerPos, hintArea.GetCenter());
		if(distOwner > 2600)
			return false;

		local zdelta = hintArea.GetCenter().z - ownerPos.z;
		if(zdelta < 0)
			zdelta = -zdelta;
		if(zdelta > 700)
			return false;
	}

	local pathLimit = distBot + 650;
	if(pathLimit < 900)
		pathLimit = 900;
	if(pathLimit > 2600)
		pathLimit = 2600;

	return NavMesh.NavAreaBuildPath(startArea, hintArea, hintArea.GetCenter(), pathLimit, 2, false);
}

function BotAI::isManualLeadTargetBlocked(pos, badTargets = null) {
	if(!BotAI.validVector(pos) || badTargets == null)
		return false;

	local now = Time();
	foreach(idx, bad in badTargets) {
		if(!("pos" in bad) || !BotAI.validVector(bad.pos))
			continue;
		if(("until" in bad) && now >= bad.until)
			continue;
		if(BotAI.distanceof(pos, bad.pos) <= 300)
			return true;
	}

	return false;
}

function BotAI::rememberManualLeadBadTarget(data, pos) {
	if(!BotAI.validVector(pos))
		return;

	if(!("badTargets" in data))
		data.badTargets <- {};
	if(!("badTargetSeq" in data))
		data.badTargetSeq <- 0;

	data.badTargetSeq = data.badTargetSeq + 1;
	data.badTargets[data.badTargetSeq] <- {
		pos = pos
		until = Time() + 12.0
	};

	foreach(idx, bad in data.badTargets) {
		if(("until" in bad) && Time() >= bad.until)
			delete data.badTargets[idx];
	}
}

function BotAI::findManualLeadDirectionalTarget(bot, owner = null, hint = null, hintMeta = null, badTargets = null) {
	if(!BotAI.IsEntitySurvivorBot(bot)) return null;

	local anchor = bot;
	if(BotAI.IsPlayerEntityValid(owner) && BotAI.IsAlive(owner))
		anchor = owner;

	local botPos = bot.GetOrigin();
	local anchorPos = anchor.GetOrigin();
	local startArea = bot.GetLastKnownArea();
	if(startArea == null)
		return null;

	local anchorArea = anchor.GetLastKnownArea();
	if(anchorArea == null)
		anchorArea = NavMesh.GetNearestNavArea(anchorPos + Vector(0, 0, 40), 260, true, true);

	local aimStart = anchorPos + Vector(0, 0, 50);
	local aimDir = null;
	if(hintMeta != null && typeof hintMeta == "table") {
		if(("eyePos" in hintMeta) && BotAI.validVector(hintMeta.eyePos))
			aimStart = hintMeta.eyePos;
		if(("forward" in hintMeta) && BotAI.validVector(hintMeta.forward)) {
			local fwd = hintMeta.forward;
			local flen = sqrt(fwd.x * fwd.x + fwd.y * fwd.y + fwd.z * fwd.z);
			if(flen > 0.1)
				aimDir = Vector(fwd.x / flen, fwd.y / flen, fwd.z / flen);
		}
	}

	if(BotAI.validVector(hint)) {
		local hx = hint.x - aimStart.x;
		local hy = hint.y - aimStart.y;
		local hz = hint.z - aimStart.z;
		local hlen = sqrt(hx * hx + hy * hy + hz * hz);
		if(hlen > 20.0)
			aimDir = Vector(hx / hlen, hy / hlen, hz / hlen);
	}

	if(!BotAI.validVector(aimDir) && anchor != bot) {
		try {
			local fwd = anchor.EyeAngles().Forward();
			local flen = sqrt(fwd.x * fwd.x + fwd.y * fwd.y + fwd.z * fwd.z);
			if(flen > 0.1)
				aimDir = Vector(fwd.x / flen, fwd.y / flen, fwd.z / flen);
		} catch(e) {}
	}

	if(!BotAI.validVector(aimDir))
		return null;

	local aimUp = aimDir.z;
	local anchorFlow = GetFlowDistanceForPosition(anchorPos);
	local best = null;
	local bestScore = -999999.0;
	local bestReason = "";

	local function considerCandidatePos(rawPos, baseBonus = 0.0, requireLineFit = false, reason = "") {
		if(!BotAI.validVector(rawPos))
			return;

		local area = NavMesh.GetNearestNavArea(rawPos + Vector(0, 0, 40), 420, true, true);
		if(area == null || area.IsDamaging() || area.IsBlocked(2, false) || area.IsBlocked(2, true))
			return;

		local pos = area.GetCenter();
		if(BotAI.isManualLeadTargetBlocked(pos, badTargets))
			return;

		local distBot = BotAI.distanceof(botPos, pos);
		if(distBot < 80 || distBot > 2500)
			return;

		local distAnchor = BotAI.distanceof(anchorPos, pos);
		if(distAnchor < 80 || distAnchor > 2500)
			return;

		local zdelta = pos.z - anchorPos.z;
		local absz = zdelta;
		if(absz < 0)
			absz = -absz;
		local maxZ = 620.0;
		if(aimUp > 0.18 || aimUp < -0.18)
			maxZ = 1100.0;
		if(absz > maxZ)
			return;

		local pathLimit = distBot + 700;
		if(pathLimit < 900)
			pathLimit = 900;
		if(pathLimit > 3200)
			pathLimit = 3200;
		if(!NavMesh.NavAreaBuildPath(startArea, area, pos, pathLimit, 2, false))
			return;

		if(anchorArea != null && anchorArea != startArea) {
			local anchorLimit = distAnchor + 650;
			if(anchorLimit < 800)
				anchorLimit = 800;
			if(anchorLimit > 3200)
				anchorLimit = 3200;
			if(!NavMesh.NavAreaBuildPath(anchorArea, area, pos, anchorLimit, 2, false))
				return;
		}

		local ox = pos.x - aimStart.x;
		local oy = pos.y - aimStart.y;
		local oz = pos.z - aimStart.z;
		local along = ox * aimDir.x + oy * aimDir.y + oz * aimDir.z;
		if(along < 40 || along > 2200)
			return;

		local px = aimStart.x + aimDir.x * along;
		local py = aimStart.y + aimDir.y * along;
		local pz = aimStart.z + aimDir.z * along;
		local lx = pos.x - px;
		local ly = pos.y - py;
		local lz = pos.z - pz;
		local lateral = sqrt(lx * lx + ly * ly + lz * lz);
		if(requireLineFit && lateral > 520)
			return;

		local forwardDot = 0.0;
		local flatLen = sqrt(aimDir.x * aimDir.x + aimDir.y * aimDir.y);
		if(flatLen > 0.05 && distAnchor > 1.0) {
			local dx = pos.x - anchorPos.x;
			local dy = pos.y - anchorPos.y;
			local dlen = sqrt(dx * dx + dy * dy);
			if(dlen > 1.0)
				forwardDot = ((dx / dlen) * (aimDir.x / flatLen)) + ((dy / dlen) * (aimDir.y / flatLen));
		}

		local verticalScore = -absz * 0.05;
		if(aimUp > 0.18)
			verticalScore = zdelta * 0.9;
		else if(aimUp < -0.18)
			verticalScore = (-zdelta) * 0.9;

		local flowDelta = GetFlowDistanceForPosition(pos) - anchorFlow;
		local score = baseBonus + forwardDot * 520.0 + verticalScore + flowDelta * 0.12 - distAnchor * 0.16 - distBot * 0.04 - absz * 0.03;
		score += 140.0 - lateral * 0.45 + along * 0.05;

		if(score > bestScore) {
			bestScore = score;
			best = pos;
			bestReason = reason;
		}
	}

	if(BotAI.validVector(hint))
		considerCandidatePos(hint, 420.0, true, "hit");

	local sampleDistances = [180, 320, 520, 760, 1050, 1400];
	foreach(sampleDist in sampleDistances) {
		local sample = Vector(
			aimStart.x + aimDir.x * sampleDist,
			aimStart.y + aimDir.y * sampleDist,
			aimStart.z + aimDir.z * sampleDist
		);
		considerCandidatePos(sample, 260.0 - sampleDist * 0.03, true, "ray");
	}

	foreach(idx, ladder in BotAI.ladders) {
		if(ladder == null)
			continue;

		local topPos = ladder.GetTopOrigin();
		local bottomPos = ladder.GetBottomOrigin();
		local topBonus = 560.0;
		local bottomBonus = 560.0;

		if(aimUp > 0.18) {
			topBonus += 180.0;
			bottomBonus -= 80.0;
		} else if(aimUp < -0.18) {
			bottomBonus += 180.0;
			topBonus -= 80.0;
		}

		if(BotAI.validVector(hint)) {
			if(BotAI.distanceof(hint, topPos) < 360)
				topBonus += 220.0;
			if(BotAI.distanceof(hint, bottomPos) < 360)
				bottomBonus += 220.0;
		}

		considerCandidatePos(topPos, topBonus, true, "ladder-top");
		considerCandidatePos(bottomPos, bottomBonus, true, "ladder-bottom");
	}

	if(best != null && BotAI.BotDebugMode)
		printl("[BotAI][ManualLead][DirHint] " + BotAI.getPlayerBaseName(bot) + " -> " + best + " [" + bestReason + "] score=" + bestScore);

	return best;
}

// selfAnchored: when true the search is centred on the BOT, exactly as it is
// when no human survivor is alive. This is what the "pathfind" (lead) command
// wants - the user verified that bots navigate the same spots smoothly once
// the humans are dead, but stall there while a human is alive.
//
// The reason is right below: with a human present the anchor becomes the
// PLAYER, so candidate areas are gathered around the player, scored by
// distance to the player, and rejected outright past 1700u from them. On a
// map where the route doubles back or the player stands still, that biases the
// bot towards areas behind it and it ends up shuffling in a dead end.
function BotAI::findManualLeadTarget(bot, owner = null, badTargets = null, selfAnchored = false) {
	if(!BotAI.IsEntitySurvivorBot(bot)) return null;

	local botPos = bot.GetOrigin();
	local startArea = bot.GetLastKnownArea();
	if(startArea == null)
		return null;

	local anchor = bot;
	if(!selfAnchored && BotAI.IsPlayerEntityValid(owner) && BotAI.IsAlive(owner))
		anchor = owner;

	local anchorPos = anchor.GetOrigin();
	if(anchor != bot && BotAI.distanceof(botPos, anchorPos) > 1700)
		return null;

	local anchorArea = anchor.GetLastKnownArea();
	if(anchorArea == null)
		anchorArea = NavMesh.GetNearestNavArea(anchorPos + Vector(0, 0, 40), 260, true, true);
	if(anchorArea == null)
		return null;

	local anchorFlow = GetFlowDistanceForPosition(anchorPos);
	local botFlow = GetFlowDistanceForPosition(botPos);
	local baseFlow = anchorFlow;
	if(botFlow > baseFlow)
		baseFlow = botFlow;

	local ownerForward = Vector(0, 0, 0);
	local hasForward = false;
	if(anchor != bot) {
		try {
			ownerForward = anchor.EyeAngles().Forward();
			ownerForward.z = 0;
			local flen = sqrt(ownerForward.x * ownerForward.x + ownerForward.y * ownerForward.y);
			if(flen > 0.1) {
				ownerForward.x = ownerForward.x / flen;
				ownerForward.y = ownerForward.y / flen;
				hasForward = true;
			}
		} catch(e) {}
	}

	local best = null;
	local bestScore = -999999.0;
	local radii = [650, 900, 1200, 1500];

	for(local pass = 0; pass < 2; pass++) {
	foreach(radius in radii) {
		local areas = {};
		NavMesh.GetNavAreasInRadius(anchorPos, radius, areas);

		foreach(area in areas) {
			if(area == null) continue;
			if(area.IsDamaging() || area.IsBlocked(2, false) || area.IsBlocked(2, true)) continue;

			local pos = area.GetCenter();
			if(BotAI.isManualLeadTargetBlocked(pos, badTargets)) continue;

			local distAnchor = BotAI.distanceof(anchorPos, pos);
			local distBot = BotAI.distanceof(botPos, pos);
			if(distAnchor < 180 || distAnchor > radius) continue;
			if(distBot > 1850) continue;

			local flow = GetFlowDistanceForPosition(pos);
			local flowDelta = flow - baseFlow;
			if(flowDelta < 70 || flowDelta > 900) continue;

			local zdelta = pos.z - anchorPos.z;
			if(zdelta < 0)
				zdelta = -zdelta;
			if(zdelta > 420) continue;

			local forwardDot = 0.0;
			if(hasForward && distAnchor > 1.0) {
				local tx = (pos.x - anchorPos.x) / distAnchor;
				local ty = (pos.y - anchorPos.y) / distAnchor;
				forwardDot = tx * ownerForward.x + ty * ownerForward.y;
				if(pass == 0 && forwardDot < -0.15)
					continue;
			}

			local pathLimit = distBot + 450;
			if(pathLimit < 900)
				pathLimit = 900;

			if(!NavMesh.NavAreaBuildPath(startArea, area, pos, pathLimit, 2, false))
				continue;
			if(anchorArea != startArea && !NavMesh.NavAreaBuildPath(anchorArea, area, pos, radius + 350, 2, false))
				continue;

			local score = flowDelta * 1.2 - distAnchor * 0.25 - distBot * 0.05 - zdelta * 0.08 + forwardDot * 260.0;
			if(score > bestScore) {
				bestScore = score;
				best = area;
			}
		}

		if(best != null)
			return best.GetCenter();
	}
	}

	return null;
}

function BotAI::startManualLead(bot, owner = null, mode = "lead", duration = 0.0, hint = null, hintMeta = null, autonomousLead = false) {
	if(!BotAI.IsEntitySurvivorBot(bot)) return false;

	local until = 0.0;
	if(duration > 0.0)
		until = Time() + duration;

	BotAI.ManualLead[bot] <- {
		owner = owner
		mode = mode
		until = until
		lockUntil = Time() + 1.5
		nextPath = 0.0
		hint = hint
		hintMeta = hintMeta
		autonomousLead = autonomousLead
		usedHint = false
		badTargets = {}
		badTargetSeq = 0
	};

	BotAI.clearManualLeadCommandSet(bot, 1.5);

	if(BotAI.BotDebugMode)
		printl("[BotAI][ManualLead] start " + mode + " " + BotAI.getPlayerBaseName(bot));

	return true;
}

function BotAI::applyPushVelocity(player, target, force = 400) {
	local velocity = target.GetVelocity();
	local pushVec = BotAI.normalize(target.GetOrigin() - player.GetOrigin()).Scale(force);
	velocity = Vector(pushVec.x, pushVec.y, velocity.z);
	target.SetVelocity(velocity);
}

function BotAI::isDoorEntity(entity) {
	if(!BotAI.IsEntityValid(entity)) return false;
	return entity.GetClassname() == "func_door" || entity.GetClassname() == "prop_door_rotating_checkpoint" || entity.GetClassname() == "prop_door_rotating";
}

function BotAI::botMove(player, vec) {
	vec = BotAI.fakeTwoD(vec);
	local inAir = !BotAI.IsOnGround(player);
	if(inAir) {
		return;
	}
	if(player in BotAI.botMoveMap) {
		local botVec = BotAI.botMoveMap[player];
		if(botVec.Length() >= 1)
			BotAI.botMoveMap[player] = botVec*0.1 + vec*0.9;
		else
			BotAI.botMoveMap[player] = vec;
	} else {
		BotAI.botMoveMap[player] <- vec;
	}
}

function BotAI::botRun(player, targetPos, speed = 220) {
	local pushVec = BotAI.normalize(targetPos - player.GetOrigin()).Scale(speed);
	local velocity = Vector(pushVec.x, pushVec.y, player.GetVelocity().z);

	local dodgeVec = BotAI.getBotDedgeVector(player);
	if(BotAI.validVector(dodgeVec)) {
		velocity = velocity.Scale(0.7) + dodgeVec.Scale(0.3);
	}

	if(BotAI.validVector(velocity)) {
		BotAI.botMove(player, velocity);
	}

	if(BotAI.BotDebugMode) {
		DebugDrawCircle(targetPos, Vector(0, 255, 0), 1.0, 25, true, 0.2);
		DebugDrawText(targetPos, BotAI.getPlayerBaseName(player) + " navigate here", false, 0.2);
	}
}

function BotAI::EnableSight(arg) {
	if("infect" in arg && BotAI.IsEntityValid(arg.infect) && "IsDead" in arg.infect && !arg.infect.IsDead())
		arg.infect.SetSenseFlags(arg.infect.GetSenseFlags() & ~BOT_CANT_SEE);
}

function BotAI::SetPlayerAtCheckPoint(player, boolean) {
	BotAI.InSafeHouse[player.GetEntityIndex()] <- boolean;
}

function BotAI::IsPlayerAtCheckPoint(player) {
	return player.GetEntityIndex() in BotAI.InSafeHouse && BotAI.InSafeHouse[player.GetEntityIndex()];
}

function BotAI::getLowOriginFromArea(area, dir) {
	local origins = BotAI.getDirectionOriginFromArea(area, dir);
	local origin0 = origins[0];
	local origin1 = origins[1];

	if(origin0.z > origin1.z)
		return origin1;
	else
		return origin0;
}

function BotAI::getHighOriginFromArea(area, dir) {
	local origins = BotAI.getDirectionOriginFromArea(area, dir);
	local origin0 = origins[0];
	local origin1 = origins[1];

	if(origin0.z < origin1.z)
		return origin1;
	else
		return origin0;
}

function BotAI::getDirectionOriginFromArea(area, dir) {
	local origin = [];
    switch(dir) {
		case 0:
			origin.append(area.GetCorner(0));
			origin.append(area.GetCorner(1));
			break;
		case 1:
			origin.append(area.GetCorner(1));
			origin.append(area.GetCorner(2));
			break;
		case 2:
			origin.append(area.GetCorner(2));
			origin.append(area.GetCorner(3));
			break;
		case 3:
			origin.append(area.GetCorner(3));
			origin.append(area.GetCorner(0));
			break;
	}
	return origin;
}

function BotAI::SetBotHealing(player, another) {
	BotAI.healing[player.GetEntityIndex()] <- another;
}

function BotAI::IsBotHealingOthers(player) {
	if(!BotAI.IsAlive(player)) {
		return false;
	}

	if (player.GetEntityIndex() in BotAI.healing) {
		local another = BotAI.healing[player.GetEntityIndex()];
		if(BotAI.IsAlive(another)) {
			return another.GetEntityIndex() != player.GetEntityIndex();
		}
	}

	return false;
}

function BotAI::IsBotHealingSelf(player) {
	if(!BotAI.IsAlive(player)) {
		return false;
	}

	if (player.GetEntityIndex() in BotAI.healing) {
		local another = BotAI.healing[player.GetEntityIndex()];
		if(BotAI.IsAlive(another)) {
			return another.GetEntityIndex() == player.GetEntityIndex();
		}
	}

	return false;
}

function BotAI::IsBotHealing(player) {
	if(!BotAI.IsAlive(player)) {
		return false;
	}

	if (player.GetEntityIndex() in BotAI.healing) {
		local another = BotAI.healing[player.GetEntityIndex()];
		if(BotAI.IsAlive(another)) {
			return true;
		}
	}

	return false;
}

::BotAI.setBotHealingTime <- function(player, boo){
	BotAI.healingTime[player.GetEntityIndex()] <- boo;
}

::BotAI.getBotHealingTime <- function(player){
	if(player.GetEntityIndex() in BotAI.healingTime)
		return BotAI.healingTime[player.GetEntityIndex()];

	return Time();
}

function BotAI::HasSpecialInfectedAlive() {
	local player = null;
	while(player = Entities.FindByClassname(player, "player"))
	{
		if(!player.IsSurvivor() && BotAI.IsAlive(player))
			return true;
	}

	return false;
}

function BotAI::breakTongue(smoker) {
	if(BotAI.hasContext(smoker, "BOTAI_BREAK"))
		return;

	local victim = NetProps.GetPropEntity(smoker, "m_tongueVictim");
	if(BotAI.IsEntityValid(victim)) {
		victim.SetOrigin(victim.GetOrigin() + Vector(0, 0, 20));
		victim.Stagger(Vector(0, 0, -100));
	}
}

function BotAI::isDeathStillAlive(death) {
	local _type = NetProps.GetPropInt(death, "m_nCharacterType");
	foreach(player in BotAI.SurvivorList) {
		if(NetProps.GetPropInt(player, "m_survivorCharacter") == _type)
			return true;
	}
	return false;
}

function BotAI::getPlayerBaseName(player)
{
	//local name = NetProps.GetPropInt(player, "m_survivorCharacter");

	return g_MapScript.GetCharacterDisplayName(player);
}

function BotAI::GetPrimaryUpgrades(player) {
	if (!BotAI.IsPlayerEntityValid(player)) {
		return 0;
	}

	local t = BotAI.GetHeldItems(player);

	if (t && "slot0" in t) {
		if ( t["slot0"].GetClassname().find("weapon_") == null )
			return 0;

		return NetProps.GetPropInt(t["slot0"], "m_upgradeBitVec");
	}
	return 0;
}

function BotAI::setPrimaryUpgrades(player, upgrade) {
	if (!BotAI.IsPlayerEntityValid(player)) {
		return;
	}

	local t = BotAI.GetHeldItems(player);

	if (t && "slot0" in t) {
		if ( t["slot0"].GetClassname().find("weapon_") == null )
			return;

		return NetProps.SetPropInt(t["slot0"], "m_upgradeBitVec", upgrade);
	}
}

function BotAI::SpawnUpgrade( upgrade, count = 4, pos = Vector(0,0,0), ang = QAngle(0,0,0), keyvalues = {} )
{
	if ( typeof(upgrade) == "integer" )
	{
		if ( upgrade == 0 )
			upgrade = "upgrade_ammo_incendiary";
		else if ( upgrade == 1 )
			upgrade = "upgrade_ammo_explosive";
		else if ( upgrade == 2 )
			upgrade = "upgrade_laser_sight";
	}
	local t = { spawnflags = "2", };
	foreach (idx, val in t)
		keyvalues[idx] <- val;

	local ent = BotAI.CreateEntity(upgrade, pos, ang, keyvalues);
	if("__KeyValueFromInt" in ent)
		ent.__KeyValueFromInt("count", count);
	return ent;
}

::BotAI.doAmmoUpgrades <- function(p, func = false) {
	local amount = 4;
	if(BotAI.SurvivorList.len() > 4)
		amount = BotAI.SurvivorList.len();

	if(HasItem(p, "upgradepack_explosive")) {
		local inv = BotAI.GetHeldItems(p);
		if("slot3" in inv)
		{
			local it = inv["slot3"];
			it.Kill();
		}

		BotAI.SpawnUpgrade(1, amount, p.GetOrigin());
	}

	if(HasItem(p, "upgradepack_incendiary")) {
		local inv = BotAI.GetHeldItems(p);
		if("slot3" in inv)
		{
			local it = inv["slot3"];
			it.Kill();
		}

		BotAI.SpawnUpgrade(0, amount, p.GetOrigin());
	}
}

function BotAI::dropItem(p, str) {
	local wep = "";
	local dummyWep = "";
	local slot = "";
	local t = BotAI.GetHeldItems(p);

	if ( str != "" )
	{
		if ( (typeof str) == "integer" )
			slot = "slot" + str.tointeger();
		else
		{
			if ( str.find("weapon_") != null )
				wep = str;
			else
				wep = "weapon_" + str;
		}
	}
	else
	{
		if (p.GetActiveWeapon() != null )
			wep = p.GetActiveWeapon().GetClassname();
		else
			return false;
	}

	if ( slot != "" )
	{
		if (t && slot in t)
			wep = t[slot].GetClassname();
	}

	if ( wep == "weapon_pistol" || wep == "weapon_melee" || wep == "weapon_chainsaw" )
		dummyWep = "pistol_magnum";
	else if ( wep == "weapon_pistol_magnum" )
		dummyWep = "pistol";
	else if ( wep == "weapon_first_aid_kit" || wep == "weapon_upgradepack_incendiary" || wep == "weapon_upgradepack_explosive" )
		dummyWep = "defibrillator";
	else if ( wep == "weapon_defibrillator" )
		dummyWep = "first_aid_kit";
	else if ( wep == "weapon_pain_pills" )
		dummyWep = "adrenaline";
	else if ( wep == "weapon_adrenaline" )
		dummyWep = "pain_pills";
	else if ( wep == "weapon_pipe_bomb" || wep == "weapon_vomitjar" )
		dummyWep = "molotov";
	else if ( wep == "weapon_molotov" )
		dummyWep = "pipe_bomb";
	else if ( wep == "weapon_gascan" || wep == "weapon_propanetank" || wep == "weapon_oxygentank" || wep == "weapon_fireworkcrate" || wep == "weapon_cola_bottles" )
		dummyWep = "gnome";
	else if ( wep == "weapon_gnome" )
		dummyWep = "gascan";
	else if ( wep == "weapon_rifle" )
		dummyWep = "smg";
	else
		dummyWep = "rifle";

	if (t)
	{
		foreach (item in t)
		{
			if ( item.GetClassname() == wep )
			{
				p.GiveItem(dummyWep);
				BotAI.removeItem(p, dummyWep);
				DoEntFire("!self", "CancelCurrentScene", "", 0, null, p);
				item.Kill();
			}
		}
	}

	return true;
}

function BotAI::removeItem(p, itemname)
{
	local t = BotAI.GetHeldItems(p);

	if (t)
	{
		foreach (killitem in t)
		{
			if ( killitem.GetClassname() == itemname || killitem.GetClassname() == "weapon_" + itemname )
				killitem.Kill();
		}
	}
}

function BotAI::HasFlag(entity, flag )
{
	local flags = NetProps.GetPropInt(entity, "m_fFlags" );

	return flags == ( flags | flag );
}

/**
 * Adds the flag to the entity's current flags.
 */
function BotAI::AddFlag(entity, flag )
{
	local flags = NetProps.GetPropInt(entity, "m_fFlags" );

	if ( BotAI.HasFlag(entity, flag) )
		return;

	NetProps.SetPropInt(entity, "m_fFlags", ( flags | flag ) );
}

/**
 * Removes the flag from the entity's current flags.
 */
function BotAI::RemoveFlag(entity, flag )
{
	local flags = NetProps.GetPropInt(entity, "m_fFlags" );

	if ( !BotAI.HasFlag(entity, flag) )
		return;

	NetProps.SetPropInt(entity, "m_fFlags", ( flags & ~flag ) );
}

function BotAI::IsOnGround(entity) {
	return BotAI.HasFlag(entity, 1);
}

function BotAI::drawArrow(point0, point1, color, timeIn) {
	local dir = BotAI.normalize(point0 - point1);
	local finalPoint = point1 + dir.Scale(5);
	DebugDrawLine(point0 - dir.Scale(5), finalPoint, color.x, color.y, color.z, false, timeIn);
	local qDir = BotAI.CreateQAngle(dir.x, dir.y, dir.z);
	local lDir = QAngle(qDir.Pitch(), qDir.Yaw() + 30, 0);
	local rDir = QAngle(qDir.Pitch(), qDir.Yaw() - 30, 0);
	DebugDrawLine(finalPoint, finalPoint + lDir.Forward().Scale(15), color.x, color.y, color.z, false, timeIn);
	DebugDrawLine(finalPoint, finalPoint + rDir.Forward().Scale(15), color.x, color.y, color.z, false, timeIn);
}

function BotAI::printTable(table, valFunc = null, shouldPrint = null) {
	if(typeof table != "table") return;
	foreach(idx, val in table) {
		if(shouldPrint != null && (!shouldPrint(idx) || !shouldPrint(val)))
			continue;
		if(valFunc != null)
			printl("Idx: " + idx + " Val: " + valFunc(val));
		else
			printl("Idx: " + idx + " Val: " + val);
		BotAI.printTable(val, valFunc);
	}
}

function BotAI::printArray(arri, valFunc) {
	if(typeof arri != "array") return;
	foreach(idx, val in arri) {
		if(valFunc != null)
			printl("Idx: " + idx + " Val: " + valFunc(val));
		else
			printl("Idx: " + idx + " Val: " + val);
	}
}

function BotAI::hookViewEntity(ent_self, ent_b) {
	if(BotAI.isChargerWeaponLockout(ent_self))
		return;

	if(BotAI.IsEntityValid(ent_b)) {
		if (BotAI.BotDebugMode) {
			printl("player " + BotAI.getPlayerBaseName(ent_self) + " hook: " + ent_b);
		}

		//NetProps.SetPropEntity(ent_self, "m_viewtarget", ent_b);
	} else {
		//NetProps.SetPropInt(ent_self, "m_viewtarget", -1);
	}
}

function BotAI::getViewEntity(ent_self) {
	return NetProps.GetPropEntity(ent_self, "m_viewtarget");
}

function BotAI::getEntityHeadPos(ent_b) {
	if(!BotAI.IsEntityValid(ent_b)) {
		printl("[Bot AI DEBUG] ent_b not valid: " + ent_b);
		return;
	}

	local x = 0;
	local y = 0;
	local z = 0;

	if(ent_b.GetClassname() == "survivor_death_model") {
		x = ent_b.GetOrigin().x;
		y = ent_b.GetOrigin().y;
		z = ent_b.GetOrigin().z;
	} else if(ent_b.GetClassname() == "infected") {
		//ValveBiped.Bip01_Head1
		local bonePos = ent_b.GetBoneOrigin(14);

		x = bonePos.x;
		y = bonePos.y;
		z = bonePos.z;
	} else if(ent_b.GetClassname() == "player" && ent_b.GetZombieType() == 8) {
		x = ent_b.EyePosition().x;
		y = ent_b.EyePosition().y;
		z = ent_b.EyePosition().z;
	} else if("LookupAttachment" in ent_b ) {
		local attachId = ent_b.LookupAttachment("forward");
		local position = ent_b.GetAttachmentOrigin(attachId);

		x = position.x;
		y = position.y;
		z = position.z;
	} else {
		x = ent_b.GetCenter().x;
		y = ent_b.GetCenter().y;
		z = ent_b.GetCenter().z;
	}

	return Vector(x, y, z);
}

function BotAI::lookAtEntity(ent_self, ent_b, frozen = false, time = 1) {
	if(BotAI.isChargerWeaponLockout(ent_self)) {
		if(frozen && BotAI.IsEntityValid(ent_self))
			BotAI.RemoveFlag(ent_self, FL_FROZEN);
		return;
	}

	if(!BotAI.IsEntityValid(ent_b)) {
		printl("[Bot AI DEBUG] ent_b not valid: " + ent_b);
		return;
	}

	local headPos = BotAI.getEntityHeadPos(ent_b);

	if(BotAI.BotDebugMode) {
		DebugDrawBox(headPos, Vector(-10, -10, -10), Vector(10, 10, 10), 100, 255, 0, 0.2, 0.2);
		DebugDrawText(headPos, BotAI.getPlayerBaseName(ent_self) + " want me", false, 0.2);
	}

	if(ent_b == BotAI.getSmokerTarget(ent_self)) {
		local dirction = Vector(headPos.x - ent_self.EyePosition().x, headPos.y - ent_self.EyePosition().y, headPos.z - ent_self.EyePosition().z);
		local qAngleDirction = BotAI.CreateQAngle(dirction.x, dirction.y, dirction.z);
		ent_self.SnapEyeAngles(qAngleDirction);
		local eyeVec = QAngle(ent_self.EyeAngles().x + 55, ent_self.EyeAngles().y, 0);
		ent_self.SnapEyeAngles(eyeVec);

		BotAI.AddFlag( ent_self, FL_FROZEN );

		local function RemoveFlag(ent_) {
			if(BotAI.IsEntityValid(ent_))
				BotAI.RemoveFlag( ent_, FL_FROZEN );
		}

		::BotAI.Timers.AddTimerByName("hitTongue" + ent_self.GetEntityIndex(), 0.3, false, RemoveFlag, ent_self);
		return;
	}

	if((ent_b.GetClassname() == "infected" || ent_b.GetClassname() == "player") && "EyePosition" in ent_self) {
		if(frozen && BotAI.HasFlag(ent_self, FL_FROZEN))
			BotAI.RemoveFlag(ent_self, FL_FROZEN );

		local dirction = Vector(headPos.x - ent_self.EyePosition().x, headPos.y - ent_self.EyePosition().y, headPos.z - ent_self.EyePosition().z);
		local qAngleDirction = BotAI.CreateQAngle(dirction.x, dirction.y, dirction.z);

		ent_self.SnapEyeAngles(qAngleDirction);

		if(frozen) {
			BotAI.AddFlag(ent_self, FL_FROZEN );

			local function RemoveFlag(ent_) {
				if(ent_ != null)
					BotAI.RemoveFlag(ent_, FL_FROZEN );
			}

			::BotAI.Timers.AddTimerByName("RemoveFrozen" + ent_self.GetEntityIndex(), time, false, RemoveFlag, ent_self);
		}
	} else {
		BotAI.lookAtPosition(ent_self, headPos, frozen, time);
	}
}

function BotAI::lookAtPosition(player, vec, frozen = false, time = 1) {
	if(BotAI.isChargerWeaponLockout(player)) {
		if(frozen && BotAI.IsEntityValid(player))
			BotAI.RemoveFlag(player, FL_FROZEN);
		return;
	}

	if(frozen && BotAI.HasFlag(player, FL_FROZEN))
		BotAI.RemoveFlag(player, FL_FROZEN );

	if("SnapEyeAngles" in player) {
		player.SnapEyeAngles(BotAI.CreateQAngle(vec.x - player.EyePosition().x, vec.y - player.EyePosition().y, vec.z - player.EyePosition().z));
	}

	if(frozen) {
		BotAI.AddFlag(player, FL_FROZEN );

		local function RemoveFlag(ent_) {
			if(ent_ != null)
				BotAI.RemoveFlag(ent_, FL_FROZEN );
		}

		::BotAI.Timers.AddTimerByName("RemoveFrozen" + player.GetEntityIndex(), time, false, RemoveFlag, player);
	}
}

::BotAI.CreateQAngle <- function(x, y, z) {
	local yaw = (atan2(y, x) * 180 / PI);
	if (yaw < 0)
		yaw += 360;

		local tmp = sqrt (x * x + y * y);
		local pitch = (atan2(-z, tmp) * 180 / PI);
		if (pitch < 0)
			pitch += 360;

	if(x == 0 && y == 0){
		if (z > 0)
				pitch = 270;
			else
				pitch = 90;
	}

	return QAngle(pitch, yaw, 0);
}

function BotAI::tracePos(player, pos, onlyGround = false) {
	local traceTable = {
		start = player.EyePosition()
		end =  (pos - player.EyePosition()).Scale(100) + pos
		ignore = player
		mask = MASK_SOLID
	}
	TraceLine(traceTable);

	if(traceTable.hit) {
		if(onlyGround) return traceTable.pos;
		if(traceTable.enthit != null && (traceTable.pos - player.GetOrigin()).z < 57)
			return pos;

		return traceTable.pos;
	}
	return null;
}

function BotAI::GetHitPosition(player, distan, bol) {
	local m_trace = { start = player.EyePosition(), end = player.EyePosition() + player.EyeAngles().Forward().Scale(distan), ignore = player, mask = g_MapScript.TRACE_MASK_ALL};
	TraceLine(m_trace);

	if (!m_trace.hit || m_trace.enthit == null || m_trace.enthit == player)
		return null;

	if (m_trace.enthit.GetClassname() == "worldspawn" || !m_trace.enthit.IsValid())
		return null;

	if(bol) {
		if(m_trace.enthit.GetClassname() == "point_prop_use_target")
			return m_trace.pos;
		else
			return null;
	}

	return m_trace.pos;
}

function BotAI::IsEntityValid(_ent) {
	BotAI.debugCall("IsEntityValid");
	if (_ent == null)
		return false;

	if (!("IsValid" in _ent))
		return false;

	if (!_ent.IsValid())
		return false;

	return true;
}

function BotAI::shoveSpecialInfected(target, player) {
	target.Stagger(player.GetOrigin());
	if (BotAI.BotDebugMode) {
		DebugDrawBox(target.GetCenter(), Vector(-10, -10, -35), Vector(10, 10, 35), 0, 0, 255, 0.2, 0.5);
	}

	local function resetMoveType() {
		if(BotAI.getMoveType(target) == 2)
			return true;

		BotAI.setMoveType(target, 2);
		return false;
	}

	BotAI.conditionTimer(resetMoveType, 0.1);
}

function BotAI::spawnParticle(particleName, position, target = null) {
	local particle = g_ModeScript.CreateSingleSimpleEntityFromTable({ classname = "info_particle_system", targetname = "botai_tmp_" + UniqueString(), origin = position, angles = QAngle(0,0,0), start_active = true, effect_name = particleName });

	if (particle) {
		DoEntFire("!self", "Kill", "", 5, null, particle);
		DoEntFire("!self", "Start", "", 0, null, particle);
		particle.SetOrigin(position);
		if(target != null)
			DoEntFire("!self", "SetParent", "!activator", 0, particle, target);
	}
}

function BotAI::IsPlayerEntityValid(_ent)
{
	if(!BotAI.IsEntityValid(_ent))
		return false;

	if ("IsPlayer" in _ent)
		return _ent.IsPlayer();

	return false;
}

function BotAI::IsEntitySI(entity)
{
	if(BotAI.IsPlayerEntityValid(entity) && !entity.IsSurvivor() && BotAI.IsAlive(entity))
		return true;

	return false;
}

function BotAI::IsEntitySIBot(entity)
{
	if(BotAI.IsEntitySI(entity) && IsPlayerABot(entity))
		return true;

	return false;
}

function BotAI::IsEntitySurvivor(entity) {
	if(BotAI.IsPlayerEntityValid(entity) && entity.IsSurvivor() && BotAI.IsAlive(entity))
		return true;

	return false;
}

function BotAI::Laugh(player) {
	if(BotAI.IsEntitySurvivor(player)) {
		DoEntFire("!self", "SpeakResponseConcept", "PlayerLaugh", 0, null, player);
	}
}

function BotAI::IsEntitySurvivorBot(entity)
{
	if(BotAI.IsEntitySurvivor(entity) && IsPlayerABot(entity))
		return true;

	return false;
}

function BotAI::isTakingItem(player, str) {
	local weapon = player.GetActiveWeapon();

	if (weapon != null && (weapon.GetClassname() == str || weapon.GetClassname() == "weapon_" + str)) {
		return true;
	}

	return false;
}

function BotAI::HasItem(player, str, t = null) {
	if(player in BotAI.BotLinkGasCan) {
		local gas = BotLinkGasCan[player];
		if(BotAI.IsEntityValid(gas) && gas.GetOwnerEntity() == null && gas.GetClassname() == str)
			return true;
	}

	if (t == null) {
		t = BotAI.GetHeldItems(player);
	}

	if (t) {
		foreach (item in t) {
			if ( item.GetClassname() == str || item.GetClassname() == "weapon_" + str )
				return true;
		}
	}

	return false;
}

//void GetInvTable(CTerrorPLayer player, table invTable)
//GetInvTable is a danger function, the first param if it's not CTerrorPLayer or it's null, game crashes
function BotAI::GetHeldItems(player) {
	local t = {};
	if(!BotAI.IsEntitySurvivor(player)) return t;
	local table = {};
	GetInvTable(player, table);

	foreach( slot, item in table )
		t[slot] <- item;

	return t;
}

function BotAI::isEntitySP(entity)
{
	if(BotAI.IsEntityValid(entity) && entity.GetClassname() == "player" && !entity.IsSurvivor())
		return true;

	if(BotAI.IsEntityValid(entity) && entity.GetClassname() == "witch" )
		return true;

	return false;
}

function BotAI::isEntityInfected(entity)
{
	if(BotAI.IsEntityValid(entity) && entity.GetClassname() == "infected")
		return true;

	return false;
}

::BotAI.IsAlive <- function(_ent) {
	if(!BotAI.IsEntityValid(_ent))
		return false;

	if("GetSequenceName" in _ent) {
		local sequenceName = _ent.GetSequenceName(_ent.GetSequence()).tolower();
		if(sequenceName.find("death") != null && !(BotAI.IsPlayerEntityValid(_ent) && _ent.IsSurvivor())) {
			return false;
		}
	}

	if ( _ent.GetClassname() == "infected" || _ent.GetClassname() == "witch" || _ent.GetClassname() == "player" ) {
		return NetProps.GetPropInt(_ent, "m_lifeState" ) == 0;
	} else {
		return _ent.GetHealth() > 0;
	}
}

::BotAI.IsLivingEntity <- function(_ent) {
	if(!BotAI.IsEntityValid(_ent))
		return false;

	return _ent.GetClassname() == "infected" || _ent.GetClassname() == "witch" || _ent.GetClassname() == "player";
}

function BotAI::getSeverLanguage() {
	if (!IsDedicatedServer() && !BotAI.ServerMode) {
		local ccLang = Convars.GetStr("cc_lang").tostring();
        if (ccLang == "") {
            return Convars.GetStr("cl_language").tostring();
        }
        return ccLang;
	} else {
		return BotAI.ServerLanguage.tostring();
	}
}

function BotAI::CanHumanSeePlace(posIn) {
	foreach(sur in BotAI.SurvivorHumanList) {
		if(BotAI.IsAlive(sur) && BotAI.VectorDotProduct(BotAI.normalize(sur.EyeAngles().Forward()), BotAI.normalize(posIn - sur.GetOrigin())) > 0)
			return true;
	}
	return false;
}

function BotAI::applyDamage(owner, target, amount) {
	if (BotAI.IsAlive(target) || amount <= 0) {
		local inflictor = owner;
		local weaponType = owner.GetActiveWeapon().GetClassname();
		local damagepos = null;
		local damageType = BotAI.headshotDmg;

		if(weaponType == "weapon_chainsaw" || weaponType == "weapon_melee") {
			inflictor = owner.GetActiveWeapon();
			damageType = BotAI.meleeDmg;
			damagepos = BotAI.getEntityHeadPos(owner);
			damagepos = Vector(damagepos.x, damagepos.y, owner.EyePosition().z);

			if (target.GetClassname() == "witch") {
				damageType = BotAI.witchMeleeDmg;
			} else {
				damageType = BotAI.meleeDmg;
			}
		} else {
			damagepos = BotAI.getEntityHeadPos(target);
		}

		target.TakeDamageEx(inflictor, owner, owner.GetActiveWeapon(), Vector(0, 0, 0), damagepos, amount, damageType);
	}
}

function BotAI::applyDamageEx(owner, target, amount, damageType, damagepos = null) {
	if (damagepos == null) {
		damagepos = BotAI.getEntityHeadPos(target);
	}

	if (BotAI.IsAlive(target) || amount <= 0) {
		local inflictor = owner;
		local weaponType = owner.GetActiveWeapon().GetClassname();
		local weapon = owner.GetActiveWeapon();

		if(weaponType == "weapon_chainsaw" || weaponType == "weapon_melee") {
			inflictor = owner.GetActiveWeapon();

			if (target.GetClassname() == "witch") {
				damageType = BotAI.witchMeleeDmg;
			} else {
				damageType = BotAI.meleeDmg;
			}
		}

		target.TakeDamageEx(inflictor, owner, weapon, Vector(0, 0, 0), damagepos, amount, damageType);
	}
}

function BotAI::IsInCombat(player, commonOnly = false) {
	if(!BotAI.IsPlayerEntityValid(player)) return false;

	local map = BotAI.getBotPropertyMap(player);

	if(map != null) {
		if (commonOnly) {
			return BotAI.IsAlive(map.combatCommon);
		} else {
			return BotAI.IsAlive(map.combatSpecial) || BotAI.IsAlive(map.combatCommon);
		}
	}

	return false;
}

function BotAI::getEntityAimPoint(entity) {
	if(!BotAI.IsEntityValid(entity))
		return Vector(0, 0, 0);

	if("EyePosition" in entity)
		return entity.EyePosition();

	if("GetBoneOrigin" in entity) {
		try { return entity.GetBoneOrigin(14); } catch(e) {}
	}

	return entity.GetOrigin() + Vector(0, 0, 45);
}

function BotAI::hasLineToEntity(viewer, target, mask = null) {
	if(!BotAI.IsEntityValid(viewer) || !BotAI.IsEntityValid(target))
		return false;

	if(mask == null)
		mask = g_MapScript.TRACE_MASK_SHOT;

	local trace = {
		start = ("EyePosition" in viewer) ? viewer.EyePosition() : viewer.GetOrigin() + Vector(0, 0, 62)
		end = BotAI.getEntityAimPoint(target)
		ignore = viewer
		mask = mask
	};
	TraceLine(trace);

	if(trace.hit && trace.enthit == target)
		return true;

	return false;
}

function BotAI::humanCanShareThreat(human, target, maxDistance = 1600, minDot = 0.35) {
	if(!BotAI.IsEntitySurvivor(human) || !BotAI.IsEntityValid(target))
		return false;

	local pos = BotAI.getEntityAimPoint(target);
	local toTarget = pos - human.EyePosition();
	local dist = toTarget.Length();
	if(dist <= 1.0 || dist > maxDistance)
		return false;

	if(human.EyeAngles().Forward().Dot(BotAI.normalize(toTarget)) < minDot)
		return false;

	return BotAI.hasLineToEntity(human, target);
}

function BotAI::updateSharedVisionTargets() {
	local now = Time();
	if("SharedVisionNextScan" in BotAI && now < BotAI.SharedVisionNextScan)
		return;

	BotAI.SharedVisionNextScan = now + 0.33;

	foreach(idx, data in BotAI.SharedVisionTargets) {
		if(!("until" in data) || now >= data.until || !("target" in data) || !BotAI.IsAlive(data.target))
			delete BotAI.SharedVisionTargets[idx];
	}

	foreach(human in BotAI.SurvivorHumanList) {
		if(!BotAI.IsEntitySurvivor(human) || human.IsIncapacitated() || human.IsHangingFromLedge())
			continue;

		foreach(_, si in BotAI.SpecialList) {
			if(!BotAI.IsAlive(si) || si.IsGhost() || si.IsSurvivor() || si.GetZombieType() == 7)
				continue;
			if(!BotAI.humanCanShareThreat(human, si, 1900, 0.15))
				continue;

			local priority = 3;
			local victim = BotAI.getSiVictim(si);
			if(BotAI.IsEntityValid(victim))
				priority = 5;
			else if(BotAI.GetTarget(si) == human)
				priority = 4;
			else if(si.GetZombieType() == 5)
				priority = 4;
			else if(si.GetZombieType() == 8)
				priority = 2;

			local data = {
				target = si
				owner = human
				priority = priority
				until = now + 1.1
				botRange = si.GetZombieType() == 5 ? 1900.0 : 1700.0
			};
			if(si.GetEntityIndex() in BotAI.SharedVisionTargets)
				BotAI.SharedVisionTargets[si.GetEntityIndex()] = data;
			else
				BotAI.SharedVisionTargets[si.GetEntityIndex()] <- data;
		}

		local witch = null;
		while(witch = Entities.FindByClassnameWithin(witch, "witch", human.GetOrigin(), 1500)) {
			if(!BotAI.IsAlive(witch) || !BotAI.humanCanShareThreat(human, witch, 1500, 0.35))
				continue;
			if(!(BotAI.witchKilling(witch) || (BotAI.witchRunning(witch) && !BotAI.witchRetreat(witch))))
				continue;

			local data = {
				target = witch
				owner = human
				priority = 3
				until = now + 1.1
				botRange = 1300.0
			};
			if(witch.GetEntityIndex() in BotAI.SharedVisionTargets)
				BotAI.SharedVisionTargets[witch.GetEntityIndex()] = data;
			else
				BotAI.SharedVisionTargets[witch.GetEntityIndex()] <- data;
		}
	}
}

function BotAI::isBotAvailableForAssist(bot) {
	if(!BotAI.IsEntitySurvivorBot(bot))
		return false;
	if(bot.IsDominatedBySpecialInfected() || bot.IsStaggering() || bot.IsIncapacitated() || bot.IsHangingFromLedge())
		return false;
	if(BotAI.IsPlayerClimb(bot) || BotAI.IsBotHealing(bot) || BotAI.isChargerWeaponLockout(bot))
		return false;
	local area = bot.GetLastKnownArea();
	if(area != null && area.IsDamaging())
		return false;
	return true;
}

function BotAI::findHumanCrowdAssistTargets() {
	local result = {};
	foreach(human in BotAI.SurvivorHumanList) {
		if(!BotAI.IsEntitySurvivor(human) || human.IsIncapacitated() || human.IsHangingFromLedge() || human.IsDominatedBySpecialInfected())
			continue;

		local count = 0;
		local nearest = null;
		local nearestDis = 999999.0;
		local infected = null;
		while(infected = Entities.FindByClassnameWithin(infected, "infected", human.GetCenter(), 360)) {
			if(!BotAI.IsAlive(infected))
				continue;
			local dis = BotAI.distanceof(human.GetOrigin(), infected.GetOrigin());
			count++;
			if(dis < nearestDis && BotAI.hasLineToEntity(human, infected)) {
				nearestDis = dis;
				nearest = infected;
			}
		}

		if(count < 6 || !BotAI.IsAlive(nearest))
			continue;

		local need = 1;
		if(count >= 14)
			need = 3;
		else if(count >= 9)
			need = 2;

		result[human.GetEntityIndex()] <- {
			target = human
			infected = nearest
			count = count
			need = need
			assigned = 0
		};
	}

	return result;
}

function BotAI::getManualMedicalItem(player, kind) {
	if(!BotAI.IsEntitySurvivor(player))
		return null;

	local inv = BotAI.GetHeldItems(player);
	if(kind == "kit") {
		if("slot3" in inv && inv["slot3"].GetClassname() == "weapon_first_aid_kit")
			return inv["slot3"];
		return null;
	}

	if(kind == "pills") {
		if("slot4" in inv && inv["slot4"].GetClassname() == "weapon_pain_pills")
			return inv["slot4"];
		return null;
	}

	if(kind == "adrenaline") {
		if("slot4" in inv && inv["slot4"].GetClassname() == "weapon_adrenaline")
			return inv["slot4"];
		return null;
	}

	return null;
}

function BotAI::manualMedicalHasItem(player, kind) {
	return BotAI.IsEntityValid(BotAI.getManualMedicalItem(player, kind));
}

function BotAI::isManualKitHealing(player) {
	if(!BotAI.IsEntitySurvivorBot(player))
		return false;
	if(!(player in BotAI.ManualMedical))
		return false;

	local data = BotAI.ManualMedical[player];
	return "kind" in data && data.kind == "kit";
}

function BotAI::shouldPauseManualKit(player) {
	if(!BotAI.isManualKitHealing(player))
		return false;
	if(BotAI.HasTank || BotAI.isChargerWeaponLockout(player))
		return true;
	try {
		if(player.IsDominatedBySpecialInfected() || player.IsIncapacitated() || player.IsHangingFromLedge() || player.IsStaggering())
			return true;
	} catch(e0) {}

	local area = player.GetLastKnownArea();
	if(area != null && area.IsDamaging())
		return true;

	try {
		player.ValidateScriptScope();
		local fs = player.GetScriptScope();
		if("_acid_evac_active" in fs)
			return true;
		if("_acid_evac_pre_only" in fs)
			return true;
		if("_acid_damage_forced_until" in fs && fs._acid_damage_forced_until > Time())
			return true;
		if("_aba_spitter_own_until" in fs && fs._aba_spitter_own_until > Time())
			return true;
	} catch(e) {}

	return false;
}

function BotAI::protectManualKitAction(player, holdTime = 0.5) {
	if(!BotAI.isManualKitHealing(player))
		return false;
	if(BotAI.shouldPauseManualKit(player)) {
		BotAI.RemoveFlag(player, FL_FROZEN);
		BotAI.ClearForcedButton(player, 1);
		return false;
	}

	local item = BotAI.getManualMedicalItem(player, "kit");
	if(!BotAI.IsEntityValid(item))
		return false;

	if(player.GetActiveWeapon() == null || player.GetActiveWeapon().GetClassname() != "weapon_first_aid_kit")
		player.SwitchToItem("weapon_first_aid_kit");

	local active = player.GetActiveWeapon();
	if(BotAI.IsEntityValid(active) && active.GetClassname() == "weapon_first_aid_kit")
		NetProps.SetPropFloat(active, "m_flNextPrimaryAttack", Time() - 1);

	BotAI.AddFlag(player, FL_FROZEN);
	BotAI.setBotTarget(player, null);
	BotAI.setBotShoveTarget(player, null);
	BotAI.UnforceButton(player, 2048);
	BotAI.RefreshForceButton(player, 1, holdTime, false);
	return true;
}

function BotAI::startManualMedical(bot, kind, owner = null) {
	if(!BotAI.IsEntitySurvivorBot(bot))
		return false;
	if(!BotAI.manualMedicalHasItem(bot, kind))
		return false;

	if(bot in BotAI.ManualMedical && "kind" in BotAI.ManualMedical[bot] && BotAI.ManualMedical[bot].kind == kind) {
		BotAI.cancelManualMedical(bot);
		return false;
	}

	BotAI.cancelManualMedical(bot);
	BotAI.cancelManualUse(bot);
	if(bot in BotAI.ManualLead)
		BotAI.stopManualLead(bot);

	BotAI.ManualMedical[bot] <- {
		kind = kind
		owner = owner
		start = Time()
		until = Time() + ((kind == "kit") ? 12.0 : 5.0)
		started = false
	};

	return true;
}

function BotAI::cancelManualMedical(bot) {
	if(bot in BotAI.ManualMedical)
		delete BotAI.ManualMedical[bot];
	if(BotAI.IsEntityValid(bot)) {
		BotAI.RemoveFlag(bot, FL_FROZEN);
		BotAI.ClearForcedButton(bot, 1);
	}
}

function BotAI::startManualUse(bot, entity, pos, owner = null) {
	if(!BotAI.IsEntitySurvivorBot(bot))
		return false;

	if(typeof pos != "Vector") {
		if(BotAI.IsEntityValid(entity))
			pos = entity.GetOrigin();
		else
			return false;
	}

	if(!BotAI.IsEntityValid(entity)) {
		entity = BotAI.findUsableTriggerNear(pos, 220);
	} else if(!BotAI.isUsableTriggerEntity(entity) || !BotAI.IsTriggerUsable(entity)) {
		local nearby = BotAI.findUsableTriggerNear(pos, 220);
		if(BotAI.IsEntityValid(nearby))
			entity = nearby;
	}

	if(bot in BotAI.ManualUse && BotAI.isSameManualUseCommand(bot, entity, pos)) {
		BotAI.cancelManualUse(bot);
		return false;
	}

	BotAI.cancelManualMedical(bot);
	BotAI.cancelManualUse(bot);
	if(bot in BotAI.ManualLead)
		BotAI.stopManualLead(bot);

	BotAI.ManualUse[bot] <- {
		entity = entity
		pos = pos
		owner = owner
		start = Time()
		until = Time() + 45.0
		validated = false
		validateTime = 0.0
		tapUntil = Time() + 1.0
		holdStarted = false
	};

	return true;
}

function BotAI::isSameManualUseCommand(bot, entity, pos) {
	if(!(bot in BotAI.ManualUse))
		return false;

	local data = BotAI.ManualUse[bot];
	if(BotAI.IsEntityValid(entity) && BotAI.IsEntityValid(data.entity))
		return entity == data.entity;

	if(typeof pos == "Vector" && typeof data.pos == "Vector")
		return BotAI.distanceof(pos, data.pos) <= 45;

	return false;
}

function BotAI::isManualUseActive(player) {
	if(!BotAI.IsEntitySurvivorBot(player))
		return false;
	return player in BotAI.ManualUse;
}

function BotAI::isManualUseHolding(player) {
	if(!BotAI.isManualUseActive(player))
		return false;

	local data = BotAI.ManualUse[player];
	if("holdStarted" in data && data.holdStarted)
		return true;
	return "validated" in data && data.validated;
}

function BotAI::shouldPauseManualUse(player) {
	if(!BotAI.isManualUseActive(player))
		return false;
	if(BotAI.HasTank || BotAI.isChargerWeaponLockout(player))
		return true;
	try {
		if(player.IsDominatedBySpecialInfected() || player.IsIncapacitated() || player.IsHangingFromLedge() || player.IsStaggering())
			return true;
	} catch(e0) {}

	local area = player.GetLastKnownArea();
	if(area != null && area.IsDamaging())
		return true;

	try {
		player.ValidateScriptScope();
		local fs = player.GetScriptScope();
		if("_acid_evac_active" in fs)
			return true;
		if("_acid_evac_pre_only" in fs)
			return true;
		if("_acid_damage_forced_until" in fs && fs._acid_damage_forced_until > Time())
			return true;
		if("_aba_spitter_own_until" in fs && fs._aba_spitter_own_until > Time())
			return true;
	} catch(e) {}

	return false;
}

function BotAI::findUsableTriggerNear(pos, radius = 220) {
	local best = null;
	local bestDis = radius;
	local classes = ["func_button_timed", "func_button", "trigger_finale"];
	foreach(cls in classes) {
		local ent = null;
		while(ent = Entities.FindByClassnameWithin(ent, cls, pos, radius)) {
			if(!BotAI.IsEntityValid(ent))
				continue;
			if(!BotAI.IsTriggerUsable(ent))
				continue;
			local dis = BotAI.distanceof(pos, ent.GetOrigin());
			if(dis < bestDis) {
				bestDis = dis;
				best = ent;
			}
		}
	}

	return best;
}

function BotAI::cancelManualUse(bot) {
	if(bot in BotAI.ManualUse)
		delete BotAI.ManualUse[bot];
	if(BotAI.IsEntityValid(bot)) {
		BotAI.ClearForcedButton(bot, 32);
		local nav = BotAI.getNavigator(bot);
		nav.clearPath("manualUse$");
	}
}

function BotAI::IsNearStartingArea(player)
{
	if(BotAI.StartPos == null)
		return;
	local endVec = player.GetOrigin();

	return BotAI.distanceof(BotAI.StartPos, endVec) < 600;
}

function BotAI::IsPressingAttack(_ent)
{
	if(!BotAI.IsAlive(_ent)) return false;
	return (_ent.GetButtonMask() & (1 << 0)) > 0;
}

function BotAI::IsPressingJump(_ent)
{
	if(!BotAI.IsAlive(_ent)) return false;
	return (_ent.GetButtonMask() & (1 << 1)) > 0;
}

function BotAI::IsPressingDuck(_ent)
{
	if(!BotAI.IsAlive(_ent)) return false;
	return (_ent.GetButtonMask() & (1 << 2)) > 0;
}

function BotAI::IsPressingUse(_ent)
{
	if(!BotAI.IsAlive(_ent)) return false;
	return (_ent.GetButtonMask() & (1 << 5)) > 0;
}

function BotAI::IsPressingReload(_ent)
{
	if(!BotAI.IsAlive(_ent)) return false;
	return (_ent.GetButtonMask() & (1 << 13)) > 0;
}

function BotAI::IsPressingShove(_ent) {
	if(!BotAI.IsAlive(_ent)) return false;
	return (_ent.GetButtonMask() & (1 << 11)) > 0;
}

function BotAI::isPressingAlt(ent) {
	if(!BotAI.IsAlive(ent)) return false;
	return (ent.GetButtonMask() & 0x8000) > 0;
}

function BotAI::IsPressingForward(_ent)
{
	if(!BotAI.IsAlive(_ent)) return false;
	return (_ent.GetButtonMask() & (1 << 3)) > 0;
}

function BotAI::IsPressingBackward(_ent)
{
	if(!BotAI.IsAlive(_ent)) return false;
	return (_ent.GetButtonMask() & (1 << 4)) > 0;
}

function BotAI::IsPressingLeft(_ent)
{
	if(!BotAI.IsAlive(_ent)) return false;
	return (_ent.GetButtonMask() & (1 << 9)) > 0;
}

function BotAI::IsPressingRight(ent) {
	if(!BotAI.IsAlive(ent)) return false;
	return (ent.GetButtonMask() & (1 << 10)) > 0;
}

function BotAI::VectorDotProduct(a, b)
{
	return (a.x * b.x) + (a.y * b.y) + (a.z * b.z);
}

function BotAI::VectorFromQAngle(angles, radius = 1.0)
{
	local function ToRad(angle)
	{
		return (angle * PI) / 180;
	}

	local yaw = ToRad(angles.Yaw());
	local pitch = ToRad(-angles.Pitch());

	local x = radius * cos(yaw) * cos(pitch);
	local y = radius * sin(yaw) * cos(pitch);
	local z = radius * sin(pitch);

	return Vector(x, y, z);
}

function BotAI::IsOnFire(_ent) {
	if (!BotAI.IsEntityValid(_ent)) {
		return false;
	}

	if ( _ent.GetClassname() == "infected" || _ent.GetClassname() == "witch" )
		return NetProps.GetPropInt(	_ent, "m_bIsBurning" ) > 0 ? true : false;
	else if ( _ent.GetClassname() == "player" )
		return _ent.IsOnFire();
	else
		return false;
}

function BotAI::IsSurvivorTrapped(_ent) {
	if (!BotAI.IsPlayerEntityValid(_ent)) {
		return false;
	}
	return _ent.IsDominatedBySpecialInfected();

	if(!(_ent.GetEntityIndex() in BotAI.SurvivorTrapped))
		return false;

	return BotAI.SurvivorTrapped[_ent.GetEntityIndex()] != null;
}

function BotAI::IsSurvivorTrappedTimed(_ent) {
	if (!BotAI.IsEntityValid(_ent))
	{
		return false;
	}

	if(!(_ent.GetEntityIndex() in BotAI.SurvivorTrappedTimed))
		return false;

	return BotAI.SurvivorTrappedTimed[_ent.GetEntityIndex()] != null;
}

function BotAI::CreateEntity(_classname, pos = Vector(0,0,0), ang = QAngle(0,0,0), kvs = {})
{
	kvs.classname <- _classname;
	kvs.origin <- pos;
	kvs.angles <- ang;

	local ent = g_ModeScript.CreateSingleSimpleEntityFromTable(kvs);

	if (!ent)
		return null;

	ent.ValidateScriptScope();

	return ent;
}

function BotAI::SetBotGasFinding(player, level) {
	//BotAI.GasFinding[player.GetEntityIndex()] <- level;
}

function BotAI::IsBotGasFinding(player) {
	return false;
	if(!BotAI.IsEntityValid(player))
		return false;
	if(player in BotAI.moveDebug && BotAI.moveDebug[player])
		return true;
	if(player.GetEntityIndex() in BotAI.GasFinding && BotAI.GasFinding[player.GetEntityIndex()] > 0)
		return true;
	return false;
}

function BotAI::getBotGasFinding(player) {
	if(!BotAI.IsEntityValid(player))
		return 0;
	if(player.GetEntityIndex() in BotAI.GasFinding)
		return BotAI.GasFinding[player.GetEntityIndex()];
	return 0;
}

::BotAI.CanSeeLocation <- function(player, otherEntity, tolerance = 50) {
	if (!player.IsValid()) {
		return false;
	}

	local clientPos = player.GetOrigin();
	if("EyePosition" in player)
		clientPos = player.EyePosition();
	else
		clientPos += Vector(0, 0, 62);

	local clientToTargetVec = otherEntity - clientPos;
	local clientAimVector = Vector(0, 0, 0);
	if("EyeAngles" in player)
		clientAimVector = player.EyeAngles().Forward();
	else if("GetForwardVector" in player)
		clientAimVector = player.GetForwardVector();

	local angToFind = acos(BotAI.VectorDotProduct(clientAimVector, clientToTargetVec) / (clientAimVector.Length() * clientToTargetVec.Length())) * 360 / 2 / 3.14159265;

	if (angToFind >= tolerance)
		return false;
	else
		return true;
}

::BotAI.CanSeeOtherEntity <- function(player, otherEntity, tolerance = 50, seeBarrier = false)
{
	BotAI.debugCall("CanSeeOtherEntity");
	if (!player.IsValid() || !otherEntity.IsValid())
	{
		return false;
	}

	local clientPos = player.GetOrigin();
	if("EyePosition" in player)
		clientPos = player.EyePosition();
	else
		clientPos += Vector(0, 0, 62);

	local clientToTargetVec = otherEntity.GetOrigin() - clientPos;
	local clientAimVector = Vector(0, 0, 0);
	if("EyeAngles" in player)
		clientAimVector = player.EyeAngles().Forward();
	else if("GetForwardVector" in player)
		clientAimVector = player.GetForwardVector();

	local angToFind = acos(BotAI.VectorDotProduct(clientAimVector, clientToTargetVec) / (clientAimVector.Length() * clientToTargetVec.Length())) * 360 / 2 / 3.14159265;

	if (angToFind >= tolerance)
		return false;
	else if(!seeBarrier)
		return true;
	else
	{
		local endVec = otherEntity.GetOrigin();
		local startVec = player.GetOrigin();

		if("EyePosition" in otherEntity)
			endVec = otherEntity.EyePosition();
		if("EyePosition" in player)
			startVec = player.EyePosition();

		local m_trace = { start = startVec, end = endVec, ignore = player};
		TraceLine(m_trace);

		if (!m_trace.hit || m_trace.enthit == null || m_trace.enthit == player)
			return false;

		if (m_trace.enthit.GetClassname() == "worldspawn" || !m_trace.enthit.IsValid())
			return false;

		if (m_trace.enthit == otherEntity)
			return true;

		return false;
	}
}

function BotAI::CanSeeOtherEntityWithoutBarrier(player, otherEntity, tolerance = 50, MaskSet = null) {
	local clientPos = player.EyePosition();
	local clientToTargetVec = otherEntity.GetOrigin() - clientPos;
	local clientAimVector = player.EyeAngles().Forward();

	local angToFind = acos(BotAI.VectorDotProduct(clientAimVector, clientToTargetVec) / (clientAimVector.Length() * clientToTargetVec.Length())) * 360 / 2 / 3.14159265;

	if (angToFind > tolerance)
		return false;

	if(MaskSet == null)
		MaskSet = MASK_UNTHROUGHABLE;

	// Next check to make sure it's not behind a wall or something
	local m_trace = { start = player.EyePosition(), end = otherEntity.GetOrigin(), ignore = player, mask = MaskSet};
	TraceLine(m_trace);

	local mT = true;

	if (!m_trace.hit || m_trace.enthit == null || m_trace.enthit == player)
		mT = false;

	if (mT && (m_trace.enthit.GetClassname() == "worldspawn" || !m_trace.enthit.IsValid()))
		mT = false;

	if (mT && m_trace.enthit == otherEntity)
		return true;

	if ("EyePosition" in otherEntity) {
		local n_trace = { start = player.EyePosition(), end = otherEntity.EyePosition(), ignore = player, mask = MaskSet};
		TraceLine(n_trace);

		local nT = true;

		if (!n_trace.hit || n_trace.enthit == null || n_trace.enthit == player)
			nT = false;

		if (nT && (n_trace.enthit.GetClassname() == "worldspawn" || !n_trace.enthit.IsValid()))
			nT = false;

		if (nT && n_trace.enthit == otherEntity)
			return true;
	} else if ("GetBoneOrigin" in otherEntity) {
		local n_trace = { start = player.EyePosition(), end = otherEntity.GetBoneOrigin(14), ignore = player, mask = MaskSet};
		TraceLine(n_trace);

		local nT = true;

		if (!n_trace.hit || n_trace.enthit == null || n_trace.enthit == player)
			nT = false;

		if (nT && (n_trace.enthit.GetClassname() == "worldspawn" || !n_trace.enthit.IsValid()))
			nT = false;

		if (nT && n_trace.enthit == otherEntity)
			return true;
	}

	return false;
}

function BotAI::CanShotOtherEntityInSight(player, otherEntity, angle = -1, _mask = g_MapScript.TRACE_MASK_SHOT) {
	if (!BotAI.IsPlayerEntityValid(player)) return false;

	local eyevec = otherEntity.GetOrigin() + Vector(0, 0, 50);

	if("EyePosition" in otherEntity) {
		eyevec = otherEntity.EyePosition();
	} else if("GetBoneOrigin" in otherEntity) {
		eyevec = otherEntity.GetBoneOrigin(14);
	}

	if (BotAI.VectorDotProduct(BotAI.normalize(eyevec - player.EyePosition()), player.EyeAngles().Forward()) < angle) {
		return false;
	}

	local mpHit = true;

	local mp_trace = { start = player.EyePosition(), end = eyevec, ignore = player, mask = _mask};
	TraceLine(mp_trace);

	if (!mp_trace.hit || mp_trace.enthit == null || mp_trace.enthit == player)
		mpHit = false;

	if(mpHit && mp_trace.enthit == otherEntity) {
		return true;
	}

	local npHit = true;

	local np_trace = { start = eyevec, end = player.EyePosition(), ignore = otherEntity, mask = _mask};
	TraceLine(np_trace);

	if (!np_trace.hit || np_trace.enthit == null || np_trace.enthit == otherEntity)
		npHit = false;

	if(npHit && np_trace.enthit == player) {
		return true;
	}

	return false;
}

function BotAI::CanHitOtherEntity(molotov, tank, _mask = null) {
	if(_mask == null)
		_mask = MASK_UNTHROUGHABLE;

	local m_trace = { start = molotov.GetOrigin(), end = tank.EyePosition(), ignore = molotov, mask = _mask};
	TraceLine(m_trace);

	if (!m_trace.hit || m_trace.enthit == null || m_trace.enthit == molotov)
		return false;

	if (m_trace.enthit == tank)
		return true;

	return false;
}

function BotAI::witchKilling(witch) {
	if(witch.GetSequenceName(witch.GetSequence()).tolower().find("killing") != null)
		return true;
	return false;
}

function BotAI::witchRetreat(witch) {
	if(witch.GetSequenceName(witch.GetSequence()).tolower().find("retreat") != null)
		return true;
	return false;
}

function BotAI::witchAngry(witch) {
	if(witch.GetSequenceName(witch.GetSequence()).tolower().find("agitated") != null)
		return true;
	return false;
}

function BotAI::witchRunning(witch) {
	if(witch.GetSequenceName(witch.GetSequence()).tolower().find("run") != null)
		return true;
	return false;
}

function BotAI::CanSeeOtherEntityPrintName(player, distan = 999999, pri = 1, trace_mask = g_MapScript.TRACE_MASK_SHOT) {
	local m_trace = { start = player.EyePosition(), end = player.EyePosition() + player.EyeAngles().Forward().Scale(distan), ignore = player, mask = trace_mask};
	TraceLine(m_trace);

	if (!m_trace.hit || m_trace.enthit == null || m_trace.enthit == player) {
		if(pri == 1 && m_trace.enthit == player)
			printl("[Bot AI DEBUG] PLAYER_SELF ");
		return null;
	}

	if (m_trace.enthit.GetClassname() == "worldspawn" || !m_trace.enthit.IsValid())
		return null;

	if(pri == 1) {
		DumpObject(m_trace.enthit);
		printl("[Bot AI DEBUG] Name: " + m_trace.enthit.GetClassname());
		printl("[Bot AI DEBUG] ModelName: " + m_trace.enthit.GetModelName());
		printl("[Bot AI DEBUG] MoveType: " + BotAI.getMoveType(m_trace.enthit));
		printl("[Bot AI DEBUG] m_hOwnerEntity: " + NetProps.GetPropEntity(m_trace.enthit, "m_hOwnerEntity"));
		printl("[Bot AI DEBUG] m_hOwner: " + NetProps.GetPropEntity(m_trace.enthit, "m_hOwner"));

		if(m_trace.enthit.GetClassname() == "player") {
			printl("[Bot AI DEBUG] Weapon: " + (m_trace.enthit.GetActiveWeapon() == null ? "None" : m_trace.enthit.GetActiveWeapon().GetClassname()));
			if (m_trace.enthit.GetZombieType() == 1) {
				printl("[Bot AI DEBUG] m_duration: " + NetProps.GetPropFloat(NetProps.GetPropEntity(m_trace.enthit, "m_customAbility"), "m_nextActivationTimer.m_duration"));
				printl("[Bot AI DEBUG] m_timestamp: " + NetProps.GetPropFloat(NetProps.GetPropEntity(m_trace.enthit, "m_customAbility"), "m_nextActivationTimer.m_timestamp"));
				printl("[Bot AI DEBUG] m_tongueState: " + NetProps.GetPropInt(NetProps.GetPropEntity(m_trace.enthit, "m_customAbility"), "m_tongueState"));
				printl("[Bot AI DEBUG] m_tongueGrabStartingHealth: " + NetProps.GetPropInt(NetProps.GetPropEntity(m_trace.enthit, "m_customAbility"), "m_tongueGrabStartingHealth"));
				printl("[Bot AI DEBUG] Time(): " + Time());
			}

			printl("[Bot AI DEBUG] IsDominatedBySpecialInfected: " + m_trace.enthit.IsDominatedBySpecialInfected());
			printl("[Bot AI DEBUG] GetSpecialInfectedDominatingMe: " + m_trace.enthit.GetSpecialInfectedDominatingMe());
			printl("[Bot AI DEBUG] SI Victim: " + BotAI.getSiVictim(m_trace.enthit));

			if (IsPlayerABot(m_trace.enthit)) {
				local target = BotAI.getBotTarget(m_trace.enthit);
				printl("[Bot AI DEBUG] Bot Target: " + target);
			}
		}

		printl("[Bot AI DEBUG] spawn flags: " + NetProps.GetPropInt(m_trace.enthit, "m_spawnflags"));
		printl("[Bot AI DEBUG] flags: " + NetProps.GetPropInt(m_trace.enthit, "m_fFlags"));
		printl("[Bot AI DEBUG] entity flags: " + NetProps.GetPropInt(m_trace.enthit, "m_iEFlags"));
		if("GetSequenceName" in m_trace.enthit) {
			local sequenceName = m_trace.enthit.GetSequenceName(m_trace.enthit.GetSequence()).tolower();
			printl("[Bot AI DEBUG] ActionState: " + m_trace.enthit.GetSequence() + " " + sequenceName);
		}
		local area = NavMesh.GetNavArea(m_trace.enthit.GetOrigin(), 100);
		if(area != null) {
			area.DebugDrawFilled(0, 0, 255, 15, 0.2, true);
		}
		printl("[Bot AI DEBUG] ViewEntity: " + NetProps.GetPropEntity(m_trace.enthit, "m_hViewEntity"));
		printl("[Bot AI DEBUG] LookatPlayer: " + NetProps.GetPropEntity(m_trace.enthit, "m_lookatPlayer"));

		printl("[Bot AI DEBUG] hit pos: " + m_trace.pos);
		printl("[Bot AI DEBUG] Position: " + m_trace.enthit.GetOrigin());
		printl("[Bot AI DEBUG] LocalVelocity: " + m_trace.enthit.GetLocalVelocity());
		printl("[Bot AI DEBUG] Velocity: " + m_trace.enthit.GetVelocity());
		printl("[Bot AI DEBUG] m_vecBaseVelocity: " + NetProps.GetPropVector(m_trace.enthit, "m_vecBaseVelocity"));
		printl("[Bot AI DEBUG] m_usable: " + NetProps.GetPropInt(m_trace.enthit, "m_usable"));
		local glowEntity = NetProps.GetPropEntity(m_trace.enthit, "m_glowEntity");
		if(glowEntity)
		printl("[Bot AI DEBUG] m_glowEntity: " + glowEntity.GetClassname() + "[" + glowEntity.GetEntityIndex() + "]" + " glow: " + NetProps.GetPropInt(glowEntity, "m_Glow.m_iGlowType") + " color: " + NetProps.GetPropInt(glowEntity, "m_Glow.m_glowColorOverride"));

		printl("[Bot AI DEBUG] Target: " + BotAI.GetTarget(m_trace.enthit));

		if(BotAI.IsEntitySurvivor(BotAI.GetTarget(m_trace.enthit))) {
			printl("[Bot AI DEBUG] me: " + BotAI.getPlayerBaseName(m_trace.enthit));
			printl("[Bot AI DEBUG] target: " + BotAI.getPlayerBaseName(BotAI.GetTarget(m_trace.enthit)));
		}
		if(m_trace.enthit in BotAI.botAim) {
			printl("[Bot AI DEBUG] BotAI.botAim: " + BotAI.botAim[m_trace.enthit]);
			printl("[Bot AI DEBUG] BotAI.botAim valid: " + BotAI.IsEntityValid(BotAI.botAim[m_trace.enthit]));
			if(BotAI.IsEntityValid(BotAI.botAim[m_trace.enthit])) {
				printl("[Bot AI DEBUG] BotAI.botAim classname: " + BotAI.botAim[m_trace.enthit].GetClassname());
				printl("[Bot AI DEBUG] BotAI.botAim alive: " + BotAI.IsAlive(BotAI.botAim[m_trace.enthit]));
			}
		}
		if("EyePosition" in m_trace.enthit)
			printl("[Bot AI DEBUG] Eye: " + m_trace.enthit.EyePosition());
		if(m_trace.enthit.GetClassname() == "weapon_spawn") {
			printl("[Bot AI DEBUG] WeaponID " + NetProps.GetPropInt(m_trace.enthit, "m_weaponID"));
		}

		local eyeAngle0 = NetProps.GetPropFloat(m_trace.enthit, "m_angEyeAngles[0]");
		local eyeAngle1 = NetProps.GetPropFloat(m_trace.enthit, "m_angEyeAngles[1]");

		printl("[Bot AI DEBUG] m_angEyeAngles: " + eyeAngle0 + ", " + eyeAngle1);
		printl("[Bot AI DEBUG]  GetAngles: " + m_trace.enthit.GetAngles());
		printl("[Bot AI DEBUG]  GetLocalAngles: " + m_trace.enthit.GetLocalAngles());

		if("EyeAngles" in m_trace.enthit)
			printl("[Bot AI DEBUG]  EyeAngles: " + m_trace.enthit.EyeAngles());

		local direcVec = NetProps.GetPropVector(m_trace.enthit, "m_angRotation");
		printl("[Bot AI DEBUG]  m_angRotation: " + BotAI.CreateQAngle(direcVec.x, direcVec.y, direcVec.z));
		printl("[Bot AI DEBUG]  GetForwardVector: " + BotAI.CreateQAngle(m_trace.enthit.GetForwardVector().x, m_trace.enthit.GetForwardVector().y, m_trace.enthit.GetForwardVector().z));
	}

	return m_trace.enthit;
}

function BotAI::printVelocity(entity) {
	printl("[Bot AI DEBUG] Position: " + entity.GetOrigin());
	printl("[Bot AI DEBUG] LocalVelocity: " + entity.GetLocalVelocity());
	printl("[Bot AI DEBUG] Velocity: " + entity.GetVelocity());
	printl("[Bot AI DEBUG] m_vecBaseVelocity: " + NetProps.GetPropVector(entity, "m_vecBaseVelocity"));
	printl("[Bot AI DEBUG] GetBaseVelocity: " + entity.GetBaseVelocity());
	printl("[Bot AI DEBUG] m_vecAbsVelocity: " + NetProps.GetPropVector(entity, "m_vecAbsVelocity"));
}

::BotAI.GetEntitySpeedVector <- function(entity) {
	if(BotAI.IsEntityValid(entity)) {
		return entity.GetVelocity().Length();
	}
	return 0;
}

::BotAI.GetEntitySpeedLocalVector <- function(entity) {
	if(BotAI.IsEntityValid(entity)) {
		return GetPhysVelocity(entity).Length();
	}
	return 0;
}

function BotAI::getCross(p1, p2, p3) {
	local dx = p1.x - p2.x;
    local dy = p1.y - p2.y;

    local u = (p3.x - p1.x) * dx + (p3.y - p1.y) * dy;
    u /= dx * dx + dy * dy;

	return Vector((p1.x + u * dx), (p1.y + u * dy), 0);
}

function BotAI::xyCrossProduct(v1, v2) {
    return (v1.x*v2.y) - (v1.y*v2.x);
}

function BotAI::xyDotProduct(v1, v2) {
    return (v1.x*v2.x) + (v1.y*v2.y);
}

/**
 * Useless, ForceButton function can't control the movement of player entity.
 */
::BotAI.dodgeEntity <- function(player, infected)
{
	BotAI.debugCall("dodgeEntity");
	local living = "EyeAngles" in infected;
	local eyeVec = Vector(0, 0, 0);
	local dirction = Vector(0, 0, 0);

	if(BotAI.GetEntitySpeedVector(infected) > 10){
		eyeVec = infected.GetVelocity();
		dirction = player.GetOrigin() - infected.GetOrigin();
	}

	if(eyeVec.Length() <= 0){
		if(living)
			eyeVec = infected.EyeAngles().Forward();
		else{
			eyeVec = player.EyeAngles().Forward();
			dirction = infected.GetOrigin() - player.GetOrigin();
		}
	}

	local leftAndRight = BotAI.xyCrossProduct(eyeVec, dirction);
	local forwardAndBack = BotAI.xyDotProduct(eyeVec, dirction);
	local time = 1;

	if(leftAndRight > 0){
		BotAI.ForceButton(player, BUTTON_RIGHT , time);
		BotAI.DisableButton(player, BUTTON_LEFT , time);
		printl("[Bot AI] Dodge: Right.");
	}
	else if(leftAndRight < 0){
		BotAI.ForceButton(player, BUTTON_LEFT , time);
		BotAI.DisableButton(player, BUTTON_RIGHT , time);
		printl("[Bot AI] Dodge: Left.");
	}

	if(forwardAndBack > 0){
		BotAI.ForceButton(player, BUTTON_BACK , time);
		BotAI.DisableButton(player, BUTTON_FORWARD , time);
		printl("[Bot AI] Dodge: Back.");
	}
	else if(forwardAndBack < 0){
		BotAI.ForceButton(player, BUTTON_FORWARD , time);
		BotAI.DisableButton(player, BUTTON_BACK , time);
		printl("[Bot AI] Dodge: Forward.");
	}
}

::BotAI.validVector <- function(vector) {
	return vector != null && "Vector" == typeof vector
	&& vector.x.tostring().find("#") == null && vector.y.tostring().find("#") == null && vector.z.tostring().find("#") == null
	&& vector.x.tostring().find("nan") == null && vector.y.tostring().find("nan") == null && vector.z.tostring().find("nan") == null;
}

::BotAI.normalize <- function(vector) {
	if(!validVector(vector)) return Vector(0, 0, 0);
	local length = vector.Length();

	return Vector(vector.x / length, vector.y / length, vector.z / length);
}

::BotAI.fakeTwoD <- function(vector){
	if(!validVector(vector)) return Vector(0, 0, 0);

	return Vector(vector.x, vector.y, 0);
}

::BotAI.rotateVector <- function(vector, angle) {
	if(!validVector(vector)) return Vector(0, 0, 0);

	/*
	local radians = angle * PI / 180;
	local x = vector.x * cos(radians) - vector.y * sin(radians);
	local y = vector.x * sin(radians) - vector.y * cos(radians);
	*/
	local length = vector.Length();
	local qAngle = BotAI.CreateQAngle(vector.x, vector.y, vector.z);
	return QAngle(qAngle.Pitch(), qAngle.Yaw() + angle, 0).Forward().Scale(length);
	//return Vector(x, y, vector.z);
}

function BotAI::printCollision(entity) {
	printl("[Bot AI DEBUG] m_vecMins " + NetProps.GetPropVector(entity, "m_Collision.m_vecMins"));
	printl("[Bot AI DEBUG] m_vecMaxs " + NetProps.GetPropVector(entity, "m_Collision.m_vecMaxs"));
	printl("[Bot AI DEBUG] m_flRadius " + NetProps.GetPropFloat(entity, "m_Collision.m_flRadius"));
}

function BotAI::GetDistanceToTop(entity)
{
	if (!BotAI.IsEntityValid(entity))
		return 0;

	local startPt = entity.GetCenter();
	if("EyePosition" in entity)
		startPt = entity.EyePosition();

	local endPt = startPt + Vector(0, 0, 9999999);

	local m_trace = { start = startPt, end = endPt, ignore = entity, mask = MASK_UNTHROUGHABLE };
	TraceLine(m_trace);

	if (m_trace.enthit == entity || !m_trace.hit)
		return 0.0;

	return BotAI.distanceof(startPt, m_trace.pos);
}

function BotAI::enableGlowColor(entity, red, green, blue) {
	local desiredColor = red | (green << 8) | (blue << 16);
	if(BotAI.IsEntityValid(entity)){
		NetProps.SetPropInt(entity, "m_Glow.m_iGlowType", 3);
		NetProps.SetPropInt(entity, "m_Glow.m_glowColorOverride", desiredColor);
	}
}

function BotAI::disableGlowColor(entity) {
	if(BotAI.IsEntityValid(entity)){
		NetProps.SetPropInt(entity, "m_Glow.m_iGlowType", 0);
		NetProps.SetPropInt(entity, "m_Glow.m_glowColorOverride", 0);
	}
}

function BotAI::vomitTank(entity) {
	if(BotAI.IsEntitySI(entity)){
		foreach(test in BotAI.SpecialList) {
			if(test != entity && BotAI.IsAlive(test) && IsPlayerABot(test)) {
				BotAI.BotAttack(test, entity);
			}
		}
		entity.HitWithVomit();
		::BotAI.Timers.AddTimerByName("vomitTank" + entity.GetEntityIndex(), 2, false, BotAI.vomitTank, entity);
	}
}

::BotAI.getDodgeVec <- function(player, infected, force = 220, backForce = 220, limit = 220, maxDis = 600, doubleHorizontal = true, motion_ = false) {
	if(!BotAI.IsPlayerEntityValid(player)) {
		printl("[Bot AI] getDodgeVec function use for player entity.");
		return Vector(0, 0, 0);
	}

	if(player.IsDominatedBySpecialInfected() || player.IsIncapacitated() || player.IsHangingFromLedge() || player.IsStaggering())
		return player.GetVelocity();

	local distance = BotAI.nextTickDistance(player, infected, 1.0);
	local nextPlayer = BotAI.nextTickPostion(player, 1.0);
	local nextInfected = BotAI.nextTickPostion(infected, 1.0);

	if(distance > maxDis) {
		distance = maxDis;
	}

	local disScale = 1 - (distance / maxDis);
	force *= disScale;
	backForce *= disScale;

	if(BotAI.getIsMelee(player) && (!BotAI.IsEntitySI(infected) || infected.GetZombieType() != 8)) {
		if(BotAI.IsTargetStaggering(infected)) {
			local attractVec = nextInfected - nextPlayer;
			return BotAI.fakeTwoD(BotAI.normalize(attractVec).Scale(limit));
		} else if(BotAI.IsLivingEntity(infected)) {
			backForce *= -1;
		}
	}

	local living = "EyeAngles" in infected;
	local motion = Vector(0, 0, 0);
	local dirction = nextInfected - nextPlayer;
	local justLeft = false;

	if(BotAI.GetEntitySpeedVector(infected) > 10) {
		motion = infected.GetVelocity();
	} else {
		if(living) {
			motion = BotAI.normalize(BotAI.fakeTwoD(infected.EyeAngles().Forward()));
		} else {
			//motion = nextPlayer - nextInfected;
			//dirction = BotAI.normalize(BotAI.fakeTwoD(player.EyeAngles().Forward()));
			justLeft = true;
		}
	}

	local foot = BotAI.getCross(nextInfected, nextInfected + motion, nextPlayer);

	if(BotAI.BotDebugMode) {
		DebugDrawLine(nextInfected + Vector(0, 0, 20), nextPlayer + Vector(0, 0, 20), 60, 120, 255, true, 0.2);
		DebugDrawLine(foot + Vector(0, 0, 20), nextPlayer + Vector(0, 0, 20), 60, 255, 60, true, 0.2);
	}

	local horizontalVector;
	local verticalVector = BotAI.normalize(BotAI.fakeTwoD(dirction));

	if (!justLeft) {
		horizontalVector = BotAI.normalize(BotAI.fakeTwoD(nextPlayer - foot));
		verticalVector = BotAI.normalize(BotAI.fakeTwoD(dirction));
	} else {
		horizontalVector = BotAI.normalize(BotAI.fakeTwoD(BotAI.rotateVector(dirction, 90)));
		verticalVector = BotAI.normalize(BotAI.fakeTwoD(dirction));
	}

	local playerEyeVec = BotAI.normalize(BotAI.fakeTwoD(player.EyeAngles().Forward()));
	local obstacleVec = Vector(0, 0, 0);
	local maxWallDist = 200;
	local minWallDist = 0;

	local function clamp(value, min, max) {
		if (value < min) return min;
		if (value > max) return max;
		return value;
	}

	local wallCount = 0;

	for(local i = 0; i < 8; ++i) {
		local angleVec = BotAI.rotateVector(playerEyeVec, i * 45);
		local dist = BotAI.GetDistanceToWall(player, angleVec);

		if(dist <= maxWallDist) {
			wallCount++;
			local t = clamp((dist - minWallDist) / (maxWallDist - minWallDist), 0, 1);
			local weight = 1.0 - (t * t) * RandomFloat(0.5, 1.0);
			obstacleVec += angleVec.Scale(-force * weight);
		}
	}

	if (wallCount >= 5) {
		horizontalVector = obstacleVec;
		verticalVector = obstacleVec;
	} else {
		if(obstacleVec.Length() > 0) {
			obstacleVec = BotAI.normalize(obstacleVec);
			local closestDist = BotAI.GetDistanceToWall(player, obstacleVec);
			local blendFactor = clamp(1.0 - (closestDist / maxWallDist), 0.3, 1.0);

			local function lerp(a, b, t) {
				return a + (b - a) * t;
			}

			horizontalVector = BotAI.normalize(
				Vector(
					lerp(horizontalVector.x, obstacleVec.x, blendFactor * 0.7),
					lerp(horizontalVector.y, obstacleVec.y, blendFactor * 0.7),
					0
				)
			);

			verticalVector = BotAI.normalize(
				Vector(
					lerp(verticalVector.x, obstacleVec.x, blendFactor * 0.3),
					lerp(verticalVector.y, obstacleVec.y, blendFactor * 0.3),
					0
				)
			);
		}
	}

	if(BotAI.isEdge(player, horizontalVector)) {
		horizontalVector = horizontalVector.Scale(-1);
		if(BotAI.isEdge(player, horizontalVector)) {
			horizontalVector = Vector(0, 0, 0);
		}
	}

	if(BotAI.isEdge(player, verticalVector)) {
		verticalVector = verticalVector.Scale(-1);
		if(BotAI.isEdge(player, verticalVector)) {
			verticalVector = Vector(0, 0, 0);
		}
	}

	local newVec = BotAI.fakeTwoD(horizontalVector.Scale(force) + verticalVector.Scale(backForce));

	if(newVec.Length() > limit) {
		newVec = BotAI.normalize(newVec).Scale(limit);
	}

	if(motion) {
		newVec += BotAI.normalize(BotAI.fakeTwoD(player.GetOrigin() - infected.GetOrigin())).Scale(limit);
	}

	if(obstacleVec.Length() > 0) {
		newVec = newVec.Scale(1.5);
	}

	return newVec;
}

function BotAI::botDeath(bot, pos = null) {
	local infoTarget = null;
    while(infoTarget = Entities.FindByName(infoTarget, "botai_target_timer_" + bot.GetEntityIndex()))
         infoTarget.Kill();
	infoTarget = null;
	while(infoTarget = Entities.FindByName(infoTarget, "botai_navigator_timer_" + bot.GetEntityIndex()))
        infoTarget.Kill();
	infoTarget = null;
	while(infoTarget = Entities.FindByName(infoTarget, "botai_item_seacher_timer_" + bot.GetEntityIndex()))
		infoTarget.Kill();
	if(bot in BotAI.playerNavigator)
		delete BotAI.playerNavigator[bot];
	if(bot in BotAI.BotLinkGasCan) {
		DoEntFire("!self", "ClearParent", "", 0, null, BotAI.BotLinkGasCan[bot]);
		printl("clear gascan parent");
		BotAI.blockBackpackPickup(BotAI.BotLinkGasCan[bot], 5.0);
		if(BotAI.validVector(pos)) {
			BotAI.BotLinkGasCan[bot].SetOrigin(pos);
		} else if("GetOrigin" in pos) {
			local function setPos(args) {
				if(BotAI.IsEntityValid(args.entity) && BotAI.IsEntityValid(args.player)) {
					args.entity.SetOrigin(args.player.GetOrigin());
					DoEntFire("!self", "Use", "", 0, args.player, args.entity);
				}
			}
			local gas = BotAI.BotLinkGasCan[bot];
			::BotAI.Timers.AddTimerByName("setEntityPos" + BotAI.BotLinkGasCan[bot].GetEntityIndex(), 0.5, false, setPos, {entity = gas, player = pos});
		} else {
			local gas = BotAI.BotLinkGasCan[bot];

			NetProps.SetPropInt(gas, "m_iEFlags", 46137344);
			BotAI.somethingBad[gas] <- gas;
		}

		delete BotAI.BotLinkGasCan[bot];
	}
}

function BotAI::GetDistanceToWall(entity, vec) {
	if (!BotAI.IsEntityValid(entity)) return 0.0;
	local startPt = entity.GetOrigin();
	if("EyePosition" in entity)
		startPt = entity.EyePosition();

	local endPt = startPt + BotAI.normalize(vec).Scale(200);

	local m_trace = { start = startPt, end = endPt, ignore = entity, mask = MASK_UNTHROUGHABLE };
	TraceLine(m_trace);

	if (!m_trace.hit)
		return 200;

	return BotAI.CalculateDistance(startPt, m_trace.pos);
}

function BotAI::isEdge(entity, vec) {
	if (!BotAI.IsEntityValid(entity)) return 0.0;
	local startPt = entity.GetOrigin();
	if("GetCenter" in entity)
		startPt = entity.GetCenter();

	vec = BotAI.normalize(vec).Scale(100);
	startPt += vec;

	local endPt = startPt + Vector(0, 0, -200);

	local m_trace = { start = startPt, end = endPt, ignore = entity, mask = MASK_UNTHROUGHABLE };
	TraceLine(m_trace);

	if (!m_trace.hit)
		return true;

	return false;
}

function BotAI::IsHumanSpectating(entity) {
	return NetProps.GetPropInt(entity, "m_humanSpectatorUserID") > 0;
}

function BotAI::isVomited(entity) {
	if(!IsEntityValid(entity))
		return false;

	if(!(entity.GetEntityIndex() in BotAI.VomitList))
		return false;

	if(!BotAI.VomitList[entity.GetEntityIndex()])
		return false;

	return true;
}

function BotAI::vomitBomb(vomitjar) {
	local angvec = Vector( 0, 0, 0 );
	local infectedX =
	{
		classname = "info_goal_infected_chase"
		origin = vomitjar.GetOrigin()
		angles = angvec
	}
	local infected = g_ModeScript.CreateSingleSimpleEntityFromTable(infectedX);
	infected.ValidateScriptScope();
	local effectX =
	{
		classname = "info_particle_system"
		effect_name = "vomit_jar"
		start_active = "1"
		angles = angvec
		origin = vomitjar.GetOrigin()
	}
	local effect = g_ModeScript.CreateSingleSimpleEntityFromTable(effectX);
	effect.ValidateScriptScope();

	if(BotAI.IsEntityValid(infected) && BotAI.IsEntityValid(effect)) {
		BotAI.playSound(vomitjar, "weapons/ceda_jar/ceda_jar_explode.wav");
		DoEntFire("!self", "Enable", "", 0, null, infected);
		vomitjar.Kill();
		DoEntFire("!self", "Kill", "", 15, null, effect);
		DoEntFire("!self", "Kill", "", 15, null, infected);

		local infec = null;
		while (infec = Entities.FindByClassnameWithin(infec, "infected", infected.GetOrigin(), 250)) {
			if(!BotAI.IsAlive(infec)) continue;
			RushVictim(infec, 3000);
			NetProps.SetPropInt(infec, "m_Glow.m_iGlowType", 3);
			NetProps.SetPropInt(infec, "m_Glow.m_glowColorOverride", -4713783);
			::BotAI.Timers.AddTimer(60, false, BotAI.disableGlowColor, infec);
		}

		local playerI = null;
		while (playerI = Entities.FindByClassnameWithin(playerI, "player", infected.GetOrigin(), 300)) {
			if(BotAI.IsAlive(playerI) && !playerI.IsSurvivor()) {
				playerI.HitWithVomit();
				BotAI.continueVomit[playerI.GetEntityIndex()] <- true;
				BotAI.vomitTank(playerI);
			}
		}
	}
}

function BotAI::GetDistanceToGround(entity) {
	local startPt = entity.GetOrigin();
	local endPt = startPt + Vector(0, 0, -9999999);

	local m_trace = { start = startPt, end = endPt, ignore = entity, mask = g_MapScript.TRACE_MASK_SHOT };
	TraceLine(m_trace);

	if (m_trace.enthit == entity || !m_trace.hit)
		return 0.0;

	return BotAI.CalculateDistance(startPt, m_trace.pos);
}

function BotAI::CalculateDistance(vec1, vec2) {
	if (!vec1 || !vec2)
		return -1.0;

	return (vec2 - vec1).Length();
}

function BotAI::centerHeight(entity) {
	if(!BotAI.IsEntityValid(entity)) return 0;
	local heightVec = entity.GetCenter() - entity.GetOrigin();
	return heightVec.z;
}

function BotAI::nextTickDistance(entity, entity1, tps = 10.0, xy = false) {
	local startPos = BotAI.nextTickPostion(entity, tps);
	local targetPos = BotAI.nextTickPostion(entity1, tps);
	if(xy) {
		startPos = BotAI.fakeTwoD(startPos);
		targetPos = BotAI.fakeTwoD(targetPos);
	}

	return BotAI.distanceof(startPos, targetPos);
}

function BotAI::nextTickPostion(entity, tps = 10.0) {
	if(!BotAI.IsEntityValid(entity)) return Vector(0, 0, 0);

	return entity.GetOrigin();
}

/**
 * break
 */
/*
function BotAI::nextTickDistance(entity, entity1, tps = 10.0, xy = false) {
	local startPos = BotAI.nextTickPostion(entity, tps);
	local targetPos = BotAI.nextTickPostion(entity1, tps);
	if(xy) {
		startPos = BotAI.fakeTwoD(startPos);
		targetPos = BotAI.fakeTwoD(targetPos);
	}

	return BotAI.distanceof(startPos, targetPos);
}

function BotAI::nextTickPostion(entity, tps = 10.0) {
	if(!BotAI.IsEntityValid(entity)) return Vector(0, 0, 0);

	local scale = 1.0 / tps;
	local vel = entity.GetVelocity().Scale(scale);
	return entity.GetOrigin() + vel;
}
*/

function BotAI::distanceof(vec1, vec2) {
	if(!vec1 || !vec2)
		return 9000;

	if(!("Length" in vec1))
		return 9000;

	if(!("Length" in vec2))
		return 9000;

	return (vec2 - vec1).Length();
}

function BotAI::IsLastStrike(player) {
	if(!BotAI.IsAlive(player))
		return false;
	if("maxIncap" in BotAI)
		return BotAI.maxIncap == NetProps.GetPropInt(player, "m_currentReviveCount");

	local maxIncap = Convars.GetFloat("survivor_max_incapacitated_count");
	maxIncap = maxIncap.tointeger();

	if (("GetDirectorOptions" in DirectorScript) && ("SurvivorMaxIncapacitatedCount" in DirectorScript.GetDirectorOptions()))
		maxIncap = DirectorScript.GetDirectorOptions().SurvivorMaxIncapacitatedCount;
	if(!("maxIncap" in BotAI))
		BotAI.maxIncap <- maxIncap;
	return maxIncap == NetProps.GetPropInt(player, "m_currentReviveCount");
}

function BotAI::getSiVictim(si) {
	local victim = null;

	if(si.GetZombieType() == 6) {
		victim = NetProps.GetPropEntity(si, "m_pummelVictim");
		if (victim == null) {
			victim = NetProps.GetPropEntity(si, "m_carryVictim");
		}
	} else if(si.GetZombieType() == 3) {
		victim = NetProps.GetPropEntity(si, "m_pounceVictim");
	} else if(si.GetZombieType() == 5) {
		victim = NetProps.GetPropEntity(si, "m_jockeyVictim");
	} else if(si.GetZombieType() == 1) {
		victim = NetProps.GetPropEntity(si, "m_tongueVictim");
	}

	return victim;
}

function BotAI::StringReplace(string, original, replacement) {
	local expression = regexp(original);
	local result = "";
	local position = 0;

	local captures = expression.capture(string);

	while (captures != null)
	{
		foreach (i, capture in captures)
		{
			result += string.slice(position, capture.begin);
			result += replacement;
			position = capture.end;
		}

		captures = expression.capture(string, position);
	}

	result += string.slice(position);

	return result;
}

function BotAI::setLastStrike(player) {
	if(!BotAI.IsAlive(player))
		return;

	if("maxIncap" in BotAI) {
		player.SetReviveCount(BotAI.maxIncap);
		return;
	}

	local maxIncap = Convars.GetFloat("survivor_max_incapacitated_count");
	maxIncap = maxIncap.tointeger();

	if (("GetDirectorOptions" in DirectorScript) && ("SurvivorMaxIncapacitatedCount" in DirectorScript.GetDirectorOptions()))
		maxIncap = DirectorScript.GetDirectorOptions().SurvivorMaxIncapacitatedCount;

	player.SetReviveCount(maxIncap);
}

function BotAI::getIsMelee(player) {
	local weaponN = player.GetActiveWeapon();

	if(weaponN == null || !weaponN.IsValid())
		return false;

	local wname = weaponN.GetClassname();

	if(wname == "weapon_chainsaw" || wname == "weapon_melee")
		return true;

	return false;
}

function BotAI::SetTarget(_ent, _target) {
	if(!BotAI.IsEntityValid(_target)) return;
	_ent.__KeyValueFromString("target", _target.tostring());

	if(_ent.GetClassname() == "infected" || _ent.GetClassname() == "witch") {
		NetProps.SetPropEntity(_ent, "m_clientLookatTarget", _target);
	}

	if(_ent.GetClassname() == "player" && !IsPlayerABot(_ent))
		return;

	//BotAI.hookViewEntity(_ent, _target);
	if(BotAI.BotDebugMode) {
		printl("[Attack] " + BotAI.getPlayerBaseName(_ent));
	}
	CommandABot( { cmd = 0, target = _target, bot = _ent } );

	BotAI.botAim[_ent] <- _target;
	BotAI.lookAtEntity(_ent, _target);
}

function BotAI::IsTarget(_ent, target) {
	if(!BotAI.IsEntityValid(_ent)) return;
	if(BotAI.GetTarget(target) != null && BotAI.GetTarget(target).GetEntityIndex() == _ent.GetEntityIndex()) {
		return true;
	}

	return false;
}

function BotAI::getBotLookAt(_ent) {
	if(_ent in BotAI.botLookAt)
		return BotAI.botLookAt[_ent];
	return null;
}

function BotAI::GetTarget(_ent) {
	if(!BotAI.IsEntityValid(_ent)) return;

	if(_ent in BotAI.botLookAt && BotAI.IsAlive(BotAI.botLookAt[_ent]))
		return BotAI.botLookAt[_ent];

	if(_ent in BotAI.botAim && BotAI.IsAlive(BotAI.botAim[_ent]))
		return BotAI.botAim[_ent];

	if(BotAI.IsPlayerEntityValid(_ent))
		return NetProps.GetPropEntity(_ent, "m_lookatPlayer");

	return NetProps.GetPropEntity(_ent, "m_clientLookatTarget");
}

::BotAI.IsTargetStaggering <- function(entity) {
	if(!BotAI.IsEntityValid(entity)) return false;
	local sequence = NetProps.GetPropInt(entity, "m_nSequence");

	return (IsEntitySI(entity) &&
	((entity.GetZombieType() == 5 && sequence >= 15 && sequence <= 18) ||
	(entity.GetZombieType() == 3 && sequence >= 45 && sequence <= 49) ||
	(entity.GetZombieType() == 1 && sequence == 39) ||
	(entity.GetZombieType() == 4 && sequence == 17) ||
	(entity.GetZombieType() == 6 && sequence >= 38 && sequence <= 42) ||
	entity.IsStaggering())
	)
	|| BotAI.IsInfectedBeShoved(entity);
}

::BotAI.IsInfectedBeShoved <- function(infected) {
	return BotAI.IsEntityValid(infected) && BotAI.IsAlive(infected) && infected.GetClassname() == "infected" && infected.GetSequence() >= 120;
}

function BotAI::shoveCommon(infected) {
	if(!BotAI.IsAlive(infected)) return;

	if (BotAI.BotDebugMode) {
		BotAI.showAABB(infected);
	}

	if(infected.GetSequence() >= 122 && infected.GetSequence() <= 134)
		infected.ResetSequence(infected.GetSequence());
	else {
		local sequences = [
			122
			123
			124
			125
			126
			127
			128
			129
			130
			131
			132
			133
			134
		];

		infected.SetSequence(sequences[RandomInt(0, 12)]);
	}
}

function BotAI::isPlayerFall(player) {
	if(!BotAI.IsEntityValid(player) || !BotAI.IsAlive(player))
		return false;
	return player.IsDominatedBySpecialInfected() || player.IsStaggering() || player.IsIncapacitated() || player.IsHangingFromLedge();
}

::BotAI.IsPlayerClimb <- function(player) {
	if(!BotAI.IsEntityValid(player) || !BotAI.IsAlive(player))
		return false;

	local PlayerState = NetProps.GetPropInt(player, "m_nSequence");
	local onLadder = NetProps.GetPropInt(player, "movetype") == MOVETYPE_LADDER;
	return PlayerState == 610 || PlayerState == 611 || onLadder;
}

function BotAI::isPlayerNearLadder(player) {
	if(!BotAI.IsEntityValid(player) || !BotAI.IsAlive(player))
		return false;

	foreach(ladder in BotAI.ladders) {
		//if(ladder.IsInUse(player))
			//return true;
		if(BotAI.distanceof(player.GetOrigin(), ladder.GetBottomOrigin()) < 200)
			return true;
		if(BotAI.distanceof(player.GetOrigin(), ladder.GetTopOrigin()) < 200)
			return true;
	}

	return false;
}

function BotAI::BotAttack(boto, otherEntity) {
	if(!BotAI.IsEntityValid(boto)) return;
	if(!BotAI.IsEntityValid(otherEntity) || (!BotAI.IsAlive(otherEntity) && otherEntity.GetClassname() != "tank_rock") || !IsPlayerABot(boto))
		return;

	if(BotAI.IsPlayerClimb(boto) || BotAI.IsBotHealingOthers(boto))
		return;

	//if(BotAI.HasItem(boto, BotAI.BotsNeedToFind) && BotAI.UseTargetOri != null && BotAI.distanceof(boto.GetOrigin(), BotAI.UseTargetOri) < 150 && otherEntity.GetClassname() != "player")
		//return;

	/*
	if (Time() - BotAI.getBotMoveCooldown(boto) > 1.5 && BotAI.getNavigator(boto).moving()) {
		BotAI.BotReset(boto)
	}
	*/

	BotAI.setBotMoveCooldown(boto, Time());
	BotAI.SetTarget(boto, otherEntity);
	return true;
}

function BotAI::BotReset(boto) {
	if(!BotAI.IsEntityValid(boto)) return;
	if(!IsPlayerABot(boto))
		return;

	if(BotAI.BotDebugMode) {
		printl("[Reset] " + BotAI.getPlayerBaseName(boto));
	}

	NetProps.SetPropFloat(boto, "m_flLaggedMovementValue", 1.0);

	return CommandABot( { cmd = 3, bot = boto } );
}

// [STALE] charger 支配残留检测: charger 在撞击/抓取/排队碾压瞬间死亡时, 受害者身上的支配
// netprop 可能残留 -> 引擎认为他仍被支配: 收起全身武器/禁止攻击和推挤/武器部署动画反复重启.
// m_queuedPummelAttacker 是"撞击结束->碾压开始"之间的排队窗口, 正是瞬杀 charger 卡住的状态.
function BotAI::hasStaleChargerLock(player) {
	if(!BotAI.IsPlayerEntityValid(player)) return false;
	local function isStale(att) {
		if(att == null) return false;
		if(!att.IsValid()) return true;
		if(!BotAI.IsAlive(att)) return true;
		if(att.GetClassname() != "player") return true;
		if(att.GetZombieType() != 6) return true;
		return false;
	}
	return isStale(NetProps.GetPropEntity(player, "m_carryAttacker"))
		|| isStale(NetProps.GetPropEntity(player, "m_pummelAttacker"))
		|| isStale(NetProps.GetPropEntity(player, "m_queuedPummelAttacker"));
}

// [预防] bot 当前是否被 charger 控制 (carry/pummel/queued 任一 prop 非空, 不管 charger 死活).
// 专门只认 charger, 不含 smoker/hunter/jockey 等其它支配 -> fire-state 早退只屏蔽 charger 窗口,
// 不误伤被其它特感控制时的开火逻辑.
function BotAI::isUnderChargerControl(player) {
	if(!BotAI.IsPlayerEntityValid(player)) return false;
	return NetProps.GetPropEntity(player, "m_carryAttacker") != null
		|| NetProps.GetPropEntity(player, "m_pummelAttacker") != null
		|| NetProps.GetPropEntity(player, "m_queuedPummelAttacker") != null;
}

function BotAI::clearStaleChargerLock(player, force = false) {
	if(!IsPlayerABot(player)) return;
	local idx = player.GetEntityIndex();
	if(!force && idx in BotAI.FireSuspendUntil && Time() < BotAI.FireSuspendUntil[idx])
		return;
	NetProps.SetPropEntity(player, "m_carryAttacker", null);
	NetProps.SetPropEntity(player, "m_pummelAttacker", null);
	NetProps.SetPropEntity(player, "m_queuedPummelAttacker", null);
	if(idx in BotAI.SurvivorTrapped) BotAI.SurvivorTrapped[idx] <- null;
	if(idx in BotAI.SurvivorTrappedTimed) BotAI.SurvivorTrappedTimed[idx] <- null;
	BotAI.RemoveFlag(player, FL_FROZEN);
	BotAI.UnforceButton(player, 1);
	// [预防] charger 释放缓冲期内不写武器 netprop (m_flNextPrimaryAttack 等), 交引擎独占重建;
	// 缓冲期外才复位攻击计时器 (供非 charger 场景的 stale 清理用)
	if(!(idx in BotAI.FireSuspendUntil && Time() < BotAI.FireSuspendUntil[idx]))
		BotAI.resetWeaponAttackState(player);
	printl("[BotAI][STALE] cleared stale charger lock on " + BotAI.getPlayerBaseName(player));
}

// [方案A] 复位攻击冷却: charger 非正常释放时, 引擎冻结的攻击计时器不会复位.
// 关键是玩家实体自身的 m_flNextAttack (抓取时引擎冻结它, 正常释放才解冻) ——
// 它卡在未来值时任何武器/药品都无法使用, fire-state 仍每 tick toggle 攻击键 -> 全物品空抖.
// 同时复位所有槽位武器的 m_flNextPrimaryAttack (药品 slot4 也会卡).
function BotAI::resetWeaponAttackState(boto) {
	if(!BotAI.IsEntityValid(boto)) return;
	if(!IsPlayerABot(boto)) return;

	NetProps.SetPropFloat(boto, "m_flNextAttack", Time());

	// 引擎级按键禁用掩码: 实际按键 = (按键|强制) & ~禁用. charger 抓人时引擎可能设置它,
	// 非正常释放不恢复 -> 支配 prop 清干净了攻击键仍被掩码吃掉, 全部动作无效.
	NetProps.SetPropInt(boto, "m_afButtonDisabled", 0);

	local function unstick(w) {
		if(!BotAI.IsEntityValid(w)) return;
		NetProps.SetPropFloat(w, "m_flNextPrimaryAttack", Time() - 1);
		NetProps.SetPropFloat(w, "m_flNextSecondaryAttack", Time() - 1);
	}

	unstick(boto.GetActiveWeapon());

	local t = BotAI.GetHeldItems(boto);
	if(t) {
		foreach(slotName, item in t)
			unstick(item);
	}
}

// [诊断] 读 bot 的 viewmodel 实体. L4D2 玩家有 m_hViewModel 数组 (索引 0 = 主视角模型),
// 武器的 deploy/开火/挥砍动画都在它身上播. charger 瞬杀疑似把它打成 NULL/失效 ->
// 武器无法播放动画 -> 第三人称手部持续抖动. 返回描述字符串供诊断打印.
function BotAI::diagViewModelState(boto) {
	if(!BotAI.IsEntityValid(boto)) return "bot-invalid";
	local vm = null;
	try {
		vm = NetProps.GetPropEntityArray(boto, "m_hViewModel", 0);
	} catch(e1) {
		try {
			vm = NetProps.GetPropEntity(boto, "m_hViewModel");
		} catch(e2) {
			return "vm-read-error";
		}
	}
	if(vm == null) return "NULL";
	if(!vm.IsValid()) return "invalid";
	local seqName = "?";
	try { seqName = vm.GetSequenceName(vm.GetSequence()); } catch(e3) { seqName = "seq-err"; }
	return "ok(seq=" + seqName + ")";
}

// [诊断] charger 释放后专属监视器: 每 0.5s 采样被撞 bot 一次, 持续 ~8s, 无论 watchdog
// 抓没抓到都打印. 目的: 坐实 viewmodel 是否在释放后变 NULL, 同时暴露 watchdog 漏判的原因
// (shove/attempts/progress 三个量), 不修改任何状态, 纯观测.
function BotAI::startChargerDiag(boto) {
	if(!BotAI.IsEntitySurvivorBot(boto)) return;
	local idx = boto.GetEntityIndex();
	// stuck: 卡死连击计数; lastSeq: 上次世界动画序列 (判断动画是否冻结);
	// lastWatk: 上次武器攻击时间戳 (判断是否真开火); repaired/escalated: 各只做一次
	local args = { idx = idx, n = 0, stuck = 0, lastSeq = null, lastWatk = null, repaired = false, escalated = false };
	local function sample(a) {
		local b = null;
		// 用 entity index 重新取, 防 boto 句柄失效
		local p = null;
		while(p = Entities.FindByClassname(p, "player")) {
			if(p.GetEntityIndex() == a.idx) { b = p; break; }
		}
		if(b == null || !BotAI.IsEntityValid(b) || b.IsDead()) {
			BotAI.Timers.RemoveTimerByName("ChargerDiag" + a.idx);
			return;
		}
		a.n++;
		local wep = b.GetActiveWeapon();
		local wepValid = BotAI.IsEntityValid(wep);
		local wname = wepValid ? wep.GetClassname() : "none";
		local watkRaw = wepValid ? NetProps.GetPropFloat(wep, "m_flNextPrimaryAttack") : 0.0;
		local watk = wepValid ? (watkRaw - Time()) : 0;
		local vmState = BotAI.diagViewModelState(b);
		local btnDis = NetProps.GetPropInt(b, "m_afButtonDisabled");
		local worldSeq = b.GetSequenceName(b.GetSequence());

		printl("[BotAI][CDIAG] " + BotAI.getPlayerBaseName(b) + " t=" + (a.n * 0.5)
			+ " vm=" + vmState
			+ " atkBtn=" + (BotAI.IsPressingAttack(b) ? 1 : 0)
			+ " forced1=" + (BotAI.HasForcedButton(b, 1) ? 1 : 0)
			+ " shove=" + (BotAI.IsPressingShove(b) ? 1 : 0)
			+ " btnDisabled=" + btnDis
			+ " btnForced=" + NetProps.GetPropInt(b, "m_afButtonForced")
			+ " wep=" + wname + " wepAtk+" + watk
			+ " dominated=" + (b.IsDominatedBySpecialInfected() ? 1 : 0)
			+ " healing=" + (BotAI.IsBotHealing(b) ? 1 : 0)
			+ " seq=" + worldSeq + " stuck=" + a.stuck);

		// [预防] 释放缓冲期内 fire-state 被主动 suspend, bot 不动属正常 -> 只观察, 不计卡死.
		// 缓冲期过后若引擎已重建好武器, bot 恢复 -> stuck 攒不起来, 监视自然结束;
		// 仍卡死 -> stuck 累计 -> 软修复 -> 硬重置 (最终保险照常起效).
		if(a.idx in BotAI.FireSuspendUntil && Time() < BotAI.FireSuspendUntil[a.idx]) {
			a.lastSeq = worldSeq;
			a.lastWatk = watkRaw;
			a.stuck = 0;
			if(a.n >= 24) BotAI.Timers.RemoveTimerByName("ChargerDiag" + a.idx);
			return;
		}

		// 合法受控态 -> 停止监视 (不是 bug, 别误杀)
		local realDom = b.IsDominatedBySpecialInfected() && !BotAI.hasStaleChargerLock(b);
		if(b.IsIncapacitated() || b.IsHangingFromLedge() || realDom
			|| BotAI.isPlayerBeingRevived(b) || BotAI.IsPlayerReviving(b) || BotAI.IsBotHealing(b)) {
			BotAI.Timers.RemoveTimerByName("ChargerDiag" + a.idx);
			return;
		}

		// 客观损坏: viewmodel 坏 / 武器整把消失 (前 5 秒卡死后期会演变成这样)
		local broken = (vmState == "NULL" || vmState == "invalid" || wname == "none");
		// 动画冻结: 世界序列与上一帧完全相同 (正常 bot 战斗/移动时序列会变)
		local frozen = (a.lastSeq != null && worldSeq == a.lastSeq);
		a.lastSeq = worldSeq;
		// 真开火: 武器攻击时间戳推进到未来 = 引擎真的执行了射击/挥砍 (站桩连射的健康 bot 会持续推进)
		local firing = (wepValid && a.lastWatk != null && watkRaw != a.lastWatk && watk > 0);
		a.lastWatk = watkRaw;
		// 战斗语境: 自己有活目标, 或 1500u 内有普感 (区分"战斗中卡死"和"安全待机", 后者别杀)
		local threat = false;
		local tgt = BotAI.getBotTarget(b);
		if(BotAI.IsEntityValid(tgt) && BotAI.IsAlive(tgt)) threat = true;
		if(!threat && Entities.FindByClassnameWithin(null, "infected", b.GetOrigin(), 1500) != null) threat = true;

		// 卡死累计: 武器/vm 损坏(无条件) 或 (动画冻结 且 处于战斗 且 没在真开火)
		if(broken || (frozen && threat && !firing))
			a.stuck++;
		else
			a.stuck = 0;

		// [第一档] 软修复, 只做一次 (用户要求保留软重置; 对本 bug 多半无效, 但无副作用先试)
		if(!a.repaired && a.stuck >= 3) {
			printl("[BotAI][CDIAG] -> soft repair (once) " + BotAI.getPlayerBaseName(b));
			BotAI.repairStuckBot(b);
			a.repaired = true;
		}

		// [第二档] 软修复没救回来 -> 升级硬重置 (kill+defib).
		// [暂时搁置] 误判触发率过高 (待机/打肾上腺素/远离威胁的 bot 都被错判卡死), 等收集
		// 足够卡死案例、设计出准确的卡死判定条件后再启用. 内部代码全部保留, 改判定后直接取消注释.
		if(!a.escalated && a.stuck >= 6) {
			printl("[BotAI][CDIAG] would HARD RESET " + BotAI.getPlayerBaseName(b)
				+ " (post-charger stuck, soft repair failed) — DISABLED, see comment");
			// BotAI.hardResetBot(b, "post-charger stuck");
			a.escalated = true;
			BotAI.Timers.RemoveTimerByName("ChargerDiag" + a.idx);
			return;
		}

		if(a.n >= 24)
			BotAI.Timers.RemoveTimerByName("ChargerDiag" + a.idx);
	}
	BotAI.Timers.AddTimerByName("ChargerDiag" + idx, 0.5, true, sample, args);
	printl("[BotAI][CDIAG] started monitor for " + BotAI.getPlayerBaseName(boto) + " (charger release)");
}

// [修复] 重建 viewmodel + 清按键掩码. 针对 charger 瞬杀导致的两个客观根因:
//   (1) viewmodel 变 NULL/失效 -> 武器动画无法播放 -> 手部抖动
//   (2) m_afButtonDisabled 非 0 -> 引擎层把攻击/推挤键全掩掉 -> 既不能开枪也不能推挤
// viewmodel 重建用 holster->redeploy: 切到另一把武器再切回, 引擎重新生成视角模型.
// 返回 true 表示执行了修复 (供日志判断).
function BotAI::repairStuckBot(boto) {
	if(!BotAI.IsEntityValid(boto)) return false;
	if(!IsPlayerABot(boto)) return false;

	// 暂停 fire-state 1.2s: AI Advanced 独有的 fire-state 每 tick ForceButton+SwitchToItem,
	// 不暂停的话下面的 viewmodel 重建 (redeploy) 会被它当场冲掉, 修复白做.
	// 这是本 bug 只在 AI Advanced 出现的根源 (原版/L4B 释放时不碰武器/按键).
	BotAI.FireSuspendUntil[boto.GetEntityIndex()] <- Time() + 1.2;

	// (2) 清按键掩码 + 攻击冷却 (轻量, 无副作用, 总是先做)
	NetProps.SetPropInt(boto, "m_afButtonDisabled", 0);
	NetProps.SetPropFloat(boto, "m_flNextAttack", Time());
	NetProps.SetPropInt(boto, "m_afButtonForced", 0);
	BotAI.UnforceButton(boto, 1);
	BotAI.UnforceButton(boto, 2048);

	// (1) viewmodel 重建: 仅在确实损坏时做 (切武器有视觉跳变, 不滥用)
	local vmState = BotAI.diagViewModelState(boto);
	if(vmState == "NULL" || vmState == "invalid") {
		local wep = boto.GetActiveWeapon();
		local curName = BotAI.IsEntityValid(wep) ? wep.GetClassname() : null;
		if(curName == null) return true; // 按键已清, 但无武器可 redeploy

		// 找一把不同的武器作为中转
		local t = BotAI.GetHeldItems(boto);
		local otherName = null;
		if(t) {
			foreach(slot, item in t) {
				if(BotAI.IsEntityValid(item) && item.GetClassname() != curName
					&& item.GetClassname() != "weapon_first_aid_kit"
					&& item.GetClassname() != "weapon_defibrillator"
					&& item.GetClassname() != "weapon_pain_pills"
					&& item.GetClassname() != "weapon_adrenaline") {
					otherName = item.GetClassname();
					break;
				}
			}
		}

		if(otherName != null) {
			boto.SwitchToItem(otherName);
			// 0.1s 后切回原武器 -> 触发 deploy 动画, 重建 viewmodel
			local function backStep(a) {
				if(!BotAI.IsEntityValid(a.b)) return;
				a.b.SwitchToItem(a.w);
				NetProps.SetPropFloat(a.b, "m_flNextAttack", Time());
			}
			BotAI.Timers.AddTimerByName("VMRebuild" + boto.GetEntityIndex(), 0.1, false, backStep, {b = boto, w = curName});
		} else {
			// 没有第二把武器 -> 用 SwitchToItem 切自身强制重新 deploy
			boto.SwitchToItem(curName);
		}
	}
	return true;
}

// 软重置: 模拟"死亡复活/换关"会清掉的那批残留状态, 用于解开鬼畜僵死态
// 不真杀 bot (合作模式死亡不自动复活), 只 scrub 卡死根因: 强制按键/冻结/charger残留
function BotAI::forceFullReset(boto, reason = "glitch state cleared") {
	if(!BotAI.IsEntityValid(boto)) return;
	if(!IsPlayerABot(boto)) return;

	local idx = boto.GetEntityIndex();

	// [诊断] scrub 之前先抓拍卡死状态, 定位引擎层封锁位
	local dwep = boto.GetActiveWeapon();
	local dwname = BotAI.IsEntityValid(dwep) ? dwep.GetClassname() : "none";
	local dwatk = BotAI.IsEntityValid(dwep) ? (NetProps.GetPropFloat(dwep, "m_flNextPrimaryAttack") - Time()) : 0;
	printl("[BotAI][DIAG] " + BotAI.getPlayerBaseName(boto)
		+ " nextAtk+" + (NetProps.GetPropFloat(boto, "m_flNextAttack") - Time())
		+ " btnDisabled=" + NetProps.GetPropInt(boto, "m_afButtonDisabled")
		+ " btnForced=" + NetProps.GetPropInt(boto, "m_afButtonForced")
		+ " frozen=" + (BotAI.HasFlag(boto, FL_FROZEN) ? 1 : 0)
		+ " carry=" + (NetProps.GetPropEntity(boto, "m_carryAttacker") != null ? 1 : 0)
		+ " pummel=" + (NetProps.GetPropEntity(boto, "m_pummelAttacker") != null ? 1 : 0)
		+ " queued=" + (NetProps.GetPropEntity(boto, "m_queuedPummelAttacker") != null ? 1 : 0)
		+ " dominated=" + (boto.IsDominatedBySpecialInfected() ? 1 : 0)
		+ " wep=" + dwname + " wepAtk+" + dwatk
		+ " seq=" + boto.GetSequenceName(boto.GetSequence()));

	// 1. 清强制按键 (僵死核心: 残留的 ForceButton 让 bot 卡在某动作)
	NetProps.SetPropInt(boto, "m_afButtonForced", 0);

	// 2. 清冻结 flag
	BotAI.RemoveFlag(boto, FL_FROZEN);

	// 3. 清 charger 残留 netprops + trapped 表
	NetProps.SetPropEntity(boto, "m_carryAttacker", null);
	NetProps.SetPropEntity(boto, "m_pummelAttacker", null);
	NetProps.SetPropEntity(boto, "m_queuedPummelAttacker", null);
	if(idx in BotAI.SurvivorTrapped) BotAI.SurvivorTrapped[idx] <- null;
	if(idx in BotAI.SurvivorTrappedTimed) BotAI.SurvivorTrappedTimed[idx] <- null;

	// 4. 移动速度/摩擦力复位 (近 tank 时会被压低, 卡死时可能残留)
	NetProps.SetPropFloat(boto, "m_flLaggedMovementValue", 1.0);
	boto.SetFriction(1.0);

	// 5. 复位武器攻击冷却 (空抖型僵死的直接根因)
	BotAI.resetWeaponAttackState(boto);

	// 6. 清自身 watchdog 追踪 + 重排 AI 任务队列
	if(idx in BotAI.WatchdogSwitchTimes) BotAI.WatchdogSwitchTimes[idx] <- [];
	if(idx in BotAI.WatchdogLastWeapon) BotAI.WatchdogLastWeapon[idx] <- null;
	BotAI.WatchdogLastActive[idx] <- Time();
	BotAI.WatchdogProgressTime[idx] <- Time();
	BotAI.WatchdogAtkAttempts[idx] <- [];
	if(idx in BotAI.WatchdogLastNextAttack) delete BotAI.WatchdogLastNextAttack[idx];
	if(idx in BotAI.WatchdogHealStart) delete BotAI.WatchdogHealStart[idx];

	// 7. 暂停 fire-state 速砍 2 秒. AI Advanced 独有的 fire-state 每 tick toggle ForceButton(1)
	// 来模拟连发, charger 卡死后这个循环会立刻覆盖软重置清掉的 m_afButtonForced, 让引擎层
	// 的动画状态机永远没机会自然归位 -> 软重置等于白做. 暂停 2 秒让引擎喘口气.
	BotAI.FireSuspendUntil[idx] <- Time() + 2.0;
	NetProps.SetPropInt(boto, "m_afButtonForced", 0);
	BotAI.UnforceButton(boto, 1);
	BotAI.UnforceButton(boto, 2048);

	CommandABot( { cmd = 3, bot = boto } );

	printl("[BotAI][WATCHDOG] force-reset " + BotAI.getPlayerBaseName(boto) + " (" + reason + ")");
}

// [兜底] 硬重置: 模拟"处死后电击复活" —— 用户验证的 100% 恢复手段 (僵死只有死亡/换关能解).
// 流程: 快照位置/血量/装备 -> 处死 -> 0.3s 后 ReviveByDefib 原地复活 -> 传回原位/还原血量/补装备.
// 安全闸: 不杀最后一个存活者 (防团灭) / 60s 冷却 (防处死循环) / 杀失败检测 (伤害钩子拦截时放弃)
function BotAI::hardResetBot(boto, reason = "soft reset failed") {
	if(!BotAI.IsEntityValid(boto)) return;
	if(!IsPlayerABot(boto)) return;
	if(!BotAI.IsAlive(boto) || boto.IsIncapacitated()) return;

	local idx = boto.GetEntityIndex();
	local now = Time();

	local lastHard = (idx in BotAI.WatchdogHardLast) ? BotAI.WatchdogHardLast[idx] : 0;
	if(now - lastHard < 60.0) return;

	local aliveOthers = 0;
	foreach(s in BotAI.SurvivorList) {
		if(s != boto && BotAI.IsAlive(s))
			aliveOthers++;
	}
	if(aliveOthers < 1) {
		printl("[BotAI][HARDRESET] aborted for " + BotAI.getPlayerBaseName(boto) + " (last alive survivor)");
		return;
	}

	BotAI.WatchdogHardLast[idx] <- now;

	// 快照: 位置/血量/装备 (melee 记 script name, 其余记 give 命令名)
	local pos = boto.GetOrigin();
	local hp = BotAI.getPlayerTotalHealth(boto);
	if(hp < 30) hp = 30;
	local items = [];
	local t = BotAI.GetHeldItems(boto);
	if(t) {
		foreach(slot, item in t) {
			if(!BotAI.IsEntityValid(item)) continue;
			local cls = item.GetClassname();
			local giveName = cls;
			if(cls == "weapon_melee") {
				local mn = NetProps.GetPropString(item, "m_strMapSetScriptName");
				giveName = (mn != null && mn != "") ? mn : "melee";
			} else if(giveName.find("weapon_") == 0) {
				giveName = giveName.slice(7);
			}
			items.append({cls = cls, give = giveName});
		}
	}

	printl("[BotAI][HARDRESET] " + BotAI.getPlayerBaseName(boto) + " kill+defib (" + reason + ")");

	// 处死: 压血到 1 再补大额伤害.
	// [方案C 旁路] 挂 WatchdogKilling 白名单, BotAITakeDamage 钩子顶部直接放行,
	// 绕过友伤/Immunity/NonAliveProtect 等所有抹零规则. 单纯 self-attacker 仍会被
	// ai_events.nut:1444 的 "bot survivor 攻击 bot survivor 一律 return false" 拦截 -> 必须用白名单.
	BotAI.WatchdogKilling[idx] <- true;
	boto.SetHealth(1);
	NetProps.SetPropFloat(boto, "m_healthBuffer", 0.0);
	boto.TakeDamage(10000.0, 0, boto);
	delete BotAI.WatchdogKilling[idx];

	// 还原: 复活 -> 传回原位/还原血量/补装备
	local function restoreStep(args2) {
		local b2 = args2.b;
		if(!BotAI.IsEntityValid(b2) || !BotAI.IsAlive(b2)) return;
		b2.SetOrigin(args2.pos);
		b2.SetHealth(args2.hp);
		foreach(it in args2.items) {
			if(!BotAI.HasItem(b2, it.cls))
				b2.GiveItem(it.give);
		}
		printl("[BotAI][HARDRESET] " + BotAI.getPlayerBaseName(b2) + " revived & restored");
	}

	// 复活步: 不能只看 IsDead(). L4D2 死亡有两种状态——
	// (1) 生还者第三次受击进入 ragdoll: m_lifeState != 0, 可被 defib, 但 IsDead() 在初期返回 false
	// (2) 真正的 entity dead: 同样 m_lifeState != 0
	// 用 m_lifeState != 0 作为"可 defib"的统一判定 (LIFE_ALIVE=0, 其他都不是活着).
	// 之前用 IsDead() 在 ragdoll 阶段误判为"还活着" -> 卡 still alive after finish.
	local function isDefibable(b) {
		if(!BotAI.IsEntityValid(b)) return false;
		if(b.IsDead()) return true;
		try {
			if(NetProps.GetPropInt(b, "m_lifeState") != 0) return true;
		} catch(e) {}
		return false;
	}

	local function reviveStep(args) {
		local b = args.b;
		if(!BotAI.IsEntityValid(b)) return;
		if(isDefibable(b)) {
			b.ReviveByDefib();
			::BotAI.Timers.AddTimerByName("HardResetRestore" + b.GetEntityIndex(), 0.4, false, restoreStep, args);
			return;
		}
		if(b.IsIncapacitated()) {
			// 第一击只打倒未致死 (还有复活次数) -> 倒地再补一击致死, 同样需要白名单旁路
			local bidx = b.GetEntityIndex();
			BotAI.WatchdogKilling[bidx] <- true;
			b.TakeDamage(10000.0, 0, b);
			delete BotAI.WatchdogKilling[bidx];
			local function finishStep(args3) {
				local b3 = args3.b;
				if(!BotAI.IsEntityValid(b3)) return;
				if(isDefibable(b3)) {
					b3.ReviveByDefib();
					::BotAI.Timers.AddTimerByName("HardResetRestore" + b3.GetEntityIndex(), 0.4, false, restoreStep, args3);
				} else {
					// 仍未进入 ragdoll/dying: 极少见, 再补一刀做最后尝试 (带白名单)
					BotAI.WatchdogKilling[b3.GetEntityIndex()] <- true;
					b3.TakeDamage(10000.0, 0, b3);
					delete BotAI.WatchdogKilling[b3.GetEntityIndex()];
					local function lastStep(args4) {
						local b4 = args4.b;
						if(!BotAI.IsEntityValid(b4)) return;
						if(isDefibable(b4)) {
							b4.ReviveByDefib();
							::BotAI.Timers.AddTimerByName("HardResetRestore" + b4.GetEntityIndex(), 0.4, false, restoreStep, args4);
						} else {
							printl("[BotAI][HARDRESET] kill failed on " + BotAI.getPlayerBaseName(b4) + " (lifeState=" + NetProps.GetPropInt(b4, "m_lifeState") + " incap=" + (b4.IsIncapacitated() ? 1 : 0) + " dead=" + (b4.IsDead() ? 1 : 0) + "), state unchanged");
						}
					}
					::BotAI.Timers.AddTimerByName("HardResetLast" + b3.GetEntityIndex(), 0.4, false, lastStep, args3);
				}
			}
			::BotAI.Timers.AddTimerByName("HardResetFinish" + b.GetEntityIndex(), 0.3, false, finishStep, args);
			return;
		}
		printl("[BotAI][HARDRESET] kill failed on " + BotAI.getPlayerBaseName(b) + " (still standing, damage blocked?), state unchanged");
	}
	::BotAI.Timers.AddTimerByName("HardResetRevive" + idx, 0.3, false, reviveStep, {b = boto, pos = pos, hp = hp, items = items});
}

// watchdog 触发后的处置调度: 计数模式 (旧的 30s 时间窗口因 perf 卡顿+8s 去抖+5s 重新积累
// 经常溢出, 永远进不了硬重置). 改为: 60s 内累计触发次数 >= 2 -> 硬重置.
// 这是因为 fire-state 速砍每 tick 重新写 ForceButton(1), 软重置清的 m_afButtonForced
// 立刻被覆盖, 软重置实际可能完全无效 -> 软重置后再次被抓 = 软重置失败 -> 直接升级硬.
function BotAI::watchdogEscalate(boto, reason) {
	local idx = boto.GetEntityIndex();
	local now = Time();
	local lastReset = (idx in BotAI.WatchdogLastReset) ? BotAI.WatchdogLastReset[idx] : 0;
	if(now - lastReset < 8.0) return;

	// 60 秒内无触发 -> 计数清零
	local count = (idx in BotAI.WatchdogResetCount) ? BotAI.WatchdogResetCount[idx] : 0;
	if(now - lastReset > 60.0) count = 0;

	count++;
	BotAI.WatchdogResetCount[idx] <- count;
	BotAI.WatchdogLastReset[idx] <- now;

	// [暂时搁置硬重置] 误判触发率过高, 等准确判定条件落地后再启用. 当前 watchdog 触发一律走软重置.
	// if(count >= 2)
	//	BotAI.hardResetBot(boto, reason + " [escalated: soft reset failed]");
	// else
	BotAI.forceFullReset(boto, reason);
}

// 兜底监视器: 检测物品鬼畜切换僵死态, 与成因无关, 纯保险
// 关键鉴别: 真僵死时 bot 既不攻击也不推挤; 正常速砍时一直在开枪/砍.
// 所以只有 "高频切换 + 持续无攻击无推挤" 才判僵死, 避免误伤正常战斗.
function BotAI::watchdogCheck(boto) {
	if(!BotAI.IsEntityValid(boto)) return;
	if(!IsPlayerABot(boto)) return;

	local idx = boto.GetEntityIndex();
	local now = Time();

	// charger 释放保护窗内只静音 ABA, 不提前清 prop; 保护窗后才清残留假支配.
	if(BotAI.hasStaleChargerLock(boto)) {
		if(idx in BotAI.FireSuspendUntil && now < BotAI.FireSuspendUntil[idx])
			return;
		BotAI.clearStaleChargerLock(boto);
	}

	// 被支配状态只有"支配者还活着"才豁免; 支配者已死/无效 = 残留假支配, 必须继续监视,
	// 否则 watchdog 被它挡住就永远救不了卡死的 bot
	local dominated = boto.IsDominatedBySpecialInfected();
	if(dominated) {
		local dom = boto.GetSpecialInfectedDominatingMe();
		if(dom == null || !dom.IsValid() || !BotAI.IsAlive(dom))
			dominated = false;
	}

	// 治疗豁免带超时: 单次治疗 (medkit ~6s) 不可能超过 12 秒. 卡死 bot 会陷入
	// "反复尝试用包 -> 引擎拒绝 -> 重试" 的治疗循环, IsBotHealing 恒为 true,
	// 无限豁免会让 watchdog 永远救不了他 (Louis 实测案例)
	local healing = BotAI.IsBotHealing(boto);
	if(healing) {
		if(!(idx in BotAI.WatchdogHealStart)) BotAI.WatchdogHealStart[idx] <- now;
		if(now - BotAI.WatchdogHealStart[idx] >= 12.0)
			healing = false;
	} else if(idx in BotAI.WatchdogHealStart) {
		delete BotAI.WatchdogHealStart[idx];
	}

	// 跳过合法的冻结/受控态, 避免误伤
	if(boto.IsIncapacitated() || boto.IsHangingFromLedge() || dominated
		|| BotAI.isPlayerBeingRevived(boto) || BotAI.IsPlayerReviving(boto)
		|| healing) {
		if(idx in BotAI.WatchdogSwitchTimes) BotAI.WatchdogSwitchTimes[idx] <- [];
		BotAI.WatchdogLastActive[idx] <- now;
		return;
	}

	// 记录最近一次"攻击或推挤"的时间 (正常战斗的标志)
	if(BotAI.IsPressingAttack(boto) || BotAI.IsPressingShove(boto)) {
		BotAI.WatchdogLastActive[idx] <- now;
	}
	if(!(idx in BotAI.WatchdogLastActive)) BotAI.WatchdogLastActive[idx] <- now;

	local wep = boto.GetActiveWeapon();
	local cur = BotAI.IsEntityValid(wep) ? wep.GetClassname() : null;

	local last = (idx in BotAI.WatchdogLastWeapon) ? BotAI.WatchdogLastWeapon[idx] : null;
	BotAI.WatchdogLastWeapon[idx] <- cur;

	if(!(idx in BotAI.WatchdogSwitchTimes)) BotAI.WatchdogSwitchTimes[idx] <- [];
	local times = BotAI.WatchdogSwitchTimes[idx];

	// 武器 classname 变了 = 一次切换
	if(last != null && cur != null && cur != last) {
		times.append(now);
	}

	// 滑动窗口: 只保留近 5 秒内的切换记录
	while(times.len() > 0 && now - times[0] > 5.0) {
		times.remove(0);
	}

	// 僵死判定 (两个条件同时满足):
	// 1. 5 秒内切换 >= 12 次 (高频鬼畜)
	// 2. 距上次攻击/推挤已 >= 4 秒 (真卡死, 而非正常速砍战斗)
	local idleSinceAction = now - BotAI.WatchdogLastActive[idx];
	if(times.len() >= 12 && idleSinceAction >= 4.0) {
		BotAI.watchdogEscalate(boto, "rapid item-switch, " + times.len() + " switches/5s");
		return;
	}

	// [模式B] 空抖型僵死: 不切换物品, 持续尝试攻击但攻击从不生效 (m_flNextPrimaryAttack 不推进).
	// 注意: fire-state 的连发模拟每 tick 在按下/抬起间 toggle, 不能用 "当前没按攻击" 来刷新进度
	// (约一半采样会撞上抬起瞬间, 5 秒永远攒不满). 改为计数: 统计 5 秒窗口内的攻击尝试次数,
	// 只有真正的进度 (时间戳推进/推挤生效) 才清零. 待机 bot 不尝试攻击 -> 攒不出次数, 不误判;
	// 正常开火/挥砍每次都推进时间戳 -> 立即清零, 不误判.
	local wepNextAtk = BotAI.IsEntityValid(wep) ? NetProps.GetPropFloat(wep, "m_flNextPrimaryAttack") : 0.0;
	local lastNextAtk = (idx in BotAI.WatchdogLastNextAttack) ? BotAI.WatchdogLastNextAttack[idx] : wepNextAtk;
	BotAI.WatchdogLastNextAttack[idx] <- wepNextAtk;

	if(!(idx in BotAI.WatchdogProgressTime)) BotAI.WatchdogProgressTime[idx] <- now;
	if(!(idx in BotAI.WatchdogAtkAttempts)) BotAI.WatchdogAtkAttempts[idx] <- [];
	local attempts = BotAI.WatchdogAtkAttempts[idx];

	// 真进度: 时间戳被推进到未来 = 引擎真的执行了攻击 (开火/挥砍都会把 m_flNextPrimaryAttack
	// 设到未来值). 脚本的解卡写入是过去值 (Time()-1), 拿药时 fire-state 也每 tick 写过去值
	// -> 过去值一律不算进度, 防止假进度把检测喂死.
	if((wepNextAtk != lastNextAtk && wepNextAtk > now) || BotAI.IsPressingShove(boto)) {
		BotAI.WatchdogProgressTime[idx] <- now;
		attempts.clear();
	}

	// 攻击尝试: 按着攻击键或被强制按下攻击键
	if(BotAI.IsPressingAttack(boto) || BotAI.HasForcedButton(boto, 1)) {
		attempts.append(now);
	}

	// 滑动窗口: 只保留近 5 秒内的尝试记录
	while(attempts.len() > 0 && now - attempts[0] > 5.0) {
		attempts.remove(0);
	}

	// 5 秒无任何攻击进度 + 窗口内 >= 10 次攻击尝试 -> 空抖僵死
	local jitterTime = now - BotAI.WatchdogProgressTime[idx];
	if(jitterTime >= 5.0 && attempts.len() >= 10) {
		local reason = "idle-jitter, " + attempts.len() + " blocked attacks/" + jitterTime + "s";
		BotAI.WatchdogProgressTime[idx] <- now;
		attempts.clear();
		BotAI.watchdogEscalate(boto, reason);
	}
}

function BotAI::BotRetreatFrom(boto, otherEntity) {
	if(!BotAI.IsEntityValid(boto) || !BotAI.IsEntityValid(otherEntity)) return;
	if(!IsPlayerABot(boto))
		return;

	if(BotAI.IsPlayerClimb(boto))
		return;

	local now = Time();
	if(now - BotAI.getBotRetreatCooldown(boto) < 1.10) {
		if(BotAI.BotDebugMode) {
			printl("[Retreat Fail] " + BotAI.getPlayerBaseName(boto));
		}
		return;
	}

	if(BotAI.BotDebugMode) {
		printl("[Retreat] " + BotAI.getPlayerBaseName(boto));
	}

	BotAI.setBotRetreatCooldown(boto, now);
	return CommandABot( { cmd = 2, target = otherEntity, bot = boto } );
}

function BotAI::botCmdMove(boto, vector, ignoreCooldown = false) {
	if(!BotAI.IsEntityValid(boto)) return;

	if(!IsPlayerABot(boto))
		return;

	local now = Time();
	local interval = ignoreCooldown ? 0.35 : 1.25;
	if (now - BotAI.getBotMoveCooldown(boto) < interval) {
		if(BotAI.BotDebugMode) {
			printl("[Move Fail] " + BotAI.getPlayerBaseName(boto));
		}
		return;
	}

	if(BotAI.BotDebugMode) {
		printl("[Move] " + BotAI.getPlayerBaseName(boto));
	}

	BotAI.setBotMoveCooldown(boto, now);
	return CommandABot({ cmd = 1, pos = vector, bot = boto});
}

function BotAI::setMoveType(player, moveType) {
	if(!BotAI.IsEntityValid(player)) return;
	NetProps.SetPropInt(player, "movetype", moveType);
}

function BotAI::getMoveType(player) {
	if(!BotAI.IsEntityValid(player)) return;
	return NetProps.GetPropInt(player, "movetype");
}

function BotAI::getBotCombatSkill(player) {
	if(!BotAI.IsEntityValid(player)) return 0;

	return BotAI.BotCombatSkill;
}

function BotAI::areaAdjacent(area, i) {
	local adjacentAreas = {};
	area.GetAdjacentAreas(i, adjacentAreas);
	//BotAI.areaCache[key] <- adjacentAreas;
	return adjacentAreas;

	local key = area.GetID().tostring() + ":" + i.tostring();
	if(key in BotAI.areaCache) {
		return BotAI.areaCache[key];
	} else {

	}
}

function BotAI::isEntityEqual(entity, _entity) {
	if(entity == _entity) return true;

	if(BotAI.validVector(entity) && BotAI.validVector(_entity)) {
		if(entity.x == _entity.x && entity.y == _entity.y && entity.z == _entity.z)
			return true;
	}

	return false;
}

function BotAI::botStayPos(player, pos, id, priority = 4, stayTime = 3, distance = 100) {
	local littleBot = player;
	local dis = distance;
	local idStay = id + "Stay#";
	local stay = stayTime;

	local function changeAndStay() {
		if(!BotAI.IsAlive(littleBot)) return true;
		if(typeof pos != "Vector" && !BotAI.IsAlive(pos)) return true;
		local navigator = BotAI.getNavigator(littleBot);
		local position = Vector(0, 0, 0);
		if(typeof pos == "Vector")
			position = pos;
		else
			position = pos.GetOrigin();
		if(BotAI.distanceof(position, littleBot.GetOrigin()) <= dis) {
			navigator.clearPath(id);
			local timeGet = Time();
			local function tryStay() {
				if(Time() - timeGet > stay)
					return true;
				return false;
			}
			BotAI.botRunPos(littleBot, pos, idStay, priority, tryStay);
		}
		return false;
	}

	if(BotAI.botRunPos(player, pos, id, priority, changeAndStay)) {
		local position = Vector(0, 0, 0);
		if(typeof pos == "Vector")
			position = pos;
		else
			position = pos.GetOrigin();

		if (BotAI.BotDebugMode) {
			DebugDrawCircle(position, Vector(255, 0, 255), 0.2, 20, false, 2);
			DebugDrawCircle(position, Vector(255, 0, 255), 0.4, 16, false, 2.5);
			DebugDrawCircle(position, Vector(255, 0, 255), 0.6, 13, false, 3);
			DebugDrawCircle(position, Vector(255, 0, 255), 0.8, 10, false, 3.5);
			DebugDrawCircle(position, Vector(255, 0, 255), 1.0, 7, false, 4);
		}

		return true;
	}

	return false;
}

function BotAI::botRunPos(player, pos, id, priority = 0, discardFunc = BotAI.trueDude, distance = 7000, buildTest = false) {
	if(!buildTest && !IsPlayerABot(player))
		return false;

	if(BotAI.IsPlayerClimb(player) || BotAI.IsBotHealingOthers(player))
		return false;

	local navigator = BotAI.getNavigator(player);
	foreach(idx, path in navigator.pathCache) {
		if(idx == id && BotAI.isEntityEqual(path.pos, pos)) {
			navigator.run(id);
			if(BotAI.BotDebugMode) {
				printl("[Bot AI] rerun: " + id);
			}
			return true;
		}
	}

	if(discardFunc == "change") {
		local function change() {
			local navigator = BotAI.getNavigator(player);
			if(!navigator.isMoving(id))
				return true;
			return false;
		}

		discardFunc = change;
	}

	if(navigator.buildPath(pos, id, priority, discardFunc, distance)) {
		navigator.run(id);
		return true;
	}

	if(BotAI.BotDebugMode) {
		printl("[Bot AI] failed to build path: " + id);
	}

	return false;
}

function BotAI::SetButtonPressed(button)
{
	if(button.GetEntityIndex() in BotAI.ButtonPressed)
		BotAI.ButtonPressed[button.GetEntityIndex()] <- BotAI.ButtonPressed[button.GetEntityIndex()] + 1;
	else
		BotAI.ButtonPressed[button.GetEntityIndex()] <- 1;
}

function BotAI::IsButtonPressed(button)
{
	if(button.GetEntityIndex() in BotAI.ButtonPressed)
	{
		if(button.GetClassname() == "func_button")
		{
			local count = BotAI.ButtonPressed[button.GetEntityIndex()];
			if(count < 1)
				count = 1;
			local num = RandomInt(0, count * 2);

			if(num == 0)
				return false;
			else
				return true;
		}
		else
		{
			local num = RandomInt(0, 3);

			if(num == 0)
				return false;
			else
				return true;
		}
	}
	else
		return false;
}

function BotAI::getPlayerTotalHealth(player) {
	return player.GetHealth() + player.GetHealthBuffer();
}

::BotAI.SetPlayerReviving <- function(player, boolean) {
	if(!BotAI.IsEntityValid(player)) return;
	BotAI.NeedRevive[player.GetEntityIndex()] <- boolean;
}

::BotAI.IsPlayerReviving <- function (player) {
	if(!BotAI.IsEntityValid(player)) return false;
	return player.GetEntityIndex() in BotAI.NeedRevive && BotAI.NeedRevive[player.GetEntityIndex()];
}

::BotAI.SetPlayerRevived <- function(player, another) {
	BotAI.RevivedPlayer[player.GetEntityIndex()] <- another;
}

::BotAI.getPlayerRevived <- function (player) {
	if(player.GetEntityIndex() in BotAI.RevivedPlayer)
		return BotAI.RevivedPlayer[player.GetEntityIndex()];
	return null;
}

function BotAI::setPlayerBeingRevived(player, bol) {
	BotAI.BeingRevivedPlayer[player.GetEntityIndex()] <- bol;
}

function BotAI::isPlayerBeingRevived(player) {
	if(!BotAI.IsEntityValid(player)) return false;
	return player.GetEntityIndex() in BotAI.BeingRevivedPlayer && BotAI.BeingRevivedPlayer[player.GetEntityIndex()];
}

function BotAI::SetPlayerTarget(player, target)
{
	BotAI.TargetFind[player.GetEntityIndex()] <- target;
}

function BotAI::GetPlayerTarget(player)
{
	if(player.GetEntityIndex() in BotAI.TargetFind && BotAI.TargetFind[player.GetEntityIndex()] != null && BotAI.IsAlive(BotAI.TargetFind[player.GetEntityIndex()]))
		return BotAI.TargetFind[player.GetEntityIndex()];
	return null;
}
