require( "deflibs.lualib" )


local Syncset = {}
Syncset.__index = Syncset

function Syncset.new( gid )
	local this = {}
	setmetatable( this, Syncset )

	this.gid = gid

	return this
end


function Syncset:getGlobalId()
	return self.gid
end


function Syncset:setPosition( pos )
	self.pos = pos
end


function Syncset:getPosition()
	return self.pos
end


function Syncset:setRotation( rot )
	self.rot = rot
end


function Syncset:getRotation()
	return self.rot
end


function Syncset:serialize()
	return sprintf( "%s|%d|%d|%d|%d|%d|%d|%d",
		self.gid,
		self.pos.x, self.pos.y, self.pos.z,
		self.rot.x, self.rot.y, self.rot.z, self.rot.w 
	)
end


function Syncset.deserialize( serialized )
	local parts = serialized:split( "|" )
	if #parts == 8 then 
		local sync = Syncset.new( parts[ 1 ] )
		sync.pos = vmath.vector3( tonumber( parts[ 2 ] ), tonumber( parts[ 3 ] ), tonumber( parts[ 4 ] ) ) 
		sync.rot = vmath.quat( tonumber( parts[ 5 ] ), tonumber( parts[ 6 ] ), tonumber( parts[ 7 ] ), tonumber( parts[ 8 ] ) ) 
		return sync 
	end
	return nil
end

--[[
function Syncset:serializeC()
	local nums = {}
	nums[ 1 ] = self.pos.x
	nums[ 2 ] = self.pos.y
	nums[ 3 ] = self.pos.z
	nums[ 4 ] = self.rot.x
	nums[ 5 ] = self.rot.y
	nums[ 6 ] = self.rot.z
	nums[ 7 ] = self.rot.w

	local ln 
	local parts = {}
	local j = 2
	for i = 1, 7, 1 do
		parts[ j ] = tostring( nums[ i ] )
		ln = #parts[ j ]
		parts[ j - 1 ] = string.char( ln )
		j = j + 2
	end

	return table.concat( parts )
end


function Syncset.deserializeC( serialized )
	local ln
	local raw
	local offstart = 1
	local max = #serialized
	local parts = {}
	local i = 1
	repeat
		ln = serialized:sub( offstart, offstart ):byte()
		parts[ i ] = serialized:sub( offstart + 1, offstart + ln )
		offstart = offstart + ln + 1
		i = i + 1
	until offstart >= max

	local sync = Syncset.new( parts[ 1 ] )
	sync.pos = vmath.vector3( tonumber( parts[ 2 ] ), tonumber( parts[ 3 ] ), tonumber( parts[ 4 ] ) )
	sync.rot = vmath.vector3( tonumber( parts[ 5 ] ), tonumber( parts[ 6 ] ), tonumber( parts[ 7 ] ), tonumber( parts[ 8 ] ) )
	
	return sync
end
--]]

return Syncset
