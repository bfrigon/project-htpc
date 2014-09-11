###################################################################
# Output filename:
PROJECT		= lcd_firmware

# Architecture:
ARCH		= pic16

# CPU type:
CPU			= 18f2520

# Source file:
SOURCES		= $(wildcard *.asm)
OBJECTS		= $(SOURCES:.asm=.o)
LIBS		= 

# Flags:
ASFLAGS		= -c -p$(CPU) -w 2 -e on
LDFLAGS		= -m -c -s $(CPU).lkr


SERIAL_PORT = /dev/ttyUSB0
SERIAL_SPEED = 38400

FLASH		= ~/bin/18floader
FLASH_ARGS  = --skip-blocks 0-3FF -b 38400 $(SERIAL_PORT)


###################################################################

AS			= /usr/local/bin/gpasm
LD			= /usr/local/bin/gplink

GPUTILS_DIR = /usr/local/share/gputils


###################################################################
all: $(PROJECT).hex

###################################################################
$(PROJECT).hex: $(OBJECTS)
	@echo "*** Linking..."
	@$(LD) $(LDFLAGS) -o $(PROJECT).hex $(OBJECTS) $(LIBS)
	@echo ";PIC$(CPU)" >> $(PROJECT).hex


###################################################################
%.o: %.asm
	@echo "*** Assembling $<..."
	@$(AS) $(ASFLAGS) $<

	
###################################################################
clean:
	@$(RM) *.hex *.cof *.dasm *.lst *.o *.cod *.map
	@echo "*** Project directory cleaned."



###################################################################
flash: all
	$(eval STATUS=$(shell $(FLASH) --ping $(SERIAL_PORT) --silent > /dev/null 2>&1; echo $$?))

	@if [ "$(STATUS)" -eq "254" ]; then \
		cat tests/cmd_bootloader.bin > /dev/ttyUSB0; \
		sleep 1; \
	fi

	@$(FLASH) $(PROJECT).hex $(FLASH_ARGS)

###################################################################
test:
	@picocom -b $(SERIAL_SPEED) $(SERIAL_PORT)
	
	
.PHONY: clean flash test all
