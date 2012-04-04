----    pickle helper script
----    Copyright (C) 2010-2012  Malar Kannan <malarkannan.p@gmail.com>
----
----    This program is free software: you can redistribute it and/or modify
----    it under the terms of the GNU General Public License as published by
----    the Free Software Foundation, either version 3 of the License, or
----    (at your option) any later version.
----
----    This program is distributed in the hope that it will be useful,
----    but WITHOUT ANY WARRANTY; without even the implied warranty of
----    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
----    GNU General Public License for more details.
----
----    You should have received a copy of the GNU General Public License
----    along with this program.  If not, see <http://www.gnu.org/licenses/>.

local string = string
local coroutine = coroutine
local table = table
local math = math
local ippickle = {}
ippickle._ipfile = DC():GetAppPath() .. "luascripts/iptable.dat"
ippickle._nickfile = DC():GetAppPath() .. "luascripts/nicktable.dat"

ippickle._ip2hall  = {[101]="AH ",[102]="BCR",[103]="GH ",[104]="HJB",[105]="JCB",
			[106]="LLR",[107]="MBM",[108]="NH ",[109]="PH" ,[110]="RK ",
			[111]="RP ",[112]="SN ",[113]="VS",[114]="ZH",[115]="MS ",
			[116]="SAM",[117]="MMM",}
ippickle._searchip = {}
ippickle._sessnick = {}
ippickle._checkstatus,ippickle._syncstatus,ippickle._checkcount,ippickle._synccount = 0,0,0,0
ippickle._counter,ippickle._interval = 0,5
ippickle._synccounter,ippickle._syncinterval = 0,90
ippickle._checkcounter,ippickle._checkinterval = 0, 150
ippickle._myip = "10.111.2.220"--dcpp.sysip()
ippickle._myport = "14282"
ippickle._userconnectstart,ippickle._spystart = true,true

function ippickle.ipsave()
	pickle.store( ippickle._ipfile,{ iptabledata = ippickle._iptable },function(err) DC():PrintDebug( "***ippickle.lua: ipfile save error: " .. err) end)
end

function ippickle.nicksave()
	pickle.store(ippickle._nickfile,{nicktabledata = ippickle._nicktable},function(err) 
	DC():PrintDebug( "***ippickle.lua: nickfile save error: " .. err) end)	
end

function ippickle.nickloaderror(err)
	os.execute('move "'..DC():GetAppPath()..'luascripts/nicktable.dat" "D:\\Dump\\logs\\ip-nick\\nick'..string.gsub(os.date(),"[/ :]","")..'.dat"')
	os.execute('echo "">"'..DC():GetAppPath()..'luascripts/nicktable.dat"')
	ippickle._nicktable = {}
	for k,_ in pairs(ippickle._iptable) do
		for l,_ in pairs(ippickle._iptable[k]) do
			if not ippickle._nicktable[l] then
				ippickle._nicktable[l] ={}
			end
			if not table.in_table(k,ippickle._nicktable[l]) then
				table.insert(ippickle._nicktable[l],k)
			end
		end
	end
	DC():PrintDebug( "*** ippickle.lua: nickfile load error: " .. err)
	ippickle.nicksave()
	ippickle.nickload()
end

function ippickle.ipload()
	pickle.restore( ippickle._ipfile,function(err)
										os.execute('move "'..DC():GetAppPath()..'luascripts/iptable.dat" "D:\\Dump\\logs\\ip-nick\\ip'..
										string.gsub(os.date(),"[/ :]","")..'.dat"')
										os.execute('echo "">"'..DC():GetAppPath()..'luascripts/iptable.dat"')
										DC():PrintDebug( "*** ippickle.lua: ipfile load error: " .. err)
										ippickle._iptable = {} ippickle.ipsave()ippickle.ipload()
									end)
	ippickle._iptable = iptabledata
	if not ippickle._iptable then ippickle._iptable = {} end
	iptabledata = nil
	DC():PrintDebug("  ** Loaded iptable.dat **")
end
ippickle.ipload()

function ippickle.nickload()
	pickle.restore( ippickle._nickfile, ippickle.nickloaderror )
	ippickle._nicktable = nicktabledata
	if not ippickle._nicktable then ippickle._nicktable = {} end
	nicktabledata = nil
	DC():PrintDebug("  ** Loaded nicktable.dat **")
end
ippickle.nickload()

dcpp:setListener( "ownChatOut", "ippickle",
	function( hub, msg, ret )
		if string.sub( msg, 1, 1 ) ~= "/" then
			return nil
		elseif string.sub( msg, 2, 5 ) == "help" then
			hub:injectChat( "*** (ippickle.lua) /<iptable/nicktable> [off] <recheck/resync/checkstatus/syncstatus/partial or full <IP/nick>>" )
		elseif string.sub( msg, 2, 6 ) =="nick " then
			local rest = string.lower(DC():FromUtf8(string.sub( msg, 7)))
			local offline = false
			if string.sub(rest,1,5) == "+off " then rest = string.sub( rest, 6) offline = true end
			local found = 0
			hub:addLine("Searching for nicks with ".."\""..rest.."\"",true)
			for nick,_ in pairs(ippickle._nicktable) do
				local x = string.find(string.lower(nick),rest,1,true)
				local out = ""
				if offline and x then
					out = out.."    "..nick.." had ips: "
					for _,ip in ipairs(ippickle._nicktable[nick]) do 
						local _,_,ip2 = string.find(ip, "^%d+%.(%d+).*")
						out=out..ip.." : "..(ippickle._ip2hall[tonumber(ip2)] or "Unknown")..", "
						found = found + 1
					end
				elseif x and hub._users[nick] then
					local _,_,ip2 = string.find(ippickle._nicktable[nick][#ippickle._nicktable[nick]], "^%d+%.(%d+).*")
					out = out.."    "..nick.." has ip "..ippickle._nicktable[nick][#ippickle._nicktable[nick]]..
					" from hall "..(ippickle._ip2hall[tonumber(ip2)] or "Unknown")
					found = found + 1
				end
				hub:addLine(out,true)
			end
			hub:addLine("found "..found.." nicks",true)
			return 1
		elseif string.sub( msg, 2, 4 ) == "ip " then
			local rest = DC():FromUtf8(string.sub( msg, 5))
			local offline,_ = string.find(rest,"+off")
			if offline then rest = string.sub( msg, 10) end
			local _,_,ip1 = string.find(rest, "^(%d+).*")
			local _,_,ip2 = string.find(rest, "^%d+%.(%d+).*")
			local _,_,ip3 = string.find(rest, "^%d+%.%d+%.(%d+).*")
			local _,_,ip4 = string.find(rest, "^%d+%.%d+%.%d+%.(%d+)")
			local found = 0
			if ip4 then
				local ip = ip1.."."..ip2.."."..ip3.."."..ip4
				hub:addLine("Searching for ip "..ip.." in iptable",true)
				if not ippickle._iptable[ip] then
					hub:addLine("ip not found")
					return 1
				end
				local out = "    "..ip.." is with "
				for nick,_ in pairs(ippickle._iptable[ip]) do
					if (hub._users[nick] and ippickle._nicktable[nick] and ippickle._nicktable[nick][#ippickle._nicktable[nick]] == ip) or offline then
						out = out.." ".. nick
					end
				end
				hub:addLine(out)
				return 1
			elseif ip3 then
				hub:addLine("Searching for ips' in network:"..ip1.."."..ip2.."."..ip3..".0/255.255.255.0".." in iptable",true)
				for x4 = 1,255 do
					local ip = ip1.."."..ip2.."."..ip3.."."..tostring(x4)
					if ippickle._iptable[ip] then
						local out,flag = "",true
						for nick,_ in pairs(ippickle._iptable[ip]) do
							if offline or hub._users[nick] and ippickle._nicktable[nick][#ippickle._nicktable[nick]] == ip then
								if flag then out = out.."   ip "..ip..(offline and " was had by" or " is with").." : " flag = nil end
								out = out.." "..nick
								found = found +1
							end
						end
						if out ~= "" then hub:addLine(out) end
					end
				end
				hub:addLine("found "..found.." ips'",true) found = 0
				return 1
			elseif ip2 then
				hub:addLine("Searching for ips' in network:"..ip1.."."..ip2..".0.0/255.255.255.0".." in iptable",true)
				for ip,_ in pairs(ippickle._iptable) do
					local _,_,x12 = string.find(ip,"(%d+%.%d+)%.%d+%.%d+")
					if x12==ip1.."."..ip2 then
						local out,flag = "",true
						for nick,_ in pairs(ippickle._iptable[ip]) do
							if offline or hub._users[nick] and ippickle._nicktable[nick][#ippickle._nicktable[nick]] == ip then
								if flag then out = out.."   ip "..ip..(offline and " was had by" or " is with").." : " flag = nil end
								out = out.." "..nick
								found = found +1
							end
						end
						if out ~= "" then hub:addLine(out) end
					end
				end
				hub:addLine("found "..found.." ips'",true) found = 0
				return 1
			elseif ip1 then
				hub:addLine("Searching for ips' in network:"..ip1..".0.0.0/255.255.255.0".." in iptable",true)
				for ip,_ in pairs(ippickle._iptable) do
					local _,_,x1 = string.find(ip,"(%d+)%.%d+%.%d+%.%d+")
					if x1==ip1 then
						local out,flag = "",true
						for nick,_ in pairs(ippickle._iptable[ip]) do
							if offline or hub._users[nick] and ippickle._nicktable[nick][#ippickle._nicktable[nick]] == ip then
								if flag then out = out.."   ip "..ip..(offline and " was had by" or " is with").." : " flag = nil end
								out = out.." "..nick
								found = found +1
							end
						end
						if out ~= "" then hub:addLine(out) end
					end
				end
				hub:addLine("found "..found.." ips'",true) found = 0
				return 1
			else
				hub:addLine( "/<iptable/nicktable> [off] <recheck/resync/checkstatus/syncstatus/partial or full <IP/nick>>" ,true)
				return 1
			end
		elseif string.sub( msg, 2, 9) == "iptable " then
			local rest = string.sub( msg, 10)
			if rest == "status" then
				local count,total = 0,0
				for k in pairs(hub._users) do if not hub._users[k]._op then total = total + 1 end end
				for k,_ in pairs(ippickle._sessnick) do if hub._users[k] and not hub._users[k]._op then count = count + 1 end end
				hub:addLine("** ippickle sync to "..math.ceil(count*100/total).."% with "..count.." users.")
				return 1
			elseif rest == "pending" then
				local out = " "
				for nick in pairs(hub._users) do if not ippickle._sessnick[nick] and not hub._users[nick]._op then out = out..nick.." " end end
				hub:addLine("pending users are:\t"..out)
				return 1
			elseif rest == "extra" then
				local out = " "
				for nick,_ in pairs(ippickle._sessnick) do if not hub._users[nick] and not hub._users[nick]._op then out = out..nick.." " end end
				hub:addLine("extra users are:\t"..out)
				return 1
			elseif rest == "checkstatus" then
				if ippickle._checkcount == 0 then hub:addLine("*** "..ippickle._checkstatus.." users has been checked")
				else hub:addLine("*** "..math.floor(ippickle._checkstatus*100/ippickle._checkcount)..
				"% is completed of checking "..ippickle._checkcount.." users at "..ippickle._checkstatus..' ( '..(ippickle._checknick or "")..' )',true)
				end
				return 1
			elseif rest == "syncstatus" then
				if ippickle._synccount == 0 then hub:addLine("*** "..ippickle._syncstatus.." users has been synced")
				else hub:addLine("*** "..math.floor(ippickle._syncstatus*100/ippickle._synccount)..
				"% is completed of syncing "..ippickle._synccount.." users at "..ippickle._syncstatus..' ( '..(ippickle._syncnick or "")..' )',true)
				end
				return 1
			elseif rest == "users" then
				local out,count = " ",0 for nick,_ in pairs(ippickle._sessnick) do out = out.." "..nick count = count + 1 end out = out.." "
				hub:addLine("users online in iptable :\n"..out.."\n\t----\t"..count.." users",true)
				return 1
			elseif rest == "start" then
				ippickle._userconnectstart,ippickle._spystart = true, true
				ippickle._checkinterval,ippickle._syncinterval = 150,90
				hub:addLine("*** listener to search,userconnected started",true)
				return 1
			elseif rest == "abort" then
				ippickle._checkco,ippickle._syncco = nil,nil
				ippickle._userconnectstart,ippickle._spystart,ippickle._startcheck,_startsync = nil,nil,nil,nil
				ippickle._checkinterval,ippickle._syncinterval = -1,-1
				hub:addLine("*** listener to search,userconnected aborted",true)
				return 1
			elseif string.sub( rest, 1, 7) == "ignore " then
				local user = DC():FromUtf8(string.sub(rest,8))
				if hub._users[user] then ippickle._sessnick[user] = true hub:addLine("ignoring user: "..user) end
				return 1
			elseif rest == "ipcount" then
				local count = 0
				for _ in pairs(ippickle._iptable) do count = count + 1 end
				hub:addLine(count.." entries in iptable",true)
				return 1
			elseif rest == "nickcount" then
				local count = 0
				for _ in pairs(ippickle._nicktable) do count = count + 1 end
				hub:addLine(count.." entries in nicktable",true)
				return 1
			elseif rest == "recheck" then
				ippickle._checkstatus,ippickle._checkcount = 0,0
				for k in pairs(hub._users) do 
					if (not hub._users[k]._op and ippickle._nicktable[hub._users[k]._nick] and not ippickle._sessnick[hub._users[k]._nick]) then
						ippickle._checkcount = ippickle._checkcount + 1
					end 
				end
				ippickle._checkco = coroutine.create(
					function()
						for _,hub in pairs(dcpp:getHubs()) do
							for k,_ in pairs(hub._users) do
								if not hub._users[k]._op and ippickle._nicktable[hub._users[k]._nick] and not ippickle._sessnick[hub._users[k]._nick] then
									DC():SendHubMessage( hub:getId(),
									"$ConnectToMe "..hub._users[k]._nick.." "..ippickle._myip..":"..ippickle._myport.."|")
									ippickle._checknick = hub._users[k]._nick
									local resendnick = coroutine.yield()
									local i = 1
									while resendnick and (i<3) do
										if not ippickle._sessnick[resendnick] then
											DC():SendHubMessage( hub:getId(),
											"$ConnectToMe "..resendnick.." "..ippickle._myip..":"..ippickle._myport.."|")
										end
										ippickle._checknick = resendnick
										resendnick = coroutine.yield()
										i = i + 1
									end							
								end
							end
						end
						hub:addLine("*** iptable check complete ")
						ippickle._checkco  = nil
					end
				)
				hub:addLine("*** iptable is being rechecked ",true )
				coroutine.resume(ippickle._checkco)
				return 1
			elseif rest == "resync" then
				ippickle._syncstatus,ippickle._synccount = 0,0
				for k in pairs(hub._users) do 
					if (not hub._users[k]._op and not ippickle._nicktable[hub._users[k]._nick]) then ippickle._synccount = ippickle._synccount + 1  end 
				end
				ippickle._syncco = coroutine.create(
					function()
						for _,hub in pairs(dcpp:getHubs()) do
							for k,_ in pairs(hub._users) do
								if not hub._users[k]._op and not ippickle._nicktable[hub._users[k]._nick] then
									DC():SendHubMessage( hub:getId(), 
									"$ConnectToMe "..hub._users[k]._nick.." "..ippickle._myip..":"..ippickle._myport.."|")
									ippickle._syncnick = hub._users[k]._nick
									local resendnick = coroutine.yield()
									local i = 1
									while resendnick and (i<3) do
										if not ippickle._sessnick[resendnick] then
											DC():SendHubMessage( hub:getId(),
											"$ConnectToMe "..resendnick.." "..ippickle._myip..":"..ippickle._myport.."|")
										end
										ippickle._syncnick = resendnick
										resendnick = coroutine.yield()
										i = i + 1
									end	
								end
							end
						end
						hub:addLine("*** iptable sync complete ")
						ippickle._syncco  = nil
					end
				)
				hub:addLine("*** iptable is being resynced ",true )
				coroutine.resume(ippickle._syncco)
				return 1
			elseif rest == "log" then
				os.execute('move "'..DC():GetAppPath()..'luascripts/iptable.dat" "D:\\Dump\\logs\\ip-nick\\ip'..string.gsub(os.date(),"[/ :]","")..'.dat"')
				os.execute('move "'..DC():GetAppPath()..'luascripts/nicktable.dat" "D:\\Dump\\logs\\ip-nick\\nick'..string.gsub(os.date(),"[/ :]","")..'.dat"')
				ippickle._iptable,ippickle._nicktable = {},{}
				return 1
			else
				hub:addLine( "/<iptable/nicktable> [off] <recheck/resync/checkstatus/syncstatus/partial or full <IP/nick>>" ,true)
				return 1
			end
		elseif string.sub( msg, 2, 8 ) =="iptable" or string.sub( msg, 2, 10) =="nicktable" then
			hub:addLine( "/<iptable/nicktable> [off] <recheck/resync/checkstatus/syncstatus/partial or full <IP/nick>>", true )
			return 1
		end
	end
)

dcpp:setListener( "userConnected", "ippickle",
	function( hub, user )
		if not user._op and  ippickle._userconnectstart then
			DC():SendHubMessage( hub:getId(), "$ConnectToMe "..user._nick.." "..ippickle._myip..":"..ippickle._myport.."|")
			ippickle._userconnectednick = user._nick
			ippickle._hub = hub:getId()
		end
	end
)

dcpp:setListener( "userQuit", "ippickle",
	function( hub, nick )
		if ippickle._sessnick[nick] then ippickle._sessnick[nick] = nil end
	end
)

dcpp:setListener( "raw", "ippickle",
	function(hub, msg)
		local r,_,ip,ip123,ip4 = string.find(msg, "((%d+%.%d+%.%d+)%.(%d+)):%d+")
		if not ippickle._iptable[ip] then
			if ippickle._spystart and not ippickle._searchip[ip] and r then
				ippickle._searchip[ip] = true
				for x4 = 1,255 do
					local x = ip123.."."..tostring(x4)
					if ippickle._iptable[x] and x4 ~= tonumber(ip4) then
						for nick,_ in pairs(ippickle._iptable[x]) do
							if hub._users[nick] and not ippickle._sessnick[nick] then
								DC():SendHubMessage( hub:getId(), "$ConnectToMe "..nick.." "..ippickle._myip..":"..ippickle._myport.."|")
							end
						end
					end
				end
			end
		end
	end
)

dcpp:setListener("timer", "ippickle",
	function()
		ippickle._counter,ippickle._synccounter,ippickle._checkcounter = ippickle._counter + 1,ippickle._synccounter + 1,ippickle._checkcounter + 1
		if ippickle._counter >= ippickle._interval then
			if ippickle._checkco and ippickle._checknick and coroutine.status(ippickle._checkco)== "suspended" then 
				coroutine.resume(ippickle._checkco,ippickle._checknick) end
			if ippickle._syncco and ippickle._syncnick and coroutine.status(ippickle._syncco)== "suspended" then 
				coroutine.resume(ippickle._syncco,ippickle._syncnick) end
			if ippickle._userconnectednick then
				DC():SendHubMessage( ippickle._hub, "$ConnectToMe "..ippickle._userconnectednick.." "..ippickle._myip..":"..ippickle._myport.."|")
			end
			if ippickle._startsync then
				ippickle._startsync = nil
				ippickle._syncstatus,ippickle._synccount = 0,0
				for _,hub in pairs(dcpp:getHubs()) do
					for k in pairs(hub._users) do 
						if (not hub._users[k]._op and not ippickle._nicktable[hub._users[k]._nick] and not ippickle._sessnick[hub._users[k]._nick]) then
							ippickle._synccount = ippickle._synccount + 1 
						end 
					end
				end
				ippickle._syncco = coroutine.create(
					function()
						for _,hub in pairs(dcpp:getHubs()) do
							for k,_ in pairs(hub._users) do
								if not hub._users[k]._op and not ippickle._nicktable[hub._users[k]._nick] and not ippickle._sessnick[hub._users[k]._nick] then
									DC():SendHubMessage( hub:getId(),
									"$ConnectToMe "..hub._users[k]._nick.." "..ippickle._myip..":"..ippickle._myport.."|")
									ippickle._syncnick = hub._users[k]._nick
									local resendnick = coroutine.yield()
									local i = 1
									while resendnick and (i<3) do
										if not ippickle._sessnick[resendnick] then
											DC():SendHubMessage( hub:getId(),
											"$ConnectToMe "..resendnick.." "..ippickle._myip..":"..ippickle._myport.."|")
										end
										ippickle._syncnick = resendnick
										resendnick = coroutine.yield()
										i = i + 1
									end	
								end
							end
						end
						ippickle._syncco = nil
					end
				)
				coroutine.resume(ippickle._syncco)
			end
			if ippickle._startcheck then
				ippickle._startcheck = nil
				ippickle._checkstatus,ippickle._checkcount = 0,0
				for _,hub in pairs(dcpp:getHubs()) do
					for k in pairs(hub._users) do 
						if (not hub._users[k]._op and ippickle._nicktable[hub._users[k]._nick] and not ippickle._sessnick[hub._users[k]._nick]) then
							ippickle._checkcount = ippickle._checkcount + 1 
						end 
					end
				end
				ippickle._checkco = coroutine.create(
					function()
						for _,hub in pairs(dcpp:getHubs()) do
							for k,_ in pairs(hub._users) do
								if not hub._users[k]._op and ippickle._nicktable[hub._users[k]._nick] and not ippickle._sessnick[hub._users[k]._nick] then
									DC():SendHubMessage( hub:getId(),
									"$ConnectToMe "..hub._users[k]._nick.." "..ippickle._myip..":"..ippickle._myport.."|")
									ippickle._checknick = hub._users[k]._nick
									local resendnick = coroutine.yield()
									local i = 1
									while resendnick and (i<3) do
										if not ippickle._sessnick[resendnick] then
											DC():SendHubMessage( hub:getId(),
											"$ConnectToMe "..resendnick.." "..ippickle._myip..":"..ippickle._myport.."|")
										end
										ippickle._checknick = resendnick
										resendnick = coroutine.yield()
										i = i + 1
									end							
								end
							end
						end
						ippickle._checkco  = nil
					end
				)
				coroutine.resume(ippickle._checkco)
			end
			ippickle._counter = math.fmod(ippickle._counter,ippickle._interval)
		end
		if ippickle._checkcounter >= ippickle._checkinterval and not ippickle._checkco then
			ippickle._startcheck = true
			ippickle._checkcounter = math.fmod(ippickle._checkcounter,ippickle._checkinterval)
		end
		if ippickle._synccounter >= ippickle._syncinterval and not ippickle._syncco then
			ippickle._startsync = true
			ippickle._synccounter = math.fmod(ippickle._synccounter,ippickle._syncinterval)
		end
	end
)

dcpp:setListener("clientIn", "ippickle",
	function(userp,line)
		local s,_,nick = string.find(line,"^%$MyNick (.*)")
		if s then
			ip = DC():GetClientIp(userp)
			ippickle._sessnick[nick] = true
			if not ippickle._nicktable[nick] then
				ippickle._nicktable[nick]={}
			end
			if not table.in_table(ip,ippickle._nicktable[nick]) then
				table.insert(ippickle._nicktable[nick],ip)
				--if #ippickle._nicktable[nick] > 1 then DC():PrintDebug("IP Changer Detected** "..ip.." with nick "..nick) end
				ippickle.nicksave()
			elseif not (ippickle._nicktable[nick][#ippickle._nicktable[nick]] == ip) then
				table.remove(ippickle._nicktable[nick],select(2,table.in_table(ip,ippickle._nicktable[nick])))
				table.insert(ippickle._nicktable[nick],ip)
				if (ippickle._nicktable[nick][#ippickle._nicktable[nick]] == ip) then DC():PrintDebug(nick.." change ip from "..
				ippickle._nicktable[nick][#ippickle._nicktable[nick]-1].." to "..ip) end
				ippickle.nicksave()
			end
			--if ippickle._searchip[ip] then ippickle._searchip[ip] = nil end
			if (ippickle._syncnick == nick) then
				ippickle._syncstatus = ippickle._syncstatus + 1
				ippickle._syncnick = nil DC():DropUserConnection(userp)
				if ippickle._syncco then coroutine.resume(ippickle._syncco) end
			end
			if ippickle._checknick == nick then
				ippickle._checkstatus = ippickle._checkstatus + 1
				ippickle._checknick = nil DC():DropUserConnection(userp)
				if ippickle._checkco then coroutine.resume(ippickle._checkco) end
			--[[if #ippickle._nicktable[nick] > 1 then DC():PrintDebug("IP Changer Detected** "..ip.." with nick "..nick) end
				local count = 0 for _ in pairs(ippickle._iptable[ip]) do count = count + 1 end
				if count > 1 then DC():PrintDebug("Nick Changer Detected** "..nick.." with ip "..ip) end count = nil]]--
			end
			if ippickle._userconnectednick == nick then
				ippickle._userconnectednick = nil DC():DropUserConnection(userp)
			end
			if not ippickle._iptable[ip] then
				ippickle._iptable[ip] = {}
			end
			if not ippickle._iptable[ip][nick] then
				ippickle._iptable[ip][nick]=os.date()
				--[[local count = 0 for _ in pairs(ippickle._iptable[ip]) do count = count + 1 end
				if count > 1 then DC():PrintDebug("Nick Changer Detected** "..nick.." with ip "..ip) end count = nil]]--
				ippickle.ipsave()
			end
		end
	end
)

dcpp:setListener("connected", "ippickle",
	function(hub)
		ippickle._myip = "10.111.2.220"--dcpp.sysip()
		ippickle._userconnectstart,ippickle._spystart = true,true
		DC():PrintDebug("  ** using system ip: "..ippickle._myip.."**")
		ippickle._sessnick = {}
		ippickle._startcheck,ippickle._startsync = true,true
	end
)

DC():PrintDebug( "  ** Loaded ippickle.lua **" )
