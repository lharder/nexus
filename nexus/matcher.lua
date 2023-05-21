require( "nexus.utils" )

local udp = require( "defnet.udp" )


local function containSameItems( tab1, tab2 )
	if( tab1 == nil ) and ( tab2 == nil ) then return true end
	if( tab1 == nil ) or ( tab2 == nil ) then return false end

	if table.getn( tab1 ) ~= table.getn( tab2 ) then 
		-- print( "Not the same amount of items in tables..." )
		return false 
	end

	local result = true
	for i, item in ipairs( tab1 ) do
		if not contains(  tab2, item ) then
			result = false
			-- break
		end
	end

	return result
end



local function lastOctet( ipv4 )
	if ipv4 == nil then return end
	local octets = ipv4:split( "." )
	if #octets ~= 4 then return nil end

	return tonumber( octets[ 4 ] )
end


local function selectMasterContact( contacts, fixedIp )
	local master 
	local max = 0
	for i, contact in ipairs( contacts ) do
		if contact.ip == fixedIp then 
			-- select the host with a given ip
			return host 
		else
			-- no fixed id is provided, use arbitrary algorithm:
			-- contact with highest last octet of ip becomes server
			local oct = lastOctet( contact.ip )
			if oct > max then 
				master = contact
				max = oct
			end
		end
	end
	return master
end


-- Matcher --------------------------------------
local Matcher = {}
Matcher.__index = Matcher

local MATCH_PORT = 16471


function Matcher.new( mycontact )
	local this = {}
	setmetatable( this, Matcher )

	-- reference to the game
	this.contact = mycontact 

	-- confirmations received from hosts
	this.confirms = {}
	this.proposal = {}

	-- create udp sender / receiver
	if this.srv == nil then 
		this.srv = udp.create( function( data, ip, port )
			if data == nil then return end  		-- something wrong
			if this.confirms[ ip ] then return end 	-- processed already

			local counterproposal = sys.deserialize( data )
			if containSameItems( this.proposal, counterproposal ) then

				-- remember that this ip has sent an answer
				this.confirms[ ip ] = true

				-- check how many have agreed
				local cntConfirms = length( this.confirms ) 
				if cntConfirms == #this.proposal then 
					-- stop sending out this proposal to all hosts
					timer.cancel( this.proposeTimer )
					this.srv:destroy()
					this.srv = nil

					local gamemaster = selectMasterContact( this.proposedContacts )

					-- callback application handler when all agreed:
					-- provide the contact commanding all NPCs as parameter
					if this.agreedHandler then this.agreedHandler( gamemaster ) end
				end
			end
		end, MATCH_PORT )
	end

	return this
end

-- proposal: list of callsigns
-- agreedHandler: function called when all have agreed
function Matcher:propose( proposedContacts, agreedHandler )
	self.proposal = {}
	self.proposedContacts = proposedContacts or {}
	self.agreedHandler = agreedHandler
	for i, contact in ipairs( self.proposedContacts ) do
		table.insert( self.proposal, contact.callsign )
	end
		
	-- always include player himself
	if not contains( self.proposal, self.contact.callsign ) then
		table.insert( self.proposal, self.contact.callsign )
		table.insert( self.proposedContacts, self.contact )
	end

	-- keep sending player's proposal until all others agree
	local serialized = sys.serialize( self.proposal )
	self.proposeTimer = timer.delay( .5, true, function()
		-- send proposal to all hosts
		for i, contact in ipairs( self.proposedContacts ) do
			self.srv.send( serialized, contact.ip, MATCH_PORT )
		end
	end )
end


function Matcher:update()
	if self.srv then self.srv.update() end
end


return Matcher

