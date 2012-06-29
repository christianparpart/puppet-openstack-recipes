define env::system($value) {
  $filename = "/etc/environment"
  $tmpfile = "/etc/environment.tmp"

  exec{"env.sys[$name]: $value":
    command => "awk '\$0 !~ /^$name=/ {print $0} END {print \"$name=$value\"}' <$filename >$tmpfile && mv -f $tmpfile $filename",
    unless => "grep -q ^$name='\"$value\"' $filename || grep -q ^$name=\"'$value'\" $filename || grep -q \"^$name=$value\" $filename"
  }
}

define env::profile($value) {
  $filename = "/etc/profile.d/95-puppet-generated.sh"
  $line = "export ${name}=${value}"

  exec{"env.profile[${name}]: ${value}" :
    command => "cat $filename | grep -v '${name}=' > /tmp/buffer;
      cat /tmp/buffer > $filename && rm /tmp/buffer && echo '${line}' >> $filename",
    unless => "grep -q '${line}'\$ $filename"
  }
}
