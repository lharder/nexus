local Serializable = require( "nexus.serializable" )

-- Helper, fast -----------------
local stringsub   = string.sub
local startsWith = function( s, start )
	return stringsub( s, 1, #start ) == start
end


local Envelope = Serializable.new()

function Envelope.new( type, url )
	local o = Serializable:new()
	o = setmetatable( o, Envelope )
	Envelope.__index = Envelope

	o:putString( "_meta_url", url )
	o:putNumber( "_meta_type", type )  

	return o
end

-- Meta data for reliable internal handling ------
function Envelope:setUrl( url )
	return self:putString( "_meta_url", url )
end

function Envelope:getUrl( )
	return self:get( "_meta_url" )
end


function Envelope:setIP( ip )
	return self:putString( "_meta_ip", ip )
end

function Envelope:getIP()
	return self:get( "_meta_ip" )
end


function Envelope:setPort( port )
	return self:putNumber( "_meta_port", port )
end

function Envelope:getPort()
	return self:get( "_meta_port" )
end


function Envelope:getType( )
	return self:get( "_meta_type" )
end

function Envelope:setType( type )
	return self:putNumber( "_meta_type", type )
end


function Envelope:deepCopy()
	return Envelope.deserialize( self:serialize() )
end


function Envelope:toTable( serialized )
	local t = {}
	t.meta = {}
	t.attrs = {}
	for key, typeValuePair in pairs( self.attrs ) do
		if startsWith( key, "_meta_" ) then 
			key = stringsub( key, 7 ) 
			t.meta[ key ] = typeValuePair.value
		else 
			if typeValuePair.type == "x" then
				t.attrs[ key ] = typeValuePair.value:serialize()
			else
				t.attrs[ key ] = typeValuePair.value
			end
		end

	end
	return t
end 



function Envelope.deserialize( serialized ) 
	local o = Serializable.deserialize( serialized )
	setmetatable( o, Envelope )
	Envelope.__index = Envelope
	return o
end

return Envelope


