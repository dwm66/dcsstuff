
function table_out (tt, indent, done)
  local result = "\n"
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
        local counter = 1
    for key, value in pairs (tt) do
      result = result .. string.rep (" ", indent) -- indent it
      if type (value) == "table" and not done [value] then
        done [value] = true
        result = result .. string.format("[%s] =\n", tostring (key));
        result = result .. string.rep (" ", indent) -- indent it
        result = result .. "{";
        result = result .. table_out (value, indent + 4, done)
        result = result .. string.rep (" ", indent) -- indent it
                if counter == #tt then 
                        result = result .. "}" .. "   -- end of " .. tostring (key) .. "\n";
                else 
                result = result .. "}," .. "  -- end of " .. tostring (key) .. "\n";
                end
      else
                if type(value) == 'string' then
                result = result .. string.format("[\"%s\"] = \"%s\",\n",tostring (key), tostring(value))
                else
                result = result .. string.format("[\"%s\"] = %s,\n",tostring (key), tostring(value))
                end
      end
          counter = counter + 1
    end
  else
    if (tt) then result = result .. tostring(tt) .. "\n" end
  end
  return result
end

function getNavpoint(name,co,altitude)
	local coal = 'blue'
	
	if co == coalition.side.BLUE then coal = 'blue' end
	if co == coalition.side.RED then coal = 'red' end
	if co == coalition.side.NEUTRALS then coal = 'neutrals' end
	
	local theNavpoints = DATABASE:New().Navpoints[coal]
	local x = nil
	local y = nil
	
	for index,navpt in pairs(theNavpoints) do
		if name == navpt.callsignStr then
			x = navpt.x
			y = navpt.y
			break
		end
	end
	
	local result = nil
	if x ~= nil then
		result = COORDINATE:New(x,altitude,y)
	end
	
	return result
end


TankerHandler = {
					-- coalition = coalition.side.BLUE,
					tankerList = {},
					tankerSpecs = {},
					specsUsage = {}
				}

TankerTypes = { Boom = "Boom", Drogue = "Drogue" }

function TankerHandler:New( theCoalition )
	local self = BASE:Inherit(self, BASE:New())
	
	self.coalition = theCoalition or coalition.side.BLUE
	
	return self
end

function TankerHandler:addTanker(name, tankerType, tankerTemplate, useUncontrolled, takeoffAirbase, landingAirbase )
	useUncontrolled = useUncontrolled or false
			
	if useUncontrolled then
		local theGroup = GROUP:FindByName(tankerTemplate)
		-- it is uncontrolled and already there, so just determine where it is ...
			takeoffAirbase = theGroup:GetCoord():GetClosestAirbase(nil,self.coalition).AirbaseName
			env.info("takeoff airbase is: " .. takeoffAirbase )			
	else
		if not takeoffAirbase then				
			local theTemplate = GROUP:FindByName(tankerTemplate)
			env.info( "template is at " .. theTemplate:GetCoord():ToStringLLDMS())
			takeoffAirbase = theTemplate:GetCoord():GetClosestAirbase(nil,self.coalition).AirbaseName
			env.info("takeoff airbase is: " .. takeoffAirbase )
		end
	end			
	
	if not landingAirbase then
		landingAirbase = takeoffAirbase
		env.info("landing airbase is: " .. landingAirbase )
	end


	
	-- TODO: Check for duplicates and plausibility
	if not self.tankerList[name] then
		self.tankerList[name] = { 	name = name, 
									tankerType = tankerType, 
									tankerTemplate = tankerTemplate, 
									useUncontrolled = useUncontrolled, 
									takeoffAirbase  = takeoffAirbase, 
									landingAirbase  = landingAirbase,
									assigned = nil }
	end
end

function TankerHandler:addSpec(name, tankerSpec )
	if not self.tankerSpecs[name] then
		self.tankerSpecs[name] = tankerSpec
	end
end

function TankerHandler:SearchTanker( tankerName )
	local theTanker = nil
	local theSpec = nil

	for k,t in pairs(self.tankerList) do
		if t.name == tankerName then 
			theTanker = t
			break
		end
	end

	return theTanker
end

function TankerHandler:SearchSpec ( tankerSpec )
	local theSpec = nil

	for n,t in pairs( self.tankerSpecs ) do
		if t.name == tankerSpec then 
			theSpec = t
			break
		end
	end

	return theSpec
end

--[[
local theTankerMenu = MENU_COALITION_COMMAND:New(Spec.coalition,"Request " .. Spec.name,
	MenuParent,
	function(aSpec,spawnTanker)
		if aSpec.spawnGroup == nil then
			env.info("Tanker " .. aSpec.name .. " does not exist yet.")
		else
			env.info("Tanker " .. aSpec.name .. " activating")
			-- TODO: Should the alerting be simulated (crew driving to plane)?
			-- Spec.spawnGroup:StartUncontrolled(5)
			spawnTanker:InitUnControlled(false)
			tanker = spawnTanker:ReSpawn(1)
			aSpec['spawnGroup']=tanker
			setTankerSpec(tanker, aSpec)
		end
	end, Spec, spawnTanker
)
--]]

function TankerHandler:menuActivateCallback(theType, spec)
	local tankerFound = self:findAvailableTanker( theType, spec )
	
	if tankerFound then
		self:startTanker( tankerFound.name, spec.name )
	else
		local msg = MESSAGE:New('Request denied: No ' .. theType .. 'tanker available!',25):ToCoalition(self.coalition)
	end
end

function TankerHandler:menuInit( parentMenu )
	local status = self:getTankerStates()
	local BoomAvailable = status.Boom.number - status.Boom.active
	local DrogueAvailable = status.Drogue.number - status.Drogue.active
	
	self.menus = { 	parentMenu = parentMenu,
					specMenus  = {}
				 }
	
	local theTankerMenu = MENU_COALITION_COMMAND:New( self.coalition ,"Tanker status report",
			parentMenu,
			function()
				local status=self:getTankerStates();
				
				local msg = MESSAGE:New(status.reportText,25):ToCoalition(self.coalition)
			end
		)		

	for k,s in pairs (self.tankerSpecs) do
		if status.specStatus[s.name].assignedTotal == 0 then
			self.menus.specMenus[k] = MENU_COALITION:New( self.coalition, "Zone " .. s.name, parentMenu )
			if BoomAvailable > 0 then
				self.menus.specMenus[k].Boom = MENU_COALITION_COMMAND:New( self.coalition, 'Request Boom Tanker for zone '..s.name,
					self.menus.specMenus[k],
					self.menuActivateCallback,
					self,TankerTypes.Boom, s )
			end
			if DrogueAvailable > 0 then
				self.menus.specMenus[k].Drogue = MENU_COALITION_COMMAND:New( self.coalition, 'Request Drogue Tanker for zone '..s.name,
					self.menus.specMenus[k],
					self.menuActivateCallback,
					self,TankerTypes.Drogue ,s )
			end
		end
	end	
end

function TankerHandler:findAvailableTanker( theType, theSpec, airstart )
	env.info ('findAvailableTanker: Searching for type ' .. theType)
	for k,t in pairs ( self.tankerList ) do
		if t.tankerType == theType and not t.assigned then
			if airstart then
				if not t.useUncontrolled then 
					return t
				end
			else
				return t
			end
		end
	end
	return nil
end

function TankerHandler:getTankerStates()
	local status =  { Boom = 	{ number = 0, active = 0},
					  Drogue = 	{ number = 0, active = 0},
					  specStatus = { }
					}
					
	local report = 'Available tankers: \n'

	for k,s in pairs (self.tankerSpecs) do
		status.specStatus[k]={ 
			-- assigned = { Boom = 0, Drogue = 0}, 
			assignedTotal = 0
		}
	end
	
	for k,t in pairs ( self.tankerList ) do
		report = report .. 'Tanker '..t.name..' (type: ' .. t.tankerType .. ') '
		status[t.tankerType].number = status[t.tankerType].number+1
		if (t.assigned) then
			report = report .. 'is assigned to ' .. t.assigned .. "\n"
			status[t.tankerType].active = status[t.tankerType].active+1
			status.specStatus[t.assigned].assignedTotal = status.specStatus[t.assigned].assignedTotal+1
		else
			report = report .. ' is waiting for assignment.\n'
		end
	end
	
	status.reportText = report

	return status
end

function TankerHandler:setTankerSpec( theTanker )
	if not theTanker.assigned then
		env.warning('called TankerHandler:setTankerSpec without spec assigned to tanker, abort!')
		return nil
	end
		
	if not theTanker.tankerGroup then
		env.warning('called setTankerSpec without spawned Group')
		return nil
	end

	local theSpec = self.tankerSpecs [ theTanker.assigned ]

	local theStartAirbase = AIRBASE:FindByName(theTanker.takeoffAirbase)
	local activeStartRW =	theStartAirbase:GetActiveRunway().idx
	local airbaseStartCoord = theStartAirbase:GetCoord()

	local theLandingAirbase = 	AIRBASE:FindByName(theTanker.landingAirbase)
	local activeLandingRW =		theLandingAirbase:GetActiveRunway().idx
	local airbaseLandingCoord = theLandingAirbase:GetCoord()			
	env.info( "Landing coordinates: " .. airbaseLandingCoord:ToStringLLDMS())

	-- tasking: Tanker
	local tasks = {}
	-- get orbit task structure
	local orbittask = theTanker.tankerGroup:TaskOrbit(theSpec.route.racetrack.coord1,theSpec.route.racetrack.altitude,theSpec.route.racetrack.velocity,theSpec.route.racetrack.coord2)
	-- get tanker task structure
	local tankertask = theTanker.tankerGroup:EnRouteTaskTanker()
			
	units = theTanker.tankerGroup:GetUnit(1)
	
	-- env.info("Units: "..table_out(units))
	
	beacon = units:GetBeacon()
	beacon:AATACAN(theSpec.tacan, theSpec.tacan_call, true)
	
	-- env.info("Beacon: " .. table_out(beacon))
	
	theTanker.tankerGroup:OptionRTBBingoFuel(true)
	
	-- add waypoints
	local theWaypoints = {}
	
	-- theTanker.tankerGroup:WayPointInitialize(theWaypoints)
	
	table.insert(theWaypoints,airbaseStartCoord:WaypointAirTakeOffParking())
	table.insert(theWaypoints,theSpec.route.base_egress[1].coord:WaypointAirTurningPoint("BARO",theSpec.route.velocity,{tankertask},'Airbase Exit'))
	-- TODO: Define way there

	for k,cords in pairs(theSpec.route.waythere) do
		table.insert(theWaypoints,cords:WaypointAirTurningPoint("BARO",theSpec.route.velocity))
	end
	
	-- Racetrack
	table.insert(theWaypoints,theSpec.route.racetrack.coord1:WaypointAirTurningPoint("BARO",theSpec.route.racetrack.velocity,{orbittask},"Holding Point"))
	
	-- TODO: Define way back
	for k,cords in pairs(theSpec.route.wayback) do
		table.insert(theWaypoints,cords:WaypointAirTurningPoint("BARO",theSpec.route.velocity))
	end

	table.insert(theWaypoints,theSpec.route.base_ingress[1].coord:WaypointAirTurningPoint("BARO",theSpec.route.velocity,{},'Airbase Ingress'))		
	table.insert(theWaypoints,airbaseLandingCoord:WaypointAirLanding())
	
	-- env.info (table_out(theWaypoints[8]))		
	theTanker.tankerGroup:Route(theWaypoints,2)
end

function TankerHandler:setCallbacks( theTankerGroup )
	self:E ('setting callbacks for Tankers')

	theTankerGroup:HandleEvent(EVENTS.EngineStartup)
	theTankerGroup['OnEventEngineStartup'] = function(self, EventData)
		self:MessageToCoalition('Tanker ' .. self:GetCallsign() .. ' starting up engines!',20,self:GetCoalition())
	end

	theTankerGroup:HandleEvent(EVENTS.Takeoff)
	theTankerGroup['OnEventTakeoff'] = function(self, EventData)
		self:MessageToCoalition('Tanker ' .. self:GetCallsign() .. ' taking off!',20,self:GetCoalition())
	end
end

function TankerHandler:startUncontrolled( theTanker )
	env.info("Starting uncontrolled Tanker: " .. theTanker.name )
	
	local tanker = GROUP:FindByName(theTanker.tankerTemplate)
	
	local theSpec = self.tankerSpecs [ theTanker.assigned ]
	
	theTanker['tankerGroup'] = tanker

	tanker:CommandSetCallsign(theSpec.callsign[1],theSpec.callsign[2])
	tanker:CommandSetFrequency(theSpec.frequency)

	self:setTankerSpec( theTanker )
	self:setCallbacks(tanker)
	
	tanker:StartUncontrolled(1)
	
	local msgText = 'Requested tanker ' .. tanker:GetTypeName() .. ' starting for zone '.. theSpec.name .. ', crew alerted.\n\n'
	msgText = msgText .. 'Contact ' .. theTanker.tankerGroup:GetUnit(1):GetCallsign() .. ' on ' .. theSpec.frequency .. ' MHz\n\n'
	msgText = msgText .. 'TACAN ' .. theSpec.tacan_call .. ' on ' ..theSpec.tacan ..'Y'
	
	local msg = MESSAGE:New(msgText,25):ToCoalition(self.coalition)		
end

function TankerHandler:spawnNew( theTanker )
	if not theTanker.assigned then
		env.warning('called TankerHandler:spawnNew without spec assigned to tanker, abort!')
		return nil
	end

	env.info ("Spawning new Tanker: " .. theTanker.name .. ' from ' .. theTanker.tankerTemplate )

	local theSpec = self.tankerSpecs [ theTanker.assigned ]

	local spawnTanker = SPAWN:New(theTanker.tankerTemplate)
	local theAirbase = AIRBASE:FindByName(theTanker.takeoffAirbase)
	
	local tanker = spawnTanker:SpawnAtAirbase(theAirbase,SPAWN.Takeoff.Cold)
	theTanker['tankerGroup'] = tanker
	
	tanker:CommandSetCallsign(theSpec.callsign[1],theSpec.callsign[2])
	tanker:CommandSetFrequency(theSpec.frequency)

	self:setTankerSpec( theTanker )
	self:setCallbacks( tanker )

	local msgText = 'Requested tanker ' .. tanker:GetTypeName() .. ' starting for zone '.. theSpec.name .. ', crew alerted.\n\n'
	msgText = msgText .. 'Contact ' .. theTanker.tankerGroup:GetUnit(1):GetCallsign() .. ' on ' .. theSpec.frequency .. ' MHz\n\n'
	msgText = msgText .. 'TACAN ' .. theSpec.tacan_call .. ' on ' ..theSpec.tacan ..'Y'
	
	local msg = MESSAGE:New(msgText,25):ToCoalition(self.coalition)

end

function TankerHandler:startTanker( tankerName, tankerSpec )
	theTanker = self:SearchTanker(tankerName)
	theSpec   = self:SearchSpec(tankerSpec)
	
	env.info('startTanker: Tanker ' .. tankerName .. ' requested for ' .. tankerSpec)

	if theTanker and theSpec and not theTanker.assigned then
		env.info('startTanker assigning: Tanker ' .. theTanker.name .. ' requested for ' .. theSpec.name )
		theTanker.assigned = theSpec.name
		
		if theTanker.useUncontrolled then
			self:startUncontrolled( theTanker )
		else
			self:spawnNew( theTanker )
		end

		return theTanker.name .. " - " .. theSpec.name
	end
	return nil
end

function TankerHandler:assignEscort( tankerName, fighterHandler, templateSpec )
	theTanker = self:SearchTanker(tankerName)
	
	fighterHandler:assignAsEscort( theTanker.tankerGroup, templateSpec )
end

-- ------------------------------- AWACS handler

AWACSHANDLER = {
					-- coalition = coalition.side.BLUE,
					AWACSList = {},
					AWACSSpecs = {},
					specsUsage = {}
				}

function AWACSHANDLER:New( theCoalition )
	local self = BASE:Inherit(self, BASE:New())
	
	self.coalition = theCoalition or coalition.side.BLUE
	
	return self
end

function AWACSHANDLER:addAWACS(name, AWACSTemplate, useUncontrolled, takeoffAirbase, landingAirbase )
	useUncontrolled = useUncontrolled or false
			
	if useUncontrolled then
		local theGroup = GROUP:FindByName(AWACSTemplate)
		-- it is uncontrolled and already there, so just determine where it is ...
			takeoffAirbase = theGroup:GetCoord():GetClosestAirbase(nil,self.coalition).AirbaseName
			env.info("takeoff airbase is: " .. takeoffAirbase )			
	else
		if not takeoffAirbase then				
			local theTemplate = GROUP:FindByName(AWACSTemplate)
			-- TODO: Treat error if template does not exist
			env.info( "template is at " .. theTemplate:GetCoord():ToStringLLDMS())
			takeoffAirbase = theTemplate:GetCoord():GetClosestAirbase(nil,self.coalition).AirbaseName
			env.info("takeoff airbase is: " .. takeoffAirbase )
		end
	end			
	
	if not landingAirbase then
		landingAirbase = takeoffAirbase
		env.info("landing airbase is: " .. landingAirbase )
	end


	
	-- TODO: Check for duplicates and plausibility
	if not self.AWACSList[name] then
		self.AWACSList[name] = { 	name = name, 
									AWACSTemplate = AWACSTemplate, 
									useUncontrolled = useUncontrolled, 
									takeoffAirbase  = takeoffAirbase, 
									landingAirbase  = landingAirbase,
									assigned = nil }
	end
end

function AWACSHANDLER:addSpec(name, AWACSSpec )
	if not self.AWACSSpecs[name] then
		self.AWACSSpecs[name] = AWACSSpec
	end
end

function AWACSHANDLER:SearchAWACS( AWACSName )
	local theAWACS = nil
	local theSpec = nil

	for k,t in pairs(self.AWACSList) do
		if t.name == AWACSName then 
			theAWACS = t
			break
		end
	end

	return theAWACS
end

function AWACSHANDLER:SearchSpec ( AWACSSpec )
	local theSpec = nil

	for n,t in pairs( self.AWACSSpecs ) do
		if t.name == AWACSSpec then 
			theSpec = t
			break
		end
	end

	return theSpec
end

function AWACSHANDLER:menuActivateCallback( spec )
	local AWACSFound = self:findAvailableAWACS()
	
	if AWACSFound then
		self:startAWACS( AWACSFound.name, spec.name )
	else
		local msg = MESSAGE:New('Request denied: No AWACS plane available!',25):ToCoalition(self.coalition)
	end
end

function AWACSHANDLER:menuInit( parentMenu )
	local status = self:getAWACSStates()
	local Available = status.number - status.active
	
	self.menus = { 	parentMenu = parentMenu,
					specMenus  = {}
				 }
	
	local theAWACSMenu = MENU_COALITION_COMMAND:New( self.coalition ,"AWACS status report",
			parentMenu,
			function()
				local status=self:getAWACSStates();
				
				local msg = MESSAGE:New(status.reportText,25):ToCoalition(self.coalition)
			end
		)		

	for k,s in pairs (self.AWACSSpecs) do
		if status.specStatus[s.name].assignedTotal == 0 then
			self.menus.specMenus[k] = MENU_COALITION:New( self.coalition, "Patrolzone " .. s.name, parentMenu )
			if Available > 0 then
				self.menus.specMenus[k].Boom = MENU_COALITION_COMMAND:New( self.coalition, 'Request AWACS for patrolzone '..s.name,
					self.menus.specMenus[k],
					self.menuActivateCallback, self, s )
			end
		end
	end	
end

function AWACSHANDLER:findAvailableAWACS( airstart )
	for k,t in pairs ( self.AWACSList ) do
		if not t.assigned then
			if airstart then
				if not t.useUncontrolled then 
					return t
				end
			else
				return t
			end
		end
	end
	return nil
end

function AWACSHANDLER:getAWACSStates()
	local status =  { number = 0, active = 0,
					  specStatus = { }
					}
					
	local report = 'Available AWACS: \n'

	for k,s in pairs (self.AWACSSpecs) do
		status.specStatus[k]={ 
			-- assigned = { Boom = 0, Drogue = 0}, 
			assignedTotal = 0
		}
	end
	
	for k,t in pairs ( self.AWACSList ) do
		report = report .. 'AWACS '..t.name
		status.number = status.number+1
		if (t.assigned) then
			report = report .. 'is assigned to ' .. t.assigned .. "\n"
			status.active = status.active+1
			status.specStatus[t.assigned].assignedTotal = status.specStatus[t.assigned].assignedTotal+1
		else
			report = report .. ' is waiting for assignment.\n'
		end
	end
	
	status.reportText = report

	return status
end

function AWACSHANDLER:setAWACSSpec( theAWACS, airstart )
	if not theAWACS.assigned then
		env.warning('called AWACSHANDLER:setAWACSSpec without spec assigned to tanker, abort!')
		return nil
	end
		
	if not theAWACS.AWACSGroup then
		env.warning('called setAWACSSpec without spawned Group')
		return nil
	end

	local theSpec = self.AWACSSpecs [ theAWACS.assigned ]

	local theStartAirbase = AIRBASE:FindByName(theAWACS.takeoffAirbase)
	local activeStartRW =	theStartAirbase:GetActiveRunway().idx
	local airbaseStartCoord = theStartAirbase:GetCoord()

	local theLandingAirbase = 	AIRBASE:FindByName(theAWACS.landingAirbase)
	local activeLandingRW =		theLandingAirbase:GetActiveRunway().idx
	local airbaseLandingCoord = theLandingAirbase:GetCoord()			
	self:E( "AWACS " .. theAWACS.name .. " landing coordinates: " .. airbaseLandingCoord:ToStringLLDMS())

	-- tasking: Tanker
	local tasks = {}
	-- get orbit task structure
	local orbittask = theAWACS.AWACSGroup:TaskOrbit(theSpec.route.racetrack.coord1,theSpec.route.racetrack.altitude,theSpec.route.racetrack.velocity,theSpec.route.racetrack.coord2)
	-- get AWACS task structure
	local AWACStask = theAWACS.AWACSGroup:EnRouteTaskAWACS()
					
	theAWACS.AWACSGroup:OptionRTBBingoFuel(true)
	
	-- add waypoints
	local theWaypoints = {}
	
	-- theTanker.tankerGroup:WayPointInitialize(theWaypoints)
	
	if not airstart then
		table.insert(theWaypoints,airbaseStartCoord:WaypointAirTakeOffParking())
		table.insert(theWaypoints,theSpec.route.base_egress[1].coord:WaypointAirTurningPoint("BARO",theSpec.route.velocity,{AWACStask},'Airbase Exit'))
		-- TODO: Define way there

		for k,cords in pairs(theSpec.route.waythere) do
			table.insert(theWaypoints,cords:WaypointAirTurningPoint("BARO",theSpec.route.velocity))
		end
	end -- airstart
	-- Racetrack
	table.insert(theWaypoints,theSpec.route.racetrack.coord1:WaypointAirTurningPoint("BARO",theSpec.route.racetrack.velocity,{AWACStask,orbittask},"Holding Point"))
	
	-- TODO: Define way back
	for k,cords in pairs(theSpec.route.wayback) do
		table.insert(theWaypoints,cords:WaypointAirTurningPoint("BARO",theSpec.route.velocity))
	end

	table.insert(theWaypoints,theSpec.route.base_ingress[1].coord:WaypointAirTurningPoint("BARO",theSpec.route.velocity,{},'Airbase Ingress'))		
	table.insert(theWaypoints,airbaseLandingCoord:WaypointAirLanding())
	
	-- env.info (table_out(theWaypoints[8]))		
	theAWACS.AWACSGroup:Route(theWaypoints,1)
end

function AWACSHANDLER:startUncontrolled( theAWACS )
	env.info("Starting uncontrolled AWACS: " .. theAWACS.name )
	
	local AWACS = GROUP:FindByName(theAWACS.AWACSTemplate)
	
	local theSpec = self.AWACSSpecs [ theAWACS.assigned ]
	
	theAWACS['AWACSGroup'] = AWACS

	AWACS:CommandSetCallsign(theSpec.callsign[1],theSpec.callsign[2] )
	AWACS:CommandSetFrequency(theSpec.frequency)
	AWACS:CommandEPLRS(true) -- datalink on

	self:setAWACSSpec( theAWACS, false )
	self:setCallbacks( AWACS )
	
	AWACS:StartUncontrolled(1)
	
	local msgText = 'Requested AWACS ' .. AWACS:GetTypeName() .. ' starting for zone '.. theSpec.name .. ', crew alerted.\n\n'
	msgText = msgText .. 'Contact ' .. theAWACS.AWACSGroup:GetUnit(1):GetCallsign() .. ' on ' .. theSpec.frequency .. ' MHz\n\n'
	
	local msg = MESSAGE:New(msgText,25):ToCoalition(self.coalition)
	return AWACS
end

function AWACSHANDLER:spawnNew( theAWACS, airstart )
	if not theAWACS.assigned then
		env.warning('called AWACSHANDLER:spawnNew without spec assigned to AWACS, abort!')
		return nil
	end

	env.info ("Spawning new AWACS: " .. theAWACS.name .. ' from ' .. theAWACS.AWACSTemplate )

	local theSpec = self.AWACSSpecs [ theAWACS.assigned ]

	local spawnAWACS = SPAWN:New(theAWACS.AWACSTemplate)
	if airstart then
		self:E( theAWACS.name .. ' - airstart initiated')
		local spawnCoord = theSpec.route.racetrack.coord1
		local nextCoord  = theSpec.route.racetrack.coord2
		
		local BasicHeading = spawnCoord:GetAngleDegrees(spawnCoord:GetDirectionVec3(nextCoord))
		spawnAWACS:InitHeading(BasicHeading)
		
		theAWACS['AWACSGroup'] = spawnAWACS:SpawnFromCoordinate(spawnCoord)
	else
		local theAirbase = AIRBASE:FindByName(theAWACS.takeoffAirbase)		
		self:E( theAWACS.name .. ' - cold start initiated at ' .. theAWACS.takeoffAirbase )
		theAWACS['AWACSGroup'] = spawnAWACS:SpawnAtAirbase(theAirbase,SPAWN.Takeoff.Cold)
	end
	
	if theAWACS.AWACSGroup == nil then
		self:E('AWACSHandler: could not start ' .. theAWACS.name)
		theAWACS.assigned = nil
		return nil
	end
	
	theAWACS.AWACSGroup:CommandSetCallsign(theSpec.callsign[1],theSpec.callsign[2])
	theAWACS.AWACSGroup:CommandSetFrequency(theSpec.frequency)
	theAWACS.AWACSGroup:CommandEPLRS(true) -- datalink on

	self:setAWACSSpec( theAWACS, airstart )
	self:setCallbacks( theAWACS.AWACSGroup )

	local msgText = 'Requested AWACS ' .. theAWACS.AWACSGroup:GetTypeName() .. ' starting for zone '.. theSpec.name .. ', crew alerted.\n\n'
	if airstart then
		msgText = 'Requested AWACS ' .. theAWACS.AWACSGroup:GetTypeName() .. ' arrived in zone '.. theSpec.name .. '\n\n'
	end
	msgText = msgText .. 'Contact ' .. theAWACS.AWACSGroup:GetUnit(1):GetCallsign() .. ' on ' .. theSpec.frequency .. ' MHz\n\n'
	
	local msg = MESSAGE:New(msgText,25):ToCoalition(self.coalition)
	return theAWACS.AWACSGroup
end

function AWACSHANDLER:setCallbacks( theAWACSGroup )
	self:E ('setting callbacks for AWACS')

	theAWACSGroup:HandleEvent(EVENTS.EngineStartup)
	theAWACSGroup['OnEventEngineStartup'] = function(self, EventData)
		self:MessageToCoalition('AWACS ' .. self:GetCallsign() .. ' starting up engines!',20,self:GetCoalition())
	end

	theAWACSGroup:HandleEvent(EVENTS.Takeoff)
	theAWACSGroup['OnEventTakeoff'] = function(self, EventData)
		self:MessageToCoalition('AWACS ' .. self:GetCallsign() .. ' taking off!',20,self:GetCoalition())
	end
end

function AWACSHANDLER:startAWACS( AWACSName, AWACSSpec, airstart )
	theAWACS = self:SearchAWACS(AWACSName)
	theSpec   = self:SearchSpec(AWACSSpec)
	
	env.info('startTanker: AWACS ' .. AWACSName .. ' requested for ' .. AWACSSpec)

	if theAWACS and theSpec and not theAWACS.assigned then
		env.info('startAWACS assigning: AWACS ' .. theAWACS.name .. ' requested for ' .. theSpec.name )

		theAWACS.assigned = theSpec.name		
		if theAWACS.useUncontrolled then
			if airstart then
				theAWACS.assigned = nil
				return nil
			end
			self:startUncontrolled( theAWACS )
		else
			self:spawnNew( theAWACS, airstart )
		end
		
		if theAWACS.NeedEscort then
			theAWACS.NeedEscort.fighterHandler:assignAsEscort( theAWACS.AWACSGroup, theAWACS.NeedEscort.templateSpec )
		end

		return theAWACS.AWACSGroup
	end
	return nil
end

function AWACSHANDLER:assignEscort( AWACSName, fighterHandler, templateSpec )
	theAWACS = self:SearchAWACS(AWACSName)
	theAWACS['NeedEscort']={ fighterHandler = fighterHandler, templateSpec = templateSpec}
	
	if theAWACS.AWACSGroup then
		theAWACS['Escort'] = fighterHandler:assignAsEscort( theAWACS.AWACSGroup, templateSpec )
	end
end

-- FighterHandler -------------------------------------------

FIGHTERHANDLER = {
					-- coalition = coalition.side.BLUE,
					FighterList = {},
					FighterSpecs = {},
					specsUsage = {},
				}

FIGHTERTASKING = {
					CAP = 1,
					Escort = 2,
				}

function FIGHTERHANDLER:New( theCoalition )
	local self = BASE:Inherit(self, BASE:New())
	
	self.coalition = theCoalition or coalition.side.BLUE
	
	return self
end

function FIGHTERHANDLER:addFighter(name, FighterTemplate, useUncontrolled, takeoffAirbase, landingAirbase )
	useUncontrolled = useUncontrolled or false
	
	if useUncontrolled then
		local theGroup = GROUP:FindByName(FighterTemplate)
		-- it is uncontrolled and already there, so just determine where it is ...
			takeoffAirbase = theGroup:GetCoord():GetClosestAirbase(nil,self.coalition).AirbaseName
			env.info("takeoff airbase is: " .. takeoffAirbase )			
	else
		if not takeoffAirbase then				
			local theTemplate = GROUP:FindByName(FighterTemplate)
			-- TODO: Treat error if template does not exist
			env.info( "template is at " .. theTemplate:GetCoord():ToStringLLDMS())
			takeoffAirbase = theTemplate:GetCoord():GetClosestAirbase(nil,self.coalition).AirbaseName
			env.info("takeoff airbase is: " .. takeoffAirbase )
		end
	end			
	
	if not landingAirbase then
		landingAirbase = takeoffAirbase
		env.info("landing airbase is: " .. landingAirbase )
	end
	
	-- TODO: Check for duplicates and plausibility
	if not self.FighterList[name] then
		self.FighterList[name] = { 	name = name, 
									FighterTemplate = FighterTemplate, 
									useUncontrolled = useUncontrolled, 
									takeoffAirbase  = takeoffAirbase, 
									landingAirbase  = landingAirbase,
									assigned = nil }
	end
end

function FIGHTERHANDLER:addSpec(name, FighterSpec )
	if not self.FighterSpecs[name] then
		self.FighterSpecs[name] = FighterSpec
	end
end

function FIGHTERHANDLER:SearchFighter( FighterName )
	local theFighter = nil
	local theSpec = nil

	for k,t in pairs(self.FighterList) do
		if t.name == FighterName then 
			theFighter = t
			break
		end
	end

	return theFighter
end

function FIGHTERHANDLER:SearchSpec ( FighterSpec )
	local theSpec = nil

	for n,t in pairs( self.FighterSpecs ) do
		if t.name == FighterSpec then 
			theSpec = t
			break
		end
	end

	return theSpec
end

function FIGHTERHANDLER:menuActivateCallback( spec )
	local FighterFound = self:findAvailableFighter()
	
	if FighterFound then
		self:startFighter( FighterFound.name, spec.name )
	else
		local msg = MESSAGE:New('Request denied: No Fighter plane available!',25):ToCoalition(self.coalition)
	end
end

function FIGHTERHANDLER:menuInit( parentMenu )
	local status = self:getFighterStates()
	local Available = status.number - status.active
	
	self.menus = { 	parentMenu = parentMenu,
					specMenus  = {}
				 }
	
	local theFighterMenu = MENU_COALITION_COMMAND:New( self.coalition ,"Fighter status report",
			parentMenu,
			function()
				local status=self:getFighterStates();
				
				local msg = MESSAGE:New(status.reportText,25):ToCoalition(self.coalition)
			end
		)		

	for k,s in pairs (self.FighterSpecs) do
		if status.specStatus[s.name].assignedTotal == 0 then
			self.menus.specMenus[k] = MENU_COALITION:New( self.coalition, "Tasking: " .. s.name, parentMenu )
			if Available > 0 then
				self.menus.specMenus[k].Boom = MENU_COALITION_COMMAND:New( self.coalition, 'Request Fighter for '..s.name,
					self.menus.specMenus[k],
					self.menuActivateCallback, self, s )
			end
		end
	end	
end

function FIGHTERHANDLER:findAvailableFighter()
	for k,t in pairs ( self.FighterList ) do
		if not t.assigned then
			return t
		end
	end
	return nil
end

function FIGHTERHANDLER:getFighterStates()
	local status =  { number = 0, active = 0,
					  specStatus = { }
					}
					
	local report = 'Available Fighter: \n'

	for k,s in pairs (self.FighterSpecs) do
		status.specStatus[k]={ 
			-- assigned = { Boom = 0, Drogue = 0}, 
			assignedTotal = 0
		}
	end
	
	for k,t in pairs ( self.FighterList ) do
		report = report .. 'Fighter '..t.name
		status.number = status.number+1
		if (t.assigned) then
			report = report .. 'is assigned to ' .. t.assigned .. "\n"
			status.active = status.active+1
			status.specStatus[t.assigned].assignedTotal = status.specStatus[t.assigned].assignedTotal+1
		else
			report = report .. ' is waiting for assignment.\n'
		end
	end
	
	status.reportText = report

	return status
end

function FIGHTERHANDLER:setFighterSpec( theFighter )
	if not theFighter.assigned then
		env.warning('called FIGHTERHANDLER:setFighterSpec without spec assigned to fighter, abort!')
		return nil
	end
		
	if not theFighter.FighterGroup then
		env.warning('called setFighterSpec without spawned Group')
		return nil
	end

	local theSpec = self.FighterSpecs [ theFighter.assigned ]

	if  theSpec.task == FIGHTERTASKING.CAP then
		self:setFighterSpecCAP( theFighter )
	elseif theSpec.task == FIGHTERTASKING.Escort then
		self:setFighterSpecEscort ( theFighter )
	else
		env.warning('FIGHTERHANDLER:setFighterSpec: Unrecognized tasking for fighter, abort')
	end
end

function FIGHTERHANDLER:setFighterSpecCAP( theFighter )
	if not theFighter.assigned then
		env.warning('called FIGHTERHANDLER:setFighterSpecCAP without spec assigned to fighter, abort!')
		return nil
	end
		
	if not theFighter.FighterGroup then
		env.warning('called setFighterSpecCAP without spawned Group')
		return nil
	end

	local theSpec = self.FighterSpecs [ theFighter.assigned ]
	if theSpec.task ~= FIGHTERTASKING.CAP then return end -- abort if wrong spec

	theFighter['CapZone'] = AI_CAP_ZONE:New( theSpec.patrolzone, theSpec.PatrolFloorAltitude,theSpec.PatrolCeilingAltitude,theSpec.PatrolMinSpeed,theSpec.PatrolMaxSpeed )

	theFighter.CapZone:SetControllable( theFighter.FighterGroup )
	-- AICapZone:SetEngageRange( 20000 ) -- Set the Engage Range to 20.000 meters. The AI won't engage when the enemy is beyond 20.000 meters.
	theFighter.CapZone:__Start(5)
end

function FIGHTERHANDLER:setFighterSpecEscort( theFighter )
	if not theFighter.assigned then
		env.warning('called FIGHTERHANDLER:setFighterSpecCAP without spec assigned to fighter, abort!')
		return nil
	end
		
	if not theFighter.FighterGroup then
		env.warning('called setFighterSpecCAP without spawned Group')
		return nil
	end

	local theSpec = self.FighterSpecs [ theFighter.assigned ]
	if theSpec.task ~= FIGHTERTASKING.Escort then return end -- abort if wrong spec
	
	local theStartAirbase = AIRBASE:FindByName(theFighter.takeoffAirbase)
	local airbaseStartCoord = theStartAirbase:GetCoord()

	local theLandingAirbase = 	AIRBASE:FindByName(theFighter.landingAirbase)
	local airbaseLandingCoord = theLandingAirbase:GetCoord()			
	env.info( "Landing coordinates: " .. airbaseLandingCoord:ToStringLLDMS())

	local escortVec3d = POINT_VEC3:New(-200,50,-200)	
	local followtask = theFighter.FighterGroup:TaskEscort(theSpec.escortedUnit, escortVec3d, nil, 15000, {"Air"})

	-- add waypoints
	local theWaypoints = {}
	
	-- theTanker.tankerGroup:WayPointInitialize(theWaypoints)
	
	table.insert(theWaypoints,airbaseStartCoord:WaypointAir("BARO", COORDINATE.WaypointType.TakeOffParking, COORDINATE.WaypointAction.FromParkingArea, nil, false, theStartAirbase, {followtask}))
	table.insert(theWaypoints,airbaseLandingCoord:WaypointAirLanding())
	
	-- env.info (table_out(theWaypoints[8]))		
	theFighter.FighterGroup:Route(theWaypoints,2)
end

function FIGHTERHANDLER:startUncontrolled( theFighter )
	env.info("Starting uncontrolled Fighter: " .. theFighter.name )
	
	local Fighter = GROUP:FindByName(theFighter.FighterTemplate)
	
	local theSpec = self.FighterSpecs [ theFighter.assigned ]
	
	-- env.info('FIGHTERHANDLER:startUncontrolled: ' .. table_out(theSpec))
	
	theFighter['FighterGroup'] = Fighter

	Fighter:CommandSetCallsign(theSpec.callsign[1],theSpec.callsign[2] )
	Fighter:CommandSetFrequency(theSpec.frequency)
	Fighter:CommandEPLRS(true) -- datalink on

	self:setCallbacks( Fighter )
	
	Fighter:StartUncontrolled(1)
	self:setFighterSpec( theFighter )
	
	local msgText = 'Requested Fighter ' .. Fighter:GetTypeName() .. ' starting for zone '.. theSpec.name .. ', crew alerted.\n\n'
	msgText = msgText .. 'Contact ' .. theFighter.FighterGroup:GetUnit(1):GetCallsign() .. ' on ' .. theSpec.frequency .. ' MHz\n\n'
	
	local msg = MESSAGE:New(msgText,25):ToCoalition(self.coalition)		
end

function FIGHTERHANDLER:spawnNew( theFighter )
	if not theFighter.assigned then
		env.warning('called FIGHTERHANDLER:spawnNew without spec assigned to Fighter, abort!')
		return nil
	end

	env.info ("Spawning new Fighter: " .. theFighter.name .. ' from ' .. theFighter.FighterTemplate )

	local spawnFighter = SPAWN:New(theFighter.FighterTemplate)
	local theAirbase = AIRBASE:FindByName(theFighter.takeoffAirbase)
	
	local Fighter = spawnFighter:SpawnAtAirbase(theAirbase,SPAWN.Takeoff.Cold)
	theFighter['FighterGroup'] = Fighter
	
	Fighter:CommandSetCallsign(theSpec.callsign[1],theSpec.callsign[2])
	Fighter:CommandSetFrequency(theSpec.frequency)
	Fighter:CommandEPLRS(true) -- datalink on

	self:setFighterSpec( theFighter )
	
	self:setCallbacks( Fighter )

	local theSpec = self.FighterSpecs [ theFighter.assigned ]

	local msgText = 'Requested Fighter ' .. Fighter:GetTypeName() .. ' starting for zone '.. theSpec.name .. ', crew alerted.\n\n'
	msgText = msgText .. 'Contact ' .. theFighter.FighterGroup:GetUnit(1):GetCallsign() .. ' on ' .. theSpec.frequency .. ' MHz\n\n'
	
	local msg = MESSAGE:New(msgText,25):ToCoalition(self.coalition)
end

function FIGHTERHANDLER:setCallbacks( theFighterGroup )
	self:E ('setting callbacks for Fighter')
	
	for k,u in pairs(theFighterGroup:GetUnits()) do
		u:HandleEvent(EVENTS.EngineStartup)
		u['OnEventEngineStartup'] = function(self, EventData)
			self:MessageToCoalition('Fighter ' .. self:GetCallsign() .. ' starting up engines!',20,self:GetCoalition())
		end
		u:HandleEvent(EVENTS.Takeoff)
		u['OnEventTakeoff'] = function(self, EventData)
			self:MessageToCoalition('Fighter ' .. self:GetCallsign() .. ' taking off!',20,self:GetCoalition())
		end
	end
	
	--[[
	theFighterGroup:HandleEvent(EVENTS.EngineStartup)
	theFighterGroup['OnEventEngineStartup'] = function(self, EventData)
		self:MessageToCoalition('Fighter ' .. self:GetCallsign() .. ' starting up engines!',20,self:GetCoalition())
	end

	theFighterGroup:HandleEvent(EVENTS.Takeoff)
	theFighterGroup['OnEventTakeoff'] = function(self, EventData)
		self:MessageToCoalition('Fighter ' .. self:GetCallsign() .. ' taking off!',20,self:GetCoalition())
	end
	--]]
end

function FIGHTERHANDLER:startFighter( FighterName, FighterSpec )
	theFighter = self:SearchFighter(FighterName)
	theSpec   = self:SearchSpec(FighterSpec)
	
	env.info('startTanker: Fighter ' .. FighterName .. ' requested for ' .. FighterSpec)

	if theFighter and theSpec and not theFighter.assigned then
		env.info('startFighter assigning: Fighter ' .. theFighter.name .. ' requested for ' .. theSpec.name )
		theFighter.assigned = theSpec.name
		
		if theFighter.useUncontrolled then
			self:startUncontrolled( theFighter )
		else
			self:spawnNew( theFighter )
		end

		return theFighter.name .. " - " .. theSpec.name
	end
	return nil
end

function FIGHTERHANDLER:assignAsEscort ( EscortedUnit, specTemplate )
	
	if EscortedUnit == nil then
		self:E('FIGHTERHANDLER:assignAsEscort not possible, escorted unit does not exist')
		return nil
	end
	
	local FighterFound = self:findAvailableFighter()
	
	if FighterFound then
		tempSpecName = "Escort " .. EscortedUnit:GetCallsign()
		self:addSpec(tempSpecName, {
			name=tempSpecName,
			callsign = specTemplate.callsign,
			frequency = specTemplate.frequency,
			
			escortedUnit = EscortedUnit,
			task = FIGHTERTASKING.Escort,
			temporary = true
		})
		
		FighterFound.assigned = tempSpecName
		
		if FighterFound.useUncontrolled then
			self:startUncontrolled( FighterFound )
		else
			self:spawnNew( FighterFound )
		end
	else
		local msg = MESSAGE:New('Request denied: No Fighter plane available!',25):ToCoalition(self.coalition)
	end	
end

-- *********************************************************************************************************************************

env.info('dwmutils loaded')