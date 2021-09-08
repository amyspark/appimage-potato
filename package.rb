#!/usr/bin/env ruby

require 'date'

require 'optparse'

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: package.rb [options]"

  CODES = %w[x86_64 armhf arm64]

  opts.on("-a", "--arch ARCH", CODES, "Architectures to build") do |arch|
    build_date = DateTime.now.rfc3339
    vcs = `git rev-parse HEAD`.strip

    Dir.chdir __dir__ do |_wd|
      warn "docker build --build-arg=BUILD_DATE=#{build_date} --build-arg=BUILD_REF=#{vcs} --tag=kde-appimage-base-1604-#{arch}:latest #{arch}"
      system("docker build --build-arg=BUILD_DATE=#{build_date} --build-arg=BUILD_REF=#{vcs} --tag=kde-appimage-base-1604-#{arch}:latest #{arch}")
    end
  end

  opts.on_tail("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!
