local Host = {}
Host.__index = Host

function Host.new( ip, port, callsign )
	local this = {}
	setmetatable( this, Host )

	this.ip = ip
	this.port = port
	this.callsign = callsign

	return this
end


function Host:tostring()
	local txt = "{ \"ip\": \"%s\", \"port\": %d, \"callsign\": \"%s\" }"
	return txt:format( self.ip, self.port, self.callsign )
end


return Host