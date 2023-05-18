local udp = require( "defnet.udp" )


function length( t )
	if t == nil then return 0 end

	local count = 0
	for _ in pairs( t ) do count = count + 1 end
	return count
end

local function contains( tab, value )
	for key, item in pairs( tab ) do
		if item == value then
			return true
		end
	end 
	return false
end


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

local MATCH_PORT = 5898


function Matcher.new( mycontact )
	local this = {}
	setmetatable( this, Matcher )

	-- reference to the game
	this.contact = mycontact 

	-- confirmations received from hosts
	this.confirms = {}

	return this
end

-- proposal: list of callsigns
-- agreedHandler: function called when all have agreed
function Matcher:propose( proposedContacts, agreedHandler )
	local proposal = {}
	for i, contact in ipairs( proposedContacts ) do
		table.insert( proposal, contact.callsign )
	end
	
	-- create udp sender / receiver
	self.negotiator = udp.create( function( data, ip, port )
		if data == nil then return end

		local callsigns = sys.deserialize( data )
		if containSameItems( proposal, callsigns ) then

			-- remember that this ip has sent an answer
			self.confirms[ ip ] = true

			-- check how many have agreed
			local cntConfirms = length( self.confirms ) 
			if cntConfirms == #proposal then 
				-- stop sending out this proposal to all hosts
				timer.cancel( self.proposeTimer )
				self.negotiator:destroy()
				self.negotiator = nil

				local master = selectMasterContact( proposedContacts )

				-- callback application handler when all agreed:
				-- provide the contact commanding all NPCs as parameter
				if agreedHandler then agreedHandler( master ) end
			end
		end
	end, MATCH_PORT )

	-- always include player himself
	if not contains( proposal, self.contact.callsign ) then
		table.insert( proposal, self.contact.callsign )
		table.insert( proposedContacts, self.contact )
	end

	-- keep sending player's proposal until all others agree
	local serialized = sys.serialize( proposal )
	self.proposeTimer = timer.delay( .5, true, function()
		-- send proposal to all hosts
		for i, contact in ipairs( proposedContacts ) do
			self.negotiator.send( serialized, contact.ip, MATCH_PORT )
		end
	end )
end


function Matcher:update()
	if self.negotiator then self.negotiator.update() end
end


return Matcher

