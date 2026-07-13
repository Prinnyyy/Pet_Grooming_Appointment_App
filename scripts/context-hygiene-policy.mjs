export const MODEL_CONTEXT_CAPACITY_TOKENS = 353000;
export const DEFAULT_WORD_REFERENCE = 650;
export const WORKLOG_ENTRY_TRIGGER = 14;
export const WORKLOG_ENTRY_RETAIN = 8;
export const TASK_LEDGER_ROW_TRIGGER = 18;
export const TASK_LEDGER_ROW_RETAIN = 12;
export const TASK_LEDGER_ROW_CHAR_LIMIT = 700;
export const DECISION_LOG_ENTRY_TRIGGER = 14;
export const DECISION_LOG_ENTRY_RETAIN = 8;
export const DECISION_ARCHIVE_POINTER_TRIGGER = 12;
export const DECISION_ARCHIVE_POINTER_RETAIN = 6;

export const WORD_REFERENCES = new Map([
  ["AGENTS.md", 800],
  ["README.md", 500],
  ["CLAUDE.md", 600],
  ["docs/README.md", 800],
  ["docs/00_memory/CURRENT_STATE.md", 1200],
  ["docs/00_memory/WORKLOG.md", 2500],
  ["docs/06_tasks/TASK_LEDGER.md", 1800],
  ["docs/06_tasks/ROADMAP.md", 1800],
  ["docs/06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md", 800],
  ["docs/00_memory/FEATURE_INDEX.md", 1200],
  ["docs/00_memory/PROJECT_MEMORY.md", 600],
  ["docs/07_decisions/DECISION_LOG.md", 1800],
  ["docs/01_product/DESIGN_SYSTEM.md", 900],
  ["docs/01_product/ACCESSIBILITY_RULES.md", 900],
  ["docs/01_product/FORM_INTERACTION_RULES.md", 1100],
  ["docs/01_product/SCREEN_INVENTORY.md", 1500],
  ["docs/08_design/UI_IMPLEMENTATION_NOTES.md", 900],
  ["docs/08_design/GROOMER_UI_REDESIGN.md", 650],
  ["docs/ui-redesign/README.md", 500],
  ["docs/03_backend/SUPABASE_CONTRACT.md", 1100],
  ["docs/03_backend/RLS_RPC_POLICY.md", 1200],
  ["docs/03_backend/STORAGE_POLICY.md", 700],
  ["docs/03_backend/MIGRATION_RULES.md", 900],
  ["docs/04_ios/testops/TESTOPS_MEMORY.md", 400],
  ["docs/05_workflow/CONTEXT_AND_RECOVERY.md", 1100],
  ["docs/05_workflow/SINGLE_AGENT_WORKFLOW.md", 1100],
  ["docs/05_workflow/TOOLING_POLICY.md", 1500],
  ["docs/10_project_structure/REORGANIZATION_LOG.md", 1200],
]);
