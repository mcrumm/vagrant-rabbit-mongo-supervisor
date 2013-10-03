group { 'puppet': ensure => present }
Exec { path => [ '/bin/', '/sbin/', '/usr/bin/', '/usr/sbin/' ] }
File { owner => 0, group => 0, mode => 0644 }

$real_hostname = "${::hostname}.dev"
$docroot       = "/var/www/${real_hostname}"
$real_docroot  = "${docroot}/web"

class {'apt':
  always_apt_update => true,
}

Class['::apt::update'] -> Package <|
    title != 'python-software-properties'
and title != 'software-properties-common'
|>

apt::source { 'packages.dotdeb.org':
  location          => 'http://packages.dotdeb.org',
  release           => $lsbdistcodename,
  repos             => 'all',
  required_packages => 'debian-keyring debian-archive-keyring',
  key               => '89DF5277',
  key_server        => 'keys.gnupg.net',
  include_src       => true
}

if $lsbdistcodename == 'squeeze' {
  apt::source { 'packages.dotdeb.org-php54':
    location          => 'http://packages.dotdeb.org',
    release           => 'squeeze-php54',
    repos             => 'all',
    required_packages => 'debian-keyring debian-archive-keyring',
    key               => '89DF5277',
    key_server        => 'keys.gnupg.net',
    include_src       => true
  }
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

apache::dotconf { 'custom':
  content => 'EnableSendfile Off'
}

apache::module { 'rewrite': }

apache::vhost { $real_hostname:
  template      => '/vagrant/files/apache/vhost.conf.erb',
  server_name   => $real_hostname,
  docroot       => $real_docroot,
  port          => '80',
  priority      => '1',
  directory_options => 'FollowSymlinks'
}

class { 'php':
  service             => 'apache',
  service_autorestart => false,
  module_prefix       => ''
}

php::module { 'php5-cli': }
php::module { 'php5-curl': }
php::module { 'php5-intl': }
php::module { 'php5-mcrypt': }
php::module { 'php5-mongo': }

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

class { 'composer':
  require => [ Package['php5'], Class['::nodejs'] ]
}

puphpet::ini { 'xdebug':
  value   => [
    'xdebug.default_enable = 1',
    'xdebug.remote_autostart = 0',
    'xdebug.remote_connect_back = 1',
    'xdebug.remote_enable = 1',
    'xdebug.remote_handler = "dbgp"',
    'xdebug.remote_port = 9000'
  ],
  ini     => '/etc/php5/conf.d/zzz_xdebug.ini',
  notify  => Service['apache'],
  require => Class['php']
}

puphpet::ini { 'php':
  value   => [
    'date.timezone = "America/Los_Angeles"'
  ],
  ini     => '/etc/php5/conf.d/zzz_php.ini',
  notify  => Service['apache'],
  require => Class['php']
}

puphpet::ini { 'custom':
  value   => [
    'display_errors = On',
    'error_reporting = -1'
  ],
  ini     => '/etc/php5/conf.d/zzz_custom.ini',
  notify  => Service['apache'],
  require => Class['php']
}

class { 'supervisord': }

supervisord::program { 'stagehand':
  command           => '/usr/bin/env php app/console rabbitmq:consumer -m 20 stagify --env=dev',
  user              => 'vagrant-root',
  directory         => $docroot,
  stdout_logfile    => "${docroot}/app/logs/dev.log"
}

class { 'mongodb':
  enable_10gen => true
}

include '::rabbitmq'

package { [ 'python', 'g++', 'wget', 'tar' ]:
  ensure => present,
  before => Class['::nodejs']
}

class { '::nodejs':
  version     => 'v0.10.20',
  manage_repo => true
}

package { [ 'bower', 'less', 'uglify-js', 'uglifycss' ]:
  provider => 'npm',
  require  => Class['::nodejs']
}
