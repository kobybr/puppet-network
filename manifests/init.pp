#
# = Class: network
#
# This class installs and manages network
#
#
# == Parameters
#
# [*gateway*]
#   String. Optional. Default: undef
#   The default gateway of your system
#
# [*hostname*]
#   String. Optional. Default: undef
#   The hostname of your system
#
# [*interfaces_hash*]
#   Hash. Default undef.
#   The complete interfaces configuration (nested) hash
#   Needs this structure:
#   - First level: Interface name
#   - Second level: Interface options (check network::interface for the
#     available options)
#   If an hash is provided here, network::interfaces defines are declared with:
#   create_resources("network::interface", $interfaces_hash)
#
# Refer to https://github.com/stdmod for official documentation
# on the stdmod parameters used
#
class network (

  $hostname                  = $::fqdn,

  $interfaces_hash           = undef,

  # Parameters used only on RedHat family
  $sysconfig_file_template   = "network/sysconfig-${::osfamily}.erb",
  $gateway                   = undef,

  $package_name              = $network::params::package_name,
  $package_ensure            = 'present',

  $service_name              = $network::params::service_name,
  $service_ensure            = 'running',
  $service_enable            = true,

  $config_file_path          = $network::params::config_file_path,
  $config_file_require       = undef,
  $config_file_notify        = 'Service[network]',
  $config_file_source        = undef,
  $config_file_template      = undef,
  $config_file_content       = undef,
  $config_file_options_hash  = { } ,

  $config_dir_path           = $network::params::config_dir_path,
  $config_dir_source         = undef,
  $config_dir_purge          = false,
  $config_dir_recurse        = true,

  $dependency_class          = undef,
  $my_class                  = undef,

  $monitor_class             = undef,
  $monitor_options_hash      = { } ,

  $firewall_class            = undef,
  $firewall_options_hash     = { } ,

  $scope_hash_filter         = '(uptime.*|timestamp)',

  $tcp_port                  = undef,
  $udp_port                  = undef,

  ) inherits network::params {


  # Class variables validation and management

  validate_bool($service_enable)
  validate_bool($config_dir_recurse)
  validate_bool($config_dir_purge)
  if $config_file_options_hash { validate_hash($config_file_options_hash) }
  if $monitor_options_hash { validate_hash($monitor_options_hash) }
  if $firewall_options_hash { validate_hash($firewall_options_hash) }

  $config_file_owner          = $network::params::config_file_owner
  $config_file_group          = $network::params::config_file_group
  $config_file_mode           = $network::params::config_file_mode

  $manage_config_file_content = default_content($config_file_content, $config_file_template)

  $manage_config_file_notify  = $config_file_notify ? {
    'class_default' => 'Service[network]',
    ''              => undef,
    default         => $config_file_notify,
  }

  $manage_hostname = pickx($hostname, $::fqdn)

  if $package_ensure == 'absent' {
    $manage_service_enable = undef
    $manage_service_ensure = stopped
    $config_dir_ensure = absent
    $config_file_ensure = absent
  } else {
    $manage_service_enable = $service_enable
    $manage_service_ensure = $service_ensure
    $config_dir_ensure = directory
    $config_file_ensure = present
  }


  # Dependency class

  if $network::dependency_class {
    include $network::dependency_class
  }


  # Resources managed

  if $network::package_name {
    package { 'network':
      ensure   => $network::package_ensure,
      name     => $network::package_name,
    }
  }

  if $network::config_file_path
  and $network::config_file_source
  or $network::manage_config_file_content {
    file { 'network.conf':
      ensure  => $network::config_file_ensure,
      path    => $network::config_file_path,
      mode    => $network::config_file_mode,
      owner   => $network::config_file_owner,
      group   => $network::config_file_group,
      source  => $network::config_file_source,
      content => $network::manage_config_file_content,
      notify  => $network::manage_config_file_notify,
      require => $network::config_file_require,
    }
  }

  if $network::config_dir_source {
    file { 'network.dir':
      ensure  => $network::config_dir_ensure,
      path    => $network::config_dir_path,
      source  => $network::config_dir_source,
      recurse => $network::config_dir_recurse,
      purge   => $network::config_dir_purge,
      force   => $network::config_dir_purge,
      notify  => $network::manage_config_file_notify,
      require => $network::config_file_require,
    }
  }

  if $network::service_name {
    service { 'network':
      ensure     => $network::manage_service_ensure,
      name       => $network::service_name,
      enable     => $network::manage_service_enable,
      hasstatus  => false,
      status     => '/bin/true',
    }
  }


  # Create network interfaces from interfaces_hash, if present

  if $interfaces_hash {
    create_resources('network::interface', $interfaces_hash)
  }


  # Configure default gateway (On RedHat
  if $::osfamily == 'RedHat'
  and $gateway {
    file { '/etc/sysconfig/network':
      ensure  => $network::config_file_ensure,
      mode    => $network::config_file_mode,
      owner   => $network::config_file_owner,
      group   => $network::config_file_group,
      content => template($network::sysconfig_file_template),
      notify  => $network::manage_config_file_notify,
    }
  }


  # Extra classes

  if $network::my_class {
    include $network::my_class
  }

  if $network::monitor_class {
    class { $network::monitor_class:
      options_hash => $network::monitor_options_hash,
      scope_hash   => {}, # TODO: Find a good way to inject class' scope
    }
  }

  if $network::firewall_class {
    class { $network::firewall_class:
      options_hash => $network::firewall_options_hash,
      scope_hash   => {},
    }
  }

}
