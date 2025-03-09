#!/bin/bash

# Function to generate statistics from the result CSV
analyze_results() {
    local csv_file=$1
    local output_dir=$2
    
    if [ ! -f "$csv_file" ]; then
        echo "Error: CSV file not found: $csv_file"
        return 1
    fi
    
    # Get test duration
    local first_timestamp=$(awk -F, 'NR==2 {print $1}' "$csv_file")
    local last_timestamp=$(awk -F, 'END {print $1}' "$csv_file")
    local test_duration_ms=$((last_timestamp - first_timestamp))
    local test_duration_s=$((test_duration_ms / 1000))
    
    # Count total requests
    local total_requests=$(awk -F, 'NR>1' "$csv_file" | wc -l)
    
    # Calculate TPS
    local tps=$(echo "scale=2; $total_requests / $test_duration_s" | bc)
    
    # Count by result type
    local allowed_count=$(awk -F, 'NR>1 && $4=="ALLOWED" {count++} END {print count+0}' "$csv_file")
    local blocked_count=$(awk -F, 'NR>1 && $4=="BLOCKED" {count++} END {print count+0}' "$csv_file")
    local error_count=$(awk -F, 'NR>1 && $4 ~ /^ERROR/ {count++} END {print count+0}' "$csv_file")
    
    # Payload distribution
    local clean_count=$(awk -F, 'NR>1 && $5 ~ /clean\.json/ {count++} END {print count+0}' "$csv_file")
    local dummy_count=$(awk -F, 'NR>1 && $5 ~ /dummy-secret\.json/ {count++} END {print count+0}' "$csv_file")
    local real_count=$(awk -F, 'NR>1 && $5 ~ /real-secret\.json/ {count++} END {print count+0}' "$csv_file")
    
    # Calculate percentages
    local allowed_pct=$(echo "scale=2; $allowed_count * 100 / $total_requests" | bc)
    local blocked_pct=$(echo "scale=2; $blocked_count * 100 / $total_requests" | bc)
    local error_pct=$(echo "scale=2; $error_count * 100 / $total_requests" | bc)
    
    local clean_pct=$(echo "scale=2; $clean_count * 100 / $total_requests" | bc)
    local dummy_pct=$(echo "scale=2; $dummy_count * 100 / $total_requests" | bc)
    local real_pct=$(echo "scale=2; $real_count * 100 / $total_requests" | bc)
    
    # Calculate response time statistics
    local min_time=$(awk -F, 'NR>1 {print $2}' "$csv_file" | sort -n | head -1)
    local max_time=$(awk -F, 'NR>1 {print $2}' "$csv_file" | sort -n | tail -1)
    local avg_time=$(awk -F, 'NR>1 {sum+=$2} END {print sum/NR-1}' "$csv_file")
    
    # Calculate percentiles
    local sorted_times="${output_dir}/sorted_times.txt"
    awk -F, 'NR>1 {print $2}' "$csv_file" | sort -n > "$sorted_times"
    
    local p50=$(awk -v count=$(wc -l < "$sorted_times") 'NR == int(count * 0.5) {print}' "$sorted_times")
    local p90=$(awk -v count=$(wc -l < "$sorted_times") 'NR == int(count * 0.9) {print}' "$sorted_times")
    local p95=$(awk -v count=$(wc -l < "$sorted_times") 'NR == int(count * 0.95) {print}' "$sorted_times")
    local p99=$(awk -v count=$(wc -l < "$sorted_times") 'NR == int(count * 0.99) {print}' "$sorted_times")
    
    # Create HTML report
    local html_report="${output_dir}/report.html"
    
    echo "<!DOCTYPE html>
<html>
<head>
    <title>GHAS Performance Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; line-height: 1.6; }
        h1, h2 { color: #333; border-bottom: 1px solid #eee; padding-bottom: 10px; }
        .metric { margin-bottom: 5px; }
        .label { font-weight: bold; display: inline-block; width: 200px; }
        .value { display: inline-block; }
        .container { display: flex; flex-wrap: wrap; }
        .section { flex: 1; min-width: 300px; margin: 10px; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th, td { text-align: left; padding: 8px; border-bottom: 1px solid #ddd; }
        th { background-color: #f2f2f2; }
        tr:hover { background-color: #f5f5f5; }
        .chart { height: 200px; margin: 20px 0; }
    </style>
</head>
<body>
    <h1>GHAS Performance Test Report</h1>
    <p>Test conducted on $(date)</p>
    
    <div class="container">
        <div class="section">
            <h2>Summary</h2>
            <div class="metric"><span class="label">Total Requests:</span> <span class="value">$total_requests</span></div>
            <div class="metric"><span class="label">Test Duration:</span> <span class="value">$test_duration_s seconds</span></div>
            <div class="metric"><span class="label">Transactions Per Second:</span> <span class="value">$tps TPS</span></div>
        </div>
        
        <div class="section">
            <h2>Response Time (ms)</h2>
            <div class="metric"><span class="label">Minimum:</span> <span class="value">$min_time ms</span></div>
            <div class="metric"><span class="label">Maximum:</span> <span class="value">$max_time ms</span></div>
            <div class="metric"><span class="label">Average:</span> <span class="value">$avg_time ms</span></div>
            <div class="metric"><span class="label">50th Percentile (P50):</span> <span class="value">$p50 ms</span></div>
            <div class="metric"><span class="label">90th Percentile (P90):</span> <span class="value">$p90 ms</span></div>
            <div class="metric"><span class="label">95th Percentile (P95):</span> <span class="value">$p95 ms</span></div>
            <div class="metric"><span class="label">99th Percentile (P99):</span> <span class="value">$p99 ms</span></div>
        </div>
    </div>
    
    <div class="container">
        <div class="section">
            <h2>Results</h2>
            <table>
                <tr>
                    <th>Result</th>
                    <th>Count</th>
                    <th>Percentage</th>
                </tr>
                <tr>
                    <td>Allowed</td>
                    <td>$allowed_count</td>
                    <td>$allowed_pct%</td>
                </tr>
                <tr>
                    <td>Blocked</td>
                    <td>$blocked_count</td>
                    <td>$blocked_pct%</td>
                </tr>
                <tr>
                    <td>Error</td>
                    <td>$error_count</td>
                    <td>$error_pct%</td>
                </tr>
            </table>
        </div>
        
        <div class="section">
            <h2>Payload Distribution</h2>
            <table>
                <tr>
                    <th>Payload Type</th>
                    <th>Count</th>
                    <th>Percentage</th>
                </tr>
                <tr>
                    <td>Clean</td>
                    <td>$clean_count</td>
                    <td>$clean_pct%</td>
                </tr>
                <tr>
                    <td>Dummy Secret</td>
                    <td>$dummy_count</td>
                    <td>$dummy_pct%</td>
                </tr>
                <tr>
                    <td>Real Secret</td>
                    <td>$real_count</td>
                    <td>$real_pct%</td>
                </tr>
            </table>
        </div>
    </div>
    
    <div class="section">
        <h2>Test Configuration</h2>
        <div class="metric"><span class="label">Target URL:</span> <span class="value">$(grep 'Target URL' "${output_dir}/test_config.txt" | cut -d ' ' -f 3-)</span></div>
        <div class="metric"><span class="label">Concurrency:</span> <span class="value">$(grep 'Concurrency' "${output_dir}/test_config.txt" | cut -d ' ' -f 2)</span></div>
        <div class="metric"><span class="label">Duration:</span> <span class="value">$(grep 'Duration' "${output_dir}/test_config.txt" | cut -d ' ' -f 2) seconds</span></div>
        <div class="metric"><span class="label">Ramp-up:</span> <span class="value">$(grep 'Ramp-up' "${output_dir}/test_config.txt" | cut -d ' ' -f 2) seconds</span></div>
        <div class="metric"><span class="label">Request Timeout:</span> <span class="value">$(grep 'Timeout' "${output_dir}/test_config.txt" | cut -d ' ' -f 2) seconds</span></div>
        <div class="metric"><span class="label">Clean Payload %:</span> <span class="value">$(grep 'Clean' "${output_dir}/test_config.txt" | cut -d ' ' -f 2)</span></div>
        <div class="metric"><span class="label">Dummy Secret %:</span> <span class="value">$(grep 'Dummy' "${output_dir}/test_config.txt" | cut -d ' ' -f 2)</span></div>
        <div class="metric"><span class="label">Real Secret %:</span> <span class="value">$(grep 'Real' "${output_dir}/test_config.txt" | cut -d ' ' -f 2)</span></div>
    </div>
</body>
</html>" > "$html_report"
    
    # Create a plain text summary
    local text_summary="${output_dir}/summary.txt"
    
    echo "GHAS Performance Test Summary" > "$text_summary"
    echo "============================" >> "$text_summary"
    echo "Test conducted on $(date)" >> "$text_summary"
    echo "" >> "$text_summary"
    echo "Summary:" >> "$text_summary"
    echo "  Total Requests: $total_requests" >> "$text_summary"
    echo "  Test Duration: $test_duration_s seconds" >> "$text_summary"
    echo "  Transactions Per Second: $tps TPS" >> "$text_summary"
    echo "" >> "$text_summary"
    echo "Response Time (ms):" >> "$text_summary"
    echo "  Minimum: $min_time ms" >> "$text_summary"
    echo "  Maximum: $max_time ms" >> "$text_summary"
    echo "  Average: $avg_time ms" >> "$text_summary"
    echo "  50th Percentile (P50): $p50 ms" >> "$text_summary"
    echo "  90th Percentile (P90): $p90 ms" >> "$text_summary"
    echo "  95th Percentile (P95): $p95 ms" >> "$text_summary"
    echo "  99th Percentile (P99): $p99 ms" >> "$text_summary"
    echo "" >> "$text_summary"
    echo "Results:" >> "$text_summary"
    echo "  Allowed: $allowed_count ($allowed_pct%)" >> "$text_summary"
    echo "  Blocked: $blocked_count ($blocked_pct%)" >> "$text_summary"
    echo "  Error: $error_count ($error_pct%)" >> "$text_summary"
    echo "" >> "$text_summary"
    echo "Payload Distribution:" >> "$text_summary"
    echo "  Clean: $clean_count ($clean_pct%)" >> "$text_summary"
    echo "  Dummy Secret: $dummy_count ($dummy_pct%)" >> "$text_summary"
    echo "  Real Secret: $real_count ($real_pct%)" >> "$text_summary"
    
    # Return location of report files
    echo "$text_summary"
    echo "$html_report"
}

# Run the analysis with the provided result file
analyze_results "$1" "$2"
