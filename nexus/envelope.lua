local Serializable = require( "nexus.serializable" )

-- Helper, fast -----------------
local stringsub   = string.sub
local startsWith = function( s, start )
	return stringsub( s, 1, #start ) == start
end


local Envelope = Serializable.new() 

-- type: for game logic to decide how to process enclosed data
-- url: globalId or absolute url for object to receive the data as message
-- isNexusInternal: allow for nexus to use envelopes, types, etc. independently
function Envelope.new( type, url, isNexusInternal )
	local o = Serializable:new()
	o = setmetatable( o, Envelope )
	Envelope.__index = Envelope

	if isNexusInternal == nil then isNexusInternal = false end

	o.attrs = {}
	o.meta = {}
	
	o.meta[ "url" ] 	 = url 
	o.meta[ "type" ] 	 = type 
	o.meta[ "internal" ] = isNexusInternal 

	return o
end


-- make sure to distiguish user data / attrs 
-- from meta data and functions
function Envelope:put( key, value )
	self.attrs[ key ] = value
end

function Envelope:get( key )
	return self.attrs[ key ]
end


-- Meta data for reliable internal handling ------
function Envelope:setUrl( url )
	self.meta[ "url" ] = url 
end

function Envelope:getUrl()
	return self.meta[ "url" ]
end


function Envelope:setIP( ip )
	self.meta[ "ip" ] = ip
end

function Envelope:getIP()
	return self.meta[ "ip" ]
end


function Envelope:setPort( port )
	self.meta[ "port" ] = port
end

function Envelope:getPort()
	return self.meta[ "port" ]
end


function Envelope:getType( )
	return self.meta[ "type" ]
end

function Envelope:setType( type )
	self.meta[ "type" ] = type
end


function Envelope:isInternal()
	return self.meta[ "internal" ]
end


function Envelope:deepCopy()
	return Envelope.deserialize( self:serialize() )
end


function Envelope:toTable()
	local t = {}
	t.meta = self.meta
	t.attrs = self.attrs 
	
	return t
end 



function Envelope.deserialize( serialized ) 
	local o = Serializable.deserialize( serialized )
	setmetatable( o, Envelope )
	Envelope.__index = Envelope
	return o
end

return Envelope


