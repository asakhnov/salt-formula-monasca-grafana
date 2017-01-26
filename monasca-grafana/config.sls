{%- from "monasca-grafana/map.jinja" import server with context %}

monasca_grafana_config:
  file.managed:
  - name: /opt/grafana/conf/defaults.ini
  - source: salt://monasca-grafana/files/defaults.ini
  - user: grafana
  - group: grafana
  - mode: 640
  - template: jinja
