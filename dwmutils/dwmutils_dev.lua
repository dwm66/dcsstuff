env.info( '*** DWMUILS INCLUDE' )

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

function table_out_1 (tt, indent, done)
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
        -- result = result .. table_out (value, indent + 4, done)
        result = result .. "TABLE\n"
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

-- extend Moose coordinate class
function COORDINATE:GetRandomVec2InSector(InnerRadius, OuterRadius, StartAzimuth, EndAzimuth)
    self:I(self:ToStringLLDMS())

    if StartAzimuth == nil then StartAzimuth = 0 end
    if EndAzimuth == nil then EndAzimuth = 360 end

    if StartAzimuth > 180 then StartAzimuth = StartAzimuth - 360 end
    if EndAzimuth > 180 then EndAzimuth = EndAzimuth - 360 end

    local AzimuthDiff = EndAzimuth - StartAzimuth
    if AzimuthDiff <= 0 then AzimuthDiff = AzimuthDiff + 360 end

    self:I ("AzimuthDiff: " .. AzimuthDiff )

    local Theta = (StartAzimuth + AzimuthDiff * math.random())/180*math.pi
    self:I('Azimuth: ' .. Theta/math.pi * 180)

    local Radials = math.random() + math.random()
    if Radials > 1 then
      Radials = 2 - Radials
    end

    local RadialMultiplier
    if InnerRadius and InnerRadius <= OuterRadius then
      RadialMultiplier = ( OuterRadius - InnerRadius ) * Radials + InnerRadius
    else
      RadialMultiplier = OuterRadius * Radials
    end

    local RandomVec2
    if OuterRadius > 0 then
      RandomVec2 = { x = math.cos( Theta ) * RadialMultiplier + self.x, y = math.sin( Theta ) * RadialMultiplier + self.z }
    else
      RandomVec2 = { x = self.x, y = self.z }
    end

    return RandomVec2
end

TANKERHANDLER = {
                    ClassName = 'TANKERHANDLER',
                    coalition = coalition.side.BLUE,
                    tankerList = {},
                    tankerSpecs = {},
                    specsUsage = {},
                }

TANKERTYPES = { Boom = "Boom", Drogue = "Drogue" }

function TANKERHANDLER:New( alias, theCoalition )
    local self = BASE:Inherit(self, BASE:New())
    
    self.alias = alias
    self.coalition = theCoalition or coalition.side.BLUE
    
    return self
end

function TANKERHANDLER:addTanker(name, tankerType, tankerTemplate, useUncontrolled, takeoffAirbase, landingAirbase )
    useUncontrolled = useUncontrolled or false
            
    if useUncontrolled then
        local theGroup = GROUP:FindByName(tankerTemplate)
        -- it is uncontrolled and already there, so just determine where it is ...
            takeoffAirbase = theGroup:GetCoord():GetClosestAirbase(nil,self.coalition).AirbaseName
            self:I("takeoff airbase is: " .. takeoffAirbase )            
    else
        if not takeoffAirbase then                
            local theTemplate = GROUP:FindByName(tankerTemplate)
            self:I( "template is at " .. theTemplate:GetCoord():ToStringLLDMS())
            takeoffAirbase = theTemplate:GetCoord():GetClosestAirbase(nil,self.coalition).AirbaseName
            self:I("takeoff airbase is: " .. takeoffAirbase )
        end
    end            
    
    if not landingAirbase then
        landingAirbase = takeoffAirbase
        self:I("landing airbase is: " .. landingAirbase )
    end


    
    -- TODO: Check for duplicates and plausibility
    if not self.tankerList[name] then
        self.tankerList[name] = {   name = name, 
                                    tankerType = tankerType, 
                                    tankerTemplate = tankerTemplate, 
                                    useUncontrolled = useUncontrolled, 
                                    takeoffAirbase  = takeoffAirbase, 
                                    landingAirbase  = landingAirbase,
                                    assigned = nil,
                                    assignmentData = {},
                                }
    end
    
    self:ExtendData( self.tankerList[name] )
end

function TANKERHANDLER:addSpec(name, tankerSpec )
    if not self.tankerSpecs[name] then
        self.tankerSpecs[name] = tankerSpec
        if tankerSpec['heightOffset'] == nil then
            self.tankerSpecs[name]['heightOffset'] = UTILS.FeetToMeters(3000)
        end
    end
end

function TANKERHANDLER:SearchTanker( tankerName )
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

function TANKERHANDLER:SearchSpec ( tankerSpec )
    local theSpec = nil

    for n,t in pairs( self.tankerSpecs ) do
        if t.name == tankerSpec then 
            theSpec = t
            break
        end
    end

    return theSpec
end

function TANKERHANDLER:CountAssigned( SpecName )
    local Counter = 0
    for _,t in pairs(self.tankerList) do
        if t.assigned == SpecName then
            Counter = Counter+1
        end    
    end
    self:I('Counting ' .. Counter .. ' tankers assigned to spec ' .. SpecName )
    return Counter
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

function TANKERHANDLER:FindGroupManaged(GroupName)
    for _,t in pairs(self.tankerList) do
        if t.tankerGroup and t.tankerGroup:GetName()==GroupName then
            return t
        end
    end
    return nil
end

function TANKERHANDLER:menuActivateCallback(theType, spec)
    local tankerFound = self:findAvailableTanker( theType, spec )
    
    if tankerFound then
        self:startTanker( tankerFound.name, spec.name )
    else
        local msg = MESSAGE:New('Request denied: No ' .. theType .. 'tanker available!',25):ToCoalition(self.coalition)
    end
end

function TANKERHANDLER:menuInit( parentMenu )
    local status = self:getTankerStates()
    local BoomAvailable = status.Boom.number - status.Boom.active
    local DrogueAvailable = status.Drogue.number - status.Drogue.active
    
    self.menus = {     parentMenu = parentMenu,
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
                    self,TANKERTYPES.Boom, s )
            end
            if DrogueAvailable > 0 then
                self.menus.specMenus[k].Drogue = MENU_COALITION_COMMAND:New( self.coalition, 'Request Drogue Tanker for zone '..s.name,
                    self.menus.specMenus[k],
                    self.menuActivateCallback,
                    self,TANKERTYPES.Drogue ,s )
            end
        end
    end    
end

function TANKERHANDLER:findAvailableTanker( theType, theSpec, airstart )
    self:I ('findAvailableTanker: Searching for type ' .. theType)
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

function TANKERHANDLER:getTankerStates()
    local status =  { Boom =     { number = 0, active = 0},
                      Drogue =     { number = 0, active = 0},
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

function TANKERHANDLER:setTACAN( theTankerEntry ,Channel)
    local tankerUnit = theTankerEntry.tankerGroup:GetUnit(1)
    local tankerBeacon = tankerUnit:GetBeacon()

    local tankerSpec =  self.tankerSpecs [ theTankerEntry.assigned ]
    local tankerCall =  tankerSpec.tacan_call .. self:CountAssigned( theTankerEntry.assigned )

    if Channel == nil then
        tankerBeacon:AATACAN(self:_GetProposedTACAN( theTankerEntry ), tankerSpec.tacan_call, true )
    else
        tankerBeacon:AATACAN(Channel, tankerSpec.tacan_call, true )
    end
end

function TANKERHANDLER:setTankerSpec( theTanker, airstart )
    if not theTanker.assigned then
        self:E('called TANKERHANDLER: setTankerSpec without spec assigned to tanker, abort!')
        return nil
    end
        
    if not theTanker.tankerGroup then
        self:E('called setTankerSpec without spawned Group')
        return nil
    end

    local theSpec = self.tankerSpecs [ theTanker.assigned ]

    local theStartAirbase = AIRBASE:FindByName(theTanker.takeoffAirbase)
    local activeStartRW =    theStartAirbase:GetActiveRunway().idx
    local airbaseStartCoord = theStartAirbase:GetCoord()

    local theLandingAirbase =     AIRBASE:FindByName(theTanker.landingAirbase)
    local activeLandingRW =        theLandingAirbase:GetActiveRunway().idx
    local airbaseLandingCoord = theLandingAirbase:GetCoord()            
    self:I( "Tanker " .. theTanker.name .. " landing coordinates: " .. airbaseLandingCoord:ToStringLLDMS())

    -- tasking: Tanker
    local tasks = {}
    -- get tanker task structure
    local tankertask = theTanker.tankerGroup:EnRouteTaskTanker()
            
    -- units = theTanker.tankerGroup:GetUnit(1)
    
    -- env.info("Units: "..table_out(units))
    
    -- beacon = units:GetBeacon()
    -- beacon:AATACAN(self:_GetProposedTACAN( theTanker ), theSpec.tacan_call, true)

    self:setTACAN( theTanker )
    
    -- env.info("Beacon: " .. table_out(beacon))
    
    theTanker.tankerGroup:OptionRTBBingoFuel(true)
    
    -- add waypoints
    local theWaypoints = {}
    
    -- theTanker.tankerGroup:WayPointInitialize(theWaypoints)
    if not airstart then
        table.insert(theWaypoints,airbaseStartCoord:WaypointAirTakeOffParking())
        table.insert(theWaypoints,theSpec.route.base_egress[1].coord:WaypointAirTurningPoint("BARO",self:_GetProposedEnrouteVelocity( theTanker ),{tankertask},'Airbase Exit'))
        -- TODO: Define way there

        for k,cords in pairs(theSpec.route.waythere) do
            table.insert(theWaypoints,cords:WaypointAirTurningPoint("BARO",theSpec.route.velocity))
        end
    end -- airstart
    -- Racetrack
    
    local coord1,coord2 = self:GetRacetrackCoordinates( theTanker )
    local orbittask = theTanker.tankerGroup:TaskOrbit(coord1,coord1.y,self:_GetProposedRacetrackVelocity( theTanker ),coord2)
    table.insert(theWaypoints,coord1:WaypointAirTurningPoint("BARO",self:_GetProposedRacetrackVelocity( theTanker ),{tankertask,orbittask},"Holding Point"))
    
    -- TODO: Define way back
    for k,cords in pairs(theSpec.route.wayback) do
        table.insert(theWaypoints,cords:WaypointAirTurningPoint("BARO",theSpec.route.velocity))
    end

    table.insert(theWaypoints,theSpec.route.base_ingress[1].coord:WaypointAirTurningPoint("BARO",self:_GetProposedEnrouteVelocity( theTanker ),{},'Airbase Ingress'))        
    table.insert(theWaypoints,airbaseLandingCoord:WaypointAirLanding())
    
    -- env.info (table_out(theWaypoints[8]))        
    theTanker.tankerGroup:Route(theWaypoints,2)
end

function TANKERHANDLER:setCallbacks( theTankerGroup )
    self:I ('setting callbacks for Tankers')

    theTankerGroup:HandleEvent(EVENTS.EngineStartup)
    theTankerGroup['OnEventEngineStartup'] = function(self, EventData)
        self:MessageToCoalition('Tanker ' .. self:GetCallsign() .. ' starting up engines!',20,self:GetCoalition())
    end

    theTankerGroup:HandleEvent(EVENTS.Takeoff)
    theTankerGroup['OnEventTakeoff'] = function(self, EventData)
        self:MessageToCoalition('Tanker ' .. self:GetCallsign() .. ' taking off!',20,self:GetCoalition())
    end
end

--[[
	TankerMirageSpec = {
		name = 'MIRAGE',
		callsign = { CALLSIGN.Tanker.Arco,1},
		frequency = 271.525,
		tacan = 103, --as in 101Y
		tacan_call = 'MIR',
		route =  {
			base_egress = {
							{ rwy = '06', coord = getNavpoint ('OWEND',	coalition.side.BLUE, UTILS.FeetToMeters(6000)) },
						  },
			waythere = {
					      getNavpoint('MIRAGE AREN',coalition.side.BLUE,UTILS.FeetToMeters(20000)),
					      getNavpoint('MIRAGE ARIP',coalition.side.BLUE,UTILS.FeetToMeters(20000)),
					  },
			racetrack = {
				coord1 = getNavpoint('MIRAGE',coalition.side.BLUE,UTILS.FeetToMeters(20000)),
				coord2 = getNavpoint('MIRAGE ARCP',coalition.side.BLUE,UTILS.FeetToMeters(20000)),
				altitude = UTILS.FeetToMeters(20000),
				velocity = UTILS.KnotsToMps(300)
			},
			wayback = {
					      getNavpoint('MIRAGE AREX',coalition.side.BLUE,UTILS.FeetToMeters(20000)),
					  },
			base_ingress = {
							{ rwy = '06', coord = getNavpoint ('HILRI',	coalition.side.BLUE, UTILS.FeetToMeters(6000)) },
						  },
			velocity = UTILS.KnotsToKmph(350),
		},		
	}
--]]

function TANKERHANDLER:ExtendData( theTanker )
    -- calculate spec values
    
    self:I(theTanker.tankerTemplate)
    local DCSgroup = GROUP:FindByName(theTanker.tankerTemplate)
    
    if not DCSgroup then
        self:E('could not find template')
        return nil
    end
    
    local DCSunit=DCSgroup:GetUnit(1)
    local DCSdesc=DCSunit:GetDesc()
    local DCScategory=DCSgroup:GetCategory()
    local DCStype=DCSunit:GetTypeName()

    -- self:I(table_out(DCSdesc))

    if not theTanker.aircraft then theTanker['aircraft']={} end

    -- Get type of aircraft.
    theTanker.aircraft.type=DCStype

    -- inital fuel in %
    theTanker.aircraft.fuel=DCSunit:GetFuel()

    -- operational range in NM converted to m
    theTanker.aircraft.Rmax = DCSdesc.range*1852.0

    -- effective range taking fuel into accound and a 5% reserve
    theTanker.aircraft.Reff = theTanker.aircraft.Rmax*theTanker.aircraft.fuel*0.95

    -- max airspeed from group
    theTanker.aircraft.Vmax = DCSdesc.speedMax
      
    -- max climb speed in m/s
    theTanker.aircraft.Vymax=DCSdesc.VyMax

    -- service ceiling in meters
    theTanker.aircraft.ceiling=DCSdesc.Hmax
    
    -- self:I(table_out(theTanker.aircraft))
end

function TANKERHANDLER:_GetProposedEnrouteVelocity( theTanker,altitude )
    if altitude == nil then
        altitude = self.tankerSpecs[theTanker.assigned].route.racetrack.coord1.y
    end

    if not theTanker.assignmentData.EnrouteVelocity then
        -- Desired speed in km/h
        local AirplaneCap = UTILS.MpsToKmph(theTanker.aircraft.Vmax * 0.8) -- Vmax is m/s
        local Desired = self.tankerSpecs[theTanker.assigned].route.velocity -- km/h
        if not Desired then 
            Desired = AirplaneCap
        else
            Desired = math.min(Desired, AirplaneCap)
        end
        -- self:I("Proposed tanker enroute velocity: " .. UTILS.KmphToKnots(Desired) .. 'knots is ' .. UTILS.KnotsToAltKIAS(UTILS.KmphToKnots(Desired), UTILS.MetersToFeet(altitude)) .. " KIAS in " .. UTILS.MetersToFeet(altitude) ..' feet') 
        theTanker.assignmentData.EnrouteVelocity = Desired
    end
    
    return theTanker.assignmentData.EnrouteVelocity  
end

function TANKERHANDLER:_GetProposedRacetrackVelocity( theTanker, altitude )

    if altitude == nil then
        altitude = self.tankerSpecs[theTanker.assigned].route.racetrack.coord1.y
    end
    
    if not theTanker.assignmentData.RacetrackVelocity then
        local AirplaneCap = UTILS.MpsToKmph(theTanker.aircraft.Vmax * 0.8) -- Vmax is m/s
        local Desired = UTILS.MpsToKnots(self.tankerSpecs[theTanker.assigned].route.racetrack.velocity)
        if not Desired then
            Desired = 270
        end
        Desired = math.min(Desired, AirplaneCap)

        self:I("Proposed Racetrack Velocity: " .. Desired .. 'knots is ' .. UTILS.KnotsToAltKIAS(Desired, UTILS.MetersToFeet(altitude)) .. " KIAS")
        
        theTanker.assignmentData.RacetrackVelocity = UTILS.KnotsToMps(UTILS.KnotsToAltKIAS(Desired, UTILS.MetersToFeet(altitude)))
    end
    
    return theTanker.assignmentData.RacetrackVelocity
end

function TANKERHANDLER:_GetProposedTACAN( theTanker )
    return self.tankerSpecs[theTanker.assigned].tacan
end

function TANKERHANDLER:_GetAirspawnCoordinate( theTanker )
    local coord1, coord2 = self:GetRacetrackCoordinates( theTanker )
    
    local IngressDistance = coord1:Get2DDistance(coord2)
	local StartCoord = coord1:GetIntermediateCoordinate(coord2,20000/IngressDistance*(-1)):GetRandomCoordinateInRadius(10000):SetAltitude(coord1.y)
    
    return StartCoord
end

function TANKERHANDLER:startUncontrolled( theTanker )
    self:I("Starting uncontrolled Tanker: " .. theTanker.name )
    
    local tanker = GROUP:FindByName(theTanker.tankerTemplate)
    
    local theSpec = self.tankerSpecs [ theTanker.assigned ]    
    
    theTanker['tankerGroup'] = tanker

    tanker:CommandSetCallsign(theSpec.callsign[1],theSpec.callsign[2])
    tanker:CommandSetFrequency(theSpec.frequency)

    self:setTankerSpec( theTanker )
    -- self:setCallbacks(tanker)
    
    tanker:StartUncontrolled(1)
    
    local msgText = 'Requested tanker ' .. tanker:GetTypeName() .. ' starting for zone '.. theSpec.name .. ', crew alerted.\n\n'
    msgText = msgText .. 'Contact ' .. theTanker.tankerGroup:GetUnit(1):GetCallsign() .. ' on ' .. theSpec.frequency .. ' MHz\n\n'
    msgText = msgText .. 'TACAN ' .. theSpec.tacan_call .. ' on ' ..theSpec.tacan ..'Y'
    
    local msg = MESSAGE:New(msgText,25):ToCoalition(self.coalition)        
end

function TANKERHANDLER:GetRacetrackCoordinates( theTanker)
    if not theTanker.assigned then
        self:E('called TANKERHANDLER:GetRacetrackCoordinates without spec assigned to tanker, abort!')
        return nil
    end
    
    local theSpec = self.tankerSpecs [ theTanker.assigned ]
    local assignedCounter = self:CountAssigned(theSpec.name)   
    
    local RaceTrackAltitude = theSpec.route.racetrack.coord1.y;
    local RaceTrackAltitude = RaceTrackAltitude + theSpec.heightOffset*( assignedCounter-1 )
    
    self:I("Setting race track altitude for tanker " .. theTanker.name .. " to " .. RaceTrackAltitude)
    
    local coord1 = COORDINATE:NewFromCoordinate(theSpec.route.racetrack.coord1):SetAltitude(RaceTrackAltitude)
    local coord2 = COORDINATE:NewFromCoordinate(theSpec.route.racetrack.coord2):SetAltitude(RaceTrackAltitude)
    
    -- self:I('Racetrack-Altitude: ' .. RaceTrackAltitude .. ' at coordinate: ' .. coord1.y)
    
    return coord1, coord2
end

function TANKERHANDLER:spawnNew( theTanker, airstart )
    if not theTanker.assigned then
        self:E('called TANKERHANDLER:spawnNew without spec assigned to tanker, abort!')
        return nil
    end

    self:I("Spawning new Tanker: " .. theTanker.name .. ' from ' .. theTanker.tankerTemplate )

    local spawnTanker = SPAWN:New(theTanker.tankerTemplate)
    
    if airstart then
        self:I( theTanker.name .. ' - airstart initiated')
        
        local spawnCoord = self:_GetAirspawnCoordinate ( theTanker )
        local nextCoord, rtCoord = self:GetRacetrackCoordinates( theTanker)
        
        local BasicHeading = spawnCoord:GetAngleDegrees(spawnCoord:GetDirectionVec3(nextCoord))
        spawnTanker:InitHeading(BasicHeading)
        
        theTanker['tankerGroup'] = spawnTanker:SpawnFromCoordinate(spawnCoord)  
    else
        local theAirbase = AIRBASE:FindByName(theTanker.takeoffAirbase)
        self:I( theTanker.name .. ' - cold start initiated at ' .. theTanker.takeoffAirbase )
        theTanker['tankerGroup'] = spawnTanker:SpawnAtAirbase(theAirbase,SPAWN.Takeoff.Cold)
    end

    if theTanker.tankerGroup == nil then
        self:E('TANKERHANDLER: could not start ' .. theTanker.name)
        theTanker.assigned = nil
        return nil
    end
        
    theTanker.tankerGroup:CommandSetCallsign(theSpec.callsign[1],theSpec.callsign[2]+(self:CountAssigned( theSpec.name )-1))
    theTanker.tankerGroup:CommandSetFrequency(theSpec.frequency)

    self:setTankerSpec( theTanker, airstart )
    self:setCallbacks( theTanker.tankerGroup )

    local msgText = 'Requested tanker ' .. theTanker.tankerGroup:GetTypeName() .. ' starting for zone '.. theSpec.name .. ', crew alerted.\n\n'
    if airstart then
        msgText = 'Requested tanker ' .. theTanker.tankerGroup:GetTypeName() .. ' arrived in zone '.. theSpec.name .. '\n\n'
    end
    
    msgText = msgText .. 'Contact ' .. theTanker.tankerGroup:GetUnit(1):GetCallsign() .. ' on ' .. theSpec.frequency .. ' MHz\n\n'
    msgText = msgText .. 'TACAN ' .. theSpec.tacan_call .. ' on ' ..theSpec.tacan ..'Y'
    
    local msg = MESSAGE:New(msgText,25):ToCoalition(self.coalition)
end

function TANKERHANDLER:_Start()
    -- self:I( self.alias )
    self:HandleEvent(EVENTS.EngineStartup,  self._OnEngineStartup)
    self:HandleEvent(EVENTS.Takeoff,        self._OnTakeoff)
    -- self:HandleEvent(EVENTS.Land,           self._OnLand)
    -- self:HandleEvent(EVENTS.EngineShutdown, self._OnEngineShutdown)
    --self:HandleEvent(EVENTS.Dead,           self._OnDeadOrCrash)
    --self:HandleEvent(EVENTS.Crash,          self._OnDeadOrCrash)
    --self:HandleEvent(EVENTS.Hit,            self._OnHit)
end

function TANKERHANDLER:_OnEngineStartup(EventData)
    -- self:I(table_out(EventData.IniUnit))
    local SpawnGroup = EventData.IniGroup --Wrapper.Group#GROUP

    if SpawnGroup then
        local theGroup = self:FindGroupManaged(SpawnGroup:GetName())
        if theGroup then
            local theUnit = EventData.IniUnit
            if theUnit then 
                local msg = 'Tanker ' .. theUnit:GetCallsign() .. ' starting up engines!'
                self:I(msg)
                theUnit:MessageToCoalition(msg,20,SpawnGroup:GetCoalition())
            end
        end    
    else
        self:T2(RAT.id.."ERROR: Group does not exist in TANKERHANDLER:_EngineStartup().")
    end
end

function TANKERHANDLER:_OnTakeoff(EventData)
    -- self:I(table_out(EventData))
    local SpawnGroup = EventData.IniGroup --Wrapper.Group#GROUP

    if SpawnGroup then
        local theGroup = self:FindGroupManaged(SpawnGroup:GetName())
        if theGroup then
            local theUnit = EventData.IniUnit
            if theUnit then 
                local msg = 'Tanker ' .. theUnit:GetCallsign() .. ' wheels up!'
                self:I(msg)
                theUnit:MessageToCoalition(msg,20,SpawnGroup:GetCoalition())
            end
        end    
    else
        self:T2(RAT.id.."ERROR: Group does not exist in TANKERHANDLER:_EngineStartup().")
    end
end

function TANKERHANDLER:_OnStation( tankerGroup )
    self:I('Tanker ' .. tankerGroup:GetCallsign() .. ' is on station')
end

function TANKERHANDLER:startTanker( tankerName, tankerSpec, airstart )
    theTanker = self:SearchTanker(tankerName)
    theSpec   = self:SearchSpec(tankerSpec)
    
    self:I('startTanker: Tanker ' .. tankerName .. ' requested for ' .. tankerSpec)
    
    if airstart and theTanker.useUncontrolled then
        self:E("Tanker " .. theTanker.name .. " can not do airstarts, its uncontrolled on " .. theTanker.takeoffAirbase)
    end

    if theTanker and theSpec and not theTanker.assigned then
        self:I('startTanker assigning: Tanker ' .. theTanker.name .. ' requested for ' .. theSpec.name )
        theTanker.assigned = theSpec.name
        
        if theTanker.useUncontrolled then
            self:startUncontrolled( theTanker )
        else
            self:spawnNew( theTanker,airstart )
        end

        return theTanker.name .. " - " .. theSpec.name
    end
    return nil
end

function TANKERHANDLER:assignEscort( tankerName, fighterHandler, templateSpec )
    theTanker = self:SearchTanker(tankerName)
    
    fighterHandler:assignAsEscort( theTanker.tankerGroup, templateSpec )
end

-- ------------------------------- AWACS handler

AWACSHANDLER = {
                    ClassName = 'AWACSHANDLER',
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
            self:I("takeoff airbase is: " .. takeoffAirbase )            
    else
        if not takeoffAirbase then                
            local theTemplate = GROUP:FindByName(AWACSTemplate)
            -- TODO: Treat error if template does not exist
            self:I( "template is at " .. theTemplate:GetCoord():ToStringLLDMS())
            takeoffAirbase = theTemplate:GetCoord():GetClosestAirbase(nil,self.coalition).AirbaseName
            self:I("takeoff airbase is: " .. takeoffAirbase )
        end
    end            
    
    if not landingAirbase then
        landingAirbase = takeoffAirbase
        self:I("landing airbase is: " .. landingAirbase )
    end


    
    -- TODO: Check for duplicates and plausibility
    if not self.AWACSList[name] then
        self.AWACSList[name] = {     name = name, 
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

function AWACSHANDLER:SearchAWACS( AWACSName, airstart )
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
    
    self.menus = {     parentMenu = parentMenu,
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
    local activeStartRW =    theStartAirbase:GetActiveRunway().idx
    local airbaseStartCoord = theStartAirbase:GetCoord()

    local theLandingAirbase =     AIRBASE:FindByName(theAWACS.landingAirbase)
    local activeLandingRW =        theLandingAirbase:GetActiveRunway().idx
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
        self:E('called AWACSHANDLER:spawnNew without spec assigned to AWACS, abort!')
        return nil
    end

    self:I("Spawning new AWACS: " .. theAWACS.name .. ' from ' .. theAWACS.AWACSTemplate )

    local theSpec = self.AWACSSpecs [ theAWACS.assigned ]

    local spawnAWACS = SPAWN:New(theAWACS.AWACSTemplate)
    if airstart then
        self:I( theAWACS.name .. ' - airstart initiated')
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
    self:I ('setting callbacks for AWACS')

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
    
    self:I('startAWACS: AWACS ' .. AWACSName .. ' requested for ' .. AWACSSpec)
    
    if airstart and theAWACS.useUncontrolled then
        self:E("AWACS " .. theAWACS.name .. " can not do airstarts, its uncontrolled on " .. theAWACS.takeoffAirbase)
    end    

    if theAWACS and theSpec and not theAWACS.assigned then
        self:I('startAWACS assigning: AWACS ' .. theAWACS.name .. ' requested for ' .. theSpec.name )

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
                    ClassName = 'FIGHTERHANDLER',
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
            self:I(name .. ": takeoff airbase is: " .. takeoffAirbase )            
    else
        if not takeoffAirbase then                
            local theTemplate = GROUP:FindByName(FighterTemplate)
            -- TODO: Treat error if template does not exist
            self:I(name ..  ": template is at " .. theTemplate:GetCoord():ToStringLLDMS())
            takeoffAirbase = theTemplate:GetCoord():GetClosestAirbase(nil,self.coalition).AirbaseName
            self:I(name .. ": takeoff airbase is: " .. takeoffAirbase )
        end
    end            
    
    if not landingAirbase then
        landingAirbase = takeoffAirbase
        self:I(name .. ": landing airbase is: " .. landingAirbase )
    end
    
    -- TODO: Check for duplicates and plausibility
    if not self.FighterList[name] then
        self.FighterList[name] = {     name = name, 
                                    FighterTemplate = FighterTemplate, 
                                    useUncontrolled = useUncontrolled, 
                                    takeoffAirbase  = takeoffAirbase, 
                                    landingAirbase  = landingAirbase,
                                    assigned = nil }
    else
        self:E('Duplicate fighter name: ' .. name .. ', this is not allowed!')
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
    
    self.menus = {     parentMenu = parentMenu,
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
        self:E('called FIGHTERHANDLER:setFighterSpecCAP without spec assigned to fighter, abort!')
        return nil
    end
        
    if not theFighter.FighterGroup then
        self:E('called setFighterSpecCAP without spawned Group')
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
        self:E('called FIGHTERHANDLER:setFighterSpecCAP without spec assigned to fighter, abort!')
        return nil
    end
        
    if not theFighter.FighterGroup then
        self:E('called setFighterSpecCAP without spawned Group')
        return nil
    end

    local theSpec = self.FighterSpecs [ theFighter.assigned ]
    if theSpec.task ~= FIGHTERTASKING.Escort then return end -- abort if wrong spec
    
    local theStartAirbase = AIRBASE:FindByName(theFighter.takeoffAirbase)
    local airbaseStartCoord = theStartAirbase:GetCoord()

    local theLandingAirbase =     AIRBASE:FindByName(theFighter.landingAirbase)
    local airbaseLandingCoord = theLandingAirbase:GetCoord()            
    self:I( "Landing coordinates: " .. airbaseLandingCoord:ToStringLLDMS())

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
    self:I("Starting uncontrolled Fighter: " .. theFighter.name )
    
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
        self:E('called FIGHTERHANDLER:spawnNew without spec assigned to Fighter, abort!')
        return nil
    end

    self:I("Spawning new Fighter: " .. theFighter.name .. ' from ' .. theFighter.FighterTemplate )

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
    
    self:I('startFighter: Fighter ' .. FighterName .. ' requested for ' .. FighterSpec)

    if theFighter and theSpec and not theFighter.assigned then
        self:I('startFighter assigning: Fighter ' .. theFighter.name .. ' requested for ' .. theSpec.name )
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

-- ******************** 
do
	INTERCEPTTRAINER = {
		Coalition          = coalition.side.BLUE,
		InitLimit          = 3,
		AirBaseSpawn       = SPAWN.Takeoff.Cold,
		
		TargetSpecs        = {}
	}
		
	function INTERCEPTTRAINER:New( theCoalition )
		local self = BASE:Inherit(self, BASE:New())
		self.Coalition = theCoalition or coalition.side.BLUE
		
		return self
	end
	
	function INTERCEPTTRAINER:addTargetSpec( Name, Template, StartAt, AttackTarget, RoutePoints, EnrouteMinAltitude, EnrouteMaxAltitude )
		local theSpec = {
			Name = Name,
			Template = Template,
			StartAt = StartAt,
			AttackTarget = AttackTarget,
			RoutePoints = RoutePoints,
			Protected = false,
			EnrouteMinAltitude = EnrouteMinAltitude,
			EnrouteMaxAltitude = EnrouteMaxAltitude,
			IngressDistance = 20000,
			EgressDistance = 10000,
		}
		
		self.TargetSpecs[Name]=theSpec
	end
	
	function INTERCEPTTRAINER:findSpec(Name)
		local theSpec = nil

		for n,t in pairs( self.TargetSpecs ) do
			if t.Name == Name then 
				theSpec = t
				break
			end
		end

		return theSpec		
	end

	function INTERCEPTTRAINER:InterceptTraining ( SpecName )
		if self.TargetSpecs[SpecName] == nil then
			self:E('INTERCEPTTRAINER Error: Spec ' .. SpecName .. ' does not exist!')
		end
		
		local theSpec = self.TargetSpecs[SpecName]		
		local StartAtClass = theSpec.StartAt:GetClassName()
		
		local AttackTargetCoord = theSpec.AttackTarget
		
		local TemplateGroup = GROUP:FindByName(theSpec.Template)
		local EnrouteVelocity = TemplateGroup:GetSpeedMax()*0.8
		
		local TargetSpawn  = SPAWN:New(theSpec.Template) -- :InitLimit(1,3)
		-- TargetSpawn:InitHeading(135)
		local TrainingDroneGroup = {}
		
		local TrainingDroneStart = theSpec.StartAt:GetCoordinate()
		
		local NextPoint = AttackTargetCoord
		if #theSpec.RoutePoints > 0 then
			NextPoint = theSpec.RoutePoints[1]
		end		
		
		local EnrouteAltitude = math.random( theSpec.EnrouteMinAltitude, theSpec.EnrouteMaxAltitude)
		
		if StartAtClass == 'AIRBASE' then
			TrainingDroneGroup = TargetSpawn:SpawnAtAirbase( theSpec.StartAt, self.AirBaseSpawn )
		elseif StartAtClass:sub(1, 4) == 'ZONE' then
			self:I('INTERCEPTTRAINER starting at Zone')
			local BasicHeading = TrainingDroneStart:GetAngleDegrees(TrainingDroneStart:GetDirectionVec3(NextPoint))
			TargetSpawn:InitHeading(BasicHeading)
			TrainingDroneGroup = TargetSpawn:SpawnInZone(theSpec.StartAt, true, theSpec.EnrouteMinAltitude, theSpec.EnrouteMaxAltitude )
			
			TrainingDroneStart = TrainingDroneGroup:GetCoordinate()
			EnrouteAltitude = TrainingDroneStart.y
			env.info('Altitude is ' .. EnrouteAltitude )
		elseif StartAtClass == 'COORDINATE' then
			self:I('INTERCEPTTRAINER starting with a COORDINATE')

			local BasicHeading = TrainingDroneStart:GetAngleDegrees(TrainingDroneStart:GetDirectionVec3(NextPoint))
			TargetSpawn:InitHeading(BasicHeading)
			TrainingDroneGroup = TargetSpawn:SpawnFromCoordinate(theSpec.StartAt)
			
			TrainingDroneStart = theSpec.StartAt
			EnrouteAltitude = TrainingDroneStart.y
			self:I('Altitude is ' .. EnrouteAltitude )
		end
		
		theSpec['DroneGroup']=TrainingDroneGroup
		
		local theWaypoints = {}
		
		if StartAtClass == 'AIRBASE' then
			table.insert(theWaypoints,theSpec.StartAt:GetCoordinate():WaypointAirTakeOffParking())
		else
			-- table.insert(theWaypoints,theSpec.StartAt:GetCoordinate():SetAltitude(EnrouteAltitude):WaypointAirTurningPoint('BARO',EnrouteVelocity ))		
		end

		local lastPoint = TrainingDroneStart:GetIntermediateCoordinate(NextPoint,0.2)
		table.insert(theWaypoints,lastPoint:SetAltitude(EnrouteAltitude):WaypointAirTurningPoint('BARO',EnrouteVelocity ))
		
		for k,cords in pairs(theSpec.RoutePoints) do
			table.insert(theWaypoints,cords:WaypointAirTurningPoint("BARO",EnrouteVelocity))
			lastPoint = cords
		end
		
		local IngressDistance = lastPoint:Get2DDistance(AttackTargetCoord)
		env.info("Ingress Distance: " .. IngressDistance )
		local EgressPoint = AttackTargetCoord:GetIntermediateCoordinate(lastPoint,10000/IngressDistance*(-1))
		
		BombingTask = TrainingDroneGroup:TaskBombing(AttackTargetCoord:GetVec2())
		table.insert(theWaypoints,AttackTargetCoord:SetAltitude(EnrouteAltitude):WaypointAirTurningPoint("BARO",EnrouteVelocity,{BombingTask}))
		table.insert(theWaypoints,EgressPoint:SetAltitude(EnrouteAltitude):WaypointAirTurningPoint('BARO',EnrouteVelocity ))
		
		-- egress ...
		table.insert(theWaypoints,theSpec.StartAt:GetCoordinate():WaypointAirTurningPoint("BARO",EnrouteVelocity))
		
		TrainingDroneGroup:Route(theWaypoints)
		
		theSpec['AttackZone'] = ZONE_RADIUS:New('Simulated Attack Zone',AttackTargetCoord:GetVec2(),3000)
		theSpec.AttackZone:DrawZone(coalition.side.BLUE,{1,0,0})
		
		self['Messager'] = SCHEDULER:New( TrainingDroneGroup,
			function(g,z)
				-- g:E('******************* Scheduler function for Zone ' .. z:GetCoordinate():ToStringLLDDM() .. ' Distance: ' .. z:GetCoordinate():Get2DDistance(g:GetCoordinate()) .. ' ******************')
				if g:IsPartlyOrCompletelyInZone(z) then
					g:MessageToAll( 'Attack group made it to target, defenders loose!' , 60 )
					g:GetCoordinate():IlluminationBomb(5000000)
				else
					-- g:E('************* is outside: ' .. g:GetCoordinate():ToStringLLDDM() ..' *****************')
				end
				-- env.info(g:GetClassName())
				-- env.info('***********************************************************************' .. z:GetClassName())
			end, 
			{ theSpec.AttackZone },1,2)
	end -- INTERCEPTTRAINER
end -- do

-- *********************************************************************************************************************************

env.info(' ******************* dwmutils loaded *********************')