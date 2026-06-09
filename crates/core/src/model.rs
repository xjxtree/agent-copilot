use std::path::PathBuf;

#[derive(Debug, Clone, Copy, Eq, PartialEq, Hash)]
pub enum AgentId {
    ToolGlobal,
    ClaudeCode,
    Codex,
    Pi,
    Hermes,
    Openclaw,
    Opencode,
}

impl AgentId {
    pub fn as_str(self) -> &'static str {
        match self {
            AgentId::ToolGlobal => "tool-global",
            AgentId::ClaudeCode => "claude-code",
            AgentId::Codex => "codex",
            AgentId::Pi => "pi",
            AgentId::Hermes => "hermes",
            AgentId::Openclaw => "openclaw",
            AgentId::Opencode => "opencode",
        }
    }
}

#[derive(Debug, Clone, Copy, Eq, PartialEq, Hash)]
#[non_exhaustive]
pub enum Scope {
    ToolGlobal,
    AgentGlobal,
    AgentProject,
}

impl Scope {
    pub fn as_str(self) -> &'static str {
        match self {
            Scope::ToolGlobal => "tool-global",
            Scope::AgentGlobal => "agent-global",
            Scope::AgentProject => "agent-project",
        }
    }
}

#[derive(Debug, Clone, Eq, PartialEq)]
pub enum SkillState {
    Loaded,
    Disabled,
    Shadowed,
    Broken,
    Missing,
}

impl SkillState {
    pub fn as_str(&self) -> &'static str {
        match self {
            SkillState::Loaded => "loaded",
            SkillState::Disabled => "disabled",
            SkillState::Shadowed => "shadowed",
            SkillState::Broken => "broken",
            SkillState::Missing => "missing",
        }
    }
}

#[derive(Debug, Clone, Eq, PartialEq)]
pub enum NetworkAccess {
    None,
    ReadOnly,
    Full,
    Unknown(String),
}

impl NetworkAccess {
    pub fn as_str(&self) -> &'static str {
        match self {
            NetworkAccess::None => "none",
            NetworkAccess::ReadOnly => "read-only",
            NetworkAccess::Full => "full",
            NetworkAccess::Unknown(_) => "unknown",
        }
    }
}

#[derive(Debug, Clone, Eq, PartialEq)]
pub struct PermissionRequest {
    pub tools: Vec<String>,
    pub files: Vec<String>,
    pub network: NetworkAccess,
    pub network_declared: bool,
    pub exec: bool,
    pub exec_declared: bool,
    pub requires_human: bool,
    pub requires_human_declared: bool,
}

impl Default for PermissionRequest {
    fn default() -> Self {
        Self {
            tools: Vec::new(),
            files: Vec::new(),
            network: NetworkAccess::None,
            network_declared: false,
            exec: false,
            exec_declared: false,
            requires_human: true,
            requires_human_declared: false,
        }
    }
}

#[derive(Debug, Clone, Eq, PartialEq)]
pub struct SkillScript {
    pub name: String,
    pub path: PathBuf,
    pub interpreter: Option<String>,
    pub description: Option<String>,
    pub fingerprint: String,
}

#[derive(Debug, Clone, Eq, PartialEq)]
pub struct SkillInstance {
    pub id: String,
    pub agent: AgentId,
    pub scope: Scope,
    pub project_root: Option<PathBuf>,
    pub path: PathBuf,
    pub display_path: PathBuf,
    pub definition_id: String,
    pub name: String,
    pub display_name: String,
    pub description: String,
    pub version: Option<String>,
    pub state: SkillState,
    pub enabled: bool,
    pub frontmatter_raw: String,
    pub body: String,
    pub scripts: Vec<SkillScript>,
    pub permissions: PermissionRequest,
    pub fingerprint: String,
    pub mtime: i64,
    pub first_seen: i64,
    pub last_seen: i64,
}

#[derive(Debug, Clone, Eq, PartialEq)]
pub struct SkillDefinition {
    pub id: String,
    pub canonical_name: String,
    pub description: String,
    pub instances: Vec<String>,
    pub active_instance: Option<String>,
    pub has_multiple_instances: bool,
    pub has_conflict: bool,
    pub fingerprint_set: Vec<String>,
}

#[derive(Debug, Clone, Eq, PartialEq)]
pub enum ConflictReason {
    NameCollision,
    ContentDrift,
    PermissionMismatch,
    Shadowed,
}

#[derive(Debug, Clone, Eq, PartialEq)]
pub struct ConflictGroup {
    pub definition_id: String,
    pub reason: ConflictReason,
    pub instances: Vec<String>,
    pub winner_id: Option<String>,
}
