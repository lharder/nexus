# nexus
nexus is a framework to build multiplayer network games in a local network with Defold. 

To build multiplayer online games is not a trivial issue. While there are several frameworks out there to connect players over the internet and take care of the social media side of things, I was surprised to find that there was no support for the actual gaming on a network with Defold.

nexus tries to take away the technical minutiae from the developer. To keep different devices in sync with gameobjects being created, destroyed and updated constantly, with animations and sounds played and game logic carried out, developing a multiplayer game quickly becomes challenging. On the other hand, a developer should be able to focus on the gameplay and not on protocols to exchange data between the players in a match. 

For setting up games over a central server platform, there are many other options out there, no need to add another. nexus, however, enables you to setup a game in a local network without a central host somewhere on the internet. Game devices on the same local network find each other and negotiate everything they need automatically.

## Beacon: peer-to-peer detection
The first step in a multiplayer game is to find out who can join in a match.  You can use the *beacon*, the peer-to-peer discovery module of nexus. 

To start searching, you instantiate a *beacon* on every device with the same, arbitrary name of your game and an individual callsign for each player. As soon as *beacon* discovers a new game contact, the handler is called and passed in the new contact object with its ip, port and callsign:

````
-- discover peers in the local network
-- create a beacon
local beacon = Beacon.new( "NameOfTheGame", "callsign", function( other )
	pprint( "Found contact: " .. other.callsign )
end ) 

-- search and react
function update( self, dt )
	if beacon then beacon:update() end
end
````

Typically, upon detecting a new contact, you would display every new player's callsign and give your own player the chance to invite them to a new match. You could e.g. display each callsign with a checkbox to allow for selecting the participants you want for the next match.

````
-- all other players detected so far
local others = beacon:others()

-- my local contact info with callsign, ip and port
local me = beacon:me()

-- stop searching, start negotiating
beacon:destroy()
```` 
*beacon* uses udp datagrams to search and find peers on port 5898. nexus relies on Britzl's defnet library for all network communication. Every nexus message is sent and received via udp.


## Matcher: negotiate a new game



