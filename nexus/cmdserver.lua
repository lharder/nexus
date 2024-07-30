local TcpServer = require( "defnet.tcp_server" )
-- local b64 = require( "nexus.b64" )


-- CmdServer ----------------------
local CmdServer = {}
CmdServer.__index = CmdServer

function CmdServer.create( port, fnConnect, fnDisconnect, optAlternativePort )
	local this = {}
	setmetatable( this, CmdServer )

	local onData = function( data, cip, cport, client )
		-- local cmd = sys.deserialize( b64.decode( data ) )
		local cmd = sys.deserialize( data ) 
		if cmd and cmd[ "type" ] then 
			local handler = this.handlers[ cmd.type ]
			if handler == nil then 
				pprint( ( "No handler for command with type = %d" ):format( cmd.type ) )
				return 
			end
			local err = handler( cmd.attrs, cip, cport )
			if err then pprint( err ) end
		end
	end

	local onConnect = function( cip, cport, client )
		if fnConnect then return fnConnect( cip, cport, client ) end 
	end

	local onDisconnect = function( cip, cport, client )
		if fnDisconnect then return fnDisconnect( cip, cport, client ) end 
	end

	this.port 		= port
	this.handlers 	= {}

	local options = { binary = true }
	this.tcpsrv 	= TcpServer.create( this.port, onData, onConnect, onDisconnect, options )
	local _, ok 	= pcall( this.tcpsrv.start )
	if not ok and ( optAlternativePort ~= nil ) then 
		this.port 	= optAlternativePort
		this.tcpsrv = TcpServer.create( this.port, onData, onConnect, onDisconnect, options )
		_, ok 		= pcall( this.tcpsrv.start )
		if not ok then 
			pprint( ( "Unable to establish server on port %d or %d!" ):format( port, this.port ) ) 
			return nil
		end
	end
	return this
end


function CmdServer:addCmdHandler( type, fn )
	if type == nil then return end 
	self.handlers[ type ] = fn
end


function CmdServer:update( dt )
	if self.tcpsrv then self.tcpsrv.update() end
end


return CmdServer




