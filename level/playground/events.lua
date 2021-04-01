local Envelope = require( "nexus.envelope" )

local Events = {}

Events.CREATE_PLAYER 		= 1
Events.CREATE_ROBOT			= 2
Events.MOVE_TO 				= 3
Events.SET_PLAYER_POS  		= 4
Events.POSITION_REACHED 	= 5
Events.USER_DIR_CHANGED		= 6

Events.names = {}
Events.names[ 1 ] = "CREATE_PLAYER"
Events.names[ 2 ] = "CREATE_ROBOT"
Events.names[ 3 ] = "MOVE_TO"
Events.names[ 4 ] = "SET_PLAYER_POS"
Events.names[ 5 ] = "POSITION_REACHED"
Events.names[ 6 ] = "USER_DIR_CHANGED"


function Events.newCreatePlayer( gid, pos, speed, name, isLocalHero )
	local env = Envelope.new( Events.CREATE_PLAYER, "playground:/level" )
	env:putString( "factory", "playground:/factories#playerfactory" )
	env:putString( "gid", gid )
	env:putVector3( "pos", pos )
	env:putString( "name", name )
	env:putNumber( "speed", speed )
	env:putBool( "isLocalHero", isLocalHero )
	return env
end


function Events.newCreateRobot( gid, pos, speed, name )
	local env = Envelope.new( Events.CREATE_ROBOT, "playground:/level", false )
	env:putString( "factory", "playground:/factories#robotfactory" )
	env:putString( "gid", gid )
	env:putVector3( "pos", pos )
	env:putNumber( "speed", speed )
	env:putString( "name", name )
	return env
end


function Events.newMoveTo( gid, pos )
	local env = Envelope.new( Events.MOVE_TO, gid, false )
	env:putVector3( "pos", pos )
	return env
end


function Events.newSetPlayerPos( gid, pos )
	-- Very many positioning events get sent: make sure only
	-- the latest / a single one gets sent with every batch
	local env = Envelope.new( Events.SET_PLAYER_POS, gid, true )
	env:putVector3( "pos", pos )
	return env
end


function Events.newPositionReached( gid, pos )
	local env = Envelope.new( Events.POSITION_REACHED, gid )
	env:putVector3( "pos", pos )
	return env
end


function Events.newUserDirChanged( gid, dir )
	local env = Envelope.new( Events.USER_DIR_CHANGED, gid )
	env:putVector3( "dir", dir )
	return env
end


function Events.getName( evt )
	-- no need to send these strings over the
	-- wire, but useful for debugging....
	return( Events.names[ evt:getType() ] )
end

return Events


