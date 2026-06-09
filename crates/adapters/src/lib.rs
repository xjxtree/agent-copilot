pub mod claude_code;
pub mod codex;
pub mod openclaw;
pub mod opencode;
pub mod pi;

pub use claude_code::ClaudeCodeAdapter;
pub use codex::{parse_codex_skill_config_entries, CodexAdapter, CodexSkillConfigEntry};
pub use openclaw::OpenclawAdapter;
pub use opencode::OpencodeAdapter;
pub use pi::PiAdapter;
