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
	if self.keyValues[ key ] == nil then 
		self.orderedKeys[ #self.orderedKeys + 1 ] = key
	end
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

function OrderedMap:indexOf( key )
	if key == nil then return end
	local index = nil
	for i, v in ipairs( self.orderedKeys ) do
		if v == key then return i end
	end
	return nil
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

function OrderedMap:remove( key )
	if key == nil then return nil end
	self.keyValues[ key ] = nil
	
	-- must adjust index
	local first = self:indexOf( key )
	if first == nil then return end 
	for i = first, #self.orderedKeys - 1, 1 do
		self.orderedKeys[ i ] = self.orderedKeys[ i + 1 ]
	end
	self.orderedKeys[ #self.orderedKeys ] = nil
end


function OrderedMap:tostring() 
	local s = ""
	for i, key in ipairs( self.orderedKeys ) do
		s = s .. ( "%s=%s\n"):format( key, tostring( self.keyValues[ key ] ) ) 
	end
	return s
end

return OrderedMap

