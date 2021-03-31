local Registry = {}
Registry.__index = Registry

function Registry.new()
	local this = {}
	setmetatable( this, Registry )

	this.globalIds = {}
	this.clientIds = {}

	return this
end


function Registry:set( gid, cid )
	assert( gid, "Global id must not be nil!" )
	assert( cid, "Local client id must not be nil!" )
	
	self.globalIds[ cid ] = gid
	self.clientIds[ gid ] = cid
end


function Registry:remove( cid )
	local gid = self.globalIds[ cid ]
	self.clientIds[ gid ] = nil
	self.globalIds[ cid ] = nil
end


function Registry:getGlobalId( cid )
	return self.globalIds[ cid ]
end


function Registry:getClientId( gid )
	return self.clientIds[ gid ]
end


return Registry

