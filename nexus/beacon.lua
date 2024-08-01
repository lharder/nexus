local PORTS = require( "nexus.ports" )
local tcpCnt = require( "defnet.tcp_client" )
local Contact = require( "nexus.contact" )
local Commands = require( "nexus.commands" )
local Localhost = require( "nexus.localhost" )

local ips

local nop = function() 
end 


-- Beacon ----------------------------------------------
local Beacon = {}
Beacon.__index = Beacon

function Beacon.create( nexus )
	local this = {}
	setmetatable( this, Beacon )

	this.nexus 				= nexus
	this.isSearching 		= false
	
	return this
end


function Beacon:search( callsign, onClientConnect, onClientDisconnect )
	self.callsign 			= callsign
	self.onClientConnect	= onClientConnect
	self.onClientDisconnect	= onClientDisconnect
	
	pprint( "I am " .. callsign )

	-- search out there
	ips = Localhost.getLocalPeerIPs()
	-- ips = { "192.168.178.23", "192.168.178.24" }
	self.ipIndex = 1
	self.portIndex = 1
	self.isSearching = true

	self.options = { 
		binary = true,  
		connection_timeout = .005 
	}

	-- no logging desired
	tcpCnt.log = function() end
end


function Beacon:addContactIP( ip )
	assert( ip, "You must provide an ip address to contact!" )
	if table.contains( ips, ip ) then return end
	table.insert( ips, ip ) 
end


function Beacon:update( dt )
	if self.isSearching then 
		-- address next possible game peer out there
		local ip = ips[ self.ipIndex ]
		local port = PORTS[ self.portIndex ]
		local ipPort = ( "%s:%s" ):format( ip, port )

		-- My profile info to be sent to other clients
		-- may change at any time, gets sent every few seconds
		local cmd = Commands.newAnnounceProfile( 
			self.callsign, 
			self.nexus.gamename,
			self.nexus.gameversion,
			self.nexus.cmdsrv.ip,
			self.nexus.cmdsrv.port 
		) 
		cmd:put( "team", "Alpha Niner" )

		-- announce my own presence to every peer:
		-- create a tcpclient only once, reuse it afterwards and keep sending
		if self.nexus.contacts[ ipPort ] == nil then 
			
			-- create a connection to this contact
			local success = false
			local ok, tcpclient = pcall( tcpCnt.create, ip, port, nop, 
			-- On disconnect of client (e.g. remote server is shutdown):
			-- My client(!) gets disconnected from the remote host. That
			-- is a sign that the remote server(!) is down. Use callback
			-- to inform that the remote player is no longer available.
				function() 
					local contact = self.nexus.contacts[ ipPort ]
					pprint( "No longer available: " .. contact.profile.callsign .. " (" .. ipPort .. ")" )

					-- inform interested scripts via callback
					self:onPlayerDisconnect( contact )

					-- cleanup, no longer available
					contact.tcpclient.destroy()
					self.nexus.contacts[ ipPort ] = nil
				end, 
				self.options 
			)
			
			success = ( type( tcpclient ) == "table" )
			if success then 
				pprint( ( "Tcp contact discovered at %s:%s. May be a game client." ):format( ip, port ) ) 

				-- remember all technical communication information for this contact
				local contact = Contact.create( ip, port, tcpclient )
				self.nexus.contacts[ ipPort ] = contact 
				
				-- Announce my own presence with game related profile information.
				-- Upon receiving this command the remote host adds the profile
				-- to its contact info: so far only my ip / port are known there.
				-- My server(!) ip and port are distinctive, not incoming client port.
				-- Beware: variables "ip" and "port" here are those of the remote host!
				self.nexus:send( cmd, contact )
				-- pprint( ( "Sending message: %s,  %s" ):format( cmd.type, cmd.attrs ) ) 
			end
		else
			-- keep announcing profile for belated game peers
			self.nexus:send( cmd, self.nexus.contacts[ ipPort ] )
		end

		self.ipIndex = self.ipIndex + 1
		if self.ipIndex > #ips then 
			self.ipIndex = 1
			if self.portIndex < #PORTS then 
				self.portIndex = self.portIndex + 1
			else
				self.portIndex = 1
			end

			-- one search cycle completed. If no other(!) clients found, increase timeout
			-- in steps. Network may be slow, so increase and start next search cycle.
			if table.length( self.nexus.contacts ) < 2 then 
				self.options.connection_timeout = 0.005 + self.options.connection_timeout
				if self.options.connection_timeout > .15 then self.options.connection_timeout = .15 end
				-- pprint( self.options.connection_timeout )
			end
		end
	end
end


-- Inform via callback that a player (i.e. tcp client with proper
-- announcement) has been found
function Beacon:onPlayerConnect( contact )
	if self.onClientConnect then self.onClientConnect( contact ) end
end

-- Inform via callback that a player (i.e. tcp client with proper
-- announcement) has been disconnected and is no longer available
function Beacon:onPlayerDisconnect( contact )
	if self.onClientDisconnect then self.onClientDisconnect( contact ) end
end


function Beacon:stop()
	self.isSearching = false

	-- do not use callbacks after stopping
	self.onClientConnect = nil
	self.onClientDisconnect = nil
end


return Beacon

