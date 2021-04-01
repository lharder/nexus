local PlayerBehavior = {}
local Events = require( "level.playground.events" )


function PlayerBehavior.new( gid )
	local this = {}
	this.gid = gid

	
	function this:init( key )
	end
	

	function this:update()
	end


	function this:onmessage( evt, ip, port )
		if evt:getType() == Events.USER_DIR_CHANGED then 
			GAME.server:sendToClientsExcept( ip,   
				Events.newSetPlayerDir( evt:getUrl(), evt:get( "dir" ) )
			)
		end
	end

	
	function this:final()
	end

	return this
end


return PlayerBehavior

