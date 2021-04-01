# nexus
A framework to build multiplayer network games in Defold

## Multiplayer network games
To write a multiplayer network game, even for just two or three players, is tricky business. As soon as you have to synchronize the state of gameobjects between two different hosts without noticeable latency, things get very complicated. nexus is my take at a framework that helps game developers to focus on their game logic instead of the communication details. 

nexus is intended to work without a central game server. nexus is not for providing chat rooms, provide a central lobby, bring players together, etc. nexus is for setting up ad hoc matches for players on the same local network. No registrations and no memberships are required: the game discovers available players automatically.

## Dependencies
The proinciples of nexus are independent of a certain engine, but the implementation is for Defold / Lua. Apart from the Defold engine, there are some excellent libraries by Bjoern Ritzl that nexus depends on:

https://github.com/britzl/defold-luasocket
https://github.com/britzl/defnet/
https://github.com/britzl/defold-input/archive/master.zip

## Example project
nexus comes with a simple example of multiple gameobjects on different hosts interacting with other. 

## 1. Game setup and discovery of peers

**game = Game.new( "MultiPlayerGame" )**

You start by instantiating a nexus game object. You provide a gameID that gets transmitted to recognize the same application on other hosts currently looking for peers.

To discover other players, the GAME object broadcasts a UDP message on the network and listens to likeminded players from other ip addresses:

**game:broadcast( "callsign", function( host )**</br>
  ...</br>
**end )**

The broadcast methods expects a callsign to identify the player. It must be unique and it is up to the players / the game application to make sure there is no conflict. Every time a host is discovered, nexus calls the callback method and provides a host object representing the new peer:

<code>

host.ip

host.port

host.callsign

</code>




- Game.new( gameId )
- Game.getLocalhostIP()

- Game:broadcast( callsign, callbackOnFound )
- Game:addHost( host )
- Game:getHost( callsign )
- Game:getHostByIp( ip )
- Game:newMatch( ... )
- Game:isServer()
- Game:getServerHost()

- Game:start()
- Game:update()





