pub mod claude_code;
pub mod codex;
pub mod hermes;
pub mod openclaw;
pub mod opencode;
pub mod pi;

pub use claude_code::ClaudeCodeAdapter;
pub use codex::{parse_codex_skill_config_entries, CodexAdapter, CodexSkillConfigEntry};
pub use hermes::HermesAdapter;
pub use openclaw::OpenclawAdapter;
pub use opencode::OpencodeAdapter;
pub use pi::{pi_disabled_skill_names, PiAdapter};
