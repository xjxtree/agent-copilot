pub mod claude_code;
pub mod codex;
pub mod opencode;

pub use claude_code::ClaudeCodeAdapter;
pub use codex::{parse_codex_skill_config_entries, CodexAdapter, CodexSkillConfigEntry};
pub use opencode::OpencodeAdapter;
