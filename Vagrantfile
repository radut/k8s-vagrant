# -- mode: ruby --
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  #config.vm.box = "bento/ubuntu-16.04"
  config.vm.box = 'ubuntu/bionic64'
  config.vm.hostname = "k8s-master"

  config.vm.network "private_network", ip: "172.16.16.10", :adapter => 2
  config.vm.synced_folder "./vagrant_data", "/vagrant_data"
#  config.vm.synced_folder "/work", "/work"

  config.vm.provider "virtualbox" do |vb|
    vb.customize [
      "modifyvm", :id,
      "--paravirtprovider", "default"
    ]
    vb.gui = false

    vb.memory = "4096"
    vb.cpus = "4"
  end

  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    sudo bash /vagrant_data/linux.sh --with-docker --with-kubernetes --with-helm --with-kubeadm-init  --disable-swap --vm
  SHELL
end

