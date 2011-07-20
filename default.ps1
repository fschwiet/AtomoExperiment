
# http://sueetie.com/wiki/UsingAtomo.ashx

properties {
	$baseDir = (resolve-path .).Path
	$atomoZip = "C:\inetpub\Sueetie.Atomo.3.2.0.zip"
	$siteTarget = "c:\inetpub\Sueetie.Atomo.Test"

	$buildTestDir = "$baseDir\build"
    
    $applicationPoolName = "atomotest"

    $connectionString = "data source=(local);initial catalog=atomoexperiment;integrated security=SSPI"

    $targetHostName = "atomotest"
}

import-module .\tools\PSUpdateXml\PSUpdateXml.psm1

task default -depends TestDeploy

task CleanupIISConfig {

    $appPoolPath = "IIS:\AppPools\$applicationPoolName";

    if (test-path $appPoolPath) {

        $appPool = gi $appPoolPath;

        ls "IIS:\sites" | ? { $_.applicationPool -eq $appPool.name } | remove-item -recurse

        $appPool | remove-item -recurse
    }
}

task CleanupDeploymentDirectory { 

	if (test-path $siteTarget) {
		$null = rm $siteTarget -recurse -force
	}
}

task CleanupDeploymentDatabase { }

task Cleanup -depends CleanupIISConfig, CleanupDeploymentDirectory, CleanupDeploymentDatabase {}

task UnzipAtomo {

	"Unzipping atomo to $siteTarget..." | write-host
	$null = exec {  & ".\tools\7-Zip\7za.exe" x $atomoZip "-o$siteTarget" }
}

task FixAtomoBuild {

	cp "$baseDir\tools\MSBuild.MSVS" "$siteTarget\tools\MSBuild.MSVS" -rec -force
	$msBuildExtensionsPath = "$siteTarget\tools\MSBuild.MSVS"

	foreach($csproj in (gci $siteTarget *.csproj -rec | % { $_.fullname })) {
	
		"updating $csproj..." | write-host
		update-xml $csproj {
		
			add-xmlnamespace "ns" "http://schemas.microsoft.com/developer/msbuild/2003"
			
			$script:needsBuildExtensions = $false;
			$script:needsImportAdded = $false;
			
			for-xml  "//ns:Import" {
				$project = get-xml "@Project"
				
				if (($project -ne $null) -and $project.Contains("`$(MSBuildExtensionsPath32)")) {
					$script:needsBuildExtensions = $true;
				}
				
				if (get-xml "@Condition") {
					$script:needsImportAdded = $true;
				}
			}
			
			if ($script:needsBuildExtensions) {
				prepend-xml -atLeastOnce "ns:Project" "<PropertyGroup>
					 <MSBuildExtensionsPath32>$msBuildExtensionsPath</MSBuildExtensionsPath32>
				</PropertyGroup>";
			}
			
			if ($script:needsImportAdded) {
				append-xml "ns:Project" "<Import Project=""`$(MSBuildExtensionsPath32)\Microsoft\VisualStudio\v10.0\WebApplications\Microsoft.WebApplication.targets""/>"
			}
			
			for-xml "//ns:Content" {
				$include = get-xml "@Include"
				if ($include -and $include.Startswith("images\slideshows\slide")) {
                    "removing $include" | write-host -fore green
					remove-xml "."
				}
			}
			
			for-xml "//ns:HintPath" {
				$value = get-xml "."
				if ($value -eq "..\References\Lib\Anthem.NET\Anthem.dll") {
					"patching HintPath to anthem.dll" | write-host -fore green
					set-xml "." "..\..\Lib\ScrewTurn304\Anthem.dll"
				}
			}
		}
	}
}


task BuildAtomo {
	$v4_net_version = (ls "$env:windir\Microsoft.NET\Framework\v4.0*").Name
	$atomoSolutionPath = "$siteTarget\source\Sueetie.Atomo.3.2.sln"

	exec { &"C:\Windows\Microsoft.NET\Framework\$v4_net_version\MSBuild.exe" $atomoSolutionPath /T:"Clean,Build" }
}


task InstallIISAndImportTools {

	# WebAdministration module requires we run in x64
	if ($env:ProgramFiles.Contains("x86")) {
		throw "IIS module WebAdministration requires powershell be running in 64bit."
	}

	try
	{
		import-module WebAdministration
	}
	catch
	{
		"Installing IIS... (this is slow...  this only runs if WebAdministration is not installed)" | write-host -fore yellow

		#
		# http://technet.microsoft.com/en-us/library/cc722041%28v=WS.10%29.aspx
		#
		# Feature names are case-sensitive, and you will get no warnings if you mispell a feature or
		# do not include prerequisite features first.  Proceed with care.
		#

		function InstallFeature($name) {
			cmd /c "ocsetup $name /passive"
		}

		InstallFeature IIS-WebServerRole
			InstallFeature IIS-WebServer
				InstallFeature IIS-CommonHttpFeatures
					InstallFeature IIS-DefaultDocument
					InstallFeature IIS-DirectoryBrowsing
					InstallFeature IIS-HttpErrors
					InstallFeature IIS-HttpRedirect
					InstallFeature IIS-StaticContent
				InstallFeature IIS-HealthAndDiagnostics
					InstallFeature IIS-CustomLogging
					InstallFeature IIS-HttpLogging
					InstallFeature IIS-HttpTracing
					InstallFeature IIS-LoggingLibraries
				InstallFeature IIS-Security
					InstallFeature IIS-RequestFiltering
					InstallFeature IIS-WindowsAuthentication
				InstallFeature IIS-ApplicationDevelopment
					InstallFeature IIS-NetFxExtensibility
					InstallFeature IIS-ISAPIExtensions
					InstallFeature IIS-ISAPIFilter
					InstallFeature IIS-ASPNET
			InstallFeature IIS-WebServerManagementTools 
				InstallFeature IIS-ManagementConsole 
				InstallFeature IIS-ManagementScriptingTools
				
			InstallFeature WCF-HTTP-Activation

		import-module WebAdministration
		
	}
}



function CreateApplicationPool($applicationPoolName) {

    $appPool = new-item "IIS:\AppPools\$applicationPoolName"

    $appPool.processModel.pingingEnabled = "False"
    $appPool.managedPipelineMode = "Integrated"
    $appPool.managedRuntimeVersion = "v4.0"
    $appPool | set-item
}


function CreateSite($host, $applicationPoolName, $physicalPath) {

    $sitePath = "iis:\sites\$host-atomo";

    $site = new-item $sitePath -bindings @{protocol="http";bindingInformation="*:80:" + $host} -physicalPath $physicalPath
    
    Set-ItemProperty $site.PSPath -name applicationPool -value $applicationPoolName
    
    $sitePath
}

function CreateApplication($sitePath, $name, $physicalPath) {

    $application = new-item "$sitePath\$name" -physicalPath "$physicalPath\$site" -type Application
}


task CreateAtomoInIIS -depends InstallIISAndImportTools {

    $physicalPath = "$siteTarget\source\WebApplication";
        
    CreateApplicationPool $applicationPoolName
    
    $sitePath = CreateSite -host $targetHostName -applicationPoolName $applicationPoolName -physicalPath $physicalPath
    
    CreateApplication -sitePath $sitePath -name "blog" -physicalPath "$physicalPath\blog"
    CreateApplication -sitePath $sitePath -name "forum" -physicalPath "$physicalPath\forum"
    CreateApplication -sitePath $sitePath -name "media" -physicalPath "$physicalPath\media"
    CreateApplication -sitePath $sitePath -name "wiki" -physicalPath "$physicalPath\wiki"

    $null = icacls $physicalPath /remove:g "BUILTIN\IIS_IUSRS"
    $null = icacls $physicalPath /grant "BUILTIN\IIS_IUSRS:(OI)(CI)(RX)" 

    "Granting read/execute permissions to $physicalPath" | write-host -fore green

    ("images\avatars", "blog\app_data", "blog\web.config", "forum\uploads", "media\gs\mediaobjects", "wiki\public", "util\index", "util\marketplace\downloads") | % {
    
        $subpath = "$physicalPath\$_"
        "Granting write permissions to $subpath" | write-host -fore green
        icacls $subpath /grant "BUILTIN\IIS_IUSRS:(OI)(CI)(M)" 
    }
}



task ConfigureAtomo {

    $original = [Regex]::Escape("data source=(local);initial catalog=AtomoDB;integrated security=SSPI")
    $originalHost = [Regex]::Escape("http://atomo");

    foreach($configFile in (gci C:\inetpub\Sueetie.Atomo.Test *.config -rec | % { $_.fullname})) {

        (get-content $configFile) | 
            % { $_ -replace $original, $connectionString } | 
            % { $_ -replace $originalHost, "http://$targetHostName" } |
            set-content $configFile
    }

	# update WCF endpoints
}

task RunAtomoFirstrun {}

task RunAtomoChecklist {
	# http://sueetie.com/wiki/GummyBearSetup.ashx#Post-Installation_Checklist_10
}

task TestDeploy -depends Cleanup, UnzipAtomo, FixAtomoBuild, BuildAtomo, CreateAtomoInIIS, ConfigureAtomo, RunAtomoFirstrun, RunAtomoChecklist
{
}