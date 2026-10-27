#!/usr/bin/env python3
import os
import subprocess
import datetime

# Root directory of the repository (one level up from scripts)
REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
REPORTS_DIR = os.path.join(REPO_ROOT, 'verification/reports')

# Create reports directory if it doesn't exist
os.makedirs(REPORTS_DIR, exist_ok=True)

HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
<style>
body {{ font-family: Arial, sans-serif; margin: 20px; }}
h1 {{ color: #333; }}
.status-pass {{ color: green; font-weight: bold; }}
.status-fail {{ color: red; font-weight: bold; }}
pre {{ background-color: #f4f4f4; padding: 10px; border-radius: 5px; overflow-x: auto; }}
</style>
<title>Verilator Lint Report</title>
</head>
<body>
<h1>Verilator Lint Report</h1>
<p><strong>Date:</strong> {date}</p>
<p><strong>Status:</strong> <span class="{status_class}">{status_text}</span></p>
<h2>Lint Output</h2>
<pre>
{lint_output}
</pre>
</body>
</html>
"""

def run_lint():
    print("Running Verilator Lint...")
    lint_script = os.path.join(REPO_ROOT, 'scripts/verilator_lint.sh')
    
    # Run the existing lint script
    result = subprocess.run([lint_script], cwd=REPO_ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    
    # Check if there are any %Error lines in the output (since warnings are not fatal right now)
    has_errors = "%Error" in result.stdout
    
    status_text = "FAILED" if has_errors else "PASSED"
    status_class = "status-fail" if has_errors else "status-pass"
    
    html_content = HTML_TEMPLATE.format(
        date=datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        status_class=status_class,
        status_text=status_text,
        lint_output=result.stdout
    )
    
    report_path = os.path.join(REPORTS_DIR, 'lint_report.html')
    with open(report_path, 'w') as f:
        f.write(html_content)
        
    print(f"Lint complete. HTML report generated at {report_path}")
    if has_errors:
        print("Lint FAILED.")
        exit(1)
    else:
        print("Lint PASSED.")
        exit(0)

if __name__ == "__main__":
    run_lint()
