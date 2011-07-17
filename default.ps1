
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
	
		"$csproj..." | write-host
		update-xml $csproj {
		
			add-xmlnamespace "ns" "http://schemas.microsoft.com/developer/msbuild/2003"
			
			prepend-xml -atLeastOnce "ns:Project" "<PropertyGroup>
				 <MSBuildExtensionsPath32>$msBuildExtensionsPath</MSBuildExtensionsPath32>
			</PropertyGroup>";
			
			for-xml "//ns:Content" {
				$include = get-xml "@Include"
				if ($include -and $include.Startswith("images\slideshows\slide")) {
					remove-xml "."
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

task CreateAtomoInIIS {}
task ConfigureAtomo {
    # update connection string
	# update WCF endpoints
}

task RunAtomoFirstrun {}

task RunAtomoChecklist {
    # http://sueetie.com/wiki/GummyBearSetup.ashx#Post-Installation_Checklist_10
}

task TestDeploy -depends Cleanup, UnzipAtomo, FixAtomoBuild, BuildAtomo #, CreateAtomoInIIS, ConfigureAtomo, RunAtomoFirstrun, RunAtomoChecklist
{
}