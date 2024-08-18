local b64 = require( "nexus.base64" )


local function makeAuthHeader( login, pwd )
	return "Basic " .. b64.encode( ( "%s:%s" ):format( login, pwd ) )
end


-- HttpClient -------------------------------
local HttpClient = {}
HttpClient.__index = HttpClient


function HttpClient.create( host, login, pwd )
	local this = {}
	setmetatable( this, HttpClient )

	this.host = host
	this.login = login
	this.password = pwd

	this.headers = {}
	this.headers[ "Content-Type" ] = "application/json; charset=utf-8"
	if( login ~= nil ) and ( pwd ~= nil ) then 
		this.headers[ "Authorization" ] = makeAuthHeader( this.login, this.password )
	end

	return this
end


function HttpClient:send( method, url, callback, payload )
	assert( method, "You must define a http method!" )
	assert( url, "You must define an API url!" )
	
	url = self.host .. url
	local options = { timeout = 5 }
	local handler = function( self, id, resp ) 
		if callback then callback( self, id, resp ) end
	end

	http.request( url, method, handler, self.headers, json.encode( payload ), options )
end


function HttpClient:get( url, callback )
	self:send( "GET", url, callback )
end
	
function HttpClient:put( url, payload, callback )
	self:send( "PUT", url, callback, payload )
end

function HttpClient:post( url, payload, callback )
	self:send( "POST", url, callback, payload )
end

return HttpClient

