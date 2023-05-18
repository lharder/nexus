
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

