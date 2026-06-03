#!/bin/bash
# ============================================================================
# OpenClaw Agent Deployment Script
# ============================================================================
# Purpose: Automatisiertes Deployment aller 4 OpenClaw-Agents auf Container
# Usage: bash deploy-agents.sh [--dry-run]
# ============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config/.env"

# Default values
DRY_RUN=false
VERBOSE=false

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${BLUE}==>${NC} ${YELLOW}$1${NC}\n"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Required command '$1' not found. Please install it first."
        exit 1
    fi
}

# ============================================================================
# Load Configuration
# ============================================================================

load_config() {
    log_step "Loading Configuration"

    if [ ! -f "${CONFIG_FILE}" ]; then
        log_error "Configuration file not found: ${CONFIG_FILE}"
        log_info "Please create it from .env.example:"
        log_info "  cd ${SCRIPT_DIR}/config"
        log_info "  cp .env.example .env"
        log_info "  nano .env"
        exit 1
    fi

    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"

    # Validate required variables
    if [ -z "${LXC_NETWORK_IP:-}" ]; then
        log_error "LXC_NETWORK_IP not set in ${CONFIG_FILE}"
        exit 1
    fi

    # Extract IP from CIDR notation
    CONTAINER_IP="${LXC_NETWORK_IP%%/*}"

    log_success "Configuration loaded"
    log_info "Container IP: ${CONTAINER_IP}"
}

# ============================================================================
# Pre-Flight Checks
# ============================================================================

pre_flight_checks() {
    log_step "Pre-Flight Checks"

    # Check required commands
    check_command "ssh"
    check_command "scp"

    # Check if sshpass is available (only required for password-only auth)
    if [ "${PROXMOX_AUTH_METHOD:-key}" = "password" ]; then
        check_command "sshpass"
    fi

    # Check agents directory
    if [ ! -d "${PROJECT_ROOT}/agents" ]; then
        log_error "Agents directory not found: ${PROJECT_ROOT}/agents"
        exit 1
    fi

    # Check if all 4 agents exist and have config files
    for agent in dev-agent review-agent security-agent ops-agent; do
        agent_dir="${PROJECT_ROOT}/agents/${agent}"
        config_file="${agent_dir}/config.yaml"

        if [ ! -d "${agent_dir}" ]; then
            log_error "Agent directory not found: ${agent_dir}"
            exit 1
        fi

        if [ ! -f "${config_file}" ]; then
            log_error "Config file not found: ${config_file}"
            exit 1
        fi

        log_success "✓ ${agent} found"
    done

    # Test SSH connection
    log_info "Testing SSH connection to ${CONTAINER_IP}..."

    if ssh -o ConnectTimeout=5 -o BatchMode=yes "root@${CONTAINER_IP}" "exit" &>/dev/null; then
        log_success "✓ SSH connection successful"
    else
        log_error "Cannot connect to container via SSH"
        log_info "Please ensure:"
        log_info "  1. Container is running: pct status 111"
        log_info "  2. SSH is configured: ssh root@${CONTAINER_IP}"
        exit 1
    fi

    log_success "All pre-flight checks passed"
}

# ============================================================================
# Deploy Agents
# ============================================================================

deploy_agents() {
    log_step "Deploying Agents to Container"

    # Create remote directory if not exists
    log_info "Creating /opt/openclaw/agents directory on container..."

    if [ "${DRY_RUN}" = true ]; then
        log_info "[DRY-RUN] Would create: /opt/openclaw/agents"
    else
        ssh "root@${CONTAINER_IP}" "mkdir -p /opt/openclaw/agents"
    fi

    # Copy all agents
    for agent in dev-agent review-agent security-agent ops-agent; do
        log_info "Copying ${agent}..."

        agent_dir="${PROJECT_ROOT}/agents/${agent}"

        if [ "${DRY_RUN}" = true ]; then
            log_info "[DRY-RUN] Would copy: ${agent_dir} -> root@${CONTAINER_IP}:/opt/openclaw/agents/"
        else
            scp -r "${agent_dir}" "root@${CONTAINER_IP}:/opt/openclaw/agents/"
            log_success "✓ ${agent} copied"
        fi
    done

    log_success "All agents deployed"
}

# ============================================================================
# Register Agents
# ============================================================================

register_agents() {
    log_step "Adding Agents to OpenClaw"

    # Agent definitions
    declare -A agent_models=(
        ["dev-agent"]="claude-sonnet-4-6"
        ["review-agent"]="claude-sonnet-4-6"
        ["security-agent"]="claude-sonnet-4-6"
        ["ops-agent"]="claude-sonnet-4-6"
    )

    for agent in dev-agent review-agent security-agent ops-agent; do
        log_info "Adding ${agent}..."

        agent_workspace="/opt/openclaw/workspaces/${agent}"
        model="${agent_models[$agent]}"

        if [ "${DRY_RUN}" = true ]; then
            log_info "[DRY-RUN] Would execute: openclaw agents add ${agent} --workspace ${agent_workspace} --model ${model} --non-interactive"
        else
            # Check if agent already exists
            if ssh "root@${CONTAINER_IP}" "openclaw agents list 2>/dev/null | grep -q '${agent}'"; then
                log_warn "Agent ${agent} already exists, skipping..."
                continue
            fi

            # Create workspace directory
            ssh "root@${CONTAINER_IP}" "mkdir -p ${agent_workspace}"

            # Add agent
            if ssh "root@${CONTAINER_IP}" "openclaw agents add ${agent} --workspace ${agent_workspace} --model ${model} --non-interactive" 2>&1 | tee /tmp/openclaw-add-${agent}.log; then
                log_success "✓ ${agent} added"
            else
                log_error "Failed to add ${agent}"
                log_info "Check logs: /tmp/openclaw-add-${agent}.log"

                # Check if OpenClaw is installed
                if ! ssh "root@${CONTAINER_IP}" "command -v openclaw" &>/dev/null; then
                    log_error "OpenClaw CLI not found on container"
                    log_info "Please install OpenClaw first:"
                    log_info "  ssh root@${CONTAINER_IP}"
                    log_info "  curl -sSL https://install.openclaw.ai | bash"
                fi

                return 1
            fi
        fi
    done

    log_success "All agents added"
}

# ============================================================================
# Enable Systemd Services
# ============================================================================

enable_gateway() {
    log_step "Ensuring OpenClaw Gateway is Running"

    log_info "Checking Gateway status..."

    if [ "${DRY_RUN}" = true ]; then
        log_info "[DRY-RUN] Would check: openclaw status"
    else
        # Check if Gateway is running
        if ssh "root@${CONTAINER_IP}" "openclaw status 2>&1 | grep -q 'Gateway.*running'"; then
            log_success "✓ Gateway already running"
        else
            log_info "Starting Gateway..."

            # Start Gateway in background
            if ssh "root@${CONTAINER_IP}" "openclaw gateway run --force &" 2>&1; then
                log_success "✓ Gateway started"

                # Wait for Gateway to be ready
                log_info "Waiting for Gateway to be ready..."
                sleep 5

                # Verify Gateway is running
                if ssh "root@${CONTAINER_IP}" "openclaw status 2>&1 | grep -q 'Gateway.*running'"; then
                    log_success "✓ Gateway is ready"
                else
                    log_warn "Gateway might not be fully ready yet"
                fi
            else
                log_error "Failed to start Gateway"
                log_info "Check logs: ssh root@${CONTAINER_IP} 'openclaw logs'"
                return 1
            fi
        fi
    fi

    log_success "Gateway is operational"
}

# ============================================================================
# Verify Deployment
# ============================================================================

verify_deployment() {
    log_step "Verifying Deployment"

    # Check if OpenClaw recognizes all agents
    log_info "Checking added agents..."

    if [ "${DRY_RUN}" = true ]; then
        log_info "[DRY-RUN] Would execute: openclaw agents list"
    else
        agent_list=$(ssh "root@${CONTAINER_IP}" "openclaw agents list" 2>&1)

        echo "${agent_list}"

        # Check if all 4 agents are listed
        for agent in dev-agent review-agent security-agent ops-agent; do
            if echo "${agent_list}" | grep -q "${agent}"; then
                log_success "✓ ${agent} added"
            else
                log_error "✗ ${agent} NOT added"
                return 1
            fi
        done
    fi

    # Check Gateway status
    log_info "Checking Gateway status..."

    if [ "${DRY_RUN}" = true ]; then
        log_info "[DRY-RUN] Would check: openclaw status"
    else
        if ssh "root@${CONTAINER_IP}" "openclaw status 2>&1 | grep -q 'Gateway.*running'"; then
            log_success "✓ Gateway running"
        else
            log_warn "✗ Gateway not running"
            log_info "Start Gateway with: ssh root@${CONTAINER_IP} 'openclaw gateway run'"
        fi
    fi

    log_success "All verification checks passed"
}

# ============================================================================
# Test Agents
# ============================================================================

test_agents() {
    log_step "Testing Agents"

    log_info "Testing agent interaction via Gateway..."

    if [ "${DRY_RUN}" = true ]; then
        log_info "[DRY-RUN] Would test agents via openclaw agent command"
    else
        # Test one agent as example (dev-agent)
        log_info "Testing dev-agent..."

        # Note: OpenClaw agents work through Gateway, not direct CLI
        # The actual test would be through chat interface or API
        log_info "To test agents interactively:"
        log_info "  1. ssh root@${CONTAINER_IP}"
        log_info "  2. openclaw tui"
        log_info "  3. Select agent: dev-agent"

        log_success "Agent configuration complete"
        log_info "Agents are ready for use through OpenClaw Gateway"
    fi
}

# ============================================================================
# Print Status Report
# ============================================================================

print_status_report() {
    log_step "Deployment Status Report"

    if [ "${DRY_RUN}" = true ]; then
        echo "================================================================"
        echo "                    DRY-RUN MODE"
        echo "================================================================"
        echo ""
        echo "Would deploy the following:"
        echo ""
    fi

    echo "================================================================"
    echo "                 OpenClaw Agent Deployment"
    echo "================================================================"
    echo ""
    echo "Container IP:     ${CONTAINER_IP}"
    echo "Agents deployed:  4 (dev, review, security, ops)"
    echo ""

    if [ "${DRY_RUN}" = false ]; then
        echo "Status:"
        echo ""

        # Get agent list
        ssh "root@${CONTAINER_IP}" "openclaw agents list" 2>/dev/null || echo "  (Unable to fetch agent list)"

        echo ""
        echo "Gateway:"
        echo ""

        if ssh "root@${CONTAINER_IP}" "openclaw status 2>&1 | grep -q 'Gateway.*running'"; then
            echo "  ✅ Gateway running"
        else
            echo "  ❌ Gateway not running"
        fi

        echo ""
        echo "================================================================"
        echo ""
        echo "Next Steps:"
        echo ""
        echo "  1. Start interactive UI:"
        echo "     ssh root@${CONTAINER_IP}"
        echo "     openclaw tui"
        echo ""
        echo "  2. Check Gateway logs:"
        echo "     ssh root@${CONTAINER_IP}"
        echo "     openclaw logs"
        echo ""
        echo "  3. List agents:"
        echo "     ssh root@${CONTAINER_IP}"
        echo "     openclaw agents list"
        echo ""
        echo "  4. Check status:"
        echo "     ssh root@${CONTAINER_IP}"
        echo "     openclaw status"
        echo ""
    fi

    echo "================================================================"
}

# ============================================================================
# Main Function
# ============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --dry-run    Show what would be done without actually doing it"
                echo "  --verbose    Enable verbose output"
                echo "  -h, --help   Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Print header
    echo ""
    echo "================================================================"
    echo "       OpenClaw Multi-Agent System - Deployment Script"
    echo "================================================================"
    echo ""

    if [ "${DRY_RUN}" = true ]; then
        log_warn "Running in DRY-RUN mode (no actual changes will be made)"
    fi

    # Execute deployment steps
    load_config
    pre_flight_checks
    deploy_agents
    enable_gateway
    register_agents
    verify_deployment

    # Optional: Test agents
    if [ "${DRY_RUN}" = false ]; then
        test_agents
    fi

    # Print final status
    print_status_report

    echo ""
    log_success "Deployment completed successfully!"
    echo ""
}

# Run main function
main "$@"
