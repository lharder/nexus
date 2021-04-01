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
	end

	
	function this:final()
	end

	return this
end


return PlayerBehavior

