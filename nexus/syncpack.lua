local stringsub   	= string.sub
local stringfind  	= string.find
local sprintf 		= string.format
local tonumber 		= tonumber
local vmathvector3 	= vmath.vector3
local vmathquat 	= vmath.quat


local function stringsplit( txt, delim )
	local t = {} 
	local wordStart = 1
	local delimStart, delimEnd 
	local i = 1
	while true  do
		delimStart, delimEnd = stringfind( txt, delim, wordStart, true )
		if delimStart == nil then 
			if wordStart <= #txt then 
				t[ i ] = stringsub( txt, wordStart )
			end 
			break
		end
		t[ i ] = stringsub( txt, wordStart, delimStart - 1 )
		wordStart = delimEnd + 1

		i = i + 1
	end 
	return t
end


-- Syncpack --------------
local Syncpack = {}
Syncpack.__index = Syncpack

function Syncpack.new( gid )
	local this = {}
	setmetatable( this, Syncpack )

	this.gid = gid

	return this
end


function Syncpack:getGlobalId()
	return self.gid
end


function Syncpack:setPosition( pos )
	self.pos = pos
end


function Syncpack:getPosition()
	return self.pos
end


function Syncpack:setRotation( rot )
	self.rot = rot
end


function Syncpack:get( key )
	if self.attrs == nil then return nil end
	
	local tv = self.attrs[ key ]
	return tv.value
end


function Syncpack:hasCustomProps()
	return self.attrs ~= nil
end


function Syncpack:put( key, type, value )
	if self.attrs == nil then self.attrs = {} end
	self.attrs[ key ] = { type = type,  value = value }
end


function Syncpack:getRotation()
	return self.rot
end


function Syncpack:serialize()
	local cust = ""
	if self.attrs then 
		local tmp = {}
		local i = 1
		for key, tv in pairs( self.attrs ) do
			if tv.type == "v" then
				tmp[ i ] = key .. "|v|" .. tv.value.x .. "|" .. tv.value.y .. "|" .. tv.value.z
				i = i + 1
				
			elseif tv.type == "n" then 
				tmp[ i ] = key .. "|n|" .. tv.value
				i = i + 1

			elseif tv.type == "b" then 
				tmp[ i ] = key .. "|b|" .. tostring( tv.value )
				i = i + 1

			elseif tv.type == "q" then 
				tmp[ i ] = key .. "|v|" .. tv.value.x .. "|" .. tv.value.y .. "|" .. tv.value.z
				i = i + 1
				
			end
		end 
		cust = "|" .. table.concat( tmp, "|" )
		
	end
		
	return sprintf( "%s|%f|%f|%f|%f|%f|%f|%f%s",
		self.gid,
		self.pos.x, self.pos.y, self.pos.z,
		self.rot.x, self.rot.y, self.rot.z, self.rot.w,
		cust 
	)
end


function Syncpack.deserialize( serialized )
	local parts = stringsplit( serialized, "|" )

	local sync = Syncpack.new( parts[ 1 ] )
	sync.pos = vmathvector3( parts[ 2 ], parts[ 3 ], parts[ 4 ] ) 
	sync.rot = vmathquat( parts[ 5 ], parts[ 6 ], parts[ 7 ], parts[ 8 ] ) 

	if #parts > 8 then
		local i = 9
		local type
		local key
		local value 
		while parts[ i ] do
			key = parts[ i ]
			type = parts[ i + 1 ]
			
			if type == "v" then 
				sync:put( key, vmathvector3( 
					parts[ i + 2 ], parts[ i + 3 ], parts[ i + 4 ] 
				))
				i = i + 5
				
			elseif type == "q" then 
				sync:put( key, vmathquat( 
					parts[ i + 2 ], parts[ i + 3 ], parts[ i + 4 ], parts[ i + 5 ]  
				))
				i = i + 6
				
			elseif type == "b" then 
				sync:put( key, "true" == parts[ i + 2 ] )
				i = i + 3
				
			elseif type == "n" then 
				sync:put( key, tonumber( parts[ i + 2 ] ) )
				i = i + 3
				
			end
		end
	end
	
	return sync 
end


return Syncpack