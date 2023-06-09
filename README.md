# nexus
nexus is a framework to build multiplayer network games in a local network with Defold. 

To build multiplayer network games is not a trivial issue. While there are several platforms and SDKs out there to connect players over the internet and take care of the social media side of things, I was surprised to find that there was little support for the actual gaming on a network with Defold.

nexus tries to take away the technical minutiae from the developer. To keep different devices in sync with gameobjects being created, destroyed and updated constantly, with animations and sounds played and game logic carried out, developing a multiplayer game quickly becomes challenging. On the other hand, a developer should be able to focus on the gameplay and not on protocols to exchange data between the players in a match. 

For setting up games over a central internet platform, there are many other options out there, so no need for nexus to add another. nexus, instead, enables you to setup a game in a local network without a central hosting platform. Game devices on the same local network find each other and negotiate everything they need automatically.

To make writing such networking games easy and painless (as far as possible), nexus provides different utility classes for game developers to use.

## Beacon: peer-to-peer detection
The first step in a multiplayer game is to find out who can join in a match. To achieve this, you can use *beacon*, the peer-to-peer discovery module of nexus. 

### Search game clients
To start searching, you instantiate a *beacon* on every device with the same, arbitrary name of your game and an individual callsign for each player. As soon as *beacon* discovers a new game contact, the handler is called and passed in the new contact object with its ip, port and callsign:

````
-- discover peers in the local network as contacts:
-- local contact = Contact.new( ip, port, callsign, attrs )
-- create a beacon
local attrs = { avatar = "bob", foo = "bar" }
local beacon = Beacon.new( "NameOfTheGame", "callsign", 
	function( other )
		pprint( "Found contact: " .. other.callsign,  other.attrs )
	end, 
attrs )

-- search and react
function update( self, dt )
	if beacon then beacon:update() end
end
````

### Selection of available contacts
Typically, upon detecting a new contact, you would display every new player's callsign and give your own player the chance to invite them to a new match. You could e.g. display each callsign with a checkbox to allow for selecting the participants you want for the next match.

````
-- all other players detected so far
local contacts = beacon:all()

-- my own contact info with callsign, ip and port
local mycontact = beacon:me()

-- all other players (except for myself)
local others = beacon:others()

-- now display all available contacts to the player. Allow 
-- for selection to setup the players for the next match.
-- You may opt for some or all of the available contacts:
local selectcontacts = {}
table.insert( selectcontacts, contacts[ 1 ] )
table.insert( selectcontacts, contacts[ 2 ] )

-- stop searching, start negotiating
beacon:destroy()
```` 
*beacon* uses udp datagrams to search and find peers on port 5898. nexus relies on Britzl's defnet library for all network communication. Every nexus message is sent and received via udp. 

(Unfortunately, with iOS 14, there have come restrictions on broadcasting. As I did not want to require extra Apple permissions, I changed the p2p code provided by Britzl to something less elegant, but workable :o)


## Matcher: negotiate a new game
Once all available contacts have been established by *beacon*, it is time to negotiate which ones of them should join for the next common match. nexus provides the *Matcher* class for this purpose.

A *matcher* takes the contact information of the local player that beacon:me() has provided as a parameter to its constructor. As *matcher* uses the same udp port as *beacon* by default, it is important to stop the first service with beacon:destroy() before initializing the next.

### Proposal and consensus
Once you have a *matcher* object, you can start proposing a list of contacts that your local player has selected as the participants of the next match. How this selection is performed is a matter of your gameplay and does not concern nexus.

When you propose a list of contacts, *matcher* automatically contacts the respective players and transmits your suggestion in the background. The other players, too, send over their suggestion for the players of the next match. If one (or more) of the desired participants suggests a different set of players, there will be no consensus and *matcher* will keep waiting for all to agree on a common set. 

Once consensus has been reached, the negotiation is over and *matcher* calls the function you provide as the method's second parameter. 

```` 
local matcher = Matcher.new( mycontact )
matcher:propose( selectcontacts, function( gamemaster ) 
	pprint( "All selected players confirmed, let's rock!!!" )
	pprint(."NPCs guided by " .. gamemaster.callsign )
end )

```` 

### Game master and the state of the world
In a multiplayer game, you need to display all characters, every item and every missile on all devices at the same time. That is a daunting task. What makes it so complicated, apart from the networking protocols involved, is the fact that the ultimate truth about what is happening at any given time is scattered over all devices: every player will be steering their own hero, while at the same time, all the non-player-characters, the monsters, items and projectiles in the game must be guided by some game logic identically on all devices. After all, who steers the monster?

In online games on the internet, the only sensible answer is a central game server farm. With huge numbers of participants unknown to each other, running an authoritative server telling every participant about the single true state of the world is the only viable approach - especially when you have to account for all kinds of cheating and fraud attempts of total strangers.

nexus on the other hand is not made for such MMOGs. It is for spontaneous, adhoc, no-registration-necessary matches among a few selected friends who happen to have access to the same WLAN. It is a happy world that way, where fraud is not an issue and no 3rd party central platform with commercial needs required. Personally, I much prefer it and it definitely makes a developer's live a lot easier.

So, with nexus, it is a part of the *matcher*'s job to negotiate for one of the participants to take over the role of the game master: that is the one contact whose device takes over carrying out the game logic for all non-player-activities. Upon calling the function that a consensus has been achieved between the players of the next match, *matcher* provides the gamemaster contact as a parameter.

## Puppeteer

Well, keeping the world in sync remains a challenging task. But fear not, nexus provides another class for you so that you can blissfully focus on your game logic without having to worry where it gets executed.

### Active and passive instances of gameobjects

nexus makes a difference between "active" gameobjects on a device and "passive" ones. On all devices, normally, you have at least one "active" gameobject - that is the player holding that device and providing input to steer their character. The characters steered by the other players are considered "active" on their respective devices, but to all others, they are considered "passive" because their game logic is executed somewhere else. It does not matter where exactly, nor, whether the active part is a human or some kind of AI, it just matters that it is not a task for the local instance of your game.

On the gamemaster device, of course, there are the most "active" gameobjects. Everything that is not steered by direct player input on one of the other devices is taken care of by the gamemaster device. It carries out all the AI logic that is required in the game.

Most of the time, nexus allows you to not care whether a gameobject is active or passive on a given device. To keep track of this and make sense of it, nexus provides the *Puppeteer* class.

Once you have agreed on the participants of your match, you load the level where the actual game starts. As *puppeteer* uses the same udp port as *beacon* and *matcher* by default, it is important to stop the previously used service with ````matcher:destroy()```` before initializing *puppeteer*.

As a part of that level, you instantiate your puppeteer. It is a good practice to have a global reference to it as it will be used a lot by all your gameobjects and access to it should be painless:

```` 
-- should be global for easy access
puppeteer = Puppeteer.new( gamemaster, mycontact, others )

-- puppeteer must be updated every frame
if puppeteer then puppeteer:update() end
```` 
*puppeteer* takes over all the communication that is required between the "active" and the "passive" instances of a gameobject on the respective devices. To allow for that syncing, a developer must cede control over creating and destroying gameobjects to *puppeteer*. Gameobjects are defined in Defold as always, with all components, but in order to instantiate them, you call a puppeteer method:

### Create and delete gameobjects
```` 
-- instead of factory.create( factUrl, pos, rot, params, scale )
puppeteer:create( gid, factUrlActive, factUrlPassive, pos, rot, params, scale )

-- instead of factory.delete( id, recursive )
puppeteer:delete( gid, recursive )
```` 
There are two new parameters in the ```` puppeteer:create()````  method: 

First, there is a global identifier ("gid"), that you must provide for every gameobject you create. In Defold, when you create an object dynamically, it gets assigned its id by the engine. There is no guarantee at all, however, that the same code carried out on two different devices will produce the same ids. So, while these Defold ids are unique locally on a single device, they are in no way fit to identify remote instances of that gameobject on other devices. 

Instead, Puppeteer allows the developer to assign an arbitray key to a gameobject and then refer to it uniquely across all devices. On each device, *puppeteer* can resolve that key and provide the corresponding local Defold id when that is needed.

And secondly, instead of a single gameobject factory url, you must provide two, one for the active object and one for the passive one. 

Typically, the active gameobject will have extensive scripting attached, containing all the logic that makes it behave in a given way. 

The passive gameobject on the other hand may not have any script attached at all, although there are a few special cases when that makes sense. The passive component is directed entirely by *puppetmaster* so you should just make sure that it is made up of the same visible and audible components as the active object.

So, when you create a gameobject via puppeteer, what you really do is create an instance of it on each of the players' devices, one active and all others passive.

### Creating gameobjects with a twist
There is one more difference between ```` factory.create()````  and ````puppeteer:create()```` that developers have to be aware of. 

Defold allows for passing properties to its ```` factory.create()```` method upon initialization. Unfortunately, it is not possible to pass in complex objects, tables, strings, etc., although this is often desirable. *puppeteer*, however, allows for arbitrary, complex parameters to be passed in to ````puppeteer:create()````. They do not get assigned to properties (which are actually not needed for this type of initialization), but get sent as a message to the new gameobject *right after its creation*. The gameobject must react to this "init" message and process the data being sent.

What happens internally is this:

````
-- create gameobjects with complex init data.
-- go script must be ready to process an "init" msg with params after creation
local function factorycreate( facturl, pos, rot, params, scale )
	local id = factory.create( facturl , pos, rot, nil, scale )
	msg.post( id, "init", params )
	return id
end

-- in gameobject script
function on_message( self, message_id, message, sender )
	if message_id == hash( "init" ) then
		-- do whatever with message and its complex data
	end
end
````

An elaborate discussion about the why and how can be found here, including example code for handling this kind of gameobject creation (https://github.com/defold/defold/issues/7058).


### Syncing state across devices
As soon as *puppeteer* creates a gameobject, it starts syncing its state to all other devices. Every active gameobject carries out its script logic in the usual cycle of ```` init(), update(), on_input()````, etc. method calls executed by the Defold engine. Carrying out that logic results in changes to the object's position, rotation, direction, speed, animation and sound as needed. All of these must get synced by *puppeteer* automatically.

For each active instance of a gameobject, *puppeteer* gathers its current state and sends it at a fixed rate to all other devices over the network via udp several times per second. On the devices with passive instances of this object, the data is received and stored as the desired state of its local twin. 

*puppeteer* does not simply set the position, rotation, etc. of the passive instances to the transmitted values. That would result in very choppy and laggy motions as there is no way to achieve anything like 50 or 60 frames per second when you transmit the required data in a network. 

Instead, *puppeteer* extrapolates from the transmitted data where the active gameobject will be at the time when the next data packet arrives, assuming that no change in direction, speed, etc. occurrs until then. Obviously, this will not always be the case, but then again, it is only a fraction of a second in the future, so most of the time, this method comes pretty close. 

Next, *puppeteer* calculates what direction, rotation, etc. is necessary for the passive instance in its current state to arrive at the desired condition and starts moving accordingly every frame until new information arrives. Ideally, that results in very smooth animations which are almost (but never quite) completely in sync with their active twins.

### Gameobject conventions to allow for sync
*puppeteer* can access much of the required information without the active gameobject being aware of it. A gameobject's position and rotation can be accessed from the outside, but gamelogic information like the direction in which a gameobject is planning to move, its speed, animation state or sound played cannot be known externally.

So, to allow for these values to be sent to the passive instances, every active gameobject must make this data available to *puppeteer*:

```` 
-- accessed automatically, no additional requirements
1. go.get_position() 
2. go.get_rotation()

-- accessed via public properties of the gameobject
-- must be declared in a script component with default name "script"
-- "dir" must be a normalized vector3 indicating the direction in which the gameobject is going to move. This can (but does not have to) relate to its rotation.
3. go.property( "dir", vmath.vector3() )

-- a number to indicate the "speed" with which the gameobject is going to move along its direction vector
4. go.property( "speed", 30.0 )

-- puppeteer methods instead of Defold standard:
-- use instead of sprite.play_flipbook( url, anim )
5. puppeteer:animate( url, anim )

-- instead of sound.play( url, props )
6a. Puppeteer:soundPlay( url, props ) 

-- instead of sound.stop( url, props )
6b. Puppeteer:soundStop( url, props ) 
```` 
### Commands
Internally, to sync state, *puppeteer* uses standardized objects for each event such as "create", "delete", "sync", etc. As a game developer, you do not need any of them (and in fact, should not mess around with them to prevent errors in your game).

It is the aim of nexus to not require you to write special code for synchronization issues in your game (with the exception of using the methods described above to provide required gamelogic information). 

However, there may be situations when you need to transmit some information from the active gameobject to all passive instances on remote devices. In Defold, obviously, passing around messages is a very common concept, but is limited to a single device.

*puppeteer*, however, has a method to send a custom message to a gameobject with a global id on all other devices:

```` 
local Commands = require( "nexus.commands" )

-- get the global id for this local gameobject
local gid = puppeteer:getGid( go.get_id() )

-- create a puppeteer command to transmit a custom message
-- Commands.newMessage( gid, message_id, message )
local cmd = Commands.newMessage( gid, "my-custom-msg", { 
	foo = "bar" 
})

-- transmit the message command to all other players
puppeteer:sendToOthers( cmd )
```` 
The message is delivered from the *puppeteer* instance on one device to those on all the others and then passed on locally via Defold's ```` msg.post( message_id, message )````  function. The receiver of this message can process the information as always in the gameobject's ```` on_message()````  method.








