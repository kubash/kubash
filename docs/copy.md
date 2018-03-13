# copy

`kubash copy`

or with a named cluster

`kubash -n mycluster copy`

This will parse your provision.csv and rsync the necessary images to the provisioning hosts, there is no need to execute this step manually as this step is part of the provision step, unless you are just prefetching, or testing.
