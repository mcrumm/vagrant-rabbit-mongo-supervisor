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


### Troubleshooting

On first boot, if none of your assets (css, js) load, run the following command inside your `mybox` folder:

```bash
$ vagrant ssh -c "sudo service supervisor restart"
```

Run the following command to verify the background processes are now running:

```bash
$ vagrant ssh -e "ps aux | grep app/console"
```

You should see output similar to the following:

```
$ vagrant ssh -c "ps aux | grep app/console"
root     21804 20.5  5.5 184756 28084 ?        S    18:53   0:00 php app/console rabbitmq:consumer -m 20 my_consumer --env=dev
root     21805 72.5  9.1 203432 46516 ?        R    18:53   0:01 php app/console assetic:dump --watch --env=dev
vagrant  21814  0.0  0.1   8040   908 ?        S    18:53   0:00 grep app/console
```
