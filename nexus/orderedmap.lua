local OrderedMap = {}
OrderedMap.__index = OrderedMap

function OrderedMap.new()
	local this = {}
	setmetatable( this, OrderedMap )

	this.keyValues = {}
	this.orderedKeys = {}

	return this
end

function OrderedMap:put( key, value )
	table.insert( self.orderedKeys, key )
	self.keyValues[ key ] = value
end	

function OrderedMap:get( key )
	return self.keyValues[ key ]
end

function OrderedMap:has( key )
	return self.keyValues[ key ] ~= nil
end

function OrderedMap:size()
	return #self.orderedKeys
end

function OrderedMap:keys()
	return self.orderedKeys
end

function OrderedMap:contains( value )
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


return OrderedMap

