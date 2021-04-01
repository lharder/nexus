local RobotBehavior = {}
local Events = require( "level.playground.events" )


local function getNewTargetEvt( self )
	local pos = vmath.vector3( math.random( 100, 1000 ), math.random( 50, 600 ), .5 )
	local evt = Events.newMoveTo( self.gid, pos )
	return evt
end


function RobotBehavior.new( gid )
	local this = {}
	this.gid = gid

	
	function this:init( key )
		GAME.server:sendToClients( getNewTargetEvt( self ) )
	end
	

	function this:update()
	end


	function this:onmessage( evt, ip, port )
		-- pprint( evt:getUrl() )
		GAME.server:sendToClients( getNewTargetEvt( this ) )
	end

	
	function this:final()
	end

	return this
end


return RobotBehavior

