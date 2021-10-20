local Serializable = {}
Serializable.__index = Serializable


function Serializable.new()
	local this = {}
	setmetatable( this, Serializable )
	
	return this	
end 


function Serializable:put( key, value )
	self[ key ] = value
end


function Serializable:get( key )
	return self[ key ]
end


function Serializable:serialize()
	return sys.serialize( self )
end


function Serializable.deserialize( serialized )
	return sys.deserialize( serialized )
end


return Serializable

