sudo route delete -net 10.102.0.0 -netmask 255.255.0.0 172.16.16.10 > /dev/null
sudo route add -net 10.102.0.0 -netmask 255.255.0.0 172.16.16.10 > /dev/null
sudo route delete -net 10.101.0.0 -netmask 255.255.0.0 172.16.16.10 > /dev/null
sudo route add -net 10.101.0.0 -netmask 255.255.0.0 172.16.16.10 > /dev/null
