# Qpoint Installer

This repo hosts an installation script for Qpoint.

```sh
# installs into /usr/local/bin/qpoint
curl -s https://get.qpoint.io/install | sudo sh
```

```sh
# downloads to a tmp dir which is cleaned up afterwards
curl -s https://get.qpoint.io/demo | sudo sh
```

#### Installing a specific version

You can specify a version via the `VERSION` env var:

```sh
curl -s https://get.qpoint.io/install | sudo VERSION=v0.9.10 sh
```

## What's Next?

For further instructions, see the [Qpoint docs](https://docs.qpoint.io/installation).