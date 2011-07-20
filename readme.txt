This is just some code to install Atomo 3.2 for testing on localhost.  The install is done via a psake script, which has filename 'default.ps1'.  To use the script,

1.  Download Sueetie.atomo.3.2.0.zip to c:\inetpub
2.  Create a database and give the iis application pool sufficient access (principal name is BUILTIN\IIS_IUSRS)
3.  Update the configuration properties section at the top of default.ps1
4.  If you've never run powershell scripts on this machine, you'll need to run:
    Set-ExecutionPolicy unrestricted
5.  From powershell, run:
    .\go.ps1
    