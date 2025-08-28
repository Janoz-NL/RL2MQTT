#pragma once
#include <nlohmann/json.hpp>
#include "bakkesmod/plugin/bakkesmodplugin.h"

using json = nlohmann::json;

json serializeGameInfo(ServerWrapper sw, std::string event, unsigned char homeTeam);
json serializeEvent(ServerWrapper sw, StatEventWrapper statEvent, PriWrapper player, PriWrapper victim, unsigned char homeTeam);
json serializeGameTime(ServerWrapper sw);

