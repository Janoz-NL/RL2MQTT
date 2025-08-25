#include "pch.h"
#include "Rl2Mqtt.h"
#include "bakkesmod/wrappers/GameObject/Stats/StatEventWrapper.h"
#include "datatypes.h"
#include "mqtt/async_client.h"
#include <chrono>

BAKKESMOD_PLUGIN(Rl2Mqtt, "RocketLeague 2 MQTT", plugin_version, PLUGINTYPE_FREEPLAY)


#define MQTT_CLIENTID			"RocketLeague"
#define MQTT_TOPIC_STATTICKER	"rl2mqtt/ticker"
#define MQTT_TOPIC_GAME_EVENT	"rl2mqtt/gameevent"


std::shared_ptr<mqtt::async_client> _mqttClient;

void Rl2Mqtt::logJson(json json) {
	std::string message = json.dump(1, ' ', true, json::error_handler_t::ignore);
	cvarManager->log(message);
}

void Rl2Mqtt::publishJson(json json, std::string topic) {
	try
	{
		if (_mqttClient->is_connected())
		{
			_mqttClient->publish(mqtt::make_message(topic, json.dump(), 1, false));
		}
	}
	catch (const mqtt::exception& exc) {
		cvarManager->log(exc.what());
	}
	catch (const std::exception& ex)
	{
		cvarManager->log(ex.what());
	}
}

void Rl2Mqtt::setServerStatus(std::string message)
{
	cvarManager->log(message);
	cvarManager->getCvar(CVAR_MQTT_STATUS).setValue(message);
}

void Rl2Mqtt::onLoad()
{
	// Server settings
	cvarManager->registerCvar(CVAR_MQTT_SERVER, "mqtt://localhost:1883", "MQTT server");
	cvarManager->registerCvar(CVAR_MQTT_USERNAME, "", "MQTT Username");
	cvarManager->registerCvar(CVAR_MQTT_PASSWORD, "", "MQTT Password");
	cvarManager->registerCvar(CVAR_MQTT_CONNECT_ON_STARTUP, "0", "Connect on startup", true, true, 0, true, 1).addOnValueChanged([this](std::string oldValue, CVarWrapper cvar)
		{
			if (cvar.getBoolValue())
			{
				gameWrapper->Execute([this](GameWrapper* gw) {
					cvarManager->executeCommand("sleep 2000; " COMMAND_MQTT_CONNECT);
				});
			}
		}
	);

	// Status container
	cvarManager->registerCvar(CVAR_MQTT_VERSION, plugin_version, "Plugin version", false, false, 0, false, 0, false);
	cvarManager->registerCvar(CVAR_MQTT_STATUS, ".....", "Server Status", false, false, 0, false, 0, false);

	// (Dis)Connect commands
	cvarManager->registerNotifier(COMMAND_MQTT_CONNECT, [this](std::vector<std::string> args) {
		connect();
		}, "Connect to the MQTT broker.", PERMISSION_ALL);
	cvarManager->registerNotifier(COMMAND_MQTT_DISCONNECT, [this](std::vector<std::string> args) {
		disconnect();
		}, "Disconnect from the MQTT broker.", PERMISSION_ALL);

	// Async versions of commands
	cvarManager->registerNotifier(COMMAND_MQTT_CONNECT "_async", [this](std::vector<std::string> args) {
		gameWrapper->Execute([this](GameWrapper* gw) {
			cvarManager->executeCommand(COMMAND_MQTT_CONNECT);
			});
		}, "Connect to the MQTT broker.", PERMISSION_ALL);
	cvarManager->registerNotifier(COMMAND_MQTT_DISCONNECT "_async", [this](std::vector<std::string> args) {
		gameWrapper->Execute([this](GameWrapper* gw) {
			cvarManager->executeCommand(COMMAND_MQTT_DISCONNECT);
			});
		}, "Disconnect from the MQTT broker.", PERMISSION_ALL);


	// Stat ticker messages
	gameWrapper->HookEventWithCallerPost<ServerWrapper>("Function TAGame.GFxHUD_TA.HandleStatTickerMessage",
		[this](ServerWrapper caller, void* params, std::string eventname) 
		{
			onStatTickerMessage(params);
		});

	// Player events
	gameWrapper->HookEventWithCallerPost<ServerWrapper>("Function TAGame.GameEvent_TA.EventPlayerAdded",
		[this](ServerWrapper caller, void* params, std::string eventname)
		{
			onMatchEvent(eventname);
		});
	gameWrapper->HookEventWithCallerPost<ServerWrapper>("Function TAGame.GameEvent_TA.EventPlayerRemoved",
		[this](ServerWrapper caller, void* params, std::string eventname)
		{
			onMatchEvent(eventname);
		});

	// Match events
	gameWrapper->HookEventWithCallerPost<ServerWrapper>("Function TAGame.GameEvent_Soccar_TA.OnAllTeamsCreated",
		[this](ServerWrapper caller, void* params, std::string eventname)
		{
			onMatchEvent(eventname);
		});
	gameWrapper->HookEventWithCallerPost<ServerWrapper>("Function GameEvent_Soccar_TA.Active.StartRound",
		[this](ServerWrapper caller, void* params, std::string eventname)
		{
			onMatchEvent(eventname);
		});
	gameWrapper->HookEventWithCallerPost<ServerWrapper>("Function TAGame.GameEvent_Soccar_TA.OnOvertimeUpdated",
		[this](ServerWrapper caller, void* params, std::string eventname)
		{
			onMatchEvent(eventname);
		});
	gameWrapper->HookEventWithCallerPost<ServerWrapper>("Function TAGame.GameEvent_Soccar_TA.Destroyed",
		[this](ServerWrapper caller, void* params, std::string eventname)
		{
			onMatchEvent(eventname);
		});
	gameWrapper->HookEventWithCallerPost<ServerWrapper>("Function TAGame.GameEvent_Soccar_TA.EventMatchEnded",
		[this](ServerWrapper caller, void* params, std::string eventname)
		{
			onMatchEvent(eventname);
		});
}

void Rl2Mqtt::connect() 
{
	setServerStatus("Connecting...");

	auto user = cvarManager->getCvar(CVAR_MQTT_USERNAME).getStringValue();
	auto password = cvarManager->getCvar(CVAR_MQTT_PASSWORD).getStringValue();
	auto server = cvarManager->getCvar(CVAR_MQTT_SERVER).getStringValue();

	auto connOptions = mqtt::connect_options_builder()
		.clean_session()
		.automatic_reconnect(true)
		.connect_timeout(std::chrono::seconds(20))
		.keep_alive_interval(std::chrono::seconds(5))
		.user_name(user)
		.password(password)
		.finalize();
	
	_mqttClient = std::make_shared<mqtt::async_client>(server, MQTT_CLIENTID);

	try
	{
		_mqttClient->connect(connOptions)->wait();

		if (_mqttClient->is_connected())
		{
			setServerStatus("Connected");
		}
		else
		{
			setServerStatus("NOT connected");
		}
	}
	catch (const mqtt::exception& exc) {
		setServerStatus("Connection failed");
		cvarManager->log(exc.what());
	}
}

void Rl2Mqtt::disconnect()
{
	setServerStatus("Disconnecting...");
	if (_mqttClient) 
		if (_mqttClient->is_connected())
		{
			_mqttClient->disconnect();
			setServerStatus("Dissconnected");
			return;
		}
	cvarManager->log("Wasn't connected");
	setServerStatus("Dissconnected");
}

void Rl2Mqtt::onUnload()
{
	disconnect();
	cvarManager->log("Unloaded Rl2Mqtt");
}

void Rl2Mqtt::onMatchEvent(std::string eventname)
{
	if (!gameWrapper->IsInGame())
		return;
	auto state = gameWrapper->GetCurrentGameState();
	publishJson(serializeGameInfo(state, eventname, getHomeTeam(state)), MQTT_TOPIC_GAME_EVENT);
}

void Rl2Mqtt::onStatTickerMessage(void* params) 
{
	if (!gameWrapper->IsInGame())
		return;
	auto state = gameWrapper->GetCurrentGameState();
	publishJson(serializeEvent(state, (StatTickerParams*)params, getHomeTeam(state)), MQTT_TOPIC_STATTICKER);
}

unsigned char Rl2Mqtt::getHomeTeam(ServerWrapper state)
{
	if (state)
	{
		auto localPlayer = state.GetLocalPrimaryPlayer();
		if (localPlayer) {
			return localPlayer.GetTeamNum2();
		}
	}
	return 127; //non excisting team
}



