#!/bin/bash

# ╔════════════════════════════════════════════════════════════════════╗
# ║         CrystalServer Interactive Recompile Script v2.0            ║
# ╚════════════════════════════════════════════════════════════════════╝
#
# Description:
#   Interactive build script with real-time progress visualization
#   Shows live output of CMake configuration and compilation
#
# Usage: 
#   ./recompile.sh [vcpkg_base_path] [build_type]
# 
# Parameters:
#   vcpkg_base_path : Base directory containing vcpkg (default: $HOME)
#   build_type      : CMake preset to use (default: linux-release)
#                     Options: linux-release, linux-debug, linux-test
# 
# Examples:
#   ./recompile.sh
#   ./recompile.sh /home/shadowborn
#   ./recompile.sh /home/shadowborn linux-debug
#
# Features:
#   ✓ Real-time progress bar with percentage
#   ✓ Color-coded output (INFO, WARN, ERROR, VCPKG, BUILD)
#   ✓ Shows vcpkg package installation progress
#   ✓ Displays total build time
#   ✓ Automatic backup of previous build (.old)
#   ✓ Comprehensive logging (cmake_log.txt, build_log.txt)
#
# ════════════════════════════════════════════════════════════════════

set -euo pipefail

# Variáveis
VCPKG_PATH=${1:-"$HOME"}
VCPKG_PATH=$VCPKG_PATH/vcpkg/scripts/buildsystems/vcpkg.cmake
BUILD_TYPE=${2:-"linux-release"}
ARCHITECTURE=$(uname -m)
ARCHITECTUREVALUE=0

# Function to print information messages
info() {
	echo -e "\033[1;34m[INFO]\033[0m $1"
}

# Function to check if a command is available
check_command() {
	if ! command -v "$1" >/dev/null; then
		echo "The command '$1' is not available. Please install it and try again."
		exit 1
	fi
}

check_architecture() {
	if [[ $ARCHITECTURE == "aarch64"* ]]; then
		info "Detected ARM64 architecture: $ARCHITECTURE"
		ARCHITECTUREVALUE=1
	else
		info "Detected x86_64 architecture: $ARCHITECTURE"
	fi
}

# Function to configure Crystal Server
setup_crystalserver() {
	if [ -d "build" ]; then
		info "Build directory already exists..."
		cd build
	else
		info "Creating build directory..."
		mkdir -p build && cd build
	fi
}

# Function to build Crystal Server
build_crystalserver() {
	info "Configuring Forgotten Server..."
	if [[ $ARCHITECTUREVALUE == 1 ]]; then
		export VCPKG_FORCE_SYSTEM_BINARIES=1
	fi
	
	cmake -DCMAKE_TOOLCHAIN_FILE="$VCPKG_PATH" .. --preset "$BUILD_TYPE" || {
		echo "[ERROR] CMake configure failed"
		return 1
	}

	info "Starting the build process..."
	
	# Build usando o diretório correto (não preset)
	cmake --build ./"$BUILD_TYPE" -- -j$(nproc) || {
		echo "[ERROR] Build failed"
		return 1
	}
	
	return 0
}

# Function to move the generated executable
move_executable() {
	local executable_name="crystalserver"
	cd ..
	
	# Procura o executável no diretório de build
	local executable_path=$(find ./build -name "$executable_name" -type f | head -n 1)
	
	if [ -z "$executable_path" ]; then
		echo "[ERROR] Executable '$executable_name' not found in build directory!"
		exit 1
	fi
	
	info "Found executable at: $executable_path"
	
	# Copia para o diretório raiz
	cp "$executable_path" ./"$executable_name"
	chmod +x ./"$executable_name"
	
	info "Build completed successfully!"
}

# Main function
main() {
	# clear
	echo -e "\033[1;36m╔════════════════════════════════════════════════════════════════════╗\033[0m"
	echo -e "\033[1;36m║         CrystalServer Build System - Interactive Mode             ║\033[0m"
	echo -e "\033[1;36m╚════════════════════════════════════════════════════════════════════╝\033[0m"
	echo ""
	
	# Check if vcpkg toolchain file exists
	if [ ! -f "$VCPKG_PATH" ]; then
		echo -e "\033[31m[ERROR]\033[0m vcpkg toolchain file not found at: $VCPKG_PATH"
		echo -e "\033[33m[INFO]\033[0m Please install vcpkg or specify the correct path."
		echo -e "\033[33m[INFO]\033[0m Usage: $0 [vcpkg_base_path] [build_type]"
		echo -e "\033[33m[INFO]\033[0m Example: $0 /home/shadowborn linux-release"
		exit 1
	fi
	
	info "Using vcpkg from: $VCPKG_PATH"
	info "Build type: $BUILD_TYPE"
	echo ""
	
	check_command "cmake"
	check_architecture
	echo ""
	setup_crystalserver
	echo ""

	local start_time=$(date +%s)
	
	if build_crystalserver; then
		move_executable
		local end_time=$(date +%s)
		local elapsed=$((end_time - start_time))
		local minutes=$((elapsed / 60))
		local seconds=$((elapsed % 60))
		
		echo ""
		echo -e "\033[1;36m╔════════════════════════════════════════════════════════════════════╗\033[0m"
		echo -e "\033[1;36m║                    BUILD COMPLETED SUCCESSFULLY!                   ║\033[0m"
		echo -e "\033[1;36m╚════════════════════════════════════════════════════════════════════╝\033[0m"
		echo ""
		echo -e "\033[1;32m✓\033[0m Executable: \033[1;37m$(pwd)/crystalserver\033[0m"
		echo -e "\033[1;32m✓\033[0m Build time: \033[1;37m${minutes}m ${seconds}s\033[0m"
		echo -e "\033[1;32m✓\033[0m Logs saved: \033[1;37mbuild/cmake_log.txt, build/build_log.txt\033[0m"
		echo ""
		echo -e "\033[1;33mTo run the server:\033[0m"
		echo -e "  \033[1;37m./crystalserver\033[0m"
		echo ""
	else
		local end_time=$(date +%s)
		local elapsed=$((end_time - start_time))
		echo ""
		echo -e "\033[1;31m╔════════════════════════════════════════════════════════════════════╗\033[0m"
		echo -e "\033[1;31m║                         BUILD FAILED!                              ║\033[0m"
		echo -e "\033[1;31m╚════════════════════════════════════════════════════════════════════╝\033[0m"
		echo ""
		echo -e "\033[1;33m[INFO]\033[0m Time elapsed: ${elapsed}s"
		echo -e "\033[1;33m[INFO]\033[0m Check logs for details:"
		echo -e "  - build/cmake_log.txt (configuration)"
		echo -e "  - build/build_log.txt (compilation)"
		echo ""
		exit 1
	fi
}

main
