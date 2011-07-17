
# http://sueetie.com/wiki/UsingAtomo.ashx

task default -depends TestDeploy

task CleanupDeploymentDirectory { }
task CleanupDeploymentDatabase { }
task Cleanup -depends CleanupDeploymentDirectory, CleanupDeploymentDatabase {}
task UnzipAtomo {}
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