--[[
	Cue-File-Parser is a freeee and simple parser for cue files.
	copyright <2026> by return5
	It is licenced under the GNU AGPL license only. no later versions of the license are valid unless otherwise specified.
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License only.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]--

local CueFileIndex <const> = 1   --arg[1] == cue file
local MusicFileIndex <const> = 2  --arg[2] == music file

local ParsedInfo <const> = {}
ParsedInfo.__index = ParsedInfo

function ParsedInfo:toString()
    return table.concat({'ffmpeg -i "',self.file,'" -ss ',self.start,"ms -to ",self.stop,'ms "',self.dest,self.track,"-",self.title,'.mp3"; '})
end

function ParsedInfo:new(track,title,start,file,dest)
    return setmetatable({start = start,track = track, title = title,file = file,dest = dest,stop = 0},self)
end

local DummyParse <const> = {}
DummyParse.__index = DummyParse
setmetatable(DummyParse,ParsedInfo)

function DummyParse:toString()
    return ""
end

local FinalParseInfo <const> = {}
FinalParseInfo.__index = FinalParseInfo
setmetatable(FinalParseInfo,ParsedInfo)

function FinalParseInfo:new(parsedInfo)
    return setmetatable(parsedInfo,self)
end

--final file to be processed should not include a '-to' nor final time stamp.  
function FinalParseInfo:toString()
    return table.concat({'ffmpeg -i "',self.file,'" -ss ',self.start,'ms "',self.dest,self.track,"-",self.title,'.mp3"; '})
end

local function parseMils(time)
    if time and time ~= "" then
        local minutes <const>, seconds <const>, mils <const> = time:match('(%d+):(%d+):(%d+)')
        return (tonumber(minutes or 0) * 60000) + (tonumber(seconds or 0) * 1000)
    end
    return 0
end

local function  getPWD()
    local pipe <const> = io.popen('echo -n "$PWD"')
    local dst <const> = pipe:read("*a")
    pipe:close()
    return dst
end

local function getDst()
    local dst <const> = arg[CueFileIndex]:match("(.+%/).+$")
    return dst and not dst:match("^%./$") and dst or getPWD() .. "/"
end

local function parseFile(text)
    local dst <const> = getDst()
    local dummyFirstValue <const> = DummyParse:new("","","","")
    local parsedFiles <const> = {dummyFirstValue}
    for track,title,start in text:gmatch('(%d+)%s+AUDIO.-TITLE%s*"+([^"]+)"+.-INDEX%s*01%s+([%d:]+)') do
        local startTime <const> = parseMils(start)
        parsedFiles[#parsedFiles].stop = startTime
        parsedFiles[#parsedFiles + 1] = ParsedInfo:new(track,title,parseMils(start),arg[MusicFileIndex],dst)
    end
    if #parsedFiles == 1 then return parsedFiles end
    parsedFiles[#parsedFiles] = FinalParseInfo:new(parsedFiles[#parsedFiles])
    return parsedFiles
end

local function getCuFile()
    if not arg[CueFileIndex] then
        io.stderr:write("error: did not include cue file\n")
        os.exit()
    end
    if not arg[CueFileIndex]:match(".+%.cue$") then
        io.stderr:write("did not include cue file. file is: ",arg[CueFileIndex],"\n")
        os.exit()
    end
    local file <const> = io.open(arg[CueFileIndex],"r")
    if not file then
        io.stderr:write("error opening cue file: ",arg[CueFileIndex],"\n")
        os.exit()
    end
    return file
end

local function checkMusicFile()
    if not arg[MusicFileIndex] then
        io.stderr:write("did not include a music file\n")
        os.exit()
    end
end

local function main()
    local file <const> = getCuFile()
    checkMusicFile()
    local parsedTbl <const> = parseFile(file:read("*a"))
    file:close()
    local cmdTbl <const> = {}
    for i=1,#parsedTbl,1 do
        cmdTbl[#cmdTbl + 1] = parsedTbl[i]:toString()
    end
   os.execute(table.concat(cmdTbl))
end

main()

