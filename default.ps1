
# http://sueetie.com/wiki/UsingAtomo.ashx

properties {
	$baseDir = (resolve-path .).Path
	$atomoZip = "C:\inetpub\Sueetie.Atomo.3.2.0.zip"
	$siteTarget = "c:\inetpub\Sueetie.Atomo.Test"

	$buildTestDir = "$baseDir\build"
}

import-module .\tools\PSUpdateXml\PSUpdateXml.psm1

task default -depends TestDeploy

task CleanupIISConfig {}

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
					remove-xml "."
				}
			}
			
			for-xml "//ns:HintPath" {
				$value = get-xml "."
				if ($value -eq "..\References\Lib\Anthem.NET\Anthem.dll") {
					"updating reference to anthem.dll" | write-host -fore green
					set-xml "." "..\..\Lib\ScrewTurn304\Anthem.dll"
				}
			}
		}
	}
}

task BuildAtomo {
	$v4_net_version = (ls "$env:windir\Microsoft.NET\Framework\v4.0*").Name
	$atomoSolutionPath = "$siteTarget\source\Sueetie.Atomo.3.2.sln"

	exec { &"C:\Windows\Microsoft.NET\Framework\$v4_net_version\MSBuild.exe" $atomoSolutionPath /T:"Clean,Build" /property:OutDir="$buildTestDir\" }
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


task CreateAtomoInIIS -depends InstallIISAndImportTools {

    $applicationPoolName = "atomotest"
    $physicalDirectory = "$siteTarget\source\WebApplication";
        
    CreateApplicationPool $applicationPoolName
    
    $site = CreateSite -host "atomotest" -physicalDirectory $physicalDirectory
    
    CreateApplication -site $site -name "blog" -physicalDirectory "$phsyicalDirectory\blog"
    CreateApplication -site $site -name "forum" -physicalDirectory "$phsyicalDirectory\forum"
    CreateApplication -site $site -name "media" -physicalDirectory "$phsyicalDirectory\media"
    CreateApplication -site $site -name "wiki" -physicalDirectory "$phsyicalDirectory\wiki"

    # grant permissions
}



task ConfigureAtomo {
	# update connection string
	# update WCF endpoints
}

task RunAtomoFirstrun {}

task RunAtomoChecklist {
	# http://sueetie.com/wiki/GummyBearSetup.ashx#Post-Installation_Checklist_10
}

task TestDeploy -depends Cleanup, UnzipAtomo, FixAtomoBuild, BuildAtomo, CreateAtomoInIIS, ConfigureAtomo, RunAtomoFirstrun, RunAtomoChecklist
{
}