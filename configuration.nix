# ============================================================================
#  NixOS gaming configuration
#  CPU: Ryzen 9 7950X3D (dual CCD, 3D V-Cache)
#  GPU: RTX 4080 Super (Ada Lovelace, open kernel modules)
#  Monitor: Alienware AW3225QF — 4K / 240Hz / QD-OLED / HDR
# ============================================================================
{ config, pkgs, lib, ... }:

{
	# ── EDIT THESE ────────────────────────────────────────────────────────────
	networking.hostName = "arrakis";   # must match the name in flake.nix
	time.timeZone = "Asia/Kolkata";
	i18n.defaultLocale = "en_US.UTF-8";

	users.users.karikaalan0207 = {
		isNormalUser = true;
		extraGroups = [ "wheel" "networkmanager" "libvirtd" "docker" ];
		shell = pkgs.zsh;   # zsh as the login shell (see programs.zsh below)
	};
	# ──────────────────────────────────────────────────────────────────────────

	nixpkgs.config.allowUnfree = true;   # NVIDIA driver, Steam, unrar...

	nix = {
		settings = {
			experimental-features = [ "nix-command" "flakes" ];
			auto-optimise-store = true;
		};
		gc = {
			automatic = true;
			dates = "weekly";
			options = "--delete-older-than 14d";
		};
	};

	# ── Boot & kernel ─────────────────────────────────────────────────────────
	boot = {
		loader = {
			systemd-boot.enable = true;
			efi.canTouchEfiVariables = true;
		};

		# CachyOS kernel (BORE-derived tuning, sched-ext support) via chaotic-nyx.
		# Binary-cached, so no local kernel compile once the nyx cache is active.
		# Fallback if chaotic ever gives you trouble: pkgs.linuxPackages_latest
		kernelPackages = pkgs.linuxPackages_cachyos;

		kernelParams = [
			"nvidia_drm.fbdev=1"          # correct framebuffer/VT + Wayland behaviour on 545+
			"acpi_enforce_resources=lax"  # REQUIRED: MSI B650 Tomahawk SMBus is ACPI-locked;
			                              # without this the JRAINBOW/JRGB headers (and RAM
			                              # RGB) never show up in OpenRGB (i2c-piix4 path)
		];

		supportedFilesystems = [ "ntfs" ];   # mount Windows/game drives
		kernelModules = [ "kvm-amd" ];       # KVM/QEMU for Windows VMs (see virtualisation)
	};

	hardware = {
		cpu.amd.updateMicrocode = true;
		enableRedistributableFirmware = true;

		# GPU: NVIDIA
		graphics = {
			enable = true;
			enable32Bit = true;                                  # required for 32-bit Proton/Wine
			extraPackages = with pkgs; [ nvidia-vaapi-driver ];  # browser video accel
		};

		nvidia = {
			modesetting.enable = true;
			powerManagement.enable = false;   # flip to true only if suspend corrupts
			open = true;                      # open kernel modules — correct for Ada
			nvidiaSettings = true;
			# chaotic caches nvidia builds for the cachyos kernel; driver >= 595.58.03
			# gives you NATIVE Wayland HDR (VK_EXT_hdr_metadata) with no Vulkan layers.
			package = config.boot.kernelPackages.nvidiaPackages.latest;
		};

		bluetooth = {   # DualSense / Xbox controllers
			enable = true;
			powerOnBoot = true;
		};

		steam-hardware.enable = true;              # controller udev rules
		nvidia-container-toolkit.enable = true;    # GPU pass-in to docker (ML Path B)

		# Logitech wireless (Bolt/Unifying receiver): udev rules + Solaar GUI —
		# pairing, battery status, scroll ratchet/free-spin toggle (MX Master etc.)
		logitech.wireless = {
			enable = true;
			enableGraphical = true;
		};
	};
	

	# umu steamrt3 runtime — repo.steampowered.com is 403-blocked by the ISP's
	# Google edge cache; borrow Steam's copy (appid 1628350, different CDN).
	# Requires Steam to have downloaded "Steam Linux Runtime 3.0 (sniper)".
	systemd.tmpfiles.rules = [
		"L+ /home/karikaalan0207/.local/share/umu/steamrt3 - - - - /home/karikaalan0207/.local/share/Steam/steamapps/common/SteamLinuxRuntime_sniper"
	];
	zramSwap.enable = true;   # compressed RAM swap — free perf headroom
	# Declarative Lutris defaults — seeded from ./lutris/ snapshots, ONLY when
	# missing (never overwrites GUI changes).
	system.activationScripts.lutrisDefaults = {
		deps = [ "users" ];
		text = ''
			LUT=/home/karikaalan0207/.config/lutris
			install -d -m 755 -o karikaalan0207 -g users "$LUT" "$LUT/runners"
			install -m 644 -o karikaalan0207 -g users ${./lutris/system.yml} "$LUT/system.yml"
			install -m 644 -o karikaalan0207 -g users ${./lutris/wine.yml} "$LUT/runners/wine.yml"
		'';
	};	
	# 7950X3D: bias new threads to the 3D V-Cache CCD — DISABLED on this machine:
	# the board doesn't expose the AMDI0101 ACPI device (no
	# /sys/bus/platform/drivers/amd_3d_vcache/). A BIOS update may add it —
	# if `ls /sys/bus/platform/drivers/amd_3d_vcache/` ever shows a device,
	# uncomment this rule (add it to services.udev.extraRules below). Harmless
	# either way; scx_lavd handles the CCDs.
	#
	#   ACTION=="add", SUBSYSTEM=="platform", KERNEL=="AMDI0101:00", ATTR{amd_x3d_mode}="cache"

	services = {
		# sched-ext CPU scheduler (needs kernel >= 6.12; cachyos has it).
		# scx_lavd is latency-aware and behaves well on heterogeneous X3D chips.
		# Alternative worth trying: "scx_bpfland".
		scx = {
			enable = true;
			scheduler = "scx_lavd";
		};

		xserver.videoDrivers = [ "nvidia" ];

		# Desktop: KDE Plasma 6 on Wayland (best HDR support on Linux)
		displayManager.sddm = {
			enable = true;
			wayland.enable = true;
		};
		desktopManager.plasma6.enable = true;

		# Audio
		pulseaudio.enable = false;
		pipewire = {
			enable = true;
			alsa.enable = true;
			alsa.support32Bit = true;
			pulse.enable = true;
		};

		hardware = {
			# RGB: OpenRGB (board, RAM, GPU, monitor AlienFX if it enumerates).
			# If you want newest device support (e.g. the AW3225QF's AlienFX zones
			# over USB), chaotic ships openrgb_git — try: package = pkgs.openrgb_git;
			openrgb = {
				enable = true;
				package = pkgs.openrgb-with-all-plugins;
				motherboard = "amd";   # AMD SMBus (i2c-piix4) wiring handled for you
			};

			# DeepCool CH510 DIGITAL display.
			# Fully supported by deepcool-digital-linux (CPU/GPU temp on the display).
			# NixOS module = package + auto-starting daemon. Manual control anytime:
			#   sudo deepcool-digital-linux --list   (detect devices / product IDs)
			#   sudo deepcool-digital-linux -m ...   (display modes, see --help)
			deepcool-digital-linux.enable = true;
		};

		# DeepCool display MCUs stall when the kernel USB-autosuspends them —
		# force the device permanently on (matches every AIO/LCD tool's advice).
		udev.extraRules = ''
			ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="3633", ATTR{idProduct}=="000a", TEST=="power/control", ATTR{power/control}="on"
		'';
		flatpak.enable = true;
	};

	security.rtkit.enable = true;   # realtime priority for PipeWire

	# Passwordless sudo for the wheel group (karikaalan0207 is in wheel).
	# Note: any process running as your user can then become root without a password.
	security.sudo.wheelNeedsPassword = false;

	# Google Drive → ~/GoogleDrive via rclone (FUSE). One-time OAuth setup first:
	#   rclone config        (n → name: gdrive → storage: drive → accept the
	#   defaults → "yes" for auto config — it opens a browser tab to sign in)
	# Until ~/.config/rclone/rclone.conf exists this service does nothing.
	# Manual control: systemctl --user start/stop/restart rclone-gdrive
	systemd.user.services.rclone-gdrive = {
		description = "Google Drive (rclone FUSE mount)";
		wantedBy = [ "default.target" ];
		unitConfig.ConditionPathExists = "%h/.config/rclone/rclone.conf";
		# The setuid fusermount3 (/run/wrappers/bin, from programs.fuse) must
		# come first in PATH — rclone's nixpkgs wrapper appends fuse3's
		# non-setuid copy, which loses otherwise.
		environment.PATH = lib.mkForce "/run/wrappers/bin:/run/current-system/sw/bin";
		serviceConfig = {
			ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/GoogleDrive";
			# rclone unmounts cleanly on SIGTERM, so no ExecStop is needed.
			ExecStart = "${pkgs.rclone}/bin/rclone mount gdrive: %h/GoogleDrive --vfs-cache-mode writes";
			Restart = "on-failure";
			RestartSec = "10s";
		};
	};

	# Applies your saved OpenRGB profile at login. One-time GUI step first:
	# set the zones (MSI board: JRAINBOW1 / JRAINBOW2 — set the correct LED
	# count per header or colors will glitch; NZXT HUE 2: Channel 3 zone),
	# then Profiles → Save as ~/.config/OpenRGB/main.orp. Until that file
	# exists this service simply does nothing.
	systemd.user.services.openrgb-profile = {
		description = "Apply saved OpenRGB profile";
		wantedBy = [ "graphical-session.target" ];
		unitConfig.ConditionPathExists = "%h/.config/OpenRGB/default.orp";
		serviceConfig = {
			Type = "oneshot";
			ExecStart = "${config.services.hardware.openrgb.package}/bin/openrgb --profile %h/.config/OpenRGB/default.orp";
		};
	};
	# logid daemon (logiops) — gesture button / button remapping for Logitech
	# MX Master mice. Reads /etc/logid.cfg (defined in environment.etc below).
	systemd.services.logid = {
		description = "Logitech device configuration daemon (logiops)";
		wantedBy = [ "multi-user.target" ];
		serviceConfig = {
			ExecStart = "${pkgs.logiops}/bin/logid";
			Restart = "on-failure";
			RestartSec = "5s";
		};
	};

	# Ollama — local LLM server for the agentic coding workflow (opencode +
	# Qwen3-Coder). Vulkan build: ollama-cuda fails to build from source on
	# this nixpkgs pin (ggml-cuda can't find nvcc — malformed CUDAToolkit_ROOT),
	# and Vulkan on the RTX 4080 Super gets most of CUDA's inference speed.
	# Listens on localhost:11434. Models are pulled imperatively with
	# `ollama pull` (stored in /var/lib/ollama), not declared here — and never
	# preloaded (no loadModels): VRAM is only used while actually coding.
	services.ollama = {
		enable = true;
		package = pkgs.ollama-vulkan;
	};

	# ── Gaming: Steam / Epic / GOG / standalone Windows games ────────────────
	programs = {
		# ssh-agent as a user service — the GitHub key (~/.ssh/id_ed25519)
		# is offered automatically without needing ssh-add each login.
		ssh.startAgent = true;

		steam = {
			enable = true;
			gamescopeSession.enable = true;               # adds a "Steam (Gamescope)" session
			remotePlay.openFirewall = true;               # to SDDM; safe to ignore if unused
			dedicatedServer.openFirewall = true;
			localNetworkGameTransfers.openFirewall = true;
			protontricks.enable = true;
			extraCompatPackages = with pkgs; [
				proton-ge-bin              # GE-Proton, selectable per game in Steam
				proton-cachyos_x86_64_v3   # Proton-CachyOS built for x86-64-v3 (Zen 4/5) — from chaotic
				steamtinkerlaunch          # Swiss-army knife for per-game tweaks
			];
		};

		gamescope = {
			enable = true;
			capSysNice = true;
			enableWsi = true;
		};

		gamemode = {
			enable = true;
			settings = {
				general.renice = 10;
				cpu.desiredgov = "performance";
			};
		};

		# AppImage support (lots of game tools/mod managers ship as AppImages)
		appimage = {
			enable = true;
			binfmt = true;
		};

		nix-ld.enable = true;        # keeps manylinux binaries happy (see ML section)
		virt-manager.enable = true;  # GUI for the libvirtd VMs below

		# ── Shell: zsh + oh-my-zsh + powerlevel10k ─────────────────────────────
		zsh = {
			enable = true;
			enableCompletion = true;           # tab completion
			autosuggestions.enable = true;     # fish-like grey inline suggestions (→ to accept)
			syntaxHighlighting.enable = true;  # colors commands red/green as you type
			ohMyZsh = {
				enable = true;
				theme = "powerlevel10k/powerlevel10k";
				customPkgs = with pkgs; [ zsh-powerlevel10k ];
				plugins = [ "git" "sudo" "docker" "colored-man-pages" ];
			};
		};
	};

	# MesloLGS NF — the font powerlevel10k is designed for (set it in Konsole:
	# Settings → Edit Profile → Appearance → Font). Wizard: `p10k configure`.
	fonts.packages = with pkgs; [ nerd-fonts.meslo-lg ];

	environment = {
		systemPackages = with pkgs; [
			# Launchers / runners for non-Steam stuff
			heroic                         # Epic + GOG (Legendary under the hood)
			lutris                         # general Windows-game runner; handles
			umu-launcher                   # Proton-outside-Steam (used by both above)
			wineWow64Packages.stagingFull  # system Wine (new WoW64 mode) for installers/tools
			winetricks
			cabextract
			gamescope

			# Monitoring / debugging
			mangohud
			goverlay                       # GUI for MangoHud + vkBasalt configs
			vulkan-tools                   # vulkaninfo --summary
			nvtopPackages.nvidia           # GPU top

			# Logitech MX Master: logid userspace driver (gesture button, remapping).
			# Runs as the logid systemd service below; config in /etc/logid.cfg.
			logiops

			# Archives you'll inevitably meet
			p7zip
			unrar

			# Everyday
			git
			vim
			htop
			rclone                         # Google Drive mount (see rclone-gdrive service above)
			firefox
			chromium                       # also powers the Kimi app-window launcher below
			google-chrome
			obsidian
			qbittorrent
			vlc                            # general playback; for HDR VIDEO use mpv instead —
			mpv                            # VLC 3.x can't output HDR on Wayland, mpv can (gpu-next)
			nodejs_24                      # system Node — runtime for Kimi Code CLI (below)
			(pkgs.callPackage ./pkgs/kimi-code.nix { })
			# Python / data-science base (ML libs live in the venv — see ML section)
			python3
			uv                             # fast pip replacement — manages the ML venv
			pre-commit                     # git hook framework (agentic workflow gate)

			# Kimi "app" launcher — opens kimi.com as its own Chrome app window
			# (no official Linux build of the Kimi desktop app exists; see the
			# AI-tooling section below).
			(pkgs.makeDesktopItem {
				name = "kimi";
				desktopName = "Kimi";
				genericName = "AI Assistant";
				comment = "Kimi AI assistant";
				exec = "${pkgs.google-chrome}/bin/google-chrome-stable --app=https://www.kimi.com";
				terminal = false;
				categories = [ "Network" "Utility" ];
			})

			# Lutris/umu launcher shim — use as Lutris "Command prefix":
			#   /run/current-system/sw/bin/gamescope-hdr
			# Fixes Lutris's empty VK_ICD_FILENAMES/VK_DRIVER_FILES (blanks Vulkan's
			# ICD search path on NixOS) and strips leaked caps before umu's bwrap.
			(writeShellScriptBin "gamescope-hdr" ''
				unset VK_ICD_FILENAMES VK_DRIVER_FILES
				exec ${gamescope}/bin/gamescope \
					--hdr-enabled --prefer-vk-device 10de:2702 \
					-w 3840 -h 2160 -f \
					-- ${util-linux}/bin/setpriv --ambient-caps=-all --inh-caps=-all "$@" \
					> /tmp/gamescope-hdr.log 2>&1
			'')
			(writeShellScriptBin "gamescope-hdr-itm" ''
				unset VK_ICD_FILENAMES VK_DRIVER_FILES
				exec ${gamescope}/bin/gamescope \
				--hdr-enabled --prefer-vk-device 10de:2702 \
				--hdr-sdr-content-nits 300 \
				--hdr-itm-enable --hdr-itm-target-nits 1000 \
				-w 3840 -h 2160 -f \
				-- ${util-linux}/bin/setpriv --ambient-caps=-all --inh-caps=-all "$@" \
				> /tmp/gamescope-hdr.log 2>&1
			'')
			
		];

		# ~/.local/bin on PATH — where per-user npm global installs land
		localBinInPath = true;

		# logid (logiops) config for the MX Master 4 (name verified via `logid -v`).
		#   thumb wheel      → volume down/up
		#   side buttons     → browser back / forward
		#   gesture button   → Ctrl+Alt+T (bound to Konsole in KDE shortcuts)
		# To adapt for another model, find its name with: sudo logid -v
		etc."logid.cfg".text = ''
			devices: ({
				name: "MX Master 4";

				smartshift: {
					on: true;
					threshold: 15;
				};

				hiresscroll: {
					hires: true;
					invert: false;
					target: false;
				};

				# Thumb scroll wheel → volume
				thumbwheel: {
					divert: true;
					invert: false;

					left: {
						mode: "OnInterval";
						interval: 2;
						action = { type: "Keypress"; keys: ["KEY_VOLUMEDOWN"]; };
					};
					right: {
						mode: "OnInterval";
						interval: 2;
						action = { type: "Keypress"; keys: ["KEY_VOLUMEUP"]; };
					};
				};

				buttons: (
					{
						cid: 0xc3;   # thumb/gesture button → launch terminal
						action = { type: "Keypress"; keys: ["KEY_LEFTCTRL", "KEY_LEFTALT", "KEY_T"]; };
					},
					{
						cid: 0x53;   # back button
						action = { type: "Keypress"; keys: ["KEY_BACK"]; };
					},
					{
						cid: 0x56;   # forward button
						action = { type: "Keypress"; keys: ["KEY_FORWARD"]; };
					}
				);
			});
		'';

		sessionVariables = {
			LIBVA_DRIVER_NAME = "nvidia";
			NVD_BACKEND = "direct";
			# Lets pip CUDA wheels (torch/tf/jax/numba/cupy) dlopen the NVIDIA driver.
			# Harmless for normal apps (it's the same driver dir the GL stack uses);
			# drop it if some app ever complains about library conflicts.
			LD_LIBRARY_PATH = "/run/opengl-driver/lib";
		};
	};

	# ── AI tooling ────────────────────────────────────────────────────────────
	# Kimi Code CLI (Moonshot's terminal agent) — packaged in pkgs/kimi-code.nix
	# and installed via systemPackages above; it runs on the system Node, which
	# sidesteps the dynamic-linker problems the curl-installed prebuilt binary
	# hits on NixOS. First run: `kimi` → /login → Kimi OAuth or API key.
	# Update later with: kimi upgrade
	# Needs Node ≥ 22.19 — nodejs_24 satisfies it. Don't confuse it with the
	# legacy Python "kimi-cli" package (that's the discontinued one).
	#
	# Google Antigravity (`agy` CLI + the IDE editor) is installed in flake.nix
	# via the antigravity-nix flake — no npm needed for those.
	#
	# Kimi desktop app: Moonshot ships NO official Linux build (Kimi Work is
	# Windows/macOS only) — the launcher above (in systemPackages) is the
	# closest thing: kimi.com as its own Chrome app window.

	# ── ML / data science: CUDA on the 4080 Super ─────────────────────────────
	# Two supported paths. (Nixpkgs-native CUDA torch is deliberately excluded:
	# it means multi-hour source builds and lags upstream releases.)
	#
	#  PATH A — uv/pip venv with official CUDA wheels (recommended; notebooks)
	#    The wheels bundle the full CUDA runtime themselves — they only need
	#    to find the DRIVER, which on NixOS lives in /run/opengl-driver/lib.
	#    That's what LD_LIBRARY_PATH above is for; nix-ld additionally keeps
	#    manylinux binaries happy in general.
	#
	#    One-time setup:
	#      uv venv ~/ml && source ~/ml/bin/activate
	#      uv pip install jupyterlab numpy pandas scikit-learn matplotlib seaborn
	#      uv pip install torch torchvision --torch-backend=auto
	#        # alternatives: `uv pip install tensorflow`  /  `uv pip install "jax[cuda12]"
	#    Sanity check:
	#      python -c "import torch; print(torch.cuda.is_available(), torch.cuda.get_device_name(0))"
	#    Run:  jupyter lab
	#
	#  PATH B — NVIDIA containers (for RAPIDS, NGC stacks, exact repro envs)
	#      docker run --rm -it --device nvidia.com/gpu=all -p 8888:8888 \
	#        -v ~/notebooks:/workspace nvcr.io/nvidia/pytorch:25.06-py3
	#    (check catalog.ngc.nvidia.com for the current tag; note the CDI syntax
	#    `--device nvidia.com/gpu=all` — plain `--gpus all` is unreliable with
	#    current docker + container-toolkit on NixOS)

	# ── Virtualisation: KVM/QEMU for Windows VMs ──────────────────────────────
	virtualisation = {
		docker = {
			enable = true;
			daemon.settings.features.cdi = true;   # GPU pass-in via CDI (ML Path B)
		};

		libvirtd = {
			enable = true;
			qemu = {
				package = pkgs.qemu_kvm;
				runAsRoot = true;
				swtpm.enable = true;   # emulated TPM — Windows 11 requirement
			};
		};
		spiceUSBRedirection.enable = true;
	};

	# ── OPTIONAL: VFIO GPU passthrough (Windows VM owns the 4080S) ────────────
	# The 7950X3D has an iGPU, so the host can run on it while the 4080S is
	# passed through. To set up: enable IOMMU + SVM in BIOS, get your GPU's IDs
	# with `lspci -nn` (the video function AND its HDMI-audio function), then
	# merge into the boot block above:
	#
	#   boot.kernelParams = [ "amd_iommu=on" "iommu=pt" ];
	#   boot.kernelModules = [ "vfio" "vfio_pci" "vfio_iommu_type1" ];
	#   boot.extraModprobeConfig = ''
	#     options vfio-pci ids=10de:XXXX,10de:YYYY
	#   '';
	#
	# Pair it with Looking Glass (pkgs.looking-glass-client) for zero-cable
	# display. Commented out by default so boot is never blocked by a stale ID.

	# ── Networking ────────────────────────────────────────────────────────────
	networking = {
		networkmanager = {
			enable = true;
			dns = "none";
		};
		useDHCP = false;
		nameservers = [ "192.168.1.19" ];
	};
	# Firewall stays ON by default; the steam options above open what they need.

	# Match this to the NixOS release of your install ISO, then never touch it.
	system.stateVersion = "25.11";
}
