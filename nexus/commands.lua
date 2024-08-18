local Command = require( "nexus.command" )


local Commands = {}
Commands.PROPOSE		= 998
Commands.READYTOPLAY	= 997
Commands.STARTTOPLAY	= 996
Commands.TRIGGEREVENT	= 995

Commands.CREATE_DRONE 	= 1
Commands.DELETE 		= 2
Commands.UPDATE         = 3
Commands.CUSTOM_MESSAGE	= 4

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

