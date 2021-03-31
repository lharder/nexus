local Map = {}
Map.__index = Map

function Map.new()
	local this = {}
	setmetatable( this, Map )

	this.keyValues = {}
	this.orderedKeys = {}

	return this
end

function Map:put( key, value )
	table.insert( self.orderedKeys, key )
	self.keyValues[ key ] = value
end	

function Map:get( key )
	return self.keyValues[ key ]
end

function Map:has( key )
	return self.keyValues[ key ] ~= nil
end

function Map:size()
	return #self.orderedKeys
end

function Map:keys()
	return self.orderedKeys
end

function Map:contains( value )
	local res = false
	local k
	for _, key in ipairs( self:keys() ) do
		if self:get( key ) == value then
			res = true
			k = key
			break
		end
	end
	return res, k
end


return Map

