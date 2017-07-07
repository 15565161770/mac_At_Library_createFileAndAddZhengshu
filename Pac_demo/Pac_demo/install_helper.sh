#!/bin/sh

#  install_helper.sh
#  shadowsocks
#
#  Created by clowwindy on 14-3-15.

cd `dirname "${BASH_SOURCE[0]}"`
sudo mkdir -p "/Library/Application Support/test_test/"
sudo cp proxy_conf_helper "/Library/Application Support/test_test/"
sudo chown root:admin "/Library/Application Support/test_test/proxy_conf_helper"
sudo chmod a+rx "/Library/Application Support/test_test/proxy_conf_helper"
sudo chmod +s "/Library/Application Support/test_test/proxy_conf_helper"

# install cert
sudo sudo security add-trusted-cert -d -k /Library/Keychains/System.keychain ./rootca.crt

echo done
