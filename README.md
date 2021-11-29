# docker-winebased-server-base

# Table of contents
<!-- vim-markdown-toc GFM -->

* [Basic Docker Usage](#basic-docker-usage)
	* [Default User](#default-user)
* [Environment Variables](#environment-variables)
* [System requirements](#system-requirements)
* [Deployment](#deployment)
	* [Deploying with Docker and systemd](#deploying-with-docker-and-systemd)
	* [Deploying with docker-compose](#deploying-with-docker-compose)
* [License](#license)

<!-- vim-markdown-toc -->

# Basic Docker Usage

The container directory `/opt/data` contains files outside of the running container. It can optionally be mounted to avoid having to download wine applications on each fresh start. 

```
$ docker run -d \
    --name docker-winebased-server-base \
    -e VNC_PASSWORD=mypassword \
    -e HTTP_PASSWORD=mypassword \
    -e USERNAME=`id -n -u` \
    -e USERID=`id -u` \
    -e PASSWORD=password \
    -p 5900:5900/tcp \ 
    -p 9000:9000/tcp \
    -v /path/to/data:/opt/data \
    Toetje585/docker-winebased-server-base
```

# Default-User
--------------------

The default user is `root`. You may change the user and password respectively by `USERNAME`, `USERID` and `PASSWORD` environment variables as seen by [Basic Docker Usage](#basic-docker-usage).

# License

Apache License Version 2.0, January 2004 http://www.apache.org/licenses/LICENSE-2.0

Original work by [Doro Wu](https://github.com/fcwu) and [Frédéric Boulanger](https://github.com/Frederic-Boulanger-UPS

Adapted by [Toetje585](https://github.com/Toetje585/)
