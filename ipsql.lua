----    IP SQL Script
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

---- ipsql.lua -- creates tables of ip vs user-nick and user-nick vs ip as well
---- currently works on eiskaltdcpp, if u don't have a mysql server try ippickle.lua on ur own risk (which has a drawback of
---- poor performance,high cpu & disk usage).
---- create a database named 'dcppdb' with username 'dcppuser' and password 'dcppp4ss' in ur mysql server

local ipsql = {}

local string = string
local coroutine = coroutine
local table = table
local math = math
require "luasql.mysql"
-- require luasql to be installed in the system

ipsql.env=assert(luasql.mysql())
ipsql.con = assert (ipsql.env:connect("dcppdb","dcppuser","dcppp4ss","localhost"))

--create a database on the mysql server server named "dbppdb" with the username "dcppuser" or preferred, and password "dcppp4ss" or preferred.
-- on ur mysql server "localhost" here;

--Also create the tables using the commands on Upper case in the database dcppdb;
--ipsql.con:execute("CREATE TABLE IF NOT EXISTS ip_nick_state (ip VARCHAR(15),nick VARCHAR(31),date DATETIME) CHARSET=utf8")
--ipsql.con:execute("CREATE TABLE IF NOT EXISTS ip_nick_raw (ip VARCHAR(15),nick VARCHAR(31),date DATETIME) CHARSET=utf8")
-- function ipsql.rows(connection, sql_statement)
--   local cursor = assert(connection:execute (sql_statement))
--   local t = {}
--   return function ()
--     return cursor:fetch(t,"a")
--   end
-- end

ipsql._ip2hall  = {[101]="AH ",[102]="BCR",[103]="GH ",[104]="HJB",[105]="JCB",
			[106]="LLR",[107]="MBM",[108]="NH ",[109]="PH" ,[110]="RK ",
			[111]="RP ",[112]="SN ",[113]="VS",[114]="ZH",[115]="MS ",
			[116]="SAM",[117]="MMM",}
ipsql._searchip = {}
ipsql._sessnick = {}
ipsql._iptable = {}
ipsql._nicktable = {}
ipsql._startcheck,ipsql._startsync = true,true
ipsql._checkstatus,ipsql._syncstatus,ipsql._checkcount,ipsql._synccount = 0,0,0,0
ipsql._counter,ipsql._interval = 0,5
ipsql._synccounter,ipsql._syncinterval = 0,100
ipsql._checkcounter,ipsql._checkinterval = 0, 600
ipsql._myip = "10.111.1.220"--dcpp.sysip()
ipsql._myport = "14282"
ipsql._userconnectstart,ipsql._spystart = true,false

local cur = ipsql.con:execute("SELECT nick,ip FROM ip_nick_state")
local nickname,ipaddr= cur:fetch()
while nickname do
	if not ipsql._nicktable[nickname] then ipsql._nicktable[nickname]=ipaddr
	else print(nickname) end
	if not ipsql._iptable[ipaddr] then ipsql._iptable[ipaddr]=nickname
	else print(ipaddr) ipsql.con:execute("DELETE from ip_nick_state WHERE BINARY ip=\""..ipaddr.."\" LIMIT 1") end
	nickname,ipaddr = cur:fetch()
end
nickname = nil
ipaddr = nil
cur:close()
cur = nil



dcpp:setListener( "ownChatOut", "ipsql",
	function( hub, msg, ret )
		if string.sub( msg, 1, 1 ) ~= "/" then
			return nil
		elseif string.sub( msg, 2, 5 ) == "help" then
			hub:injectChat( "*** (ipsql.lua) /<iptable/nicktable> [off] <recheck/resync/checkstatus/syncstatus/partial or full <IP/nick>>" )
		elseif string.sub( msg, 2, 6 ) =="nick " then
			local rest = string.lower(DC():ToUtf8(string.sub( msg, 7)))
			local found = 0
			hub:addLine("Searching for nicks with ".."\""..rest.."\"",true)
			for nick,_ in pairs(hub._users) do
				if string.find(string.lower(DC():ToUtf8(nick),rest,1,true)) then
					local _,_,ip2 = string.find(ipsql._nicktable[DC():ToUtf8(nick)], "^%d+%.(%d+).*")
					hub:addLine("    <"..nick.."> has ip "..ipsql._nicktable[DC():ToUtf8(nick)].." from hall "..(ipsql._ip2hall[tonumber(ip2)] or "Unknown"),true)
					found = found + 1
				end
			end
			hub:addLine("found "..found.." nicks",true)
			return 1
		elseif string.sub( msg, 2, 4 ) == "ip " then
			local rest = DC():ToUtf8(string.sub( msg, 5))
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
				if not ipsql._iptable[ip] then
					hub:addLine("ip not found")
					return 1
				end
				hub:addLine("    "..ip.." was with <"..ipsql._iptable[ip].."> ")
				return 1
			elseif ip3 then
				hub:addLine("Searching for ips' in network:"..ip1.."."..ip2.."."..ip3.."10.0.0.0/255.255.255.0".." in iptable",true)
				local out = "\n"
				for x4 = 1,255 do
					local ip = ip1.."."..ip2.."."..ip3.."."..tostring(x4)
					if ipsql._iptable[ip] and hub._users[ipsql._iptable[ip]] then
						found = found +1
						out = out..ip.." was with <"..ipsql._iptable[ip].."> \n"
					end
				end
				if out ~= "\n" then hub:addLine(out) end
				hub:addLine("found "..found.." ips'",true) found = 0
				return 1
			elseif ip2 then
				hub:addLine("Searching for ips' in network:"..ip1.."."..ip2.."10.0.0.0/255.255.0.0".." in iptable",true)
				local out = "\n"
				for ip,_ in pairs(ipsql._iptable) do
					local _,_,x12 = string.find(ip,"(%d+%.%d+)%.%d+%.%d+")
					if x12==ip1.."."..ip2 then
						out = out..ip.." was with <"..ipsql._iptable[ip].."> \n"
						found = found +1
					end
				end
				if out ~= "\n" then hub:addLine(out) end
				hub:addLine("found "..found.." ips'",true) found = 0
				return 1
			elseif ip1 then
				hub:addLine("Searching for ips' in network:"..ip1.."10.0.0.0/255.0.0.0".." in iptable",true)
				local out= "\n"
				for ip,_ in pairs(ipsql._iptable) do
					local _,_,x1 = string.find(ip,"(%d+)%.%d+%.%d+%.%d+")
					if x1==ip1 then
						out = out.." was with <"..ipsql._iptable[ip].."> \n"
						found = found +1
					end
				end
				if out ~= "\n" then hub:addLine(out) end
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
				for k,_ in pairs(ipsql._sessnick) do if hub._users[k] and not hub._users[k]._op then count = count + 1 end end
				hub:addLine("** ipsql sync to "..math.ceil(count*100/total).."% (i.e) with "..count.." of "..total.." users.")
				return 1
			elseif rest == "pending" then
				local out = " "
				for nick in pairs(hub._users) do if not ipsql._sessnick[nick] and not hub._users[nick]._op then out = out..nick.." " end end
				hub:addLine("pending users are:\t"..out)
				return 1
			elseif rest == "extra" then
				local out = " "
				for nick,_ in pairs(ipsql._sessnick) do if not hub._users[nick] and not hub._users[nick]._op then out = out..nick.." " end end
				hub:addLine("extra users are:\t"..out)
				return 1
			elseif rest == "checkstatus" then
				if ipsql._checkcount == 0 then hub:addLine("*** "..ipsql._checkstatus.." users has been checked")
				else hub:addLine("*** "..math.floor(ipsql._checkstatus*100/ipsql._checkcount)..
				"% is completed of checking "..ipsql._checkcount.." users at "..ipsql._checkstatus..' <'..(ipsql._checknick or "")..'> ',true)
				end
				return 1
			elseif rest == "syncstatus" then
				if ipsql._synccount == 0 then hub:addLine("*** "..ipsql._syncstatus.." users has been synced")
				else hub:addLine("*** "..math.floor(ipsql._syncstatus*100/ipsql._synccount)..
				"% is completed of syncing "..ipsql._synccount.." users at "..ipsql._syncstatus..' <'..(ipsql._syncnick or "")..'> ',true)
				end
				return 1
			elseif rest == "users" then
				local out,count = " ",0 for nick,_ in pairs(ipsql._sessnick) do out = out.." "..nick count = count + 1 end out = out.." "
				hub:addLine("users online in iptable :\n"..out.."\n\t----\t"..count.." users",true)
				return 1
			elseif rest == "start" then
				ipsql._userconnectstart,ipsql._spystart = true, true
				ipsql._checkinterval,ipsql._syncinterval = 150,90
				hub:addLine("*** listener to search,userconnected started",true)
				return 1
			elseif rest == "abort" then
				ipsql._checkco,ipsql._syncco = nil,nil
				ipsql._userconnectstart,ipsql._spystart,ipsql._startcheck,_startsync = nil,nil,nil,nil
				ipsql._checkinterval,ipsql._syncinterval = -1,-1
				hub:addLine("*** listener to search,userconnected aborted",true)
				return 1
			elseif string.sub( rest, 1, 7) == "ignore " then
				local user = DC():FromUtf8(string.sub(rest,8))
				if hub._users[user] then ipsql._sessnick[user] = true hub:addLine("ignoring user: "..user) end
				return 1
			elseif rest == "ipcount" then
				local count = 0
				for _ in pairs(ipsql._iptable) do count = count + 1 end
				hub:addLine(count.." entries in iptable",true)
				return 1
			elseif rest == "nickcount" then
				local count = 0
				for _ in pairs(ipsql._nicktable) do count = count + 1 end
				hub:addLine(count.." entries in nicktable",true)
				return 1
			elseif rest == "recheck" then
				ipsql._checkstatus,ipsql._checkcount = 0,0
				for k in pairs(hub._users) do
					if (not hub._users[k]._op and ipsql._nicktable[DC():ToUtf8(hub._users[k]._nick)] and not ipsql._sessnick[hub._users[k]._nick]) then
						ipsql._checkcount = ipsql._checkcount + 1
					end
				end
				ipsql._checkco = coroutine.create(
					function()
						for _,hub in pairs(dcpp:getHubs()) do
							for k,_ in pairs(hub._users) do
								if not hub._users[k]._op and ipsql._nicktable[DC():ToUtf8(hub._users[k]._nick)] and not ipsql._sessnick[hub._users[k]._nick] then
									DC():SendHubMessage( hub:getId(),
									"$ConnectToMe "..hub._users[k]._nick.." "..ipsql._myip..":"..ipsql._myport.."|")
									ipsql._checknick = hub._users[k]._nick
									local resendnick = coroutine.yield()
									local i = 1
									while resendnick and (i<3) do
										if not ipsql._sessnick[resendnick] then
											DC():SendHubMessage( hub:getId(),
											"$ConnectToMe "..resendnick.." "..ipsql._myip..":"..ipsql._myport.."|")
										end
										ipsql._checknick = resendnick
										resendnick = coroutine.yield()
										i = i + 1
									end
								end
							end
						end
						hub:addLine("*** iptable check complete ")
						ipsql._checkco  = nil
					end
				)
				hub:addLine("*** iptable is being rechecked ",true )
				coroutine.resume(ipsql._checkco)
				return 1
			elseif rest == "resync" then
				ipsql._syncstatus,ipsql._synccount = 0,0
				for k in pairs(hub._users) do
					if (not hub._users[k]._op and not ipsql._nicktable[DC():ToUtf8(hub._users[k]._nick)] and not ipsql._sessnick[hub._users[k]._nick]) then
						ipsql._synccount = ipsql._synccount + 1
					end
				end
				ipsql._syncco = coroutine.create(
					function()
						for _,hub in pairs(dcpp:getHubs()) do
							for k,_ in pairs(hub._users) do
								if not hub._users[k]._op and not ipsql._nicktable[DC():ToUtf8(hub._users[k]._nick)] then
									DC():SendHubMessage( hub:getId(),
									"$ConnectToMe "..hub._users[k]._nick.." "..ipsql._myip..":"..ipsql._myport.."|")
									ipsql._syncnick = hub._users[k]._nick
									local resendnick = coroutine.yield()
									local i = 1
									while resendnick and (i<3) do
										if not ipsql._sessnick[resendnick] then
											DC():SendHubMessage( hub:getId(),
											"$ConnectToMe "..resendnick.." "..ipsql._myip..":"..ipsql._myport.."|")
										end
										ipsql._syncnick = resendnick
										resendnick = coroutine.yield()
										i = i + 1
									end
								end
							end
						end
						hub:addLine("*** iptable sync complete ")
						ipsql._syncco  = nil
					end
				)
				hub:addLine("*** iptable is being resynced ",true )
				coroutine.resume(ipsql._syncco)
				return 1
-- 			elseif rest == "log" then
-- 				os.execute('move "'..DC():GetAppPath()..'luascripts/iptable.dat" "D:\\Dump\\logs\\ip-nick\\ip'..string.gsub(os.date(),"[/ :]","")..'.dat"')
-- 				os.execute('move "'..DC():GetAppPath()..'luascripts/nicktable.dat" "D:\\Dump\\logs\\ip-nick\\nick'..string.gsub(os.date(),"[/ :]","")..'.dat"')
-- 				ipsql._iptable,ipsql._nicktable = {},{}
-- 				hub:addLine(DC():FromUtf8(DC():ToUtf8("™")))
-- 				return 1
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

dcpp:setListener( "userConnected", "ipsql",
	function( hub, user )
		if not user._op and  ipsql._userconnectstart then
			DC():SendHubMessage( hub:getId(), "$ConnectToMe "..user._nick.." "..ipsql._myip..":"..ipsql._myport.."|")
			ipsql._userconnectednick = user._nick
			ipsql._hub = hub:getId()
		end
	end
)

dcpp:setListener( "userQuit", "ipsql",
	function( hub, nick )
		if ipsql._sessnick[nick] then ipsql._sessnick[nick] = nil end
	end
)
--
-- dcpp:setListener( "raw", "ipsql",
-- 	function(hub, msg)
-- 		local r,_,ip,ip123,ip4 = string.find(msg, "((%d+%.%d+%.%d+)%.(%d+)):%d+")
-- 		if not ipsql._iptable[ip] then
-- 			if ipsql._spystart and not ipsql._searchip[ip] and r then
-- 				ipsql._searchip[ip] = true
-- 				for x4 = 1,255 do
-- 					local x = ip123.."."..tostring(x4)
-- 					if ipsql._iptable[x] and x4 ~= tonumber(ip4) then
-- 						for nick,_ in pairs(ipsql._iptable[x]) do
-- 							if hub._users[nick] and not ipsql._sessnick[nick] then
-- 								DC():SendHubMessage( hub:getId(), "$ConnectToMe "..nick.." "..ipsql._myip..":"..ipsql._myport.."|")
-- 							end
-- 						end
-- 					end
-- 				end
-- 			end
-- 		end
-- 	end
-- )
--
dcpp:setListener("timer", "ipsql",
	function()
		ipsql._counter,ipsql._synccounter,ipsql._checkcounter = ipsql._counter + 1,ipsql._synccounter + 1,ipsql._checkcounter + 1
		if ipsql._counter >= ipsql._interval then
			if ipsql._checkco and ipsql._checknick and coroutine.status(ipsql._checkco)== "suspended" then
				coroutine.resume(ipsql._checkco,ipsql._checknick) end
			if ipsql._syncco and ipsql._syncnick and coroutine.status(ipsql._syncco)== "suspended" then
				coroutine.resume(ipsql._syncco,ipsql._syncnick) end
			if ipsql._userconnectednick then
				DC():SendHubMessage( ipsql._hub, "$ConnectToMe "..ipsql._userconnectednick.." "..ipsql._myip..":"..ipsql._myport.."|")
			end
			if ipsql._startsync then
				ipsql._startsync = nil
				ipsql._syncstatus,ipsql._synccount = 0,0
				for _,hub in pairs(dcpp:getHubs()) do
					for k in pairs(hub._users) do
						if (not hub._users[k]._op and not ipsql._nicktable[DC():ToUtf8(hub._users[k]._nick)] and not ipsql._sessnick[hub._users[k]._nick]) then
							ipsql._synccount = ipsql._synccount + 1
						end
					end
				end
				ipsql._syncco = coroutine.create(
					function()
						for _,hub in pairs(dcpp:getHubs()) do
							for k,_ in pairs(hub._users) do
								if not hub._users[k]._op and not ipsql._nicktable[DC():ToUtf8(hub._users[k]._nick)] and not ipsql._sessnick[hub._users[k]._nick] then
									DC():SendHubMessage( hub:getId(),
									"$ConnectToMe "..hub._users[k]._nick.." "..ipsql._myip..":"..ipsql._myport.."|")
									ipsql._syncnick = hub._users[k]._nick
									local resendnick = coroutine.yield()
									local i = 1
									while resendnick and (i<3) do
										if not ipsql._sessnick[resendnick] then
											DC():SendHubMessage( hub:getId(),
											"$ConnectToMe "..resendnick.." "..ipsql._myip..":"..ipsql._myport.."|")
										end
										ipsql._syncnick = resendnick
										resendnick = coroutine.yield()
										i = i + 1
									end
								end
							end
						end
						ipsql._syncco = nil
					end
				)
				coroutine.resume(ipsql._syncco)
			end
			if ipsql._startcheck then
				ipsql._startcheck = nil
				ipsql._checkstatus,ipsql._checkcount = 0,0
				for _,hub in pairs(dcpp:getHubs()) do
					for k in pairs(hub._users) do
						if (not hub._users[k]._op and ipsql._nicktable[hub._users[k]._nick] and not ipsql._sessnick[hub._users[k]._nick]) then
							ipsql._checkcount = ipsql._checkcount + 1
						end
					end
				end
				ipsql._checkco = coroutine.create(
					function()
						for _,hub in pairs(dcpp:getHubs()) do
							for k,_ in pairs(hub._users) do
								if not hub._users[k]._op and ipsql._nicktable[DC():ToUtf8(hub._users[k]._nick)] and not ipsql._sessnick[hub._users[k]._nick] then
									DC():SendHubMessage( hub:getId(),
									"$ConnectToMe "..hub._users[k]._nick.." "..ipsql._myip..":"..ipsql._myport.."|")
									ipsql._checknick = hub._users[k]._nick
									local resendnick = coroutine.yield()
									local i = 1
									while resendnick and (i<3) do
										if not ipsql._sessnick[resendnick] then
											DC():SendHubMessage( hub:getId(),
											"$ConnectToMe "..resendnick.." "..ipsql._myip..":"..ipsql._myport.."|")
										end
										ipsql._checknick = resendnick
										resendnick = coroutine.yield()
										i = i + 1
									end
								end
							end
						end
						hub:addLine("*** iptable check complete ")
						ipsql._checkco  = nil
					end
				)
				coroutine.resume(ipsql._checkco)
			end
			ipsql._counter = math.fmod(ipsql._counter,ipsql._interval)
		end
		if ipsql._checkcounter >= ipsql._checkinterval and not ipsql._checkco then
			ipsql._startcheck = true
			ipsql._checkcounter = math.fmod(ipsql._checkcounter,ipsql._checkinterval)
		end
		if ipsql._synccounter >= ipsql._syncinterval and not ipsql._syncco then
			ipsql._startsync = true
			ipsql._synccounter = math.fmod(ipsql._synccounter,ipsql._syncinterval)
		end
	end
)

dcpp:setListener("clientIn", "ipsql",
	function(userp,line)
		local s,_,nick = string.find(line,"^%$MyNick (.*)$")
		if s then
			ip = DC():GetClientIp(userp)
			ipsql._sessnick[nick] = true
			nick=DC():ToUtf8(nick)
			if (ipsql._syncnick == nick) then
				ipsql._syncstatus = ipsql._syncstatus + 1
				ipsql._syncnick = nil DC():DropUserConnection(userp)
				if ipsql._syncco then coroutine.resume(ipsql._syncco) end
			end
			if ipsql._checknick == nick then
				ipsql._checkstatus = ipsql._checkstatus + 1
				ipsql._checknick = nil DC():DropUserConnection(userp)
				if ipsql._checkco then coroutine.resume(ipsql._checkco) end
			end
			if ipsql._userconnectednick == nick then
				ipsql._userconnectednick = nil DC():DropUserConnection(userp)
			end

			local cursor = ipsql.con:execute("SELECT nick,ip FROM ip_nick_state WHERE ip=\""..ip.."\" OR BINARY nick=\""..nick.."\"")
			local sqlnick,sqlip
			if (cursor:numrows() == 0) then
				--print(nick,ip)
				ipsql.con:execute("INSERT INTO ip_nick_state VALUES(\""..ip.."\",\""..nick.."\",NOW())")
			elseif (cursor:numrows() == 1) then
				sqlnick,sqlip = cursor:fetch()
				if sqlnick==nick and sqlip==ip then
					ipsql.con:execute("UPDATE ip_nick_state SET time = NOW() WHERE ip=\""..ip.."\" AND BINARY nick=\""..nick.."\"")
				elseif sqlip==ip then
					ipsql.con:execute("UPDATE ip_nick_state SET time = NOW(), nick=\""..nick.."\" WHERE ip=\""..ip.."\"")
				elseif sqlnick==nick then
					ipsql.con:execute("UPDATE ip_nick_state SET time = NOW(), ip=\""..ip.."\" WHERE BINARY nick=\""..nick.."\"")
-- 				else
-- 					print("luasql library malfunctioning "..ip,nick,sqlip,sqlnick)
				end
			elseif (cursor:numrows() == 2) then
				sqlnick,sqlip = cursor:fetch()
				if (sqlip==ip and sqlnick ~= nick) then
					ipsql.con:execute("DELETE from ip_nick_state WHERE BINARY nick=\""..nick.."\"")
					ipsql.con:execute("UPDATE ip_nick_state SET time = NOW(), nick=\""..nick.."\" WHERE ip=\""..ip.."\"")
-- 					print("Here We Go! ip collition:",nick,ip)
				elseif (sqlnick==nick and sqlip ~= ip) then
					ipsql.con:execute("DELETE from ip_nick_state WHERE ip=\""..ip.."\"")
					ipsql.con:execute("UPDATE ip_nick_state SET time = NOW(), ip=\""..ip.."\" WHERE BINARY nick=\""..nick.."\"")
-- 					print("Here We Go! nick collition:",nick,ip)
				end
-- 			else
-- 				print("eiskaltdcpp application malfunctioning")
			end
			cursor:close()
			cursor=nil sqlnick=nil sqlip=nil
			local cursor = ipsql.con:execute("SELECT nick,ip FROM ip_nick_raw WHERE ip=\""..ip.."\" OR BINARY nick=\""..nick.."\"")
			if (cursor:numrows() == 0) then
				ipsql.con:execute("INSERT INTO ip_nick_raw VALUES(\""..ip.."\",\""..nick.."\",NOW())")
			elseif (cursor:numrows() > 0) then
				local sqlnick,sqlip = cursor:fetch()
				local found = false
				while (sqlnick) do
					if sqlnick==nick and sqlip==ip then
						found = true
						ipsql.con:execute("UPDATE ip_nick_raw SET time = NOW() WHERE ip=\""..ip.."\" AND BINARY nick=\""..nick.."\"")
						--print("Update entry:",ip,nick)
						break
					end
					sqlnick,sqlip = cursor:fetch()
				end
				if not found then
					ipsql.con:execute("INSERT INTO ip_nick_raw VALUES(\""..ip.."\",\""..nick.."\",NOW())")
					--print("New entry:",ip,nick)
				end
				sqlnick=nil sqlip=nil
			end
			cursor:close()
			cursor=nil
		end
	end
)
--
-- dcpp:setListener("connected", "ipsql",
-- 	function(hub)
-- 		ipsql._myip = "10.111.2.220"--dcpp.sysip()
-- 		ipsql._userconnectstart,ipsql._spystart = true,true
-- 		DC():PrintDebug("  ** using system ip: "..ipsql._myip.."**")
-- 		ipsql._sessnick = {}
-- 		ipsql._startcheck,ipsql._startsync = true,true
-- 	end
-- )
--
print( "  ** Loaded ipsql.lua **" )
