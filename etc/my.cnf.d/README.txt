#
# ViciBox v.10.0 MariaDB 10.5.X config for OpenSuSE Leap 15.3
# 
# Recommended hardware for this config file :
#  - 8-Core CPU 2.0Ghz or up (Real cores!!! not threads)
#  - 16GB of RAM for 250 or less agents, 32GB or up for more agents
#  - At least 512GB of SSD configured in a RAID1 (Hardware or Linux MD)
#
#
#
# Tips, Tricks, and Cheats :
#  - ALL DISCRETIONARY BUDGET SHOULD GO TOWARDS FAST DATABASE DRIVES, 
#      FOLLOWED BY RAM, FOLLOWED BY CPU. That's the order of importance
#      for your standard ViciDial database before custom stuff gets
#      thrown into the mix. More info below.
#
#  - 256GB SSD/NVMe can be used if mounted under /srv/mysql/data while
#      using regular SATA 7200-rpm (or up) enterprise drives for the OS.
#      Please be careful that you don't do this AFTER you have set-up 
#      ViciDial otherwise you will need to move the database files or
#      create a back-up then re-import the whole database. Doing this 
#      wrong will wipe out all your data. You've been warned!
#
#  - If given a choice, more GHz is better then more CPU within the same
#      generation of CPU. For example a CPU with 8-cores at 2.1GHz gives
#      you a performance metric of 16.8 (Cores x GHz). A 6-core CPU at
#      3.0GHz gives you a performance metric of 18. So for MariaDB the
#      6-Core CPU at 3.0GHz would be faster then the 8-core CPU at 2.1GHz.
#      Your average 300-agent call center is quite happy with an 8-core
#      CPU until the custom report developers and management gets in 
#      there and starts data mining. Use a slave for that!!!
#
#  - There's not much of a reason to go above 128GB RAM as this config
#      and ViciDial in general doesn't really take advantage of it with
#      the generated workload. Sure it won't hurt, but it won't really 
#      help either. Better of spending that additional money on SSDs or
#      NVMe where you can afford it.
#
#  - NVMe drives are best used in a Linux MD RAID-1 attached directly
#      to the CPU through either a PCIe 3.0 add-in card or a M.2 to
#      PCIe 3.0 adapter card. Best performance is obtained when not 
#      using a 'PLX' or PCIe switch chip. An example of some NVMe to
#      PCIe adapter cards are the SuperMicro AOC-SLG3-2M2, the ASRock
#      Ultra Quad M.2, or using multiple StarTech PEX4M2E1 adapters.
#      The dual or quad M.2 cards require "PCIe Bifurcation" support
#      in the motherboards BIOS. Please check the motherboard block
#      diagram in the manual to identify which PCIe ports are directly
#      attached to the CPU. You can use Dual and Quad NVMe cards with a
#      PLX or PCIe switcher built in but they will bottleneck with a
#      modern NVMe. An example of these type of 'switching' adapters 
#      would be the SuperMicro AOC-SHG3-4M2P or Synology M2D18. In 
#      reality most call centers won't need the speed of NVMe until
#      around 300 agents or so, but it's nice to have on tap.
#
#  - Most onboard M.2 NVMe ports are not directly attached to the CPU, but
#      are actually attached to the chipset instead. A single modern NVMe
#      drive can max out the connection between the CPU and the chipset,
#      let alone two NVMe drives. You also have induced latency from the
#      CPU to Chipset transport as well.
#
#  - If you feel the need to tune this config file, you need to tune for
#      a 50/50 read to write workload or if anything a higher write
#      workload. Googling MariaDB performance tuning that uses something
#      like WordPress or Drupal or PHPBB as the target audience is not
#      really comprable to a ViciDial workload. The correct search terms
#      would be 'write intensive' or 'balanced' workload.
#
#  - There are no magic tuning or settings that can fix inadequate
#      hardware. Run 'iostat -dkx 1' and see how utilized your non-NVMe
#      drives are. If it's above 90%, there is no fix for that. NVMe's 
#      do not report utilization correctly in iostat so you'll need to
#      go by feel on those. Always used an SSD for /srv/mysql/data in a
#      RAID-1 whenever possible. Go cheap on the dialers/web, not the DB!!!
#