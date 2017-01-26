{%- from "monasca-grafana/map.jinja" import server with context %}

install_dependencies:
  pkg.installed:
  - pkgs: {{ server.pkgs }}

group_grafana:
  group.present:
  - name: grafana
  - system: True

user_grafana:
  user.present:
  - name: grafana
  - shell: /bin/false
  - system: True
  - createhome: False
  - groups:
    - grafana

download_grafana:
  cmd.run:
  - name: go get github.com/twc-openstack/grafana
  - cwd: /opt
  - env:
    - GOPATH: /opt/go
    - PATH: /opt/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
  - check_cmd:
    - /bin/true
  - unless: test -d /opt/grafana

change_grafana_branch:
  cmd.run:
  - name: git checkout v2.6.0-keystone
  - cwd: /opt/go/src/github.com/twc-openstack/grafana
  - env:
    - GOPATH: /opt/go
    - PATH: /opt/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
  - onchanges:
    - cmd: download_grafana

configure_grafana:
  cmd.run:
  - name: go run build.go setup
  - cwd: /opt/go/src/github.com/twc-openstack/grafana
  - env:
    - GOPATH: /opt/go
    - PATH: /opt/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
  - onchanges:
    - cmd: change_grafana_branch

# This is a workaround for a dependency issue
create_deps_dir:
  file.directory:
  - name: /opt/go/src/github.com/grafana/grafana
  - user: root
  - group: root
  - mode: 755
  - makedirs: True
  - onlyif: test -d /opt/go/src/github.com/twc-openstack/grafana

copy_deps:
  cmd.run:
  - name: cp -r twc-openstack/grafana grafana/
  - cwd: /opt/go/src/github.com/
  - onlyif: test -d /opt/go/src/github.com/twc-openstack/grafana && test -d /opt/go/src/github.com/grafana/grafana

get_deps:
  cmd.run:
  - name: godep restore
  - cwd: /opt/go/src/github.com/twc-openstack/grafana
  - env:
    - GOPATH: /opt/go
    - PATH: /opt/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
  - onchanges:
    - cmd: configure_grafana

build_grafana:
  cmd.run:
  - name: go run build.go build
  - cwd: /opt/go/src/github.com/twc-openstack/grafana
  - env:
    - GOPATH: /opt/go
    - PATH: /opt/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
  - onchanges:
    - cmd: get_deps

grab_grafana_assets:
  cmd.run:
  - name: npm install
  - cwd: /opt/go/src/github.com/twc-openstack/grafana
  - env:
    - GOPATH: /opt/go
    - PATH: /opt/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
  - onchanges:
    - cmd: build_grafana

build_grafana_assets:
  cmd.run:
  - name: npm install -g grunt-cli
  - cwd: /opt/go/src/github.com/twc-openstack/grafana
  - env:
    - GOPATH: /opt/go
    - PATH: /opt/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
  - onchanges:
    - cmd: grab_grafana_assets

compile_assets:
  cmd.run:
  - name: grunt --force
  - cwd: /opt/go/src/github.com/twc-openstack/grafana
  - env:
    - GOPATH: /opt/go
    - PATH: /opt/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
  - onchanges:
    - cmd: build_grafana_assets
  - check_cmd:
    - /bin/true

move_grafana:
  cmd.run:
  - name: mv grafana/ /opt/
  - cwd: /opt/go/src/github.com/twc-openstack/
  - onchanges:
    - cmd: compile_assets

set_permissions:
  file.directory:
  - name: /opt/grafana
  - user: grafana
  - group: grafana
  - mode: 770
  - recurse:
    - user
    - group
  - onlyif: test -d /opt/grafana

/var/log/grafana:
  file.directory:
  - user: grafana
  - group: grafana
  - mode: 755
  - makedirs: True
  - require:
    - user: user_grafana

/run/grafana:
  file.directory:
  - user: grafana
  - group: grafana
  - mode: 755
  - require:
    - user: user_grafana

monasca_grafana_service_script:
  file.managed:
  - name: {{ server.init_dir }}/{{ server.monasca_grafana_service_script }}
  - source: salt://monasca-grafana/files/{{ grains['init'] }}/{{ server.monasca_grafana_service_script }}
  - template: jinja
  - user: root
  - group: root
  - mode: 744
