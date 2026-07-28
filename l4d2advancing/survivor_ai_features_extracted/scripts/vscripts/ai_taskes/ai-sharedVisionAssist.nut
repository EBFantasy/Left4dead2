class ::AITaskSharedVisionAssist extends AITaskGroup {
	constructor(orderIn, tickIn, compatibleIn, forceIn) {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
		name = "sharedVisionAssist";
    }

	name = "sharedVisionAssist";
	updating = false;
	playerList = {};
	assignments = {};
	sharedTargets = {};
	assistTargets = {};

	function preCheck() {
		sharedTargets = {};
		assistTargets = {};
		assignments = {};

		if(BotAI.SurvivorHumanList.len() <= 0)
			return false;

		BotAI.updateSharedVisionTargets();
		sharedTargets = BotAI.SharedVisionTargets;
		assistTargets = BotAI.findHumanCrowdAssistTargets();

		return sharedTargets.len() > 0 || assistTargets.len() > 0;
	}

	function GroupUpdateChecker(player) {
		if(!BotAI.isBotAvailableForAssist(player))
			return false;

		if(player in BotAI.ManualMedical || player in BotAI.ManualUse)
			return false;

		local best = null;
		local bestScore = -999999.0;

		foreach(_, data in assistTargets) {
			if(!("target" in data) || !BotAI.IsEntityValid(data.target))
				continue;
			if(!("need" in data) || !("assigned" in data) || data.assigned >= data.need)
				continue;

			local dis = BotAI.distanceof(player.GetOrigin(), data.target.GetOrigin());
			if(dis > 1300)
				continue;

			local score = 5000.0 - dis + data.count * 55.0;
			if(score > bestScore) {
				bestScore = score;
				best = data;
			}
		}

		if(best != null) {
			best.assigned++;
			assignments[player] <- { mode = "assist", data = best };
			return true;
		}

		foreach(_, data in sharedTargets) {
			if(!("target" in data) || !BotAI.IsAlive(data.target))
				continue;

			local target = data.target;
			local dis = BotAI.distanceof(player.GetOrigin(), target.GetOrigin());
			if(dis > data.botRange)
				continue;

			if(!BotAI.CanShotOtherEntityInSight(player, target, -1))
				continue;

			local priority = data.priority;
			local score = priority * 1000.0 - dis;
			if(score > bestScore) {
				bestScore = score;
				best = data;
			}
		}

		if(best != null) {
			assignments[player] <- { mode = "vision", data = best };
			return true;
		}

		return false;
	}

	function playerUpdate(player) {
		if(!(player in assignments)) {
			updating = false;
			return;
		}

		local assignment = assignments[player];
		local data = assignment.data;

		if(assignment.mode == "vision") {
			local target = data.target;
			if(BotAI.IsAlive(target) && BotAI.CanShotOtherEntityInSight(player, target, -1)) {
				BotAI.BotAttack(player, target);
				if(BotAI.nextTickDistance(player, target, 5.0) < 100)
					BotAI.setBotShoveTarget(player, target);
			}
		} else {
			local human = data.target;
			local infected = data.infected;
			if(BotAI.IsPlayerEntityValid(human) && BotAI.IsAlive(infected)) {
				local disToHuman = BotAI.distanceof(player.GetOrigin(), human.GetOrigin());
				local disToInfected = BotAI.distanceof(player.GetOrigin(), infected.GetOrigin());

				if(disToHuman > 360) {
					local h = human;
					local function done() {
						if(!BotAI.IsPlayerEntityValid(h)) return true;
						return BotAI.distanceof(player.GetOrigin(), h.GetOrigin()) < 260;
					}
					BotAI.botRunPos(player, human, "assistHuman$", 2, done, 1400);
				}

				if(BotAI.CanShotOtherEntityInSight(player, infected, -1)) {
					BotAI.BotAttack(player, infected);
					if(disToInfected < 110)
						BotAI.setBotShoveTarget(player, infected);
				} else if(disToHuman < 300) {
					BotAI.setBotTarget(player, infected);
					if(disToInfected < 130)
						BotAI.setBotShoveTarget(player, infected);
				}
			}
		}

		if(player in assignments)
			delete assignments[player];
		updating = false;
	}

	function taskReset(player = null) {
		base.taskReset(player);
		if(player != null && player in assignments)
			delete assignments[player];
	}
}
