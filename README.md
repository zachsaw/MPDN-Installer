# MPDN-Installer
NSIS Installer for MediaPlayerDotNet.

To be used with NSIS 3.0

## Variables
### Project Variables

Variable  						| Explanation
------------- 					| -------------
VER_MAJOR, VER_MINOR, VER_BUILD	| The version of the player.
PROJECT_NAME_LONG				| Set it to what you want, but better keep it as Media Player.NET.
PROJECT_NAME_SHORT				| Set it to what you want, but better keep it as MPDN.
PROJECT_NAME					| Set it to what you want, but better keep it as MediaPlayerDotNet.
ARCH							| Set the architecture of the player : x86 or x64.
SPECIAL_BUILD					| In case you want to create a special build, set this variable to the wanted value, else set it empty.

### .NET Variables
Those 3 variables set the needed version of the .NET framework. Using either a number for each or the wildcard (*) if the version is not important. For now SET MAJOR_NET=4 and the rest =*

* MAJOR_NET
* MINOR_NET				
* BUILD_NET