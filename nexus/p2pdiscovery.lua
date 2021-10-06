-- P2P broadcasting is no longer allowed under iOS 14 :o(
-- This class is not elegant, but gets the job done.
-- Important: must use UDP ports used by Apple, as well...
local udp = require "defnet.udp"
local Localhost = require( "nexus.localhost" )


local function startsWith( str, start )
	if str == nil or start == nil then return false end
	return str:sub( 1, #start ) == start
end


local function getLocalPeerIPs()
	local ip = Localhost.getIP()

	local octets = Localhost.getOctets( ip )
	if octets == nil then return end  
	local myOctet = tonumber( octets[ 4 ] )
	octets[ 4 ] = nil
	
	local ips = {}
	for i = 1, 255, 1 do 
		ips[ i ] = table.concat( octets, "." ) .. "." .. i
		-- pprint( ips[ i ] )
	end

	return ips
end



local M = {}
M.__index = M

function M.create( port )
	local this = {}
	setmetatable( this, M )
	
	this.port = port
	
	return this
end


function M:broadcast( msg )
	-- create only if not available yet
	if self.srv == nil then 
		self.srv = udp.create( function( data, ip, port )	
			-- no reaction for broadcasting only
		end, self.port )
	end
	
	local index = 1
	local ip
	local peerIPs = getLocalPeerIPs()
	timer.delay( .020, true, function( this, handle, dt ) 
		-- pprint( dt )
		ip = peerIPs[ index ]
		if ip then self.srv.send( msg, ip, self.port ) end
		index = index + 1
		if index >= 255 then 
			-- prepare next run...
			index = 1 
			
			-- apart from regular 255 ips, is there a custom ip declared by user?
			-- if so, try that one, as well (once every run)
			if self.customIP then 
				local parts = self.customIP:split( ":" )
				if #parts == 2 then
					self.srv.send( msg, parts[ 1 ], parts[ 2 ] ) 
				else
					self.srv.send( msg, self.customIP, self.port ) 
				end
			end
		end
	end )
end


function M:setCustomIP( ip )
	self.customIP = ip
end


function M:listen( name, customhandler )
	if self.srv ~= nil then self.srv.destroy() end
	self.srv = udp.create( function( data, ip, port )	
		pprint( "Received: " .. data )
		if startsWith( data, name ) then 
			if customhandler then 
				customhandler( ip, port, data:sub( #name + 1 ) ) 
			end
		end
	end, self.port )
end


function M:update()
	if self.srv then self.srv:update() end
end


function M:destroy()
	if self.srv then self.srv.destroy() end
end


return M

