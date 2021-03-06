fetch_extract_ports_tree:
  module.run:
    - name: ports.update
    - extract: True
    - unless: test -e /usr/ports

update_ports_tree:
  module.run:
    - name: ports.update
    - onlyif: test -e /usr/ports

{% for dep in pillar['poudriere']['dependencies'] %}
{{ dep | replace('/', '-') }}_install:
  ports.installed:
    - name: {{ dep }}
{% endfor %}

{% for dir in ['certs', 'keys'] %}
poudriere_ssl_{{ dir }}_directory:
  file.directory:
    - name: {{ pillar['poudriere']['ssl_dir'] }}/{{ dir }}
    - user: root
    - group: wheel
    - dir_mode: 0600
    - file_mode: 0600
    - makedirs: True
    - recurse:
      - user
      - group
      - mode
{% endfor %}

poudriere_ssl_cert:
  file.managed:
    - name: {{ pillar['poudriere']['ssl_dir'] }}/certs/poudriere.cert
    - user: root
    - group: wheel
    - mode: 0600
    - contents: |
        {{ pillar['poudriere']['ssl_cert'] | indent(8) }}

poudriere_ssl_key:
  file.managed:
    - name: {{ pillar['poudriere']['ssl_dir'] }}/keys/poudriere.key
    - user: root
    - group: wheel
    - mode: 0600
    - contents: |
        {{ pillar['poudriere']['ssl_key'] | indent(8) }}

poudriere_config:
  file.managed:
    - name: /usr/local/etc/poudriere.conf
    - source: salt://{{ slspath }}/templates/poudriere.conf
    - user: root
    - group: wheel
    - file_mode: 0644
    - template: jinja

poudriere_config_dir:
  file.directory:
    - name: {{ pillar['poudriere']['config_dir'] }}
    - user: root
    - group: wheel
    - dir_mode: 0755
    - file_mode: 0644

{% for jail in pillar['poudriere']['jails'] %}
{% set jail_version = jail['version'] | replace('.', '-') %}
{% set jail_name = 'freebsd_' ~ jail_version ~ jail['arch'] %}
poudriere_update_{{ jail_name }}:
  cmd.run:
    - name: poudriere jail -u -j {{ jail_name }}
    - runas: root
    - use_vt: True
    - onlyif: poudriere jail -l | grep {{ jail_name }}

poudriere_create_{{ jail_name }}:
  cmd.run:
    - name: poudriere jail -c -j {{ jail_name }} -v {{ jail['version'] }}-{{ jail['branch'] }}
    - runas: root
    - use_vt: True
    - unless: poudriere jail -l | grep {{ jail_name }}

{% for f in ['pkglist', 'make.conf'] %}
poudriere_config_{{ f }}:
  file.managed:
    - name: {{ pillar['poudriere']['config_dir'] }}/{{ jail_name }}-{{ f }}
    - source: salt://{{ slspath }}/templates/{{ f }}
    - user: root
    - group: wheel
    - file_mode: 0644
    - template: jinja
{% endfor %}
{% endfor %}

{% for tree in pillar['poudriere']['ports_trees'] %}
poudriere_update_ports_tree_{{ tree }}:
  cmd.run:
    - name: poudriere ports -u -p {{ tree }}
    - runas: root
    - use_vt: True
    - onlyif: test -e {{ pillar['poudriere']['basefs'] }}/ports/{{ tree }}

poudriere_install_ports_tree_{{ tree }}:
  cmd.run:
    - name: poudriere ports -c -p {{ tree }}
    - runas: root
    - use_vt: True
    - unless: test -e {{ pillar['poudriere']['basefs'] }}/ports/{{ tree }}
{% endfor %}

poudriere_nginx_config:
  file.managed:
    - name: /usr/local/etc/nginx/nginx.conf
    - source: salt://{{ slspath }}/templates/nginx.conf
    - user: root
    - group: wheel
    - file_mode: 0644
    - template: jinja

poudriere_nginx_ssl_dir:
  file.directory:
    - name: {{ pillar['poudriere']['nginx_conf_dir'] }}/ssl
    - user: root
    - group: wheel
    - dir_mode: 0600
    - file_mode: 0600
    - makedirs: True
    - recurse:
      - user
      - group
      - mode

poudriere_nginx_ssl_cert:
  file.managed:
    - name: {{ pillar['poudriere']['nginx_conf_dir'] }}/ssl/{{ pillar['poudriere']['server_name'] }}.crt
    - user: root
    - group: wheel
    - mode: 0600
    - contents: |
        {{ pillar['poudriere']['nginx_ssl_cert'] | indent(8) }}

poudriere_nginx_ssl_key:
  file.managed:
    - name: {{ pillar['poudriere']['nginx_conf_dir'] }}/ssl/{{ pillar['poudriere']['server_name'] }}.key
    - user: root
    - group: wheel
    - mode: 0600
    - contents: |
        {{ pillar['poudriere']['nginx_ssl_key'] | indent(8) }}

poudriere_nginx_create_dhparam:
  cmd.run:
    - name: openssl dhparam -out {{ pillar['poudriere']['nginx_conf_dir'] }}/ssl/dhparam.pem 2048
    - runas: root
    - use_vt: True
    - unless: test -e {{ pillar['poudriere']['nginx_conf_dir'] }}/ssl/dhparam.pem

poudriere_enable_nginx:
  sysrc.managed:
    - name: nginx_enable
    - value: YES
