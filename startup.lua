
	--[[ startup.lua: version 2.1.2d 2009/01/22
		 modded by ATAG - atagster [at] gmail [dot] com
	   
	   2.1.2d:
		  fixed: error on missing libsimplepickle.lua - reported by [NH]Nando
		  
	   2.1.2c:
		  first public release
	   
	NMDC Listeners (events):
		  chat	  = normal chat message (you won't get your own messages)
				  function chat( hub, user, "message" )
				  DISCARDABLE:
					* return non-nil to hide the msg from BCDC++
		  unknownchat   = incoming messages displayed without any nick
				  function unknownchat( hub, "message" )
				  DISCARDABLE
		  ownChat	  = normal chat message from yourself (incoming from the hub)
				  function ownChat( hub, "message" )
				  DISCARDABLE
		  pm	  = normal pm message
				  function pm( hub, user, "message" )
				  DISCARDABLE
		  hubPm	  = pm message with a different prefix than the nick in the From field
				  function hubPm( hub, user, "message which may include a <nickname>" )
				  DISCARDABLE
		  userConnected	= a user connected (or rather.. the first getUser call was made)
				  function userConnected( hub, user )
		  userMyInfo   = a myinfo message from a user, use this as "userConnected"
				  function userMyInfo( hub, user, "$MyINFO $ALL ... 1234$|" )
				  DISCARDABLE
		  userQuit   = a quit message from a user
				  function userQuit( hub, nick )
				  DISCARDABLE
		  raw	  = a full message
				  function raw( hub, "line" )
				  DISCARDABLE (message won't get parsed.. no other listeners will be called)
	ADC Listeners:
		  adcChat	  = normal chat message (you won't get your own messages).
				  function adcChat( hub, user, "message", me_msg )
				  DISCARDABLE:
					* return non-nil to hide the msg from BCDC++,
					* me_msg is true if a /me-style message is sent
		  adcOwnChat   = normal chat message from yourself (incoming from the hub)
				  function adcOwnChat( hub, "message", me_msg )
				  DISCARDABLE
		  adcPm	  = normal pm message
				  function adcPm( hub, user, "message", me_msg )
				  DISCARDABLE
		  groupPm	  = pm message with a different reply-sid than the one who talks (probably chatroom or bot)
				  function groupPm( hub, user, "message", reply_sid, me_msg )
				  DISCARDABLE
		  userInf	  = an INF message from a user
				  function userInf( hub, user, flags )
			   flags is a table where all named flags are stored (ie: flags["NI"], flags["I4"], ...)
				  DISCARDABLE
		  adcUserCon	= a user connected (or rather.. the first getUser call was made)
				  function adcUserCon( hub, user )
		  adcUserQui   = a quit message from a user
				  function adcUserQui( hub, sid, flags )
			   flags is a table where all named flags are stored (ie: flags["ID"], flags["MS"], ...)
	Common Listeners:
		  ownChatOut   = normal chat message from yourself (outgoing to the hub)
				  function ownChatOut( hub, "message" )
				  DISCARDABLE
		  connected   = connecting to a hub (many functions may be unavailable (return nil))
				  function connected( hub )
		  disconnected	= disconnected from a hub
				  function disconnected( hub )
		  timer	  = called every second (if DC():RunTimer(1) is called), use
				  dcpp:getHubs()[k]:getAddress() or :getUrl() to select a hub
				  function timer()
		  clientIn   = peer to peer line oriented transfer control input, userp is a pointer
				  (lightuserdata)
				  function clientIn( userp, "line" )
				  DISCARDABLE (returning non-nil kills the connection)
		  clientOut   = peer to peer line oriented transfer control output, userp is a pointer
				  (lightuserdata)
				  function clientOut( userp, "line" )
				  DISCARDABLE (returning non-nil kills the connection)

	Example listener:
	   function chat( hub, user, text )
		  local s = string.lower( text )
		  if string.find( s, "[^a-z]bier+[^a-z]" ) or string.find( s, "[^a-z]biertje[^a-z]" ) then
			 hub:sendChat( "bier? ja lekker! :)" )
		  end
	   end

	Example Usercommand:
	   function connected( hub )
		  if ( hub:getProtocol() ~= "adc" ) then
			 hub:injectChat( '$UserCommand 1 2 Ignore$%[lua:scriptMan:Run("AddUser","!%!{userNI!}")]||' )
			 hub:injectChat( '$UserCommand 1 2 Unignore$%[lua:scriptMan:Run("RmUser","!%!{userNI!}")]||' )
		  end
	   end
	]]							  

	DC():PrintDebug( "  ** Started startup.lua **" )

	--/////////////////////////////////////
	--// Helper functions
	--/////////////////////////////////////

	if not dcu then
	   dcu = {}
	end

	dcu.NmdcEscape = function(this, msg )
	   msg = msg:gsub( "[%$|]", function(s) return "&#"..string.byte(s)..";" end )
	   return msg
	end

	dcu.AdcEscape = function(this, msg, inverse)
	   msg = string.gsub(msg, "\r", "")
	   local ret = ""
	   if inverse then
		  local replacetable = {
			 ["\\\\"] = [[\]],
			 ["\\s"] = [[ ]],
			 ["\\n"] = "\n"
		  }
		  local skip = false
		  for k = 1, #msg do
			 if skip then
				skip = false
			 else
				local c = msg:sub( k, k + 1)
				if replacetable[c] then
				   ret = ret .. replacetable[c]
				   skip = true
				else
				   ret = ret .. c:sub(1, 1)
				end
			 end
		  end
	   else
		  local replacetable = {
			 ["\\"] = [[\\]],
			 [" "] = [[\s]],
			 ["\n"] = [[\n]]
		  }
		  for k = 1, #msg do
			 local c = msg:sub( k, k)
			 if replacetable[c] then
				ret = ret .. replacetable[c]
			 else
				ret = ret .. c
			 end
		  end
	   end
	   return ret
	end

	--// Checks if the given decimal number has the 2^exp bit set
	dcu.BBit = function(this, num, exp)
	   if string.find( math.floor(num / 2^exp), "[13579]$") then
		  return true
	   end
	   return false
	end

	--/////////////////////////////////////
	--// Hub manager
	--/////////////////////////////////////

	if not dcpp or dcpp._init_me_anyway == true then
	   dcpp = {}
	   dcpp._hubs = {}
	   dcpp._listeners = { id = {} }
	end

	dcpp.addHub = function( this, hub, isitadc )
	   if not this._hubs[hub] then
		  -- DC():PrintDebug( "Hub added (id = "..tostring( hub )..")" )
		  if isitadc then
			 this._hubs[hub] = createAdcHub( hub )
			 DC():PrintDebug( "ADC hub added (id = " .. tostring( hub ) ..")" )
		  else
			 this._hubs[hub] = createNmdcHub( hub )
		  end
		  local h = dcpp:getHub( hub )
		  scriptMan:Run( "connected", h )
		  
		  return this._hubs[hub]
	   else
		  --DC():PrintDebug( "Tried to add existing hub on: "..this._hubs[hub]:getHubName()..
		  --				  " (id = "..tostring( hub )..")" )
		  return nil
	   end
	end

	dcpp.getHub = function( this, hub )
	   if this._hubs[hub] then
		  return this._hubs[hub]
	   else
		  --DC():PrintDebug( "Tried to fetch an unknown hub (id = "..tostring( hub )..")" )
		  return this:addHub( hub ):setPartial() -- tell the object that we missed the logon
	   end
	end

	dcpp.getHubs = function( this )
	   return this._hubs
	end

	dcpp.hasHub = function( this, hub )
	   if this._hubs[hub] then
		  return 1
	   else
		  return nil
	   end
	end

	dcpp.findHub = function( this, url )
	   for k, h in pairs(this._hubs) do
		  if h:getUrl() == url then
			 return h
		  end
	   end
	   return false
	end


	dcpp.removeHub = function( this, hub )
	   if this._hubs[hub] then
		  --DC():PrintDebug( "Hub removed: "..this._hubs[hub]:getHubName().." (id = "..tostring( hub )..")" )
		  local h = dcpp:getHub( hub )
		  scriptMan:Run( "disconnected", h )

		  this._hubs[hub]:destroy()
		  this._hubs[hub] = nil
	   else
		  --DC():PrintDebug( "Tried to remove non-existent hub (id = "..tostring( hub )..")" )
	   end	  
	end

	dcpp.listHubs = function( this )
	   DC():PrintDebug( "** Listing hubs **" )
	   for k,v in pairs(this._hubs) do
		  DC():PrintDebug( tostring( k ).." ("..v:getHubName()..")" )
	   end
	end

	dcpp.setListener = function( this, ltype, id, func  )
	   -- load func into the caller's environment
	   getfenv(2)[ltype] = func
	end

	dcpp.getListeners = function( this, ltype )
	-- only for backward compatibility :)
	end

	--/////////////////////////////////////
	--// Hub object
	--/////////////////////////////////////

	function createAdcHub( hubid )
	   local hub = {}
	   
	   hub._id = hubid
	   hub._mySID = nil
	   hub._myNick = nil
	   hub._myCID = nil
	   hub._nick = nil
	   hub._description = nil
	   hub._users = {}
	   hub._uptime = os.time()
	   
	   hub.getId = function( this )
		  return this._id
	   end
	   
	   hub.getUptime = function( this )
		  return ( os.time() - hub._uptime ) / 60
	   end
	   
	   hub.getProtocol = function( this )
		  return "adc"
	   end
	   
	   hub.getAddress = function( this )
		  return DC():GetHubIpPort( this._id )
	   end
	   
	   hub.getHubName = function( this )
		  --// TODO: Shall we return with NI or DE? or both?
		  --//	   For now just returning the nick with the url
		  if this._nick then
			 return this._nick  .. " ("..this:getUrl()..")"
		  else
			 return this:getUrl()
		  end
	   end
	   
	   hub.getUrl = function( this )
		  return DC():GetHubUrl( this._id )
	   end
	   
	   hub.getOwnNick = function( this )
		  return this._myNick
	   end

	   hub.setOwnNick = function( this, newnick )
		  this._myNick = newnick
		  DC():PrintDebug( " [STATUS] Own nick set: " .. newnick )
	   end
	   
	   hub.getOwnSid = function( this )
		  if this._mySID then
			 return this._mySID
		  end
		  DC():PrintDebug( " [" .. this:getUrl() .."] Own SID not set, your scripts are failing. Reconnect please." )
	   end
	   
	   hub.getOwnCid = function( this )
		  if this._myCID then
			 return this._myCID
		  end
		  DC():PrintDebug( " [" .. this:getUrl() .."] Own CID not set, your scripts are failing. Reconnect please." )
	   end
	   
	   hub.getUser = function( this, sid, inf )
		  local newuser = false
		  if sid == "HUB9" and inf then
			 -- INF is about the hub itself
			 local params = {}
			 string.gsub(inf, "([^ ]+)", function(s) table.insert(params, s) end )
			 for k in pairs(params) do
				local name = string.sub( params[k], 1, 2 )
				if name == "NI" then
				   local NI = dcu:AdcEscape(string.sub( params[k], 3), true)
				   this._nick = NI
				   DC():PrintDebug(" [STATUS] HUB nick set: " .. NI )
				elseif name == "DE" then
				   local DE = dcu:AdcEscape(string.sub( params[k], 3), true)
				   this._description = DE
				   DC():PrintDebug(" [STATUS] HUB description set: " .. DE )
				end
			 end
		  end
		  
		  if not this._users[sid] then
			 this._users[sid] = createAdcUser( this, sid )
			 newuser = true
			 if this:getUptime() >= 2 then -- start sending messages AFTER logon
						 scriptMan:Run( "adcUserCon", this, this._users[sid] )
			 end
		  end
		  local r = this._users[sid]
		  if inf then
			 local params = {}
			 string.gsub(inf, "([^ ]+)", function(s) table.insert(params, s) end )
			 for k in pairs(params) do
				local name = string.sub( params[k], 1, 2 )
				if name == "ID" then
				   local ID = string.sub( params[k], 3)
				   r:setCid(ID)
				   if sid == this._mySID then
					  this._myCID = ID
					  DC():PrintDebug(" [STATUS] Own CID set: " .. ID )
				   end
				elseif name == "CT" then
				   local CT = string.sub( params[k], 3)
				   r:processCt(CT)
				elseif name == "I4" then
				   local I4 = string.sub( params[k], 3)
				   r:setIp(I4)
				elseif name == "NI" then
				   local NI = dcu:AdcEscape(string.sub( params[k], 3), true)
				   if not newuser then
					  local oldNI = r:getNick()
					  r:setNick(NI)				  
					  this:addLine( oldNI .. " is now known as " .. NI )
				   else
					  r:setNick(NI)
				   end
				   if sid == this._mySID then
					  this:setOwnNick(NI)
				   end
				end
			 end
		  end
		  return r
	   end
	   
	   hub.removeUser = function( this, sid )
		  this._users[sid] = nil
	   end
	   
	   hub.isOp = function( this, sid )
		  if this._users[sid] then
			 return this._users[sid]._op
		  end
		  return nil
	   end
	   
	   hub.getSidbyNick = function( this, nick )
		  for k in pairs(this._users) do
			 if this._users[k]._nick == nick then
				return k
			 end
		  end
		  return nil
	   end
	   
	   hub.getSidbyCid = function( this, cid )
		  for k in pairs(this._users) do
			 if this._users[k]._cid == cid then
				return k
			 end
		  end
		  return nil
	   end
	   
	   hub.sendChat = function( this, msg )
		  local ownSid = this:getOwnSid()
		  msg = dcu:AdcEscape( msg )
		  DC():SendHubMessage( this:getId(), "BMSG " .. ownSid .. " " .. msg .. "\n" )
	   end
	   
	   hub.injectChat = function( this, msg )
			 DC():PrintDebug(" [WARNING] Your scripts trying to use hub:injectChat on ADC hub. Please use hub:injectMessage() to inject an ADC message or hub:addLine() to inject a chat line." )
			 -- hub:injectMessage( msg )
	   end
	   
	   hub.injectMessage = function( this, msg )
		  DC():InjectHubMessageADC( this:getId(), msg )
	   end
	   
	   hub.addLine = function( this, msg, fmt )
		  --// TODO: need a function which adds a chat line without nick
		  msg = dcu:AdcEscape( msg )
		  DC():InjectHubMessageADC( this:getId(), "ISTA 000 " .. msg )
	   end
	   
	   hub.sendPrivMsgTo = function( this, victimSid, msg_unescaped, hideFromSelf )
		  local ownSid = this:getOwnSid()
		  local msg = dcu:AdcEscape( msg_unescaped )
		  if ownSid then
			 if hideFromSelf then
				DC():SendHubMessage( this:getId(), "DMSG ".. ownSid .. " " .. victimSid .." " .. msg .. " PM" .. ownSid .."\n" )
			 else
				DC():SendHubMessage( this:getId(), "EMSG ".. ownSid .. " " .. victimSid .." " .. msg .. " PM" .. ownSid .."\n" )
			 end
		  end   
	   end

	   hub.injectPrivMsg = function( this, victimSid, fromSid, msg )
		  DC():InjectHubMessageADC( this:getId(), "DMSG " .. fromSid .." ".. victimSid .." ".. msg .. " PM" .. victimSid .. "\n" )
	   end
	   
	   hub.findUsers = function( this, nick, notag )
		  -- you get a possibly empty table of users
		  if not notag then
			 return { this._users[this:getSidbyNick(nick)] }
		  else
			 local list = {}
			 for k in pairs(this._users) do
				local ret,c,n = string.find( this._users[k]._nick, "^%[.*%](.-)$" )
				if n == nick then
				   table.insert( list, this._users[k] )
				end
			 end
			 return list
		  end
	   end

	   hub.destroy = function( this )
	   end
	   
	   --// events
	   
	   hub.onChatMessage = function( this, user, text, me_msg )
		  return scriptMan:Run( "adcChat", this, user, text, me_msg )
	   end
	   
	   hub.onChatFromSelf = function( this, text, me_msg )
		  return scriptMan:Run( "adcOwnChat", this, text, me_msg )
	   end   
	   
	   hub.onINF = function( this, user, flags )
		  return scriptMan:Run( "userInf", this, user, flags )
	   end
	   
	   hub.onQUI = function( this, sid, flags )
		  scriptMan:Run( "adcUserQui", this, sid, flags )
	   end
	   
	   hub.onPrivateMessage = function( this, user, targetSid, replySid, text, me_msg )
		  if targetSid == this:getOwnSid() then
			 if user:getSid() == replySid then
				return scriptMan:Run( "adcPm", this, user, text, me_msg )
			 else
				return scriptMan:Run( "groupPm", this, user, replySid, text, me_msg )
			 end   
		  end
	   end
	   
	   hub.attention = function( this )
		  DC():HubWindowAttention( this:getId() )
	   end

	   return hub
	end

	function createNmdcHub( hubid )
	   local hub = {}

	   hub._id = hubid
	   hub._users = {}
	   hub._name = nil
	   hub._myNick = nil
	   hub._partial = nil
	   hub._gotOpList = nil
	   hub._uptime = os.time()
	   hub._hubUC = {}
	   hub._customUC = {}

	   hub.getId = function( this )
		  return this._id
	   end
	   
	   hub.getProtocol = function( this )
		  return "nmdc"
	   end

	   hub.getUptime = function( this )
		  return ( os.time() - hub._uptime ) / 60
	   end

	   hub.getUser = function( this, nick, op )
		  if not this._users[nick] then
			 this._users[nick] = createNmdcUser( this, nick )
			 if this:getUptime() >= 2 then -- start sending messages AFTER logon
						 scriptMan:Run( "userConnected", this, this._users[nick] )
			 end
		  end
		  local r = this._users[nick]
		  if op then
			 r:setOp( true )
			 r:setClass( "op" )
			 this._gotOpList = 1
		  end
		  return r
	   end

	   hub.findUsers = function( this, nick, notag )
		  -- you get a possibly empty table of users
		  if not notag then
			 return { this._users[nick] }
		  else
			 local list = {}
			 for k,v in pairs(this._users) do
				local ret,c,n = string.find( k, "^%[.*%](.-)$" )
				if n == nick then
				   table.insert( list, v )
				end
			 end
			 return list
		  end
	   end

	   hub.gotOpList = function( this )
		  return this._gotOpList
	   end

	   hub.isOp = function( this, nick )
		  if this._users[nick] and this._users[nick]:isOp() then
			 return 1
		  end
	   end

	   hub.removeUser = function( this, nick )
		  this._users[nick] = nil
	   end

	   hub.setPartial = function( this )
		  --// we're most likely missing logon info
		  this._partial = 1
	   end

	   hub.isPartial = function( this )
		  --// are we missing logon info?
		  return this._partial
	   end   

	   hub.setHubName = function( this, msg )
		  this._name = msg
	   end

	   hub.getAddress = function( this )
		  return DC():GetHubIpPort( this._id )
	   end
	   
	   hub.getUrl = function( this )
		  return DC():GetHubUrl( this._id )
	   end

	   hub.getHubName = function( this )
		  if this._name then
			 return this._name.." ("..this:getUrl()..")"
		  else
			 return this:getUrl()
		  end
	   end

	   hub.setOwnNick = function( this, nick )
		  this._myNick = nick
	   end

	   hub.getOwnNick = function( this )
		  if not this:isPartial() then
			 return this._myNick
		  end
		  DC():PrintDebug( "[" .. this:getUrl() .."] Your scripts are failing. "..
				   "Own nick not set. Reconnect please." )
	   end

	   hub.destroy = function( this )
	   end

	   hub.sendChat = function( this, msg )
		  local ownNick = this:getOwnNick()
		  msg = dcu:NmdcEscape( msg )
		  if ownNick then
			 DC():SendHubMessage( this:getId(), "<"..ownNick.."> "..msg.."|" )
		  end
	   end

	   hub.injectChat = function( this, msg, skipusercommand )
			 DC():InjectHubMessage( this:getId(), msg )
			 -- test if it's usercommand
			 if ( string.sub(msg, 1, 13) == "$UserCommand " ) and (not skipusercommand) then
				this:customUC( msg )
			 end
	   end
	   
	   hub.addLine = function( this, msg, fmt )
		  if not fmt then
			 msg = "*** " .. msg
		  end
		  DC():InjectHubMessage( this:getId(), msg )
	   end

	   hub.sendPrivMsgTo = function( this, victim, msg, hideFromSelf )
		  local ownNick = this._myNick
		  msg = dcu:NmdcEscape( msg )
		  if ownNick then
			 DC():SendHubMessage( this:getId(), "$To: "..victim.." From: "..ownNick.." $"..msg.."|" )
			 if not hideFromSelf then
				this:injectPrivMsg( victim, ownNick, msg )
			 end
		  end   
	   end

	   hub.injectPrivMsg = function( this, from, to, msg )
			 DC():InjectHubMessage( this:getId(), "$To: "..to.." From: "..from.." $"..msg )
	   end

	   hub.injectPrivMsgFmt = function( this, from, to, msg )
		  this:injectPrivMsg( from, to, "<"..from.."> "..msg )
	   end

	   hub.attention = function( this )
		  DC():HubWindowAttention( this:getId() )
	   end

	   --///////////////////////////
	   --// $UserCommand manager
	   --///////////////////////////
	   -- Todo: context sensitivitiy at UC 255

	   hub.hubUC = function( this, msg )
		  local uc_type = string.gsub( msg, "%$UserCommand (%d+) .+", "%1")
		  -- DC():PrintDebug( "UserCommand " .. uc_type .. " arrived from " .. this:getHubName() .. " : " .. msg)
		  if uc_type == "255" then
			 -- clear user command list and resend our own commands to prevent it from disappearing
			 -- DC():PrintDebug( "Clearing Hub UC list.." )
			 this:clearHubUCList()
			 -- DC():PrintDebug( "Resending Custom commands.." )
			 this:reSendCustomUC()
		  else
			 -- add usercommands to UClist
			 -- DC():PrintDebug( "Adding hubUC.." )
			 this:addHubUC( msg )
		  end

		  return true
	   end

	   hub.customUC = function ( this, msg )
		  local uc_type = string.gsub( msg, "%$UserCommand (%d+) .+", "%1")
		  -- DC():PrintDebug( "UserCommand " .. uc_type .. " arrived from a script: " .. msg)
		  if uc_type == "255" then
			 -- clear own user command list and resend hub usercommands to prevent it from disappearing
			 this:clearCustomUCList()
			 this:reSendHubUC()
		  else
			 -- add usercommands to UClist
			 this:addCustomUC( msg )
		  end
		  return true
	   end

	   hub.addHubUC = function( this, msg )
		  table.insert( this._hubUC, msg )
		  return true
	   end

	   hub.addCustomUC = function( this, msg)
		  table.insert( this._customUC, msg )
		  return true
	   end

	   hub.clearHubUCList = function( this )
		  this._hubUC = {}
		  return true
	   end

	   hub.clearCustomUCList = function( this )
		  this._customUC = {}
		  return true
	   end
	   
	   hub.reSendCustomUC = function( this )
		  for k in pairs(this._customUC) do
			 hub:injectChat( this._customUC[k] , true )
			 -- DC():PrintDebug("Sending custom uc from stored table: " .. this._customUC[k] )
		  end
		  return true
	   end

	   hub.reSendHubUC = function( this )
		  for k in pairs(this._hubUC) do
			 hub:injectChat( this._hubUC[k] , true)
		  end
		  return true
	   end

	   --////////////////
	   --// Own functions
	   --////////////////
	   
	   hub.onRaw = function( this, msg )
		  return scriptMan:Run( "raw", this, msg )
	   end

	   hub.onSearch = function( this, msg )
		  --DC():PrintDebug( this:getHubName().."> "..msg )
	   end
	   
	   hub.onHello = function( this, user, msg )
	   end
	   
	   hub.onMyInfo = function( this, user, msg )
		  return scriptMan:Run( "userMyInfo", this, user, msg )
	   end
	   
	   hub.onQuit = function( this, nick, msg )
		  return scriptMan:Run( "userQuit", this, nick )
	   end
	   
	   hub.onHubName = function( this, hubname, msg )
	   end
	   
	   hub.onPrivateMessage = function( this, user, to, prefix, text, full )
		  if to == this:getOwnNick() then
			 if prefix == "<"..user:getNick().."> " then
				return scriptMan:Run( "pm", this, user, text )
			 else
				return scriptMan:Run( "hubPm", this, user, text )
			 end   
		  end
	   end

	   hub.onChatMessage = function( this, user, text )
		  return scriptMan:Run( "chat", this, user, text ) or scriptMan:Run( "ChatArrival", this, user, text )
	   end
	   
	   hub.onUnknownChatMessage = function( this, text )
		  return scriptMan:Run( "unknownchat", this, text )
	   end
	   
	   hub.onChatFromSelf = function( this, text )
		  return scriptMan:Run( "ownChat", this, text )
	   end   

	   return hub
	end



	--/////////////////////////////////////
	--// User object
	--/////////////////////////////////////

	function createNmdcUser( hub, nick )
	   local user = {}

	   user._hub = hub
	   user._nick = nick
	   user._op = false
	   user._ip = ""
	   user._class = "user"
	   user._handled_messages = {} -- flood protection
	   setmetatable( user, {__index = {
		  sNick = user._nick,
		  bOperator = function() return user._op end,
		  sIP = function() return user._ip end,
		  }
	   })
	   user.getProtocol = function( this )
		  return "nmdc"
	   end

	   user.setOp = function( this, op )
		  this._op = op
		  return this
	   end

	   user.isOp = function( this )
		  return this._op
	   end
	   
	   user.setClass = function( this, param )
		  this._class = param
		  return this
	   end
	   
	   user.getClass = function( this )
		  return this._class
	   end

	   user.setIp = function( this, ip )
		  this._ip = ip
	   end

	   user.getIp = function( this )
		  return this._ip
	   end
	   
	   user.getNick = function( this )
		  return this._nick
	   end

	   user.sendPrivMsgFmt = function( this, msg, hideFromSelf )
		  local ownNick = this._hub:getOwnNick()
		  if ownNick then
			 this._hub:sendPrivMsgTo( this._nick, "<"..ownNick.."> "..msg, hideFromSelf )
		  end
		  return this
	   end

	   user.setMsgHandled = function( this, which )
		  this._handled_messages[which] = 1
		  return this
	   end

	   user.msgHandled = function( this, which )
		  return this._handled_messages[which]
	   end

	   return user
	end

	function createAdcUser( hub, sid )
	   local user = {}
	   
	   user._sid = sid
	   user._cid = ""
	   user._hub = hub
	   user._nick = ""
	   user._op = false
	   user._bot = false
	   user._registered = false
	   user._hubitself = false
	   user._class = "user"
	   user._ip = ""
	   user._handled_messages = {} -- flood protection
	   
	   user.getProtocol = function( this )
		  return "adc"
	   end

	   user.setOp = function( this, op )
		  this._op = op
		  return this
	   end

	   user.isOp = function( this )
		  return this._op
	   end
	   
	   user.processCt = function( this, param )
		  local num = tonumber(param)
		  if num then
			 
			 --// Init
			 this._class = "user"
			 
			 --// 2^0: bot
			 if dcu:BBit(num, 0) then
				this:setBot(true)
				DC():PrintDebug("BOT set: " .. this:getSid())
			 else
				this:setBot(false)
			 end
			 
			 --// 2^1: registered
			 if dcu:BBit(num, 1) then
				this:setReg(true)
			 else
				this:setReg(false)
			 end
			 
			 --// 2^2, 2^3, 2^4: some type of operator
			 if dcu:BBit(num, 2) or dcu:BBit(num, 3) or dcu:BBit(num, 4) then
				this:setOp(true)
				if dcu:BBit(num, 2) then
				   this._class = "op"
				elseif dcu:BBit(num, 3) then
				   this._class = "su"
				else
				   this._class = "owner"
				end
			 else
				this:setOp(false)
			 end
			 
			 if dcu:BBit(num, 5) then
				this:setHub(true)
				this._class = "hub"
			 else
				this:setHub(false)
			 end
			 
		  else
			 --// Empty CT field should cause all properties gone
			 this:setBot(false)
			 this:setOp(false)
			 this:setReg(false)
			 this:setHub(false)
			 this._class = "user"
		  end
		  
		  DC():PrintDebug("CLASS: " .. this._class .. " [" .. tostring(param) .. "]" )
		  return this
	   end
	   
	   --// Possible values: "user", "op", "su", "owner", "hub"
	   user.getClass = function( this )
		  return this._class
	   end
	   
	   user.setBot = function(this, bot)
		  this._bot = bot
		  return this
	   end
	   
	   user.isBot = function(this)
		  return this._bot
	   end
	   
	   user.setReg = function(this, registered)
		  this._registered = registered
		  return this
	   end
	   
	   user.isReg = function(this)
		  return this._registered
	   end
	   
	   user.setHub = function(this, hubitself)
		  this._hubitself = hubitself
		  return this
	   end
	   
	   user.isHub = function(this)
		  return this._hubitself
	   end

	   user.setIp = function( this, ip )
		  this._ip = ip
	   end

	   user.getIp = function( this )
		  return this._ip
	   end
	   
	   user.setCid = function( this, cid )
		  this._cid = cid
	   end
	   
	   user.getCid = function( this )
		  return this._cid
	   end
	   
	   user.getSid = function( this )
		  return this._sid
	   end
	   
	   user.getNick = function( this )
		  return this._nick
	   end
	   
	   user.setNick = function( this, nick )
		  this._nick = nick
		  -- DC():PrintDebug("Nick set: " .. nick )
	   end
	   
	   user.sendPrivMsg = function( this, msg, hideFromSelf )
		  local victimSid = this:getSid()
		  this._hub:sendPrivMsgTo( victimSid, msg, hideFromSelf )
		  return this
	   end
	   
	   -- Backward compatibility
	   user.sendPrivMsgFmt = user.sendPrivMsg

	   user.setMsgHandled = function( this, which )
		  this._handled_messages[which] = 1
		  return this
	   end

	   user.msgHandled = function( this, which )
		  return this._handled_messages[which]
	   end
	   
	   return user
	end


	--/////////////////////////////////////
	--// Handlers
	--/////////////////////////////////////

	nmdch = {}

	function nmdch.DataArrival( hub, msg )
	   local h = dcpp:getHub( hub )

	   --// If we missed the logon, we really have no business here,
	   --// modify only if you really have to.
	   --// Note that if not h:isPartial and not h:getOwnNick(),
	   --// functions requiring an ownNick will silently fail.
	   if h:isPartial() then
		  return
	   end

	   --// raw/unparsed message
	   if h:onRaw( msg ) then
		  return scriptMan:Run( "UnknownArrival", msg )
	   end

	   --// parse message and fire appropriate
	   local ret,c,cmd = string.find( msg, "^%$([^ ]+)" )
	   if ret then
		  if cmd == "Search" then
			 return h:onSearch( msg )
		  elseif cmd == "Hello" then
			 local nick = string.sub( msg, 8 )
			 if not h:getOwnNick() then
				h:setOwnNick( nick ) -- don't trust this nick on h:isPartial()
			 end
			 return h:onHello( h:getUser( nick ), msg )
		  elseif cmd == "MyINFO" and string.sub( msg, 1, 13 ) == "$MyINFO $ALL " then
			 local nick = string.sub( msg, 14, string.find( msg, " ", 14, 1 ) - 1 )
			 return h:onMyInfo( h:getUser( nick ), msg )
		  elseif cmd == "Quit" then
			 local nick = string.sub( msg, 7 )
			 h:removeUser( nick )
			 return h:onQuit( nick, msg )
		  elseif cmd == "HubName" then
			 local hubname = string.sub( msg, 10 )
			 h:setHubName( hubname )
			 return h:onHubName( hubname, msg )
		  elseif cmd == "OpList" then
			 for nick in string.gfind( string.sub( msg, 9 ), "[^$]+") do
				h:getUser( nick, 1 )
			 end
			 return nil
		  elseif cmd == "UserIP" then
			 local nick,ip
			 for combo in string.gfind( string.sub( msg, 9 ), "[^$]+") do
				ret,c,nick,ip = string.find( combo, "^(%S+) (%S+)$" )
				if ret then
				   h:getUser( nick ):setIp( ip )
				end
			 end
			 return nil
		  elseif cmd == "UserCommand" then
			 h:hubUC( msg )
		  --elseif string.sub( msg, 1, 10 ) == "$NickList " then
		  --   for nick in string.gfind( string.sub( msg, 9, -1), "[^$]+") do
		  --	  h:getUser( nick )
		  --   end
		  --   return nil
		  elseif cmd == "To:" then
			 local ret,c,to,from,fulltext = string.find( msg, "^%$To: ([^ ]+) From: ([^ ]+) %$(.*)$" )
			 if ret then
				local ret,c,prefix,text = string.find( fulltext, "^(%b<> )(.*)$" )
				if ret then
				   return h:onPrivateMessage( h:getUser( from ), to, prefix, text, msg )
				else
				   return h:onPrivateMessage( h:getUser( from ), to, nil, fulltext, msg )
				end
			 end
		  end
	   elseif string.sub( msg, 1, 1 ) == "<" then
		  local ret,c,nick,text = string.find( msg, "^<([^>]+)> (.*)$" )
		  if ret and h:getOwnNick() then
			 if nick ~= h:getOwnNick() then -- don't be flooding mainchat now..
				return h:onChatMessage( h:getUser( nick ), text )
			 else
				return h:onChatFromSelf( text )
			 end
		  end
	   elseif msg ~= "" then
		  return h:onUnknownChatMessage(msg)
	   end
	end

	function dcpp.UserDataIn( user, msg )
	   return scriptMan:Run( "clientIn", user, msg )
	end

	function dcpp.UserDataOut( user, msg )
	   return scriptMan:Run( "clientOut", user, msg )
	end

	function dcpp.OnCommandEnter( hub, text )
	   local h = dcpp:getHub( hub )
	   return scriptMan:Run( "ownChatOut", h, text )
	end

	function dcpp.OnTimer()
	   -- Called every second.
	   return scriptMan:Run( "timer" )
	end

	function nmdch.OnHubAdded( hub )
	   dcpp:addHub( hub, false )
	end

	function nmdch.OnHubRemoved( hub )
	   dcpp:removeHub( hub )
	end

	adch = {}

	function adch.DataArrival( hub, msg )
	   if msg == "" then
		  return nil
	   end
	   local h = dcpp:getHub( hub )
	   
	   local params = {}
	   string.gsub(msg, "([^ ]+)", function(s) table.insert(params, s) end )
	   
	   local mtype = string.sub(params[1], 1, 1)
	   local cmd = string.sub(params[1], 2, 4)
	   local sid, targetSid, parameters = false, false, ""
	   
	   if mtype == "I" then
		  parameters = string.sub( msg, 6)
		  sid = "HUB9"
	   elseif mtype == "B" then
		  parameters = string.sub( msg, 11)
		  sid = params[2]
	   elseif mtype == "D" or mtype == "E" then
		  parameters = string.sub( msg, 16 )
		  sid = params[2]
		  targetSid = params[3]
	   end
	   
	   -- Building flags table
	   local flags = {}
	   string.gsub(parameters, "([^ ]+)", function(s) flags[string.sub(s, 1, 2)] = dcu:AdcEscape( string.sub(s, 3), true ) end )
	   
	   if cmd == "SID" then
		  DC():PrintDebug( "[STATUS] SID received: " .. params[2] )
		  h._mySID = params[2]
	   elseif cmd == "QUI" then
		  h:removeUser( params[2] )
		  h:onQUI( params[2], flags )
	   elseif cmd == "INF" then
		  local u = h:getUser( sid, parameters )
		  return h:onINF( u, flags )
	   elseif cmd == "MSG" then
		  local pm, replySid, me_msg = false, false, false
		  local tmp = {}
		  
		  string.gsub(parameters, "([^ ]+)", function(s) table.insert(tmp, s) end )
		  local text = dcu:AdcEscape(tmp[1], true)
		  tmp[1] = nil
		  
		  -- Check for named parameters
		  for k in pairs(tmp) do
			 local name = string.sub(tmp[k], 1,2)
			 local value = string.sub(tmp[k], 3)
			 if name == "ME" then
				if value == "1" then
				   me_msg = true
				end
			 elseif name == "PM" then
				pm = true
				replySid = value
			 end
		  end
		  
		  if pm then
			 return h:onPrivateMessage( h:getUser( sid ), targetSid, replySid, text, me_msg )
		  else
			 if sid ~= h:getOwnSid() then -- don't be flooding mainchat now..
				return h:onChatMessage( h:getUser( sid ), text, me_msg )
			 else
				return h:onChatFromSelf( text, me_msg )
			 end
		  end
		  
	   end
	end

	function adch.OnHubAdded( hub )
	   dcpp:addHub( hub, true )
	end

	function adch.OnHubRemoved( hub )
	   dcpp:removeHub( hub )
	end


	--/////////////////////////////////////
	--// Utility functions
	--/////////////////////////////////////

	function SendActiveSearchResult( hub, ip_port, search_nick, filename, filesize, open_slots, total_slots )
	   DC():SendUDP( ip_port, "$SR "..search_nick.." "..filename.."\005".. filesize.." "..open_slots..
		  "/"..total_slots.."\005"..dcpp:getHub( hub ):getHubName() ) -- no pipe in UDP $SR
	end

	function dcpp.sysip()
		for line in io.popen("ipconfig"):lines() do
		  local ip = line:match("IPv?4? Address[^:]+: ([%d%.]+)")
		  if ip then
			  return ip
		  end
		end
	end

	function table.in_table ( e, t ) 
		for u,v in pairs(t) do
			if (v==e) then 
				return true,u
			end
		end
		return false
	end
	
	--/////////////////////////////////////
	--// Start Lua Manager
	--/////////////////////////////////////

	local fnc, err = loadfile( DC():GetAppPath().."luascripts/libsimplepickle.lua" )
	if fnc then
	   fnc()
	   fnc = nil
	else
	   DC():PrintDebug( " LUA ERROR: "..err)
	   pickle = { store = function() end }
	end

	scriptMan = {}

	scriptMan.Init = function( filename )
	   dcpp._listeners = { id = {} }
	   scriptMan.script = {}
	   setmetatable( scriptMan.script, { __index = {
		  load = function( this, filename )
			 local ret
			 if scriptMan.script:getid( filename ) then
				scriptMan.script:unload( filename )
				ret = "successfully reloaded."
			 else
				ret = "successfully loaded."
			 end
			 local i = #dcpp._listeners.id +1
			 local func, err = loadfile( DC():GetAppPath().."luascripts/"..filename )
			 if not func then return nil, err end
			 -- load into a new environment
			 dcpp._listeners[i] = {}
			 setmetatable( dcpp._listeners[i], { __index = _G } )
			 setfenv( func, dcpp._listeners[i] )
			 func()

			 dcpp._listeners.id[i] = filename
			 -- change status flag if exists
			 local known = false
			 for i in ipairs(scriptlist) do
				if scriptlist[i][1] == filename then
				   scriptlist[i][2] = 1
				   known = true
				   break
				end
			 end
			 -- insert if it's new
			 if not known then table.insert( scriptlist, { filename, 1 } ) end
			 scriptMan.script:save()
			 return ret
		  end,
		  remove = function( this, filename )
			 local id = scriptMan.script:getid( filename )
			 if id then
				table.remove( dcpp._listeners.id, id ) -- remove its id
				table.remove( dcpp._listeners, id ) -- remove its environment
				collectgarbage("collect")
			 end
			 -- remove from scriptlist
			 for i in ipairs(scriptlist) do
				if scriptlist[i][1] == filename then
				   table.remove( scriptlist, i )
				   scriptMan.script:save()
				   return "removed."
				end
			 end
			 return "not found."
		  end,
		  unload = function( this, filename )
			 local id = scriptMan.script:getid( filename )
			 if id then
				table.remove( dcpp._listeners.id, id ) -- remove its id
				table.remove( dcpp._listeners, id ) -- remove its environment
				collectgarbage("collect")
			 end
			 -- change status flag to 0 (inactive)
			 for i in ipairs(scriptlist) do
				if scriptlist[i][1] == filename then
				   scriptlist[i][2] = 0
				   scriptMan.script:save()
				   return "unloaded."
				end
			 end
			 return "not found"
		  end,
		  getid = function( this, filename )
			 for id, name in pairs( dcpp._listeners.id ) do
				if name == filename then
				   return id
				end
			 end
			 return nil
		  end,
		  save = function( this )
			 pickle.store( DC():GetAppPath().."luascripts/scriptlist.tbl", { scriptlist = scriptlist } )
		  end}
	   })
	   -- load scriptmanager first
	   dcpp._listeners.id[1] = "startup.lua"
	   dcpp._listeners[1] =  {
		  ownChatOut = function( hub, message )
			 if message:sub(1,1) ~= "/" then return nil end
	   
			 local _,_, cmd, fname = message:find( "([^ ]+)[ ]*(.*)" )
			 if cmd == nil then
				return nil
			 elseif cmd == "/lualist" then
				local sc, a = {}, 0
				for i, n in ipairs( scriptlist ) do
				   if n[2] == 1 then a = a +1 end
				   table.insert( sc, ("[ ".. n[2] .." ] ".. n[1]) )
				end
				hub:addLine( "Scripts: (".. a .."/".. #sc ..")\r\nVersion: ".. _VERSION .."\r\n"..table.concat(sc, "\r\n").."\r\n" )
				return 1   
			 elseif cmd == "/luaload" then
				if fname ~= "startup.lua" then
				   local ret, err = scriptMan.script:load( DC():FromUtf8(fname) )
				   hub:addLine( (err and err or "Lua script '"..fname.."' "..ret) )
				else
				   hub:addLine( "ERROR: Use '/luafile startup.lua' if you really want to reload it." )
				end
					return 1
			 elseif  cmd == "/luareload" then
					if scriptMan.script:getid( DC():FromUtf8(fname) ) then
					   local ret, err = scriptMan.script:load( DC():FromUtf8(fname) )
				   hub:addLine( (err and err or "Lua script '"..fname.."' "..ret) )
					else
					   hub:addLine( "ERROR: Lua script '"..fname.."' is not running." )
					end
					return 1
			 elseif cmd == "/luaunload" then
				if fname ~= "startup.lua" then
				   local ret = scriptMan.script:unload( DC():FromUtf8(fname) )
				   hub:addLine( "Lua script '"..fname.."' "..ret )
				else
				   hub:addLine( "ERROR: Use '/luafile startup.lua' if you really want to reload it." )
				end
				return 1
			 elseif cmd == "/luaremove" then
				if fname ~= "startup.lua" then
				   local ret = scriptMan.script:remove( DC():FromUtf8(fname) )
				   hub:addLine( "Lua script '"..fname.."' "..ret )
				else
				   hub:addLine( "ERROR: Use '/luafile startup.lua' if you really want to reload it." )
				end
				return 1
			 elseif cmd == "/mem" then
				collectgarbage("collect")
				local mem = collectgarbage("count")
				local t, i = { "KiB", "MiB", "GiB", "TiB" }, 1
				while mem >= 1024 and i < #t do mem = (mem / 1024); i = i+1 end
				hub:addLine( "Scripts are using ".. string.format("%.2f", mem ) .. " "..t[i].." of memory." )
				return 1
			 elseif cmd == "/help" then
				hub:addLine( "\r\n"..string.rep("-", 156).."\r\n   Script Manager\r\n"..string.rep("-", 156).."\r\n"..
				   "/lualist			   scriptlist\r\n"..
				   "/luaload <filename>			load <filename> script\r\n"..
				   "/luareload <filename>		 reload <filename> script\r\n"..
				   "/luaunload <filename>		 unload <filename> script\r\n"..
				   "/luaremove <filename>		 unload and/or remove <filename> from scriptlist\r\n"..
				   "/mem			   memory usage by scripts\r\n"..
				   "/luafile startup.lua			reload scripting interface" )
				return nil
			 end
		  end
	   }
	   setmetatable( dcpp._listeners[1], { __index = _G } )
	   setfenv( dcpp._listeners[1].ownChatOut, dcpp._listeners[1] )
	end   

	scriptMan.Run = function( this, fname, ... )
	   for i in ipairs( dcpp._listeners ) do
		  if type( dcpp._listeners[i][fname] ) == "function" then
			 local res, ret = pcall( dcpp._listeners[i][fname], ... )
			 if not res then
				DC():PrintDebug( " LUA ERROR: ("..dcpp._listeners.id[i]..": "..fname..") "..ret )
			 else
				if ret then return 1 end
			 end
		  end
	   end
	end

	scriptMan.Init()

	if not scriptlist then
	   local func = loadfile( DC():GetAppPath() .. "luascripts/scriptlist.tbl" )
	   if func then
		  func()
	   else
		  local f = io.open( DC():GetAppPath() .. "luascripts/scriptlist.tbl", "w+")
		  if f then f:close() end
	   end
	   
	   if type(scriptlist) ~= "table" then
		  scriptlist = {}   -- [1] = {scriptname, active (1/0)}
		  scriptMan.script:save()
	   end
	end

	dofile = function( filename )
	   local fnc, err = loadfile( filename )
	   if fnc then
		  setfenv(fnc, getfenv(2))
		  fnc()
	   else
		  DC():PrintDebug( " LUA ERROR: "..err )
	   end
	end
	   
	-- _always_ start formatting.lua
	scriptMan.script:load( "formatting.lua" )

	-- autostart last running scripts but (running) formatting.lua
	for i in ipairs( scriptlist ) do
	   if scriptlist[i][2] == 1 and scriptlist[i][1] ~= "formatting.lua" then
		  local res, err = scriptMan.script:load( scriptlist[i][1] )
		  if not res then
			 DC():PrintDebug( " "..err)
		  end
	   end
	end

	-- run timer
	DC():RunTimer(1)