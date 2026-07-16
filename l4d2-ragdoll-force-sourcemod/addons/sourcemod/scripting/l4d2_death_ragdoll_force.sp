// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 EpicBF

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin myinfo =
{
    name = "L4D2 Ragdoll Force",
    author = "EpicBF",
    description = "Adds configurable death-only ragdoll force for supported weapon kills.",
    version = "0.3.4",
    url = ""
};

#define MAX_PENDING_PUSHES 32

ConVar gCvarEnable;
ConVar gCvarShotgunForce;
ConVar gCvarAwpForce;
ConVar gCvarHunterJockeyMult;
ConVar gCvarMediumMult;
ConVar gCvarUpMult;
ConVar gCvarAimZMult;
ConVar gCvarDamageForceScale;
ConVar gCvarPreDeathPush;
ConVar gCvarPreDeathVelocityScale;
ConVar gCvarEntityPush;
ConVar gCvarEntityVelocityScale;
ConVar gCvarMatchRadius;
ConVar gCvarDebug;

bool gHookedClient[MAXPLAYERS + 1];
bool gPendingActive[MAX_PENDING_PUSHES];
float gPendingOrigin[MAX_PENDING_PUSHES][3];
float gPendingVelocity[MAX_PENDING_PUSHES][3];
float gPendingExpireTime[MAX_PENDING_PUSHES];
char gPendingVictimName[MAX_PENDING_PUSHES][32];
int gPendingVictimUserId[MAX_PENDING_PUSHES];
int gPendingVictimEntRef[MAX_PENDING_PUSHES];
bool gPendingFallbackLogged[MAX_PENDING_PUSHES];
int gPendingCursor;

public void OnPluginStart()
{
    gCvarEnable = CreateConVar("l4d2_ragdoll_force_enable", "1", "Enable death-only ragdoll force.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    gCvarShotgunForce = CreateConVar("l4d2_ragdoll_force_shotgun", "7800.0", "Base force for shotgun death ragdolls.", FCVAR_NOTIFY, true, 0.0, true, 30000.0);
    gCvarAwpForce = CreateConVar("l4d2_ragdoll_force_awp", "9800.0", "Base force for AWP death ragdolls.", FCVAR_NOTIFY, true, 0.0, true, 40000.0);
    gCvarHunterJockeyMult = CreateConVar("l4d2_ragdoll_force_hunter_jockey_mult", "2.20", "Force multiplier for hunter and jockey ragdolls.", FCVAR_NOTIFY, true, 0.0, true, 8.0);
    gCvarMediumMult = CreateConVar("l4d2_ragdoll_force_medium_mult", "1.55", "Force multiplier for smoker, boomer, spitter, and witch ragdolls.", FCVAR_NOTIFY, true, 0.0, true, 6.0);
    gCvarUpMult = CreateConVar("l4d2_ragdoll_force_up_mult", "0.24", "Vertical lift multiplier applied to the death ragdoll force.", FCVAR_NOTIFY, true, 0.0, true, 2.0);
    gCvarAimZMult = CreateConVar("l4d2_ragdoll_force_aim_z_mult", "0.70", "How much vertical shot direction contributes to ragdoll force. Positive pushes upward shots up and downward shots down.", FCVAR_NOTIFY, true, 0.0, true, 2.0);
    gCvarDamageForceScale = CreateConVar("l4d2_ragdoll_force_damageforce_scale", "6.0", "Scale applied to SDKHooks damageForce. Higher values make death impulse more visible.", FCVAR_NOTIFY, true, 0.0, true, 30.0);
    gCvarPreDeathPush = CreateConVar("l4d2_ragdoll_force_predeath_push", "1", "Apply a short velocity to the victim on the lethal damage frame so client ragdolls inherit motion.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    gCvarPreDeathVelocityScale = CreateConVar("l4d2_ragdoll_force_predeath_velocity_scale", "0.28", "Scale for lethal-frame victim velocity. This is separate from damageForce.", FCVAR_NOTIFY, true, 0.0, true, 2.0);
    gCvarEntityPush = CreateConVar("l4d2_ragdoll_force_entity_push", "1", "Also push the spawned ragdoll entity after death. Use this when damageForce is ignored.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    gCvarEntityVelocityScale = CreateConVar("l4d2_ragdoll_force_entity_velocity_scale", "0.32", "Scale applied when converting damage force to ragdoll entity velocity.", FCVAR_NOTIFY, true, 0.0, true, 4.0);
    gCvarMatchRadius = CreateConVar("l4d2_ragdoll_force_match_radius", "420.0", "Maximum distance for matching a newly spawned ragdoll to a recent kill.", FCVAR_NOTIFY, true, 32.0, true, 1024.0);
    gCvarDebug = CreateConVar("l4d2_ragdoll_force_debug", "1", "Print ragdoll force debug lines to the server console.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    EnsureEmsConfig();
    RegAdminCmd("sm_ragdoll_force_reload_ems", Command_ReloadEms, ADMFLAG_GENERIC, "Reload ems/ragdoll_force/settings.txt.");

    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client))
        {
            HookClientDamage(client);
        }
    }

    HookExistingWitches();
    AutoExecConfig(true, "l4d2_death_ragdoll_force");
}

public void OnConfigsExecuted()
{
    LoadEmsConfig();
}

public Action Command_ReloadEms(int client, int args)
{
    LoadEmsConfig();
    ReplyToCommand(client, "[RagdollForce] Reloaded ems/ragdoll_force/settings.txt.");
    return Plugin_Handled;
}

void GetEmsConfigPath(char[] path, int pathLength)
{
    char emsDirectory[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, emsDirectory, sizeof(emsDirectory), "../../ems");
    if (!DirExists(emsDirectory))
    {
        CreateDirectory(emsDirectory, 511);
    }

    char directory[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, directory, sizeof(directory), "../../ems/ragdoll_force");
    if (!DirExists(directory))
    {
        CreateDirectory(directory, 511);
    }

    BuildPath(Path_SM, path, pathLength, "../../ems/ragdoll_force/settings.txt");
}

void EnsureEmsConfig()
{
    char path[PLATFORM_MAX_PATH];
    GetEmsConfigPath(path, sizeof(path));
    if (FileExists(path))
    {
        return;
    }

    File file = OpenFile(path, "w");
    if (file == null)
    {
        LogError("[RagdollForce] Could not create EMS config: %s", path);
        return;
    }

    file.WriteLine("// ============================================================");
    file.WriteLine("// 中文说明（请先阅读）");
    file.WriteLine("// 本文件是 Ragdoll Force SourceMod 版的最终参数覆盖层；它在普通 CFG 之后加载。");
    file.WriteLine("// 修改后执行 sm_ragdoll_force_reload_ems，或重新载入地图。");
    file.WriteLine("// 基础关系：最终基础力 = shotgun_force 或 awp_force × 对应特感倍率。");
    file.WriteLine("// damageforce_scale、predeath_velocity_scale 和 entity_velocity_scale 会在不同推力通道继续缩放效果。");
    file.WriteLine("// 多个参数同时提高会产生叠加甚至近似乘法放大；建议每次只改一项，并以 10% 至 15% 为步长测试。");
    file.WriteLine("// enable：有效值 0 或 1；建议 1。0 会关闭插件。");
    file.WriteLine("// shotgun_force：有效范围 0 至 30000；建议 3000 至 16000；默认 7800。");
    file.WriteLine("// awp_force：有效范围 0 至 40000；建议 4000 至 20000；默认 9800。");
    file.WriteLine("// hunter_jockey_mult：有效范围 0 至 8；建议 0.50 至 4.00；默认 2.20。");
    file.WriteLine("// medium_mult：控制 Smoker、Boomer、Spitter 和 Witch；有效范围 0 至 6；建议 0.50 至 3.00；默认 1.55。");
    file.WriteLine("// up_mult：基础垂直抬升倍率；有效范围 0 至 2；建议 0.05 至 0.60；默认 0.24。");
    file.WriteLine("// aim_z_mult：瞄准俯仰对垂直力的影响倍率；有效范围 0 至 2；建议 0 至 1.20；默认 0.70。");
    file.WriteLine("// damageforce_scale：SDKHooks 伤害力缩放；有效范围 0 至 30；建议 1 至 12；默认 6。");
    file.WriteLine("// predeath_push：有效值 0 或 1；建议 1。控制致死帧活体速度推力。");
    file.WriteLine("// predeath_velocity_scale：有效范围 0 至 2；建议 0.05 至 0.65；默认 0.28。");
    file.WriteLine("// entity_push：有效值 0 或 1；建议 1。控制尸体实体生成后的补充推力。");
    file.WriteLine("// entity_velocity_scale：有效范围 0 至 4；建议 0.05 至 0.80；默认 0.32。");
    file.WriteLine("// match_radius：有效范围 32 至 1024；建议 200 至 600；默认 420。过大会把推力匹配到错误尸体。");
    file.WriteLine("// debug：有效值 0 或 1；正常使用建议 0，排查时临时设为 1。");
    file.WriteLine("// 注意：插件只处理受支持武器造成的致死击杀；Charger 和 Tank 仍被排除，EMS 不能解除该限制。");
    file.WriteLine("// 注意：不要与 Ragdoll Force VScript/VPK 版同时启用，否则效果会叠加。");
    file.WriteLine("// 注意：超出有效范围、非数字值和未知键会被忽略，并写入 SourceMod 错误日志。");
    file.WriteLine("// ============================================================");
    file.WriteLine("// English guide");
    file.WriteLine("// This file is the final override layer for the Ragdoll Force SourceMod edition and loads after the normal CFG.");
    file.WriteLine("// Run sm_ragdoll_force_reload_ems after editing, or reload the map.");
    file.WriteLine("// Base relationship: final base force = shotgun_force or awp_force multiplied by the matching infected multiplier.");
    file.WriteLine("// damageforce_scale, predeath_velocity_scale, and entity_velocity_scale further scale separate push channels.");
    file.WriteLine("// Raising several values together compounds the result and may behave approximately multiplicatively. Change one value at a time in 10% to 15% steps.");
    file.WriteLine("// enable: valid 0 or 1; recommended 1. Set 0 to disable the plugin.");
    file.WriteLine("// shotgun_force: valid 0 to 30000; recommended 3000 to 16000; default 7800.");
    file.WriteLine("// awp_force: valid 0 to 40000; recommended 4000 to 20000; default 9800.");
    file.WriteLine("// hunter_jockey_mult: valid 0 to 8; recommended 0.50 to 4.00; default 2.20.");
    file.WriteLine("// medium_mult: affects Smoker, Boomer, Spitter, and Witch; valid 0 to 6; recommended 0.50 to 3.00; default 1.55.");
    file.WriteLine("// up_mult: base vertical lift multiplier; valid 0 to 2; recommended 0.05 to 0.60; default 0.24.");
    file.WriteLine("// aim_z_mult: vertical aim contribution multiplier; valid 0 to 2; recommended 0 to 1.20; default 0.70.");
    file.WriteLine("// damageforce_scale: SDKHooks damage-force scale; valid 0 to 30; recommended 1 to 12; default 6.");
    file.WriteLine("// predeath_push: valid 0 or 1; recommended 1. Controls lethal-frame living-entity velocity.");
    file.WriteLine("// predeath_velocity_scale: valid 0 to 2; recommended 0.05 to 0.65; default 0.28.");
    file.WriteLine("// entity_push: valid 0 or 1; recommended 1. Controls the post-spawn ragdoll-entity fallback push.");
    file.WriteLine("// entity_velocity_scale: valid 0 to 4; recommended 0.05 to 0.80; default 0.32.");
    file.WriteLine("// match_radius: valid 32 to 1024; recommended 200 to 600; default 420. Excessive values can match the wrong ragdoll.");
    file.WriteLine("// debug: valid 0 or 1; recommended 0 normally and 1 only while diagnosing.");
    file.WriteLine("// Note: only lethal kills from supported weapons are handled. Charger and Tank remain excluded and EMS cannot remove that restriction.");
    file.WriteLine("// Note: do not enable the Ragdoll Force VScript/VPK edition at the same time because the effects will stack.");
    file.WriteLine("// Note: out-of-range values, non-numeric values, and unknown keys are ignored and logged by SourceMod.");
    file.WriteLine("// ============================================================");
    file.WriteLine("enable 1");
    file.WriteLine("shotgun_force 7800.0");
    file.WriteLine("awp_force 9800.0");
    file.WriteLine("hunter_jockey_mult 2.20");
    file.WriteLine("medium_mult 1.55");
    file.WriteLine("up_mult 0.24");
    file.WriteLine("aim_z_mult 0.70");
    file.WriteLine("damageforce_scale 6.0");
    file.WriteLine("predeath_push 1");
    file.WriteLine("predeath_velocity_scale 0.28");
    file.WriteLine("entity_push 1");
    file.WriteLine("entity_velocity_scale 0.32");
    file.WriteLine("match_radius 420.0");
    file.WriteLine("debug 0");
    delete file;
}

void LoadEmsConfig()
{
    EnsureEmsConfig();

    char path[PLATFORM_MAX_PATH];
    GetEmsConfigPath(path, sizeof(path));
    File file = OpenFile(path, "r");
    if (file == null)
    {
        LogError("[RagdollForce] Could not read EMS config: %s", path);
        return;
    }

    char line[256];
    int loaded = 0;
    while (!file.EndOfFile() && file.ReadLine(line, sizeof(line)))
    {
        TrimString(line);
        if (line[0] == '\0' || line[0] == '#' || line[0] == ';'
            || (line[0] == '/' && line[1] == '/'))
        {
            continue;
        }

        ReplaceString(line, sizeof(line), "\t", " ");
        char fields[2][64];
        if (ExplodeString(line, " ", fields, sizeof(fields), sizeof(fields[]), true) < 2)
        {
            continue;
        }

        TrimString(fields[1]);
        float value;
        if (StringToFloatEx(fields[1], value) == 0)
        {
            LogError("[RagdollForce] Ignored non-numeric EMS value: %s", fields[0]);
            continue;
        }

        ConVar cvar = GetEmsConVar(fields[0]);
        if (cvar == null)
        {
            LogError("[RagdollForce] Ignored unknown EMS key: %s", fields[0]);
            continue;
        }

        float lower;
        float upper;
        bool hasLower = cvar.GetBounds(ConVarBound_Lower, lower);
        bool hasUpper = cvar.GetBounds(ConVarBound_Upper, upper);
        if ((hasLower && value < lower) || (hasUpper && value > upper))
        {
            LogError("[RagdollForce] Ignored EMS value outside ConVar bounds: %s", fields[0]);
            continue;
        }

        cvar.SetFloat(value);
        loaded++;
    }

    delete file;
    PrintToServer("[RagdollForce] Loaded %d EMS settings from %s", loaded, path);
}

ConVar GetEmsConVar(const char[] key)
{
    if (StrEqual(key, "enable")) return gCvarEnable;
    if (StrEqual(key, "shotgun_force")) return gCvarShotgunForce;
    if (StrEqual(key, "awp_force")) return gCvarAwpForce;
    if (StrEqual(key, "hunter_jockey_mult")) return gCvarHunterJockeyMult;
    if (StrEqual(key, "medium_mult")) return gCvarMediumMult;
    if (StrEqual(key, "up_mult")) return gCvarUpMult;
    if (StrEqual(key, "aim_z_mult")) return gCvarAimZMult;
    if (StrEqual(key, "damageforce_scale")) return gCvarDamageForceScale;
    if (StrEqual(key, "predeath_push")) return gCvarPreDeathPush;
    if (StrEqual(key, "predeath_velocity_scale")) return gCvarPreDeathVelocityScale;
    if (StrEqual(key, "entity_push")) return gCvarEntityPush;
    if (StrEqual(key, "entity_velocity_scale")) return gCvarEntityVelocityScale;
    if (StrEqual(key, "match_radius")) return gCvarMatchRadius;
    if (StrEqual(key, "debug")) return gCvarDebug;
    return null;
}

public void OnClientPutInServer(int client)
{
    HookClientDamage(client);
}

public void OnClientDisconnect(int client)
{
    gHookedClient[client] = false;
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (StrEqual(classname, "witch", false))
    {
        SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
        return;
    }

    if (StrContains(classname, "ragdoll", false) != -1)
    {
        SDKHook(entity, SDKHook_SpawnPost, OnRagdollSpawned);
    }
}

public void OnRagdollSpawned(int entity)
{
    if (!gCvarEnable.BoolValue || !gCvarEntityPush.BoolValue)
    {
        return;
    }

    CreateTimer(0.03, Timer_ApplyPendingPushToRagdoll, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
}

void HookClientDamage(int client)
{
    if (client <= 0 || client > MaxClients || gHookedClient[client])
    {
        return;
    }

    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    gHookedClient[client] = true;
}

void HookExistingWitches()
{
    int maxEntities = GetMaxEntities();
    char classname[64];

    for (int entity = MaxClients + 1; entity <= maxEntities; entity++)
    {
        if (!IsValidEntity(entity))
        {
            continue;
        }

        if (!GetEntityClassname(entity, classname, sizeof(classname)))
        {
            continue;
        }

        if (StrEqual(classname, "witch", false))
        {
            SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
        }
    }
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype,
    int &weapon, float damageForce[3], float damagePosition[3])
{
    if (!gCvarEnable.BoolValue || damage <= 0.0)
    {
        return Plugin_Continue;
    }

    int shooter = ResolveSurvivorAttacker(attacker, inflictor, weapon);
    if (!IsValidSurvivorAttacker(shooter))
    {
        return Plugin_Continue;
    }

    char weaponName[64];
    int weaponKind = GetAllowedWeaponKind(shooter, inflictor, weapon, weaponName, sizeof(weaponName));
    if (weaponKind == 0)
    {
        return Plugin_Continue;
    }

    float victimMult = GetVictimForceMultiplier(victim);
    if (victimMult <= 0.0)
    {
        return Plugin_Continue;
    }

    if (!WillDamageKill(victim, damage))
    {
        return Plugin_Continue;
    }

    float baseForce = (weaponKind == 2) ? gCvarAwpForce.FloatValue : gCvarShotgunForce.FloatValue;
    float force = baseForce * victimMult;
    float forceVector[3];
    BuildDeathForceVector(shooter, victim, force, forceVector);

    float damageScale = gCvarDamageForceScale.FloatValue;
    damageForce[0] += forceVector[0] * damageScale;
    damageForce[1] += forceVector[1] * damageScale;
    damageForce[2] += forceVector[2] * damageScale;

    char victimClass[64];
    GetSafeClassname(victim, victimClass, sizeof(victimClass));

    if (gCvarEntityPush.BoolValue)
    {
        StorePendingRagdollPush(victim, victimClass, forceVector);
    }

    bool preDeathPushed = false;
    if (gCvarPreDeathPush.BoolValue)
    {
        preDeathPushed = ApplyPreDeathVelocity(victim, forceVector);
    }

    if (gCvarDebug.BoolValue)
    {
        PrintToServer("[RagdollForce] %N killed %s with %s force=%.1f dmgScale=%.2f preVel=%d vec=(%.1f %.1f %.1f)",
            shooter, victimClass, weaponName, force, damageScale, preDeathPushed ? 1 : 0,
            damageForce[0], damageForce[1], damageForce[2]);
    }

    return Plugin_Changed;
}

int ResolveSurvivorAttacker(int attacker, int inflictor, int weapon)
{
    if (IsValidSurvivorAttacker(attacker))
    {
        return attacker;
    }

    int shooter = ResolveEntityOwnerClient(attacker);
    if (IsValidSurvivorAttacker(shooter))
    {
        return shooter;
    }

    shooter = ResolveEntityOwnerClient(inflictor);
    if (IsValidSurvivorAttacker(shooter))
    {
        return shooter;
    }

    shooter = ResolveEntityOwnerClient(weapon);
    if (IsValidSurvivorAttacker(shooter))
    {
        return shooter;
    }

    // Mounted damage can report worldspawn or the turret as the attacker and
    // omit owner handles. Match the damage entities against each active user.
    int candidates[3];
    candidates[0] = attacker;
    candidates[1] = inflictor;
    candidates[2] = weapon;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsValidSurvivorAttacker(client) || !IsClientUsingMountedWeapon(client))
        {
            continue;
        }

        int mountedEntity = GetMountedUseEntity(client);
        if (mountedEntity <= MaxClients || !IsValidEntity(mountedEntity))
        {
            continue;
        }

        for (int index = 0; index < sizeof(candidates); index++)
        {
            if (candidates[index] == mountedEntity)
            {
                return client;
            }
        }
    }

    return 0;
}

int ResolveEntityOwnerClient(int entity)
{
    if (entity <= 0 || !IsValidEntity(entity))
    {
        return 0;
    }

    if (HasEntProp(entity, Prop_Send, "m_hOwnerEntity"))
    {
        int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
        if (IsValidSurvivorAttacker(owner))
        {
            return owner;
        }
    }

    if (HasEntProp(entity, Prop_Data, "m_hOwnerEntity"))
    {
        int owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
        if (IsValidSurvivorAttacker(owner))
        {
            return owner;
        }
    }

    if (HasEntProp(entity, Prop_Send, "m_hOwner"))
    {
        int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwner");
        if (IsValidSurvivorAttacker(owner))
        {
            return owner;
        }
    }

    if (HasEntProp(entity, Prop_Data, "m_hOwner"))
    {
        int owner = GetEntPropEnt(entity, Prop_Data, "m_hOwner");
        if (IsValidSurvivorAttacker(owner))
        {
            return owner;
        }
    }

    return 0;
}

bool ApplyPreDeathVelocity(int victim, const float forceVector[3])
{
    if (!IsValidEntity(victim))
    {
        return false;
    }

    float velocity[3];
    float scale = gCvarPreDeathVelocityScale.FloatValue;
    velocity[0] = forceVector[0] * scale;
    velocity[1] = forceVector[1] * scale;
    velocity[2] = forceVector[2] * scale;

    float current[3];
    if (HasEntProp(victim, Prop_Data, "m_vecVelocity"))
    {
        GetEntPropVector(victim, Prop_Data, "m_vecVelocity", current);
        velocity[0] += current[0];
        velocity[1] += current[1];
        velocity[2] += current[2];
        SetEntPropVector(victim, Prop_Data, "m_vecVelocity", velocity);
    }

    if (HasEntProp(victim, Prop_Send, "m_vecVelocity"))
    {
        SetEntPropVector(victim, Prop_Send, "m_vecVelocity", velocity);
    }

    if (HasEntProp(victim, Prop_Data, "m_vecBaseVelocity"))
    {
        SetEntPropVector(victim, Prop_Data, "m_vecBaseVelocity", velocity);
    }

    TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, velocity);
    return true;
}

int GetAllowedWeaponKind(int attacker, int inflictor, int weapon, char[] weaponName, int weaponNameSize)
{
    weaponName[0] = '\0';

    // Mounted damage often arrives with a generic weapon handle. Resolve the
    // turret from the attacker first, then inspect both SDKHooks entities.
    int mountedEntity = GetMountedUseEntity(attacker);
    if (TryGetMountedWeaponName(mountedEntity, weaponName, weaponNameSize))
    {
        return 2;
    }

    if (TryGetMountedWeaponName(inflictor, weaponName, weaponNameSize))
    {
        return 2;
    }

    if (TryGetMountedWeaponName(weapon, weaponName, weaponNameSize))
    {
        return 2;
    }

    bool usingMounted = IsClientUsingMountedWeapon(attacker);
    if (usingMounted)
    {
        // Some L4D2 builds expose the mounted state but not a usable
        // m_hUseEntity. Keep the hit eligible and use the AWP/mounted base
        // force rather than silently dropping the lethal hit.
        strcopy(weaponName, weaponNameSize, "mounted_gun");
        return 2;
    }

    if (weapon > MaxClients && IsValidEntity(weapon))
    {
        GetEntityClassname(weapon, weaponName, weaponNameSize);
    }

    if (weaponName[0] == '\0')
    {
        GetClientWeapon(attacker, weaponName, weaponNameSize);
    }

    if (StrEqual(weaponName, "weapon_pumpshotgun")
        || StrEqual(weaponName, "weapon_shotgun_chrome")
        || StrEqual(weaponName, "weapon_autoshotgun")
        || StrEqual(weaponName, "weapon_shotgun_spas"))
    {
        return 1;
    }

    if (StrEqual(weaponName, "weapon_sniper_awp"))
    {
        return 2;
    }

    if (IsMountedGunWeapon(weaponName))
    {
        return 2;
    }

    return 0;
}

bool IsClientUsingMountedWeapon(int client)
{
    if (client <= 0 || client > MaxClients || !IsClientInGame(client))
    {
        return false;
    }

    if (HasEntProp(client, Prop_Send, "m_usingMountedWeapon")
        && GetEntProp(client, Prop_Send, "m_usingMountedWeapon") != 0)
    {
        return true;
    }

    if (HasEntProp(client, Prop_Send, "m_usingMountedGun")
        && GetEntProp(client, Prop_Send, "m_usingMountedGun") != 0)
    {
        return true;
    }

    if (HasEntProp(client, Prop_Data, "m_usingMountedWeapon")
        && GetEntProp(client, Prop_Data, "m_usingMountedWeapon") != 0)
    {
        return true;
    }

    return HasEntProp(client, Prop_Data, "m_usingMountedGun")
        && GetEntProp(client, Prop_Data, "m_usingMountedGun") != 0;
}

int GetMountedUseEntity(int client)
{
    if (client <= 0 || client > MaxClients || !IsClientInGame(client))
    {
        return -1;
    }

    if (HasEntProp(client, Prop_Send, "m_hUseEntity"))
    {
        int entity = GetEntPropEnt(client, Prop_Send, "m_hUseEntity");
        if (entity > MaxClients && IsValidEntity(entity))
        {
            return entity;
        }
    }

    if (HasEntProp(client, Prop_Data, "m_hUseEntity"))
    {
        int entity = GetEntPropEnt(client, Prop_Data, "m_hUseEntity");
        if (entity > MaxClients && IsValidEntity(entity))
        {
            return entity;
        }
    }

    return -1;
}

bool TryGetMountedWeaponName(int entity, char[] weaponName, int weaponNameSize)
{
    if (entity <= MaxClients || !IsValidEntity(entity))
    {
        return false;
    }

    weaponName[0] = '\0';
    GetEntityClassname(entity, weaponName, weaponNameSize);
    if (IsMountedGunWeapon(weaponName))
    {
        return true;
    }

    // A few map entities expose a generic classname while their model still
    // identifies the mounted weapon (w_minigun.mdl or 50cal.mdl).
    if (HasEntProp(entity, Prop_Data, "m_ModelName"))
    {
        GetEntPropString(entity, Prop_Data, "m_ModelName", weaponName, weaponNameSize);
        if (IsMountedGunWeapon(weaponName))
        {
            return true;
        }
    }

    weaponName[0] = '\0';
    return false;
}

bool IsMountedGunWeapon(const char[] weaponName)
{
    if (weaponName[0] == '\0')
    {
        return false;
    }

    if (StrContains(weaponName, "minigun", false) != -1
        || StrContains(weaponName, "50cal", false) != -1
        || StrContains(weaponName, "50_cal", false) != -1
        || StrContains(weaponName, "fifty", false) != -1
        || StrContains(weaponName, "mounted_gun", false) != -1
        || StrContains(weaponName, "mountedgun", false) != -1
        || StrContains(weaponName, "mounted_machine_gun", false) != -1)
    {
        return true;
    }

    return StrEqual(weaponName, "weapon_minigun")
        || StrEqual(weaponName, "weapon_mounted_machine_gun")
        || StrEqual(weaponName, "prop_minigun")
        || StrEqual(weaponName, "prop_minigun_l4d1")
        || StrEqual(weaponName, "prop_mounted_gun")
        || StrEqual(weaponName, "prop_mounted_machine_gun");
}

float GetVictimForceMultiplier(int victim)
{
    if (victim > 0 && victim <= MaxClients)
    {
        if (!IsClientInGame(victim) || GetClientTeam(victim) != 3)
        {
            return 0.0;
        }

        int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
        switch (zombieClass)
        {
            case 3, 5:
            {
                return gCvarHunterJockeyMult.FloatValue;
            }
            case 1, 2, 4:
            {
                return gCvarMediumMult.FloatValue;
            }
            case 6, 8:
            {
                return 0.0;
            }
        }

        return 0.0;
    }

    char classname[64];
    if (GetSafeClassname(victim, classname, sizeof(classname)) && StrEqual(classname, "witch", false))
    {
        return gCvarMediumMult.FloatValue;
    }

    return 0.0;
}

bool WillDamageKill(int victim, float damage)
{
    int health = 0;

    if (victim > 0 && victim <= MaxClients)
    {
        if (!IsClientInGame(victim) || !IsPlayerAlive(victim))
        {
            return false;
        }

        health = GetClientHealth(victim);
    }
    else
    {
        if (!IsValidEntity(victim))
        {
            return false;
        }

        if (HasEntProp(victim, Prop_Data, "m_iHealth"))
        {
            health = GetEntProp(victim, Prop_Data, "m_iHealth");
        }
        else if (HasEntProp(victim, Prop_Send, "m_iHealth"))
        {
            health = GetEntProp(victim, Prop_Send, "m_iHealth");
        }
        else
        {
            return false;
        }
    }

    return damage >= float(health);
}

void BuildDeathForceVector(int attacker, int victim, float force, float forceVector[3])
{
    float from[3];
    float to[3];
    float dir[3];
    float shotDir[3];

    GetClientEyePosition(attacker, from);
    GetVictimOrigin(victim, to);
    to[2] += 42.0;

    MakeVectorFromPoints(from, to, shotDir);
    float shotZ = 0.0;

    if (GetVectorLength(shotDir) >= 0.001)
    {
        NormalizeVector(shotDir, shotDir);
        shotZ = ClampFloatValue(shotDir[2], -0.70, 0.85);
        dir[0] = shotDir[0];
        dir[1] = shotDir[1];
        dir[2] = shotDir[2];
    }
    else
    {
        float angles[3];
        GetClientEyeAngles(attacker, angles);
        GetAngleVectors(angles, shotDir, NULL_VECTOR, NULL_VECTOR);
        shotZ = ClampFloatValue(shotDir[2], -0.70, 0.85);
        dir[0] = shotDir[0];
        dir[1] = shotDir[1];
        dir[2] = shotDir[2];
    }

    dir[2] = 0.0;

    if (GetVectorLength(dir) < 0.001)
    {
        float angles[3];
        GetClientEyeAngles(attacker, angles);
        GetAngleVectors(angles, dir, NULL_VECTOR, NULL_VECTOR);
        dir[2] = 0.0;
    }

    NormalizeVector(dir, dir);

    forceVector[0] = dir[0] * force;
    forceVector[1] = dir[1] * force;
    forceVector[2] = force * ClampFloatValue(gCvarUpMult.FloatValue + (shotZ * gCvarAimZMult.FloatValue), -0.55, 0.95);
}

void StorePendingRagdollPush(int victim, const char[] victimClass, const float forceVector[3])
{
    int slot = gPendingCursor;
    gPendingCursor = (gPendingCursor + 1) % MAX_PENDING_PUSHES;

    GetVictimOrigin(victim, gPendingOrigin[slot]);
    gPendingVelocity[slot][0] = forceVector[0] * gCvarEntityVelocityScale.FloatValue;
    gPendingVelocity[slot][1] = forceVector[1] * gCvarEntityVelocityScale.FloatValue;
    gPendingVelocity[slot][2] = forceVector[2] * gCvarEntityVelocityScale.FloatValue;
    gPendingExpireTime[slot] = GetGameTime() + 2.00;
    gPendingActive[slot] = true;
    gPendingVictimUserId[slot] = (victim > 0 && victim <= MaxClients && IsClientInGame(victim)) ? GetClientUserId(victim) : 0;
    gPendingVictimEntRef[slot] = (victim > MaxClients && IsValidEntity(victim)) ? EntIndexToEntRef(victim) : INVALID_ENT_REFERENCE;
    gPendingFallbackLogged[slot] = false;
    strcopy(gPendingVictimName[slot], sizeof(gPendingVictimName[]), victimClass);

    CreateTimer(0.06, Timer_SearchRagdollsForPendingPush, slot, TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(0.16, Timer_SearchRagdollsForPendingPush, slot, TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(0.36, Timer_SearchRagdollsForPendingPush, slot, TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(0.72, Timer_SearchRagdollsForPendingPush, slot, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ApplyPendingPushToRagdoll(Handle timer, any entRef)
{
    int entity = EntRefToEntIndex(entRef);
    if (entity == INVALID_ENT_REFERENCE || !IsValidEntity(entity))
    {
        return Plugin_Stop;
    }

    int slot = FindBestPendingPushForEntity(entity);
    if (slot == -1)
    {
        if (gCvarDebug.BoolValue)
        {
            char classname[64];
            GetSafeClassname(entity, classname, sizeof(classname));
            PrintToServer("[RagdollForce] saw ragdoll %d %s but no pending push matched", entity, classname);
        }

        return Plugin_Stop;
    }

    ApplyPendingPushToEntity(entity, slot);
    return Plugin_Stop;
}

public Action Timer_SearchRagdollsForPendingPush(Handle timer, any slot)
{
    if (slot < 0 || slot >= MAX_PENDING_PUSHES || !IsPendingPushAlive(slot))
    {
        return Plugin_Stop;
    }

    int maxEntities = GetMaxEntities();
    char classname[64];
    int nearCount = 0;
    int ragdollCount = 0;
    char nearby[192];
    nearby[0] = '\0';

    for (int entity = MaxClients + 1; entity <= maxEntities; entity++)
    {
        if (!IsValidEntity(entity))
        {
            continue;
        }

        if (!GetEntityClassname(entity, classname, sizeof(classname)))
        {
            continue;
        }

        if (IsEntityCloseToPendingPush(entity, slot))
        {
            nearCount++;
            if (nearby[0] == '\0')
            {
                strcopy(nearby, sizeof(nearby), classname);
            }
            else if (StrContains(nearby, classname, false) == -1 && strlen(nearby) < 150)
            {
                Format(nearby, sizeof(nearby), "%s,%s", nearby, classname);
            }
        }

        if (StrContains(classname, "ragdoll", false) != -1)
        {
            ragdollCount++;
            if (IsEntityCloseToPendingPush(entity, slot))
            {
                ApplyPendingPushToEntity(entity, slot);
                return Plugin_Stop;
            }
        }
    }

    if (gCvarDebug.BoolValue && !gPendingFallbackLogged[slot] && GetGameTime() > gPendingExpireTime[slot] - 1.10)
    {
        gPendingFallbackLogged[slot] = true;
        PrintToServer("[RagdollForce] no server ragdoll matched %s near kill origin; nearby=%d ragdollsSeen=%d classes=%s",
            gPendingVictimName[slot], nearCount, ragdollCount, nearby[0] == '\0' ? "none" : nearby);
    }

    return Plugin_Stop;
}

int FindBestPendingPushForEntity(int entity)
{
    float origin[3];
    if (!GetEntityOriginSafe(entity, origin))
    {
        return -1;
    }

    int bestSlot = -1;
    float bestDistance = gCvarMatchRadius.FloatValue;

    for (int slot = 0; slot < MAX_PENDING_PUSHES; slot++)
    {
        if (!IsPendingPushAlive(slot))
        {
            continue;
        }

        float distance = GetVectorDistance(origin, gPendingOrigin[slot]);
        if (distance <= bestDistance)
        {
            bestSlot = slot;
            bestDistance = distance;
        }
    }

    return bestSlot;
}

bool IsEntityCloseToPendingPush(int entity, int slot)
{
    float origin[3];
    if (!GetEntityOriginSafe(entity, origin))
    {
        return false;
    }

    return GetVectorDistance(origin, gPendingOrigin[slot]) <= gCvarMatchRadius.FloatValue;
}

bool IsPendingPushAlive(int slot)
{
    if (!gPendingActive[slot])
    {
        return false;
    }

    if (GetGameTime() > gPendingExpireTime[slot])
    {
        gPendingActive[slot] = false;
        return false;
    }

    return true;
}

void ApplyPendingPushToEntity(int entity, int slot)
{
    float velocity[3];
    velocity[0] = gPendingVelocity[slot][0];
    velocity[1] = gPendingVelocity[slot][1];
    velocity[2] = gPendingVelocity[slot][2];

    if (HasEntProp(entity, Prop_Data, "m_vecVelocity"))
    {
        SetEntPropVector(entity, Prop_Data, "m_vecVelocity", velocity);
    }

    if (HasEntProp(entity, Prop_Send, "m_vecVelocity"))
    {
        SetEntPropVector(entity, Prop_Send, "m_vecVelocity", velocity);
    }

    if (HasEntProp(entity, Prop_Send, "m_vecRagdollVelocity"))
    {
        SetEntPropVector(entity, Prop_Send, "m_vecRagdollVelocity", velocity);
    }

    TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, velocity);

    if (gCvarDebug.BoolValue)
    {
        char classname[64];
        GetSafeClassname(entity, classname, sizeof(classname));
        PrintToServer("[RagdollForce] pushed ragdoll %d %s from %s vel=(%.1f %.1f %.1f)",
            entity, classname, gPendingVictimName[slot], velocity[0], velocity[1], velocity[2]);
    }

    gPendingActive[slot] = false;
}

void GetVictimOrigin(int victim, float origin[3])
{
    if (victim > 0 && victim <= MaxClients)
    {
        GetClientAbsOrigin(victim, origin);
        return;
    }

    GetEntPropVector(victim, Prop_Send, "m_vecOrigin", origin);
}

bool GetEntityOriginSafe(int entity, float origin[3])
{
    if (!IsValidEntity(entity))
    {
        return false;
    }

    if (HasEntProp(entity, Prop_Send, "m_vecOrigin"))
    {
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
        return true;
    }

    if (HasEntProp(entity, Prop_Data, "m_vecOrigin"))
    {
        GetEntPropVector(entity, Prop_Data, "m_vecOrigin", origin);
        return true;
    }

    return false;
}

bool IsValidSurvivorAttacker(int client)
{
    return client > 0
        && client <= MaxClients
        && IsClientInGame(client)
        && IsPlayerAlive(client)
        && GetClientTeam(client) == 2;
}

bool GetSafeClassname(int entity, char[] classname, int size)
{
    classname[0] = '\0';

    if (entity > 0 && entity <= MaxClients)
    {
        if (!IsClientInGame(entity) || !HasEntProp(entity, Prop_Send, "m_zombieClass"))
        {
            return false;
        }

        int zombieClass = GetEntProp(entity, Prop_Send, "m_zombieClass");
        switch (zombieClass)
        {
            case 1: strcopy(classname, size, "smoker");
            case 2: strcopy(classname, size, "boomer");
            case 3: strcopy(classname, size, "hunter");
            case 4: strcopy(classname, size, "spitter");
            case 5: strcopy(classname, size, "jockey");
            case 6: strcopy(classname, size, "charger");
            case 8: strcopy(classname, size, "tank");
            default: strcopy(classname, size, "infected_client");
        }

        return true;
    }

    return IsValidEntity(entity) && GetEntityClassname(entity, classname, size);
}

float ClampFloatValue(float value, float minValue, float maxValue)
{
    if (value < minValue)
    {
        return minValue;
    }

    if (value > maxValue)
    {
        return maxValue;
    }

    return value;
}
