vagrant-rabbit-mongo-supervisor
===============================

Vagrant box for PHP apps with MongoDB, RabbitMQ and supervisord

## Installation

```bash
$ cd ~/vagrant
$ git clone --recursive https://github.com/mcrumm/vagrant-rabbit-mongo-supervisor mybox
$ cd mybox
$ cp Vagrantfile.example Vagrantfile
$ vagrant up
```

## Updating

```bash
$ cd ~/vagrant/mybox
$ git pull
$ git submodule init
$ git submodule update
$ vagrant reload
```

## Configuration

```bash
$ cd ~/vagrant/mybox
$ vagrant ssh
$ cd /var/www/mybox.dev/
$ composer install
```

Enter all configuration values when prompted.
