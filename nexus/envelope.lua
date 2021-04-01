local Defmap = require( "nexus.defmap" )


local Envelope = {}
Envelope.__index = Envelope

function Envelope.new( type, url, latestOnly )
	local this = {}
	setmetatable( this, Envelope )

	assert( type, "Type of envelope required!" )
	assert( url, "Url for envelope processing required!" )
	if latestOnly == nil then latestOnly = false end
	
	this.meta = Defmap.new( "||" )
	this.meta:putString( "url", url )
	this.meta:putNumber( "type", type )  
	this.meta:putBool( "latestOnly", latestOnly )  
	
	this.attrs = Defmap.new( "||" )

	return this
end


function Envelope:serialize()
	local env = Defmap.new( "|||" )
	local strMeta = self.meta:serialize()
	local strAttrs = self.attrs:serialize()
	env:putString( "meta", strMeta )
	env:putString( "attrs", strAttrs )
	
	return env:serialize()
end


-- Meta data for reliable internal handling ------
function Envelope:setUrl( url )
	return self.meta:putString( "url", url )
end

function Envelope:getUrl( )
	return self.meta:get( "url" )
end


function Envelope:setIP( ip )
	return self.meta:putString( "ip", ip )
end

function Envelope:getIP()
	return self.meta:get( "ip" )
end


function Envelope:setPort( port )
	return self.meta:putNumber( "port", port )
end

function Envelope:getPort()
	return self.meta:get( "port" )
end


function Envelope:getType( )
	return self.meta:get( "type" )
end

function Envelope:setType( type )
	return self.meta:putNumber( "type", type )
end


function Envelope:getLatestOnly( )
	return self.meta:get( "latestOnly" )
end

function Envelope:setLatestOnly( isLatestOnly )
	return self.meta:setBool( "latestOnly", isLatestOnly )
end


-- Custom defined attributes -------------------
function Envelope:putNumber( key, value )
	self.attrs:putNumber( key, value )
end


function Envelope:putString( key, value )
	self.attrs:putString( key, value )
end


function Envelope:putBool( key, value )
	self.attrs:putBool( key, value )
end


function Envelope:putVector3( key, value )
	self.attrs:putVector3( key, value )
end


function Envelope:putQuat( key, value )
	self.attrs:putQuat( key, value )
end


function Envelope:get( key )
	return self.attrs:get( key )
end


function Envelope:toTable()
	local t = {}
	t.meta = self.meta:toTable()
	t.attrs = self.attrs:toTable()
	return t
end


function Envelope:deepCopy()
	return Envelope.deserialize( self:serialize() )
end


function Envelope.deserialize( serialized )
	assert( serialized ~= "", "You must provide a serialized envelope string!" )
	assert( serialized, "You must provide a serialized envelope string!" )
	
	local env = Defmap.deserialize( serialized, "|||" )
	local serializedMeta = env:get( "meta" )
	local serializedAttrs = env:get( "attrs" )
	
	local meta = Defmap.deserialize( serializedMeta, "||" )
	local attrs = Defmap.deserialize( serializedAttrs, "||" )
	
	local env = Envelope.new( 
		meta:get( "type" ), meta:get( "url" ), meta:get( "latestOnly" ) 
	)
	env.attrs = attrs

	return env
end


return Envelope


