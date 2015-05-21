# MPDN-Installer
NSIS Installer for MediaPlayerDotNet

## Variables
### Project Variables

Variable  			| Explanation
------------- 		| -------------
VERSION_STRING 		| The version of the player
SPECIAL_BUILD		| If it's a test build put it in this variable, else just set it as empty
PROJECT_NAME		| Set it to what you want, but better keep it as MediaPlayerDotNet.

### .NET Variables
Those 3 variables set the needed version of the .NET framework. Using either a number for each or the wildcard (*) if the version is not important. For now SET MAJOR_NET=4 and the rest =*

* MAJOR_NET
* MINOR_NET				
* BUILD_NET