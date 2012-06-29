define sysctl($value, $file = "/etc/sysctl.conf", $live = true) {
	case $value {
		"default": {
			exec {"remove_old_sysctl_${name}":
				command => "perl -ni -e 'print unless /^${name}[ ]*=.*$/' '${file}'"
			}
		}
		default: {
			# update sysctl.conf
			exec {"write_sysctl_conf_${name}":
				command => "perl -ni -e 'print unless /^${name}[ ]*=.*$/' '${file}' && echo '${name} = ${value}' >> '${file}'",
				unless => "grep -q '^${name} = ${value}\>' '${file}'",
			}

			if ($live) {
				# change value live
				exec {"update_sysctl_live_${name}":
					command => "/sbin/sysctl ${name}=${value}",
					unless => "/sbin/sysctl ${name} | grep -q ' = ${value}$'",
				}
			}
		}
	}
}
