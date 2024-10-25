# VBox Manager API

> [!NOTE]
> The frontend for this project [here](https://github.com/alphatechnolog/vbox-manager-frontend), check it out aswell!

This project's purpose is to provide a simple solution for remote virtualbox-based machines management! And this is the api repository. The idea is to let you create/start/stop/remove virtual machines and also allow you to connect through ssh and even connect directly from the frontend itself via vnc! (or via an external vnc guest)

## Building this api

### Manual process

First install the next dependencies

- zig
- git
- virtualbox
- virtualbox-ext-vnc (on arch linux, on others you might need to manually install this extension)

Then go ahead and type these commands:

```sh
git clone https://github.com/AlphaTechnolog/vbox-manager-api.git
cd vbox-manager-api
zig build -Doptimize=ReleaseFast
sudo ./zig-out/bin/vbox-manager-api
```

This should start a new server process in the port 8080, you can test if it retrieves virtual machines from the root user by using

```sh
curl http://localhost:8080/list
```

> [!NOTE]
> This api is intended to be ran as the root user, so if not running with sudo, it will internally call sudo anyways and u might have to type the password when someone calls a request on the api. Also you can leave this running as some kind of daemon in your server, since if this process ends, it will kill all the running vms.

### Using [nix](https://nixos.org/download/)

Download git using your system's package manager and then you should be able to do this.

```sh
git clone https://github.com/AlphaTechnolog/vbox-manager-api.git
cd vbox-manager-api
sudo nix run '.#vbox-manager-api-release'
```

This should build vbox-manager-api and then run it immediatelly, if you get some kind of sha256 error for zig-cache or something related, take a look at the output of [check-zig-cache-hash.sh](./nix/build-support/check-zig-cache-hash.sh), you can either make a pull request with the generated changes or leave it that way.