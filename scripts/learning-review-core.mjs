const PREFERENCE_PATTERNS = [
  /\b(?:i\s+prefer|prefer|please\s+avoid|avoid|do\s+not|don't|never|always|must|should)\b/i,
  /(?:不要|别|避免|必须|务必|总是|优先|偏好|希望|不希望|喜欢|不喜欢)/,
];

const SKILL_PATTERNS = [
  /\b(?:next\s+time|when\s+.+,\s*(?:run|use|check|read|write|create|update|verify|ask|stop)|if\s+.+,\s*(?:run|use|check|read|write|create|update|verify|ask|stop))\b/i,
  /(?:下次|以后|当.+时|如果.+时|遇到.+时).*(?:运行|使用|检查|读取|写入|创建|更新|验证|询问|停止)/,
];

const LEADING_ROLE_PATTERN = /^(?:user|assistant|system|developer|task|result|next|note)\s*:\s*/i;

function normalizeStatement(line) {
  return line
    .replace(LEADING_ROLE_PATTERN, "")
    .replace(/\s+/g, " ")
    .trim();
}

function candidateType(statement) {
  if (SKILL_PATTERNS.some((pattern) => pattern.test(statement))) {
    return "skill";
  }
  if (PREFERENCE_PATTERNS.some((pattern) => pattern.test(statement))) {
    return "preference";
  }
  return null;
}

function fingerprint(statement) {
  return statement.toLowerCase().replace(/\s+/g, " ").trim();
}

export function extractLearningCandidates(sources) {
  const byFingerprint = new Map();

  for (const source of sources) {
    const lines = source.text.split(/\r?\n/);
    lines.forEach((rawLine, index) => {
      const statement = normalizeStatement(rawLine);
      if (!statement || statement.length < 12) {
        return;
      }

      const type = candidateType(statement);
      if (!type) {
        return;
      }

      const key = `${type}:${fingerprint(statement)}`;
      const evidence = { path: source.path, line: index + 1 };
      const existing = byFingerprint.get(key);
      if (existing) {
        existing.evidence.push(evidence);
        return;
      }

      byFingerprint.set(key, {
        type,
        statement,
        source: evidence,
        evidence: [evidence],
      });
    });
  }

  return [...byFingerprint.values()];
}

function evidenceText(candidate) {
  return candidate.evidence
    .map((item) => `${item.path}:${item.line}`)
    .join(", ");
}

function section(title, candidates) {
  const lines = [`## ${title}`, ""];
  if (candidates.length === 0) {
    lines.push("No candidates found.", "");
    return lines.join("\n");
  }

  for (const candidate of candidates) {
    lines.push(`- [ ] ${candidate.statement}`);
    lines.push(`  Evidence: ${evidenceText(candidate)}`);
  }
  lines.push("");
  return lines.join("\n");
}

export function buildLearningReview({ title = "Manual Learning Review", sources }) {
  const candidates = extractLearningCandidates(sources);
  const preferences = candidates.filter((candidate) => candidate.type === "preference");
  const skills = candidates.filter((candidate) => candidate.type === "skill");

  return [
    `# ${title}`,
    "",
    "This is a draft. Review every candidate before promoting it into `AGENTS.md`, project docs, or a Codex skill.",
    "",
    section("Preference Candidates", preferences),
    section("Skill Candidates", skills),
    "## Promotion Checklist",
    "",
    "- [ ] Candidate is still current and not contradicted by newer project rules.",
    "- [ ] Candidate is specific enough to execute or test.",
    "- [ ] Do not promote secrets, credentials, private user data, full logs, or unverified assumptions.",
    "- [ ] Durable rules go into their owning workflow or domain doc, not into multiple places.",
    "- [ ] Re-run context hygiene after durable memory or workflow changes.",
    "",
  ].join("\n");
}
