require( "deflibs.lualib" )

-- Serializable -----------------------
local Serializable = {}
Serializable.__index = Serializable


-- TypeValuePair -----------------------
local TypeValuePair = {}
function TypeValuePair.new( type, value )

	local this = {}
	this.type = type
	this.value = value

	function this:serialize()
		if this.type == "n" then 
			local tmp = tostring( this.value )
			return "n" .. string.char( #tmp ) .. tmp

		elseif this.type == "s" then 
			return "s" .. string.char( #this.value ) .. this.value 

		elseif this.type == "b" then 
			if this.value then 
				return "b" .. string.char( 1 ) .. "1" 
			else 
				return "b" .. string.char( 1 ) .. "0" 
			end
			
		elseif this.type == "v" then 
			local tx = tostring( this.value.x )
			local ty = tostring( this.value.y )
			local tz = tostring( this.value.z )
			return "v" .. string.char( #tx ) .. tx .. string.char( #ty ) .. ty .. string.char( #tz ) .. tz 
			
		elseif this.type == "q" then 
			local tx = tostring( this.value.x )
			local ty = tostring( this.value.y )
			local tz = tostring( this.value.z )
			local tw = tostring( this.value.w )
			return "q" .. string.char( #tx ) .. tx .. string.char( #ty ) .. ty .. string.char( #tz ) .. tz .. string.char( #tw ) .. tw

		elseif this.type == "x" then 
			local ts = this.value:serialize()
			return "x" .. string.char( #ts ) .. ts
			
		end
	end
	
	return this
end


function TypeValuePair.deserialize( serialized )
	-- {type}{length of value as char}{value}
	local tvp

	local type = serialized:sub( 1, 1 )
	local lnValue
	local offset = 0
	local values = {}

	lnValue = serialized:byte( 2, 2 )
	values[ 1 ]  = serialized:sub( 3, 2 + lnValue )
	offset = 3 + lnValue
	
	if type == "n" then
		tvp = TypeValuePair.new( type, tonumber( values[ 1 ] ) )
		
	elseif type == "s" then
		tvp = TypeValuePair.new( type, values[ 1 ] ) 
		
	elseif type == "b" then 
		tvp = TypeValuePair.new( type, values[ 1 ] == "1" ) 

	elseif type == "v" then 
		lnValue = serialized:byte( offset, offset )
		values[ 2 ] = serialized:sub( offset + 1, offset + lnValue )	
		offset = offset + 1 + lnValue

		lnValue = serialized:byte( offset, offset )
		values[ 3 ] = serialized:sub( offset + 1, offset + lnValue )	
		offset = offset + 1 + lnValue
		
		tvp = TypeValuePair.new( type, vmath.vector3(
			values[ 1 ], values[ 2 ], values[ 3 ] 
		)) 

	elseif type == "q" then 
		lnValue = serialized:byte( offset, offset )
		values[ 2 ] = serialized:sub( offset + 1, offset + lnValue )	
		offset = offset + 1 + lnValue

		lnValue = serialized:byte( offset, offset )
		values[ 3 ] = serialized:sub( offset + 1, offset + lnValue )	
		offset = offset + 1 + lnValue

		lnValue = serialized:byte( offset, offset )
		values[ 4 ] = serialized:sub( offset + 1, offset + lnValue )	
		offset = offset + 1 + lnValue
		
		tvp = TypeValuePair.new( type, vmath.quat(
			values[ 1 ], values[ 2 ], values[ 3 ], values[ 4 ]  
		)) 

	elseif type == "x" then 
		local nested = Serializable.deserialize( values[ 1 ] )
		tvp = TypeValuePair.new( type, nested ) 
		
	end

	-- return object and the part of serialized that has not been processed yet
	return tvp, serialized:sub( offset )
end


--------------------------
function Serializable.new()
	local this = {}
	setmetatable( this, Serializable )

	this.attrs = {}
	
	return this
end


function Serializable:put( type, key, value )
	self.attrs[ key ] = TypeValuePair.new( type, value )
end


function Serializable:putNumber( key, value )
	self:put( "n", key, value )
end


function Serializable:putString( key, value )
	self:put( "s", key, value )
end


function Serializable:putBool( key, value )
	self:put( "b", key, value )
end


function Serializable:putVector3( key, value )
	self:put( "v", key, value )
end


function Serializable:putQuat( key, value )
	self:put( "q", key, value )
end


function Serializable:putSerializable( key, value )
	self:put( "x", key, value )
end


function Serializable:get( key )
	local tvp = self.attrs[ key ]
	if tvp == nil then return nil end
	return tvp.value
end


function Serializable:toTable()
	local t = {}
	for key, typeValuePair in pairs( self.attrs ) do
		t[ key ] = typeValuePair.value
	end
	return t
end


function Serializable:serialize()
	-- {length of key as char 1-255}{key}{type}{length of value as char}{value}
	local parts = {}
	local i = 1
	for key, tvp in pairs( self.attrs ) do 
		parts[ i ] = string.char( #key ) .. key .. tvp:serialize()
		i = i + 1
	end

	return table.concat( parts )
end



function Serializable.deserialize( serialized )
	local key
	local lnKey
	local tvp
	local offset
	local obj = Serializable.new()
	repeat
		lnKey = serialized:byte( 1, 1 )
		key = serialized:sub( 2, 1 + lnKey )
		
		tvp, serialized = TypeValuePair.deserialize( serialized:sub( 2 + lnKey ) )
		obj:put( tvp.type, key, tvp.value )

	until #serialized == 0

	return obj	
end


return Serializable

