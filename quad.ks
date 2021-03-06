@LAZYGLOBAL on.
clearvecdraws().
clearscreen.
switch to 0.
global all_libs_loaded is false.
//runpath("lib_quad.ksm").
//runpath("lib_json.ksm").
//runpath("race.ksm").
global mode is m_pos.
global submode is m_pos.
global page is 1.
global focused is true.
backlog:add("Booting up program..").
console_init().
wait 0.

//undock if needed 
set hasMS to false.
if core:element:dockingports:length > 0 { 
	//set localPort to core:element:dockingports[0].
	set localPort to dockSearch(core:part:parent,core:part). //call to recursive search function that returns the cpu vessel's local dockingport
	entry("Found dockingport: " + localPort:name).
	set hasPort to true.
	if localPort:state = "Docked (docker)" or localPort:state = "Docked (dockee)" {
		set mothership to ship.
		set hasMS to true.
		localPort:undock.
		wait 0.
	}
	for ms in localPort:modules {
		local m is localPort:getmodule(ms).
		if m:hasevent("Decouple Node") {
			set mothership to ship.
			m:doevent("Decouple Node").
			set hasMS to true.
		}
		else if m:hasevent("Undock") m:doevent("Undock").
		wait 0.
	}
}
else set hasPort to false.
for curpart in ship:parts {
	for ms in curpart:modules {
		if ms = "ModuleCommand" {
			
			set dronePod to curpart.
			dronePod:controlfrom.
			lock throttle to 0. set ship:control:pilotmainthrottle to 0.
			entry("Probe core: " + dronePod:name).
			wait 0.1.
		}
	}
}

brakes off. ag1 off. ag2 off. ag3 off. ag4 off. ag5 off. ag6 off. ag7 off. ag8 off. ag9 off. ag10 off.
vecs_clear().

// ### engine/servo checks and preparations --------------------------------------------------------------------
// >>
set engDist to 0.
set deploying to false.
set canReverse to false.
list engines in engs.
set engsLexList to list().

local i is 0.
for eng in engs {
	//check for foldable engines, unfold
	local thisEngineCanReverse is false.
	local reverseMod is 0.
	for moduleStr in eng:modules {
		
		
		local mod is eng:getmodule(moduleStr).
		if mod:hasevent("Deploy Propeller") {
			mod:doevent("Deploy Propeller").
			set deploying to true.
		}
		
		if mod:hasevent("Set Reverse Thrust") {
			//set canReverse to true.
			set thisEngineCanReverse to true.
			set reverseMod to mod.
		}
		
	}
	
	local currentLex is lexicon(). //temporary dummy lex
	//assign engines as pitch/roll
	if vdot(facing:starvector,eng:position) < -0.3 {
		set eng_roll_pos to lexicon().
		engsLexList:add(eng_roll_pos).
		eng_roll_pos:add("part",eng).
		if thisEngineCanReverse set currentLex to eng_roll_pos.
	}
	else if vdot(facing:starvector,eng:position) > 0.3 {
		set eng_roll_neg to lexicon().
		engsLexList:add(eng_roll_neg).
		eng_roll_neg:add("part",eng).
		if thisEngineCanReverse set currentLex to eng_roll_neg.
	}
	else if vdot(facing:topvector,eng:position) < -0.3 {
		set eng_pitch_pos to lexicon().
		engsLexList:add(eng_pitch_pos).
		eng_pitch_pos:add("part",eng).
		if thisEngineCanReverse set currentLex to eng_pitch_pos.
	}
	else if vdot(facing:topvector,eng:position) > 0.3 {
		set eng_pitch_neg to lexicon().
		engsLexList:add(eng_pitch_neg).
		eng_pitch_neg:add("part",eng).
		if thisEngineCanReverse set currentLex to eng_pitch_neg.
	}
	
	
	if thisEngineCanReverse {
		currentLex:add("canReverse",true).
		currentLex:add("reverseMod",reverseMod).
		currentLex:add("inReverse",false).
	}
	
	set engDist to engDist + vxcl(facing:vector,eng:position):mag.
}
set engDist to engDist/4.
if deploying { entry("Deploying propellers.."). wait 2. }


local yawRotatrons is list().
set i to 0.
for eng in engs {
	if not(eng:ignition) { eng:activate(). wait 0. }
	vecs_add(eng:position,eng:facing:vector * eng:thrust,red,"",0.2).
	set vecs[i]:show to false.
	set eng:thrustlimit to 100.
	
	set rot to 0.
	
	
	
	//check for yaw servos
	for moduleStr in eng:parent:modules {
		if moduleStr = "MuMechToggle" {
			set rot to eng:parent:getmodule("MuMechToggle").
			if rot:hasfield("Rotation") {
				rot:setfield("Acceleration",25).
				
				for s in addons:ir:allservos {
					if s:part = eng:parent { yawRotatrons:add(s). }
				}
			}
		}
	}
	
	set i to i + 1.
}

setLights(0,1,0).

if yawRotatrons:length = 2 or yawRotatrons:length = 4 {
	entry("Found " + yawRotatrons:length + " servos attached to engines.").
	entry("Yaw control enabled.").
	set yawControl to true.
	
	if ship:partstagged("front"):length > 0 {
		set frontPart to ship:partstagged("front")[0].
		set hasFront to true.
		entry("Face front mode active.").
	}
	else set hasFront to false.

	wait 0.2.
}
else set yawControl to false.
// <<

//### camera stuff ---------------------------------------------------------------------
// >>
set hasGimbal to false.
set hasCam to false.
set cam to ship:partstagged("camera").
set camRotH to ship:partstagged("horizontal").
set camRotV to ship:partstagged("vertical").
if cam:length > 0 and camRotH:length > 0 and camRotV:length > 0 {
	entry("Found camera and gimballing parts, enabling camera controls..").
	wait 0.2.
	set hasGimbal to true.
	set cam to cam[0].
	//if false {
		set hasCam to true.
		set camMod to cam:getmodule("MuMechModuleHullCameraZoom").
	//}
	
	set camRotH to camRotH[0].
	set rotHMod to camRotH:getmodule("MuMechToggle").
	set camRotV to camRotV[0].
	set rotVMod to camRotV:getmodule("MuMechToggle").
	
	rotHMod:setfield("acceleration",100).
	rotVMod:setfield("acceleration",100).
	
	set frontPart to camRotV. 
	set hasFront to true.
}
for servo in addons:ir:allservos {
	if servo:part = camRotH set servoH to servo.
	else if servo:part = camRotV set servoV to servo.
}
wait 0.1.
// <<

// ### Vecdraws -----------------------------------------------------------
// >>
//local markThrustAcc is vecs_add(v(0,0,0),v(0,0,0),red,"Thr").
//local markStar is vecs_add(v(0,0,0),facing:starvector*5,rgba(1,1,0,0.1),"stb",0.2).
//local markTop is vecs_add(v(0,0,0),facing:topvector*5,rgba(1,0.8,0,0.12),"top",0.2).
//local markFwd is vecs_add(v(0,0,0),facing:forevector*5,rgba(1,0.6,0,0.14),"fwd",0.2).
local targetVec is up:forevector.
local targetVecStar is v(0,0,0).
local targetVecTop is v(0,0,0).
local markTar is vecs_add(v(0,0,0),v(0,0,0),cyan,"tgt",0.2).
//local markTarP is vecs_add(v(0,0,0),v(0,0,0),cyan,"TP",0.2).
//local markTarY is vecs_add(v(0,0,0),v(0,0,0),cyan,"TY",0.2).
//local markAcc is vecs_add(v(0,0,0),v(0,0,0),green,"acc",0.2). 
local markHorV is vecs_add(v(0,0,0),v(0,0,0),blue,"HV",0.2).
local markDesired is vecs_add(v(0,0,0),v(0,0,0),yellow,"",0.2).
local markVMod is vecs_add(v(0,0,0),v(0,0,0),green,"",0.2).
local markDestination is vecs_add(v(0,0,0),-up:vector * 3,rgb(1,0.8,0),"",0.2).
local markGate is vecs_add(v(0,0,0),-up:vector * 40,rgb(0,1,0),"",10).

local pList is list(). //terrain prediction vecs
pList:add(0).
pList:add(vecs_add(v(0,0,0),up:vector * 3,rgb(1,0,0.0),"",1.0)).
pList:add(vecs_add(v(0,0,0),up:vector * 3,rgb(1,0.2,0.0),"",1.0)).
pList:add(vecs_add(v(0,0,0),up:vector * 3,rgb(1,0.4,0.0),"",1.0)).
pList:add(vecs_add(v(0,0,0),up:vector * 3,rgb(1,0.6,0.0),"",1.0)).
pList:add(vecs_add(v(0,0,0),up:vector * 3,rgb(1,0.8,0.0),"",1.0)). 

set terMark to false.
set stMark to false.
set thMark to false.
set miscMark to false.

function updateVec {
	parameter targetVec.
	set targetVecStar to vxcl(facing:topvector, targetVec).
	set targetVecTop to vxcl(facing:starvector, targetVec).
	set vecs[markTar]:vec to targetVec*5.
	//set vecs[markTarP]:vec to targetVecTop*5.
	//set vecs[markTarY]:vec to targetVecStar*5.
}
// <<

//### User input function ###
function inputs {
	
	// OPTIONS PAGE ######################################################################################
	if page = 2 { 
		if ag1 {
			ag1 off.
			if showstats set showstats to false.
			else set page to 1.
			
			console_init().
			save_json(). //save settings to json file on local volume
		}
		else if ag2 {
			if forceDock set forceDock to false.
			else set forceDock to true.
			console_init().
		}
		else if ag3 {
			if autoFuel set autoFuel to false.
			else set autoFuel to true.
			console_init().
		}
		else if ag4 {
			if autoLand set autoLand to false.
			else set autoLand to true.
			console_init().
		}
		else if ag5 {
			if agressiveChase set agressiveChase to false.
			else set agressiveChase to true.
			console_init().
		}
		else if ag6 {
			if showstats set showstats to false.
			else set showstats to true.
			console_init().
		}
		
		//ui
		else if ag7 { //terrain prediciton vecs
			toggleTerVec().
			console_init().
		}
		else if ag8 { //steering stuff
			toggleVelVec().
			console_init().
		}
		if ag9 { //thrusters
			toggleThrVec().
			console_init().
		}
		else if ag10 { //misc
			toggleAccVec().
			console_init().
		}
		
		if showstats {
			if ship:control:pilotpitch <> 0 set speedlimitmax to max(5,speedlimitmax - round(ship:control:pilotpitch)).
			//else if ship:control:pilotyaw <> 0 {}.
		}
	}
	else if page = 1 {
		if ag1 { // OPTIONS
			ag1 off.
			set page to 2.
			console_init().
		}
		else if ag10 { // EXIT
			set exit to true.
		}
	}
	
	// MISC CONTROLS ##########################################################################################################
	if not(isDocked) and not(charging) {
		if hasCam {
			if ship:control:pilottop > 0 {
				if lastCamActivation + 0.5 < time:seconds {
					camMod:doevent("Activate Camera").
					set lastCamActivation to time:seconds.
				}
			}
		}
		if submode = m_free { //manual direction
			if ship:control:pilotyaw <> 0 { // S+D
				set countHeading to countHeading + 1.
				if countHeading <= 10 set freeHeading to freeHeading + ship:control:pilotyaw/5.
				else set freeHeading to freeHeading + ship:control:pilotyaw * min(40,countHeading)/10.
				if freeHeading > 360 set freeHeading to freeHeading - 360.
				else if freeHeading < 0 set freeHeading to freeHeading + 360.
			}
			else {
				set countHeading to 0.
			}
			if ship:control:pilotpitch <> 0 { // W+S
				set freeSpeed to freeSpeed - ship:control:pilotpitch * min(5,max(0.5,abs(freeSpeed*0.1))).
				set freeSpeed to min(2000,max(0,freeSpeed)).
			}
		}
		else if mode = m_pos { //position shift
			if ship:control:pilotyaw <> 0 {
				set targetGeoPosP to targetGeoPos:position.
				set countE to min(150,countE + 1).
				//if countE <= 10 set eastShift to -ship:control:pilotyaw * 0.05.
				set eastShift to -ship:control:pilotyaw * 0.01 * (countE^1.5). 
				if mapview set eastShift to eastShift * 100.
				else set eastShift to eastShift * max(1,min(10,targetGeoPosP:mag ^ 0.1)).
				
				set targetGeoPosP to targetGeoPosP + vcrs(north:vector,up:vector):normalized * eastShift.
				set targetGeoPos to body:geopositionof(targetGeoPosP).
			}
			else {
				set countE to 0.
			}
			if ship:control:pilotpitch <> 0 { 
				set targetGeoPosP to targetGeoPos:position.
				set countN to min(150,countN + 1).
				set northShift to -ship:control:pilotpitch * 0.01 * (countN^1.5).
				if mapview set northShift to northShift * 100.
				else set northShift to northShift * max(1,min(10,targetGeoPosP:mag ^ 0.1)).
				
				set targetGeoPosP to targetGeoPosP + vxcl(up:vector,north:vector):normalized * northShift. 
				set targetGeoPos to body:geopositionof(targetGeoPosP).
				
			}
			else {
				set countN to 0.
			}
		}
		else if submode = m_follow {
			if ship:control:pilotpitch <> 0 {
				set followDist to max(0,followDist - ship:control:pilotpitch*0.5).
			}
			
			if ship:control:pilotyaw <> 0 {
				set rotateSpeed to max(0,rotateSpeed + ship:control:pilotyaw*0.5).
			}
		}
		else if mode = m_patrol {
			if ship:control:pilotyaw <> 0 { // A+D
				set patrolRadius to patrolRadius - ship:control:pilotyaw * min(500,max(1,abs(patrolRadius*0.075))).
				set patrolRadius to min(50000, max(5,patrolRadius)).
			}
			if ship:control:pilotpitch <> 0 {
				set freeSpeed to freeSpeed - ship:control:pilotpitch * min(5,max(1,abs(freeSpeed*0.1))).
				set freeSpeed to min(min(speedlimitmax,30*TWR),max(0,freeSpeed)).
			}
		}
		
		if ship:control:pilotfore <> 0 { //target hover height 
			set countH to countH + 1.
			set heightShift to ship:control:pilotfore * (0.05 * min(countH,20)).
			set tHeight to max(0.3,round(tHeight + heightShift,2)).
		}
		else {
			set countH to 0.
		}
		
		if gear {
			gear off.
			//if mode = m_race { nextGate(). entry("Skipped gate.").}
			if hasCamAddon {
				set camMode to camMode + 1.
				if camMode = 3 set camMode to 0.
				set extcam:camerafov to 70.
				set extcam:cameradistance to 10.
			}
		}
		
		// (SUB)MODES ###########################################################################################
		if page = 1 {
			local modeChanged is false.
			if ag2 { //hover
				set mode to m_hover.
				set submode to m_hover.
				set modeChanged to true.
				set vecs[markDestination]:show to false.
				popup("Canceling velocity").
			}
			else if ag3 { //landing
				set mode to m_free.
				set submode to m_free.
				set doLanding to true.
				set freeSpeed to 0.
				set freeHeading to 90.
				set modeChanged to true.
				set targetGeoPos to ship:geoposition.
				set vecs[markDestination]:show to false.
				popup("Landing").
			}
			else if ag4 { //free
				set mode to m_free.
				set submode to m_free.
				set doLanding to false.
				set modeChanged to true.
				set freeSpeed to 0.
				set freeHeading to 90.
				toggleVelVec().
				set vecs[markDestination]:show to false.
				popup("Freeroam mode").
			}
			else if ag5 { //bookedmarked location
				set mode to m_bookmark.
				set submode to m_pos.
				set modeChanged to true.
				if targetString = "POOL" { set targetGeoPos to geo_bookmark("LAUNCHPAD"). set targetString to "LAUNCHPAD". }
				else if targetString = "LAUNCHPAD" { set targetGeoPos to geo_bookmark("VAB"). set targetString to "VAB". }
				else if targetString = "VAB" { set targetGeoPos to geo_bookmark("RUNWAY E"). set targetString to "RUNWAY E". }
				else if targetString = "RUNWAY E" { set targetGeoPos to geo_bookmark("RUNWAY W"). set targetString to "RUNWAY W". }
				else if targetString = "RUNWAY W" { set targetGeoPos to geo_bookmark("ISLAND W"). set targetString to "ISLAND W". }
				else if targetString = "ISLAND W" { set targetGeoPos to geo_bookmark("POOL"). set targetString to "POOL". }
				else { set targetGeoPos to geo_bookmark("LAUNCHPAD"). set targetString to "LAUNCHPAD". }
				set vecs[markDestination]:show to true.
				set destinationLabel to targetString.
				popup("Bookmark location: " + targetString).
				entry("Go to: " + targetString).
			}
			else if ag6 { //local position
				set targetGeoPos to ship:geoposition.
				set targetString to "LOCAL".
				set mode to m_pos.
				set submode to m_pos.
				set modeChanged to true.
				set destinationLabel to targetString.
				set vecs[markDestination]:show to true.
				popup("Location submode").
			}
			else if ag7 { //target vehicles
				set tarVeh to ship.
				if hastarget {
					set tarVeh to target.
				}
				else  {
					if lastTargetCycle + 5 < time:seconds { set targetsInRange to sortTargets(). set target_i to 0. popup(targetsInRange:length). } //update target list
					if targetsInRange:length > 0 {
						local counter is 0.
						local done is false.
						until done or counter = targetsInRange:length {
							if targetsInRange[target_i]:position:mag < 100000 {
								set done to true.
								set tarVeh to targetsInRange[target_i].
							}
							set target_i to target_i + 1.
							set counter to counter + 1.
							if target_i = targetsInRange:length set target_i to 0.
						}
						
					}
					
					set lastTargetCycle to time:seconds.
				}
				if not(tarVeh = ship) {
					set mode to m_follow.
					set submode to m_follow.
					set modeChanged to true.
					if tarVeh:loaded { taggedPart(). }
					else { set tarPart to ship:rootpart. set destinationLabel to tarVeh:name. }
					popup("Following " + tarVeh:name).
					entry("Following " + tarVeh:name).
					//set vecs[markDestination]:show to true.
					
					//set target to tarVeh.
				}

			}
			else if ag8 { //patrol
				set targetGeoPos to ship:geoposition.
				set patrolGeoPos to targetGeoPos.
				set mode to m_patrol.
				set submode to m_pos.
				set freeSpeed to min(speedlimitmax,30*TWR)/2.
				set modeChanged to true.
				set destinationLabel to "Waypoint".
				set vecs[markDestination]:show to true.
			}
			else if ag9 { // RACE ON 
				set modeChanged to true.
				set mode to m_race.
				set submode to m_pos.
				set gravitymod to 0.8. //.90 
				set thrustmod to 0.75. //.50
				setLights(1,0.5,0).
				
				listGates().
				nextGate().
				
				set targetGeoPos to targetGate:geoposition.
				set targetString to targetGate:name.
				set destinationLabel to targetString.
				set vecs[markDestination]:show to false.
				//set vecs[markGate]:show to true.
				
				toggleVelVec(). 
			}
			if modeChanged { //stuff that needs doing after mode change
				if mode <> m_free {
					set doLanding to false.
					if not(stMark) {
						set vecs[markHorV]:show to false.
						set vecs[markDesired]:show to false.
					}
				}
				
				if not(mode = m_race) {
					set gravitymod to 1.3.
					set thrustmod to 0.92.
					set vecs[markGate]:show to false.
					setLights(0,1,0).
					
					set PID_hAcc to pidloop(1.2 * ipuMod,0,0.1 + 1 - weightRatio,0,90).  
				} 
				else set PID_hAcc to pidloop(1.6 * ipuMod,0,0.1,0,90). //2.1  0.4  
				console_init().
			}
		}
	}
	ag1 off. ag2 off. ag3 off. ag4 off. ag5 off. ag6 off. ag7 off. ag8 off. ag9 off. ag10 off. 
}


function taggedPart {
	set tagged to tarVeh:PARTSTAGGED("attach").
	if tagged:length > 0 { 
		set tarPart to tagged[0].
		set destinationLabel to tarVeh:name + " - " + tarPart:name.
	}
	else { set tarPart to tarVeh:rootpart. set destinationLabel to tarVeh:name. }
}

//### Angular momentum / inertia / acceleration stuff ###
// >>

function getInertia { //moment of inertia around an axis
	parameter axis. //vector
	
	local inertia is 0.
	for p in ship:parts {
		set inertia to inertia + p:mass * (vxcl(axis,p:position):mag^2).
	}
	return inertia.
}
set roll_inertia to getInertia(facing:topvector).
set pitch_inertia to getInertia(facing:starvector).

function getTorque {
	parameter p. 
	return vxcl(ship:facing:vector,p:position):mag * (p:maxthrust * vdot(ship:facing:vector,p:facing:vector)).
}
set pitch_torque to (getTorque(eng_pitch_pos["part"]) + getTorque(eng_pitch_neg["part"])) / 2.
set roll_torque to (getTorque(eng_roll_pos["part"]) + getTorque(eng_roll_neg["part"])) / 2.

set pitch_acc to pitch_torque / pitch_inertia.
set roll_acc to roll_torque / roll_inertia.

// <<

//### resource stuff ###
//>>
set drone_resources to core:element:resources.
set fuelType to "ELECTRICCHARGE".
for res in drone_resources {
	if res:name = "LIQUIDFUEL" {
		if res:amount > 1 {
			set fuelType to "LIQUIDFUEL".
			set droneRes to res.
		}
	}
	
} 
if fuelType = "ELECTRICCHARGE" {
	for res in drone_resources {
		if res:name = "ELECTRICCHARGE" set droneRes to res.
	}
}
entry("Fuel type: " + fuelType).
//<<

//### Vars initial ###
//>>
set sampleInterval to 0.2.
set lastTargetCycle to 0.
set doLanding to false.
set rotateSpeed to 0.
list targets in targs.
set target_i to 0.
set tarPart to 0.
set adjustedMass to mass.
set localTWR to (MaxShipThrust() / adjustedMass)/(body:mu / body:position:mag^2).
set TWR to (MaxShipThrust() / adjustedMass)/9.81.
set v_acc_e_old to 0.
set h_acc_e_old to v(0,0,0).
local tOld is time:seconds. local velold is velocity:surface. local dT is 1. local tarVelOld is v(0,0,0).
global tHeight is round(min(50,alt:radar + 4),2).
global th is 0.
local posI is 0.
local accI is 0.
local throtOld is 0.
local lastT is time:seconds - 1000.
local acc_list is list().
set i to 0. until i = 5 { acc_list:add(0). set i to i + 1. }
local posList is list().
set i to 0. until i = 10 { posList:add(ship:geoposition:terrainheight). set i to i + 1. }
lock throttle to th.
global thrust_toggle is true. 
set targetGeoPos to ship:geoposition.
set targetString to "LOCAL".
set massOffset to 0.
set charging to false.
set speedlimitmax to 200.
set consoleTimer to time:seconds.
set slowTimer to time:seconds.
set forceUpdate to true.
set desiredHV to v(0,0,0).
set v_acc_dif_average to 0.
set followDist to 0.
set forceDock to false.
if hasPort set autoFuel to true.
else set autoFuel to false.
set autoLand to true.
set patrolRadius to 10.
set massOffset to 0.
set engineCheck to 0.
set stVec to v(0,0,0).
set agressiveChase to false.
set focusPos to facing:topvector * 10.
set focusCamPos to facing:topvector * 1.
set vMod to 0.
set fuel to 100.
set gravitymod to 1.0.
set thrustmod to 1.0.
set h_vel to v(0,0,0).
set isDocked to false.
set hasWinch to false.
set ipuMod to sqrt(config:ipu/2000). //used to slow things down if low IPU setting 
set camMode to 0.
set destinationLabel to "".
set lastCamActivation to 0.
set showstats to false.


if hasMS {
	set mode to m_follow.
	set submode to m_follow.
	set followDist to 10.
	set tarVeh to mothership. 
	set tarPart to tarVeh:rootpart.
}
//<<

//### PID controllers ###
//>>
if canReverse {
	global PID_pitch is P_init(100.0,-200,200). 
	global PID_roll is P_init(100.0,-200,200).  
}
else {
	global PID_pitch is pidloop(75, 0, 2, -100, 100). //(75, 0, 2, -100, 100).    
	//global PID_pitch is P_init(50.0,-100,100). //P_init(50.0,-100,100).       
	global PID_roll is pidloop(75, 0, 2, -100, 100). //(75, 0, 2, -100, 100).    
	//global PID_roll is P_init(50.0,-100,100). //P_init(50.0,-100,100).  
}

global PID_vAcc is pidloop(4,0,0.5,-90,90). //pidloop(8,0,0.5,-90,90).   
set PID_vAcc:setpoint to 0.

//global PID_hAcc is pidloop(2.1,0,0.1,0,90).   //(3,0,0.3,0,90).     
global PID_hAcc is pidloop(1.4 * ipuMod,0,0.1,0,90). 

set PID_hAcc:setpoint to 0.
//<<

//runpath("quad_loop.ksm").
local filename is "0:vessels/" + ship:name + ".json".
if exists(filename) load_json(). //load saved settings on the local drive, if any.  
set all_libs_loaded to true.
backlog:add("All systems ready. Initializing controllers.").
console_init().

//main controller loop
set exit to false.
set lockToggle to false.
until exit {
	flightcontroller().
	if lockToggle { set lockToggle to false. lock throttle to th. }
}


ag1 off.
set mode to 10.
set submode to 10.

console_init().
vecs_clear().
clearvecdraws().
for eng in engs {
	for moduleStr in eng:modules {
		local mod is eng:getmodule(moduleStr).
		if mod:hasevent("Retract Propeller") {
			mod:doevent("Retract Propeller").
		}
	}
	eng:shutdown().
}
if hasGimbal { 
	rotHMod:doaction("move +",false). rotHMod:doaction("move -",false). 
	rotVMod:doaction("move +",false). rotVMod:doaction("move -",false). 
}
if yawControl {
	for s in yawRotatrons {
		s:moveto(0,5).
	}
}
set th to throt.
unlock throttle.
set ship:control:pilotmainthrottle to throt.
entry("Program ended.").
setLights(1,0.1,0.1).
wait 1.
reboot.