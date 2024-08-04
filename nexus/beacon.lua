local PORTS = require( "nexus.ports" )
local TcpClient = require( "defnet.tcp_client" )
local Contact = require( "nexus.contact" )
local Commands = require( "nexus.commands" )
local Localhost = require( "nexus.localhost" )

local ips

local nop = function() 
end 

-- advance declaration, impl comes later....
local newReconnector
	
--------------------------------------
local function newTcpClient( self, ip, port )
	local ipPort = ( "%s:%s" ):format( ip, port )
	
	-- On disconnect of client (e.g. remote server is shutdown):
	-- My client(!) gets disconnected from the remote host. That
	-- is a sign that the remote server(!) is down. Use callback
	-- to inform that the remote player is no longer available.
	local onDisconnect = function()
		local contact = self.nexus.contacts[ ipPort ]
		pprint( "No longer available: " .. contact.profile.callsign .. " (" .. ipPort .. ")" )

		-- beacon is active: if peer disconnects, delete it
		-- and keep searching over all ips (including this one
		-- in case the peer restarts / reconnects.
		if self.isSearching then 
			-- inform interested scripts via callback
			self:onPlayerDisconnect( contact )

			-- cleanup, contact is no longer available.
			-- Thus get ready to connect again!
			contact.tcpclient.destroy()
			self.nexus.contacts[ ipPort ] = nil

		else
			-- Not searching and matching anymore, now we are playing!
			-- When disconnected, do not destroy client, but try to 
			-- reestablish the connection to proceed as soon as peer is 
			-- available again. Assume it is the same and has the same
			-- state, e.g. because it was interrupted by a tel call.
			-- When a coplayer is disconnected, all others should pause
			-- immediately to keep common state: up to the game via callback.
			contact.tcpclient = newReconnector( self, ip, port )

			-- inform via callback to allow e.g. for pausing the game
			self:onPlayerDisconnect( contact )
		end
	end

	return pcall( TcpClient.create, ip, port, nop, onDisconnect, self.options )
end


-- Reconnector --------------------------------------------
-- Temporary drop-in to replace a disconnected TcpClient:
-- tries to reconnect on update() until new connection 
-- can be established. Implements all methods of a regular
-- TcpClient and replaces itself automatically when successful.
newReconnector = function( beacon, ip, port )
	local rec 		= {}
	rec.beacon 		= beacon
	rec.ip 			= ip
	rec.port 		= port
	rec.ipPort 		= ( "%s:%s" ):format( ip, port )
	rec.nextconnect = socket.gettime()

	rec.send = function() 
		-- pprint( "No sending to disconnected " .. rec.ipPort )
	end
	
	rec.destroy = function()
		-- destroy myself
		rec.beacon.nexus.contacts[ rec.ipPort ].tcpclient = nil
	end

	rec.update = function()
		if socket.gettime() > rec.nextconnect then 
			rec.nextconnect = socket.gettime() + 1
			-- pprint( "Try to reconnect to " .. rec.ipPort .. "....." )

			_, rec.tcpclient = newTcpClient( rec.beacon, rec.ip, rec.port )
			local success = ( type( rec.tcpclient ) == "table" )
			if success then 
				-- replace myself with a "real" tcpclient again
				pprint( "Reconnect to " .. rec.ipPort .. " successful!" )
				rec.beacon.nexus.contacts[ rec.ipPort ].tcpclient = rec.tcpclient
				pprint( "Replaced myself with my new TcpClient! Reconnector out ;o)" )

				-- callback and inform about successfully reestablishing connection
				local contact = rec.beacon.nexus.contacts[ rec.ipPort ]
				rec.beacon:onPlayerConnect( contact )
			end
		end
	end

	return rec
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
	TcpClient.log = function() end
end


function Beacon:addContactIP( ip )
	assert( ip, "You must provide an ip address to contact!" )
	
	if table.contains( ips, ip ) then return end
	table.insert( ips, ip ) 

	-- make sure that next connect attempt is the given ip
	self.ipIndex = #ips
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
			local ok, tcpclient = newTcpClient( self, ip, port )
			local success = ( type( tcpclient ) == "table" )
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

			-- one search cycle completed. If no other clients found, increase timeout
			-- in steps. Network may be slow, so increase and start next search cycle.
			if table.length( self.nexus.contacts ) < 2 then 
				self.options.connection_timeout = .001 + self.options.connection_timeout
				if self.options.connection_timeout > .15 then 
					self.options.connection_timeout = .15 
				end
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
	-- self.onClientConnect = nil
	-- self.onClientDisconnect = nil
end


return Beacon

