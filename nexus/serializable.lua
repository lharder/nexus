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


function Serializable.deserialize( serialized, asTable )
	if asTable then 
		return sys.deserialize( serialized )
	else
		local obj = sys.deserialize( serialized )
		setmetatable( obj, Serializable )
		return obj
	end
end


return Serializable

