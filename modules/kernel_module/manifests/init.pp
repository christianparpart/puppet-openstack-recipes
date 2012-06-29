define kernel_module($ensure = present) {
	$modulesfile = $::operatingsystem ? {
		debian => "/etc/modules",
    ubuntu => "/etc/modules",
		redhat => "/etc/rc.modules",
		gentoo => "/etc/modules-load.d/puppet.conf", # we require systemd on Gentoo (TODO support openrc, too)
	}
	case $ensure {
		"present": {
			exec { "register_module_${name}":
				command => $::operatingsystem ? {
					debian => "echo '${name}' >> '${modulesfile}'",
					ubuntu => "echo '${name}' >> '${modulesfile}'",
					redhat => "echo '/sbin/modprobe ${name}' >> '${modulesfile}'",
					gentoo => "echo '${name}' >> '${modulesfile}'"
				},
				unless => "grep -qFx '${name}' '${modulesfile}'"
			}
			# actually load module at runtime
			exec { "/sbin/modprobe ${name}":
				unless => "lsmod | grep -qw '${name}'"
			}
		}
		"absent": {
			exec { "unregister_module_${name}":
				command => $::operatingsystem ? {
					debian => "perl -ni -e 'print unless /^\\Q${name}\\E\$/' '${modulesfile}'",
					ubuntu => "perl -ni -e 'print unless /^\\Q${name}\\E\$/' '${modulesfile}'",
					redhat => "perl -ni -e 'print unless /^\\Q/sbin/modprobe ${name}\\E\$/' '${modulesfile}'",
					gentoo => "perl -ni -e 'print unless /^\\Q${name}\\E\$/' '${modulesfile}'",
				},
			}
			# actually unload module at runtime
			exec { "/sbin/modprobe -r ${name}":
				unless => "lsmod | grep -qvw '${name}'"
			}
		}
		default: {
			err ( "unknown ensure value ${ensure}" )
		}
	}
}
