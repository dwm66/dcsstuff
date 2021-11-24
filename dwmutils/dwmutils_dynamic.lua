env.info( '*** DWMUtils DYNAMIC INCLUDE START *** ' )

local base = _G
__DWMUtils =    {
                    BasePath = 'C:\\Users\\dwmin\\Saved Games\\DCS.openbeta\\Missions\\dcsstuff\\dwmutils\\'
                }

__DWMUtils.Include = function( IncludeFile )
	if not __DWMUtils.Includes[ IncludeFile ] then
		__DWMUtils.Includes[IncludeFile] = __DWMUtils.BasePath .. IncludeFile
		local f = assert( base.loadfile( __DWMUtils.Includes[IncludeFile] ) )
		if f == nil then
			error ("DWMUtils: Could not load DWMUtils file " .. __DWMUtils.Includes[IncludeFile] )
		else
			env.info( "DWMUtils: " .. __DWMUtils.Includes[IncludeFile] .. " dynamically loaded." )
			return f()
		end
	end
end

__DWMUtils.Includes = {}
-- C:\Users\dwmin\Saved Games\DCS.openbeta\Missions\dcsstuff\dwmutils\dwmutils_dev.lua
__DWMUtils.Include( 'dwmutils_dev.lua' )