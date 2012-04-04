----    Unix Commands script :P
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
---- unix.lua --lets the cat out of the bag :P 
---- 			and implements many unix utilities
---- 			simple unix tools like script 
----			(no command-line parameters :P)
----

local lfs = require "lfs"

lfs.chdir(DC():GetAppPath())

dcpp:setListener( "ownChatOut", "Unix",
	function( hub, msg, ret )
		local curdir = lfs.currentdir()
		if string.sub( msg, 1, 1 ) ~= "/" then
			return nil
		elseif string.sub( msg, 2, 5 ) == "help" then
			hub:injectChat( "*** (unix.lua) /<cat/ls/cd/pwd/vi/nmap [all]> [filename/directory/ip]" )
		elseif string.sub( msg, 2, 5 ) == "cat " then
			--local script = string.sub( msg, 6 )
			local script,x = io.open(curdir.."\\"..string.sub( msg, 6 ),"r") if not script and x then hub:injectChat("cat : "..tostring(x)) return 1 end 
			local out,i = "\n",1
			for line in script:lines() do
				out = out..tostring(i).."\t"..line.."\n"
				i=i+1
			end
			hub:injectChat( out )
			return 1
		elseif string.sub( msg, 2, 3 ) == "ls" then
			local out = "\n"
			for f in lfs.dir(curdir) do
				if f ~= '.' and f ~= '..' then					
					if lfs.attributes(curdir.."\\"..f,'mode') == 'file' then
						out = out..f.."\n"
					else
						out = out..f.."\\\n"
					end
				end
			end
			hub:injectChat( out )
			return 1
		elseif string.sub( msg, 2, 4 ) == "pwd" then
			hub:injectChat( curdir )
			return 1
		elseif string.sub( msg, 2, 4 ) == "cd " then
			ch2dir = string.sub( msg, 5 )
			if ch2dir == "~/" then
				lfs.chdir(DC():GetAppPath().."Scripts\\")
			else
				lfs.chdir(ch2dir)
			end
			hub:injectChat("switched to "..lfs.currentdir() )
			return 1
		elseif string.sub( msg, 2, 4 ) == "vi " then
			return os.execute('start E:\\Progra~2\\Notepad++\\notepad++.exe '..string.sub( msg, 5 ))
			--DC():PrintDebug('" E:\\Progra~2\\Notepad++\\notepad++.exe" '..string.sub( msg, 5 ))
		elseif string.sub( msg, 2, 6 ) == "nmap " then
			if string.sub( msg, 7, 9 ) == "all" then
				return os.execute('start E:\\Progra~2\\Nmap\\zenmap.exe -p"Intense scan, no ping, all TCP ports" -t '..string.sub( msg, 11 ))
			elseif string.sub( msg, 7, 9) == "min" then
				return os.execute('start E:\\Progra~2\\Nmap\\zenmap.exe -p"Quick scan" -t '..string.sub( msg, 11 ))
			else
				return os.execute('start E:\\Progra~2\\Nmap\\zenmap.exe -p"Intense scan, no ping" -t '..string.sub( msg, 7 ))
			end
			--start E:\Progra~2\Nmap\zenmap.exe -p "Intense scan, no ping" -t 10.111.1.2
			--DC():PrintDebug('" E:\\Progra~2\\Notepad++\\notepad++.exe" '..string.sub( msg, 7 ))
		elseif string.sub( msg, 2, 5 ) == "exit" then
			os.exit(0)
		end
	end
)

DC():PrintDebug( "  ** Loaded unix.lua **" )
