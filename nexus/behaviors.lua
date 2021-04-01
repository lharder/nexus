local Personality = require( "nexus.personality" )


-- Behaviors -----------------------
local Behaviors = {}
Behaviors.__index = Behavior

function Behaviors.new()
	local this = {}
	setmetatable( this, Behaviors )

	this.personalities = {}
	
	return this
end 


function Behaviors:put( gid, behavior, key )
	assert( gid, "Please provide the global id of the gameobject!" )
	if key == nil then key = "default" end

	if self.personalities[ gid ] == nil then 
		self.personalities[ gid ] = Personality.new( gid )
	end

	self.personalities[ gid ]:put( key, behavior )
end



function Behaviors:update()
	for gid, personality in self.personalities do
		personality:update()
	end
end


function Behaviors:onmessage()
end


return Behaviors


