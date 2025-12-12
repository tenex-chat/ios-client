#!/bin/bash
# Install git hooks for TENEX iOS
# Run this script after cloning the repository

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

echo "Installing git hooks for TENEX iOS..."

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Install pre-commit hook
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
# TENEX iOS Pre-Commit Hook
# Runs linting and formatting checks before allowing commit

set -e

echo "Running pre-commit checks..."

# Check if SwiftLint is installed
if ! command -v swiftlint &> /dev/null; then
    echo "Error: SwiftLint is not installed."
    echo "Install with: brew install swiftlint"
    exit 1
fi

# Check if SwiftFormat is installed
if ! command -v swiftformat &> /dev/null; then
    echo "Error: SwiftFormat is not installed."
    echo "Install with: brew install swiftformat"
    exit 1
fi

# Get staged Swift files
STAGED_SWIFT_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.swift$' || true)

if [ -z "$STAGED_SWIFT_FILES" ]; then
    echo "No Swift files staged. Skipping checks."
    exit 0
fi

echo "Checking staged files:"
echo "$STAGED_SWIFT_FILES"
echo ""

# Run SwiftFormat check (don't auto-fix, just check)
echo "Checking formatting..."
if ! echo "$STAGED_SWIFT_FILES" | xargs swiftformat --lint --config .swiftformat 2>/dev/null; then
    echo ""
    echo "Error: Code formatting issues found."
    echo "Run 'swiftformat .' to fix formatting issues."
    exit 1
fi

# Run SwiftLint
echo "Running SwiftLint..."
if ! echo "$STAGED_SWIFT_FILES" | xargs swiftlint lint --strict --quiet; then
    echo ""
    echo "Error: SwiftLint violations found."
    echo "Fix the issues above before committing."
    exit 1
fi

echo "Pre-commit checks passed!"
EOF

chmod +x "$HOOKS_DIR/pre-commit"
echo "Installed pre-commit hook"

# Install pre-push hook
cat > "$HOOKS_DIR/pre-push" << 'EOF'
#!/bin/bash
# TENEX iOS Pre-Push Hook
# Runs tests before allowing push

set -e

echo "Running pre-push checks..."

# Check if Tuist is installed
if ! command -v tuist &> /dev/null; then
    echo "Warning: Tuist is not installed. Skipping test run."
    echo "Install with: curl -Ls https://install.tuist.io | bash"
    exit 0
fi

# Run tests
echo "Running tests..."
if ! tuist test 2>/dev/null; then
    echo ""
    echo "Error: Tests failed."
    echo "Fix failing tests before pushing."
    exit 1
fi

echo "Pre-push checks passed!"
EOF

chmod +x "$HOOKS_DIR/pre-push"
echo "Installed pre-push hook"

# Install commit-msg hook for conventional commits
cat > "$HOOKS_DIR/commit-msg" << 'EOF'
#!/bin/bash
# TENEX iOS Commit Message Hook
# Enforces conventional commit format

commit_msg_file=$1
commit_msg=$(cat "$commit_msg_file")

# Conventional commit pattern
# type(scope): description
# Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
pattern="^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9-]+\))?: .{1,72}$"

# Allow merge commits
if [[ "$commit_msg" =~ ^Merge ]]; then
    exit 0
fi

# Check first line
first_line=$(echo "$commit_msg" | head -n1)

if ! [[ "$first_line" =~ $pattern ]]; then
    echo "Error: Invalid commit message format."
    echo ""
    echo "Expected format: type(scope): description"
    echo ""
    echo "Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert"
    echo ""
    echo "Examples:"
    echo "  feat(auth): add biometric authentication"
    echo "  fix(chat): resolve message ordering issue"
    echo "  docs: update README with setup instructions"
    echo ""
    echo "Your message: $first_line"
    exit 1
fi

echo "Commit message format OK"
EOF

chmod +x "$HOOKS_DIR/commit-msg"
echo "Installed commit-msg hook"

echo ""
echo "Git hooks installed successfully!"
echo ""
echo "Hooks installed:"
echo "  - pre-commit: Runs SwiftLint and SwiftFormat checks"
echo "  - pre-push: Runs tests before push"
echo "  - commit-msg: Enforces conventional commit format"
echo ""
echo "Required tools:"
echo "  - SwiftLint: brew install swiftlint"
echo "  - SwiftFormat: brew install swiftformat"
echo "  - Tuist: curl -Ls https://install.tuist.io | bash"
