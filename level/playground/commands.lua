local Envelope = require( "nexus.envelope" )

local Commands = {}

Commands.CREATE_PLAYER 		= 1
Commands.CREATE_ROBOT		= 2
Commands.MOVE_TO 			= 3
Commands.SET_PLAYER_DIR 	= 4
Commands.SET_PLAYER_POS  	= 5


function Commands.newCreatePlayer( gid, pos, speed, name, isLocalHero )
	local env = Envelope.new( Commands.CREATE_PLAYER, "playground:/level" )
	env:putString( "factory", "playground:/factories#playerfactory" )
	env:putString( "gid", gid )
	env:putVector3( "pos", pos )
	env:putString( "name", name )
	env:putNumber( "speed", speed )
	env:putBool( "isLocalHero", isLocalHero )
	return env
end


function Commands.newCreateRobot( gid, pos, speed, name )
	local env = Envelope.new( Commands.CREATE_ROBOT, "playground:/level", false )
	env:putString( "factory", "playground:/factories#robotfactory" )
	env:putString( "gid", gid )
	env:putVector3( "pos", pos )
	env:putNumber( "speed", speed )
	env:putString( "name", name )
	return env
end


function Commands.newMoveTo( gid, pos )
	local env = Envelope.new( Commands.MOVE_TO, gid, false )
	env:putVector3( "pos", pos )
	return env
end


function Commands.newSetPlayerDir( gid, dir )
	local env = Envelope.new( Commands.SET_PLAYER_DIR, gid, false )
	env:putVector3( "dir", dir )
	return env
end


-- Very many positioning cmds get sent: make sure only
-- the latest / a single one gets sent with every batch
function Commands.newSetPlayerPos( gid, pos )
	local env = Envelope.new( Commands.SET_PLAYER_POS, gid, true )
	env:putVector3( "pos", pos )
	return env
end


return Commands

