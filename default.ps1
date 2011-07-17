
# http://sueetie.com/wiki/UsingAtomo.ashx

properties {
	$atomoZip = "C:\inetpub\Sueetie.Atomo.3.2.0.zip"
	$siteTarget = "c:\inetpub\Sueetie.Atomo.Test"
}

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


task BuildAtomo {}
task CreateAtomoInIIS {}
task ConfigureAtomo {
    # update connection string
	# update WCF endpoints
}

task RunAtomoFirstrun {}

task RunAtomoChecklist {
    # http://sueetie.com/wiki/GummyBearSetup.ashx#Post-Installation_Checklist_10
}

task TestDeploy -depends Cleanup, UnzipAtomo, BuildAtomo, CreateAtomoInIIS, ConfigureAtomo, RunAtomoFirstrun, RunAtomoChecklist