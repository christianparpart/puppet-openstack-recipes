class patch::package {
  package{"patch": ensure => installed}
}

define patch($filename, $workdir) {
  include patch::package

  exec {"patch-apply-${filename}-${workdir}":
    cwd => $workdir,
    command => "patch -p1 <$filename",
    onlyif => "patch --dry-run -p1 <${filename}",
    require => Class["patch::package"],
  }
}
