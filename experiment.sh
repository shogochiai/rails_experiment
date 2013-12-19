# Copyright 2013, Shogo Ochiai
# Licensed under the GPL licenses. 

#!/bin/zsh

RUBY=("1.9.3-p484" "2.0.0-p353" "2.1.0-preview1") 
for ruby in ${RUBY[@]}; do
  export PATH=$RBENV_ROOT/shims:$PATH
  rbenv global $ruby >/dev/null 2>&1

  RAILS_VER=("3.2.15" "4.0.2") 
  for rails_ver in ${RAILS_VER[@]}; do
    gem install rails -v $rails_ver >/dev/null 2>&1
    if test $rails_ver = '3.2.15' ; then
      gem uninstall rails -v "4.0.2" >/dev/null 2>&1
      gem uninstall railties -v "4.0.2" >/dev/null 2>&1
    else
      gem uninstall rails -v "3.2.15" >/dev/null 2>&1
      gem uninstall railties -v "3.2.15" >/dev/null 2>&1
    fi
    rbenv rehash
    ruby -v
    rails -v
    rails new rails_${rails_ver}_speedtest -d mysql >/dev/null 2>&1
    echo "gem 'spring'" >> ./rails_${rails_ver}_speedtest/Gemfile
    cd ./rails_${rails_ver}_speedtest
    bundle install --path vendor/bundle >/dev/null 2>&1
    bundle exec spring rails g scaffold blog title:string description:string >/dev/null 2>&1

    echo not_spring
    for i in {1..10};do
      bundle exec time rake routes | grep real
    done 2> routes.txt
    awk -f ../ave.awk routes.txt
    echo spring
    for i in {1..10};do
      bundle exec time spring rake routes | grep real
    done 2> routes.txt
    awk -f ../ave.awk routes.txt
    cd ..
    rm -rf ./rails_${rails_ver}_speedtest
  done
done
