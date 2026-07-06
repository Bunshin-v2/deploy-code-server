#!/bin/sh
set -eu

# allow us to access systemd logs to see the status of --link
sed -i.bak 's/#Storage=auto/Storage=persistent/' /etc/systemd/journald.conf
mkdir -p /var/log/journal
systemctl force-reload systemd-journald
systemctl restart systemd-journald

# install code-server service system-wide
export HOME=/root
if ! curl -fsSL https://code-server.dev/install.sh | sh; then
    echo "ERROR: Failed to install code-server" >&2
    exit 1
fi

# add our helper server to redirect to the proper URL for --link
if ! git clone https://github.com/bpmct/coder-cloud-redirect-server; then
    echo "ERROR: Failed to clone coder-cloud-redirect-server" >&2
    exit 1
fi
cd coder-cloud-redirect-server
cp coder-cloud-redirect.service /etc/systemd/system/
cp coder-cloud-redirect.py /usr/bin/

# create a code-server user
adduser --disabled-password --gecos "" coder
echo "coder ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/coder
usermod -aG sudo coder

# copy ssh keys from root
cp -r /root/.ssh /home/coder/.ssh
chown -R coder:coder /home/coder/.ssh

# use a more unique hostname (for Linode)
sudo hostnamectl set-hostname linode-$LINODE_ID
source /root/.bashrc

# configure code-server to use --link with the "coder" user
mkdir -p /home/coder/.config/code-server
touch /home/coder/.config/code-server/config.yaml
echo "link: true" > /home/coder/.config/code-server/config.yaml
chown -R coder:coder /home/coder/.config

# start and enable code-server and our helper service
if ! systemctl enable code-server@coder; then
    echo "ERROR: Failed to enable code-server service" >&2
    exit 1
fi
if ! systemctl enable coder-cloud-redirect; then
    echo "ERROR: Failed to enable coder-cloud-redirect service" >&2
    exit 1
fi
if ! systemctl start code-server@coder; then
    echo "ERROR: Failed to start code-server service" >&2
    exit 1
fi
if ! systemctl start coder-cloud-redirect; then
    echo "ERROR: Failed to start coder-cloud-redirect service" >&2
    exit 1
fi