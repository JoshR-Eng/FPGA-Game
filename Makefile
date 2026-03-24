
# --- Variables ---
COMPILER = iverilog
FLAGS = -g2012
SOURCES = 
OUTPUT = sim.vvp
WAVES = waves.vcd

# --- Testbench Examples ---
# Uncomment one of these to set SOURCES, or define your own
SOURCES = tb/mouse_tb.v src/mouse.v


# "sim" recipe: This compiles, runs and open the waves
sim: build run wave

# Recipe to compile the code
build:
	$(COMPILER) $(FLAGS) -o $(OUTPUT) $(SOURCES)

# Recipe to run the simulation
run: build
	vvp $(OUTPUT)

# Recipe to open GTKWAVE
wave: run
	gtkwave $(WAVES) &

# Recipe to clean up hte junk files when done
clean:
	rm -f $(OUTPUT) $(WAVES)


.PHONY: sim build run wave clean
