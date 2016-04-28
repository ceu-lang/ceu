# INSTALLATION

# (Assuming a Ubuntu machine.)

# Install required software:

> sudo apt-get install git lua5.1 liblua5.1-dev lua-lpeg

# Clone Céu repository:

> git clone https://github.com/fsantanna/ceu
> cd ceu/

# Run self tests:

> ./run_tests.lua
> cp ceu /usr/local/bin/  # copy ceu to your path

# Include Céu in your path:

> echo 'export PATH="$PATH:/.../ceu/"' >> ~/.bashrc
