local Contact = {}
Contact.__index = Contact

function Contact.new( ip, port, callsign )
	local this = {}
	setmetatable( this, Contact )

	this.ip = ip
	this.port = port
	this.callsign = callsign

	return this
end


function Contact:tostring()
	local txt = "{ \"ip\": \"%s\", \"port\": %d, \"callsign\": \"%s\" }"
	return txt:format( self.ip, self.port, self.callsign )
end


return Contact
