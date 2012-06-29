
# {{{ OpenStack base packages
class openstack::base {
  # parameter checking
  if (!$openstack_region) { $openstack_region = "RegionOne" }
  if (!$openstack_admin_tenant_name) { $openstack_admin_tenant_name = "admin" }
  if (!$openstack_admin_username) { $openstack_admin_username = "admin" }
  if (!$openstack_admin_password) { fail("required variable \$openstack_admin_password not defined.") }

  if (!$openstack_keystone_dbname) { $openstack_keystone_dbname = "keystone" }
  if (!$openstack_keystone_dbusername) { $openstack_keystone_dbusername = "keystone" }
  if (!$openstack_keystone_dbpassword) { fail("required variable \$openstack_keystone_dbpassword not defined.") }

  if (!$openstack_glance_dbname) { $openstack_glance_dbname = "glance" }
  if (!$openstack_glance_dbusername) { $openstack_glance_dbusername = "glancedbadmin" }
  if (!$openstack_glance_dbpassword) { fail("required variable \$openstack_glance_dbpassword not defined.") }

  if (!$openstack_nova_dbname) { $openstack_nova_dbname = "nova" }
  if (!$openstack_nova_dbusername) { $openstack_nova_dbusername = "novadbadmin" }
  if (!$openstack_nova_dbpassword) { fail("required variable \$openstack_nova_dbpassword not defined.") }

  if (!$openstack_network_gw_public_ipaddr) { $openstack_network_gw_public_ipaddr = $openstack_cc_ipaddr }
  if (!$openstack_network_size) { $openstack_network_size = "2048" } # this is a /21 block
  if (!$openstack_cc_ipaddr) { $openstack_cc_ipaddr = $::ipaddress }
  if (!$openstack_db_ipaddr) { $openstack_db_ipaddr = $openstack_cc_ipaddr }

  if (!$openstack_dhcp_domain) { $openstack_dhcp_domain = $::domain }

  # also export variables to system environment (i.e. /etc/environment on Ubuntu)
  env::system{"OS_TENANT_NAME": value => $openstack_admin_tenant_name}
  -> env::system{"OS_USERNAME": value => $openstack_admin_username}
  -> env::system{"OS_PASSWORD": value => $openstack_admin_password}
  -> env::system{"OS_AUTH_URL": value => "http://$openstack_cc_ipaddr:5000/v2.0/"}
  -> env::system{"OS_AUTH_STRATEGY": value => "keystone"}
  -> env::system{"OS_REGION": value => $openstack_region}

  # make sure the OS_* variables don't get stripped off by sudo command.
  file{"/etc/sudoers.d/openstack":
    ensure => present,
    mode => 0440,
    owner => root,
    group => root,
    content => "Defaults env_keep += \"OS_TENANT_NAME OS_USERNAME OS_PASSWORD OS_REGION_NAME OS_AUTH_URL 0S_AUTH_STRATEGY\"\n",
  }

  # install some helper scripts to all OpenStack nodes
  # to make day-to-day use with OpenStack a pleasure.
  file{"/usr/local/bin/os_instance_id":
    ensure => present,
    mode => 0555,
    owner => root,
    group => root,
    source => "puppet:///modules/openstack/os_instance_id.sh"
  }
} # }}}

# {{{ support classes / definitions
class openstack::support::vlan_enabled {
  kernel_module{"8021q":}
  sysctl{"net.ipv4.ip_forward": value => 1}
}
# }}}

# {{{ keystone: identity management
class openstack::keystone::client {
  package{"python-keystoneclient":}
}

class openstack::keystone::server {
  package{"keystone": ensure => installed}

  file {"/etc/keystone/keystone.conf":
    mode => 0640,
    owner => root,
    group => keystone,
    content => template("openstack/keystone/keystone.conf.erb"),
    require => Package["keystone"],
  }

  file {"/etc/keystone/default_catalog.templates":
    mode => 0640,
    owner => root,
    group => keystone,
    content => template("openstack/keystone/default_catalog.templates.erb"),
    require => Package["keystone"],
  }

  service {"keystone":
    ensure => undef,
    enable => false,
    hasrestart => true,
    require => [
      File["/etc/keystone/keystone.conf"],
      Package["keystone"],
    ],
    subscribe => File["/etc/keystone/keystone.conf"],
  }
} # }}}

# {{{ glance: image service
class openstack::glance::client {
  package{"glance-client":}
}
class openstack::glance::server {
  include openstack::base

  $glance_packages = ["glance", "glance-api", "glance-common", "glance-registry"]

  group{"glance":
    gid => 501,
    allowdupe => false,
  }
  user{"glance":
    uid => 501,
    gid => 501,
    require => Group["glance"],
  }
  package{$glance_packages:
    require => User["glance"]
  }

  file{"/etc/glance/glance-api.conf":
    mode => 0640,
    owner => root,
    group => glance,
    content => template("openstack/glance/glance-api.conf.erb"),
    require => Package["glance-api"],
  }

  file{"/etc/glance/glance-api-paste.ini":
    mode => 0640,
    owner => root,
    group => glance,
    content => template("openstack/glance/glance-api-paste.ini.erb"),
    require => Package["glance-api"],
  }

  service{"glance-api":
    ensure => undef,
    enable => false,
    require => [
      File["/etc/glance/glance-api.conf"],
      File["/etc/glance/glance-api-paste.ini"],
    ],
    subscribe => [
      File["/etc/glance/glance-api.conf"],
      File["/etc/glance/glance-api-paste.ini"],
    ],
  }

  file{"/etc/glance/glance-registry.conf":
    mode => 0640,
    owner => root,
    group => glance,
    content => template("openstack/glance/glance-registry.conf.erb"),
    require => Package["glance-registry"],
  }

  file{"/etc/glance/glance-registry-paste.ini":
    mode => 0640,
    owner => root,
    group => glance,
    content => template("openstack/glance/glance-registry-paste.ini.erb"),
    require => Package["glance-registry"],
  }

  service{"glance-registry":
    ensure => undef,
    enable => false,
    require => [
      File["/etc/glance/glance-registry.conf"],
      File["/etc/glance/glance-registry-paste.ini"],
    ],
    subscribe => [
      File["/etc/glance/glance-registry.conf"],
      File["/etc/glance/glance-registry-paste.ini"],
    ],
  }
} # }}}

# {{{ controller
class openstack::controller {
  include openstack::base

  include openstack::keystone::server
  include openstack::glance::server
  include openstack::nova::scheduler_server
  include openstack::nova::api_server
  include openstack::nova::consoleauth
  include openstack::nova::cert_server

  include openstack::keystone::client
  include openstack::glance::client
  include openstack::nova::client

  # nova-novncproxy (noVNC)
  package{"novnc":}
  service{"novnc":
    ensure => running,
    enable => true,
    require => Package["novnc"],
    subscribe => [
      File["/etc/nova/nova.conf"],
      File["/etc/nova/api-paste.ini"],
    ],
  }

  package{"nova-objectstore":}
  service{"nova-objectstore":
    ensure => undef,
    enable => false,
    require => Package["nova-objectstore"],
    subscribe => [
      File["/etc/nova/nova.conf"],
      File["/etc/nova/api-paste.ini"],
    ],
  }

  # cluster communication
  package{"rabbitmq-server": ensure => installed}
  service{"rabbitmq-server":
    ensure => undef,
    enable => false,
    require => Package["rabbitmq-server"],
  }

  # mySQL
  package{"mysql-server":}

  file {"/etc/mysql/my.cnf":
    mode => 0644,
    owner => root,
    group => root,
    content => template("openstack/mysql-my.cnf.erb"),
    require => Package["mysql-server"],
  }

  service{"mysql":
    ensure => running,
    enable => true,
    hasrestart => true,
    require => File["/etc/mysql/my.cnf"],
    subscribe => File["/etc/mysql/my.cnf"],
  }

  # TODO: this is very bad and destructive, fix design!
  exec{"openstack-cc-init-mysql-db":
    command => "/etc/puppet/repo/modules/openstack/files/mysql-init-db.sh",
    unless => "test -f /var/lib/mysql/nova/users.frm", # check whether db `nova` with table `users` exists
    require => Service["mysql"],
  }
  cron{"openstack-db-backups":
    command => "/etc/puppet/repo/bin/backup-db.sh keystone glance nova",
    user => "root",
    minute => 0,
  }
} # }}}

# {{{ nova
class openstack::nova::client {
  package{"python-novaclient":}
}

class openstack::nova::common {
  include openstack::base

  # provides FS structure, man pages, config files
  package{"nova-common":}

  package{"python-nova":}
  patch{"nova-affinity-filter-fix":
    filename => "/etc/puppet/repo/modules/openstack/files/nova-affinity-filter-fix.patch",
    workdir => "/usr/lib/python2.7/dist-packages/",
    require => Package["python-nova"],
  }
  patch{"nova-resume_state_on_host_boot-fix":
    filename => "/etc/puppet/repo/modules/openstack/files/resume_state_on_host_boot-fix.patch",
    workdir => "/usr/lib/python2.7/dist-packages/",
    require => Package["python-nova"],
  }

  file{"/etc/nova/nova.conf":
    mode => 0640,
    owner => root,
    group => nova,
    content => template("openstack/nova/nova.conf.erb"),
    require => Package["nova-common"],
  }

  file{"/etc/nova/api-paste.ini":
    mode => 0640,
    owner => root,
    group => nova,
    content => template("openstack/nova/api-paste.ini.erb"),
    require => Package["nova-common"],
  }
}

class openstack::nova::api_server {
  include openstack::nova::common
  package{"nova-api":}
  service{"nova-api":
    ensure => undef,
    enable => false,
    require => Package["nova-api"],
    subscribe => [
      File["/etc/nova/nova.conf"],
      File["/etc/nova/api-paste.ini"],
    ],
  }
}

class openstack::nova::scheduler_server {
  include openstack::nova::common
  package{"nova-scheduler":
    require => File["/etc/nova/nova.conf"],
  }
  service{"nova-scheduler":
    ensure => undef,
    enable => false,
    subscribe => [
      File["/etc/nova/nova.conf"],
      File["/etc/nova/api-paste.ini"],
    ],
    require => Package["nova-scheduler"],
  }
}

class openstack::nova::consoleauth {
  include openstack::nova::common
  package{"nova-consoleauth":}
  service{"nova-consoleauth":
    ensure => undef,
    enable => false,
    require => Package["nova-consoleauth"],
    subscribe => [
      File["/etc/nova/nova.conf"],
      File["/etc/nova/api-paste.ini"],
    ],
  }
}

class openstack::nova::cert_server {
  include openstack::nova::common
  package{"nova-cert":}
  service{"nova-cert":
    ensure => undef,
    enable => false,
    require => Package["nova-cert"],
    subscribe => [
      File["/etc/nova/nova.conf"],
      File["/etc/nova/api-paste.ini"],
    ],
  }
}

class openstack::nova::volume {
  include openstack::nova::common

  package{"nova-volume":}
  package{"tgt":}

  exec{"nova-sudoers-hack":
    command => "echo 'nova ALL = (root) NOPASSWD: /bin/dd' >> /etc/sudoers",
    unless => "grep -q '^nova ALL=(root) NOPASSWD: /bin/dd' /etc/sudoers",
  }

  service{"nova-volume":
    ensure => running,
    enable => true,
    require => [
      Package["nova-volume"],
      Exec["nova-sudoers-hack"],
    ],
    subscribe => [
      File["/etc/nova/nova.conf"],
      File["/etc/nova/api-paste.ini"],
    ],
  }
}

class openstack::nova::network_server {
  include openstack::nova::common
  include openstack::support::vlan_enabled

  package{"nova-network":}

  service{"nova-network":
    ensure => undef,
    enable => false,
    require => Package["nova-network"],
    subscribe => [
      File["/etc/nova/nova.conf"],
      File["/etc/nova/api-paste.ini"],
    ],
  }

  package{"bind9":}
  service{"bind9":
    ensure => running,
    enable => true,
    require => Package["bind9"],
  }
}

class openstack::nova::compute {
  include openstack::nova::common
  include openstack::support::vlan_enabled

  # required for nova-volume
  package{"open-iscsi":}
  package{"open-iscsi-utils":}

  package{"kvm":}
  package{"libvirt-bin":}
  file{"/etc/libvirt/qemu/networks/autostart/default.xml":
    ensure => absent,
    require => Package["libvirt-bin"],
  }

  # With this module enabled on compute nodes, the KVM guests make use of VhostNet[1],
  # a host virtio network accelerator that outperforms default traffic with much lower latency.
  # With this kernel module loaded, all future started KVM instances (via libvirt)
  # automatically make use of it with the kvm flag vhost=on.
  #
  # [1] http://www.linux-kvm.org/page/VhostNet
  kernel_module{"vhost_net":}

  package{"nova-compute-kvm":}
  package{"nova-compute":}
  service{"nova-compute":
    ensure => running,
    enable => true,
    require => Package["nova-compute"],
    subscribe => [
      File["/etc/nova/nova.conf"],
      File["/etc/nova/api-paste.ini"],
    ],
  }

  # Munin Monitoring Plugins
  file{"/etc/munin/plugin-conf.d/openstack-nova.conf":
    ensure => present,
    mode => 0444,
    owner => root,
    group => root,
    source => "puppet:///modules/openstack/munin/openstack-nova-plugins.conf",
  }
  file{"/etc/munin/plugins/openstack_nova_instances":
    ensure => present,
    mode => 0555,
    owner => root,
    group => root,
    source => "puppet:///modules/openstack/munin/openstack_nova_instances",
  }
  file{"/etc/munin/plugins/openstack_nova_ram":
    ensure => present,
    mode => 0555,
    owner => root,
    group => root,
    source => "puppet:///modules/openstack/munin/openstack_nova_ram",
  }
  file{"/etc/munin/plugins/openstack_nova_cpu":
    ensure => present,
    mode => 0555,
    owner => root,
    group => root,
    source => "puppet:///modules/openstack/munin/openstack_nova_cpu",
  }
} # }}}

# {{{ horizon: dashboard
class openstack::dashboard {
  package{"memcached": ensure => installed}

  package{"python-memcache": ensure => installed}

  package{"openstack-dashboard": ensure => installed}
  file{"/etc/openstack-dashboard/local_settings.py":
    mode => 0440,
    owner => root,
    group => root,
    content => template("openstack/dashboard/local_settings.py.erb"),
    require => Package["openstack-dashboard"],
  }

  file{"/etc/apache2/conf.d/openstack-dashboard.conf":
    mode => 0440,
    owner => root,
    group => root,
    content => template("openstack/dashboard/apache-config.erb"),
    require => Package["openstack-dashboard"],
  }
} # }}}

# {{{ cloudpipe
class openstack::cloudpipe {
  package{"openvpn":}
  service{"openvpn":
    ensure => running,
    enable => true,
    require => Package["openvpn"],
    subscribe => [
      File["/etc/openvpn/cloudpipe.conf"],
      File["/etc/openvpn/up.sh"],
      File["/etc/openvpn/down.sh"],
    ],
  }

  # required packages for the cloudpipe init script
  #package{"openssl":}
  #package{"unzip":}
  #package{"wget":}

  file{"/etc/network/interfaces":
    mode => 0444,
    owner => root,
    group => root,
    content => template("openstack/cloudpipe/network-interfaces.erb"),
  }

  file{"/etc/openvpn":
    ensure => directory,
    mode => 0775,
    owner => root,
    group => root,
  }

  file{"/etc/openvpn/up.sh":
    mode => 0775,
    owner => root,
    group => root,
    content => template("openstack/cloudpipe/up.sh.erb"),
    require => File["/etc/openvpn"],
  }

  file{"/etc/openvpn/down.sh":
    mode => 0775,
    owner => root,
    group => root,
    content => template("openstack/cloudpipe/up.sh.erb"),
    require => File["/etc/openvpn"],
  }

  file{"/etc/openvpn/cloudpipe.conf":
    mode => 0440,
    owner => root,
    group => root,
    content => template("openstack/cloudpipe/openvpn.conf.erb"),
    require => File["/etc/openvpn"],
  }

  file{"/etc/rc.local":
    mode => 0755,
    owner => root,
    group => root,
    content => template("openstack/cloudpipe/cloudpipe-load.sh.erb"),
  }
}
# }}}

# {{{ management commands
define openstack::nova::flavor($id, $cpu, $ram, $root, $ephemeral = 0, $ensure = present) {
  # TODO: $ensure (present,absent)

  exec{"creating nova flavor $name":
    command => "nova-manage flavor create --flavor=$id --name=$name --cpu=$cpu --memory=$ram --root_gb=$root --ephemeral=$ephemeral",
    unless => "nova-manage flavor list | grep -q ^$name",
  }
}

define openstack::nova::keypair($pubkey) {
  # TODO: $ensure (present,absent)

  exec{"creating nova keypair for user $name":
    command => "echo '$pubkey' > /tmp/pubkey.$name \
             && nova keypair-add --pub_key /tmp/pubkey.$name $name \
             && rm -f /tmp/pubkey.$name",
    unless => "nova keypair-list | grep -q ' $name '",
    require => Class["openstack::nova::compute"],
  }
}

define openstack::nova::user($access, $secret, $admin = false) {
  # TODO: $ensure (present,absent)

  $create_cmd = $admin ? {
    true => "admin",
    false => "create"
  }

  exec{"creating nova user $name":
    command => "nova-manage user $create_cmd --name='$name' --access='$access' --secret='$secret'",
    unless => "nova-manage user list | grep -q '^$name$'",
    require => Class["openstack::nova::common"],
  }
}

define openstack::nova::project($owner, $desc = "$name") {
  # TODO: $ensure (present,absent)

  exec{"creating nova project $name":
    command => "nova-manage project create --project='$name' --user='$owner' --desc=\"$desc\"",
    unless => "nova-manage project list | grep -q '^$name$'",
    require => [ Openstack::Nova::User[$owner],
                 Class["openstack::nova::compute"] ],
  }
}

define openstack::nova::network($cidr, $range_v4 = $cidr, $project = "", $vlan = "", $dns1 = "4.2.2.1", $dns2 = "8.8.8.8") {
  # TODO: $ensure (present,absent)

  $vlan_arg = $vlan ? {
    /\d+/ => "--vlan=${vlan}",
    default => ""
  }

  # (F=false, T=true)
  # whether or not we're running nova-network on every compute node or on a single dedicated network node.
  # the single dedicated node can still be HA'd via keepalived (or similar) with one shared virtual IP.
  $multi_host_arg = "--multi_host=F"

  if $project != "" {
    exec {"creating nova network $name: $cidr":
      command => "nova-manage network create --label='$name' $multi_host_arg $vlan_arg \
                  --fixed_cidr=$cidr --fixed_range_v4=$range_v4 --dns1=$dns1 --dns2=$dns2 \
                  --project_id=\$(keystone tenant-list | grep ' $project ' | awk '{print \$2}')",
      unless => "nova-manage network list | cut -f2 | grep -qw $cidr",
      require => Openstack::Nova::Project[$project],
    }
  } else {
    exec {"creating nova network $name: $cidr":
      command => "nova-manage network create --label='$name' \
                  $vlan_arg --fixed_cidr=$cidr --fixed_range_v4=$range_v4 \
                  --dns1=$dns1 --dns2=$dns2",
      unless => "nova-manage network list | cut -f2 | grep -vqw $cidr",
      require => Class["openstack::nova::compute"],
    }
  }
}

define openstack::nova::secgroup($tenant, $description = $name, $ensure = present) {
  case $ensure {
    present: {
      exec{"nova security group: $name@$tenant":
        command => "nova --os_tenant_name=$tenant secgroup-create $name '$description'",
        unless => "nova --os_tenant_name=$tenant secgroup-list | grep -qw $name",
        require => Class["openstack::nova::client"],
      }
    }
    absent: {
      exec{"nova security group: $name@$tenant":
        command => "nova --os_tenant_name='$tenant' secgroup-delete '$name'",
        unless => "nova --os_tenant_name='$tenant' secgroup-list | grep -vqw '$name'",
        require => Class["openstack::nova::client"],
      }
    }
  }
}

define openstack::nova::secgroup_rule($tenant, $group = "default", $proto, $from, $to, $iprange = "0.0.0.0/0") {
  exec{"nova security group: $group, rule: $name":
    command => "nova --os_tenant_name=$tenant secgroup-add-rule $group $proto $from $to $iprange",
    unless => "nova --os_tenant_name=$tenant secgroup-list-rules '$group' 2>&1 | \
                awk '/^\\| (icmp|tcp|udp) / {print \$2, \$4, \$6, \$8}' | \
                grep -q '$proto $from $to $iprange'",
    require => Class["openstack::nova::client"],
  }
}

define openstack::nova::floating_ip($ensure = present, $pool = "nova") {
  case $ensure {
    present: {
      exec{"nova floating ip: $name":
        command => "nova-manage floating create --ip_range=$name",
        unless => "nova-manage floating list | grep -qw '$name'",
        require => Class["openstack::nova::common"],
      }
    }
    absent: {
      exec{"nova floating ip: $name (absense)":
        command => "nova-manage floating delete --ip_range=$name",
        unless => "nova-manage floating list | grep -vqw '$name'",
        require => Class["openstack::nova::common"],
      }
    }
  }
}
# }}}
