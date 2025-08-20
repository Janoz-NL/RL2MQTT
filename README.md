# RL2MQTT

Connect your Rocket League to an MQTT broker. Game events and ticker messages wil be published as json messages. Use these messages in whatever tool you like to do whatever you want. Change lights using node-red and/or home-assistant. Trigger actions in OBS-Studio or activate a soundboard on your discord server.

## Configuration


### GUI

When you open the Bakkesmod screen (F2), there is a settings page in the plugin manager.

### Console

Configuration can also be done in the console (F6). Change server settings using
`rl2mqtt_server "mqtt://localhost:1883"`. When you use a standard port without SSL, only an IP address is 
enough. Optionaly you can also configure a username and password with `rl2mqtt_username "user"` and
`rl2mqtt_password "password"` when nescesary.

To connect use `rl2mqtt_connect` and to disconnect `rl2mqtt_disconnect`.

## Game event messages

Game events are hooks in the game which trigger a message on certain events. THe message will contain all the teams and players in the current match. Gamne event messages are published in `"rl2mqtt/gameevent"`.

### Example of game event message
```json
{
    "gameEvent":"Function GameEvent_Soccar_TA.Active.StartRound",
    "teams":[{
        "clubId":0,
        "homeTeam":true,
        "index":0,
        "name":"Team",
        "num":0,
        "players":[{
            "club":{
                "accentColor":{"B":0,"G":178,"R":0},
                "id":99999,
                "name":"CLUBNAME",
                "primaryColor":{"B":38,"G":38,"R":38},
                "tag":"TAG"
            },
            "id":"Epic|12345|0",
            "name":"Janoz"
        },{
            "id":"Unknown|0|0",
            "name":"Buzz"
        },{
            "id":"Unknown|0|0",
            "name":"Iceman"
        }],
        "primaryColor":{"B":255,"G":115,"R":24},
        "score":0,
        "secondaryColor":{"B":229,"G":229,"R":229}
    },{
        "clubId":0,
        "homeTeam":false,
        "index":1,
        "name":"Team",
        "num":1,
        "players":[{
            "id":"Unknown|0|0",
            "name":"Centice"
        },{
            "id":"Unknown|0|0",
            "name":"Gerwin"
        },{
            "id":"Unknown|0|0",
            "name":"Imp"
        }],
        "primaryColor":{"B":24,"G":100,"R":194},
        "score":0,
        "secondaryColor":{"B":229,"G":229,"R":229}
    }]
}
```

Curently the following hooks are supported:

* TAGame.GameEvent_TA.EventPlayerAdded
* TAGame.GameEvent_TA.EventPlayerRemoved
* TAGame.GameEvent_Soccar_TA.OnAllTeamsCreated
* GameEvent_Soccar_TA.Active.StartRound
* TAGame.GameEvent_Soccar_TA.OnOvertimeUpdate
* TAGame.GameEvent_Soccar_TA.Destroyed
* TAGame.GameEvent_Soccar_TA.EventMatchEnded

## Ticker messages

Ticker messages are messages which would normaly be displayed in the upper right corner. The JSON message consists of the player and the tickerEvent. In case of a "Demolish" it will also contain the victim. These messages are published in `rl2mqtt/ticker`.

### Example of a ticker json message:

```json
{
    "player":{
        "club":{
            "accentColor":{"B":0,"G":178,"R":0},
            "id":99999,
            "name":"CLUBNAME",
            "primaryColor":{"B":38,"G":38,"R":38},
            "tag":"TAG"
        },
        "id":"Epic|12345|0",
        "name":"Janoz",
        "team":{
            "clubId":0,
            "homeTeam":true,
            "index":0,
            "name":"Team",
            "num":0,
            "primaryColor":{"B":255,"G":115,"R":24},
            "score":0,
            "secondaryColor":{"B":229,"G":229,"R":229}
        }
    },
    "tickerEvent":{
        "event":"Demolish"
    },
    "victim":{
        "id":"Unknown|0|0",
        "name":"Imp",
        "team":{
            "clubId":0,
            "homeTeam":false,
            "index":1,
            "name":"Team",
            "num":1,
            "primaryColor":{"B":24,"G":100,"R":194},
            "score":0,
            "secondaryColor":{"B":229,"G":229,"R":229}
        }
    }
}
```
Possible values of ticker event are:

* Demolish
* Demolition
* Goal
* Win
* MVP
* AerialGoal
* BackwardsGoal
* BicycleGoal
* LongGoal
* TurtleGoal
* PoolShot
* OvertimeGoal
* HatTrick
* Assist
* Playmaker
* Save
* EpicSave
* Savior
* Shot
* Center
* Clear
* FirstTouch
* BreakoutDamage
* BreakoutDamageLarge
* LowFive
* HighFive
* HoopsSwishGoal
* BicycleHit
* OwnGoal
* KO_Winner
* KO_Knockout
* KO_DoubleKO
* KO_TripleKO
* KO_Death
* KO_LightHit
* KO_HeavyHit
* KO_AerialLightHit
* KO_AerialHeavyHit
* KO_HitTaken
* KO_BlockTaken
* KO_Grabbed
* KO_Thrown
* KO_LightBlock
* KO_HeavyBlock
* KO_PlayerGrabbed
* KO_PlayerThrown

# Usages

TODO

### Node-RED

TODO

### Home Assistant

TODO
