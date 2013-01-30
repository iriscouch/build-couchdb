# Distribution (platform) detection

def detect_distro
  # OSX
  if `uname`.chomp == 'Darwin'
    os_release = %x[ sysctl -n kern.osrelease ].chomp
    return [:osx, os_release]
  end

  # Solaris
  if `uname`.chomp == "SunOS"
    return [:solaris, `uname -r`.chomp]
  end

  if `uname -r`.chomp[-4..-1] == "ARCH" 
    return [:arch, `uname -r`.chomp]
  end

  # Ubuntu
  if File.exist? '/etc/lsb-release'
    info = Hash[ *File.new('/etc/lsb-release').lines.map{ |x| x.split('=').map { |y| y.chomp } }.flatten ]
    if info['DISTRIB_ID'] == 'Ubuntu'
      return [:ubuntu, info['DISTRIB_RELEASE']]
    elsif info['DISTRIB_ID'] == 'LinuxMint'
      return [:ubuntu, info['DISTRIB_RELEASE']]
    end
  end

  # Debian
  ver = '/etc/debian_version'
  return [:debian, File.new(ver).readline.chomp] if !File.exist?('/etc/lsb-release') && File.exist?(ver)

  # Fedora
  if File.exist? '/etc/fedora-release'
    release = File.new('/etc/fedora-release').readline.match(/Fedora release (\d+)/)[1]
    return [:fedora, release]
  end

  # Red Hat # TODO: Do not piggyback the :fedora version.
  if File.exist? '/etc/redhat-release'
    match = File.new('/etc/redhat-release').readline.match(/Red Hat Enterprise Linux Server release (\S+)/)
    if match
      release = match[1]
      return [:fedora, release]
    end
  end

  # CentOS # TODO: Do not piggyback the :fedora version
  if File.exist? '/etc/redhat-release'
    match = File.new('/etc/redhat-release').readline.match(/CentOS release (\S+)/)
    if match
      release = match[1]
      return [:fedora, release]
    end
  end

  # Scientific Linux
  if File.exist? '/etc/redhat-release'
    if RUBY_VERSION <= '1.8.7'
      raise 'Version of ruby is too old. Consider installing a more recent version'
    end

    release = File.new('/etc/redhat-release').readline.match(/Scientific Linux release \d.\d \([A-z][a-z]+\)/)[1]
    return [:slf, release]
  end

  # OpenSUSE
  if File.exist? '/etc/SuSE-release'
    release = File.new('/etc/SuSE-release').readline.match(/openSUSE (\d+)/)[1]
    return [:opensuse, release]
  end

  # Amazon Linux AMI
  if File.exist? '/etc/system-release'
    match = File.new('/etc/system-release').readline.match(/Amazon Linux AMI release/)
    if match
        return [:fedora, '5.5']
    end
  end

  raise StandardError, 'could not find distribution, maybe your OS isn\'t supported'
end
