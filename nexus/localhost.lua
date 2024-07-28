require( "nexus.utils" )

local M = {}

function M.getIP()
	local ip = nil
	local ifaddrs = sys.get_ifaddrs()
	for _,interface in ipairs( ifaddrs ) do
		if interface.name == "en0" then
			local adr = interface.address
			if adr ~= nil then
				local cntDots = adr:cntSubstr( "%." )
				if cntDots == 3 then 
					ip = adr
				end
			end
		end
	end
	-- there may be no network interface available!
	if ip == nil then ip = "127.0.0.1" end

	return ip
end


function M.getOctets( ipv4 )
	if ipv4 == nil then return end
	local octets = ipv4:split( "." )
	if #octets ~= 4 then return nil end

	return octets
end


function M.getLocalPeerIPs()
	local ip = M.getIP()
	
	local octets = M.getOctets( ip )
	if octets == nil then return end  
	
	local myOctet = tonumber( octets[ 4 ] )
	octets[ 4 ] = nil

	local ips = {}
	for i = 1, 254, 1 do 
		ips[ i ] = table.concat( octets, "." ) .. "." .. i
		-- pprint( ips[ i ] )
	end

	return ips
end

return M
