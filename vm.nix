# ============================================================================
#  VM variant — VMware Workstation (Windows host)
#  Imported ONLY by the `arrakis-vm` flake target. Swaps the bare-metal GPU
#  stack for the VMware guest driver; everything else comes from
#  configuration.nix unchanged.
# ============================================================================
{ lib, ... }:

{
	# VMware's virtual GPU (vmwgfx) instead of NVIDIA. mkForce beats the value
	# in configuration.nix. Plasma/Wayland uses the kernel vmwgfx driver; the
	# "vmware" X driver only matters if you ever fall back to an X11 session.
	services.xserver.videoDrivers = lib.mkForce [ "vmware" ];

	# Belt and braces: make sure no NVIDIA kernel params/modules leak in.
	hardware.nvidia = {
		modesetting.enable = lib.mkForce false;
		open = lib.mkForce false;
	};

	# open-vm-tools: clipboard, drag & drop, display autoresize, shared folders.
	virtualisation.vmware.guest.enable = true;

	# Things that stay HARMLESS in a VM (no action needed):
	#   - the amd_3d_vcache udev rule simply never matches (no such ACPI device)
	#   - OpenRGB starts, finds no SMBus devices, idles
	#   - scx_lavd and the CachyOS kernel run fine under VMware
	#
	# Things you CANNOT meaningfully test in a VM:
	#   - NVIDIA driver, HDR, 240Hz, G-Sync  (virtual GPU has none of these)
	#   - OpenRGB device detection / AlienFX (no hardware SMBus)
	#   - real game performance (vmwgfx 3D is basic — desktop smoke-test only)
	#   - libvirtd/KVM inside the guest, UNLESS you tick
	#     "Virtualize AMD-V/RVI" (nested virtualisation) in the VM's CPU settings

	# ── VirtualBox instead? ──────────────────────────────────────────────────
	# services.xserver.videoDrivers = lib.mkForce [ "modesetting" ];
	# virtualisation.virtualbox.guest.enable = true;
	# ── Hyper-V instead? ─────────────────────────────────────────────────────
	# services.xserver.videoDrivers = lib.mkForce [ "modesetting" ];
	# virtualisation.hypervGuest.enable = true;
}
