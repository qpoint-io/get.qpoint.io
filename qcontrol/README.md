# Qcontrol Installer

This repo hosts an installation script for Qcontrol.

```sh
# installs into /usr/local/bin/qcontrol
curl -s https://get.qpoint.io/qcontrol/install | sh
```

```sh
# downloads to current directory to be run as ./qcontrol
curl -s https://get.qpoint.io/qcontrol/demo | sh
```

#### Installing a specific version

You can specify a version via the `VERSION` env var:

```sh
curl -s https://get.qpoint.io/qcontrol/install | VERSION=v0.9.10 sh
```

## What's Next?

For further instructions, see the [Qcontrol docs](https://docs.qpoint.io/installation).
