local RobotBehavior = {}
local Commands = require( "level.playground.commands" )


local function getNewTargetCmd( self )
	local pos = vmath.vector3( math.random( 100, 1000 ), math.random( 50, 600 ), .5 )
	local cmd = Commands.newMoveTo( self.gid, pos )
	return cmd
end


function RobotBehavior.new( gid )
	local this = {}
	this.gid = gid

	
	function this:init( key )
		GAME.server:sendToClients( getNewTargetCmd( self ) )
	end
	

	function this:update()
	end


	function this:onmessage( evt, ip, port )
		-- pprint( evt:getUrl() )
		GAME.server:sendToClients( getNewTargetCmd( this ) )
	end

	
	function this:final()
	end

	return this
end


return RobotBehavior

