#include "pch.h"
#include "JsonSerializer.h"

std::string getString(UnrealStringWrapper wrp)
{
	if (wrp) return wrp.ToString();
	else return "";
}

json serializeColor(LinearColor color) {
	return
	{
		{ "R", (int)(color.R * 255) },
		{ "G", (int)(color.G * 255) },
		{ "B", (int)(color.B * 255) }
	};
}

json serializeColor(int color) {
	return
	{
		{ "R", (int)((color & 0x00ff0000) >> 16) },
		{ "G", (int)((color & 0x0000ff00) >> 8) },
		{ "B", (int)((color & 0x000000ff)) }
	};
}

json serializeTeam(TeamWrapper team, unsigned char homeTeam) {
	if (team)
	{
		return
		{
			{"name", getString(team.GetTeamName())},
			{"num", team.GetTeamNum()},
			{"index", team.GetTeamIndex()},
			{"score", team.GetScore()},
			{"homeTeam", team.GetTeamNum2() == homeTeam},
			{"clubId", team.GetClubID() },
			{"primaryColor", serializeColor(team.GetPrimaryColor())},
			{"secondaryColor", serializeColor(team.GetSecondaryColor())}
		};
	}
	else return {};
}

json serializeClub(ClubDetailsWrapper club)
{
	return
	{
		{ "id", club.GetClubID() },
		{ "name", getString(club.GetClubName()) },
		{ "tag", getString(club.GetClubTag()) },
		{ "primaryColor", serializeColor(club.GetPrimaryColor()) },
		{ "accentColor",  serializeColor(club.GetAccentColor()) }
	};
}


json serializePlayer(ServerWrapper sw, PriWrapper player, bool teamExpanded, unsigned char homeTeam)
{
	json result = 
	{
		{"name", getString(player.GetPlayerName())},
		{"id", player.GetUniqueIdWrapper().GetIdString()},
		{"score", player.GetMatchScore()}
	};
	ClubDetailsWrapper club = player.GetClubDetails();
	if (club) 
	{
		result["club"] = serializeClub(club);
	}
	if (teamExpanded)
	{
		TeamInfoWrapper team = player.GetTeam();
		if (team)
		{			
			result["team"] = serializeTeam(sw.GetTeams().Get(team.GetTeamIndex()), homeTeam);
		}
	}
	return result;
}

json serializeTeams(ServerWrapper sw, unsigned char homeTeam)
{
	ArrayWrapper<PriWrapper> players = sw.GetPRIs();
	std::map<int, json> teams;
	json noTeam;
	for (int i = 0; i < players.Count(); i++)
	{
		PriWrapper current = players.Get(i);
		TeamInfoWrapper team = current.GetTeam();
		if (team)
		{
			if (!teams.contains(team.GetTeamIndex()))
			{
				teams[team.GetTeamIndex()] = serializeTeam(sw.GetTeams().Get(team.GetTeamIndex()), homeTeam);
			}
			teams[team.GetTeamIndex()]["players"] += serializePlayer(sw, current, false, homeTeam);
		}
		else
		{
			noTeam += serializePlayer(sw, current, false, homeTeam);
		}
	}
	json result;
	for (const auto& [index, team] : teams)
		result += team;
	if (noTeam.size() > 0)
	{
		result += {
			{ "players", noTeam}
		};
	}
	return result;
}

json serializeStatEvent(StatEventWrapper statEvent)
{
	return
	{
		{ "event" , statEvent.GetEventName()
		}
	};
}

json serializeEvent(ServerWrapper sw, StatEventWrapper statEvent, PriWrapper player, PriWrapper victim, unsigned char homeTeam)
{
	json result;
	result["tickerEvent"] = serializeStatEvent(statEvent);
	result["player"] = serializePlayer(sw, player, true, homeTeam);
	if (victim) 
	{
		result["victim"] = serializePlayer(sw, victim, true, homeTeam);
	}
	return result;
}

json serializeGameTime(ServerWrapper sw) {
	return {
			{ "remaining", sw.GetSecondsRemaining() },
			{ "overtime", sw.GetbOverTime() == 1 }
	};
}

json serializeGameInfo(ServerWrapper sw, std::string event, unsigned char homeTeam) {
	json result;
	result["gameEvent"] = event;
	if (sw)
	{
		result["teams"] = serializeTeams(sw, homeTeam);
	}
	return result;
}
