{ config, pkgs, ... }:

with pkgs.lib;
let
	openrgb_overlay = (self: super: {
		openrgb = super.openrgb.overrideAttrs (prev: rec {
			version = "master";
			src = super.fetchFromGitLab {
				owner = "CalcProgrammer1";
				repo = "OpenRGB";
				rev = "master";
				hash = "sha256-8DcLt20Rsu5UPiq9ebFHObP8hJ1vzFMgYDuygM1nyrQ="; # Replace with correct hash
			};
			# Add buildInputs and patch udev script to handle /usr/bin/env
			buildInputs = prev.buildInputs or [] ++ [
				super.hidapi
			];
			postPatch = prev.postPatch or "" + ''
			substituteInPlace scripts/build-udev-rules.sh \
				--replace "/usr/bin/env" "${super.coreutils}/bin/env"
			'';

			# Ensure udev rules reference correct env path
			postInstall = prev.postInstall or "" + ''
			substituteInPlace $out/lib/udev/rules.d/60-openrgb.rules \
				--replace "/usr/bin/env" "${super.coreutils}/bin/env"
			'';
		});
	});
	deepcool-digital-linux = pkgs.callPackage ./deepcool/deepcool-digital-linux.nix {};
in
{
	# Allow unfree packages for proprietary NVIDIA drivers
	nixpkgs.config.allowUnfree = true;
	nix.settings.experimental-features = [ "nix-command" "flakes" ];
	nixpkgs.overlays = [ openrgb_overlay ];
	# Bootloader configuration
	boot.loader.systemd-boot.enable = true;
	boot.loader.efi.canTouchEfiVariables = true;
	boot.loader.systemd-boot.configurationLimit = 3;
	
	# Hostname
	networking.hostName = "Arrakis";

	# Networking
	networking.networkmanager.enable = true;

	# Time zone and localization
	time.timeZone = "Asia/Kolkata";
	i18n.defaultLocale = "en_IN";
	i18n.extraLocaleSettings = {
		LC_ADDRESS = "en_IN";
		LC_IDENTIFICATION = "en_IN";
		LC_MEASUREMENT = "en_IN";
		LC_MONETARY = "en_IN";
		LC_NAME = "en_IN";
		LC_NUMERIC = "en_IN";
		LC_PAPER = "en_IN";
		LC_TELEPHONE = "en_IN";
		LC_TIME = "en_IN";
	};

	# Filesystem support
	boot.supportedFilesystems = [ "ntfs" ];

	# Desktop environment
	services.xserver.enable = true;
	services.displayManager.sddm.enable = true;
	services.desktopManager.plasma6.enable = true;
	#services.xserver.desktopManager.cinnamon.enable = true;
	services.xserver.displayManager.lightdm.greeters.gtk.theme.package = pkgs.numix-gtk-theme;
	services.xserver.displayManager.lightdm.greeters.gtk.iconTheme.package = pkgs.numix-icon-theme-circle;
	# Configure keymap in X11
	services.xserver = {
		#layout = "us";
		#xkbVariant = "";
		xkb.layout = "us";
		xkb.variant = "";
	};
	# NVIDIA drivers and CUDA support
	hardware.graphics.enable = true;
	hardware.nvidia = {
		open = false;
		modesetting.enable = true;
		package = config.boot.kernelPackages.nvidiaPackages.stable;
		nvidiaSettings = true;
		# prime.offload.enable = true;
		# prime.nvidiaBusId = "PCI:1:0:0";
		powerManagement.enable = true;
		# powerManagement.finegrained = true;
	};
	services.xserver.videoDrivers = [ "nvidia" ];

	hardware.bluetooth = {
		enable = true;
		powerOnBoot = true; # Automatically powers up the Bluetooth controller on boot
	};

	# Enable 32-bit support libraries
	hardware.opengl = {
		enable = true;
		driSupport32Bit = true;
	};

	# Audio
	services.pipewire = {
		enable = true;
		alsa.enable = true;
		pulse.enable = true;
	};

	# User configuration
	users.users.karikaalan0207 = {
		isNormalUser = true;
		extraGroups = [ "wheel" "video" "docker" "networkmanager" "plugdev" ];
		shell = pkgs.zsh;
	};

	# System packages
	environment.systemPackages = with pkgs; [
		vim
		emacs
		vscode
		zsh
		zsh-powerlevel10k
		vlc
		gcc
		go
		obsidian
		git
		gitAndTools.delta
		gitAndTools.gh
		git-lfs
		ntfs3g
		google-chrome
		lm_sensors
		i2c-tools
		nvtop
		hwinfo
		glances
		htop
		tmux
		neofetch
# 		heroic
# 		steam
# 		lutris
# 		wine
# 		dxvk
# 		vkd3d
		libva
		libva-utils
		liquidctl
		usbutils
		i2c-tools
		deepcool-digital-linux
		toybox
		pciutils
		python3Full
		python3Packages.hidapi
		python3Packages.psutil
		python3Packages.json5
		python3Packages.jupyterlab
		python3Packages.notebook
		python3Packages.ipykernel
		python3Packages.pandas
		python3Packages.matplotlib
		python3Packages.numpy
		python3Packages.scipy
		python3Packages.requests
	];
	programs.nix-ld.enable = true;
	programs.nix-ld.libraries = with pkgs; [
		# Add any missing dynamic libraries for unpackaged programs
		# here, NOT in environment.systemPackages
	];

	programs.ssh.startAgent = true;

	# ZSH configuration with Powerlevel10k
	programs.zsh = {
		enable = true;
		syntaxHighlighting.enable = true;
		promptInit = "source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
		ohMyZsh = {
			enable = true;
			plugins = [ "git" "sudo" ];
		};
	};

	# Firewall configuration
	networking.firewall = {
		enable = true;
		allowedTCPPorts = [ 22 80 443 ];
		allowedUDPPorts = [ 5353 ];
	};

	# OpenSSH service
	services.openssh.enable = true;

	# Docker service with NVIDIA Container Toolkit
	virtualisation.docker = {
		enable = true;
		enableNvidia = true;
	};

	virtualisation.libvirtd.enable = true;

	# JupyterHub service
	services.jupyterhub = {
		enable = true;
		port = 8000;
	};

	# OpenRGB
	services.hardware.openrgb = {
		enable = true;
		motherboard = "amd";
	};
	hardware.i2c.enable = true;

	systemd.services.deepcool-digital-linux = {
		description = "DeepCool Digital Linux Service";
		after = [ "network.target" ];
		wantedBy = [ "multi-user.target" ];
		serviceConfig = {
			ExecStart = "${deepcool-digital-linux}/bin/deepcool-digital-linux";
			Restart = "on-failure";
			User = "root";
		};
	};

	# Udev rules for device access
	services.udev.extraRules = ''
	  # DeepCool HID raw devices
	  SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3633", MODE="0666"
	'';
	

	# System state version
	system.stateVersion = "24.11";
}
