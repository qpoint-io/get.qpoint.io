# Qcontrol Installer and Downloader

This repo hosts installation and download scripts for Qcontrol.

```sh
# installs into /usr/local/bin/qcontrol
curl -s https://get.qpoint.io/qcontrol/install | sudo sh
```

```sh
# downloads to current directory to be run as ./qcontrol
curl -s https://get.qpoint.io/qcontrol/download | sh
```

#### Installing or downloading a specific version

You can specify a version via the `VERSION` env var:

```sh
curl -s https://get.qpoint.io/qcontrol/install | sudo VERSION=v0.9.10 sh
curl -s https://get.qpoint.io/qcontrol/download | VERSION=v0.9.10 sh
```

## What's Next?

For further instructions, see the [Qcontrol docs](https://docs.qpoint.io/installation).
