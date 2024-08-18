local HttpClient = require( "nexus.httpclient" )
local TcpClient = require( "defnet.tcp_client" )
local Contact = require( "nexus.contact" )


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
newReconnector = function( broker, ip, port )
	local rec 		= {}
	rec.broker 		= broker
	rec.ip 			= ip
	rec.port 		= port
	rec.ipPort 		= ( "%s:%s" ):format( ip, port )
	rec.nextconnect = socket.gettime()

	rec.send = function() 
		-- pprint( "No sending to disconnected " .. rec.ipPort )
	end

	rec.destroy = function()
		-- destroy myself
		rec.broker.nexus.contacts[ rec.ipPort ].tcpclient = nil
	end

	rec.update = function()
		if socket.gettime() > rec.nextconnect then 
			rec.nextconnect = socket.gettime() + 1
			-- pprint( "Try to reconnect to " .. rec.ipPort .. "....." )

			_, rec.tcpclient = newTcpClient( rec.broker, rec.ip, rec.port )
			local success = ( type( rec.tcpclient ) == "table" )
			if success then 
				-- replace myself with a "real" tcpclient again
				pprint( "Reconnect to " .. rec.ipPort .. " successful!" )
				rec.broker.nexus.contacts[ rec.ipPort ].tcpclient = rec.tcpclient
				pprint( "Replaced myself with my new TcpClient! Reconnector out ;o)" )

				-- callback and inform about successfully reestablishing connection
				local contact = rec.broker.nexus.contacts[ rec.ipPort ]
				rec.broker:onPlayerConnect( contact )
			end
		end
	end

	return rec
end



local function sendIntro( self, callback )
	local me = self.nexus:me() 
	if me == nil then 
		me = Contact.create( 
			self.nexus.cmdsrv.ip, 
			self.nexus.cmdsrv.port, 
			{}
		)
	end
	
	local player = { 
		gamename 	= self.nexus.gamename,
		gameversion = self.nexus.gameversion,
		callsign	= self.callsign,
		contact 	= me
	}

	player.contact:put( "callsign", self.callsign )
	self.http:put( "beacon/intro", player, callback ) 
end


-- Broker ------------------
local Broker = {}
Broker.__index = Broker


function Broker.create( nexus, host, login, pwd )
	local this = {}
	setmetatable( this, Broker )

	this.nexus 			= nexus
	this.isSearching 	= false
	this.http 			= HttpClient.create( host, login, pwd )
	
	this.options = { 
		binary = true,  
		connection_timeout = .3
	}

	return this
end


function Broker:search( callsign, onClientConnect, onClientDisconnect )
	self.callsign 			= callsign
	self.onClientConnect	= onClientConnect
	self.onClientDisconnect	= onClientDisconnect
	self.isSearching 		= true
	self.interval			= socket.gettime() + 2
	
	pprint( "I am " .. callsign )
	sendIntro( self, function( httpclient, id, resp )
		pprint( "Response status " .. resp.status .. ". " .. resp.response )
	end )
end


function Broker:update( dt )
	if self.isSearching then 
		if socket.gettime() > self.interval then 
			self.interval = socket.gettime() + 2
			
			sendIntro( self, function( httpclient, id, resp )
				if resp.status > 299 then 
					pprint( "Response status " .. resp.status .. ". " .. resp.response )
	
				else
					local contacts = json.decode(  resp.response )
					pprint( ( "Received %d contacts in our network" ):format( #contacts ) )
					
					for i, con in ipairs( contacts ) do 
						-- profile comes back as string, must be deserialized extra
						con.profile = json.decode( con.profile )
						
						local ipPort = ( "%s:%s" ):format( con.ip, con.port )
						pprint( con.profile.callsign .. ": " .. ipPort )
						if self.nexus.contacts[ ipPort ] == nil then 

							local _, tcpclient = newTcpClient( self, con.ip, con.port )
							local success = ( type( tcpclient ) == "table" )
							if success then 
								pprint( ( "Game client '%s' discovered at %s:%s." ):format( 
									con.profile.callsign, 
									con.ip, 
									con.port ) 
								) 

								-- remember all technical communication information for this contact
								local contact = Contact.create( con.ip, con.port, tcpclient )
								contact.profile = con.profile
								self.nexus.contacts[ ipPort ] = contact 

								-- inform custom script
								self:onPlayerConnect( contact )
								
							end
						end
					end
				end
			end )
		end
	end
end


-- Inform via callback that a player (i.e. tcp client with proper
-- announcement) has been found
function Broker:onPlayerConnect( contact )
	if self.onClientConnect then self.onClientConnect( contact ) end
end

-- Inform via callback that a player (i.e. tcp client with proper
-- announcement) has been disconnected and is no longer available
function Broker:onPlayerDisconnect( contact )
	if self.onClientDisconnect then self.onClientDisconnect( contact ) end
end


function Broker:stop()
	self.isSearching = false
end



return Broker

