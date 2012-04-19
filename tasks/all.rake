# Miscellaneous build tasks

require 'tmpdir'
require 'tempfile'
require 'fileutils'

namespace :build do
  desc 'Confirm the correct Ruby environment for development and deployment'
  task :confirm_ruby => :os_dependencies do
    expectation = "#{RUBY_BUILD}/bin"
    %w[ ruby gem rake ].each do |cmd|
      raise "#{cmd} not running from #{expectation}. Did you source env.sh?" unless `which #{cmd}`.chomp.match(Regexp.new("#{expectation}/#{cmd}$"))
    end
  end

  desc 'Hook into the Ruby in a Box environment to get everything else built and installed'
  task :ruby_inabox => :couchdb

  # Submodules
  submodules = ["#{DEPS}/otp/otp_build", "#{DEPS}/couchdb/bootstrap"]
  submodules.each do |submodule_file|
    file submodule_file do
      human_friendly = File.dirname(submodule_file)
      raise "No Git submodule: #{human_friendly}.\nTry: git submodule init && git submodule update"
    end
  end

  task :couch_git_submodules => ["#{DEPS}/couchdb/bootstrap"]
  task :otp_git_submodules => ["#{DEPS}/otp/otp_build"]

  desc 'Confirm (and install if possible) the OS dependencies'
  task :os_dependencies => [:mac_dependencies, :ubuntu_dependencies, :debian_dependencies, :opensuse_dependencies, :solaris_dependencies]

  desc 'Confirm Git submodules are updated'
  task :confirm_submodules => submodules do
    puts "Confirmed Git Submodules"
  end

  task :debian_dependencies => :known_distro do
    if DISTRO[0] == :debian
      install_packages [
        # For building OTP
        %w[ flex dctrl-tools libsctp-dev ed ],

        # All Ubuntu gets these.
        %w[ libxslt1-dev automake make ruby libtool g++ ],
        %w[ zip libcap2-bin ],

        # Needed for Varnish
        # %w[ libpcre3-dev ]
      ].flatten
    end
  end

  task :ubuntu_dependencies => :known_distro do
    if DISTRO[0] == :ubuntu
      # For building OTP
      install_packages %w[ flex dctrl-tools libsctp-dev ed zlib1g-dev ]

      # All Ubuntu gets these.
      install_packages %w[ libxslt1-dev automake make ruby libtool g++ ]
      install_packages %w[ zip libcap2-bin ]

      # Needed for Varnish
      #install_packages %w[ libpcre3-dev ]
    end
  end

  task :arch_dependencies => :known_distro do
    if DISTRO[0] == :arch
      # For building OTP
      install_packages %w[ flex lksctp-tools zlib zip ]

      # All Arch gets these.
      install_packages %w[ libxslt automake make ruby libtool gcc libcap m4 openssl ]
    end
  end

  task :mac_dependencies => :known_distro do
    %w[ gcc make ].each do |dep|
      raise 'Please install Xcode from Apple' if DISTRO[0] == :osx and system("#{dep} --version > /dev/null 2> /dev/null") == false
    end
  end

  task :opensuse_dependencies => :known_distro do
    if DISTRO[0] == :opensuse
      # For building OTP
      install_packages %w[ flex lksctp-tools-devel zip]

      # All OpenSUSE gets these.
      install_packages %w[ rubygem-rake gcc-c++ make m4 zlib-devel libopenssl-devel libtool automake ]

    end
  end

  task :solaris_dependencies => :known_distro do
    if DISTRO[0] == :solaris
      install_packages %w[ gcc4core gcc4g++ arc gmake zlib openssl readline ] # General
      install_packages %w[ flex ]  # OTP
      install_packages %w[ automake autoconf curl_devel libtool ]
    end
  end

  desc 'Clean all CouchDB-related build output'
  task :clean do
    sh "rm -rf #{BUILD}"
  end

end
