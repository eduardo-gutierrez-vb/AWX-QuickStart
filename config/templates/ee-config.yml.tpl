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
  
  galaxy: collections.yml
  python: requirements.txt
  system: bindep.txt

additional_build_steps:
  prepend_base:
    # System updates and repository setup
    - RUN dnf update -y && dnf install -y epel-release
    
    # Development tools for compilation
    - RUN dnf install -y python3 python3-pip python3-devel gcc gcc-c++ make
    - RUN dnf install -y krb5-devel krb5-libs krb5-workstation
    - RUN dnf install -y libxml2-devel libxslt-devel libffi-devel
    - RUN dnf install -y openssh-clients sshpass git rsync iputils bind-utils
    - RUN dnf install -y sudo which procps-ng unzip
    
    # SAP NW RFC SDK preparation
    - RUN mkdir -p /usr/local/sapnwrfcsdk
    - RUN mkdir -p /etc/ld.so.conf.d
    
    # Environment variables for SAP
    - ENV SAPNWRFC_HOME=/usr/local/sapnwrfcsdk
    - ENV LD_LIBRARY_PATH=/usr/local/sapnwrfcsdk/lib:$LD_LIBRARY_PATH
    - ENV PATH=/usr/local/sapnwrfcsdk/bin:$PATH

  append_base:
    # Python environment setup
    - RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel
    
    # SAP specific installation with error handling
    - RUN python3 -m pip install --no-cache-dir pyrfc==3.3.1 || echo "PyRFC installation failed - SAP NW RFC SDK may be required"
    
    # Azure CLI installation
    - RUN python3 -m pip install --no-cache-dir azure-cli
    
    # Ansible directory structure
    - RUN mkdir -p /opt/ansible/{collections,playbooks,inventories,roles}
    
    # Library configuration for SAP
    - RUN echo "/usr/local/sapnwrfcsdk/lib" > /etc/ld.so.conf.d/nwrfcsdk.conf
    - RUN ldconfig
    
    # System cleanup
    - RUN dnf clean all && rm -rf /var/cache/dnf
    
    # Installation verification
    - RUN python3 -c "import ansible; print('Ansible version:', ansible.__version__)"
    - RUN python3 -c "try: import pyrfc; print('PyRFC successfully imported'); except ImportError as e: print('PyRFC import failed:', e)"
    
    # Receptor setup
    - RUN mkdir -p /var/run/receptor /tmp/receptor
    - COPY --from=quay.io/ansible/receptor:v1.5.5 /usr/bin/receptor /usr/bin/receptor
    - RUN chmod +x /usr/bin/receptor

build_arg_defaults:
  ANSIBLE_CORE_VERSION: ">=2.14.0"
  ANSIBLE_RUNNER_VERSION: ">=2.3.0"
  PYTHON_VERSION: "3.9"
  
# Collections configuration file
collections_file: |
  collections:
    # Network and connectivity collections
    - name: ansible.netcommon
    - name: ansible.utils
    - name: community.network
    - name: cisco.ios
    - name: fortinet.fortios
    
    # Operating system collections
    - name: ansible.windows
    - name: ansible.posix
    - name: community.windows
    - name: microsoft.ad
    
    # Cloud and virtualization collections
    - name: azure.azcollection
    - name: maxhoesel.proxmox
    - name: community.docker
    
    # Monitoring and observability collections
    - name: community.zabbix
    - name: grafana.grafana
    
    # Security and cryptography collections
    - name: community.crypto
    
    # Utility collections
    - name: community.general
    - name: community.dns
    - name: community.saplibs
    - name: ansible.eda

# Python requirements file
requirements_file: |
  # SAP specific dependencies
  pyrfc==3.3.1
  
  # Network and connectivity dependencies
  dnspython
  urllib3
  ncclient
  netaddr
  lxml
  
  # Windows and authentication dependencies
  pykerberos
  pywinrm[kerberos]
  
  # Azure dependencies
  azure-cli-core
  azure-common
  azure-mgmt-compute
  azure-mgmt-network
  azure-mgmt-resource
  azure-mgmt-storage
  azure-identity
  azure-mgmt-authorization
  
  # Virtualization dependencies
  pyVim
  PyVmomi
  proxmoxer
  
  # Monitoring dependencies
  zabbix-api
  grafana-api
  
  # General dependencies
  requests
  xmltodict
  cryptography
  jmespath
  awxkit
  
  # Additional dependencies for AWX
  psutil
  python-dateutil

# System dependencies file
bindep_file: |
  # Compilation dependencies
  gcc [platform:rpm]
  gcc-c++ [platform:rpm]
  make [platform:rpm]
  python3-devel [platform:rpm]
  libffi-devel [platform:rpm]
  
  # Development tools
  unzip [platform:rpm]
  git [platform:rpm]
  openssh-clients [platform:rpm]
  sshpass [platform:rpm]
  rsync [platform:rpm]
  iputils [platform:rpm]
  bind-utils [platform:rpm]
