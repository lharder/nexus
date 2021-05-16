local Serializable = require( "nexus.serializable" )

-- Helper, fast -----------------
local stringsub   = string.sub
local startsWith = function( s, start )
	return stringsub( s, 1, #start ) == start
end


local Envelope = {}
Envelope.__index = Envelope

function Envelope.new( type, url )
	local this = {}
	setmetatable( this, Envelope )

	-- assert( type, "Type of envelope required!" )
	-- assert( url, "Url for envelope processing required!" )

	this.serializer = Serializable.new()
	this.serializer:putString( "_meta_url", url )
	this.serializer:putNumber( "_meta_type", type )  

	return this
end

-- standard serialization

-- Custom defined attributes -------------------
function Envelope:putNumber( key, value )
	self.serializer:putNumber( key, value )
end


function Envelope:putString( key, value )
	self.serializer:putString( key, value )
end


function Envelope:putBool( key, value )
	self.serializer:putBool( key, value )
end


function Envelope:putVector3( key, value )
	self.serializer:putVector3( key, value )
end


function Envelope:putQuat( key, value )
	self.serializer:putQuat( key, value )
end


function Envelope:get( key )
	return self.serializer:get( key )
end


function Envelope:serialize()
	return self.serializer:serialize()
end


-- Meta data for reliable internal handling ------
function Envelope:setUrl( url )
	return self.serializer:putString( "_meta_url", url )
end

function Envelope:getUrl( )
	return self.serializer:get( "_meta_url" )
end


function Envelope:setIP( ip )
	return self.serializer:putString( "_meta_ip", ip )
end

function Envelope:getIP()
	return self.serializer:get( "_meta_ip" )
end


function Envelope:setPort( port )
	return self.serializer:putNumber( "_meta_port", port )
end

function Envelope:getPort()
	return self.serializer:get( "_meta_port" )
end


function Envelope:getType( )
	return self.serializer:get( "_meta_type" )
end

function Envelope:setType( type )
	return self.serializer:putNumber( "_meta_type", type )
end


function Envelope:deepCopy()
	return Envelope.deserialize( self.serializer:serialize() )
end


function Envelope:toTable( serialized )
	local t = {}
	t.meta = {}
	t.attrs = {}
	for key, typeValuePair in pairs( self.serializer.attrs ) do
		if startsWith( key, "_meta_" ) then 
			key = stringsub( key, 7 ) 
			t.meta[ key ] = typeValuePair.value
		else 
			t.attrs[ key ] = typeValuePair.value
		end

	end
	return t
end 


function Envelope.deserialize( serialized )
	local env = Envelope.new()
	env.serializer = Serializable.deserialize( serialized )
	return env
end


return Envelope


