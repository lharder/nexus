local Screenmaster = {}

local function unload( screen, screenname )
	if screenname then
		local url = msg.url( nil, screen, screenname )
		msg.post( url, "unload" ) 
	end
end


local function sendInitMessages( messages )
	if messages then 
		timer.delay( 0.1, false, function()
			for url, message in pairs( messages ) do
				msg.post( url, "screenmaster:loaded", message )
			end
		end )
	end
end


-- goScreens: the go with proxy components for each loadable screen.
-- Every single proxy is named after the screen it loads.
function Screenmaster.get( goScreens, goOverlays )
	if Screenmaster.inst == nil then
		local this = {}
		this.screen = goScreens
		this.screenname = nil
		this.overlay = goOverlays
		
		function this:load( screenname, messages )
			local url = nil

			-- unload the current level first
			if this.screenname then
				unload( this.screen, this.screenname )
			end

			-- allow for unloading to complete: important
			-- if a reload of the same level is intended!
			timer.delay( 0.1, false, function()
				-- load the new level as current
				local url = msg.url( nil, this.screen, screenname )
				msg.post( url, "load" )
				this.screenname = screenname

				-- allow for initialization messages to be  
				-- sent after loading a new screen
				sendInitMessages( messages )			
			end )
		end


		function this:loadOverlay( overlayname, messages )
			-- unload the current level first
			if self.screenname then
				-- freeze time in active level
				local url = msg.url( nil, self.screen, self.screenname )
				pprint( "Freeze " .. url )
				msg.post( url, "set_time_step", { factor = 0, mode = 0 })
			end

			-- load the overlay on top of the frozen level
			local url = msg.url( nil, self.overlay, overlayname )
			msg.post( url, "load" )

			-- allow for initialization messages to be  
			-- sent after loading a new screen
			sendInitMessages( messages )
		end


		function this:removeOverlay( overlayname )
			unload( self.overlay, overlayname )

			local url = msg.url( nil, self.screen, self.screenname )
			pprint( "Unfreeze " .. url )
			msg.post( url, "set_time_step", { factor = 1, mode = 0 })
		end
		

		function this:getScreenname()
			return this.screenname
		end
		
		Screenmaster.inst = this
	end

	return Screenmaster.inst
end


-- Overlays must be components of a gameobject 
-- independent of the screens gameobject underneath: 
-- only then can input be prevented from bubbling down 
-- the stack. ALl(!) components of a gameobject receive 
-- input at the same time. (Need refactoring here.....)
return Screenmaster.get( "/levels", "/overlay" )

