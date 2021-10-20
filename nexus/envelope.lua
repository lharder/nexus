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
	
	o:put( "_meta_url", url )
	o:put( "_meta_type", type )  
	o:put( "_meta_internal", isNexusInternal )  

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
	return self:put( "_meta_url", url ) 
end

function Envelope:getUrl( )
	return self:get( "_meta_url" )
end


function Envelope:setIP( ip )
	self:put( "_meta_ip", ip )
end

function Envelope:getIP()
	return self:get( "_meta_ip" )
end


function Envelope:setPort( port )
	return self:put( "_meta_port", port )
end

function Envelope:getPort()
	return self:get( "_meta_port" )
end


function Envelope:getType( )
	return self:get( "_meta_type" )
end

function Envelope:setType( type )
	return self:put( "_meta_type", type )
end


function Envelope:isInternal()
	return self:get( "_meta_internal" )
end


function Envelope:deepCopy()
	return Envelope.deserialize( self:serialize() )
end


function Envelope:toTable( serialized )
	local t = {}
	t.meta = {}
	t.attrs = {}
	for key, value in pairs( self.attrs ) do
		if startsWith( key, "_meta_" ) then 
			key = stringsub( key, 7 ) 
			t.meta[ key ] = value
		else 
			t.attrs[ key ] = value
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


