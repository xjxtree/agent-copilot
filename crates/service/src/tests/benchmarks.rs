use super::*;

const BENCH_ITERATIONS: usize = 12;
const BENCH_WARMUPS: usize = 2;

fn benchmark_host(name: &str) -> (PathBuf, ServiceHost) {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-{name}-bench-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());
    (app_data_dir, host)
}

fn percentile_ms(samples: &[f64], percentile: f64) -> f64 {
    let mut sorted = samples.to_vec();
    sorted.sort_by(|left, right| left.total_cmp(right));
    let index = ((sorted.len().saturating_sub(1)) as f64 * percentile).ceil() as usize;
    sorted[index.min(sorted.len().saturating_sub(1))]
}

fn measure_service_call(mut run: impl FnMut() -> Value) -> (f64, f64, f64, Value) {
    for _ in 0..BENCH_WARMUPS {
        let _ = run();
    }

    let mut samples = Vec::with_capacity(BENCH_ITERATIONS);
    let mut last_result = Value::Null;
    for _ in 0..BENCH_ITERATIONS {
        let started = std::time::Instant::now();
        last_result = run();
        samples.push(started.elapsed().as_secs_f64() * 1_000.0);
    }

    (
        percentile_ms(&samples, 0.50),
        percentile_ms(&samples, 0.95),
        samples
            .iter()
            .copied()
            .fold(0.0_f64, |current, sample| current.max(sample)),
        last_result,
    )
}

#[test]
#[ignore = "benchmark"]
fn benchmark_task_readiness_fixture() {
    let (app_data_dir, host) = benchmark_host("task-readiness");
    seed_catalog_with_many_task_skills(&host, 240);

    let (p50_ms, p95_ms, max_ms, result) = measure_service_call(|| {
        let response = host.handle(ServiceRequest {
            id: Some("benchmark-task-readiness".to_string()),
            method: "task.checkReadiness".to_string(),
            params: json!({
                "task": "Validate release readiness privacy evidence",
                "agent": "codex",
                "limit": 8
            }),
        });
        assert!(response.ok, "{:?}", response.error);
        response.result.expect("task readiness benchmark result")
    });

    let rows = result
        .get("candidate_skills")
        .and_then(Value::as_array)
        .map(Vec::len)
        .unwrap_or_default();
    let scanned = result
        .pointer("/aggregation/scanned_count")
        .and_then(Value::as_u64)
        .unwrap_or_default();
    let total = result
        .pointer("/aggregation/total_count")
        .and_then(Value::as_u64)
        .unwrap_or_default();

    println!(
        "skills-copilot-bench benchmark=task_readiness dataset=240_skills iterations={BENCH_ITERATIONS} warmups={BENCH_WARMUPS} p50_ms={p50_ms:.2} p95_ms={p95_ms:.2} max_ms={max_ms:.2} rows={rows} scanned={scanned} total={total}"
    );

    let _ = fs::remove_dir_all(app_data_dir);
}

#[test]
#[ignore = "benchmark"]
fn benchmark_routing_fixture() {
    let (app_data_dir, host) = benchmark_host("routing");
    seed_catalog_with_many_task_skills(&host, 240);

    let (p50_ms, p95_ms, max_ms, result) = measure_service_call(|| {
        let response = host.handle(ServiceRequest {
            id: Some("benchmark-routing".to_string()),
            method: "task.rankSkillRoutes".to_string(),
            params: json!({
                "task": "Validate release readiness privacy evidence",
                "agent": "codex",
                "limit": 8
            }),
        });
        assert!(response.ok, "{:?}", response.error);
        response.result.expect("routing benchmark result")
    });

    let rows = result
        .get("route_candidates")
        .and_then(Value::as_array)
        .map(Vec::len)
        .unwrap_or_default();
    let scanned = result
        .pointer("/aggregation/scanned_count")
        .and_then(Value::as_u64)
        .unwrap_or_default();
    let total = result
        .pointer("/aggregation/total_count")
        .and_then(Value::as_u64)
        .unwrap_or_default();

    println!(
        "skills-copilot-bench benchmark=routing dataset=240_skills iterations={BENCH_ITERATIONS} warmups={BENCH_WARMUPS} p50_ms={p50_ms:.2} p95_ms={p95_ms:.2} max_ms={max_ms:.2} rows={rows} scanned={scanned} total={total}"
    );

    let _ = fs::remove_dir_all(app_data_dir);
}

#[test]
#[ignore = "benchmark"]
fn benchmark_knowledge_search_fixture() {
    let (app_data_dir, host) = benchmark_host("knowledge-search");
    seed_catalog_with_many_task_skills(&host, 120);

    let (p50_ms, p95_ms, max_ms, result) = measure_service_call(|| {
        let response = host.handle(ServiceRequest {
            id: Some("benchmark-knowledge-search".to_string()),
            method: "knowledge.search".to_string(),
            params: json!({
                "query": "release readiness privacy",
                "agent": "codex",
                "limit": 25
            }),
        });
        assert!(response.ok, "{:?}", response.error);
        response.result.expect("knowledge search benchmark result")
    });

    let rows = result
        .get("rows")
        .and_then(Value::as_array)
        .map(Vec::len)
        .unwrap_or_default();
    let indexed = result
        .pointer("/summary/indexed_skill_count")
        .and_then(Value::as_u64)
        .unwrap_or_default();

    println!(
        "skills-copilot-bench benchmark=knowledge_search dataset=120_skills iterations={BENCH_ITERATIONS} warmups={BENCH_WARMUPS} p50_ms={p50_ms:.2} p95_ms={p95_ms:.2} max_ms={max_ms:.2} rows={rows} indexed={indexed}"
    );

    let _ = fs::remove_dir_all(app_data_dir);
}
