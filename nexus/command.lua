
-- Command -----------------------------
local Command = {} 
Command.__index = Command

function Command.create( type ) 
	local this = {}
	this = setmetatable( this, Command )

	this.type = type
	this.attrs = {}
	
	return this
end

function Command:put( key, value ) self.attrs[ key ] = value end
function Command:get( key ) return self.attrs[ key ] end

function Command:serialize() 
	return sys.serialize( { type = self.type,  attrs = self.attrs } )
end

return Command

