#pragma once
#include <nlohmann/json.hpp>
#include "bakkesmod/plugin/bakkesmodplugin.h"
#include "datatypes.h"

using json = nlohmann::json;

json serializeGameInfo(ServerWrapper sw, std::string event, unsigned char homeTeam);
json serializeEvent(ServerWrapper sw, StatTickerParams* pStruct, unsigned char homeTeam);

