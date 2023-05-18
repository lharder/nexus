local Stack = {}
Stack.__index = Stack

function Stack.new()
	local this = {}
	setmetatable( this, Stack )

	-- entry table
	this._et = {}
	return this
end


-- push a value on to the stack
function Stack:push(...)
	if ... then
		local targs = {...}
		-- add values
		for _, v in ipairs( targs ) do
			table.insert( self._et, v )
		end
	end
end


-- pop a value from the stack
function Stack:pop( num )
	-- get num values from stack
	local num = num or 1

	-- return table
	local entries = {}

	-- get values into entries
	for i = 1, num do
		-- get last entry
		if #self._et ~= 0 then
			table.insert( entries, self._et[ #self._et ] )
			-- remove last value
			table.remove( self._et )
		else
			break
		end
	end
	
	-- return unpacked entries
	return unpack( entries )
end

-- get entries
function Stack:getn()
	return #self._et
end

-- list values
function Stack:list()
	for i,v in pairs(self._et) do
		print(i, v)
	end
end


return Stack

