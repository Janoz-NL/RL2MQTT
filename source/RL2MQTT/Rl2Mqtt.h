#pragma once
#pragma comment(lib, "Ws2_32.lib")

#include "bakkesmod/plugin/bakkesmodplugin.h"
#include "JsonSerializer.h"
#include "version.h"

constexpr auto plugin_version = stringify(VERSION_MAJOR) "." stringify(VERSION_MINOR) "." stringify(VERSION_BUILD);

#define CVAR_MQTT_SERVER				"rl2mqtt_server"
#define CVAR_MQTT_USERNAME				"rl2mqtt_username"
#define CVAR_MQTT_PASSWORD				"rl2mqtt_password"
#define CVAR_MQTT_STATUS				"rl2mqtt_status"
#define	CVAR_MQTT_VERSION				"rl2mqtt_version"
#define CVAR_MQTT_CONNECT_ON_STARTUP	"rl2mqtt_connect-on-startup"

#define COMMAND_MQTT_CONNECT	"rl2mqtt_connect"
#define COMMAND_MQTT_DISCONNECT	"rl2mqtt_disconnect"

class Rl2Mqtt: public BakkesMod::Plugin::BakkesModPlugin
{
	void onLoad() override;
	void onUnload() override;

private:
	void onGameTimeChanged();
	void onMatchEvent(std::string eventname);
	void onStatTickerMessage(void* params);

	unsigned char getHomeTeam(ServerWrapper state);
	bool shouldProcess();

	void connect();
	void disconnect();
	void publishJson(json json, std::string topic);

	void logJson(json json);
	void setServerStatus(std::string message);
};

