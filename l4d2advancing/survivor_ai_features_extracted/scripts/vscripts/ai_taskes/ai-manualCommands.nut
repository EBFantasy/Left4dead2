class ::AITaskManualMedical extends AITaskSingle {
	constructor(orderIn, tickIn, compatibleIn, forceIn) {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
		name = "manualMedical";
    }

	name = "manualMedical";
	single = true;
	updating = {};
	playerTick = {};

	function singleUpdateChecker(player) {
		if(!(player in BotAI.ManualMedical))
			return false;

		local data = BotAI.ManualMedical[player];
		if(!BotAI.IsEntitySurvivorBot(player) || !BotAI.IsAlive(player) || Time() > data.until) {
			BotAI.cancelManualMedical(player);
			return false;
		}

		if(player.IsDominatedBySpecialInfected() || player.IsIncapacitated() || player.IsHangingFromLedge() || BotAI.isChargerWeaponLockout(player))
			return false;

		if(!BotAI.manualMedicalHasItem(player, data.kind)) {
			BotAI.cancelManualMedical(player);
			return false;
		}

		return true;
	}

	function playerUpdate(player) {
		if(!(player in BotAI.ManualMedical)) {
			updating[player] <- false;
			return;
		}

		local data = BotAI.ManualMedical[player];
		local item = BotAI.getManualMedicalItem(player, data.kind);
		if(!BotAI.IsEntityValid(item)) {
			BotAI.cancelManualMedical(player);
			updating[player] <- false;
			return;
		}

		local classname = item.GetClassname();
		if(data.kind == "kit") {
			if(BotAI.protectManualKitAction(player, Convars.GetFloat("first_aid_kit_use_duration") + 0.5))
				BotAI.ManualMedical[player].started = true;
		} else {
			if(player.GetActiveWeapon() == null || player.GetActiveWeapon().GetClassname() != classname)
				player.SwitchToItem(classname);

			local active = player.GetActiveWeapon();
			if(BotAI.IsEntityValid(active))
				NetProps.SetPropFloat(active, "m_flNextPrimaryAttack", Time() - 1);

			BotAI.ForceButton(player, 1, 0.35);
			if(data.kind == "adrenaline")
				player.UseAdrenaline(2);
			BotAI.ManualMedical[player].started = true;
			if(!BotAI.manualMedicalHasItem(player, data.kind))
				BotAI.cancelManualMedical(player);
		}

		updating[player] <- false;
	}

	function taskReset(player = null) {
		base.taskReset(player);
	}
}

class ::AITaskManualUse extends AITaskSingle {
	constructor(orderIn, tickIn, compatibleIn, forceIn) {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
		name = "manualUse";
    }

	name = "manualUse";
	single = true;
	updating = {};
	playerTick = {};

	function singleUpdateChecker(player) {
		if(!(player in BotAI.ManualUse))
			return false;

		local data = BotAI.ManualUse[player];
		if(!BotAI.IsEntitySurvivorBot(player) || !BotAI.IsAlive(player) || Time() > data.until) {
			BotAI.cancelManualUse(player);
			return false;
		}

		if(player.IsDominatedBySpecialInfected() || player.IsIncapacitated() || player.IsHangingFromLedge() || BotAI.isChargerWeaponLockout(player)) {
			BotAI.ClearForcedButton(player, 32);
			data.until = Time() + 45.0;
			data.validated = false;
			data.holdStarted = false;
			data.tapUntil = Time() + 1.0;
			BotAI.ManualUse[player] = data;
			return false;
		}

		if(BotAI.shouldPauseManualUse(player)) {
			BotAI.ClearForcedButton(player, 32);
			data.until = Time() + 45.0;
			data.validated = false;
			data.holdStarted = false;
			data.tapUntil = Time() + 1.0;
			BotAI.ManualUse[player] = data;
			return false;
		}

		if(!BotAI.IsEntityValid(data.entity) && typeof data.pos != "Vector") {
			BotAI.cancelManualUse(player);
			return false;
		}

		return true;
	}

	function playerUpdate(player) {
		if(!(player in BotAI.ManualUse)) {
			updating[player] <- false;
			return;
		}

		local data = BotAI.ManualUse[player];
		if(!("tapUntil" in data))
			data.tapUntil <- data.start + 1.0;
		if(!("holdStarted" in data))
			data.holdStarted <- false;

		if(BotAI.shouldPauseManualUse(player)) {
			BotAI.ClearForcedButton(player, 32);
			data.until = Time() + 45.0;
			data.validated = false;
			data.holdStarted = false;
			data.tapUntil = Time() + 1.0;
			BotAI.ManualUse[player] = data;
			updating[player] <- false;
			return;
		}

		local entity = data.entity;
		local pos = data.pos;
		if(BotAI.IsEntityValid(entity))
			pos = BotAI.getEntityAimPoint(entity);

		local dis = BotAI.distanceof(player.GetOrigin(), pos);
		if(dis > 125) {
			local targetPos = pos;
			local function done() {
				return BotAI.distanceof(player.GetOrigin(), targetPos) < 95;
			}
			BotAI.botRunPos(player, targetPos, "manualUse$", 4, done, 1600);
			updating[player] <- false;
			return;
		}

		local entityClass = "";
		if(BotAI.IsEntityValid(entity))
			entityClass = entity.GetClassname();

		local canUseEntity = BotAI.IsEntityValid(entity) && BotAI.IsTriggerUsable(entity);
		local probing = !data.validated && Time() <= data.tapUntil;

		if(BotAI.IsEntityValid(entity)) {
			BotAI.SetTarget(player, entity);
			BotAI.lookAtEntity(player, entity, true, 0.4);
			if(probing || !data.holdStarted)
				DoEntFire("!self", "Use", "", 0, player, entity);
		} else {
			BotAI.lookAtPosition(player, pos, true, 0.4);
		}

		if(canUseEntity || data.validated) {
			BotAI.RefreshForceButton(player, 32, 1.25);
			data.holdStarted = true;
		} else {
			BotAI.ForceButton(player, 32, 0.35);
		}

		if(!data.validated) {
			if(canUseEntity || Time() > data.tapUntil) {
				data.validated = canUseEntity;
				data.validateTime = Time();
			}
		}

		BotAI.ManualUse[player] = data;

		if(!data.validated && Time() > data.tapUntil) {
			BotAI.cancelManualUse(player);
			updating[player] <- false;
			return;
		}

		if(BotAI.IsEntityValid(entity) && data.validated && !BotAI.IsTriggerUsable(entity) && Time() - data.validateTime > 0.8) {
			if(entityClass == "func_button_timed") {
				local rawUsable = true;
				local useOwner = null;
				try { rawUsable = NetProps.GetPropInt(entity, "m_usable") == 1; } catch(e0) {}
				try { useOwner = NetProps.GetPropEntity(entity, "m_useActionOwner"); } catch(e1) {}

				if(!rawUsable && (!BotAI.IsEntityValid(useOwner) || useOwner != player))
					BotAI.cancelManualUse(player);
			} else {
				BotAI.cancelManualUse(player);
			}
		}

		updating[player] <- false;
	}

	function taskReset(player = null) {
		base.taskReset(player);
	}
}
