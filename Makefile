.PHONY: build run clean test check

# Default target
all: build

# Build the executable
build:
	swift build -c release

# Build and run
run:
	swift run

# Run in debug mode
debug:
	swift build
	./.build/debug/ClaudeAutoConfig

# Test with TextEdit
test: build
	@echo "🧪 Testing with TextEdit.app"
	@echo "📌 Launch and quit TextEdit to test the monitor"
	./.build/release/ClaudeAutoConfig

# Check setup
check:
	@chmod +x check_setup.sh
	@./check_setup.sh

# Test paths
test-paths:
	swift run test_paths

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build

# Install to /usr/local/bin (requires sudo)
install: build
	@echo "📦 Installing to /usr/local/bin/"
	sudo cp ./.build/release/ClaudeAutoConfig /usr/local/bin/

# Create LaunchDaemon plist
plist:
	@echo "📝 Creating LaunchDaemon plist..."
	@echo "TODO: Implement plist generation"
