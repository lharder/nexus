local Command = require( "nexus.command" )


local Commands = {}
Commands.ANNOUNCE 		= 999
Commands.PROPOSE		= 998
Commands.READYTOPLAY	= 997
Commands.STARTTOPLAY	= 996
Commands.TRIGGEREVENT	= 995

Commands.CREATE_DRONE 	= 1
Commands.DELETE 		= 2
Commands.UPDATE         = 3
Commands.CUSTOM_MESSAGE	= 4

-- Announce profile -----------------------------
-- the profile of the player with callsign and ip:port under which
-- that host listens for communication, e.g. 192.168.178.24:8888,
-- as its distinctive profile id. On the receiving "onData()" end, 
-- only the ip and outgoing client port number are available.
function Commands.newAnnounceProfile( callsign, gamename, gameversion, ip, port ) 
	assert( callsign, "Announce command must have a callsign!" )
	assert( ip, "Announce command must have an ip address!" )
	assert( port, "Announce command must have a port number!" )
	
	local this = Command.create( Commands.ANNOUNCE )

	this:put( "id", ( "%s:%s" ):format( ip, port ) )
	this:put( "callsign", callsign )
	this:put( "gamename", gamename )
	this:put( "gameversion", gameversion )
		
	return this 
end

-- Propose match constellation ----------
function Commands.newProposal( profiles, senderIp, senderPort ) 
	assert( profiles, "Proposal command must have a list of chosen profiles!" )
	assert( senderIp, "Proposal command needs the sender's ip address!" )
	assert( senderPort, "Proposal command needs the sender's port number!" )
	
	local this = Command.create( Commands.PROPOSE )
	this:put( "id", ( "%s:%s" ):format( senderIp, senderPort ) )
	this:put( "profiles", profiles )

	return this 
end


-- Inform selected gamemaster of readiness to play ----------
function Commands.newReadyToPlay( senderIp, senderPort ) 
	assert( senderIp, "ReadyToPlay command needs the sender's ip address!" )
	assert( senderPort, "ReadyToPlay command needs the sender's port number!" )
	
	local this = Command.create( Commands.READYTOPLAY )
	this:put( "id", ( "%s:%s" ):format( senderIp, senderPort ) )
	
	return this 
end

-- command from the game master that the game begins ----------
function Commands.newStartToPlay() 
	return Command.create( Commands.STARTTOPLAY )
end


-- Create -----------------------------
function Commands.newCreateDrone( gid, factName, pos, rot, params, scale, speed ) 
	local this = Command.create( Commands.CREATE_DRONE )

	this:put( "gid", gid )
	this:put( "factName", factName )
	this:put( "pos", pos )
	this:put( "rot", rot )
	this:put( "scale", scale )
	this:put( "speed", speed )
	this:put( "params", params )
	
	return this
end


function Commands.newDelete( gid, pos ) 
	local this = Command.create( Commands.DELETE )

	this:put( "gid", gid )
	this:put( "pos", pos )

	return this
end


-- Update -----------------------------
function Commands.newUpdate( gid, params ) 
	local this = Command.create( Commands.UPDATE )
	this.attrs = params or {} 
	this:put( "gid", gid )

	return this
end


-- Trigger event -----------------------
function Commands.newTriggerEvent( evtname ) 
	local this = Command.create( Commands.TRIGGEREVENT )
	this:put( "evtname", evtname )

	return this
end


-- Custom -----------------------------
function Commands.newMessage( gid, params ) 
	local this = Command.create( Commands.CUSTOM_MESSAGE )
	this.attrs = params or {} 
	this:put( "gid", gid )

	return this
end


return Commands

