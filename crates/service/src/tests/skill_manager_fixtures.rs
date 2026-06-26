use super::*;

pub(super) fn skill_manager_dispatch_params(method: &str) -> Value {
    match method {
        "skillManager.search" => {
            json!({ "query": "frontend", "owner": "vercel-labs", "network_allowed": false })
        }
        "skillManager.listInstalled" => json!({ "scope": "project" }),
        "skillManager.previewInstall" | "skillManager.applyInstall" => {
            json!({
                "source": "vercel-labs/agent-skills",
                "skills": ["frontend-design"],
                "scope": "project",
                "network_allowed": false,
                "confirmed": false
            })
        }
        "skillManager.previewRemove" | "skillManager.applyRemove" => {
            json!({ "skill": "frontend-design", "scope": "project", "confirmed": false })
        }
        "skillManager.previewUpdate" | "skillManager.applyUpdate" => {
            json!({
                "skills": ["frontend-design"],
                "scope": "project",
                "network_allowed": false,
                "confirmed": false
            })
        }
        "skillManager.previewLocalCreate" | "skillManager.applyLocalCreate" => {
            json!({ "name": "dispatch-local-skill", "confirmed": false })
        }
        "skillManager.deleteLocal" => {
            json!({ "instance_id": "missing-skill", "confirmed": false })
        }
        _ => Value::Null,
    }
}
