-- Personality -----------------------
local Personality = {}
Personality.__index = Personality

function Personality.new( gid )
	local this = {}
	setmetatable( this, Personality )

	this.gid = gid
	this.behaviors = {}
	this.active = "default"

	return this
end 


function Personality:put( key, behavior )
	assert( behavior, "Please provide an object to handle behavior events!" )
	assert( behavior.init, "Your behavior object must provide an 'init()' method!" )
	assert( behavior.update, "Your behavior object must provide an 'update()' method!" )
	assert( behavior.onmessage, "Your behavior object must provide a 'handle()' method!" )
	assert( behavior.final, "Your behavior object must provide a 'final()' method!" )
	assert( behavior.transition == nil, "Method transition() will be overwritten! in your behavior object!" )

	if key == nil then key = "default" end
	
	local personality = self
	behavior.transition = function( self, key )
		personality:activate( key )
	end

	self.behaviors[ key ] = behavior
end


function Personality:activate( key )
	if key == nil then return end
	
	self.behaviors[ self.active ]:final( self.active )

	self.active = key
	if self.behaviors[ self.active ] then 
		self.behaviors[ self.active ]:init( self.active )
	end
end


function Personality:getActiveBehavior()
	return self.behaviors[ self.active ]
end


function Personality:update()
	self.behaviors[ self.active ]:update( self.active )
end


return Personality

