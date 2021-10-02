local Serializable = require( "nexus.serializable" )
local Envelope = require( "nexus.envelope" )

local Syncmap = {}
Syncmap.__index = Syncmap

local EVENT_VAR_CHANGE = -999


-- Syncs key/values for game entities on all clients:
-- Global map synced among all hosts automatically.
function Syncmap.new( client )
	local this = {}
	setmetatable( this, Syncmap )

	this.client = client 
	this.namespaces = {}

	return this
end


--
function Syncmap:put( gid, key, value, isSyncNeeded )
	-- When nexus client receives a new value, it also uses this 
	-- method to update the local value and align it with the remote
	-- value. In that case, another sync request would be double,
	-- so isSyncNeeded = false prevents that 
	if isSyncNeeded == nil then isSyncNeeded = true end
	
	-- no key makes no sense
	if key == nil then return end

	-- create namespace if required
	if self.namespaces[ gid ] == nil then self.namespaces[ gid ] = {} end

	-- no change in value: no more action required. 
	-- Prevent endless loop!
	if self.namespaces[ gid ][ key ] == value then return end

	self.namespaces[ gid ][ key ] = value 

	-- is internal event: declare with (optional) parameter "true"
	local env = Envelope.new( EVENT_VAR_CHANGE, gid, true )
	local tv = type( value )

	if tv == "string" then 
		env:putString( key, value )

	elseif tv == "number" then 
		env:putNumber( key, value )

	elseif tv == "userdata" then 
		local udata = tostring( value )
		if udata:indexOf( "quat" ) > -1 then 
			env:putQuat( key, value )
		elseif udata:indexOf( "vector" ) > -1 then 
			env:putVector3( key, value )
		elseif udata:indexOf( "boolean" ) > -1 then 
			env:putBool( key, value )
		end

	elseif tv == "table" then 	
		env:putSerializable( key, value )

	elseif tv == "boolean" then 
		env:putBool( key, value ) 
	end

	if isSyncNeeded then 
		self.client:sendToOtherClients( env )
		-- self.client:send( "192.168.178.24", env )
	end
end


function Syncmap:get( gid, key )
	if self.namespaces[ gid ] == nil then return nil end
	return self.namespaces[ gid ][ key ]
end


return Syncmap


