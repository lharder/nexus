-- SyncProvider -----------------------------------
local SyncProvider = {}
SyncProvider.__index = SyncProvider

function SyncProvider.create( fnGet, fnSet )
	assert( fnGet, "Syncprovider must have a 'get' function!" )
	assert( fnSet, "Syncprovider must have a 'set' function!" )

	local this 	= {}
	setmetatable( this, SyncProvider )
	
	this.fnGet 	= fnGet
	this.fnSet 	= fnSet

	return this
end

function SyncProvider:get( entity )
	return self.fnGet( entity )
end

function SyncProvider:set( entity, params )
	return self.fnSet( entity, params )
end


return SyncProvider



