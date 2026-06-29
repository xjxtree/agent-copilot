import Darwin
import Foundation

final class FakeServiceScript: ServiceProcessRunning {
    private let directory: URL
    let executableURL: URL
    private let callsURL: URL
    private let scenarioLock = NSLock()
    private var currentScenario = "normal"

    init() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("skills-copilot-fake-service-\(UUID().uuidString)", isDirectory: true)
        executableURL = directory.appendingPathComponent("fake-service.sh")
        callsURL = directory.appendingPathComponent("calls.log")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: callsURL.path, contents: nil)
        try script.write(to: executableURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: executableURL.path
        )
    }

    func activate(scenario: String) {
        setScenario(scenario)
    }

    func setScenario(_ scenario: String) {
        scenarioLock.lock()
        currentScenario = scenario
        scenarioLock.unlock()
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: directory)
    }

    func serviceClient() -> ServiceClient {
        ServiceClient(processRunner: self, serviceURL: executableURL)
    }

    func run(executableURL: URL, input: Data, timeoutNanoseconds: UInt64?) async throws -> Data {
        let invocation = FakeServiceFileProcessInvocation(
            executableURL: self.executableURL,
            workingDirectory: directory,
            input: input,
            environmentOverrides: [
                "SKILLS_COPILOT_FAKE_SERVICE_SCENARIO": scenario,
                "SKILLS_COPILOT_FAKE_SERVICE_CALLS": callsURL.path
            ]
        )
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .userInitiated) {
                try invocation.run(timeoutNanoseconds: timeoutNanoseconds)
            }.value
        } onCancel: {
            invocation.cancel()
        }
    }

    func calls() -> String {
        (try? String(contentsOf: callsURL, encoding: .utf8)) ?? ""
    }

    private var scenario: String {
        scenarioLock.lock()
        let value = currentScenario
        scenarioLock.unlock()
        return value
    }

    private var script: String {
        """
        #!/bin/sh
        input=$(cat)
        scenario=${SKILLS_COPILOT_FAKE_SERVICE_SCENARIO:-normal}

        if [ -n "$SKILLS_COPILOT_FAKE_SERVICE_CALLS" ]; then
          printf '%s\\n' "$input" >> "$SKILLS_COPILOT_FAKE_SERVICE_CALLS"
        fi

        respond() {
          printf '%s' "$1"
          exit 0
        }

        service_error() {
          respond '{"id":"test","ok":false,"result":null,"error":{"code":"test.error","message":"boom"}}'
        }

        status_response() {
          respond '{"id":"test","ok":true,"result":{"protocol_version":1,"version":"test","app_data_dir":"/tmp/skills-copilot","catalog_path":"/tmp/skills-copilot/catalog.sqlite","user_home":"/tmp/home","supported_methods":["app.stateSnapshot","service.status","catalog.listSkills","catalog.scanAll","catalog.getSkill","catalog.listFindings","catalog.listConflicts","skill.listEvents","snapshot.list","snapshot.listAgentConfig","config.toggleSkill","config.readAgentConfig","batch.previewSkillToggles","batch.applySkillToggles","project.getContext","project.setContext","project.clearContext","project.validateContext"],"adapter_capabilities":'"$adapter_capabilities"'}}'
        }

        adapter_capabilities='[{"agent":"claude-code","display_name":"Claude Code","status":"verified","scan":{"supported":true,"status":"verified","reason":null},"project_scan":{"supported":true,"status":"verified","reason":null},"config_toggle":{"supported":true,"status":"verified","reason":null},"config_snapshot":{"supported":true,"status":"verified","reason":null},"install":{"supported":true,"status":"verified","reason":null},"writable":{"supported":true,"status":"verified","reason":null},"blockers":[]},{"agent":"codex","display_name":"Codex","status":"verified","scan":{"supported":true,"status":"verified","reason":null},"project_scan":{"supported":true,"status":"verified","reason":null},"config_toggle":{"supported":true,"status":"verified","reason":null},"config_snapshot":{"supported":true,"status":"verified","reason":null},"install":{"supported":false,"status":"planned","reason":"Install is not part of this slice."},"writable":{"supported":true,"status":"verified","reason":null},"blockers":[]},{"agent":"opencode","display_name":"opencode","status":"verified","scan":{"supported":true,"status":"verified","reason":null},"project_scan":{"supported":true,"status":"verified","reason":null},"config_toggle":{"supported":true,"status":"verified","reason":null},"config_snapshot":{"supported":true,"status":"verified","reason":null},"install":{"supported":true,"status":"verified","reason":null},"writable":{"supported":true,"status":"verified","reason":null},"blockers":[]},{"agent":"pi","display_name":"Pi","status":"read-only","scan":{"supported":true,"status":"verified","reason":null},"project_scan":{"supported":true,"status":"verified","reason":null},"config_toggle":{"supported":false,"status":"read-only","reason":"Pi writable support is blocked pending evidence."},"config_snapshot":{"supported":false,"status":"read-only","reason":"Pi is read-only."},"install":{"supported":false,"status":"read-only","reason":"Pi is read-only."},"writable":{"supported":false,"status":"read-only","reason":"Pi is read-only."},"blockers":["Pi writable support is blocked pending evidence."]},{"agent":"hermes","display_name":"Hermes","status":"read-only","scan":{"supported":true,"status":"verified","reason":null},"project_scan":{"supported":false,"status":"read-only","reason":"Hermes project skills are not confirmed."},"config_toggle":{"supported":false,"status":"read-only","reason":"Hermes is read-only."},"config_snapshot":{"supported":false,"status":"read-only","reason":"Hermes is read-only."},"install":{"supported":false,"status":"read-only","reason":"Hermes is read-only."},"writable":{"supported":false,"status":"read-only","reason":"Hermes is read-only."},"blockers":["Hermes is read-only."]},{"agent":"openclaw","display_name":"OpenClaw","status":"read-only","scan":{"supported":true,"status":"verified","reason":null},"project_scan":{"supported":true,"status":"verified","reason":null},"config_toggle":{"supported":false,"status":"read-only","reason":"OpenClaw is read-only."},"config_snapshot":{"supported":false,"status":"read-only","reason":"OpenClaw is read-only."},"install":{"supported":false,"status":"read-only","reason":"OpenClaw is read-only."},"writable":{"supported":false,"status":"read-only","reason":"OpenClaw is read-only."},"blockers":["OpenClaw is read-only."]}]'
        project_active='{"id":"project-1","name":"Fixture Project","root_path":"/tmp/project","current_cwd":"/tmp/project","last_used_at":"2026-06-08T00:00:00Z","is_active":true,"validation_error":null}'
        project_recent='[{"id":"project-1","name":"Fixture Project","root_path":"/tmp/project","current_cwd":"/tmp/project","last_used_at":"2026-06-08T00:00:00Z","is_active":true,"validation_error":null},{"id":"project-2","name":"Other Project","root_path":"/tmp/other","current_cwd":"/tmp/other","last_used_at":"2026-06-07T00:00:00Z","is_active":false,"validation_error":null}]'
        project_invalid='{"id":"project-missing","name":"Missing Project","root_path":"/tmp/missing","current_cwd":"/tmp/missing","last_used_at":"2026-06-08T00:00:00Z","is_active":true,"validation_error":"Project root does not exist."}'

        skills_normal='[{"id":"alpha","agent":"claude-code","scope":"agent-global","path":"/tmp/global/alpha/SKILL.md","display_path":"/tmp/global/alpha/SKILL.md","definition_id":"def.alpha","name":"Alpha","state":"loaded","enabled":true},{"id":"beta","agent":"claude-code","scope":"agent-project","path":"/tmp/project/beta/SKILL.md","display_path":"/tmp/project/beta/SKILL.md","definition_id":"def.beta","name":"Beta","state":"loaded","enabled":true},{"id":"gamma","agent":"codex","scope":"agent-global","path":"/tmp/codex/skills/gamma/SKILL.md","display_path":"~/.codex/skills/gamma/SKILL.md","definition_id":"codex:gamma","name":"Gamma","state":"loaded","enabled":true}]'
        skills_toggled='[{"id":"alpha","agent":"claude-code","scope":"agent-global","path":"/tmp/global/alpha/SKILL.md","display_path":"/tmp/global/alpha/SKILL.md","definition_id":"def.alpha","name":"Alpha","state":"loaded","enabled":true},{"id":"beta","agent":"claude-code","scope":"agent-project","path":"/tmp/project/beta/SKILL.md","display_path":"/tmp/project/beta/SKILL.md","definition_id":"def.beta","name":"Beta","state":"loaded","enabled":false},{"id":"gamma","agent":"codex","scope":"agent-global","path":"/tmp/codex/skills/gamma/SKILL.md","display_path":"~/.codex/skills/gamma/SKILL.md","definition_id":"codex:gamma","name":"Gamma","state":"loaded","enabled":true}]'
        skills_codex_toggled='[{"id":"alpha","agent":"claude-code","scope":"agent-global","path":"/tmp/global/alpha/SKILL.md","display_path":"/tmp/global/alpha/SKILL.md","definition_id":"def.alpha","name":"Alpha","state":"loaded","enabled":true},{"id":"beta","agent":"claude-code","scope":"agent-project","path":"/tmp/project/beta/SKILL.md","display_path":"/tmp/project/beta/SKILL.md","definition_id":"def.beta","name":"Beta","state":"loaded","enabled":true},{"id":"gamma","agent":"codex","scope":"agent-global","path":"/tmp/codex/skills/gamma/SKILL.md","display_path":"~/.codex/skills/gamma/SKILL.md","definition_id":"codex:gamma","name":"Gamma","state":"loaded","enabled":false}]'
        skills_opencode='[{"id":"omega","agent":"opencode","scope":"agent-global","path":"/tmp/opencode/skills/omega/SKILL.md","display_path":"~/.config/opencode/skills/omega/SKILL.md","definition_id":"opencode:omega","name":"Omega","state":"loaded","enabled":true}]'
        skills_opencode_toggled='[{"id":"omega","agent":"opencode","scope":"agent-global","path":"/tmp/opencode/skills/omega/SKILL.md","display_path":"~/.config/opencode/skills/omega/SKILL.md","definition_id":"opencode:omega","name":"Omega","state":"disabled","enabled":false}]'
        skills_toolglobal='[{"id":"tool-alpha","agent":"tool-global","scope":"tool-global","path":"/tmp/skills-copilot/staging/tool-alpha/SKILL.md","display_path":"Tool Pool/tool-alpha/SKILL.md","definition_id":"tool:alpha","name":"Tool Alpha","state":"loaded","enabled":true}]'
        skills_batch_mixed='[{"id":"alpha","agent":"claude-code","scope":"agent-global","path":"/tmp/global/alpha/SKILL.md","display_path":"/tmp/global/alpha/SKILL.md","definition_id":"def.alpha","name":"Alpha","state":"loaded","enabled":true},{"id":"beta","agent":"claude-code","scope":"agent-project","path":"/tmp/project/beta/SKILL.md","display_path":"/tmp/project/beta/SKILL.md","definition_id":"def.beta","name":"Beta","state":"loaded","enabled":false},{"id":"gamma","agent":"codex","scope":"agent-global","path":"/tmp/codex/skills/gamma/SKILL.md","display_path":"~/.codex/skills/gamma/SKILL.md","definition_id":"codex:gamma","name":"Gamma","state":"loaded","enabled":true},{"id":"pi-one","agent":"pi","scope":"agent-global","path":"/tmp/pi/skills/pi-one/SKILL.md","display_path":"~/.pi/skills/pi-one/SKILL.md","definition_id":"pi:one","name":"Pi One","state":"loaded","enabled":true}]'
        skills_batch_applied='[{"id":"alpha","agent":"claude-code","scope":"agent-global","path":"/tmp/global/alpha/SKILL.md","display_path":"/tmp/global/alpha/SKILL.md","definition_id":"def.alpha","name":"Alpha","state":"loaded","enabled":false},{"id":"beta","agent":"claude-code","scope":"agent-project","path":"/tmp/project/beta/SKILL.md","display_path":"/tmp/project/beta/SKILL.md","definition_id":"def.beta","name":"Beta","state":"loaded","enabled":false},{"id":"gamma","agent":"codex","scope":"agent-global","path":"/tmp/codex/skills/gamma/SKILL.md","display_path":"~/.codex/skills/gamma/SKILL.md","definition_id":"codex:gamma","name":"Gamma","state":"loaded","enabled":false},{"id":"pi-one","agent":"pi","scope":"agent-global","path":"/tmp/pi/skills/pi-one/SKILL.md","display_path":"~/.pi/skills/pi-one/SKILL.md","definition_id":"pi:one","name":"Pi One","state":"loaded","enabled":true}]'
        findings_stale_before='[{"id":"finding-stale-before","instance_id":"beta","definition_id":"def.beta","rule_id":"frontmatter.required-fields","severity":"error","message":"before","suggestion":"Add missing metadata.","created_at":1}]'
        findings_stale_after_scan='[{"id":"finding-fresh-scan","instance_id":"beta","definition_id":"def.beta","rule_id":"fingerprint.changed","severity":"info","message":"scan","suggestion":"Review changed content.","created_at":2},{"id":"finding-fresh-codex","instance_id":"gamma","definition_id":"codex:gamma","rule_id":"path.outside-workspace","severity":"error","message":"codex","suggestion":"Move the skill under the project root.","created_at":3}]'
        findings_stale_after_project='[{"id":"finding-project","instance_id":"gamma","definition_id":"codex:gamma","rule_id":"name.collision","severity":"warning","message":"project","suggestion":"Review duplicate names.","created_at":4}]'
        findings_stale_after_toggle='[{"id":"finding-toggle","instance_id":"beta","definition_id":"def.beta","rule_id":"path.outside-workspace","severity":"error","message":"toggle","suggestion":"Move the skill under the project root.","created_at":5}]'
        findings_detail_scope='[{"id":"finding-beta-instance","instance_id":"beta","definition_id":"def.beta","rule_id":"fingerprint.changed","severity":"info","message":"beta instance","suggestion":"Review beta.","created_at":6},{"id":"finding-beta-definition-only","instance_id":"alpha","definition_id":"def.beta","rule_id":"name.collision","severity":"warning","message":"shared definition, wrong skill","suggestion":"Do not show on beta detail.","created_at":7},{"id":"finding-gamma-instance","instance_id":"gamma","definition_id":"codex:gamma","rule_id":"path.outside-workspace","severity":"error","message":"gamma instance","suggestion":"Review gamma.","created_at":8}]'
        conflicts_detail_scope='[{"id":"conflict-beta-alpha","definition_id":"def.beta","reason":"content-drift","winner_id":null,"instance_ids":["beta","alpha"]},{"id":"conflict-beta-gamma-cross-agent","definition_id":"def.beta","reason":"source-overlap","winner_id":null,"instance_ids":["beta","gamma"]},{"id":"conflict-alpha-gamma-no-selected","definition_id":"def.shared","reason":"source-overlap","winner_id":null,"instance_ids":["alpha","gamma"]}]'
        events_beta='[{"id":1001,"instance_id":"beta","kind":"toggle","payload":{"enabled":false,"agent":"claude-code","skill_name":"Beta"},"occurred_at":10},{"id":1000,"instance_id":"beta","kind":"scan","payload":{"summary":"rescan"},"occurred_at":9}]'
        events_gamma='[{"id":2001,"instance_id":"gamma","kind":"toggle","payload":{"enabled":true,"agent":"codex","skill_name":"Gamma"},"occurred_at":11}]'
        snapshots_claude='[{"id":"snap-claude-new","agent":"claude-code","scope":"agent-global","target":"/tmp/home/.claude/settings.json","content":"{}\\n","reason":"pre-toggle","created_at":30},{"id":"snap-claude-old","agent":"claude-code","scope":"agent-project","target":"/tmp/project/.claude/settings.local.json","content":"{}\\n","reason":"pre-config-edit","created_at":20}]'
        snapshots_codex='[{"id":"snap-codex","agent":"codex","scope":"agent-global","target":"/tmp/home/.codex/config.toml","content":"disable_response_storage = true\\n","reason":"pre-toggle","created_at":40}]'
        snapshots_opencode='[{"id":"snap-opencode","agent":"opencode","scope":"agent-global","target":"/tmp/home/.config/opencode/opencode.json","content":"{}\\n","reason":"pre-toggle","created_at":50}]'
        agent_config_claude='[{"agent":"claude-code","scope":"agent-global","target":"/tmp/home/.claude/settings.json","format":"json","content":"{\\"skillOverrides\\":{}}\\n","exists":true},{"agent":"claude-code","scope":"agent-project","target":"/tmp/project/.claude/settings.local.json","format":"json","content":"{\\"permissions\\":{\\"allow\\":[\\"Bash(grep *)\\"]}}\\n","exists":true}]'
        agent_config_codex='[{"agent":"codex","scope":"agent-global","target":"/tmp/home/.codex/config.toml","format":"toml","content":"model = \\"gpt-5\\"\\n","exists":true},{"agent":"codex","scope":"agent-project","target":"/tmp/project/.codex/config.toml","format":"toml","content":"approval_policy = \\"never\\"\\n","exists":true}]'
        agent_config_opencode='[{"agent":"opencode","scope":"agent-global","target":"/tmp/home/.config/opencode/opencode.json","format":"json","content":"{\\"permission\\":{\\"skill\\":{}}}\\n","exists":true},{"agent":"opencode","scope":"agent-project","target":"/tmp/project/opencode.json","format":"json","content":"{\\"permission\\":{\\"skill\\":{\\"local-review\\":\\"deny\\"}}}\\n","exists":true}]'
        agent_config_pi='[{"agent":"pi","scope":"agent-global","target":"/tmp/home/.pi/agent/settings.json","format":"json","content":"{\\"skills\\":{\\"disabled\\":[\\"alibabacloud-agentbay-aio-skills\\"]},\\"apiToken\\":\\"fixture-token\\"}\\n","exists":true},{"agent":"pi","scope":"agent-project","target":"/tmp/project/.pi/settings.json","format":"json","content":"{\\"skills\\":{\\"disabled\\":[]}}\\n","exists":false}]'
        agent_config_hermes='[{"agent":"hermes","scope":"agent-global","target":"/tmp/home/.hermes/config.yaml","format":"yaml","content":"skills:\\n  disabled: []\\n","exists":true}]'
        agent_config_openclaw='[{"agent":"openclaw","scope":"agent-global","target":"/tmp/home/.openclaw/openclaw.json","format":"json","content":"{\\"skills\\":{\\"entries\\":{}}}\\n","exists":true}]'

        state_snapshot_response() {
          if [ "$scenario" = "error" ]; then service_error; fi
          if [ "$scenario" = "empty" ]; then
            state_skills='[]'
            state_findings='[]'
            state_conflicts='[]'
          elif [ "$scenario" = "toggle-disabled" ]; then
            state_skills=$skills_toggled
            state_findings='[]'
            state_conflicts='[]'
          elif [ "$scenario" = "toggle-codex-disabled" ]; then
            state_skills=$skills_codex_toggled
            state_findings='[]'
            state_conflicts='[]'
          elif [ "$scenario" = "opencode" ]; then
            if grep -q '"method":"config.toggleSkill"' "$SKILLS_COPILOT_FAKE_SERVICE_CALLS"; then
              state_skills=$skills_opencode_toggled
            else
              state_skills=$skills_opencode
            fi
            state_findings='[]'
            state_conflicts='[]'
          elif [ "$scenario" = "tool-global" ]; then
            state_skills=$skills_toolglobal
            state_findings='[]'
            state_conflicts='[]'
          elif [ "$scenario" = "stale-before" ]; then
            state_skills=$skills_normal
            state_findings=$findings_stale_before
            state_conflicts='[]'
          elif [ "$scenario" = "stale-after-scan" ]; then
            state_skills=$skills_normal
            state_findings=$findings_stale_after_scan
            state_conflicts='[]'
          elif [ "$scenario" = "stale-after-project" ]; then
            state_skills=$skills_normal
            state_findings=$findings_stale_after_project
            state_conflicts='[]'
          elif [ "$scenario" = "stale-after-toggle" ]; then
            state_skills=$skills_toggled
            state_findings=$findings_stale_after_toggle
            state_conflicts='[]'
          elif [ "$scenario" = "detail-scope" ]; then
            state_skills=$skills_normal
            state_findings=$findings_detail_scope
            state_conflicts=$conflicts_detail_scope
          elif [ "$scenario" = "batch-mixed" ]; then
            if grep -q '"method":"batch.applySkillToggles"' "$SKILLS_COPILOT_FAKE_SERVICE_CALLS"; then
              state_skills=$skills_batch_applied
            else
              state_skills=$skills_batch_mixed
            fi
            state_findings='[]'
            state_conflicts='[]'
          else
            state_skills=$skills_normal
            state_findings='[]'
            state_conflicts='[]'
          fi
          respond '{"id":"test","ok":true,"result":{"status":{"protocol_version":1,"version":"test","app_data_dir":"/tmp/skills-copilot","catalog_path":"/tmp/skills-copilot/catalog.sqlite","user_home":"/tmp/home","supported_methods":["app.stateSnapshot","service.status","catalog.listSkills","catalog.scanAll","catalog.getSkill","catalog.listFindings","catalog.listConflicts","skill.listEvents","snapshot.list","snapshot.listAgentConfig","config.toggleSkill","config.readAgentConfig","batch.previewSkillToggles","batch.applySkillToggles","project.getContext","project.setContext","project.clearContext","project.validateContext"],"adapter_capabilities":'"$adapter_capabilities"'},"skills":'"$state_skills"',"findings":'"$state_findings"',"conflicts":'"$state_conflicts"',"snapshots":[]}}'
        }

        detail_alpha='{"id":"alpha","agent":"claude-code","scope":"agent-global","path":"/tmp/global/alpha/SKILL.md","display_path":"/tmp/global/alpha/SKILL.md","definition_id":"def.alpha","name":"Alpha","description":"Alpha skill","state":"loaded","enabled":true,"frontmatter_raw":"name: Alpha","body":"Alpha body","permissions":{"marker":"alpha"},"fingerprint":"fp-alpha"}'
        detail_beta_enabled='{"id":"beta","agent":"claude-code","scope":"agent-project","path":"/tmp/project/beta/SKILL.md","display_path":"/tmp/project/beta/SKILL.md","definition_id":"def.beta","name":"Beta","description":"Beta skill","state":"loaded","enabled":true,"frontmatter_raw":"name: Beta","body":"Beta body","permissions":{"marker":"default"},"fingerprint":"fp-beta"}'
        detail_beta_disabled='{"id":"beta","agent":"claude-code","scope":"agent-project","path":"/tmp/project/beta/SKILL.md","display_path":"/tmp/project/beta/SKILL.md","definition_id":"def.beta","name":"Beta","description":"Beta skill","state":"loaded","enabled":false,"frontmatter_raw":"name: Beta","body":"Beta body","permissions":{"marker":"toggle-disabled"},"fingerprint":"fp-beta"}'
        detail_gamma='{"id":"gamma","agent":"codex","scope":"agent-global","path":"/tmp/codex/skills/gamma/SKILL.md","display_path":"~/.codex/skills/gamma/SKILL.md","definition_id":"codex:gamma","name":"Gamma","description":"Gamma skill","state":"loaded","enabled":true,"frontmatter_raw":"name: Gamma","body":"Gamma body","permissions":{"marker":"codex"},"fingerprint":"fp-gamma"}'
        detail_gamma_disabled='{"id":"gamma","agent":"codex","scope":"agent-global","path":"/tmp/codex/skills/gamma/SKILL.md","display_path":"~/.codex/skills/gamma/SKILL.md","definition_id":"codex:gamma","name":"Gamma","description":"Gamma skill","state":"loaded","enabled":false,"frontmatter_raw":"name: Gamma","body":"Gamma body","permissions":{"marker":"codex-disabled"},"fingerprint":"fp-gamma"}'
        detail_beta_before='{"id":"beta","agent":"claude-code","scope":"agent-project","path":"/tmp/project/beta/SKILL.md","display_path":"/tmp/project/beta/SKILL.md","definition_id":"def.beta","name":"Beta","description":"Beta skill","state":"loaded","enabled":true,"frontmatter_raw":"name: Beta","body":"Beta body","permissions":{"marker":"before"},"fingerprint":"fp-beta-before"}'
        detail_beta_scan='{"id":"beta","agent":"claude-code","scope":"agent-project","path":"/tmp/project/beta/SKILL.md","display_path":"/tmp/project/beta/SKILL.md","definition_id":"def.beta","name":"Beta","description":"Beta skill","state":"loaded","enabled":true,"frontmatter_raw":"name: Beta","body":"Beta body","permissions":{"marker":"scan"},"fingerprint":"fp-beta-scan"}'
        detail_beta_toggle='{"id":"beta","agent":"claude-code","scope":"agent-project","path":"/tmp/project/beta/SKILL.md","display_path":"/tmp/project/beta/SKILL.md","definition_id":"def.beta","name":"Beta","description":"Beta skill","state":"loaded","enabled":false,"frontmatter_raw":"name: Beta","body":"Beta body","permissions":{"marker":"toggle"},"fingerprint":"fp-beta-toggle"}'
        detail_gamma_scan='{"id":"gamma","agent":"codex","scope":"agent-global","path":"/tmp/codex/skills/gamma/SKILL.md","display_path":"~/.codex/skills/gamma/SKILL.md","definition_id":"codex:gamma","name":"Gamma","description":"Gamma skill","state":"loaded","enabled":true,"frontmatter_raw":"name: Gamma","body":"Gamma body","permissions":{"marker":"codex-scan"},"fingerprint":"fp-gamma-scan"}'
        detail_gamma_project='{"id":"gamma","agent":"codex","scope":"agent-global","path":"/tmp/codex/skills/gamma/SKILL.md","display_path":"~/.codex/skills/gamma/SKILL.md","definition_id":"codex:gamma","name":"Gamma","description":"Gamma skill","state":"loaded","enabled":true,"frontmatter_raw":"name: Gamma","body":"Gamma body","permissions":{"marker":"project"},"fingerprint":"fp-gamma-project"}'
        detail_omega='{"id":"omega","agent":"opencode","scope":"agent-global","path":"/tmp/opencode/skills/omega/SKILL.md","display_path":"~/.config/opencode/skills/omega/SKILL.md","definition_id":"opencode:omega","name":"Omega","description":"Omega skill","state":"loaded","enabled":true,"frontmatter_raw":"name: Omega","body":"Omega body","permissions":{},"fingerprint":"fp-omega"}'
        detail_omega_disabled='{"id":"omega","agent":"opencode","scope":"agent-global","path":"/tmp/opencode/skills/omega/SKILL.md","display_path":"~/.config/opencode/skills/omega/SKILL.md","definition_id":"opencode:omega","name":"Omega","description":"Omega skill","state":"disabled","enabled":false,"frontmatter_raw":"name: Omega","body":"Omega body","permissions":{},"fingerprint":"fp-omega"}'
        detail_toolglobal='{"id":"tool-alpha","agent":"tool-global","scope":"tool-global","path":"/tmp/skills-copilot/staging/tool-alpha/SKILL.md","display_path":"Tool Pool/tool-alpha/SKILL.md","definition_id":"tool:alpha","name":"Tool Alpha","description":"Tool-global staged skill","state":"loaded","enabled":true,"frontmatter_raw":"name: Tool Alpha","body":"Tool Alpha body","permissions":{},"fingerprint":"fp-tool-alpha"}'

        case "$input" in
          *\\"app.stateSnapshot\\"*)
            state_snapshot_response
            ;;
          *\\"service.status\\"*)
            if [ "$scenario" = "error" ]; then service_error; fi
            status_response
            ;;
          *\\"rules.listTuning\\"*)
            respond '{"id":"test","ok":true,"result":[]}'
            ;;
          *\\"llm.status\\"*)
            if [ "$scenario" = "old-service" ]; then
              respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: llm.status"}}'
            elif [ "$scenario" = "llm-ready" ] || [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"enabled":true,"provider":"openai","model":"gpt-5","disabled_reason":null,"supported_actions":["analyze","recommend","explain_conflict","draft_frontmatter"]}}'
            else
              respond '{"id":"test","ok":true,"result":{"enabled":false,"provider":null,"model":null,"disabled_reason":"LLM is disabled.","supported_actions":["analyze","recommend","explain_conflict","draft_frontmatter"]}}'
            fi
            ;;
          *\\"llm.listProviderProfiles\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"service_available":true,"enabled":true,"configured":true,"active_profile_id":"openai-compatible","credential_storage":"keychain","credential_persistence_allowed":true,"profiles":[{"id":"openai-compatible","kind":"openai-compatible","endpoint":"https://llm.example.com/v1","model":"gpt-5","enabled":true,"configured":true,"has_api_key":true}]}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: llm.listProviderProfiles"}}'
            ;;
          *\\"llm.prepareSkillAnalysis\\"*)
            if [ "$scenario" = "old-service" ]; then
              respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: llm.prepareSkillAnalysis"}}'
            elif [ "$scenario" = "llm-ready" ] || [ "$scenario" = "prompt-ready" ]; then
              if printf '%s' "$input" | grep -q '\\"analysis_kind\\":\\"risk\\"'; then
                respond '{"id":"test","ok":true,"result":{"enabled":false,"disabled_reason":"AI analysis is disabled by default.","analysis_kind":"risk","selected_skill_count":1,"included_skills":[{"instance_id":"beta","name":"Beta","agent":"claude-code"}],"excluded_count":0,"missing_count":0,"prompt_draft":"Risk prompt for Beta.","summary_draft":"Risk summary for Beta.","write_back_enabled":false,"script_execution_enabled":false,"credential_storage_enabled":false,"confirmation_required":true}}'
              else
                respond '{"id":"test","ok":true,"result":{"enabled":false,"disabled_reason":"AI analysis is disabled by default.","analysis_kind":"overview","selected_skill_count":2,"included_skills":[{"instance_id":"alpha","name":"Alpha","agent":"claude-code"},{"instance_id":"beta","name":"Beta","agent":"claude-code"}],"excluded_count":0,"missing_count":0,"prompt_draft":"Overview prompt for visible skills.","summary_draft":"Overview summary for visible skills.","safety":{"write_back_enabled":false,"script_execution_enabled":false,"credential_storage_enabled":false,"confirmation_required":true}}}'
              fi
            else
              respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: llm.prepareSkillAnalysis"}}'
            fi
            ;;
          *\\"analysis.scoreSkillQuality\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"instance_id":"beta","score":82,"band":"Good","summary":"Beta has usable metadata, one permission clarity gap, and no same-agent conflict.","components":[{"key":"metadata","label":"Metadata completeness","score":92,"summary":"Name and description are present."},{"key":"permissions","label":"Permission clarity","score":70,"summary":"Network access needs explicit declaration."}],"evidence":[{"title":"Metadata","detail":"Description is present.","source":"catalog"},{"title":"Findings","detail":"One permission warning.","source":"permissions.network-declared"}],"risk_notes":["Network access is not declared."],"suggested_improvements":["Declare network access explicitly."],"safety":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_secret_returned":false}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: analysis.scoreSkillQuality"}}'
            ;;
          *\\"task.checkReadiness\\"*)
            if [ "$scenario" = "prompt-ready" ] || [ "$scenario" = "llm-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"task_text":"Audit local skills for a release note.","score":74,"band":"Partial","summary":"Beta has local audit coverage but lacks release-note-specific examples.","candidate_skills":[{"instance_id":"beta","name":"Beta","agent":"claude-code","score":74,"band":"Partial","rationale":"Best selected-skill fit for local audit work.","evidence":["description match","catalog evidence available"]}],"gaps":["No release-note-specific examples."],"blockers":[],"risk_notes":["Permission clarity should be reviewed before routing."],"evidence":[{"title":"Metadata","detail":"Description mentions local audit.","source":"catalog"},{"title":"Findings","detail":"One permission warning remains.","source":"permissions.network-declared"}],"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_secret_returned":false}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: task.checkReadiness"}}'
            ;;
          *\\"task.rankSkillRoutes\\"*)
            if [ "$scenario" = "prompt-ready" ] || [ "$scenario" = "llm-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"task":"Route a local audit release note task.","confidence_score":88,"band":"High","summary":"Beta is the strongest selected route; Alpha is a nearby alternate.","candidate_routes":[{"instance_id":"beta","name":"Beta","agent":"claude-code","confidence_score":88,"band":"High","summary":"Best project-scoped local audit fit.","match_reasons":["Description matches local audit.","Selected skill is enabled."],"ambiguity_warnings":["Alpha has overlapping audit wording."],"wrong_pick_risks":["Could miss release-note-specific examples."],"evidence_references":[{"title":"Metadata","detail":"Description mentions local audit.","source":"catalog"}]},{"instance_id":"alpha","name":"Alpha","agent":"claude-code","score":69,"band":"Medium","summary":"Nearby fallback with weaker task wording.","match_reasons":["Same agent and enabled."],"ambiguity_warnings":[],"wrong_pick_risks":["Less project-specific."],"evidence":["Enabled fallback"]}],"ambiguity_warnings":["Alpha has overlapping audit wording."],"wrong_pick_risks":["Choosing Alpha may miss project-scoped evidence."],"evidence_references":[{"title":"Comparison","detail":"Same-agent candidates reviewed.","source":"analysis"}],"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_secret_returned":false}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: task.rankSkillRoutes"}}'
            ;;
          *\\"task.compareAgentReadiness\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.50","catalog_available":true,"filters":{"limit_per_agent":3,"include_routing_accuracy":true,"include_benchmarks":true},"summary":{"agent_count":2,"candidate_count":5,"ready_agent_count":1,"partial_agent_count":1,"blocked_agent_count":0,"gap_issue_count":1,"recommended_agent":"claude-code","summary":"Claude Code is strongest for this task; Codex is usable but lacks benchmark coverage."},"recommended_agent":{"agent":"claude-code","display_name":"Claude Code","comparison_score":93,"readiness_score":88,"routing_confidence_score":91,"skill_name":"Beta","reason":"Best local task fit with benchmark and accuracy context."},"agent_rows":[{"rank":1,"agent":"claude-code","display_name":"Claude Code","comparison_score":93,"readiness_score":88,"readiness_band":"Ready","routing_confidence_score":91,"routing_confidence_band":"High","best_candidate":{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","scope":"agent-project","enabled":true,"state":"loaded","readiness_score":88,"readiness_band":"Ready","routing_confidence_score":91,"routing_confidence_band":"High","quality_score":82},"candidate_count":3,"enabled_scope_risk_state":{"enabled":true,"scope":"agent-project","state":"loaded","risk_level":"low","risk_summary":"Low local risk.","writable_status":"verified","adapter_status":"healthy"},"blocker_count":0,"gap_count":0,"reasons":["Description matches local audit.","Benchmark expected route is covered."],"blocker_notes":[],"gap_notes":[],"routing_accuracy_context":{"summary":"7 of 8 known traces hit expected route."},"benchmark_context":{"summary":"Benchmark expected route is covered."},"evidence_refs":["benchmark:bench-1","trace:trace-1"]},{"rank":2,"agent":"codex","display_name":"Codex","comparison_score":72,"readiness_score":74,"readiness_band":"Partial","routing_confidence_score":67,"routing_confidence_band":"Medium","best_candidate":{"instance_id":"gamma","definition_id":"codex:gamma","skill_name":"Gamma","scope":"agent-global","enabled":true,"state":"loaded","readiness_score":74,"readiness_band":"Partial","routing_confidence_score":67,"routing_confidence_band":"Medium","quality_score":76},"candidate_count":2,"enabled_scope_risk_state":{"enabled":true,"scope":"agent-global","state":"loaded","risk_level":"medium","risk_summary":"Benchmark coverage is missing.","writable_status":"verified","adapter_status":"healthy"},"blocker_count":0,"gap_count":1,"reasons":["Documentation wording overlaps."],"blocker_notes":[],"gap_notes":["No benchmark covers the Codex route."],"routing_accuracy_context":{"summary":"No imported traces in window."},"benchmark_context":{"summary":"No baseline saved."},"evidence_refs":["catalog:gamma"]}],"gap_issue_rows":[{"source":"benchmark","severity":"warning","agent":"codex","title":"Missing Codex benchmark","detail":"No benchmark covers the Codex route for this task.","evidence_refs":["benchmark:none"]}],"evidence_references":[{"title":"Benchmark","detail":"Beta benchmark matched expected route.","source":"task.evaluateBenchmarks","agent":"claude-code"},{"title":"Routing accuracy","detail":"Trace evidence favors Claude Code.","source":"routing.accuracyDashboard","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"cross_agent_task_readiness","summary":"Provider explanation is copy-only and preview-gated.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: task.compareAgentReadiness"}}'
            ;;
          *\\"evidence.previewMcpServers\\"*)
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: evidence.previewMcpServers"}}'
            ;;
          *\\"session.previewLocalSessions\\"*)
            if [ "$scenario" = "sessions-mixed" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.98","authorized":true,"count":3,"total_candidate_count":3,"session_rows":[{"id":"session-alpha","title":"Analyze repository CI","source_kind":"authorized-local-session","agent":"claude-code","scope":"project","project_root":"/tmp/project","redacted_path":"$HOME/.codex/sessions/alpha.jsonl","excerpt":"Audit the current repository CI pipeline.","user_message_count":1,"total_message_count":2,"tool_call_count":1,"skill_call_count":0,"content_hash":"alpha"},{"id":"session-develop","title":"Switch to develop branch","source_kind":"authorized-local-session","agent":"claude-code","scope":"project","project_root":"/tmp/project","redacted_path":"$HOME/.codex/sessions/develop.jsonl","excerpt":"Switch branch to develop and inspect status.","user_message_count":1,"total_message_count":2,"tool_call_count":1,"skill_call_count":0,"content_hash":"develop"},{"id":"session-global","title":"Review global setup","source_kind":"authorized-local-session","agent":"claude-code","scope":"agent-global","redacted_path":"$HOME/.codex/sessions/global.jsonl","excerpt":"Review global agent setup.","user_message_count":2,"total_message_count":4,"tool_call_count":0,"skill_call_count":1,"content_hash":"global"}],"skill_usage_rows":[{"skill_name":"release-audit","call_count":1,"session_count":1,"agent":"claude-code"}]}}'
            fi
            if [ "$scenario" = "sessions-all-scope-project-root" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.98","authorized":true,"count":2,"total_candidate_count":2,"session_rows":[{"id":"session-project-from-all","title":"Open latest app","source_kind":"authorized-local-session","agent":"claude-code","scope":"all","project_root":"<project-root>","redacted_path":"$HOME/.claude/projects/project/session.jsonl","excerpt":"Open latest app.","user_message_count":2,"total_message_count":24,"tool_call_count":24,"skill_call_count":1,"content_hash":"project-all"},{"id":"session-global","title":"Review global setup","source_kind":"authorized-local-session","agent":"claude-code","scope":"all","redacted_path":"$HOME/.claude.jsonl","excerpt":"Review global setup.","user_message_count":1,"total_message_count":2,"tool_call_count":0,"skill_call_count":0,"content_hash":"global"}]}}'
            fi
            if [ "$scenario" = "sessions" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.98","authorized":true,"count":2,"total_candidate_count":2,"session_rows":[{"id":"session-alpha","title":"Analyze repository CI","source_kind":"authorized-local-session","agent":"claude-code","scope":"project","project_root":"/tmp/project","redacted_path":"$HOME/.codex/sessions/alpha.jsonl","excerpt":"Audit the current repository CI pipeline.","user_message_count":1,"total_message_count":2,"tool_call_count":1,"skill_call_count":0,"content_hash":"alpha"},{"id":"session-develop","title":"Switch to develop branch","source_kind":"authorized-local-session","agent":"claude-code","scope":"project","project_root":"/tmp/project","redacted_path":"$HOME/.codex/sessions/develop.jsonl","excerpt":"Switch branch to develop and inspect status.","user_message_count":1,"total_message_count":2,"tool_call_count":1,"skill_call_count":0,"content_hash":"develop"}]}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: session.previewLocalSessions"}}'
            ;;
          *\\"knowledge.search\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.52","catalog_available":true,"filters":{"query":"release audit","agent":"claude-code","limit":20},"summary":{"result_count":1,"agent_count":1,"gap_count":1,"blocker_count":0,"summary":"Beta matches local knowledge for release audit work."},"knowledge_rows":[{"rank":1,"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","purpose":"Handles local audit release notes.","matched_fields":["purpose","tools"],"match_reasons":["Purpose mentions audit."],"keywords":["audit","release"],"tools":["rg"],"rules":["permissions.network-declared"],"capability_tags":["analysis"],"risk_tags":["local-only"],"evidence_refs":["catalog:beta"],"safety_flags":["provider not sent"]}],"facet_rows":[{"facet":"agent","value":"claude-code","count":1}],"gap_notes":["No fresh trace confirms the release audit route."],"blocker_notes":[],"evidence_references":[{"title":"Knowledge index","detail":"Beta indexed from local catalog metadata.","source":"knowledge.search","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"knowledge_search","summary":"Provider explanation is copy-only and preview-gated.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: knowledge.search"}}'
            ;;
          *\\"knowledge.buildLocalSkillMap\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.63","catalog_available":true,"filters":{"agent":"claude-code","selected_skill_id":"beta","selected_skill_name":"Beta","selected_skill_agent":"claude-code","project_root":"/tmp/project","current_cwd":"/tmp/project","workspace":"Fixture Project","limit":30,"include_edges":true,"include_clusters":true},"summary":{"node_count":2,"edge_count":1,"cluster_count":1,"domain_count":1,"skill_count":2,"agent_count":1,"gap_count":1,"blocker_count":0,"evidence_count":1,"selected_skill_context":"Beta in Claude Code project scope","summary":"Beta anchors the release audit local skill map."},"selected_skill":{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","quality_score":82,"readiness_score":78,"reasons":["Selected skill anchors this map."],"evidence_refs":["catalog:beta"],"safety_flags":["provider not sent"]},"nodes":[{"node_id":"skill:beta","label":"Beta","kind":"skill","instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","domain":"Release audit","cluster_id":"cluster:audit","weight":0.91,"reasons":["Selected skill anchors this map."],"evidence_refs":["catalog:beta"],"safety_flags":["provider not sent"]},{"node_id":"skill:alpha","label":"Alpha","kind":"skill","instance_id":"alpha","definition_id":"def.alpha","skill_name":"Alpha","agent":"claude-code","scope":"agent-global","enabled":true,"state":"loaded","domain":"Release audit","cluster_id":"cluster:audit","weight":0.64,"reasons":["Similar purpose wording."],"evidence_refs":["catalog:alpha"],"safety_flags":["provider not sent"]}],"edges":[{"source_id":"skill:beta","target_id":"skill:alpha","relation_kind":"similar-purpose","label":"Shared audit purpose","strength":0.74,"direction":"undirected","reasons":["Shared audit keywords and rg tool use."],"evidence_refs":["similar:audit"],"safety_flags":["provider not sent"]}],"clusters":[{"cluster_id":"cluster:audit","name":"Release audit","kind":"domain","summary":"Skills that support release audit workflows.","node_ids":["skill:beta","skill:alpha"],"agents":["claude-code"],"capabilities":["release-audit"],"gap_notes":["No Codex project route."],"blocker_notes":[],"evidence_refs":["domain:audit"],"safety_flags":["provider not sent"]}],"gap_rows":[{"title":"Missing Codex route","detail":"No Codex project route.","severity":"warning","agent":"codex","evidence_refs":["workspace:codex-gap"]}],"blocker_rows":[],"evidence_references":[{"title":"Local skill map","detail":"Map derived from local catalog and analysis evidence.","source":"knowledge.buildLocalSkillMap","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"local_skill_map","summary":"Provider explanation is copy-only and preview-gated.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: knowledge.buildLocalSkillMap"}}'
            ;;
          *\\"skill.lifecycleTimeline\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.66","catalog_available":true,"filters":{"agent":"claude-code","selected_skill_id":"beta","selected_skill_name":"Beta","selected_skill_agent":"claude-code","project_root":"/tmp/project","current_cwd":"/tmp/project","workspace":"Fixture Project","limit":20,"include_skill_rows":true,"include_agent_rows":true,"include_evidence":true,"include_safety_flags":true},"summary":{"event_count":3,"skill_count":1,"agent_count":1,"event_type_count":3,"stage_count":3,"gap_count":1,"blocker_count":1,"evidence_count":1,"safety_flag_count":1,"first_event_at":"2026-06-10T09:00:00Z","latest_event_at":"2026-06-12T08:00:00Z","summary":"Beta lifecycle was reconstructed from local catalog, scan, routing, and remediation evidence."},"timeline_rows":[{"id":"life-scan-beta","occurred_at":"2026-06-10T09:00:00Z","event_type":"scan.detected","lifecycle_stage":"discovered","title":"Beta loaded from project root","summary":"Catalog scan detected the selected skill.","agent":"claude-code","skill_name":"Beta","instance_id":"beta","definition_id":"def.beta","source":"catalog.scanAll","severity":"info","status":"loaded","evidence_refs":["catalog:beta"],"safety_flags":["provider not sent"]},{"id":"life-route-beta","occurred_at":"2026-06-12T08:00:00Z","event_type":"routing.selected","lifecycle_stage":"in-use","title":"Beta selected for release audit task","summary":"Routing confidence ranked Beta first.","agent":"claude-code","skill_name":"Beta","instance_id":"beta","definition_id":"def.beta","source":"task.rankSkillRoutes","severity":"info","status":"ready","evidence_refs":["route:beta"],"safety_flags":["provider not sent"]}],"skill_rows":[{"id":"skill-beta","event_type":"skill.aggregate","lifecycle_stage":"active","title":"Beta lifecycle","summary":"Three local lifecycle events reference Beta.","agent":"claude-code","skill_name":"Beta","instance_id":"beta","definition_id":"def.beta","source":"skill.lifecycleTimeline","status":"active","count":3,"evidence_refs":["catalog:beta"],"safety_flags":["provider not sent"]}],"agent_rows":[{"id":"agent-claude","event_type":"agent.aggregate","lifecycle_stage":"active","title":"Claude Code lifecycle coverage","summary":"Claude Code has selected skill lifecycle evidence.","agent":"claude-code","source":"skill.lifecycleTimeline","status":"covered","count":3,"evidence_refs":["agent:claude-code"],"safety_flags":["provider not sent"]}],"gap_notes":["No Codex lifecycle evidence for this selected skill."],"blocker_notes":["Lifecycle timeline is read-only and does not create snapshots."],"evidence_references":[{"title":"Lifecycle timeline","detail":"Derived from local catalog and analysis evidence.","source":"skill.lifecycleTimeline","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"skill_lifecycle_timeline","summary":"No provider request is prepared or sent.","draft_copy_only":true,"redacted":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent","read-only timeline"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: skill.lifecycleTimeline"}}'
            ;;
          *\\"llm.providerObservability\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.64","app_local_only":true,"metadata_redacted":true,"filters":{"window_days":30,"limit":30,"include_history":true,"include_budget_hints":true,"include_retention_recommendations":true,"include_evidence":true},"summary":{"call_count":3,"success_count":1,"failure_count":1,"blocked_count":1,"provider_count":1,"model_count":2,"destination_count":1,"error_count":1,"estimated_input_tokens":980,"estimated_output_tokens":320,"estimated_total_tokens":1300,"estimated_cost_usd":0.041,"total_duration_ms":1800,"average_duration_ms":600,"budget_hint_count":1,"retention_recommendation_count":2,"summary":"Three redacted provider-call metadata rows were reviewed locally."},"call_rows":[{"id":"call-1","preview_id":"preview-1","confirmation_id":"confirm-1","request_kind":"task_readiness","action":"task_readiness","provider":"openai-compatible","model":"gpt-5","destination_host":"llm.example.com","status":"succeeded","duration_ms":720,"input_tokens":420,"output_tokens":120,"total_tokens":540,"estimated_cost_usd":0.014,"completed_at":1781260000000,"draft_copy_only":true,"provider_request_sent":true,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_secret_returned":false,"evidence_refs":["prompt-run:preview-1"],"safety_flags":["copy-only","raw prompt not stored"],"detail":"Provider response metadata was stored without raw prompt or response."},{"id":"call-2","request_kind":"quality_score","provider":"openai-compatible","model":"gpt-5-mini","destination_host":"llm.example.com","status":"failed","error_code":"timeout","error_message":"Provider request timed out.","duration_ms":1080,"input_tokens":560,"output_tokens":0,"total_tokens":560,"estimated_cost_usd":0.027,"draft_copy_only":true,"provider_request_sent":true,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_secret_returned":false,"evidence_refs":["prompt-run:timeout"],"safety_flags":["raw response not stored"]}],"provider_rows":[{"kind":"provider","label":"OpenAI-compatible","provider":"openai-compatible","call_count":3,"success_count":1,"failure_count":1,"blocked_count":1,"estimated_tokens":1300,"estimated_cost_usd":0.041,"average_duration_ms":600,"status":"partial","notes":["One timeout and one blocked local preview."],"evidence_refs":["provider:openai-compatible"]}],"model_rows":[{"kind":"model","label":"gpt-5","model":"gpt-5","call_count":1,"success_count":1,"estimated_tokens":540,"status":"ok"},{"kind":"model","label":"gpt-5-mini","model":"gpt-5-mini","call_count":1,"failure_count":1,"estimated_tokens":560,"status":"warning"}],"destination_rows":[{"kind":"destination","label":"llm.example.com","destination_host":"llm.example.com","call_count":2,"status":"partial"}],"model_task_history_rows":[{"id":"model-task:fixture","source":"model-task-matches.json","source_kind":"manual","title":"Release audit model fit","task":"Review local release audit evidence.","task_kind":"task_readiness","agent":"codex","provider":"openai-compatible","model":"gpt-5","destination_host":"llm.example.com","match_status":"fit","confidence_score":88,"status":"fit","latency_ms":720,"estimated_total_tokens":540,"estimated_cost_usd":0.014,"gap_notes":[],"blocker_notes":[],"outcome_notes":["The model was recorded as a fit for release audit work."],"evidence_refs":["prompt-run:preview-1"],"redaction_status":"redacted-local-only","safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false}}],"status_rows":[{"severity":"info","status":"succeeded","title":"Succeeded","detail":"One call completed.","count":1},{"severity":"warning","status":"blocked","title":"Blocked locally","detail":"One preview never sent a provider request.","count":1}],"error_rows":[{"severity":"warning","status":"failed","title":"Timeout","detail":"Provider request timed out.","count":1,"provider":"openai-compatible","model":"gpt-5-mini","evidence_refs":["prompt-run:timeout"]}],"budget_hints":[{"severity":"info","title":"Monthly budget healthy","detail":"Estimated spend is below the configured budget.","value":"0.041","threshold":"25.00","recommendation":"Keep monitoring prompt-run history."}],"usage_hints":[{"severity":"info","title":"Token usage available","detail":"Estimated token totals are derived from redacted metadata.","value":"1300"}],"retention_rows":[{"severity":"info","title":"Retain metadata only","detail":"Keep redacted prompt-run metadata; do not retain raw prompts.","recommendation":"Review old metadata periodically."}],"cleanup_recommendations":[{"severity":"info","title":"No cleanup required","detail":"No unsafe raw prompt or response payloads were observed."}],"gap_notes":["No raw response bodies are available for observability by design."],"blocker_notes":[],"evidence_references":[{"title":"Prompt run history","detail":"Read from app-local prompt-runs metadata.","source":"llm.providerObservability"}],"prompt_request":{"enabled":false,"request_kind":"provider_observability","summary":"No provider request is prepared or sent by observability.","draft_copy_only":true,"redacted":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["observability did not send a provider request"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: llm.providerObservability"}}'
            ;;
          *\\"task.buildCockpit\\"*)
            if [ "$scenario" = "slow-task-cockpit" ]; then
              sleep 1
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.73","catalog_available":true,"filters":{"task":"Prepare local release audit work.","agent":"claude-code"},"summary":{"task_text":"Prepare local release audit work.","summary":"Late slow result that should be ignored after timeout or cancel.","recommended_agent":"claude-code","recommended_skill_name":"Slow Beta","readiness_score":61,"routing_score":62},"route_candidates":[{"route_id":"route-slow-beta","rank":1,"title":"Slow Beta","agent":"claude-code","routing_score":62}],"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false}}}'
            elif [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.73","catalog_available":true,"filters":{"task":"Prepare local release audit work.","agent":"claude-code","selected_skill_id":"beta","selected_skill_name":"Beta","selected_skill_agent":"claude-code","project_root":"/tmp/project","current_cwd":"/tmp/project","workspace":"Fixture Project","limit":8,"include_session_review":true,"include_provider_observability":true,"include_remediation_context":true},"summary":{"task_text":"Prepare local release audit work.","summary":"Beta is the strongest route; Codex coverage remains a gap.","route_candidate_count":2,"agent_candidate_count":1,"skill_candidate_count":1,"readiness_signal_count":1,"session_review_count":1,"provider_call_count":3,"remediation_item_count":1,"gap_count":1,"blocker_count":1,"evidence_count":1,"safety_flag_count":1,"recommended_agent":"claude-code","recommended_skill_name":"Beta","readiness_score":78,"routing_score":88},"route_candidates":[{"route_id":"route-beta","rank":1,"title":"Beta","agent":"claude-code","skill":{"instance_id":"beta","skill_name":"Beta","agent":"claude-code","definition_id":"def.beta"},"readiness_score":78,"routing_score":88,"band":"High","status":"ready","summary":"Best local match for release audit.","match_reasons":["Description matches audit work."],"evidence_refs":["route:beta"],"safety_flags":["provider not sent"]},{"route_id":"route-alpha","rank":2,"title":"Alpha","agent":"claude-code","routing_score":64,"band":"Medium","summary":"Similar audit wording."}],"agent_candidates":[{"agent_id":"agent-claude","title":"Claude Code","agent":"claude-code","score":82,"reasons":["Selected skill is enabled."]}],"skill_candidates":[{"skill_id":"beta","title":"Beta","agent":"claude-code","skill":{"instance_id":"beta","skill_name":"Beta","agent":"claude-code","definition_id":"def.beta"},"readiness_score":78,"routing_score":88}],"readiness_signals":[{"id":"readiness-beta","title":"Readiness partial","detail":"Ready for local audit, missing release-note examples.","status":"partial","count":1}],"session_review_context":[{"id":"review-1","title":"Recent session matched Beta","detail":"Latest review outcome was hit.","status":"hit","source":"session.reviewAgentSkillUse"}],"provider_observability_context":[{"id":"provider-1","title":"Provider calls observed","detail":"Three redacted call metadata rows.","count":3,"source":"llm.providerObservability"}],"remediation_context":[{"id":"plan-1","title":"Add Codex release audit coverage","detail":"Guidance only; no apply path.","severity":"medium","source":"remediation.plan"}],"gap_rows":[{"title":"Codex coverage gap","detail":"No Codex project route.","severity":"warning","agent":"codex","evidence_refs":["workspace:codex-gap"]}],"blocker_rows":[{"title":"No apply path","detail":"Cockpit only recommends review surfaces.","severity":"info"}],"evidence_references":[{"title":"Task cockpit","detail":"Derived from local readiness, routing, session, provider, and remediation metadata.","source":"task.buildCockpit","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"task_cockpit","summary":"No provider request is prepared or sent.","draft_copy_only":true,"redacted":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: task.buildCockpit"}}'
            ;;
          *\\"knowledge.groupSimilarSkills\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.53","catalog_available":true,"filters":{"agent":"claude-code","limit":20,"min_score":0.62,"include_singletons":false},"summary":{"group_count":1,"member_count":2,"duplicate_count":1,"similar_count":0,"confusable_count":0,"high_ambiguity_count":1,"coverage_redundancy_count":1,"routing_ambiguity_count":1,"summary":"Beta and Gamma overlap on audit routing."},"groups":[{"group_id":"grp-1","rank":1,"group_type":"duplicate","similarity_score":0.88,"ambiguity_risk":"high","coverage_redundancy":"substantial overlap","routing_ambiguity":"likely wrong-pick","title":"Audit release skills","summary":"Two skills cover the same audit release workflow.","why_grouped":["Same keywords and tool declarations."],"shared_terms":["audit","release"],"shared_tools":["rg"],"shared_rules":["permissions.network-declared"],"shared_capabilities":["analysis"],"shared_risks":["routing ambiguity"],"source_signals":["same project root"],"members":[{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","source_kind":"project","source_root":"project","quality_score":82,"quality_band":"Good","readiness_score":74,"readiness_band":"Partial","stale_drift_state":"fresh","reasons":["Name and purpose overlap."],"evidence_refs":["catalog:beta"],"safety_flags":["provider not sent"]}],"evidence_refs":["catalog:beta","catalog:gamma"],"safety_flags":["provider not sent"]}],"gap_notes":["No benchmark separates the two skills."],"blocker_notes":[],"evidence_references":[{"title":"Similar grouping","detail":"Beta and Gamma grouped from local catalog evidence.","source":"knowledge.groupSimilarSkills","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"similar_skill_grouping","summary":"Provider explanation is copy-only and preview-gated.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: knowledge.groupSimilarSkills"}}'
            ;;
          *\\"knowledge.buildCapabilityTaxonomy\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.54","catalog_available":true,"filters":{"agent":"claude-code","limit":20,"include_gaps":true},"summary":{"domain_count":1,"capability_count":2,"skill_count":3,"agent_count":1,"gap_count":1,"blocker_count":0,"summary":"Audit capabilities are covered but benchmark evidence is thin."},"coverage_by_agent":[{"agent":"claude-code","skill_count":3,"capability_count":2,"coverage_state":"covered","notes":["Release audit is covered."]}],"domains":[{"domain_id":"audit","name":"Audit workflows","summary":"Local audit and release review skills.","capability_count":2,"skill_count":3,"coverage_by_agent":[{"agent":"claude-code","skill_count":3,"capability_count":2,"coverage_state":"covered"}],"capabilities":[{"capability_id":"release-audit","name":"Release audit","summary":"Prepare local release audit evidence.","keywords":["audit","release"],"tools":["rg"],"rules":["permissions.network-declared"],"risk_tags":["local-only"],"representative_skills":[{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","quality_score":82,"readiness_score":74,"reasons":["Purpose maps to release audit."],"evidence_refs":["catalog:beta"],"safety_flags":["provider not sent"]}],"evidence_refs":["catalog:beta"],"safety_flags":["provider not sent"]}],"gap_notes":["No imported trace covers release audit."],"blocker_notes":[],"evidence_refs":["domain:audit"],"safety_flags":["provider not sent"]}],"gap_notes":["Codex has no equivalent audit capability."],"blocker_notes":[],"evidence_references":[{"title":"Capability taxonomy","detail":"Capabilities derived from local catalog evidence.","source":"knowledge.buildCapabilityTaxonomy","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"capability_taxonomy","summary":"Provider explanation is copy-only and preview-gated.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: knowledge.buildCapabilityTaxonomy"}}'
            ;;
          *\\"workspace.checkReadiness\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.55","catalog_available":true,"filters":{"task":"Prepare local release audit work.","agent":"claude-code","limit":40,"include_checklist":true,"include_capabilities":true},"summary":{"overall_state":"partial","readiness_score":78,"checklist_count":2,"ready_count":1,"partial_count":1,"blocked_count":0,"agent_count":2,"capability_count":2,"gap_count":1,"blocker_count":0,"summary":"Workspace is partially ready for release audit work."},"checklist_rows":[{"check_id":"release-audit","title":"Release audit skill enabled","status":"ready","severity":"info","agent":"claude-code","capability":"Release audit","summary":"Beta is enabled and project scoped.","required_skills":["Beta"],"matched_skills":[{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","quality_score":82,"readiness_score":78,"reasons":["Project-scoped audit coverage."],"evidence_refs":["catalog:beta"],"safety_flags":["provider not sent"]}],"gaps":[],"blockers":[],"evidence_refs":["catalog:beta"],"safety_flags":["provider not sent"]},{"check_id":"codex-audit","title":"Codex release audit route","status":"partial","severity":"warning","agent":"codex","capability":"Release audit","summary":"Codex lacks project-scoped coverage.","required_skills":["Release audit"],"matched_skills":[],"gaps":["No Codex project-scoped release audit skill."],"blockers":[],"evidence_refs":["catalog:gamma"],"safety_flags":["provider not sent"]}],"agent_rows":[{"agent":"claude-code","display_name":"Claude Code","readiness_score":86,"readiness_state":"ready","enabled_skill_count":3,"required_skill_count":2,"matched_skill_count":2,"gap_count":0,"blocker_count":0,"notes":["Project skills are scoped correctly."],"evidence_refs":["agent:claude-code"]},{"agent":"codex","display_name":"Codex","readiness_score":62,"readiness_state":"partial","enabled_skill_count":1,"required_skill_count":2,"matched_skill_count":1,"gap_count":1,"blocker_count":0,"notes":["No project-scoped Codex release audit skill."],"evidence_refs":["agent:codex"]}],"capability_rows":[{"capability_id":"release-audit","domain":"Release & Validation","capability":"Release audit","readiness_state":"partial","readiness_score":78,"agent_coverage":[{"agent":"claude-code","skill_count":2,"capability_count":1,"coverage_state":"covered"},{"agent":"codex","skill_count":0,"capability_count":1,"coverage_state":"gap"}],"representative_skills":[{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","readiness_score":78}],"gap_notes":["No Codex route is enabled."],"blocker_notes":[],"evidence_refs":["capability:release-audit"]}],"gap_notes":["Codex lacks a project-scoped release audit skill."],"blocker_notes":[],"evidence_references":[{"title":"Workspace readiness","detail":"Derived from local catalog evidence.","source":"workspace.checkReadiness","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"workspace_readiness","summary":"Provider explanation is copy-only and preview-gated.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: workspace.checkReadiness"}}'
            ;;
          *\\"remediation.plan\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.56","catalog_available":true,"filters":{"task":"Prepare local release audit work.","agent":"claude-code","limit":20,"include_guidance_only":true},"summary":{"total_count":2,"critical_count":0,"high_count":1,"medium_count":1,"low_count":0,"quick_win_count":1,"blocker_count":1,"gap_count":1,"ambiguity_count":1,"drift_count":1,"summary":"Review the missing Codex route before tuning duplicate audit skills."},"priority_rows":[{"id":"high","priority":"high","title":"High priority","count":1,"rationale":"Blocks release audit coverage.","evidence_refs":["workspace:codex-gap"]},{"id":"medium","priority":"medium","title":"Medium priority","count":1,"rationale":"Reduces routing ambiguity.","evidence_refs":["similar:audit"]}],"plan_items":[{"item_id":"plan-1","title":"Add Codex release audit coverage","priority":"high","category":"gap","status":"guidance_only","agent":"codex","capability":"Release audit","skill":{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","readiness_score":78},"rationale":"Workspace readiness reports no Codex project route.","suggested_action":"Open Workspace Readiness and review the Codex gap.","guidance_only":true,"next_area":"Workspace Readiness","expected_impact":"Improves cross-agent readiness for release audit tasks.","gap_notes":["Codex lacks project-scoped audit coverage."],"blocker_notes":[],"evidence_refs":["workspace:codex-gap"],"safety_flags":["provider not sent","guidance only"]},{"item_id":"plan-2","title":"Review duplicate audit wording","priority":"medium","category":"routing_ambiguity","status":"guidance_only","agent":"claude-code","capability":"Release audit","rationale":"Similar grouping found overlapping audit skills.","suggested_action":"Open Similar Skill Grouping and compare the duplicate routes.","guidance_only":true,"next_area":"Similar Skill Grouping","expected_impact":"Clarifies routing confidence without writing files.","gap_notes":[],"blocker_notes":["No automatic write/apply path is exposed."],"evidence_refs":["similar:audit"],"safety_flags":["provider not sent","guidance only"]}],"gap_notes":["Codex lacks a project-scoped release audit skill."],"blocker_notes":["No automatic write/apply path is exposed."],"evidence_references":[{"title":"Remediation planner","detail":"Derived from local workspace readiness.","source":"remediation.plan","agent":"codex"}],"prompt_request":{"enabled":false,"request_kind":"remediation_plan","summary":"Provider explanation is not sent.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent","guidance only"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: remediation.plan"}}'
            ;;
          *\\"remediation.previewDrafts\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.57","catalog_available":true,"filters":{"task":"Prepare local release audit work.","agent":"claude-code","limit":20},"summary":{"total_count":2,"frontmatter_count":1,"description_count":0,"permissions_count":1,"dependency_count":0,"policy_count":0,"blocker_count":1,"copy_only_count":2,"summary":"Two copy-only remediation drafts are available for review."},"draft_items":[{"draft_id":"draft-frontmatter","title":"Declare network permission","draft_type":"frontmatter","agent":"claude-code","affected_skill":{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","readiness_score":78},"finding_id":"finding-beta","rule_id":"permissions.network-declared","current_text":"permissions: {}","proposed_text":"permissions:\\n  network: true","rationale":"Finding reports undeclared network access.","confidence_score":82,"confidence_band":"High","copy_label":"Copy YAML","edit_guidance":"Paste into SKILL.md frontmatter after manual review.","evidence_refs":["finding:permissions.network-declared"],"blocker_notes":["Review network intent before editing."],"safety_flags":["copy only","provider not sent"]},{"draft_id":"draft-permissions","title":"Add human confirmation note","draft_type":"permissions","agent":"claude-code","affected_skill":{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","readiness_score":78},"finding_id":"finding-exec","rule_id":"permissions.exec-needs-human","current_text":"Run local commands as needed.","proposed_text":"Ask the user to confirm before running local commands.","rationale":"Execution-capable guidance must remain explicitly human-confirmed.","confidence_score":76,"confidence_band":"Medium","copy_label":"Copy sentence","edit_guidance":"Review wording in the skill body; this preview does not write files.","evidence_refs":["finding:permissions.exec-needs-human"],"blocker_notes":[],"safety_flags":["copy only","provider not sent"]}],"gap_notes":["No dependency draft needed."],"blocker_notes":["No automatic write/apply path is exposed."],"evidence_references":[{"title":"Fix preview","detail":"Derived from local findings.","source":"remediation.previewDrafts","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"remediation_preview_drafts","summary":"Provider explanation is not sent.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent","copy only"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: remediation.previewDrafts"}}'
            ;;
          *\\"remediation.previewImpact\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.58","catalog_available":true,"filters":{"task":"Prepare local release audit work.","agent":"claude-code","limit":20},"summary":{"total_count":6,"task_impact_count":1,"agent_impact_count":1,"skill_impact_count":1,"risk_delta_count":1,"snapshot_rollback_count":1,"blocker_count":1,"gap_count":1,"no_write_count":1,"summary":"Impact preview is read-only and shows where remediation would improve routing confidence."},"impact_rows":[{"row_id":"impact-overall","title":"Overall readiness improves","category":"overall","impact":"Improves release audit readiness without writing files.","rationale":"Derived from remediation plan and workspace readiness.","severity":"info","evidence_refs":["remediation:plan"],"safety_flags":["provider not sent","no write"]}],"task_impact_rows":[{"row_id":"task-release-audit","title":"Release audit route gets clearer","category":"task","before":"Partial","after":"Ready","delta":"+12 readiness","impact":"The selected task has a stronger local route.","rationale":"Routing confidence and workspace readiness both point to Beta.","severity":"medium","evidence_refs":["task:release-audit"]}],"agent_impact_rows":[{"row_id":"agent-claude","title":"Claude Code remains the recommended agent","category":"agent","agent":"claude-code","delta":"+8 comparison","impact":"No cross-agent write path is needed.","severity":"low"}],"skill_impact_rows":[{"row_id":"skill-beta","title":"Beta benefits from clearer permissions","category":"skill","agent":"claude-code","skill":{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","readiness_score":78},"impact":"The permission finding would become easier to review.","severity":"medium"}],"risk_delta_rows":[{"row_id":"risk-network","title":"Network declaration risk drops","category":"risk_delta","before":"Medium","after":"Low","delta":"-1 risk band","impact":"Manual review remains required.","severity":"warning"}],"snapshot_rollback_rows":[{"row_id":"rollback-none","title":"No snapshot is created","category":"snapshot_rollback","impact":"Rollback remains a plan note only because no write happens.","severity":"info","safety_flags":["snapshot not created"]}],"gap_notes":["Codex still lacks project-scoped coverage."],"blocker_notes":["No apply/write path is exposed."],"evidence_references":[{"title":"Impact preview","detail":"Derived from local remediation evidence.","source":"remediation.previewImpact","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"remediation_preview_impact","summary":"Provider explanation is not sent.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent","preview only","no write"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: remediation.previewImpact"}}'
            ;;
          *\\"cleanup.planGuidedFlow\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.67","catalog_available":true,"filters":{"task":"Prepare local release audit work.","agent":"claude-code","selected_skill_id":"beta","selected_skill_name":"Beta","selected_skill_agent":"claude-code","project_root":"/tmp/project","current_cwd":"/tmp/project","workspace":"Fixture Project","limit":12,"include_issue_groups":true,"include_safe_next_actions":true,"include_recorded_steps":true,"include_evidence":true,"include_safety_flags":true},"summary":{"step_count":2,"issue_group_count":1,"safe_action_count":2,"recorded_step_count":1,"recommended_step_count":1,"gap_count":1,"blocker_count":1,"summary":"Review the permission finding, inspect impact, then record local metadata."},"flow_steps":[{"step_id":"step-review-permission","title":"Review network permission finding","kind":"finding_review","status":"preview_only","priority":"high","order":1,"action_label":"Open Findings and Fix Preview Drafts","review_area":"Fix Preview Drafts","agent":"claude-code","skill":{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","readiness_score":78},"rationale":"Finding and draft preview both point to manual permission review.","detail":"No file write happens from Guided Cleanup.","recommended":true,"app_local_record_only":true,"evidence_refs":["finding:permissions.network-declared"],"gap_notes":["Codex route still lacks equivalent coverage."],"blocker_notes":["No apply/write path is exposed."],"safety_flags":["provider not sent","metadata only","no write"],"safe_entry_method":"remediation.previewDrafts","existing_safe_method":"remediation.previewDrafts","safe_action_deep_link":{"label":"Open Findings and Fix Preview Drafts","target":"analysis_action","detail_section":"analysis","method":"remediation.previewDrafts","trigger":"previewRemediationDrafts","preview_only":true,"requires_confirmation":false,"copy_only":true,"can_apply":false,"instance_ids":["beta"],"related_step_ids":["step-review-permission"],"evidence_refs":["finding:permissions.network-declared"],"safety_flags":["provider not sent","metadata only","no write"]}},{"step_id":"step-impact","title":"Inspect impact preview","kind":"impact_preview","status":"preview_only","priority":"medium","action_label":"Open Impact Preview","recommended":false,"app_local_record_only":true,"safe_entry_method":"remediation.previewImpact","existing_safe_method":"remediation.previewImpact","safe_action_deep_link":{"label":"Open Impact Preview","target":"analysis_action","detail_section":"analysis","method":"remediation.previewImpact","trigger":"previewRemediationImpact","preview_only":true,"requires_confirmation":false,"copy_only":false,"can_apply":false,"instance_ids":["beta"],"related_step_ids":["step-impact"],"evidence_refs":[],"safety_flags":["provider not sent","metadata only","no write"]}}],"issue_groups":[{"group_id":"group-permissions","title":"Permission clarity","category":"finding","severity":"high","status":"open","count":1,"summary":"One permission finding needs human review.","issue_refs":["finding:permissions.network-declared"],"safe_next_action_ids":["open-fix-preview"],"evidence_refs":["finding:permissions.network-declared"],"safety_flags":["no write"]}],"safe_next_actions":[{"action_id":"open-fix-preview","title":"Open Fix Preview Drafts","kind":"existing_safe_entry","review_area":"Fix Preview Drafts","detail":"Use the existing copy-only draft surface.","requires_existing_safe_entry":true,"app_local_only":true,"can_apply_fix":false,"evidence_refs":["draft:permissions"],"entry_method":"remediation.previewDrafts","requires_preview":true,"requires_confirmation":false,"copy_only":true,"related_step_ids":["step-review-permission"],"deep_link":{"label":"Open Fix Preview Drafts","target":"analysis_action","detail_section":"analysis","method":"remediation.previewDrafts","trigger":"previewRemediationDrafts","preview_only":true,"requires_confirmation":false,"copy_only":true,"can_apply":false,"instance_ids":["beta"],"related_step_ids":["step-review-permission"],"evidence_refs":["draft:permissions"],"safety_flags":["provider not sent","metadata only","no write"]}},{"action_id":"open-history","title":"Open Remediation History","kind":"app_local_metadata","review_area":"Remediation History","detail":"Record local audit metadata only.","requires_existing_safe_entry":true,"app_local_only":true,"can_apply_fix":false,"entry_method":"cleanup.recordGuidedStep","requires_preview":false,"requires_confirmation":true,"copy_only":false,"related_step_ids":["step-review-permission"],"deep_link":{"label":"Open Remediation History","target":"guided_metadata","detail_section":"guidedCleanup","method":"cleanup.recordGuidedStep","trigger":"recordGuidedStep","preview_only":false,"requires_confirmation":true,"copy_only":false,"can_apply":false,"instance_ids":["beta"],"related_step_ids":["step-review-permission"],"evidence_refs":[],"safety_flags":["provider not sent","metadata only","no write"]}}],"recorded_steps":[{"record_id":"guided-record-1","step_id":"step-review-permission","title":"Permission review recorded","status":"recorded","decision":"reviewed","source_method":"cleanup.recordGuidedStep","recorded_at":"2026-06-12T08:00:00Z","note":"Metadata only.","metadata_redacted":true,"app_local_only":true,"evidence_refs":["guided_step:step-review-permission"],"safety_flags":["app-local metadata only","no write"]}],"gap_notes":["Codex lacks project-scoped release audit coverage."],"blocker_notes":["Actual edits remain in existing preview-first flows."],"evidence_references":[{"title":"Guided cleanup","detail":"Derived from local cleanup/remediation evidence.","source":"cleanup.planGuidedFlow","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"guided_cleanup_flow","summary":"No provider request is prepared or sent.","draft_copy_only":true,"redacted":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent","planning read-only"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: cleanup.planGuidedFlow"}}'
            ;;
          *\\"cleanup.recordGuidedStep\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"recorded":true,"generated_by":"local-v2.67","app_local_only":true,"metadata_redacted":true,"record":{"record_id":"guided-record-native","step_id":"step-review-permission","title":"Native guided cleanup metadata","status":"recorded","decision":"reviewed","source_method":"analysis.guidedCleanupFlow.ui","recorded_at":"2026-06-12T08:05:00Z","note":"Recorded app-local metadata only; no cleanup was applied.","metadata_redacted":true,"app_local_only":true,"evidence_refs":["guided_step:step-review-permission"],"safety_flags":["app-local metadata only","no write","provider not sent"]},"summary":{"recorded_step_count":1,"summary":"Recorded one guided cleanup step."},"message":"Guided cleanup metadata recorded.","evidence_references":[{"title":"Guided record","detail":"Stored app-local metadata only.","source":"cleanup.recordGuidedStep"}],"prompt_request":{"enabled":false,"request_kind":"guided_cleanup_record","summary":"No provider request is sent.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["app-local metadata only","no write"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: cleanup.recordGuidedStep"}}'
            ;;
          *\\"remediation.batchReview\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.59","catalog_available":true,"filters":{"task":"Prepare local release audit work.","agent":"claude-code","limit":30,"review_dimensions":["task","risk","rule","agent","workspace"],"risk_levels":["medium","high"],"rule_ids":["permissions.network-declared"],"include_blocked":true},"summary":{"total_count":3,"group_count":2,"task_count":1,"risk_count":1,"rule_count":1,"agent_count":1,"workspace_count":1,"blocker_count":1,"gap_count":1,"safe_next_step_count":2,"summary":"Batch review groups remediation candidates before any write-capable flow."},"review_groups":[{"group_id":"risk-rules","title":"Risk and rule review","category":"risk_rule","priority":"high","summary":"Review permission findings before any manual edit.","safe_next_step_labels":["Open Findings","Open Fix Preview Drafts"],"items":[{"item_id":"rule-network","title":"Network permission declaration","category":"rule","priority":"high","status":"preview_only","agent":"claude-code","workspace":"Fixture Project","rule_id":"permissions.network-declared","risk_level":"medium","task_text":"Prepare local release audit work.","skill":{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","readiness_score":78},"rationale":"Finding and draft preview both point to manual permission review.","safe_next_step_label":"Open Fix Preview Drafts","review_area":"Fix Preview Drafts","evidence_refs":["finding:permissions.network-declared"],"gap_notes":["Codex route still lacks equivalent coverage."],"blocker_notes":["No apply/write path is exposed."],"safety_flags":["provider not sent","preview only","no write"]}],"evidence_refs":["finding:permissions.network-declared"],"gap_notes":["Codex route still lacks equivalent coverage."],"blocker_notes":["No apply/write path is exposed."],"safety_flags":["preview only"]}],"review_items":[{"item_id":"workspace-codex","title":"Codex workspace gap","category":"workspace","priority":"medium","status":"preview_only","agent":"codex","workspace":"Fixture Project","rationale":"Workspace readiness reports a partial Codex route.","safe_next_step_label":"Open Workspace Readiness","review_area":"Workspace Readiness","evidence_refs":["workspace:codex-gap"]}],"safe_next_step_labels":["Open Remediation Planner","Open Impact Preview"],"gap_notes":["Codex lacks project-scoped release audit coverage."],"blocker_notes":["No batch apply path is available from review."],"evidence_references":[{"title":"Batch review","detail":"Derived from local remediation evidence.","source":"remediation.batchReview","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"remediation_batch_review","summary":"Provider explanation is not sent.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent","preview only","no write"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: remediation.batchReview"}}'
            ;;
          *\\"remediation.listHistory\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.60","catalog_available":true,"filters":{"task":"Prepare local release audit work.","agent":"claude-code","limit":30,"rule_ids":["permissions.network-declared"],"risk_levels":["medium"],"decisions":["reviewed"],"statuses":["recorded"]},"summary":{"total_count":2,"recorded_count":2,"recurrence_count":1,"reopened_count":1,"readiness_improvement_count":1,"decision_count":1,"status_count":1,"blocker_count":1,"gap_count":1,"summary":"Local remediation history shows one recurring permission review and one readiness improvement."},"records":[{"record_id":"hist-network","title":"Network permission reviewed","category":"rule","decision":"reviewed","status":"recorded","agent":"claude-code","workspace":"Fixture Project","rule_id":"permissions.network-declared","risk_level":"medium","task_text":"Prepare local release audit work.","review_area":"Fix Preview Drafts","source_method":"remediation.previewDrafts","skill":{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","readiness_score":78},"recurrence_count":1,"reopened_count":1,"readiness_improvement":"+8 readiness","recorded_at":"2026-06-12T08:00:00Z","rationale":"Finding and copy-only draft were reviewed locally.","note":"Audit-only record; no remediation was applied.","evidence_refs":["finding:permissions.network-declared"],"gap_notes":["Codex route still lacks equivalent coverage."],"blocker_notes":["No apply/write path is exposed."],"safety_flags":["local audit only","no write","provider not sent"]}],"decisions":["reviewed"],"statuses":["recorded"],"gap_notes":["Workspace gap remains visible."],"blocker_notes":["No direct write/apply path is exposed."],"evidence_references":[{"title":"History","detail":"Derived from app-local remediation audit records.","source":"remediation.listHistory","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"remediation_history","summary":"Provider explanation is not sent.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["app-local history","provider not sent","no write"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: remediation.listHistory"}}'
            ;;
          *\\"remediation.recordHistory\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"recorded":true,"record":{"record_id":"hist-native-audit","title":"Native Analysis local audit","category":"audit","decision":"reviewed","status":"recorded","agent":"claude-code","workspace":"Fixture Project","task_text":"Prepare local release audit work.","review_area":"Remediation History","source_method":"analysis.remediationHistory.ui","skill":{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","readiness_score":78},"recorded_at":"2026-06-12T08:05:00Z","rationale":"User recorded local remediation audit metadata from native Analysis.","note":"Recorded app-local audit metadata only; no remediation was applied.","evidence_refs":["selected_skill:beta"],"safety_flags":["local audit only","no write","provider not sent"]},"summary":{"total_count":1,"recorded_count":1,"summary":"Recorded one local remediation audit entry."},"message":"Local remediation history recorded.","evidence_references":[{"title":"History record","detail":"Stored app-local audit metadata only.","source":"remediation.recordHistory","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"remediation_history_record","summary":"Provider explanation is not sent.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["app-local history","provider not sent","no write"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: remediation.recordHistory"}}'
            ;;
          *\\"task.listBenchmarks\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"benchmarks":[{"benchmark_id":"bench-1","task_text":"Route a local audit task.","expected_skill":{"instance_id":"beta","name":"Beta","agent":"claude-code"},"acceptable_skills":[{"instance_id":"beta","name":"Beta","agent":"claude-code"},{"instance_id":"alpha","name":"Alpha","agent":"claude-code"}]}]}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: task.listBenchmarks"}}'
            ;;
          *\\"task.saveBenchmark\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"benchmark":{"benchmark_id":"bench-2","task_text":"Route a local audit release note task.","expected_skill":{"instance_id":"beta","name":"Beta","agent":"claude-code"},"acceptable_skills":[{"instance_id":"beta","name":"Beta","agent":"claude-code"}]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: task.saveBenchmark"}}'
            ;;
          *\\"task.evaluateBenchmarks\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"evaluated_count":2,"matched_count":1,"acceptable_count":2,"average_score":82,"evaluations":[{"benchmark_id":"bench-2","task":"Route a local audit release note task.","match_status":"matched","top_route":{"instance_id":"beta","name":"Beta","agent":"claude-code","confidence_score":88,"band":"High","match_reasons":["Description matches local audit."]},"expected_covered":true,"acceptable_covered":true,"blockers":[],"gaps":["No release-note-specific examples."],"safety_flags":["provider not sent"],"evidence_references":[{"title":"Routing","detail":"Beta ranked first.","source":"local"}]},{"benchmark_id":"bench-1","task":"Route a local audit task.","match_status":"acceptable","top_route":{"instance_id":"alpha","name":"Alpha","agent":"claude-code","confidence_score":76,"band":"Medium","match_reasons":["Same-agent fallback."]},"expected_covered":false,"acceptable_covered":true,"blockers":[],"gaps":[],"safety_flags":["provider not sent"],"evidence":["Alpha is acceptable."]}],"blockers":[],"gaps":["One benchmark missed exact expected route."],"evidence_references":[{"title":"Benchmark","detail":"Two local tasks evaluated.","source":"task.evaluateBenchmarks"}],"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_secret_returned":false}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: task.evaluateBenchmarks"}}'
            ;;
          *\\"task.saveRoutingBaseline\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"baseline_id":"baseline-1","benchmark_count":1,"average_score":88,"matched_count":1,"acceptable_count":1,"summary":"Saved local routing baseline from current benchmarks.","safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_secret_returned":false}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: task.saveRoutingBaseline"}}'
            ;;
          *\\"task.detectRoutingRegression\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"baseline_id":"baseline-1","benchmark_count":1,"regression_count":1,"improved_count":0,"unchanged_count":0,"average_score_delta":-16,"match_status_changed_count":1,"top_route_changed_count":1,"regressions":[{"benchmark_id":"bench-1","task":"Route a local audit task.","regression_type":"expected_to_acceptable","previous_match_status":"matched","current_match_status":"acceptable","previous_score":88,"current_score":72,"score_delta":-16,"previous_top_route":{"instance_id":"beta","name":"Beta","agent":"claude-code","confidence_score":88,"band":"High"},"current_top_route":{"instance_id":"alpha","name":"Alpha","agent":"claude-code","confidence_score":72,"band":"Medium"},"top_route_changed":true,"new_blockers":["Expected route dropped below top rank."],"new_gaps":["Release-note examples still missing."],"safety_flags":["provider not sent"],"evidence_references":[{"title":"Regression","detail":"Top route changed from Beta to Alpha.","source":"task.detectRoutingRegression"}]}],"new_blockers":["Expected route dropped below top rank."],"new_gaps":["Release-note examples still missing."],"evidence_references":[{"title":"Baseline","detail":"Compared against baseline-1.","source":"task.detectRoutingRegression"}],"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_secret_returned":false}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: task.detectRoutingRegression"}}'
            ;;
          *\\"routing.accuracyDashboard\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.49","catalog_available":true,"filters":{"agent":"claude-code","window_days":30,"limit":20,"include_history":true,"include_recent_evidence":true},"summary":{"trace_count":11,"hit_count":7,"miss_count":2,"wrong_pick_count":1,"ambiguous_count":1,"unknown_count":0,"benchmark_count":5,"benchmark_matched_count":4,"benchmark_gap_count":3,"regression_count":1,"missing_benchmark_count":2,"accuracy_rate":0.636,"known_outcome_rate":1.0,"summary":"Seven of eleven imported traces hit the expected route."},"agent_rows":[{"agent":"claude-code","trace_count":11,"outcomes":{"hit":7,"miss":2,"wrong_pick":1,"ambiguous":1,"unknown":0},"accuracy_rate":0.636,"benchmark_count":5,"benchmark_matched_count":4,"benchmark_gap_count":3,"regression_count":1,"recent_evidence_count":2,"notes":["One expected route has no benchmark."]}],"history_rows":[{"unix_day":1781136000,"trace_count":11,"outcomes":{"hit":7,"miss":2,"wrong_pick":1,"ambiguous":1,"unknown":0},"accuracy_rate":0.636}],"gap_issue_rows":[{"source":"trace","severity":"warning","agent":"openclaw","title":"Missing trace coverage","detail":"No OpenClaw traces in the selected window.","evidence_refs":["trace:none"]}],"recent_evidence_rows":[{"source":"trace.importLocal","agent":"claude-code","title":"Trace","outcome":"hit","detail":"Beta matched expected route in trace-1.","evidence_refs":["trace-1"],"observed_at":1781136000000}],"blocker_notes":["One expected route has no benchmark."],"prompt_request":{"enabled":false,"request_kind":"routing_accuracy","summary":"Provider explanation is copy-only and preview-gated.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"script_execution_allowed":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: routing.accuracyDashboard"}}'
            ;;
          *\\"analysis.detectStaleDrift\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.51","catalog_available":true,"filters":{"agent":"claude-code","limit":40,"include_readiness_impact":true},"summary":{"stale_count":2,"drift_count":1,"candidate_count":3,"affected_agent_count":2,"readiness_impact_count":1,"gap_issue_count":1,"high_risk_count":1,"summary":"Beta appears stale and Gamma has routing drift evidence."},"stale_drift_rows":[{"id":"stale-beta","kind":"stale","severity":"warning","agent":"claude-code","skill":{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","scope":"agent-project","state":"loaded","enabled":true},"title":"Beta appears stale","summary":"Beta has not appeared in recent trace or benchmark evidence.","last_seen":"2026-05-01","current_signal":"No recent trace hits.","expected_signal":"Expected route remains Beta.","confidence":82,"reasons":["No trace hits in the current window."],"signals":["Benchmark age exceeds threshold."],"evidence_refs":["catalog:beta","trace:none"]},{"id":"drift-gamma","kind":"drift","severity":"medium","agent":"codex","skill":{"instance_id":"gamma","definition_id":"codex:gamma","skill_name":"Gamma","scope":"agent-global","state":"loaded","enabled":true},"title":"Gamma routing drift","summary":"Imported trace wording no longer matches benchmark expectations.","current_signal":"Trace selected Gamma for a task that used to route to Beta.","expected_signal":"Benchmark expected Beta.","confidence":74,"reasons":["Top route changed in regression evidence."],"signals":["Regression baseline changed."],"evidence_refs":["regression:bench-1"]}],"readiness_impact_rows":[{"agent":"claude-code","skill_name":"Beta","severity":"warning","title":"Readiness lowered","detail":"Readiness is partial because evidence is stale.","evidence_refs":["readiness:beta"]}],"gap_issue_rows":[{"source":"trace","severity":"warning","agent":"claude-code","title":"Missing fresh evidence","detail":"No fresh trace confirms the expected route.","evidence_refs":["trace:none"]}],"evidence_references":[{"title":"Catalog freshness","detail":"Beta fingerprint is unchanged but not recently exercised.","source":"catalog","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"stale_drift_detection","summary":"Provider explanation is copy-only and preview-gated.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: analysis.detectStaleDrift"}}'
            ;;
          *\\"task.deleteBenchmark\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"deleted":true,"benchmark_id":"bench-1"}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: task.deleteBenchmark"}}'
            ;;
          *\\"trace.listImports\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"records":[{"import_id":"trace-1","title":"Existing local trace","task":"Route a local audit task.","outcome":"hit","detected_skills":[{"instance_id":"beta","name":"Beta","agent":"claude-code"}],"expected_skill_names":["Beta"],"redacted_excerpt":"Assistant selected Beta from <project-root> evidence.","redaction_summary":{"status":"redacted","summary":"Local paths removed.","placeholders":["<project-root>"]},"reasons":["Detected skill matched expected skill."],"evidence_references":[{"title":"Trace","detail":"Beta appeared in route selection.","source":"trace.listImports"}],"safety_flags":["provider not sent"],"safety":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_secret_returned":false}}]}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: trace.listImports"}}'
            ;;
          *\\"trace.importLocal\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"record":{"import_id":"trace-2","title":"Local trace","task":"Route a local audit release note task.","outcome":"wrong_pick","detected_skill_names":["Alpha"],"expected_skills":[{"instance_id":"beta","name":"Beta","agent":"claude-code"}],"redacted_excerpt":"User asked for <project-root> release notes. Assistant selected Alpha.","redaction_summary":{"status":"redacted","summary":"Secrets and local paths removed.","redacted_fields":["path"],"placeholders":["<project-root>"]},"reasons":["Detected route differs from expected skill."],"evidence_references":[{"title":"Trace","detail":"Alpha appeared in route selection.","source":"trace.importLocal"}],"safety_flags":["provider not sent"],"safety":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_secret_returned":false}}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: trace.importLocal"}}'
            ;;
          *\\"trace.deleteImport\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"deleted":true,"import_id":"trace-1"}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: trace.deleteImport"}}'
            ;;
          *\\"llm.prepareAction\\"*)
            if [ "$scenario" = "old-service" ]; then
              respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: llm.prepareAction"}}'
            elif [ "$scenario" = "llm-ready" ] || [ "$scenario" = "prompt-ready" ]; then
              case "$input" in
                *\\"kind\\":\\"draft_frontmatter\\"*)
                  respond '{"id":"test","ok":true,"result":{"action":"draft_frontmatter","enabled":true,"disabled_reason":null,"provider":"openai","model":"gpt-5","estimate":{"input_tokens":240,"output_tokens":180,"total_tokens":420,"estimated_cost_usd":0.0042},"confirmation_required":true}}'
                  ;;
                *)
                  respond '{"id":"test","ok":true,"result":{"action":"analyze","enabled":true,"disabled_reason":null,"provider":"openai","model":"gpt-5","estimate":{"input_tokens":240,"output_tokens":120,"total_tokens":360,"estimated_cost_usd":0.0042},"confirmation_required":true}}'
                  ;;
              esac
            else
              respond '{"id":"test","ok":true,"result":{"action":"analyze","enabled":false,"disabled_reason":"LLM is disabled.","provider":null,"model":null,"estimate":null,"confirmation_required":true}}'
            fi
            ;;
          *\\"llm.previewPrompt\\"*)
            if [ "$scenario" = "prompt-ready" ] || [ "$scenario" = "slow-task-cockpit" ]; then
              if printf '%s' "$input" | grep -q '\\"request_kind\\":\\"task_cockpit\\"'; then
                respond '{"id":"test","ok":true,"result":{"preview_id":"task-cockpit-preview","request_kind":"task_cockpit","action":"task_cockpit","scope":"agents","prompt_scope":"Task preflight for selected agents","enabled":true,"provider":"openai-compatible","model":"gpt-5","destination_host":"llm.example.com","included_fields":["task.text","agents","effective_skills"],"excluded_fields":[{"name":"skill.body","reason":"raw body omitted"},{"name":"agent.config","reason":"config contents omitted"},{"name":"api_key","reason":"credential redacted"}],"redaction":{"status":"redacted","summary":"Secrets, raw bodies, config contents, and local paths removed.","redacted_fields":["api_key","path","skill.body","agent.config"],"placeholders":["<project-root>"]},"estimate":{"input_tokens":520,"output_tokens":240,"total_tokens":760,"estimated_cost_usd":0.008},"confirmation_required":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"draft_copy_only":true,"redacted_prompt_preview":"Task preflight from selected agent and effective skill metadata."}}'
              fi
            fi
            if [ "$scenario" = "prompt-ready" ]; then
              if printf '%s' "$input" | grep -q '\\"request_kind\\":\\"routing_confidence\\"'; then
                respond '{"id":"test","ok":true,"result":{"preview_id":"routing-preview-beta","request_kind":"routing_confidence","action":"routing_confidence","scope":"selected","prompt_scope":"Selected skill routing confidence for Beta","enabled":true,"provider":"openai-compatible","model":"gpt-5","destination_host":"llm.example.com","included_fields":["task.text","skill.metadata","routing.result","analysis.comparison"],"excluded_fields":[{"name":"api_key","reason":"credential redacted"},{"name":"skill.body","reason":"raw body omitted"}],"redaction":{"status":"redacted","summary":"Secrets, raw body, and local paths removed.","redacted_fields":["api_key","path"],"placeholders":["<project-root>"]},"estimate":{"input_tokens":360,"output_tokens":170,"total_tokens":530,"estimated_cost_usd":0.0065},"confirmation_required":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"draft_copy_only":true,"redacted_prompt_preview":"Explain routing confidence for Beta from redacted local evidence."}}'
              fi
              if printf '%s' "$input" | grep -q '\\"request_kind\\":\\"task_readiness\\"'; then
                respond '{"id":"test","ok":true,"result":{"preview_id":"readiness-preview-beta","request_kind":"task_readiness","action":"task_readiness","scope":"selected","prompt_scope":"Selected skill task readiness for Beta","enabled":true,"provider":"openai-compatible","model":"gpt-5","destination_host":"llm.example.com","included_fields":["task.text","skill.metadata","readiness.result","findings.summary"],"excluded_fields":[{"name":"api_key","reason":"credential redacted"},{"name":"skill.body","reason":"raw body omitted"}],"redaction":{"status":"redacted","summary":"Secrets, raw body, and local paths removed.","redacted_fields":["api_key","path"],"placeholders":["<project-root>"]},"estimate":{"input_tokens":340,"output_tokens":160,"total_tokens":500,"estimated_cost_usd":0.006},"confirmation_required":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"draft_copy_only":true,"redacted_prompt_preview":"Explain task readiness for Beta from redacted local evidence."}}'
              fi
              if printf '%s' "$input" | grep -q '\\"request_kind\\":\\"quality_score\\"'; then
                respond '{"id":"test","ok":true,"result":{"preview_id":"quality-preview-beta","request_kind":"quality_score","action":"quality_score","scope":"selected","prompt_scope":"Selected skill quality score for Beta","enabled":true,"provider":"openai-compatible","model":"gpt-5","destination_host":"llm.example.com","included_fields":["skill.metadata","findings.summary","conflicts.summary","adapter.diagnostics"],"excluded_fields":[{"name":"skill.body","reason":"raw body omitted"},{"name":"api_key","reason":"credential redacted"}],"redaction":{"status":"redacted","summary":"Secrets, raw body, and local paths removed.","redacted_fields":["api_key","path"],"placeholders":["<project-root>"]},"estimate":{"input_tokens":300,"output_tokens":140,"total_tokens":440,"estimated_cost_usd":0.005},"confirmation_required":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"draft_copy_only":true,"redacted_prompt_preview":"Score Beta quality from redacted local evidence."}}'
              fi
              respond '{"id":"test","ok":true,"result":{"preview_id":"prompt-preview-beta","request_kind":"action","action":"analyze","scope":"selected","prompt_scope":"Selected skill analysis for Beta","enabled":true,"provider":"openai-compatible","model":"gpt-5","destination_host":"llm.example.com","included_fields":["skill.name","findings.summary"],"excluded_fields":[{"name":"api_key","reason":"credential redacted"}],"redaction":{"status":"redacted","summary":"Secrets and local paths removed.","redacted_fields":["api_key"],"placeholders":["<project-root>"]},"estimate":{"input_tokens":240,"output_tokens":120,"total_tokens":360,"estimated_cost_usd":0.0042},"confirmation_required":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"draft_copy_only":true,"redacted_prompt_preview":"Analyze Beta using catalog metadata and finding summaries only."}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: llm.previewPrompt"}}'
            ;;
          *\\"llm.confirmPromptAndSend\\"*)
            if [ "$scenario" = "slow-task-cockpit" ]; then
              if printf '%s' "$input" | grep -q '\\"request_kind\\":\\"task_cockpit\\"'; then
                sleep 1
                respond '{"id":"test","ok":true,"result":{"preview_id":"task-cockpit-preview","status":"succeeded","message":"Provider response received.","output_text":"{\\"generated_by\\":\\"provider-task-cockpit\\",\\"catalog_available\\":true,\\"filters\\":{\\"task_text\\":\\"Prepare local release audit work.\\",\\"agents\\":[\\"claude-code\\"]},\\"summary\\":{\\"task_text\\":\\"Prepare local release audit work.\\",\\"summary\\":\\"Late slow result that should be ignored after timeout or cancel.\\",\\"recommended_agent\\":\\"claude-code\\",\\"recommended_skill_name\\":\\"Slow Beta\\",\\"readiness_score\\":61,\\"routing_score\\":62,\\"agent_candidate_count\\":1,\\"skill_candidate_count\\":1,\\"gap_count\\":0,\\"blocker_count\\":0},\\"agent_candidates\\":[{\\"id\\":\\"agent-claude\\",\\"rank\\":1,\\"title\\":\\"Claude Code\\",\\"agent\\":\\"claude-code\\",\\"score\\":62}],\\"skill_candidates\\":[{\\"id\\":\\"skill:beta\\",\\"rank\\":1,\\"title\\":\\"Slow Beta\\",\\"agent\\":\\"claude-code\\",\\"skill\\":{\\"instance_id\\":\\"beta\\",\\"name\\":\\"Slow Beta\\",\\"agent\\":\\"claude-code\\",\\"definition_id\\":\\"def.beta\\"},\\"routing_score\\":62,\\"readiness_score\\":61}],\\"safety_flags\\":{\\"provider_request_sent\\":true,\\"write_back_allowed\\":false,\\"script_execution_allowed\\":false,\\"raw_prompt_persisted\\":false,\\"raw_response_persisted\\":false}}","draft_copy_only":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"write_back_allowed":false,"script_execution_allowed":false,"audit_metadata":{"request_id":"audit-task-cockpit-slow","status":"succeeded","provider":"openai-compatible","model":"gpt-5","destination_host":"llm.example.com","redaction_applied":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"input_tokens":520,"output_tokens":180}}}'
              fi
            fi
            if [ "$scenario" = "prompt-ready" ]; then
              if printf '%s' "$input" | grep -q '\\"request_kind\\":\\"task_cockpit\\"'; then
                respond '{"id":"test","ok":true,"result":{"preview_id":"task-cockpit-preview","status":"succeeded","message":"Provider response received.","output_text":"{\\"generated_by\\":\\"provider-task-cockpit\\",\\"catalog_available\\":true,\\"filters\\":{\\"task_text\\":\\"Prepare local release audit work.\\",\\"agents\\":[\\"claude-code\\"]},\\"summary\\":{\\"task_text\\":\\"Prepare local release audit work.\\",\\"summary\\":\\"Beta is the strongest provider-ranked route; confirm handoff boundaries.\\",\\"recommended_agent\\":\\"claude-code\\",\\"recommended_skill_name\\":\\"Beta\\",\\"readiness_score\\":78,\\"routing_score\\":88,\\"agent_candidate_count\\":1,\\"skill_candidate_count\\":2,\\"gap_count\\":1,\\"blocker_count\\":0},\\"agent_candidates\\":[{\\"id\\":\\"agent-claude\\",\\"rank\\":1,\\"title\\":\\"Claude Code\\",\\"agent\\":\\"claude-code\\",\\"score\\":82,\\"summary\\":\\"Selected agent has enabled matching skills.\\",\\"reasons\\":[\\"Effective skills include Beta.\\"]}],\\"skill_candidates\\":[{\\"id\\":\\"skill:beta\\",\\"rank\\":1,\\"title\\":\\"Beta\\",\\"agent\\":\\"claude-code\\",\\"skill\\":{\\"instance_id\\":\\"beta\\",\\"name\\":\\"Beta\\",\\"agent\\":\\"claude-code\\",\\"definition_id\\":\\"def.beta\\"},\\"readiness_score\\":78,\\"routing_score\\":88,\\"summary\\":\\"Best match for release audit.\\",\\"reasons\\":[\\"Description matches audit work.\\"]},{\\"id\\":\\"skill:alpha\\",\\"rank\\":2,\\"title\\":\\"Alpha\\",\\"agent\\":\\"claude-code\\",\\"skill\\":{\\"instance_id\\":\\"alpha\\",\\"name\\":\\"Alpha\\",\\"agent\\":\\"claude-code\\",\\"definition_id\\":\\"def.alpha\\"},\\"routing_score\\":64,\\"summary\\":\\"Similar audit wording.\\"}],\\"readiness_signals\\":[{\\"id\\":\\"readiness-beta\\",\\"title\\":\\"Provider readiness\\",\\"detail\\":\\"Ready for local audit, confirm handoff boundary.\\",\\"status\\":\\"review\\",\\"agent\\":\\"claude-code\\"}],\\"gap_rows\\":[{\\"id\\":\\"gap-codex\\",\\"title\\":\\"Codex coverage not selected\\",\\"detail\\":\\"Selected scope only includes Claude Code.\\",\\"severity\\":\\"info\\",\\"agent\\":\\"codex\\"}],\\"blocker_rows\\":[],\\"safety_flags\\":{\\"provider_request_sent\\":true,\\"write_back_allowed\\":false,\\"write_actions_available\\":false,\\"script_execution_allowed\\":false,\\"execution_actions_available\\":false,\\"config_mutation_allowed\\":false,\\"snapshot_created\\":false,\\"triage_mutation_allowed\\":false,\\"credential_accessed\\":false,\\"raw_prompt_persisted\\":false,\\"raw_response_persisted\\":false,\\"raw_trace_persisted\\":false,\\"cloud_sync_enabled\\":false,\\"telemetry_enabled\\":false,\\"raw_secret_returned\\":false,\\"notes\\":[\\"copy-only recommendation\\"]}}","draft_copy_only":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"write_back_allowed":false,"script_execution_allowed":false,"audit_metadata":{"request_id":"audit-task-cockpit-1","status":"succeeded","provider":"openai-compatible","model":"gpt-5","destination_host":"llm.example.com","redaction_applied":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"input_tokens":520,"output_tokens":180}}}'
              fi
              if printf '%s' "$input" | grep -q '\\"request_kind\\":\\"routing_confidence\\"'; then
                respond '{"id":"test","ok":true,"result":{"preview_id":"routing-preview-beta","status":"succeeded","message":"Provider response received.","output_text":"Copy-only routing confidence explanation for Beta.","draft_copy_only":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"write_back_allowed":false,"script_execution_allowed":false,"audit_metadata":{"request_id":"audit-routing-1","status":"succeeded","provider":"openai-compatible","model":"gpt-5","destination_host":"llm.example.com","redaction_applied":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"input_tokens":360,"output_tokens":100}}}'
              fi
              if printf '%s' "$input" | grep -q '\\"request_kind\\":\\"task_readiness\\"'; then
                respond '{"id":"test","ok":true,"result":{"preview_id":"readiness-preview-beta","status":"succeeded","message":"Provider response received.","output_text":"Copy-only task readiness explanation for Beta.","draft_copy_only":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"write_back_allowed":false,"script_execution_allowed":false,"audit_metadata":{"request_id":"audit-readiness-1","status":"succeeded","provider":"openai-compatible","model":"gpt-5","destination_host":"llm.example.com","redaction_applied":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"input_tokens":340,"output_tokens":95}}}'
              fi
              if printf '%s' "$input" | grep -q '\\"request_kind\\":\\"quality_score\\"'; then
                respond '{"id":"test","ok":true,"result":{"preview_id":"quality-preview-beta","status":"succeeded","message":"Provider response received.","output_text":"Copy-only quality explanation for Beta.","draft_copy_only":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"write_back_allowed":false,"script_execution_allowed":false,"audit_metadata":{"request_id":"audit-quality-1","status":"succeeded","provider":"openai-compatible","model":"gpt-5","destination_host":"llm.example.com","redaction_applied":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"input_tokens":300,"output_tokens":90}}}'
              fi
              respond '{"id":"test","ok":true,"result":{"preview_id":"prompt-preview-beta","status":"succeeded","message":"Provider response received.","output_text":"Read-only analysis for Beta.","draft_copy_only":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"write_back_allowed":false,"script_execution_allowed":false,"audit_metadata":{"request_id":"audit-prompt-1","status":"succeeded","provider":"openai-compatible","model":"gpt-5","destination_host":"llm.example.com","redaction_applied":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"input_tokens":240,"output_tokens":80}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: llm.confirmPromptAndSend"}}'
            ;;
          *\\"script.previewExecution\\"*)
            if [ "$scenario" = "script-preview" ]; then
              respond '{"id":"test","ok":true,"result":{"instance_id":"beta","script_name":"setup","command_preview":["bash","scripts/setup.sh"],"scope":{"current_cwd":"/tmp/project","env":{"SKILLS_SAFE_MODE":"1"},"network":"none","files":["/tmp/project/scripts/setup.sh"]},"risks":["Writes are blocked by default."],"requires_confirmation":true,"execution_allowed":false,"audit_status":"blocked","audit_id":"audit-1","summary":"Blocked until confirmed.","reason":"Native UI is preview-only."}}'
            else
              respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: script.previewExecution"}}'
            fi
            ;;
          *\\"batch.previewSkillToggles\\"*)
            if [ "$scenario" = "batch-mixed" ]; then
              respond '{"id":"test","ok":true,"result":{"preview_id":"batch-preview-1","action":"disable","target_enabled":false,"selected_count":4,"writable_count":2,"skipped_count":2,"affected_skills":[{"instance_id":"alpha","name":"Alpha","agent":"claude-code","scope":"agent-global","display_path":"/tmp/global/alpha/SKILL.md","current_enabled":true,"target_enabled":false},{"instance_id":"gamma","name":"Gamma","agent":"codex","scope":"agent-global","display_path":"~/.codex/skills/gamma/SKILL.md","current_enabled":true,"target_enabled":false}],"skipped_items":[{"instance_id":"beta","name":"Beta","agent":"claude-code","scope":"agent-project","display_path":"/tmp/project/beta/SKILL.md","current_enabled":false,"target_enabled":false,"reason":"Already disabled"},{"instance_id":"pi-one","name":"Pi One","agent":"pi","scope":"agent-global","display_path":"~/.pi/skills/pi-one/SKILL.md","current_enabled":true,"target_enabled":false,"reason":"Pi is read-only."}],"snapshot_plan":{"summary":"Create config snapshots for Claude Code and Codex before applying; rollback uses existing agent-config timeline.","rollback_supported":true,"targets":["/tmp/home/.claude/settings.json","/tmp/home/.codex/config.toml"]},"apply_supported":true}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: batch.previewSkillToggles"}}'
            ;;
          *\\"batch.applySkillToggles\\"*)
            if [ "$scenario" = "batch-mixed" ]; then
              respond '{"id":"test","ok":true,"result":{"updated_count":2,"skipped_count":2,"snapshot_ids":["snap-claude-new","snap-codex"]}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: batch.applySkillToggles"}}'
            ;;
          *\\"report.exportLocal\\"*)
            if [ "$scenario" = "report-export" ]; then
              respond '{"id":"test","ok":true,"result":{"export_id":"local-report-test","generated_at":1780590000000,"output_dir":"<app-data-dir>/report-exports/local-report-test","files":[{"format":"json","path":"<app-data-dir>/report-exports/local-report-test/report.json"}],"catalog_available":true,"summary":{"skill_count":2,"finding_count":1,"open_finding_count":1,"triage_count":0,"cleanup_item_count":1,"comparison_group_count":0},"redaction":{"enabled":true,"placeholders":["$HOME","<project-root>","<project-cwd>","<app-data-dir>"],"path_policy":"Local paths are redacted."},"read_only":true,"writes_allowed":false,"provider_request_sent":false,"script_execution_allowed":false,"credential_accessed":false}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: report.exportLocal"}}'
            ;;
          *\\"catalog.listSkills\\"*)
            if [ "$scenario" = "empty" ]; then
              respond '{"id":"test","ok":true,"result":[]}'
            elif [ "$scenario" = "toggle-disabled" ]; then
              respond '{"id":"test","ok":true,"result":'"$skills_toggled"'}'
            elif [ "$scenario" = "toggle-codex-disabled" ]; then
              respond '{"id":"test","ok":true,"result":'"$skills_codex_toggled"'}'
            elif [ "$scenario" = "opencode" ]; then
              if grep -q '"method":"config.toggleSkill"' "$SKILLS_COPILOT_FAKE_SERVICE_CALLS"; then
                respond '{"id":"test","ok":true,"result":'"$skills_opencode_toggled"'}'
              else
                respond '{"id":"test","ok":true,"result":'"$skills_opencode"'}'
              fi
            elif [ "$scenario" = "tool-global" ]; then
              respond '{"id":"test","ok":true,"result":'"$skills_toolglobal"'}'
            elif [ "$scenario" = "batch-mixed" ]; then
              respond '{"id":"test","ok":true,"result":'"$skills_batch_mixed"'}'
            else
              respond '{"id":"test","ok":true,"result":'"$skills_normal"'}'
            fi
            ;;
          *\\"catalog.scanAll\\"*)
            if [ "$scenario" = "scan-slow" ]; then sleep 1; fi
            if [ "$scenario" = "stale-after-toggle" ]; then
              scan_skills=$skills_toggled
              scan_finding_count=1
            else
              scan_skills=$skills_normal
              scan_finding_count=0
            fi
            respond '{"id":"test","ok":true,"result":{"scanned_count":3,"skills":'"$scan_skills"',"activity":{"operation":"scan","status":"ok","started_at":1,"finished_at":2,"scanned_count":3,"skill_count":3,"finding_count":'"$scan_finding_count"',"conflict_count":0,"snapshot_count":0,"roots":["/tmp/global","/tmp/codex"],"log_entries":[],"recovery_actions":[],"agent_summaries":[{"agent":"claude-code","display_label":"Claude Code","status":"completed","scanned_count":2,"catalog_count":2,"broken_count":0,"roots_considered":["/tmp/global","/tmp/missing-claude"],"roots_scanned":["/tmp/global"],"roots_skipped":["/tmp/missing-claude"],"recovery_actions":["Create missing Claude root."]},{"agent":"codex","display_label":"Codex","status":"completed","scanned_count":1,"catalog_count":1,"broken_count":0,"roots_considered":["/tmp/codex"],"roots_scanned":["/tmp/codex"],"roots_skipped":[],"recovery_actions":[]}]}}}'
            ;;
          *\\"project.getContext\\"*)
            if [ "$scenario" = "project-clear" ] || [ "$scenario" = "empty" ]; then
              respond '{"id":"test","ok":true,"result":{"active":null,"recent":'"$project_recent"'}}'
            elif [ "$scenario" = "project-validation-error" ]; then
              respond '{"id":"test","ok":true,"result":{"active":'"$project_invalid"',"recent":'"$project_recent"'}}'
            else
              respond '{"id":"test","ok":true,"result":{"active":'"$project_active"',"recent":'"$project_recent"'}}'
            fi
            ;;
          *\\"project.setContext\\"*)
            if [ "$scenario" = "project-validation-error" ]; then
              respond '{"id":"test","ok":true,"result":{"active":'"$project_invalid"',"recent":['"$project_invalid"']}}'
            else
              respond '{"id":"test","ok":true,"result":{"active":'"$project_active"',"recent":'"$project_recent"'}}'
            fi
            ;;
          *\\"project.clearContext\\"*)
            respond '{"id":"test","ok":true,"result":{"active":null,"recent":'"$project_recent"'}}'
            ;;
          *\\"project.validateContext\\"*)
            if [ "$scenario" = "project-validation-error" ]; then
              respond '{"id":"test","ok":true,"result":'"$project_invalid"'}'
            else
              respond '{"id":"test","ok":true,"result":'"$project_active"'}'
            fi
            ;;
          *\\"catalog.getSkill\\"*)
            case "$input" in
              *\\"instance_id\\":\\"beta\\"*)
                if [ "$scenario" = "stale-before" ]; then
                  respond '{"id":"test","ok":true,"result":'"$detail_beta_before"'}'
                elif [ "$scenario" = "stale-after-scan" ]; then
                  respond '{"id":"test","ok":true,"result":'"$detail_beta_scan"'}'
                elif [ "$scenario" = "stale-after-toggle" ]; then
                  respond '{"id":"test","ok":true,"result":'"$detail_beta_toggle"'}'
                elif [ "$scenario" = "toggle-disabled" ]; then
                  respond '{"id":"test","ok":true,"result":'"$detail_beta_disabled"'}'
                else
                  respond '{"id":"test","ok":true,"result":'"$detail_beta_enabled"'}'
                fi
                ;;
              *\\"instance_id\\":\\"gamma\\"*)
                if [ "$scenario" = "stale-after-scan" ]; then
                  respond '{"id":"test","ok":true,"result":'"$detail_gamma_scan"'}'
                elif [ "$scenario" = "stale-after-project" ]; then
                  respond '{"id":"test","ok":true,"result":'"$detail_gamma_project"'}'
                elif [ "$scenario" = "toggle-codex-disabled" ]; then
                  respond '{"id":"test","ok":true,"result":'"$detail_gamma_disabled"'}'
                else
                  respond '{"id":"test","ok":true,"result":'"$detail_gamma"'}'
                fi
                ;;
              *\\"instance_id\\":\\"omega\\"*)
                if grep -q '"method":"config.toggleSkill"' "$SKILLS_COPILOT_FAKE_SERVICE_CALLS"; then
                  respond '{"id":"test","ok":true,"result":'"$detail_omega_disabled"'}'
                else
                  respond '{"id":"test","ok":true,"result":'"$detail_omega"'}'
                fi
                ;;
              *\\"instance_id\\":\\"tool-alpha\\"*)
                respond '{"id":"test","ok":true,"result":'"$detail_toolglobal"'}'
                ;;
              *)
                respond '{"id":"test","ok":true,"result":'"$detail_alpha"'}'
                ;;
            esac
            ;;
          *\\"catalog.listFindings\\"*)
            respond '{"id":"test","ok":true,"result":[]}'
            ;;
          *\\"catalog.listConflicts\\"*)
            respond '{"id":"test","ok":true,"result":[]}'
            ;;
          *\\"skill.listEvents\\"*)
            if [ "$scenario" = "detail-scope" ]; then
              case "$input" in
                *\\"instance_id\\":\\"beta\\"*)
                  respond '{"id":"test","ok":true,"result":'"$events_beta"'}'
                  ;;
                *\\"instance_id\\":\\"gamma\\"*)
                  respond '{"id":"test","ok":true,"result":'"$events_gamma"'}'
                  ;;
              esac
            fi
            respond '{"id":"test","ok":true,"result":[]}'
            ;;
          *\\"snapshot.previewRollback\\"*)
            if [ "$scenario" = "timeline" ]; then
              respond '{"id":"test","ok":true,"result":{"snapshot":{"id":"snap-claude-new","agent":"claude-code","scope":"agent-global","target":"/tmp/home/.claude/settings.json","content":"{}\\n","reason":"pre-toggle","created_at":30},"current_content":"{\\"skillOverrides\\":{\\"beta\\":false}}\\n","current_read_error":null,"changed":true,"redacted":false,"rollback_supported":true}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"test.missing","message":"missing snapshot preview"}}'
            ;;
          *\\"snapshot.rollback\\"*)
            if [ "$scenario" = "timeline" ]; then
              respond '{"id":"test","ok":true,"result":3}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"test.missing","message":"missing snapshot rollback"}}'
            ;;
          *\\"snapshot.listAgentConfig\\"*)
            if [ "$scenario" = "timeline" ]; then
              case "$input" in
                *\\"agent\\":\\"claude-code\\"*)
                  respond '{"id":"test","ok":true,"result":'"$snapshots_claude"'}'
                  ;;
                *\\"agent\\":\\"codex\\"*)
                  respond '{"id":"test","ok":true,"result":'"$snapshots_codex"'}'
                  ;;
                *\\"agent\\":\\"opencode\\"*)
                  respond '{"id":"test","ok":true,"result":'"$snapshots_opencode"'}'
                  ;;
              esac
            fi
            respond '{"id":"test","ok":true,"result":[]}'
            ;;
          *\\"snapshot.list\\"*)
            respond '{"id":"test","ok":true,"result":[]}'
            ;;
          *\\"config.readAgentConfig\\"*)
            if [ "$scenario" = "agent-config" ]; then
              case "$input" in
                *\\"agent\\":\\"claude-code\\"*) respond '{"id":"test","ok":true,"result":'"$agent_config_claude"'}' ;;
                *\\"agent\\":\\"codex\\"*) respond '{"id":"test","ok":true,"result":'"$agent_config_codex"'}' ;;
                *\\"agent\\":\\"opencode\\"*) respond '{"id":"test","ok":true,"result":'"$agent_config_opencode"'}' ;;
                *\\"agent\\":\\"pi\\"*) respond '{"id":"test","ok":true,"result":'"$agent_config_pi"'}' ;;
                *\\"agent\\":\\"hermes\\"*) respond '{"id":"test","ok":true,"result":'"$agent_config_hermes"'}' ;;
                *\\"agent\\":\\"openclaw\\"*) respond '{"id":"test","ok":true,"result":'"$agent_config_openclaw"'}' ;;
              esac
            fi
            respond '{"id":"test","ok":true,"result":[]}'
            ;;
          *\\"config.toggleSkill\\"*)
            if [ "$scenario" = "stale-after-toggle" ]; then
              respond '{"id":"test","ok":true,"result":'"$detail_beta_toggle"'}'
            elif [ "$scenario" = "toggle-disabled" ]; then
              sleep 1
              respond '{"id":"test","ok":true,"result":'"$detail_beta_disabled"'}'
            elif [ "$scenario" = "toggle-codex-disabled" ]; then
              respond '{"id":"test","ok":true,"result":'"$detail_gamma_disabled"'}'
            elif [ "$scenario" = "opencode" ]; then
              respond '{"id":"test","ok":true,"result":'"$detail_omega_disabled"'}'
            else
              respond '{"id":"test","ok":true,"result":'"$detail_beta_disabled"'}'
            fi
            ;;
          *)
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"test.unknown","message":"unknown method"}}'
            ;;
        esac
        """
    }
}

private final class FakeServiceFileProcessInvocation {
    private let executableURL: URL
    private let workingDirectory: URL
    private let input: Data
    private let environmentOverrides: [String: String]
    private let lock = NSLock()
    private var process: Process?

    init(
        executableURL: URL,
        workingDirectory: URL,
        input: Data,
        environmentOverrides: [String: String]
    ) {
        self.executableURL = executableURL
        self.workingDirectory = workingDirectory
        self.input = input
        self.environmentOverrides = environmentOverrides
    }

    func run(timeoutNanoseconds: UInt64?) throws -> Data {
        try Task.checkCancellation()

        let invocationID = UUID().uuidString
        let stdoutURL = workingDirectory.appendingPathComponent("stdout-\(invocationID).json")
        let stderrURL = workingDirectory.appendingPathComponent("stderr-\(invocationID).log")
        _ = FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        _ = FileManager.default.createFile(atPath: stderrURL.path, contents: nil)

        let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
        let stderrHandle = try FileHandle(forWritingTo: stderrURL)
        defer {
            try? stdoutHandle.close()
            try? stderrHandle.close()
            try? FileManager.default.removeItem(at: stdoutURL)
            try? FileManager.default.removeItem(at: stderrURL)
        }

        let process = Process()
        process.executableURL = executableURL
        var environment = ProcessInfo.processInfo.environment
        environmentOverrides.forEach { key, value in
            environment[key] = value
        }
        process.environment = environment
        process.standardInput = Pipe()
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle

        register(process)
        defer { clear(process) }

        let completed = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            completed.signal()
        }
        defer { process.terminationHandler = nil }

        try process.run()

        if let stdin = process.standardInput as? Pipe {
            try stdin.fileHandleForWriting.write(contentsOf: input)
            try stdin.fileHandleForWriting.close()
        }

        if let timeoutNanoseconds {
            let timeout = DispatchTime.now() + .nanoseconds(Int(min(timeoutNanoseconds, UInt64(Int.max))))
            if completed.wait(timeout: timeout) == .timedOut {
                cancel()
                _ = completed.wait(timeout: .now() + .milliseconds(500))
                throw ServiceClient.ClientError.processTimedOut
            }
        } else {
            completed.wait()
        }

        try Task.checkCancellation()
        try stdoutHandle.close()
        try stderrHandle.close()

        let output = try Data(contentsOf: stdoutURL)
        let errorOutput = try Data(contentsOf: stderrURL)
        if process.terminationStatus != 0 {
            let message = String(data: errorOutput, encoding: .utf8) ?? ""
            throw ServiceClient.ClientError.processFailed(process.terminationStatus, message)
        }
        return output
    }

    func cancel() {
        lock.lock()
        let process = self.process
        lock.unlock()

        guard let process, process.isRunning else { return }
        process.terminate()
        let deadline = Date().addingTimeInterval(0.25)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
    }

    private func register(_ process: Process) {
        lock.lock()
        self.process = process
        lock.unlock()
    }

    private func clear(_ process: Process) {
        lock.lock()
        if self.process === process {
            self.process = nil
        }
        lock.unlock()
    }
}
