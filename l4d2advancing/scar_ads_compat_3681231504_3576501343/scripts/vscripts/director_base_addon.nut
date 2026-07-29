IncludeScript("ads_base");

if(!IncludeScript("greenyoshiyt_scar"))
{
	printl("[SCAR-L Mode Selector][ERROR] ADS compatibility version could not load the SCAR fire-mode script");
}
else
{
	printl("[SCAR-L Mode Selector] ADS compatibility version loaded  (build: shove-fix v6 + full diag, 2026-07-29)");
}


// set hooks
// these are shared, and I like that each mod can work independently rather than having to subscribe to an extra library.
// hook can add to 'g_ModeScript, g_MapScript, getroottable()' scope, but only one will exec and follow 'g_ModeScript > g_MapScript > getroottable()' priority, so not add the low priority hook
if (!("L4D2Lxc_HOOKS" in getroottable()))
{
	::L4D2Lxc_HOOKS <-
	{
		Activator = null
		SkipFirstLoad = true // waiting for the second loading
		HookList =
		{
			["dmg"] = "AllowTakeDamage",
			["cmd"] = "UserConsoleCommand",
		}
		LXC =
		{
			AllowTakeDamage = {}
			UserConsoleCommand = {}
		}
		OTH =
		{
			AllowTakeDamage = {}
			UserConsoleCommand = {}
		}
		
		function AddHooks(scope, hook, name, func)
		{
			if (!(scope in this) || typeof(func) != "function")
				return false;
			
			local target = null;
			switch (hook)
			{
				case "dmg":
					target = "AllowTakeDamage";
					break;
				case "cmd":
					target = "UserConsoleCommand";
					break;
			}
			
			if (!target)
				return false;
			
			this[scope][target][name] <- func;
			
			return true;
		}
		
		function RemoveHooks(scope, hook, name)
		{
			if (!(scope in this))
				return false;
			
			local target = null;
			switch (hook)
			{
				case "dmg":
					target = "AllowTakeDamage";
					break;
				case "cmd":
					target = "UserConsoleCommand";
					break;
			}
			
			if (!target || !(name in this[scope][target]))
				return false;
			
			return delete this[scope][target][name];
		}
		
		function ClearHooks()
		{
			local g_RootScript = getroottable();
			foreach (hook in HookList)
			{
				LXC[hook].clear();
				OTH[hook].clear();
				
				local hook_func = this["Hook_" + hook];
				if (hook in g_ModeScript && g_ModeScript[hook] == hook_func)
					delete g_ModeScript[hook];
				if (hook in g_MapScript && g_MapScript[hook] == hook_func)
					delete g_MapScript[hook];
				if (hook in g_RootScript && g_RootScript[hook] == hook_func)
					delete g_RootScript[hook];
			}
		}
		
		function Hook_AllowTakeDamage(damageTable)
		{
			local Damage = true;
			
			foreach (name, func in ::L4D2Lxc_HOOKS.LXC.AllowTakeDamage)
			{
				try
				{
					if (func(damageTable) == false)
						Damage = false;
				}
				catch(exception)
				{
					error("L4D2Lxc_HOOKS.LXC.AllowTakeDamage - error in func \"" + name + "\": " + exception);
				}
			}
			
			foreach (name, func in ::L4D2Lxc_HOOKS.OTH.AllowTakeDamage)
			{
				try
				{
					if (func(damageTable) == false)
						Damage = false;
				}
				catch(exception)
				{
					error("L4D2Lxc_HOOKS.OTH.AllowTakeDamage - error in func \"" + name + "\": " + exception);
				}
			}
			
			return Damage;
		}
		
		function Hook_UserConsoleCommand(playerScript, arg)
		{
			foreach (name, func in ::L4D2Lxc_HOOKS.LXC.UserConsoleCommand)
			{
				try
				{
					func(playerScript, arg);
				}
				catch(exception)
				{
					error("L4D2Lxc_HOOKS.LXC.UserConsoleCommand - error in func \"" + name + "\": " + exception);
				}
			}
			
			foreach (name, func in ::L4D2Lxc_HOOKS.OTH.UserConsoleCommand)
			{
				try
				{
					func(playerScript, arg);
				}
				catch(exception)
				{
					error("L4D2Lxc_HOOKS.OTH.UserConsoleCommand - error in func \"" + name + "\": " + exception);
				}
			}
		}
		
		function SetScriptedModeHooks()
		{
			printl("L4D2Lxc_HOOKS: Set Scripted Mode Hooks. Activator: " + Activator);
			
			// set Hook from list
			local g_RootScript = getroottable();
			foreach (alt_name, hook in HookList)
			{
				local hook_func = this["Hook_" + hook];
				if ("HooksHub" in g_RootScript) //Left 4 Lib, used for Left 4 Bots, Left 4 Bots 2
				{
					HooksHub["Set" + hook]("LXC_HOOKS", hook_func);
				}
				else if ("VSLib" in g_RootScript) //it should be fine
				{
					local mode = hook in g_ModeScript ? delete g_ModeScript[hook] : hook_func;
					local root = hook in g_RootScript ? delete g_RootScript[hook] : mode;
					if (mode != hook_func)
						AddHooks("OTH", alt_name, "Mode", mode);
					if (root != mode)
						AddHooks("OTH", alt_name, "Root", root);
					
					g_ModeScript[hook] <- hook_func;
					g_RootScript[hook] <- hook_func;
				}
				else
				{
					if (hook in g_ModeScript && g_ModeScript[hook] != hook_func)
					{
						local mode = delete g_ModeScript[hook];
						if (mode)
							AddHooks("OTH", alt_name, "Mode", mode);
					}
					else if (hook in g_MapScript && g_MapScript[hook] != hook_func)
					{
						local map = delete g_MapScript[hook];
						if (map)
							AddHooks("OTH", alt_name, "Map", map);
					}
					else if (hook in g_RootScript && g_RootScript[hook] != hook_func)
					{
						local root = delete g_RootScript[hook];
						if (root)
							AddHooks("OTH", alt_name, "Root", root);
					}
					
					g_ModeScript[hook] <- hook_func;
					//g_MapScript[hook] <- hook_func;
					g_RootScript[hook] <- hook_func;
				}
			}
		}
		
		function Initialize(caller)
		{
			if (Activator == null)
				Activator = caller;
			
			if (SkipFirstLoad)
			{
				SkipFirstLoad = false;
				return;
			}
			
			if (caller != Activator)
				return;
			
			SkipFirstLoad = true; //if round restarts, this will fix something
			SetScriptedModeHooks();
		}
		
		function OnGameEnd()
		{
			Activator = null;
			SkipFirstLoad = true;
			ClearHooks();
		}
		
		function OnGameEvent_round_end(params)
		{
			OnGameEnd();
		}
	}
}
// prevent multiple executions
if (!("L4D2Lxc_HOOKS_Initialized" in this))
{
	::L4D2Lxc_HOOKS.Initialize("ADS");
	L4D2Lxc_HOOKS_Initialized <- true;
}
__CollectEventCallbacks(::L4D2Lxc_HOOKS, "OnGameEvent_", "GameEventCallbacks", ::RegisterScriptGameEventListener);

