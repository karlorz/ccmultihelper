#!/usr/bin/env python3
"""
Webhook server for coordinating Claude Code worktree workflows.
This server listens for webhook events and triggers automated workflows.
"""

import os
import sys
import json
import subprocess
import http.server
import socketserver
import threading
import time
import signal
from urllib.parse import urlparse, parse_qs
from pathlib import Path

class WorkflowWebhookHandler(http.server.BaseHTTPRequestHandler):
    """Handle webhook requests for workflow automation."""

    def __init__(self, *args, **kwargs):
        self.workflow_dir = Path(__file__).parent
        self.log_file = "/tmp/claude-webhook.log"
        super().__init__(*args, **kwargs)

    def log_message(self, message):
        """Log messages to both console and log file."""
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        log_entry = f"[{timestamp}] {message}"
        print(log_entry)

        try:
            with open(self.log_file, 'a') as f:
                f.write(log_entry + '\n')
        except Exception as e:
            print(f"Failed to write to log file: {e}")

    def do_POST(self):
        """Handle POST requests."""
        try:
            # Parse the URL path
            parsed_path = urlparse(self.path)
            path = parsed_path.path

            # Get content length
            content_length = int(self.headers.get('Content-Length', 0))

            # Read the POST data
            post_data = self.rfile.read(content_length)

            # Try to parse as JSON
            try:
                data = json.loads(post_data.decode('utf-8'))
            except json.JSONDecodeError:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b'Invalid JSON data')
                return

            # Handle different webhook endpoints
            if path == '/webhook/claude-complete':
                self.handle_claude_complete(data)
            elif path == '/webhook/tests-complete':
                self.handle_tests_complete(data)
            elif path == '/webhook/bugfix-complete':
                self.handle_bugfix_complete(data)
            elif path == '/webhook/workflow':
                self.handle_generic_workflow(data)
            else:
                self.send_response(404)
                self.end_headers()
                self.wfile.write(b'Endpoint not found')

        except Exception as e:
            self.log_message(f"Error handling POST request: {e}")
            self.send_response(500)
            self.end_headers()
            self.wfile.write(f'Internal server error: {str(e)}'.encode())

    def do_GET(self):
        """Handle GET requests for health checks."""
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "healthy", "timestamp": time.time()}).encode())
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'Not found')

    def handle_claude_complete(self, data):
        """Handle Claude Code completion webhook."""
        self.log_message("Claude Code completion webhook received")

        project_name = data.get('project_name', 'unknown')
        worktree_type = data.get('worktree_type', 'feature')

        self.log_message(f"Project: {project_name}, Worktree: {worktree_type}")

        # Trigger test workflow
        if self.trigger_workflow('test', project_name):
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "success", "message": "Test workflow triggered"}).encode())
        else:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(b'Failed to trigger test workflow')

    def handle_tests_complete(self, data):
        """Handle tests completion webhook."""
        self.log_message("Tests completion webhook received")

        project_name = data.get('project_name', 'unknown')
        test_results = data.get('test_results', {})

        self.log_message(f"Project: {project_name}, Test results: {test_results}")

        # Trigger documentation workflow
        if self.trigger_workflow('docs', project_name):
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "success", "message": "Documentation workflow triggered"}).encode())
        else:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(b'Failed to trigger documentation workflow')

    def handle_bugfix_complete(self, data):
        """Handle bugfix completion webhook."""
        self.log_message("Bugfix completion webhook received")

        project_name = data.get('project_name', 'unknown')
        bugfix_id = data.get('bugfix_id', 'unknown')

        self.log_message(f"Project: {project_name}, Bugfix ID: {bugfix_id}")

        # Trigger validation workflow
        if self.trigger_workflow('validation', project_name):
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "success", "message": "Validation workflow triggered"}).encode())
        else:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(b'Failed to trigger validation workflow')

    def handle_generic_workflow(self, data):
        """Handle generic workflow webhook."""
        self.log_message("Generic workflow webhook received")

        workflow_type = data.get('workflow_type', 'unknown')
        project_name = data.get('project_name', 'unknown')

        self.log_message(f"Workflow type: {workflow_type}, Project: {project_name}")

        # Trigger specified workflow
        if self.trigger_workflow(workflow_type, project_name):
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "success", "message": f"{workflow_type} workflow triggered"}).encode())
        else:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(b'Failed to trigger workflow')

    def trigger_workflow(self, workflow_type, project_name):
        """Trigger a specific workflow."""
        try:
            self.log_message(f"Triggering {workflow_type} workflow for {project_name}")

            # Path to workflow scripts
            workflow_script = self.workflow_dir / f"trigger-{workflow_type}-workflow.sh"

            if workflow_script.exists():
                # Run the workflow script
                result = subprocess.run(
                    [str(workflow_script), project_name],
                    capture_output=True,
                    text=True,
                    timeout=300  # 5 minute timeout
                )

                if result.returncode == 0:
                    self.log_message(f"Successfully triggered {workflow_type} workflow")
                    return True
                else:
                    self.log_message(f"Workflow script failed: {result.stderr}")
                    return False
            else:
                # Fallback: create signal file
                worktree_base = f"../{project_name}-worktrees"
                signal_files = {
                    'test': f"{worktree_base}/feature/.claude-complete",
                    'docs': f"{worktree_base}/test/.tests-complete",
                    'validation': f"{worktree_base}/bugfix/.bugfix-complete"
                }

                if workflow_type in signal_files:
                    signal_file = signal_files[workflow_type]
                    Path(signal_file).touch()
                    self.log_message(f"Created signal file: {signal_file}")
                    return True
                else:
                    self.log_message(f"Unknown workflow type: {workflow_type}")
                    return False

        except subprocess.TimeoutExpired:
            self.log_message(f"Workflow {workflow_type} timed out")
            return False
        except Exception as e:
            self.log_message(f"Error triggering workflow {workflow_type}: {e}")
            return False

def run_webhook_server(port=8080):
    """Run the webhook server."""
    class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
        """Handle requests in separate threads."""
        daemon_threads = True

    server = ThreadedHTTPServer(('localhost', port), WorkflowWebhookHandler)

    print(f"🚀 Claude Code Webhook Server started on port {port}")
    print(f"📝 Health check: http://localhost:{port}/health")
    print(f"🔗 Webhook endpoints:")
    print(f"   POST http://localhost:{port}/webhook/claude-complete")
    print(f"   POST http://localhost:{port}/webhook/tests-complete")
    print(f"   POST http://localhost:{port}/webhook/bugfix-complete")
    print(f"   POST http://localhost:{port}/webhook/workflow")
    print(f"📋 Logs: /tmp/claude-webhook.log")
    print(f"Press Ctrl+C to stop the server")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Shutting down webhook server...")
        server.shutdown()
        server.server_close()
        print("✅ Server stopped")

def create_workflow_scripts():
    """Create workflow trigger scripts."""
    scripts = {
        'trigger-test-workflow.sh': '''#!/bin/bash
# Trigger test workflow
PROJECT_NAME="${1:-test-project}"
WORKTREE_BASE="../${PROJECT_NAME}-worktrees"

if [[ -d "$WORKTREE_BASE/test" ]]; then
    cd "$WORKTREE_BASE/test"
    git pull origin feature/"$PROJECT_NAME" 2>/dev/null || true

    # Run tests
    if [[ -f "package.json" ]]; then
        npm test 2>/dev/null || true
    elif [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]; then
        if command -v pytest &> /dev/null; then
            pytest 2>/dev/null || true
        fi
    fi

    # Create test completion signal
    touch "$WORKTREE_BASE/test/.tests-complete"
    echo "Test workflow completed for $PROJECT_NAME"
else
    echo "Test worktree not found for $PROJECT_NAME"
    exit 1
fi
''',
        'trigger-docs-workflow.sh': '''#!/bin/bash
# Trigger documentation workflow
PROJECT_NAME="${1:-test-project}"
WORKTREE_BASE="../${PROJECT_NAME}-worktrees"

if [[ -d "$WORKTREE_BASE/docs" ]]; then
    cd "$WORKTREE_BASE/docs"
    git pull origin feature/"$PROJECT_NAME" 2>/dev/null || true

    # Create documentation needed signal
    echo "Documentation update needed for $PROJECT_NAME" > .docs-needed
    echo "Documentation workflow triggered for $PROJECT_NAME"
else
    echo "Documentation worktree not found for $PROJECT_NAME"
    exit 1
fi
''',
        'trigger-validation-workflow.sh': '''#!/bin/bash
# Trigger validation workflow
PROJECT_NAME="${1:-test-project}"
WORKTREE_BASE="../${PROJECT_NAME}-worktrees"

if [[ -d "$WORKTREE_BASE/test" ]]; then
    cd "$WORKTREE_BASE/test"
    git pull origin bugfix/"$PROJECT_NAME" 2>/dev/null || true

    # Run validation tests
    if [[ -f "package.json" ]]; then
        npm test 2>/dev/null || true
    elif [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]; then
        if command -v pytest &> /dev/null; then
            pytest 2>/dev/null || true
        fi
    fi

    # Create validation completion signal
    touch "$WORKTREE_BASE/test/.bugfix-validated"
    echo "Validation workflow completed for $PROJECT_NAME"
else
    echo "Test worktree not found for $PROJECT_NAME"
    exit 1
fi
'''
    }

    for filename, content in scripts.items():
        script_path = Path(__file__).parent / filename
        with open(script_path, 'w') as f:
            f.write(content)
        os.chmod(script_path, 0o755)
        print(f"✅ Created {filename}")

if __name__ == "__main__":
    # Create workflow scripts
    create_workflow_scripts()

    # Get port from command line or use default
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080

    # Run the server
    run_webhook_server(port)