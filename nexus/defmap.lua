local Lua = require( "deflibs.lualib" )
local SEPARATOR = "|"


-- ArrayList --------------------
local ArrayList = {}
ArrayList.__index = ArrayList

function ArrayList.new( o )
	return setmetatable( o or {}, ArrayList )
end

function ArrayList:append( value )
	self[ #self + 1 ] = value
end

function ArrayList:slice( i, j )
	local ls = ArrayList.new()
	for i = i or 1, j or #self do
		ls:append( self[ i ] )
	end
	return ls
end


function ArrayList:length()
	return #self
end

function ArrayList:toString( sep )
	if sep == nil then sep = "," end
	return table.concat( self, sep )
end 


-- TypeValuePair -----------------------
local TypeValuePair = {}
function TypeValuePair.new( type, value, separator )
	if separator == nil then separator = SEPARATOR end
	
	local this = {}
	this.type = type
	this.value = value
	-- this.separator = separator

	function this:serializeValue()
		if this.type == "n" then 
			return string.format( "%f", this.value )
			
		elseif this.type == "s" then 
			return string.format( "%s", this.value )

		elseif this.type == "b" then 
			local no = 0
			if this.value then no = 1 end
			return string.format( "%d", no )

		elseif this.type == "v" then 
			return string.format( 
				"%f%s%f%s%f", 
				this.value.x, separator, 
				this.value.y, separator, 
				this.value.z 
			)

		elseif this.type == "q" then 
			return string.format( 
				"%f%s%f%s%f%s%f", 
				this.value.x, separator, 
				this.value.y, separator, 
				this.value.z, separator,  
				this.value.w
			)
		end
	end
	
	return this
end


function TypeValuePair.deserialize( type, values, separator )
	if( type == nil ) or ( values == nil ) then return nil end
	if separator == nil then separator = SEPARATOR end
	
	if type == "n" then 
		return 1, TypeValuePair.new( type, tonumber( values[ 1 ] ), separator )

	elseif type == "s" then 
		return 1, TypeValuePair.new( type, values[ 1 ], separator )

	elseif type == "b" then 
		local value = false
		if tonumber( values[ 1 ] ) == 1 then value = true end
		return 1, TypeValuePair.new( type, value, separator )
		
	elseif type == "v" then 
		local value = vmath.vector3( values[ 1 ], values[ 2 ], values[ 3 ] )
		return 3, TypeValuePair.new( type, value, separator )

	elseif type == "q" then 
		local value = vmath.quat( values[ 1 ], values[ 2 ], values[ 3 ], values[ 4 ] )
		return 4, TypeValuePair.new( type, value, separator )
	end
		
	return 0, nil
end


-- Defmap ------------------------------
local Defmap = {}

function Defmap.new( separator )
	local this = {}
	this.attrs = {}

	if separator == nil then separator = SEPARATOR end
	this.separator = separator

	function this:put( type, key, value )
		-- need reliable order of serialized key/values
		this.attrs[ key ] = TypeValuePair.new( type, value, this.separator )
	end 


	function this:remove( key )
		this.attrs[ key ] = nil
	end
	
	
	function this:putNumber( key, value )
		this:put( "n", key, value )
	end
	
	function this:putString( key, value )
		this:put( "s", key, value )
	end


	function this:putBool( key, value )
		this:put( "b", key, value )
	end
	

	function this:putVector3( key, value )
		this:put( "v", key, value )
	end
	

	function this:putQuat( key, value )
		this:put( "q", key, value )
	end

	
	function this:get( key )
		local tvp = this.attrs[ key ]
		if tvp == nil then return nil end
		return tvp.value
	end


	function this:serialize()
		local listKeys = {}
		local listTypes = {}
		local listValues = {}

		local typeValue
		for key, typeValue in pairs( this.attrs ) do 
			table.insert( listKeys, key )
			table.insert( listTypes, typeValue.type )
			table.insert( listValues, typeValue:serializeValue() )
		end

		local strKeys = table.concat( listKeys, "," )
		local strTypes = table.concat( listTypes, "," )
		local strValues = table.concat( listValues, this.separator )

		local serialized = StringBuilder.new()
		serialized:append( strKeys ):append( this.separator )
		serialized:append( strTypes ):append( this.separator )
		serialized:append( strValues )

		return serialized:toString()
	end


	function this:toTable()
		local t = {}
		for key, typeValuePair in pairs( self.attrs ) do
			t[ key ] = typeValuePair.value
		end
		return t
	end
	
	
	return this
end


function Defmap.deserialize( serialized, separator )
	if serialized == nil then return nil end
	if separator == nil then separator = SEPARATOR end

	local parts = ArrayList.new( serialized:split( separator ) )
	if #parts < 3 then return nil end

	local keys = parts[ 1 ]:split( "," )
	local types = parts[ 2 ]:split( "," )
	
	local values = parts:slice( 3 )
	local index = 1
	local map = Defmap.new( separator )
	for i, type in ipairs( types ) do
		local key = keys[ i ]
		local cnt, tvp = TypeValuePair.deserialize( type, values, separator )
		values = values:slice( cnt + 1 )
		map:put( type, key, tvp.value )
	end

	return map
end


return Defmap

