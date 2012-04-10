# Dependencies on files installed by a package
#

unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

require_relative 'distros'


def package_dep opts
  # Unfortunately the dependency must be defined after the OS is detected,
  # Even if this task is a no-op, if other tasks depend on it, they will re-run
  # if this task runs. Therefore it must not be defined at all for un-requested
  # distros. That means calling detect_distro() now and presumably later in :known_distro.
  distro = detect_distro()

  distros = opts.delete :distros
  if distros && !distros.member?(distro[0])
    puts "#{distro[0]} does not need #{opts.inspect}" if ENV['debug_package']
    return "/" # Return a file dependency that will presumably always work.
  end

  puts "Package dependency for #{distro[0]}: #{opts.inspect}" if ENV['debug_package']
  program_file, package = opts.to_a.first

  Rake.application.in_explicit_namespace(':') do
    file program_file do
      case distro[0]
        when :ubuntu, :debian
          installed = `dpkg --list`.split("\n").map { |x| x.split[1] } # Hm, this is out of scope if defined outside.
          if !installed.member?(package)
            sh "sudo apt-get -y install #{package}"
          end
        when :solaris
          installed = `pkg-get -l`.split("\n")
          if !installed.member?(package)
            sh "sudo pkg-get install #{package}"
          end
        when :arch
          installed = `pacman -Q`.split("\n")
          if !installed.member?(package)
            sh "sudo pacman -S #{package}"
          end
        when :osx
          installed = `brew list`.split("\n")
          if !installed.member?(package)
            sh "sudo brew install #{package}"
          end
        else
          puts "Skipping package requirement '#{package}' on an unsupported platform"
      end
    end
  end

  return program_file
end
