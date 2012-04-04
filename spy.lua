----	IP Table Script
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
----
---- spy.lua -- alternate for the default searchspy but the real one showing even ip and nick !!!
---- linked with the spy for retrieving and updating details in it.
----

local string = string
local spy = {}
require "luasql.mysql"

spy.env=luasql.mysql()
spy.con = spy.env:connect("dcppdb","dcppuser","dcppp4ss","localhost")

spy._spyhall = {["AH "] = 1, ["BCR"] = 1,["GH "] = 1,["HJB"] = 1,["JCB"] = 1,
			["LLR"] = 1,["NH "] = 1,["PH"] = 1,["RK "] = 1,
			["RP "] = 1,["VS"] = 1,["ZH"] = 1,["MS "] = 1,
			["SAM"] = 1,["MMM"] = 1,["SNH"] = 1, ["MBM"] = 1}
spy._nicktable = {}
spy._iptable = {}
spy._subscribers = {}
spy._spynickfile = DC():GetAppPath() .. "luascripts/spynick.dat"
spy._spyipfile = DC():GetAppPath() .. "luascripts/spyip.dat"
spy._spywordfile = DC():GetAppPath() .. "luascripts/spyword.dat"
spy._sendpm = false
spy._subscribeswitch = false

function spy.loaderror(err)
	DC():PrintDebug( "*** spy.lua: file load/save error: " .. err)
end

function spy.spynickload()
	pickle.restore( spy._spynickfile, spy.loaderror )
	spy._spynick = spynickdata
	if not spy._spynick then spy._spynick = {} end
	spynickdata = nil
	DC():PrintDebug("  ** Loading spynick.dat **")
end

function spy.spyipload()
	pickle.restore( spy._spyipfile, spy.loaderror )
	spy._spyip = spyipdata
	if not spy._spyip then spy._spyip = {} end
	spyipdata = nil
	DC():PrintDebug("  ** Loading spyip.dat **")
end

function spy.spywordload()
	pickle.restore( spy._spywordfile, spy.loaderror )
	spy._spyword = spyworddata
	if not spy._spyword then spy._spyword = {} end
	spyworddata = nil
	DC():PrintDebug("  ** Loading spyword.dat **")
end

function spy.ipnickload(selectip,selectnick)
	if selectip or selectnick then
		if selectip then
			local cur = spy.con:execute("SELECT nick FROM ip_nick_state WHERE ip=\""..selectip.."\"")
			local nick = cur:fetch()
			spy._nicktable[nick]=ip spy._iptable[selectip]=nick nick=nil cur:close() cur = nil
			return nil
		elseif selectnick then
			local cur = spy.con:execute("SELECT ip FROM ip_nick_state WHERE BINARY nick=\""..selectnick.."\"")
			local ip = cur:fetch()
			spy._iptable[ip]=nick spy._nicktable[selectnick]=ip ip=nil cur:close() cur = nil
			return nil
		end
	end
	local cur = spy.con:execute("SELECT nick,ip FROM ip_nick_state")
	local nick,ip = cur:fetch()
	while nick do
		if spy._nicktable[nick] then spy._nicktable[nick]=ip print(nick) else spy._nicktable[nick]=ip end
		if spy._iptable[ip] then spy._iptable[ip]=nick print(ip) else spy._iptable[ip]=nick end
		nick,ip = cur:fetch()
	end
	cur:close()
	cur = nil
	return nil
end

function spy.spynicksave()
	pickle.store( spy._spynickfile, { spynickdata = spy._spynick },spy.loaderror )
end

function spy.spyipsave()
	pickle.store( spy._spyipfile, { spyipdata = spy._spyip },spy.loaderror )
end

function spy.spywordsave()
	pickle.store( spy._spywordfile, {spyworddata = spy._spyword},spy.loaderror)
end

spy.spynickload()
spy.spyipload()
spy.spywordload()
spy.ipnickload()

spy._wordpmsent = {}
for word in pairs(spy._spyword) do spy._wordpmsent[word]={} end

spy._ip2hall  = {[101]="AH ",[102]="BCR",[103]="GH ",[104]="HJB",[105]="JCB",
			[106]="LLR",[107]="MBM",[108]="NH ",[109]="PH" ,[110]="RK ",
			[111]="RP ",[112]="SNH",[113]="VS",[114]="ZH",[115]="MS ",
			[116]="SAM",[117]="MMM",}


function ip2nick(ip,hub)
	local strt = ""
	if not spy._iptable[ip] then
		spy.ipnickload(ip)
		if spy._iptable[ip] and hub._users[spy._iptable[ip]] then
			return spy._iptable[ip]
		end
	elseif spy._iptable[ip] and hub._users[spy._iptable[ip]] then
		return spy._iptable[ip]
	elseif spy._iptable[ip] then
		spy.ipnickload(ip)
		if spy._iptable[ip] and hub._users[spy._iptable[ip]] then
			return spy._iptable[ip]
		else
			for nick,_ in pairs(hub._users) do
				if (DC():ToUtf8(nick)==spy._iptable[ip]) then
					return nick
				end
			end
		end
	end
	return "******"
end

function spy.hallsearch(hub,ip2,ip,searchstring,hall,nick)
	if hall and spy._ip2hall[ip2] == hall then
		hub:injectPrivMsgFmt(hub:getOwnNick(), hub:getOwnNick(),
		hall.." \t\t-\t < "..nick.." > \t|\t"..ip..string.rep(" ",14-string.len(ip)).."\t|\t"..searchstring)
	end
end

dcpp:setListener( "ownChatOut", "spy",
	function( hub, msg, ret )
		if string.sub( msg, 1, 1 ) ~= "/" then
			return nil
		elseif string.sub( msg, 2, 5 ) == "help" then
			hub:injectChat( "*** (spy.lua) /<spynick/spyword/spyip/spyhall> [+list/+load/+del/+flush/+pm/+mag] <nick/hall>" )
		elseif string.sub( msg, 2, 9 ) == "spynick " then
			local rest = DC():FromUtf8(string.sub(msg,10))
			if rest == "+list" then
				hub:injectChat(" listing the nicks being spied")
				local out = "\n"
				for nick in pairs(spy._spynick) do
					out = out.."   "..(hub._users[nick] and (nick.."\t:online") or nick).."\n"
				end
				hub:addLine(out,true) out = nil
			elseif rest == "+load" then
				spy.spynickload()
			elseif rest == "+flush" then
				spy._spynick = {} spy.spynicksave() hub:injectChat(" cleared spynick table")
			elseif string.sub( msg, 10, 14) == "+off " then
				local nick = DC():FromUtf8(string.sub(msg,15))
				spy._spynick[nick] = true hub:injectChat(" adding the nick "..nick.." to be spied") spy.spynicksave()
			elseif string.sub( msg, 10, 14) == "+del " then
				local nick = string.sub(msg,15)
				if spy._spynick[nick] then
					spy._spynick[nick] = nil spy.spynicksave()
					hub:injectChat(" removing the nick "..nick.." from being spied")
				else hub:injectChat("  nick not found or added")
				end
			elseif hub._users[rest] then
				spy._spynick[rest] = true hub:injectChat(" adding the nick "..rest.." to be spied") spy.spynicksave()
			else hub:injectChat("  nick "..rest.." not online")
			end
			return 1
		elseif string.sub( msg, 2, 7 ) == "spyip " then
			local rest = string.sub(msg,8)
			if rest == "+list" then
				hub:injectChat(" listing the ips being spied")
				for ip in pairs(spy._spyip) do hub:injectChat("   "..ip) end
			elseif rest == "+cls" then
				spy._spyip = {} spy.spyipsave() hub:injectChat(" cleared spyip table")
			elseif string.sub( msg, 8, 12) == "+del " then
				local ip = string.sub(msg,13)
				if spy._spyip[ip] then
					spy._spyip[ip] = nil spy.spyipsave() hub:injectChat(" removing the ip "..ip.." from being spied")
				else hub:injectChat("ip not found or added")
				end
			elseif string.find(rest,"^%d+%.%d+%.%d+%.%d+") then
				spy._spyip[rest] = true hub:injectChat(" adding the ip "..rest.." to be spied") spy.spyipsave()
			end
			return 1
		elseif string.sub(msg,2,9) == "spyword " then
			local rest = string.lower(string.sub(msg,10))
			if rest == "+list" then
				hub:injectChat(" listing the words being monitored")
				for word in pairs(spy._spyword) do
					if spy._spyword[word]~= true then
						hub:injectChat("   "..word.." .. "..spy._spyword[word])
					else
						hub:injectChat("   "..word)
					end
				end
			elseif rest == "+cls" then
				spy._spyword = {} spy.spywordsave() hub:injectChat(" cleared spyword table")
			elseif rest == "+pm" then
				spy._sendpm = not spy._sendpm
				hub:injectChat(" sending pm for searches: "..(spy._sendpm and "on" or "off"))
			elseif string.sub( msg, 10, 14) == "+del " then
				local word = string.sub(msg,15)
				if spy._spyword[word] then
					spy._spyword[word] = nil spy.spywordsave()
					hub:injectChat(" removing the word "..word.." from being monitored")
				else hub:injectChat("word not found or added")
				end
			elseif string.sub( msg, 10, 14) == "+mag " then
				local word = string.sub(msg,15,(string.find(msg,"magnet.*")-2))
				spy._spyword[word]=string.sub(msg,string.find(msg,"magnet.*"))
				for word in pairs(spy._spyword) do spy._wordpmsent[word]={} end
				hub:injectChat(" adding the word: "..word.." - with magnet: "..spy._spyword[word].." to be spied")
				spy.spywordsave()
			else
				spy._spyword[rest] = true hub:injectChat(" adding the word "..rest.." to be spied") spy.spywordsave()
			end
			return 1
		elseif string.sub( msg, 2, 9 ) == "spyhall " then
			local rest = string.lower(string.sub(msg,10))
			if rest == "+list" then
				hub:injectChat(" listing the halls being spied")
				for hall in pairs(spy._spyhall) do hub:injectChat("   "..hall) end
			elseif rest == "+cls" then
				spy._spyhall = {} hub:injectChat("cleared spyhall table")
			elseif string.sub( msg, 10, 14) == "+del " then
				local removed = false
				rest = string.sub(msg,15)
				for _,hall in pairs(spy._ip2hall) do
					if string.find(string.lower(hall),rest) then spy._spyhall[hall],removed = nil,true
					hub:injectChat(" removing the hall "..hall.." from being spied") end
				end
				if not removed then hub:injectChat("hall not found") end
			else
				local added = false
				for _,hall in pairs(spy._ip2hall) do
					if string.find(string.lower(hall),rest) then spy._spyhall[hall],added = true,true
					hub:injectChat(" adding the hall "..hall.." to be spied") end
				end
				if not added then hub:injectChat("hall not found") end
			end
			return 1
		elseif string.sub(msg,2,11) == "subscribe " then
			local rest = string.sub(msg,12)
			if rest=="+off" then
				spy._subscribeswitch = false
				hub:injectChat(" turning off spy subscribers ")
			elseif rest=="+on"then
				spy._subscribeswitch = true
				hub:injectChat(" turning on spy subscribers ")
			elseif rest=="+list" then
				local out=""
				for nick,_ in pairs(spy._subscribers) do out = out..nick.." " end
				hub:injectChat(" listing subscribers "..out)
			else
				spy._subscribers[rest] = true
			end
			return 1
		end
	end
)

dcpp:setListener( "pm", "spy",
	function(hub,user,msg)
		if not user._op and spy._subscribeswitch then
			if not (spy._subscribers[user._nick]) then
				if msg=="+subscribe" then
					hub:sendPrivMsgTo(user._nick,"<"..hub:getOwnNick().."> "..
					"\nYou have subscribed successfully.\nType +unsubscribe to unsubscribe.\nType +help for more info",true)
					hub:injectPrivMsgFmt(user._nick,hub:getOwnNick(),"My IP: "..spy._nicktable[DC():ToUtf8(user._nick)])
					spy._subscribers[user._nick] = true
				end
			else
				if string.sub(msg,1,12)=="+unsubscribe" then
					spy._subscribers[user._nick]=nil
					hub:sendPrivMsgTo(user._nick,"<"..hub:getOwnNick().."> ".."Bye, "..user._nick,true)
				elseif string.sub(msg,1,12)=="+subscribers" then
					local out=""
					for nick,_ in pairs(spy._subscribers) do out = out..nick.." " end
					hub:sendPrivMsgTo(user._nick,"<"..hub:getOwnNick().."> "..out,true)
				elseif string.sub(msg,1,5)=="+help" then
					hub:sendPrivMsgTo(user._nick,"<"..hub:getOwnNick().."> "..
					"0. +help to show this message\n1.Type +unsubscribe to unsubscribe.\n2.Type +subscribers to list current subscribers",true)
				end
			end
		end
	end
)

dcpp:setListener( "raw", "spy",
	function(hub, msg)
		local r,_,searchip,ip1,ip2,ip3,ip4,port,filename = string.find(msg, "^%$Search ((%d+)%.(%d+)%.(%d+)%.(%d+)):(%d+) F%?T%?0%?[^9]%?(.*)")
		if r then
			local searchstring = string.gsub(filename,"%$"," ")
			local searchnick = ip2nick(searchip,hub)

			for hall in pairs(spy._spyhall) do spy.hallsearch(hub,tonumber(ip2),searchip,searchstring,hall,searchnick) end
			for nick in pairs(spy._spynick) do
				if not spy._nicktable[nick] then
					spy.ipnickload(nil,nick)
				end
				if hub._users[nick] and spy._nicktable[nick] then
					hub:injectPrivMsgFmt(nick, hub:getOwnNick(),"\t\tIP: "..searchip.."\t\tSearch: "..searchstring)
				end
			end
			for x in pairs(spy._spyip) do
				if x == searchip then hub:injectChat(" \t\tIP: "..ip.."\t\tSearch: "..searchstring) end
			end
			for word in pairs(spy._spyword) do
				if string.find(string.lower(searchstring),word) then
					for nick in pairs(type(spy._iptable[searchip])=="table" and spy._iptable[searchip] or {}) do
						if not spy._nicktable[nick] then
							spy.ipnickload(nil,nick)
						end
						if hub._users[nick] then
							print("user exists problem occured")
						end
						if hub._users[nick] and spy._nicktable[nick] == searchip then
							hub:injectPrivMsgFmt(nick, hub:getOwnNick(),"\t\tIP: "..searchip.."\t\tSearch: "..searchstring)
							if ip2 == "112" then spy._spynick[nick] = true end
							if spy._spyword[word]~=true and spy._sendpm and not spy._wordpmsent[word][nick] then
								spy._wordpmsent[word][nick] = true
								hub:sendPrivMsgTo(nick,"<"..hub:getOwnNick().."> "..
								"This is an automated response\n try this ;) "..spy._spyword[word],true)
							end
						end
					end
				end
			end

			if hub._subscribeswitch then
				for nick,_ in pairs(spy._subscribers) do
					if hub._users[nick] then
					      hub:sendPrivMsgTo(nick,"<"..hub:getOwnNick().."> ".."Nick : < "..searchnick..
					      " >\t Searching :\t"..searchstring,true)
	-- 				else spy._subscribers[nick]=false
					end
				end
			end

		end
	end
)

print("  ** Loaded spy.lua **")
