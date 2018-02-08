# Build

`kubash build`

### builder options

`--builder packer` This will build images using packer

`--builder coreos` This will download the official coreos images

### OS options

`--target-os ubuntu` This will build ubuntu images

`--target-os debian` This will build debian images

`--target-os fedora` This will build fedora images

`--target-os centos` This will build centos images

`--target-os coreos` This will build coreos images (* no packer build for this)

### Target build

For the packer build you can specify alternate json files to use

`--target-build my-alternate.json` This must exist in `$KUBASH_DIR/pax/$target_os/my-alternate.json`

For the coreos option this sets the channel (stable,beta,alpha)

`--target-build beta`
