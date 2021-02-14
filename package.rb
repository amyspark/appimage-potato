#!/usr/bin/env ruby

require 'date'

build_date = DateTime.now.rfc3339

vcs = `git rev-parse HEAD`.strip

architectures = %w[armhf arm64]

architectures.each do |arch|
  Dir.chdir __dir__ do |_wd|
    warn "docker build --build-arg=BUILD_DATE=#{build_date} --build-arg=BUILD_REF=#{vcs} --tag=kde-appimage-base-1604-#{arch}:latest #{arch}"
    system("docker build --build-arg=BUILD_DATE=#{build_date} --build-arg=BUILD_REF=#{vcs} --tag=kde-appimage-base-1604-#{arch}:latest #{arch}")
  end
end
