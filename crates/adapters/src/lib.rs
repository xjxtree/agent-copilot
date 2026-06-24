pub(crate) mod shared;

pub mod claude_code;
pub mod codex;
pub mod hermes;
pub mod openclaw;
pub mod opencode;
pub mod pi;

pub use claude_code::ClaudeCodeAdapter;
pub use codex::{parse_codex_skill_config_entries, CodexAdapter, CodexSkillConfigEntry};
pub use hermes::{hermes_disabled_skill_names, HermesAdapter};
pub use openclaw::{
    openclaw_config_key_from_frontmatter, openclaw_disabled_skill_keys, OpenclawAdapter,
};
pub use opencode::OpencodeAdapter;
pub use pi::{pi_disabled_skill_names, PiAdapter};
