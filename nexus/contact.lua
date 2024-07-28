
-- Contact ----------------------
local Contact = {}
Contact.__index = Contact

function Contact.create( ip, port, tcpclient )
	local this = {}
	setmetatable( this, Contact )

	assert( ip, "Contact must have an ip address!" )
	assert( port, "Contact must have a port number!" )
	assert( tcpclient, "Contact must have a tcp client!" )
	
	this.ip 		= ip
	this.port 		= port
	this.tcpclient 	= tcpclient
	this.profile 	= {}
	this.created	= socket.gettime()

	return this
end

function Contact:id() return ( "%s:%s" ):format( self.ip, self.port ) end

function Contact:put( key, value ) self.profile[ key ] = value end
function Contact:get( key ) return self.profile[ key ] end

function Contact:tostring() 
	local t 	= {}
	t.ip 		= self.ip
	t.port 		= self.port
	t.profile 	= self.profile
	return json.encode( t )
end


return Contact
