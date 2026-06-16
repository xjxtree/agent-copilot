use super::*;
use serde::de::DeserializeOwned;
use serde_json::{json, Value};
use skills_copilot_catalog::{ConflictGroupDraft, RuleFindingDraft, SkillDefinitionDraft};
use skills_copilot_core::{
    AgentId, NetworkAccess, PermissionRequest, Scope, SkillInstance, SkillState,
};
use std::{
    env, fs,
    path::{Path, PathBuf},
};

mod dispatch_fixtures;
mod llm_provider;
mod protocol_fixtures;
mod remediation_workspace;
mod support_and_status;
mod support_seed;
mod task_routing;

use support_and_status::EnvVarGuard;
use support_seed::*;
