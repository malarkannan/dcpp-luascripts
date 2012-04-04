----	Mirror Chat Script
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
---- mirror.lua -- just repeats what others chat in the hub :P
----

local string = string
local mirrornick = "+none"

dcpp:setListener( "ownChatOut", "MirrorChat",
	function( hub, msg, ret )
		if string.sub( msg, 1, 1 ) ~= "/" then
			return nil
		elseif string.sub( msg, 2, 5 ) == "help" then
			hub:injectChat( "*** (mirror.lua) /mirror [all/me/user/none]" )
		elseif string.sub( msg, 2, 8 ) == "mirror " then
			local rest = string.sub(msg, 9)
			if rest == "+all" then
				mirrornick = "+all"
				hub:injectChat( "*** mirroring all users " )
				return 1
			elseif rest == "+none" then
				mirrornick = "+none"
				hub:injectChat( "*** mirroring  no user" )
				return 1
			elseif rest == "+me" then
				mirrornick = "+me"
				hub:injectChat( "*** mirroring only users using my nick" )
				return 1
			elseif string.find(rest," ") then
				hub:injectChat( "*** (mirror.lua) /mirror [+all/+me/nick/+none]" )
				return 1
			else
				mirrornick = rest
				hub:injectChat( "*** mirroring  user: "..rest )
				return 1
			end
		elseif string.sub( msg, 2, 8 ) == "mirror" then
			hub:addLine( "/mirror [-all/-me/nick/-none]\n\t currently mirroring "..mirrornick, true )
			return 1
		end
	end
)

dcpp:setListener("chat", "MirrorChat",
	function(hub,user,msg)
		local sendtxt,x,y = msg,0,0
		sendtxt,x = string.gsub(string.lower(sendtxt),string.gsub(string.gsub(string.lower(hub:getOwnNick()),"%A",".?"),"[aeiouw]",".?"),user._nick)
		--hub:addLine( hub:getOwnNick():lower(), true )
		sendtxt,y = string.gsub(sendtxt,"(%s*)i(%s+)am","%1you are%2")
		--"%a(.-)%p%a(.-)","[gG]%1%%A[bB]%2"
		if msg:len() > 150 then
			hub:addLine("*** MESSAGE LIMIT EXCEEDED!!!",true)
			return nil
		end
		if mirrornick == "+none" then
			return nil
		elseif mirrornick == "+me" then
			if x ~= 0 then
				hub:sendChat(sendtxt)
				return nil
			end
		elseif mirrornick == user._nick then
			hub:sendChat(sendtxt)
			return nil
		elseif mirrornick == "+all" then
			hub:sendChat(sendtxt)
			return nil
		else
			return nil
		end
	end
)

DC():PrintDebug("  ** Loaded mirror.lua **")
