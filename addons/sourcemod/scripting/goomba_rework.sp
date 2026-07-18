#pragma semicolon            1
#pragma newdecls             required
#define PROFILER 0

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <tf2_stocks>
#include <morecolors>
#if PROFILER
#include <profiler>
#endif 

#define PLUGIN_VERSION          "1.0.0"
#define PLUGIN_VERSION_REVISION "manual"
#define PLUGIN_DESCRIPTION      "Goomba Stomp"
#define PLUGIN_URL              "https://github.com/lessari-tf/GoombaRework"

public Plugin myinfo = 
{
  name        = "Goomba",
  author      = "Aidan Sanders",
  description =  PLUGIN_DESCRIPTION,
  version     =  PLUGIN_VERSION ... "." ... PLUGIN_VERSION_REVISION,
  url         =  PLUGIN_URL,
};

#define STOMP_SOUND   "goomba/stomp.wav"
#define REBOUND_SOUND "goomba/rebound.wav"

enum struct GoombaCvars {
  ConVar PluginEnabled;
  ConVar ParticlesEnabled;
  ConVar SoundsEnabled;
  ConVar ImmunityEnabled;
  ConVar JumpPower;
  ConVar DamageLifeMultiplier;
  ConVar DamageAdd;
  
  ConVar StompMinSpeed;
  ConVar UberImun;
  ConVar CloakImun;
  ConVar StunImun;
  ConVar StompUndisguise;
  ConVar CloakedImun;
  ConVar BonkedImun;
  ConVar FriendlyFire;
}

enum struct GoombaGlobals {
  GoombaCvars m_hCvars;
}
GoombaGlobals g_goomba;

bool g_bGoombaPlayer[MAXPLAYERS+1];
bool g_bPerformGoomba[MAXPLAYERS+1];
float g_fVecGoomba[MAXPLAYERS+1][3];

public void OnPluginStart()
{
  char sModName[32]; GetGameFolderName(sModName, sizeof(sModName));
  if (!StrEqual(sModName, "tf", false))
    SetFailState("This plugin only works with Team Fortress 2");

  LoadTranslations("goomba.phrases");

  g_goomba.m_hCvars.PluginEnabled        = CreateConVar("goomba_enabled", "0.0", "Plugin On/Off", 0, true, 0.0, true, 1.0);
  g_goomba.m_hCvars.SoundsEnabled        = CreateConVar("goomba_sounds", "1", "Enable or disable sounds of the plugin", 0, true, 0.0, true, 1.0);
  g_goomba.m_hCvars.ParticlesEnabled     = CreateConVar("goomba_particles", "1", "Enable or disable particles of the plugin", 0, true, 0.0, true, 1.0);
  g_goomba.m_hCvars.ImmunityEnabled      = CreateConVar("goomba_immunity", "1", "Enable or disable the immunity system", 0, true, 0.0, true, 1.0);
  g_goomba.m_hCvars.JumpPower            = CreateConVar("goomba_rebound_power", "300.0", "Goomba jump power", 0, true, 0.0);
  g_goomba.m_hCvars.StompMinSpeed        = CreateConVar("goomba_minspeed", "360.0", "Minimum falling speed to kill", 0, true, 0.0, false, 0.0);
  g_goomba.m_hCvars.DamageLifeMultiplier = CreateConVar("goomba_dmg_lifemultiplier", "0.025", "How much damage the victim will receive based on its actual life", 0, true, 0.0, false, 0.0);
  g_goomba.m_hCvars.DamageAdd            = CreateConVar("goomba_dmg_add", "450.0", "Add this amount of damage after goomba_dmg_lifemultiplier calculation", 0, true, 0.0, false, 0.0);

  g_goomba.m_hCvars.UberImun             = CreateConVar("goomba_uber_immun", "1.0", "Prevent ubercharged players from being stomped", 0, true, 0.0, true, 1.0);
  g_goomba.m_hCvars.CloakImun            = CreateConVar("goomba_cloak_immun", "1.0", "Prevent cloaked spies from stomping", 0, true, 0.0, true, 1.0);
  g_goomba.m_hCvars.StunImun             = CreateConVar("goomba_stun_immun", "1.0", "Prevent stunned players from being stomped", 0, true, 0.0, true, 1.0);
  g_goomba.m_hCvars.StompUndisguise      = CreateConVar("goomba_undisguise", "1.0", "Undisguise spies after stomping", 0, true, 0.0, true, 1.0);
  g_goomba.m_hCvars.CloakedImun          = CreateConVar("goomba_cloaked_immun", "0.0", "Prevent cloaked spies from being stomped", 0, true, 0.0, true, 1.0);
  g_goomba.m_hCvars.BonkedImun           = CreateConVar("goomba_bonked_immun", "1.0", "Prevent bonked scout from being stomped", 0, true, 0.0, true, 1.0);
  g_goomba.m_hCvars.FriendlyFire         = CreateConVar("goomba_friendlyfire", "0.0", "Enable friendly fire, \"tf_avoidteammates\" and \"mp_friendlyfire\" must be set to 1", 0, true, 0.0, true, 1.0);
  
  AutoExecConfig(true, "goomba");

  HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);

  // Support for plugin late loading
  for (int iClient = 1; iClient <= MaxClients; iClient++)
  {
    if (IsClientInGame(iClient))
    {
      OnClientPutInServer(iClient);
    }
  }
}

public void OnMapStart()
{
  PrecacheSound(STOMP_SOUND, true);
  PrecacheSound(REBOUND_SOUND, true);

  char sStompSound[128], sReboundSound[128];
  Format(sStompSound, sizeof(sStompSound), "sound/%s", STOMP_SOUND);
  Format(sReboundSound, sizeof(sReboundSound), "sound/%s", REBOUND_SOUND);

  AddFileToDownloadsTable(sStompSound);
  AddFileToDownloadsTable(sReboundSound);
}

public void OnClientPutInServer(int iClient)
{
  SDKHook(iClient, SDKHook_StartTouch, OnStartTouch);	
  SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

public void OnPreThinkPost(int iClient)
{
  if (!IsValidClient(iClient) || !IsPlayerAlive(iClient))
    return;
  
  if (g_bPerformGoomba[iClient])
  {
    TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, g_fVecGoomba[iClient]);
    TF2_AddCondition(iClient, TFCond_BlastJumping, 0.0);
  }
  g_bPerformGoomba[iClient] = false;
}

public Action Timer_EntityCleanup(Handle hTimer, int iRef)
{
  int iEntity = EntRefToEntIndex(iRef);
  if (iEntity > MaxClients)
    AcceptEntityInput(iEntity, "Kill");
  return Plugin_Handled;
}

public Action Event_PlayerDeath(Event event, const char[] sName, bool bDontBroadcast)
{
  int iVictim = GetClientOfUserId(event.GetInt("userid"));
  int iAttacker = GetClientOfUserId(event.GetInt("attacker"));

  if (!g_bGoombaPlayer[iVictim])
    return Plugin_Continue;

  CPrintToChatAllEx(iAttacker, "%t", "Goomba Stomp", iAttacker, iVictim);

  int iDamageBits = event.GetInt("damagebits");
  iDamageBits |= DMG_ACID;

  event.SetString("weapon_logclassname", "goomba");
  event.SetString("weapon", "taunt_scout");
  event.SetInt("damagebits", iDamageBits);
  event.SetInt("customkill", 0);
  event.SetInt("playerpenetratecount", 0);

  if (!(event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER))
  {
    if (g_goomba.m_hCvars.SoundsEnabled.BoolValue)
      EmitSoundToClient(iVictim, STOMP_SOUND, iVictim);

    PrintHintText(iVictim, "%t", "Victim Stomped");
  }

  if (g_goomba.m_hCvars.StompUndisguise.BoolValue)
    TF2_RemovePlayerDisguise(iAttacker);

  return Plugin_Continue;
}

public void GoombaStomp(int iClient, int iVictim, 
                        float fDmgMult, float fDmgBonus, 
                        float fJumpPower)
{
  if (!g_goomba.m_hCvars.PluginEnabled.BoolValue)
    return;

  if (fJumpPower > 0.0)
  {
    float vel[3];
    GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", vel);

    // If falling, flip downward speed into upward velocity
    if (vel[2] < 0.0)
      vel[2] = -vel[2]; // Make it positive
    else
      vel[2] = 0.0; // No fall, start from 0

    // Add our stomp boost
    vel[2] += fJumpPower;

    // Save for later use if needed
    g_fVecGoomba[iClient] = vel;
    g_bPerformGoomba[iClient] = true;

    SetEntProp(iClient, Prop_Send, "m_bJumping", true);

    if (g_goomba.m_hCvars.SoundsEnabled.BoolValue)
      EmitSoundToAll(REBOUND_SOUND, iClient);
    
    if (g_goomba.m_hCvars.ParticlesEnabled.BoolValue)
    {
      float fVecOrigin[3]; GetClientAbsOrigin(iClient, fVecOrigin);
      fVecOrigin[2] += 74;
      CreateTimer(3.0, Timer_EntityCleanup, TF2_SpawnParticle("mini_fireworks", fVecOrigin));
    }
  }

  int iVictimHealth = GetClientHealth(iVictim);

  SDKHooks_TakeDamage(
    iVictim,
    iClient,
    iClient,
    iVictimHealth * fDmgMult + fDmgBonus,
    DMG_PREVENT_PHYSICS_FORCE | DMG_CRUSH | DMG_ALWAYSGIB);

  if (TF2_IsPlayerInCondition(iVictim, TFCond_Ubercharged) && !g_goomba.m_hCvars.UberImun.BoolValue) 
    TF2_RemoveCondition(iVictim, TFCond_Ubercharged);
}

public Action OnStartTouch(int iClient, int iOther)
{
  if (!g_goomba.m_hCvars.PluginEnabled.BoolValue)
    return Plugin_Continue;

  if (!IsValidClient(iClient) || !IsValidClient(iOther))
    return Plugin_Continue;

#if PROFILER
  Profiler profiler = new Profiler();
  profiler.Start();
#endif 

  float fClientPosition[3], fVictimPosition[3], fVictimVecMaxs[3];
  GetClientAbsOrigin(iClient, fClientPosition);
  GetClientAbsOrigin(iOther, fVictimPosition);
  GetEntPropVector(iOther, Prop_Send, "m_vecMaxs", fVictimVecMaxs);

  if (fClientPosition[2] - fVictimPosition[2] <= fVictimVecMaxs[2])
    return Plugin_Continue;

  float fVec[3];
  GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", fVec);

  if (fVec[2] < g_goomba.m_hCvars.StompMinSpeed.FloatValue * -1.0 )
  {
    if (!AreValidStompTargets(iClient, iOther))
      return Plugin_Continue;
    
    // Perform Goomba Stomp
    float fDmgMult = g_goomba.m_hCvars.DamageLifeMultiplier.FloatValue;
    float fDmgBonus = g_goomba.m_hCvars.DamageAdd.FloatValue;
    float fJumpPower = g_goomba.m_hCvars.JumpPower.FloatValue;
    g_bGoombaPlayer[iOther] = true;
    GoombaStomp(iClient, iOther, fDmgMult, fDmgBonus, fJumpPower);		
    g_bGoombaPlayer[iOther] = false;
  }

#if PROFILER
  profiler.Stop();
  PrintToChatAll("Total time taken: %f", profiler.Time);
  delete profiler;
#endif 
  
  return Plugin_Handled;
}

stock bool AreValidStompTargets(int iClient, int iVictim)
{
  if (!IsValidClient(iVictim) || GetEntProp(iVictim, Prop_Data, "m_takedamage", 1) == 0)
    return false;

  // Only check classname if necessary
  char sClass[32];
  GetEdictClassname(iVictim, sClass, sizeof(sClass));
  if (!StrEqual(sClass, "player") || !IsPlayerAlive(iVictim))
    return false;

  // Uber, Stun, Bonked checks
  if ((g_goomba.m_hCvars.UberImun.BoolValue && TF2_IsPlayerInCondition(iVictim, TFCond_Ubercharged)) ||
      (g_goomba.m_hCvars.StunImun.BoolValue && TF2_IsPlayerInCondition(iVictim, TFCond_Dazed)) ||
      (g_goomba.m_hCvars.BonkedImun.BoolValue && TF2_IsPlayerInCondition(iVictim, TFCond_Bonked)))
    return false;

  // Friendly Fire
  ConVar mp_friendlyfire   = FindConVar("mp_friendlyfire");
  ConVar tf_avoidteammates = FindConVar("tf_avoidteammates");
  if (GetClientTeam(iClient) == GetClientTeam(iVictim))
    if (!g_goomba.m_hCvars.FriendlyFire.BoolValue || !mp_friendlyfire.BoolValue || tf_avoidteammates.BoolValue)
      return false;

  // Cloak checks (for both client and victim)
  if (g_goomba.m_hCvars.CloakImun.BoolValue &&
    (TF2_IsPlayerInCondition(iClient, TFCond_Cloaked) || TF2_IsPlayerInCondition(iVictim, TFCond_Cloaked)))
    return false;

  return true;
}

stock int TF2_SpawnParticle(char[] sParticle, float vecOrigin[3] = NULL_VECTOR, float vecAngles[3] = NULL_VECTOR, bool bActivate = true, int iEntity = 0, int iControlPoint = 0, const char[] sAttachment = "", const char[] sAttachmentOffset = "")
{
  int iParticle = CreateEntityByName("info_particle_system");
  TeleportEntity(iParticle, vecOrigin, vecAngles, NULL_VECTOR);
  DispatchKeyValue(iParticle, "effect_name", sParticle);
  DispatchSpawn(iParticle);
  
  if (0 < iEntity && IsValidEntity(iEntity))
  {
    SetVariantString("!activator");
    AcceptEntityInput(iParticle, "SetParent", iEntity);

    if (sAttachment[0])
    {
      SetVariantString(sAttachment);
      AcceptEntityInput(iParticle, "SetParentAttachment", iParticle);
    }
    
    if (sAttachmentOffset[0])
    {
      SetVariantString(sAttachmentOffset);
      AcceptEntityInput(iParticle, "SetParentAttachmentMaintainOffset", iParticle);
    }
  }
  
  if (0 < iControlPoint && IsValidEntity(iControlPoint))
  {
    //Array netprop, but really only need element 0 anyway
    SetEntPropEnt(iParticle, Prop_Send, "m_hControlPointEnts", iControlPoint, 0);
    SetEntProp(iParticle, Prop_Send, "m_iControlPointParents", iControlPoint, _, 0);
  }
  
  if (bActivate)
  {
    ActivateEntity(iParticle);
    AcceptEntityInput(iParticle, "Start");
  }
  
  //Return ref of entity
  return EntIndexToEntRef(iParticle);
}

stock bool IsValidClient(const int iClient, bool bReplayCheck=true)
{
  if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
    return false;
  else if (GetEntProp(iClient, Prop_Send, "m_bIsCoaching"))
    return false;
  else if (bReplayCheck && (IsClientSourceTV(iClient) || IsClientReplay(iClient)))
    return false;
  else if (TF2_GetPlayerClass(iClient) == TFClass_Unknown)
    return false;
  return true;
}
