local Envelope = require( "nexus.envelope" )

local Events = {}

Events.CREATE_PLAYER 		= 1
Events.CREATE_ROBOT			= 2
Events.MOVE_TO 				= 3 
Events.POSITION_REACHED 	= 4

Events.names = {}
Events.names[ 1 ] = "CREATE_PLAYER"
Events.names[ 2 ] = "CREATE_ROBOT"
Events.names[ 3 ] = "MOVE_TO"
Events.names[ 4 ] = "POSITION_REACHED"


function Events.newCreatePlayer( gid, pos, speed, name, isLocalHero )
	local env = Envelope.new( Events.CREATE_PLAYER, "playground:/level" )
	env:put( "factory", "playground:/factories#playerfactory" )
	env:put( "gid", gid )
	env:put( "pos", pos )
	env:put( "name", name )
	env:put( "speed", speed )
	env:put( "isLocalHero", isLocalHero )
	return env
end


function Events.newCreateRobot( gid, pos, speed, name )
	local env = Envelope.new( Events.CREATE_ROBOT, "playground:/level", false )
	env:put( "factory", "playground:/factories#robotfactory" )
	env:put( "gid", gid )
	env:put( "pos", pos )
	env:put( "speed", speed )
	env:put( "name", name )
	return env
end


function Events.newMoveTo( gid, pos )
	local env = Envelope.new( Events.MOVE_TO, gid, false )
	env:put( "pos", pos )
	return env
end


function Events.newPositionReached( gid, pos )
	local env = Envelope.new( Events.POSITION_REACHED, gid )
	env:put( "pos", pos )
	return env
end


function Events.getName( evt )
	-- no need to send these strings over the
	-- wire, but useful for debugging....
	return( Events.names[ evt:getType() ] )
end

return Events


