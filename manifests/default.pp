group { 'puppet': ensure => present }
Exec { path => [ '/bin/', '/sbin/', '/usr/local/bin/', '/usr/bin/', '/usr/sbin/' ] }
File { owner => 0, group => 0, mode => 0644 }

$real_hostname = "${::hostname}.dev"
$docroot       = "/var/www/${real_hostname}"
$real_docroot  = "${docroot}/web"

class { 'apt':
  always_apt_update    => true,
  purge_sources_list   => true,
  purge_sources_list_d => true,
  purge_preferences_d  => true
}

Class['::apt::update'] -> Package <|
    title != 'python-software-properties'
and title != 'software-properties-common'
|>

apt::source { 'debian':
  location    => 'http://ftp.us.debian.org/debian',
  release     => $lsbdistcodename,
  repos       => 'main contrib non-free',
  key         => '89DF5277',
  key_server  => 'keys.gnupg.net',
  include_src => true
}

apt::source { 'testing':
  location    => 'http://ftp.us.debian.org/debian',
  release     => 'testing',
  repos       => 'main contrib non-free',
  key         => '89DF5277',
  key_server  => 'keys.gnupg.net',
  include_src => true
}

package { 'apache2-mpm-prefork':
  ensure => 'installed',
  notify => Service['apache']
}

class { 'puphpet::dotfiles': }

package { [
    'build-essential',
    'vim',
    'git-core'
  ]:
  ensure  => 'installed'
}

class { 'apache': }

include apache::ssl

apache::module { 'rewrite': }

apache::vhost { $real_hostname:
  template          => '/vagrant/files/apache/vhost.conf.erb',
  server_name       => $real_hostname,
  docroot           => $real_docroot,
  port              => '80',
  priority          => '1',
  directory_options => 'FollowSymlinks'
}

apache::vhost { "${real_hostname}-ssl":
  template          => '/vagrant/files/apache/vhost-ssl.conf.erb',
  server_name       => $real_hostname,
  docroot           => $real_docroot,
  port              => '443',
  priority          => '1',
  directory_options => 'FollowSymlinks'
}

class { 'php':
  service             => 'apache',
  service_autorestart => true,
  module_prefix       => ''
}

$php_path     = "/etc/php5"
$php_ini      = "php.ini"
$php_modules  = "${php_path}/mods-available"
$php_apache   = "${php_path}/apache2"
$php_cli      = "${php_path}/cli"
$php_conf     = "conf.d"
$php_custom   = "${php_conf}/zzz_php.ini"
$php_timezone = "America/Los_Angeles"

php::module { 'php5-curl': }
php::module { 'php5-intl': }
php::module { 'php5-mcrypt': }
php::module { 'php5-mongo': }

file { "${php_apache}/${php_conf}/30-mongo.ini":
  ensure  => link,
  target  => "${php_modules}/mongo.ini",
  require => Php::Module['php5-mongo'],
  notify  => Service['apache']
}

file { "${php_cli}/${php_conf}/30-mongo.ini":
  ensure  => link,
  target  => "${php_modules}/mongo.ini",
  require => Php::Module['php5-mongo'],
  notify  => Service['apache']
}

class { 'php::devel':
  require => Class['php']
}

class { 'php::pear':
  require => Class['php']
}

if !defined(Package['git-core']) {
  package { 'git-core' : }
}

class { 'xdebug':
  service => 'apache'
}

file { '/etc/php5/conf.d':
  ensure  => 'directory',
  before  => File['/etc/php5/conf.d/suhosin.ini'],
  require => Class['php']
}

file { '/etc/php5/conf.d/suhosin.ini':
  ensure => present,
  before => Class['composer']
}

include 'augeas'

php::augeas {
  'php-apache2-disable_functions':
    entry   => 'PHP/disable_functions',
    ensure  => absent,
    target  => "${php_apache}/${php_ini}",
    require => [ Class['php'], Package['ruby-augeas'] ],
    notify  => Service['apache'];
  'php-apache2-date_timezone':
    entry  => 'Date/date.timezone',
    value  => "${php_timezone}",
    target  => "${php_apache}/${php_ini}",
    require => [ Class['php'], Package['ruby-augeas'] ],
    notify  => Service['apache'];
  'php-cli-disable_functions':
    entry   => 'PHP/disable_functions',
    ensure  => absent,
    target  => "${php_cli}/${php_ini}",
    require => [ Class['php'], Package['ruby-augeas'] ],
    notify  => Service['apache'];
  'php-cli-date_timezone':
    entry  => 'Date/date.timezone',
    value  => "${php_timezone}",
    target  => "${php_cli}/${php_ini}",
    require => [ Class['php'], Package['ruby-augeas'] ],
    notify  => Service['apache'];
}

class { 'composer':
  logoutput => true,
  require   => [
    Package['php5'],
    Package['ruby-augeas'],
    Class['::nodejs'] # nodejs module defines 'curl', also needed to install composer
  ]
}

puphpet::ini { 'xdebug':
  value   => [
    'xdebug.max_nesting_level = 300',
    'xdebug.default_enable = 1',
    'xdebug.remote_autostart = 0',
    'xdebug.remote_connect_back = 1',
    'xdebug.remote_enable = 1',
    'xdebug.remote_handler = "dbgp"',
    'xdebug.remote_port = 9000'
  ],
  ini     => "${php_apache}/${php_conf}/zzz_xdebug.ini",
  notify  => Service['apache'],
  require => Class['php']
}

puphpet::ini { 'php_conf_apache2':
  value   => [
    'display_errors = On',
    'error_reporting = -1'
  ],
  ini     => "${php_apache}/${php_custom}",
  notify  => Service['apache'],
  require => Class['php']
}

class { 'supervisord': }

supervisord::program { 'stagehand':
  command           => '/usr/bin/env php app/console rabbitmq:consumer -m 20 stagify --env=dev',
  user              => 'root',
  directory         => $docroot,
  stdout_logfile    => "${docroot}/app/logs/dev.log"
}

supervisord::program { 'assetic':
  command           => '/usr/bin/env php app/console assetic:dump --watch --env=dev',
  user              => 'root',
  directory         => $docroot,
  stdout_logfile    => "${docroot}/app/logs/dev.log"
}

class { 'mongodb':
  enable_10gen => true
}

include '::rabbitmq'

class { '::nodejs': }

file { '/usr/bin/node':
  ensure  => link,
  target  => '/usr/bin/nodejs',
  require => Package['npm']
}

package { [ 'bower', 'less', 'uglify-js', 'uglifycss' ]:
  provider => 'npm',
  require  => Class['::nodejs']
}

package { [ 'capistrano', 'capifony' ]:
  provider => 'gem'
}

exec { 'app':
  command     => "composer install --prefer-dist --profile -vvv",
  environment => 'HOME=/home/vagrant',
  cwd         => "${real_docroot}/../",
  user        => 'vagrant',
  onlyif      => "test -f ${real_docroot}/../composer.json",
  logoutput   => true,
  require     => [
    Class['apache', 'php', 'composer'],
    Package['bower']
  ],
  notify     => Service['supervisor']
}
