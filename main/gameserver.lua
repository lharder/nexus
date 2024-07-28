local SyncProvider = require( "nexus.syncprovider" )
local gameserver = require( "nexus.nexus" ).create( "DemoGame", "1.0" )

gameserver:setSyncProvider( SyncProvider.create( 
	-- get params
	function( entity ) 
		entity.params.pos = go.get_position( entity.id )
		entity.params.rot = go.get_rotation( entity.id )
		return entity.params
	end, 
	-- set params
	function( entity, params ) 
		go.animate( entity.id, "position", go.PLAYBACK_ONCE_FORWARD, params.pos, go.EASING_LINEAR, .2 )
		go.animate( entity.id, "rotation", go.PLAYBACK_ONCE_FORWARD, params.rot, go.EASING_LINEAR, .2 )
		entity.params = params
	end )
)


return gameserver


