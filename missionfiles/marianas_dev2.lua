SETTINGS:SetPlayerMenuOff()

local Menu1 = false
local MenuTactical = true
local RatOn  = false
local TrainingRangeOn = true
local AARange = true
local CarrierOps = true
local EWRDetection = true
local TankerHandling = true
local AWACSHandling = true
local FighterHandling = true

local MissionParameters = {
	CrystalPalace		= { Unit = "HQ", Frequency = 136.5 },
	TankerOpsFreq		= 328.025,
	FighterOpsFreq		= 376.125,
}

local MissionStates = { Cold = 1, Hot = 2 }
local MissionStateAir = MissionStates.Cold
local MissionStateGround = MissionStates.Cold

-- Mission menus

if Menu1 then
	local M1 = missionCommands.addSubMenu("Tactical Support", nil)

	-- missionCommands.addCommand("Request AWACS Support", M1,function() trigger.action.setUserFlag(62001, 1) end, nil)
	missionCommands.addCommand("Request CAP Support", M1,function() trigger.action.setUserFlag(62003, 1) end, nil)

	local M2 = missionCommands.addSubMenu("Carrier Support", nil)

	missionCommands.addCommand("Request Carrier AWACS Support", M2,function() trigger.action.setUserFlag(63001, 1) end, nil)
	missionCommands.addCommand("Request Carrier Tanker Support", M2,function() trigger.action.setUserFlag(63002, 1) end, nil)
	missionCommands.addCommand("Request Carrier CAP", M2,function() trigger.action.setUserFlag(63003, 1) end, nil)
	missionCommands.addCommand("Request Carrier SUCAP", M2,function() trigger.action.setUserFlag(63004, 1) end, nil)
	missionCommands.addCommand("Request Land based Tanker Support", M2,function() trigger.action.setUserFlag(63005, 1) end, nil)
end

if MenuTactical then
	MenuTactical = {}
	MenuTactical['Blue']={}	
	MenuTactical['Blue']['Top'] = MENU_COALITION:New( coalition.side.BLUE,"Tactical Support")
	MenuTactical['Blue']['AWACS'] = MENU_COALITION:New( coalition.side.BLUE,"AWACS",MenuTactical['Blue']['Top'])
	MenuTactical['Blue']['Tankers'] = MENU_COALITION:New( coalition.side.BLUE,"Tankers",MenuTactical['Blue']['Top'])	
	MenuTactical['Blue']['Fighters'] = MENU_COALITION:New( coalition.side.BLUE,"Fighters",MenuTactical['Blue']['Top'])
	
end

-- helper functions

-- == RAT =====================================================================

if RatOn then

  rat={}
    
  -- Aircraft types.
  rat.aircraft={}
  rat.aircraft.All={"A320","A330","B727", "B737", "B757", "Cessna210","Yak40","Yak52"}
  rat.aircraft.Big={"A320","A330","B727", "B737", "B757"}
  rat.aircraft.Small={"Cessna210","Yak40","Yak52"}
  
  for _,type in pairs(rat.aircraft.All) do
    rat[type]={}
  end
  
  -- Liveries CAM v0.78
  rat.A320.skins={"American Airlines","China Airlines","Cebu Pacific","Lufthansa"}
  rat.A330.skins={"China Eastern","Air China","Air Tahiti Nui","AirAsia","Airbus","Cathay Pacific","CEBU Pacific","DragonAir","Edelweiss","Egypt Air","Emirates","ETIHAD","EVA","FIJI","FinnAir","FrenchBlue","Garude Indunesia","GulfAir","Hainan Airlines","Iberia","IRoI","KLM","LAN Airways","Lion Air PK-LEG","LTU","Lufthansa","NWA","nwaold","Olympic","Philipines","Qantas","Singapore","Srilankan","Star Aliance"}
  rat.B727.skins={"AEROFLOT", "Air France", "Alaska", "Alitalia", "American Airlines", "Clean", "Delta Airlines", "Delta Airlines OLD", "Hapag Lloyd", "Lufthansa", "Lufthansa Oberhausen Old", "Northwest", "Pan Am", "Singapore Airlines", "Southwest", "UNITED", "UNITED Old", "ZERO G"}
  rat.B737.skins={"Japan Airlines 2011 737", "American Modern", "C40s", "JA", "kulula", "LH", "Lufthansa BA", "Lufthansa KR", "QANTAS", "UPS"}
  -- rat.B747.skins={"AF", "AI", "CP", "IM", "KLM", "LH", "NW", "PA", "QA", "TA"} -- not using "AF-One"
  rat.B757.skins={"AA","C-32", "Delta", "DHL", "Asia Pacific Modern 757", "FedEx"}
  -- rat.A380.skins={"Air France", "BA", "China Southern", "Clean", "Emirates", "KA", "LH", "LHF", "Qantas Airways", "QTR", "SA", "TA"}
  rat.Cessna210.skins={"Blank", "D-EKVW", "HellenicAF", "Muster", "N9672H", "SEagle_blue", "SEagle_red", "USAF-Academy", "V5-BUG", "VH-JGA"}
  rat.Yak40.skins={"Olympic Airways","Aeroflot","Delta","Lufthansa","NORTHWEST","VistaJet"}
  rat.Yak52.skins={"Bare_Metall","Pobeda","The First Flight"}
  
  -- Cardinal zones defined in the mission editor.
  rat.zone={}
  -- rat.zone.All={"Zone North", "Zone South", "Zone West", "Zone East", "Zone NorthWest", "Zone NorthEast", "Zone SouthWest", "Zone SouthEast"}
  rat.zone.All = {"RAT Zone North","RAT Zone West","RAT Zone SouthEast"}
  -- rat.zone.Cardinal={"Zone North", "Zone South", "Zone West", "Zone East"}
  rat.zone.Cardinal = {"RAT Zone North","RAT Zone West","RAT Zone SouthEast"}
  
  -- Airports
  rat.airports={}
  
  rat.airports.IntlAll={"Saipan Intl","Antonio B. Won Pat Intl","Rota Intl", "Tinian Intl"}
  rat.airports.IntlBig={"Saipan Intl","Antonio B. Won Pat Intl"}
   
  
  -- Long range outbound traffic: Every 2-4 minues an aircraft of each type leaves from each International Airport to some "far away land".
  -- However, at most two aircraft of each type can be active simultaniously. In total 2*3*3=18 aircraft are activated (4*3*3=36 are spawned in total).
  local bigInboundManager=RATMANAGER:New(2)
  for _,type in pairs(rat.aircraft.Big) do
    for _,airport in pairs(rat.airports.IntlBig) do
      local template=string.format("RAT_%s", type)
      local alias=string.format("%s %s-AllZones", type, airport)
      rat[type].alias=RAT:New(template, alias)
      rat[type].alias:Invisible()
      rat[type].alias:SetDeparture(airport)
      rat[type].alias:SetDestination(rat.zone.All)
      rat[type].alias:DestinationZone()
      rat[type].alias:Livery(rat[type].skins)
      rat[type].alias:SetSpawnDelay(20)
      rat[type].alias:SetSpawnInterval(15)
      rat[type].alias:Uncontrolled()
      rat[type].alias:ActivateUncontrolled(1, math.random(240,720), 240, 0.5)
      -- 1rat[type].alias:Spawn(1)
	  bigInboundManager:Add(rat[type].alias, 0)
    end
  end
  bigInboundManager:Start(10)
  
  -- Long range inbound traffic: Two aircraft of each type are spawned in zones and will fly randomly to all big International Airports. In total 6 aircraft are active.
  local bigOutboundManager=RATMANAGER:New(2)
  for _,type in pairs(rat.aircraft.Big) do
    local template=string.format("RAT_%s", type)
    local alias=string.format("%s AllZones-Intl", type)
    rat[type].alias=RAT:New(template, alias)
    rat[type].alias:Invisible()
    rat[type].alias:SetDeparture(rat.zone.All)
    rat[type].alias:SetDestination(rat.airports.IntlBig)
    rat[type].alias:SetTakeoff("air")
    rat[type].alias:Livery(rat[type].skins)
    rat[type].alias:SetFLcruise(180)
    rat[type].alias:SetFLmin(150)
    rat[type].alias:SetFLmax(200)  
    rat[type].alias:SetSpawnDelay(10)
    rat[type].alias:SetSpawnInterval(120)
    -- rat[type].alias:Spawn(1)
	bigOutboundManager:Add(rat[type].alias, 0)
  end
  bigOutboundManager:Start(15)
  
  -- Local traffic: Four Cessnas are spawned. Two of them are activated and will fly to random big International Airports.
  local localTraffic=RATMANAGER:New(5)
  for _,type in pairs(rat.aircraft.Small) do
    local template=string.format("RAT_%s", type)
    local alias=string.format("%s Small IntlAll", type)
    rat[type].alias=RAT:New(template, alias)
    rat[type].alias:Invisible()
    --rat[type].alias:Debugmode()
    rat[type].alias:SetDeparture(rat.airports.IntlAll)
    rat[type].alias:SetDestination(rat.airports.IntlAll)
    rat[type].alias:Livery(rat[type].skins)
    rat[type].alias:SetSpawnDelay(10)
    rat[type].alias:SetSpawnInterval(1)
    rat[type].alias:Uncontrolled()
    rat[type].alias:ActivateUncontrolled(2, 120, 240, 0.5)
    localTraffic:Add(rat[type].alias, 0)
	-- rat[type].alias:Spawn(4)
  end
  localTraffic:Start(25)  
  
  -- High altitude transient traffic to/from all cardinal directions. Eight aircraft of random type are spawned and will fly from one zone to another.
  local transient=RATMANAGER:New(2)
  for _,type in pairs(rat.aircraft.Big) do
    local template=string.format("RAT_%s", type)
    local alias=string.format("%s %s", type, "Cardinal")        
    rat[type].alias=RAT:New(template, alias)
    rat[type].alias:Invisible() 
    rat[type].alias:SetDeparture(rat.zone.Cardinal)
    rat[type].alias:SetDestination(rat.zone.Cardinal)
    rat[type].alias:SetTakeoff("air")
    rat[type].alias:DestinationZone()
    rat[type].alias:SetFLcruise(250)
    rat[type].alias:SetFLmin(200)
    rat[type].alias:SetFLmax(350)
    rat[type].alias:Livery(rat[type].skins)
    transient:Add(rat[type].alias, 0)
  end
  transient:Start(20)
  
end

if TrainingRangeOn then
	 -- Strafe pits. Each pit can consist of multiple targets.
	 -- These are names of the corresponding units defined in the ME.
	-- local MedinillaStrafePit_left ={"Al Dhafra Range Strafe Pit Left"}
	--// local MedinillaStrafePit_right={"Al Dhafra Range Strafe Pit Right"}

	 -- Table of bombing target names. Again these are the names of the corresponding units as defined in the ME.
	local MedinillaBombTargets = {"Medinilla Bomb Target A-1","Medinilla Bomb Target B-1","Medinilla Bomb Target C-1","Medinilla Bomb Target D-1"}


	 -- Create a range object.
	 MedinillaRange=RANGE:New("Fallon de Medinilla Range")
	 MedinillaRangeZone = ZONE:New("PGR-7201")
	 
	 MedinillaRange:SetRangeZone(MedinillaRangeZone)

	 -- Distance between strafe target and foul line. You have to specify the names of the unit or static objects.
	 -- Note that this could also be done manually by simply measuring the distance between the target and the foul line in the ME.
	-- local MedinillaFoulDist=MedinillaRange:GetFoullineDistance("Al Dhafra Range Strafe Pit Left", "Al Dhafra Range Foul Line Left")

	 -- Add strafe pits. Each pit (left and right) can consist of more targets.
	 -- RANGE:AddStrafePit(targetnames, boxlength, boxwidth, heading, inverseheading, goodpass, foulline)
	-- MedinillaRange:AddStrafePit(MedinillaStrafePit_left,  nil, nil, nil, true, 15, MedinillaFoulDist)
	 -- MedinillaRange:AddStrafePit(MedinillaStrafePit_right, nil, nil, nil, true, 15, MedinillaFoulDist)
	 
	 -- Add moving strafing target


	 -- Add bombing targets. A good hit is if the bomb falls less then 50 m from the target.
	MedinillaRange:AddBombingTargets(MedinillaBombTargets, 50)

	-- tune radio frequency
	MedinillaRange:SetRangeControl(325.050)
	MedinillaRange:SetInstructorRadio(325.050)

	-- Start range.
	MedinillaRange:Start()
end

if AARange then
	fox=FOX:New()

	-- fighter training scenario
	function FighterTraining1 ( template, StartAt, AAZone )
		StartAtClass = StartAt:GetClassName()
		env.info("FighterTraining - StartAt is a " .. StartAtClass)
		
		local FighterSpawn = SPAWN:New( template ):InitLimit(1,3)
		FighterSpawn:InitRepeatOnEngineShutDown()
		
		
		if StartAtClass == 'AIRBASE' then
			local TrainingDroneGroup = FighterSpawn:SpawnAtAirbase( StartAt, SPAWN.Takeoff.Cold )
		elseif StartAtClass:sub(1, 4) == 'ZONE' then
			env.info('FighterTraining starting at Zone')
			local TrainingDroneGroup = FighterSpawn:SpawnInZone(SpawnAt, true, UTILS.FeetToMeters(15000), UTILS.FeetToMeters(30000) ) 
		end
		
		if TrainingDroneGroup == nil then
			return
		end
		
		local TrainingCAPZone = AI_CAP_ZONE:New( AAZone, UTILS.FeetToMeters(15000), UTILS.FeetToMeters(30000),
														 UTILS.KnotsToKmph(300),UTILS.KnotsToKmph(400) )

		TrainingCAPZone:SetControllable( TrainingDroneGroup )
		
		-- AICapZone:SetEngageRange( 20000 ) -- Set the Engage Range to 20.000 meters. The AI won't engage when the enemy is beyond 20.000 meters.
		fox:AddProtectedGroup(TrainingDroneGroup)

		TrainingCAPZone:__Start(1)
	end
	
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
		
		theSpec['AttackZone'] = ZONE_RADIUS:New('Simulated Attack Zone',AttackTargetCoord:GetVec2(),5000)
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
	end

	MenuTactical['Blue']['Training'] = MENU_COALITION:New( coalition.side.BLUE,"Air-Air Training")

	MenuTactical['Blue']['Training']['Target Drone QF-4E']=MENU_COALITION_COMMAND:New( coalition.side.BLUE ,'Target Drone QF-4E',
		MenuTactical['Blue']['Training'],
		function()				
			local msg = MESSAGE:New("Starting Target Drone",25):ToCoalition(coalition.side.BLUE)
			FighterTraining1 ('TargetdroneTemplate - F-4E-1',AIRBASE:FindByName('Andersen AFB'),TrainingZone)
		end
	)		

	InterceptTrainer = INTERCEPTTRAINER:New(coalition.side.BLUE)
	InterceptTrainer:addTargetSpec('Tu95 from northwest','TargetdroneTemplate -Tu95-1',ZONE_RADIUS:New('Tu95Area',getNavpoint('MIRAGE',coalition.side.BLUE,0):GetVec2(),100),
	                               UNIT:FindByName('Medinilla Bomb Target B-1'):GetCoord(),
								   {}, UTILS.FeetToMeters(15000),UTILS.FeetToMeters(20000))
	InterceptTrainer:addTargetSpec('B17 from northwest','TargetdroneTemplate -B17-1',ZONE_RADIUS:New('B17Area',COORDINATE:NewFromLLDD(18.5,143,0):GetVec2(),40000),
	                               AIRBASE:FindByName('Andersen AFB'):GetCoord(),
								   {}, UTILS.FeetToMeters(5000),UTILS.FeetToMeters(15000))								   
	env.info(table_out(InterceptTrainer.TargetSpecs))

	InterceptTrainer:InterceptTraining('B17 from northwest')
	
	-- Add single protected group(s).
	-- fox:AddProtectedGroup(GROUP:FindByName("Target-Drone 1-2"))
	-- fox:AddSafeZone(ZONE:New("Safe Zone AA-Training 1"))
	-- Start missile trainer.
	local vec = getNavpoint('WUVEN',coalition.side.BLUE,0):GetVec2()
	TrainingZone = ZONE_RADIUS:New('A2A Training Area',vec,20000)
	-- TrainingZone = ZONE:New('AA Training')
	
	TrainingZone:DrawZone(coalition.side.BLUE,{1,0,0})
	fox:AddSafeZone( TrainingZone )
	-- fox:Start()
end

if CarrierOps then
	local Carrier1GroupName = 'CVBG75'
	local Carrier1Name = Carrier1GroupName .. '-1'
	local RescueHelo1Name = Carrier1GroupName .. '-SAR-1' -- CVBG75-SAR-1
	local RecoveryAWACS1Name = Carrier1GroupName .. '-AWACS-1'
	local RecoveryTanker1Name = Carrier1GroupName .. '-TANKER-1'
	local CAP1Name = Carrier1GroupName .. '-CAP-1'
	local CAP2Name = Carrier1GroupName .. '-CAP-2'
	local SUCAP1Name = Carrier1GroupName .. '-SUCAP-1'
	-- local SUCAP2Name = Carrier1GroupName .. '-SUCAP-2'
	
	heloCarrier1=RESCUEHELO:New( Carrier1Name, RescueHelo1Name )
	heloCarrier1:SetTakeoffCold()
	heloCarrier1:Start()

	-- E-2D @ 
	awacsCarrier1=RECOVERYTANKER:New(Carrier1Name, RecoveryAWACS1Name )

	-- Custom settings:
	awacsCarrier1:SetUseUncontrolledAircraft()
	awacsCarrier1:SetAWACS()
	awacsCarrier1:SetCallsign(CALLSIGN.AWACS.Darkstar)
	awacsCarrier1:SetTakeoffCold()
	awacsCarrier1:SetAltitude(20000)
	awacsCarrier1:SetSpeed(300)
	awacsCarrier1:SetRadio(262)
	awacsCarrier1:SetTACAN(2, "DSR")
	awacsCarrier1:SetRacetrackDistances(40, 20)
	awacsCarrier1:SetModex(666)
	
	-- awacsCarrier1:__Start(1)
	
	-- S-3B at USS Carrier1 spawning on deck.
	tankerCarrier1=RECOVERYTANKER:New(Carrier1Name, RecoveryTanker1Name )

	-- Custom settings:
	tankerCarrier1:SetUseUncontrolledAircraft()
	tankerCarrier1:SetTakeoffCold()
	tankerCarrier1:SetRadio(261)
	tankerCarrier1:SetTACAN(1, "SHL")
	tankerCarrier1:SetCallsign(CALLSIGN.Tanker.Shell)
	tankerCarrier1:SetModex(0)  -- "Triple nuts"

	-- Start recovery tanker.
	-- NOTE: If you spawn on deck, it seems prudent to delay the spawn a bit after the mission starts.
	-- tankerCarrier1:__Start(1)
	
	local CAP1Carrier1 = GROUP:FindByName(CAP1Name)
	CAP1Carrier1:Activate(2)
	local CAP2Carrier1 = GROUP:FindByName(CAP2Name)
	CAP2Carrier1:Activate(2)
	local SUCAP1Carrier1 = GROUP:FindByName(SUCAP1Name)
	SUCAP1Carrier1:Activate(2)

	-- set up menus
	if MenuTactical then
		MenuTactical['Blue']['Carrier']=MENU_COALITION:New( coalition.side.BLUE,"Carrier Support")		
		MenuTactical['Blue']['Carrier']['AWACS']=MENU_COALITION_COMMAND:New( coalition.side.BLUE ,'Request Carrier AWACS Support',
			MenuTactical['Blue']['Carrier'],
			function()				
				local msg = MESSAGE:New("Carrier AWACS Starting up",25):ToCoalition(coalition.side.BLUE)
				awacsCarrier1:__Start(1)
			end
		)		
		MenuTactical['Blue']['Carrier']['Tanker']=MENU_COALITION_COMMAND:New( coalition.side.BLUE ,'Request Carrier Tanker Support',
			MenuTactical['Blue']['Carrier'],
			function()				
				local msg = MESSAGE:New("Carrier Tanker Starting up",25):ToCoalition(coalition.side.BLUE)
				tankerCarrier1:__Start(1)
			end
		)	
		MenuTactical['Blue']['Carrier']['CAP1']=MENU_COALITION_COMMAND:New( coalition.side.BLUE ,'Request Carrier CAP',
			MenuTactical['Blue']['Carrier'],
			function()				
				local msg = MESSAGE:New("Carrier CAP Starting up",25):ToCoalition(coalition.side.BLUE)
				CAP1Carrier1:StartUncontrolled(4)
			end
		)		
		MenuTactical['Blue']['Carrier']['SUCAP1']=MENU_COALITION_COMMAND:New( coalition.side.BLUE ,'Request Carrier SUCAP',
			MenuTactical['Blue']['Carrier'],
			function()				
				local msg = MESSAGE:New("Carrier SUCAP Starting up",25):ToCoalition(coalition.side.BLUE)
				SUCAP1Carrier1:StartUncontrolled(4)
			end
		)
	end	
end

if EWRDetection then
	SetEWRGroup = SET_GROUP:New():FilterPrefixes( "EWR" ):FilterStart()

	HQ = GROUP:FindByName( "HQ" )
	CC = COMMANDCENTER:New( HQ, "HQ" )

	AlertRaised = false

	RecceDetection = DETECTION_UNITS:New( SetEWRGroup ):FilterCategories( Unit.Category.AIRPLANE )

	RecceDetection:Start()

	--- OnAfter Transition Handler for Event Detect.
	-- @param Functional.Detection#DETECTION_UNITS self
	-- @param #string From The From State string.
	-- @param #string Event The Event string.
	-- @param #string To The To State string.
	-- function RecceDetection:OnAfterDetect(From,Event,To)

	  -- local DetectionReport = self:DetectedReportDetailed()

	  -- HQ:MessageToAll( DetectionReport, 15, "Detection" )
	-- end

	function RecceDetection:OnAfterDetected( From, Event, To, DetectedUnits )
		self:E( { From, Event, To, DetectedUnits } )

		for DetectedUnitID, DetectedUnit in pairs( DetectedUnits ) do
			local DetectedUnit = DetectedUnit -- Wrapper.Unit#UNIT

			local ThreatLevel = DetectedUnit:GetThreatLevel()

			HQ:MessageToAll("Threat detected, raising Alert "..ThreatLevel, 30, "Detection")

			if ThreatLevel > 0 and not AlertRaised then
				HQ:MessageToAll("Threat detected, raising Alert", 30, "Detection")
				AlertRaised = true
			end -- if
		
		end -- for ...
	end -- function
	-- garbagecollect()
end -- EWRDetection

if FighterHandling then
	GuamCAPSpec = {
		name = 'Guam CAP',
		callsign = { CALLSIGN.Aircraft.Colt,3 },
		frequency = 238.5,
		task = FIGHTERTASKING.CAP,
		
		patrolzone = ZONE_AIRBASE:New(AIRBASE.MarianaIslands.Andersen_AFB,50000),
		PatrolFloorAltitude = 5000, 
		PatrolCeilingAltitude = 10000, 
		PatrolMinSpeed = 600, PatrolMaxSpeed= 700, 
		-- EngageMinSpeed, EngageMaxSpeed, PatrolAltType
	}
	
	MarianasFightersBlue = FIGHTERHANDLER:New()
	
	MarianasFightersBlue:addFighter('JG73-1','JG-73-F15C-1',true)
	MarianasFightersBlue:addFighter('JG73-2','JG-73-F15C-2',true)
	MarianasFightersBlue:addFighter('JG73-3','JG-73-F15C-3',true)
	MarianasFightersBlue:addFighter('JG73-4','JG-73-F15C-4',true)

	MarianasFightersBlue:addSpec('Guam CAP',GuamCAPSpec)
	
	MarianasFightersBlue:menuInit(MenuTactical['Blue']['Fighters'])		
end -- Fighter Handling

if TankerHandling then
	env.info(table_out(TankerHandler))

	TankerRIOSpec = {
		name = 'RIO',
		callsign = { CALLSIGN.Tanker.Shell,2 },
		frequency = 234.75,
		tacan = 101, --as in 101Y
		tacan_call = 'RIO',
		route =  {
			base_egress = {
							{ rwy = '06', coord = getNavpoint ('OWEND',	coalition.side.BLUE, UTILS.FeetToMeters(6000)) },
						  },
			waythere = {
					      getNavpoint('RIO AREN',coalition.side.BLUE,UTILS.FeetToMeters(20000)),
					      getNavpoint('RIO ARIP',coalition.side.BLUE,UTILS.FeetToMeters(20000)),
					  },
			racetrack = {
				coord1 = getNavpoint('RIO',coalition.side.BLUE,UTILS.FeetToMeters(20000)),
				coord2 = getNavpoint('RIO ARCP',coalition.side.BLUE,UTILS.FeetToMeters(20000)),
				altitude = UTILS.FeetToMeters(20000),
				velocity = UTILS.KnotsToMps(300)
			},
			wayback = {
					      getNavpoint('RIO AREX',coalition.side.BLUE,UTILS.FeetToMeters(20000)),
					  },
			base_ingress = {
							{ rwy = '06', coord = getNavpoint ('HILRI',	coalition.side.BLUE, UTILS.FeetToMeters(6000)) },
						  },
			velocity = UTILS.KnotsToKmph(350),
		},		
	}

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

	TankerLuxorSpec = {
		name = 'LUXOR',
		callsign = { CALLSIGN.Tanker.Arco,1},
		frequency = MissionParameters.TankerOpsFreq,
		tacan = 102, --as in 102Y
		tacan_call = 'LXR',
		route =  {
			base_egress = {
							{ rwy = '06', coord = getNavpoint ('OWEND',	coalition.side.BLUE, UTILS.FeetToMeters(6000)) },
						  },
			waythere = {
					      getNavpoint('LUXOR AREN',coalition.side.BLUE,UTILS.FeetToMeters(20000)),
					      getNavpoint('LUXOR ARIP',coalition.side.BLUE,UTILS.FeetToMeters(20000)),
					  },
			racetrack = {
				coord1 = getNavpoint('LUXOR',coalition.side.BLUE,UTILS.FeetToMeters(20000)),
				coord2 = getNavpoint('LUXOR ARCP',coalition.side.BLUE,UTILS.FeetToMeters(20000)),
				altitude = UTILS.FeetToMeters(20000),
				velocity = UTILS.KnotsToMps(300)
			},
			wayback = {
					      getNavpoint('LUXOR AREX',coalition.side.BLUE,UTILS.FeetToMeters(20000)),
					  },
			base_ingress = {
							{ rwy = '06', coord = getNavpoint ('HILRI',	coalition.side.BLUE, UTILS.FeetToMeters(6000)) },
						  },
			velocity = UTILS.KnotsToKmph(350),
		},		
	}

	
	MarianasTankersBlue = TankerHandler:New()

	MarianasTankersBlue:addTanker("Django-1", TankerTypes.Boom, 'Template-KC-135-1',true)
	MarianasTankersBlue:addTanker("Django-2", TankerTypes.Drogue, 'Template-KC-135MPRS-1',true)
	MarianasTankersBlue:addTanker("Django-3", TankerTypes.Boom, 'Template-KC-135-2',true)
	MarianasTankersBlue:addTanker("Django-4", TankerTypes.Drogue, 'Template-KC-135MPRS-2',true)
	MarianasTankersBlue:addTanker("Django-5", TankerTypes.Drogue, 'Template-KC-135MPRS-3',true)
	
	MarianasTankersBlue:addSpec("RIO",TankerRIOSpec)
	MarianasTankersBlue:addSpec('MIRAGE',TankerMirageSpec)
	MarianasTankersBlue:addSpec('LUXOR',TankerMirageSpec)
	
	env.info( "Tanker states: " .. table_out( MarianasTankersBlue:getTankerStates() ))

	db = DATABASE:New()
	PlayerUnits=db:GetPlayerUnits()
	
	local needBoom = false;
	local needDrogue = false;
	
	for PlayerName, PlayerUnit in pairs( PlayerUnits ) do
		self:E('Player ' .. PlayerName .. ' in ' .. PlayerUnit.GetCallsign() .. ' is a ' .. PlayerUnit:GetTypeName())
	end
	
	-- MarianasTankersBlue:startTanker('Django-2','MIRAGE')
	
	if MissionStateAir == MissionStates.Hot then
		MarianasTankersBlue:assignEscort('Django-2', MarianasFightersBlue, {
			callsign = { CALLSIGN.Aircraft.Colt,5 },
			frequency = MissionParameters.FighterOpsFreq,
		})
	end
	
	MarianasTankersBlue:menuInit(MenuTactical['Blue']['Tankers'])
	
end --TankerHandler

if AWACSHandling then
	AWACSSpec = {
		name = 'Guam',
		callsign = { CALLSIGN.AWACS.Wizard,3 },
		frequency = 267.2,
		route =  {
			base_egress = {
							{ rwy = '06', coord = getNavpoint ('OWEND',	coalition.side.BLUE, UTILS.FeetToMeters(6000)) },
						  },
			waythere = {
						  -- getNavpoint('RIO AREN',coalition.side.BLUE,UTILS.FeetToMeters(20000)),
						  -- getNavpoint('RIO ARIP',coalition.side.BLUE,UTILS.FeetToMeters(20000)),
					  },
			racetrack = {
				coord1 = getNavpoint('REWJU',coalition.side.BLUE,UTILS.FeetToMeters(25000)),
				coord2 = getNavpoint('HEXOR',coalition.side.BLUE,UTILS.FeetToMeters(25000)),
				altitude = UTILS.FeetToMeters(25000),
				velocity = UTILS.KnotsToMps(300)
			},
			wayback = {
						  -- getNavpoint('RIO AREX',coalition.side.BLUE,UTILS.FeetToMeters(20000)),
					  },
			base_ingress = {
							{ rwy = '06', coord = getNavpoint ('HILRI',	coalition.side.BLUE, UTILS.FeetToMeters(6000)) },
						  },
			velocity = UTILS.KnotsToKmph(350),
		},	
	}

	MarianasAWACSBlue = AWACSHANDLER:New()

	-- MarianasAWACSBlue:addAWACS('AWACS-1', 'Template-E-3A-1', true )
	MarianasAWACSBlue:addAWACS('AWACS-2', 'TemplateMil-E-3A-1', false, 'Andersen AFB' )
	MarianasAWACSBlue:addSpec('Guam',AWACSSpec)

	MarianasAWACSBlue:startAWACS( 'AWACS-2','Guam',true )

	if MissionStateAir == MissionStates.Hot then
		MarianasAWACSBlue:assignEscort('AWACS-2', MarianasFightersBlue, {
			callsign = { CALLSIGN.Aircraft.Colt,6 },
			frequency = MissionParameters.FighterOpsFreq,
		})
	end
		
	-- MarianasAWACSBlue:menuInit(MenuTactical['Blue']['AWACS'])		
end -- AWACS

if GCICAP then

end -- GCICAP