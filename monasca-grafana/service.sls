{%- from "storm/map.jinja" import server with context %}

monasca_grafana_service:
  service.running:
  - name: grafana-server
  - enable: True
  - watch:
    - file: monasca_grafana_config
    - file: monasca_grafana_service_script
