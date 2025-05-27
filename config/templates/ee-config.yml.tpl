---
version: 3

images:
  base_image:
    name: quay.io/ansible/awx-ee:latest

dependencies:
  ansible_core:
    package_pip: ansible-core>=2.14.0
  ansible_runner:
    package_pip: ansible-runner
  galaxy: collections.yml  # Sem espaços extras após o nome do arquivo
  python: requirements.txt
  system: bindep.txt

additional_build_steps:
  prepend_base:
    - RUN dnf update -y && dnf install -y epel-release
    - RUN dnf install -y python3 python3-pip python3-devel gcc gcc-c++ make
    - RUN dnf install -y krb5-devel krb5-libs krb5-workstation
    - RUN dnf install -y libxml2-devel libxslt-devel libffi-devel
    - RUN dnf install -y openssh-clients sshpass git rsync iputils bind-utils
    - RUN dnf install -y sudo which procps-ng unzip
    - RUN mkdir -p /usr/local/sapnwrfcsdk /etc/ld.so.conf.d
    - ENV SAPNWRFC_HOME=/usr/local/sapnwrfcsdk
    - ENV LD_LIBRARY_PATH=/usr/local/sapnwrfcsdk/lib:$LD_LIBRARY_PATH
    - ENV PATH=/usr/local/sapnwrfcsdk/bin:$PATH

  append_base:
    - RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel
    - RUN python3 -m pip install --no-cache-dir pyrfc==3.3.1 || echo "PyRFC installation failed - SAP NW RFC SDK may be required"
    - RUN python3 -m pip install --no-cache-dir azure-cli
    - RUN mkdir -p /opt/ansible/{collections,playbooks,inventories,roles}
    - RUN echo "/usr/local/sapnwrfcsdk/lib" > /etc/ld.so.conf.d/nwrfcsdk.conf
    - RUN ldconfig
    - RUN dnf clean all && rm -rf /var/cache/dnf
    - RUN python3 -c "import ansible; print('Ansible version:', ansible.__version__)"
    - RUN python3 -c "import pyrfc"
    - RUN mkdir -p /var/run/receptor /tmp/receptor
    - COPY --from=quay.io/ansible/receptor:v1.5.5 /usr/bin/receptor /usr/bin/receptor
    - RUN chmod +x /usr/bin/receptor

build_arg_defaults:
  ANSIBLE_CORE_VERSION: ">=2.14.0"
  ANSIBLE_RUNNER_VERSION: ">=2.3.0"
  PYTHON_VERSION: "3.9"
