
local Lua = require( "deflibs.lualib" )


local ConStack = {}
ConStack.__index = ConStack

function ConStack.new( max )
	local stack = {}
	setmetatable( stack, ConStack )

	stack.model = {}
	stack.max = max
	stack.startAt = 0
	stack.endAt = max
	stack.size = 0
	
	return stack
end


function ConStack:nextKey()
	self.startAt = self.startAt + 1
	local key = string.format( "%04d", self.startAt )
	
	
	return key
end


function ConStack:get( key )
	return self.model[ key ]
end


function ConStack:slice( omitFromLast, cnt )
	if omitFromLast == nil then omitFromLast = 0 end
	if cnt == nil then cnt = 1 end
	if cnt > self:length() then cnt = self:length() end

	local startAtIndex = self.startAt - omitFromLast
	
	local res = ConStack.new( cnt )
	for i = startAtIndex - cnt, startAtIndex, 1 do
		local key = string.format( "%04d", i )
		local value = self.model[ key ]
		res:push( value )
	end

	return res
end


function ConStack:last( cnt )
	return self:slice( 0, cnt )
end


function ConStack:push( value )
	local index = self:nextKey()
	local key = string.format( "%04d", index )
	self.model[ key ] = value
	self.size = self.size + 1

	if self.size > self.max then 
		local outdatedIndex = self.startAt - self.max 
		local outdatedKey = string.format( "%04d", outdatedIndex )
		self.model[ outdatedKey ] = nil
		self.size = self.size - 1
	end
end


function ConStack:length()
	return self.size
end


function ConStack:toString( withLineNo )
	if withLineNo == nil then withLineNo = false end
	
	local sb = StringBuilder.new() 
	for key, value in Lua.spairs( self.model ) do
		if withLineNo then sb:append( key ):append( " " ) end
		sb:append( value ):append( "\n" )
	end

	return sb:toString()
end


return ConStack
