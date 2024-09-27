#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d2_nativevote>

public void OnPluginStart()
{
	RegConsoleCmd("sm_vote_test", Cmd_VoteTest);
}

Action Cmd_VoteTest(int client, int args)
{
	if (!L4D2NativeVote_IsAllowNewVote())
	{
		PrintToChat(client, "currently not allowed initiate a new vote.");
		return Plugin_Handled;
	}

	L4D2NativeVote vote = L4D2NativeVote(VoteHandler);

	vote.SetDisplayText("%N is stupid ?", client);
	vote.Initiator = client;
	vote.Value = 42;	// int, float, bool...
	vote.SetInfoString("Some String");

	int iCount = 0;
	int[] iClients = new int[MaxClients];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if (GetClientTeam(i) == 2 || GetClientTeam(i) == 3)
			{
				iClients[iCount++] = i;
			}
		}
	}

	if (!vote.DisplayVote(iClients, iCount, 20))
		LogError("Failed to start vote!");

	return Plugin_Handled;
}

void VoteHandler(L4D2NativeVote vote, VoteAction action, int param1, int param2)
{
	switch (action)
	{
		case VoteAction_Start:
		{
			PrintToChatAll("%N initiated a vote", param1);
		}
		case VoteAction_PlayerVoted:
		{
			PrintToChatAll("%N has voted: %s", param1, param2 == VOTE_YES ? "Yes" : "No");
		}
		case VoteAction_End:
		{
			// if (vote.YesCount > vote.NoCount)
			if (vote.YesCount > vote.PlayerCount/2)
			{
				vote.SetPass("Vote passed, processing...");

				char str[256];
				vote.GetInfoString(str, sizeof(str));
				PrintToChatAll("stored string is: %s", str);
				PrintToChatAll("stored value is: %i", vote.Value);

				// Do something...
			}
			else
			{
				vote.SetFail();
			}
		}
	}
}
