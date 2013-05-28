def local_cache(box_name, purpose)
  cache_dir = File.join(File.expand_path(Vagrant::Environment::DEFAULT_HOME),
                        'cache',
                        purpose,
                        box_name)
  partial_dir = File.join(cache_dir, 'partial')
  FileUtils.mkdir_p(partial_dir) unless File.exists? partial_dir
  cache_dir
end

Vagrant.configure("2") do |config|
  config.ssh.forward_x11 = true
  config.vm.box = "precise64"
  config.vm.box_url = "http://files.vagrantup.com/precise64.box"
  config.vm.provision :shell, :inline => $BOOTSTRAP_SCRIPT # see below
  config.vm.network :forwarded_port, guest: 27017, host: 27017 # Mongo
  config.vm.network :forwarded_port, guest: 28017, host: 28017 # MongoWeb
  config.vm.network :forwarded_port, guest: 8080, host: 8080 # Web

  # enable audio
  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, '--audio', 'coreaudio', '--audiocontroller', 'hda']
  end

  # apt package caching
  config.vm.synced_folder (local_cache config.vm.box, 'apt'), "/var/cache/apt/archives/"

  # roms
  #config.vm.synced_folder '/Users/giro/Dropbox/ROMS/', "/var/roms/"
  config.vm.synced_folder '/Dropbox/ROMS/', "/var/roms/"
end

$BOOTSTRAP_SCRIPT = <<EOF
	set -e # Stop on any error

	# --------------- SETTINGS ----------------
	# Other settings
	export DEBIAN_FRONTEND=noninteractive

	# --------------- APT-GET REPOS ----------------
	# Install prereqs
	sudo apt-get update
	sudo apt-get install -y python-software-properties build-essential gcc g++ git-core
	sudo add-apt-repository ppa:chris-lea/node.js
	sudo apt-get update
	sudo apt-get install -y libxml2-dev libxslt-dev
	sudo apt-get install -y mongodb coffeescript nodejs

	# ----------------- MONGODB -----------------
	sudo sed -ibak 's/bind_ip = 127.0.0.1/bind_ip = 0.0.0.0/' /etc/mongodb.conf
	sudo mongod --config /etc/mongodb.conf --shutdown
	sudo nohup bash -c "mongod --config /etc/mongodb.conf &"

  #--------------- SNES9X
  sudo add-apt-repository ppa:bearoso/ppa
  sudo apt-get update
  apt-cache search snes9x
  sudo apt-get install -y snes9x-gtk pkg-config libasound2-dev esound alsa-utils asoundconf-gtk

  #--------------- RETROARCH / LIBRETRO
  sudo apt-get install -y libgl1-mesa-dev libglu1-mesa-dev
  cd ~/
  git clone https://github.com/Themaister/RetroArch.git
  cd RetroArch
  ./configure
  make
  make install
  cd ~/
  git clone https://github.com/libretro/snes9x-next.git
  cd snes9x-next
  ./compile_libretro.sh make
  cp snes9x_next_libretro.so ~vagrant
  chown vagrant ~vagrant/snes9x_next_libretro.so
  # TEST IT:   retroarch -L snes9x_next_libretro.so /var/roms/SNES/Animaniacs.smc

  # ---- OSS AUDIO
  sudo usermod -a -G audio vagrant
  sudo apt-get install -y oss4-base oss4-dkms oss4-source oss4-gtk linux-headers-3.2.0-23 debconf-utils
  sudo ln -s /usr/src/linux-headers-$(uname -r)/ /lib/modules/$(uname -r)/source || echo ALREADY SYMLINKED
  sudo module-assistant prepare
  sudo module-assistant auto-install -i oss4 # this can take 2 minutes
  sudo debconf-set-selections <<< "linux-sound-base linux-sound-base/sound_system select  OSS"
  echo READY.

  # have to reboot for drivers to kick in, but only the first time of course
  if [ ! -f ~/runonce ]
  then
    sudo reboot
    touch ~/runonce
  fi


EOF
