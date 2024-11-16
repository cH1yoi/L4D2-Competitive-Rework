#include <sourcemod>

#define REQUIRE_EXTENSIONS
#include <sourcetvmanager>

#undef REQUIRE_PLUGIN
#include <readyup>
#define REQUIRE_PLUGIN

#include <autorecorder/logic>
#include <autorecorder/console>

public void OnAllPluginsLoaded()
{
    g_bReadyUpAvailable = LibraryExists("readyup");
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "readyup"))
    {
        g_bReadyUpAvailable = true;
    }
}

public void OnPluginStart()
{
    Logic_Init();
    Console_Init();
}

public void OnLibraryRemoved(const char[] name)
{
    if (strcmp(name, "sourcetvsupport") == 0 && SourceTV_IsRecording()) {
        SourceTV_StopRecording();
    }
    if (StrEqual(name, "readyup"))
    {
        g_bReadyUpAvailable = false;
    }
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int maxlen)
{
    switch (GetEngineVersion()) {
        case Engine_Left4Dead2, Engine_Left4Dead:
        {
            return APLRes_Success;
        }
    }

    strcopy(error, maxlen, "Game is not supported.");

    return APLRes_SilentFailure;
}

#if !defined REQUIRE_PLUGIN
public void __pl_readyup_SetNTVOptional()
{
    MarkNativeAsOptional("OnRoundIsLive");
}
#endif

public Plugin myinfo =
{
    name = "[L4D/2] Automated Demo Recording",
    author = "shqke",
    description = "Plugin takes control over demo recording process allowing to record only useful footage",
    version = "1.2",
    url = "https://github.com/shqke/sp_public"
};