local Envelope = require( "nexus.envelope" )

local Events = {}

Events.POSITION_REACHED 		= 100
Events.USER_DIR_CHANGED			= 101


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


return Events


