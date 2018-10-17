Configuration DataDisk
{
    Import-DSCResource -ModuleName xStorage

    Node localhost
    {
        xWaitforDisk 'Disk2'
        {
            diskid = 2
            RetryIntervalSec = 60
            Retrycount = 60
        }

        xDisk "FVolume"
        {
            Diskid = 2
            DriveLetter = 'F'
            FSLabel = 'Data'
        }
 	File FileDemo 
	{
	    DependsOn = "[xDisk]FVolume"
            DestinationPath = 'F:\folder\Task7.txt'
            Ensure = "Present"
            Contents = 'hello world'
        }

    }
}