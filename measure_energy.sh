#!/usr/bin/env bash

# This script measures the energy consumption of the React frontend (npm start).
# Usage:
#   ./measure-energy-frontend.sh /path/to/EnergiBridge [seconds]

# Check argument
if [ -z "$1" ]; then
  echo "Error: You must specify the path to the EnergiBridge directory."
  echo "Usage: ./measure-energy-frontend.sh /path/to/EnergiBridge [seconds]"
  exit 1
fi

ENERGIBRIDGE_DIR="$1"
ENERGIBRIDGE_BIN="$ENERGIBRIDGE_DIR/target/release/energibridge"

# Default measurement time is 15 seconds
MEASURE_TIME="${2:-15}"

# Check energibridge binary
if [ ! -f "$ENERGIBRIDGE_BIN" ]; then
  echo "Error: energibridge binary not found in:"
  echo "  $ENERGIBRIDGE_BIN"
  echo "Compile EnergiBridge with: cargo build -r"
  exit 1
fi

# Automatically set permissions for MSR registers (reset on reboot)
sudo chgrp -R wheel /dev/cpu/*/msr 2>/dev/null
sudo chmod g+r /dev/cpu/*/msr 2>/dev/null

# Apply raw I/O capability to energibridge binary
sudo setcap cap_sys_rawio=ep "$ENERGIBRIDGE_BIN"

# Check if package.json exists
if [ ! -f "package.json" ]; then
  echo "Error: package.json not found in the current directory."
  exit 1
fi

# Check if npm install was done
if [ ! -d "node_modules" ]; then
  echo "Error: node_modules not found. Run npm install first."
  exit 1
fi

# Create output directory
OUTPUT_DIR="energy-frontend-results"
mkdir -p "$OUTPUT_DIR"

echo "---------------------------------------------"
echo "Using energibridge: $ENERGIBRIDGE_BIN"
echo "Using npm start"
echo "Frontend directory: $(pwd)"
echo "Execution time:     $MEASURE_TIME seconds"
echo "Output directory:   $OUTPUT_DIR"
echo "---------------------------------------------"
echo ""

# Launch npm start in the background and capture the PID
npm start >/dev/null 2>&1 &
NPM_PID=$!

# Wait 0.5 seconds so React dev server forks its child processes
sleep 0.5

# Generate timestamped CSV filename
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
OUTPUT_FILE="$OUTPUT_DIR/energy-frontend-$TIMESTAMP.csv"

# Measure energy consumption and save output to CSV
"$ENERGIBRIDGE_BIN" --summary -o "$OUTPUT_FILE" -m "$MEASURE_TIME" bash -c 'sleep infinity'

# Kill npm and all its child processes
pkill -TERM -P "$NPM_PID" 2>/dev/null
kill -TERM "$NPM_PID" 2>/dev/null
pkill node 2>/dev/null

echo ""
echo "---------------------------------------------"
echo " Energy report saved: $OUTPUT_FILE"
echo "---------------------------------------------"

