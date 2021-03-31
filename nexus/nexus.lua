local Nexus = {}


-- returns ip address of the localhost
function Nexus.getLocalhostIP()
	local ip = nil
	local ifaddrs = sys.get_ifaddrs()
	for _,interface in ipairs(ifaddrs) do
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

return Nexus

