
function table.length( t )
	cnt = 0
	for k,v in pairs( t ) do cnt = cnt + 1 end
	return cnt
end

function table.contains( t, value )
	for k, v in pairs( t ) do
		if v == value then return true, k end
	end
	return false
end


-- make a copy of table with new objects.
-- include only keys from whitelist.
-- copy all if no list is provided.
function table.deepcopy( t, keylist )
	local clone = {}
	for k, v in pairs( t ) do 
		if( keylist == nil ) or contains( keylist, k ) then 
			if type( v ) == "table" then 
				clone[ k ] = table.deepcopy( v, keylist )
			else
				clone[ k ] = v
			end
		end
	end
	return clone
end


function table.containSameItems( tab1, tab2 )
	if( tab1 == nil ) and ( tab2 == nil ) then return true end
	if( tab1 == nil ) or ( tab2 == nil ) then return false end

	if table.length( tab1 ) ~= table.length( tab2 ) then 
		-- not the same amount of items in tables
		return false 
	end

	-- ordering of items in table should be of no consequence!
	local result = true
	for key, value in pairs( tab1 ) do
		-- recursive: check contents of table items
		if type( value ) == "table" then 
			result = result and table.containSameItems( value, tab2[ key ] )
		else
			-- simple item, must be contained and identical
			if value ~= tab2[ key ] then
				result = false
				break
			end
		end
	end

	return result
end


string.startsWith = function( s, start )
	return s:sub( 1, #start ) == start
end


string.endsWith = function( s, ending )
	return ending == "" or s:sub(-#ending) == ending
end


string.indexOf = function( s, txt, startAtPos )
	if startAtPos == nil then startAtPos = 0 end

	-- returns two values: start and end position!
	local start, stop = string.find( s, txt, startAtPos, true )
	if start then 
		return start 
	else
		return -1
	end
end

string.cntSubstr = function( s1, s2 )
	if s2 == nil then return 0 end
	if s2 == "." then s2 = "%." end

	return select( 2, s1:gsub( s2, "" ) )
end

