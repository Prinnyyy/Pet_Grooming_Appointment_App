import { createHash } from "node:crypto";

export const UI_RULES = Object.freeze([
  { id: "UI001", severity: "error", category: "typography", message: "Use Beckon semantic typography." },
  { id: "UI002", severity: "error", category: "typography", message: "Use Beckon semantic typography instead of a platform style in migrated or new Feature code." },
  { id: "UI003", severity: "error", category: "color", message: "Use DesignTokens semantic colors." },
  { id: "UI004", severity: "error", category: "spacing", message: "Use a semantic layout token or shared component." },
  { id: "UI005", severity: "error", category: "shape", message: "Use a DesignTokens shape role or shared surface." },
  { id: "UI006", severity: "error", category: "elevation", message: "Use beckonShadow with a canonical elevation role." },
  { id: "UI007", severity: "error", category: "local-style", message: "Move repeatable presentation styles into DesignSystem." },
  { id: "UI008", severity: "error", category: "text-fit", message: "Reflow text; scale factors below 0.85 are not allowed." },
  { id: "UI009", severity: "error", category: "keyboard-safe-area", message: "Keep the native keyboard safe area on Feature form content." },
  { id: "UI010", severity: "error", category: "keyboard-clearance", message: "Do not create Feature-local keyboard padding or offsets." },
  { id: "UI011", severity: "error", category: "keyboard-observation", message: "Keyboard observation belongs to DesignSystem." },
  { id: "UI101", severity: "warning", category: "fixed-geometry", message: "Review fixed geometry for dynamic text risk." },
  { id: "UI102", severity: "warning", category: "layout-patch", message: "Review offset or negative spacing as a layout repair." },
  { id: "UI201", severity: "review", category: "duplicate-stack", message: "Review repeated visual modifier stacks for a semantic component." },
]);

const ruleByID = new Map(UI_RULES.map((rule) => [rule.id, rule]));
const exactFixedGeometryDirective = "// beckon-ui-audit: allow UI101 -- Fixed square media crop; text is outside this frame.";

function hash(value) {
  return createHash("sha256").update(value).digest("hex");
}

export function maskSwiftNonCode(source) {
  const output = source.split("");
  let index = 0;
  let state = "code";
  let blockDepth = 0;

  const mask = (position) => {
    if (source[position] !== "\n" && source[position] !== "\r") output[position] = " ";
  };

  while (index < source.length) {
    const pair = source.slice(index, index + 2);
    const triple = source.slice(index, index + 3);

    if (state === "code") {
      if (pair === "//") {
        mask(index); mask(index + 1);
        index += 2; state = "line-comment"; continue;
      }
      if (pair === "/*") {
        mask(index); mask(index + 1);
        index += 2; blockDepth = 1; state = "block-comment"; continue;
      }
      if (triple === '\"\"\"') {
        mask(index); mask(index + 1); mask(index + 2);
        index += 3; state = "multiline-string"; continue;
      }
      if (source[index] === '"') {
        mask(index); index += 1; state = "string"; continue;
      }
      index += 1;
      continue;
    }

    if (state === "line-comment") {
      if (source[index] === "\n") state = "code";
      else mask(index);
      index += 1;
      continue;
    }

    if (state === "block-comment") {
      if (pair === "/*") {
        mask(index); mask(index + 1); index += 2; blockDepth += 1; continue;
      }
      if (pair === "*/") {
        mask(index); mask(index + 1); index += 2; blockDepth -= 1;
        if (blockDepth === 0) state = "code";
        continue;
      }
      mask(index); index += 1; continue;
    }

    if (state === "multiline-string") {
      if (triple === '\"\"\"') {
        mask(index); mask(index + 1); mask(index + 2); index += 3; state = "code"; continue;
      }
      mask(index); index += 1; continue;
    }

    if (source[index] === "\\") {
      mask(index);
      if (index + 1 < source.length) mask(index + 1);
      index += 2;
    } else if (source[index] === '"') {
      mask(index); index += 1; state = "code";
    } else {
      mask(index); index += 1;
    }
  }
  return output.join("");
}

function callEnd(masked, openIndex) {
  let depth = 0;
  for (let index = openIndex; index < masked.length; index += 1) {
    if (masked[index] === "(") depth += 1;
    if (masked[index] === ")") {
      depth -= 1;
      if (depth === 0) return index + 1;
    }
  }
  return openIndex + 1;
}

function location(source, index) {
  const before = source.slice(0, index);
  const line = before.split("\n").length;
  const lastNewline = before.lastIndexOf("\n");
  return { line, column: index - lastNewline };
}

function normalizedExpression(expression) {
  return expression.replace(/\s+/g, " ").trim();
}

export function fingerprintFinding(finding) {
  const expressionHash = finding.expressionHash ?? hash(normalizedExpression(finding.expression ?? ""));
  return hash([finding.ruleID, finding.path, expressionHash, finding.occurrence ?? 1].join("\0"));
}

function hasFixedGeometryException(source, index) {
  const lineStart = source.lastIndexOf("\n", index - 1) + 1;
  const previousEnd = Math.max(0, lineStart - 1);
  const previousStart = source.lastIndexOf("\n", previousEnd - 1) + 1;
  return source.slice(previousStart, previousEnd).trim() === exactFixedGeometryDirective;
}

function addMatches(results, { masked, source, filePath, ruleID, pattern, replacement, predicate, exception }) {
  for (const match of masked.matchAll(pattern)) {
    const index = match.index;
    if (predicate && !predicate(match, index)) continue;
    if (exception && exception(source, index)) continue;
    const openIndex = masked.indexOf("(", index);
    const end = openIndex >= 0 ? callEnd(masked, openIndex) : index + match[0].length;
    const expression = normalizedExpression(source.slice(index, end));
    const rule = ruleByID.get(ruleID);
    results.push({
      ruleID,
      path: filePath,
      severity: rule.severity,
      category: rule.category,
      message: rule.message,
      replacement,
      expression,
      expressionHash: hash(expression),
      index,
      ...location(source, index),
    });
  }
}

function addDuplicateStacks(results, { masked, source, filePath }) {
  const visualModifier = /\.(?:font|foregroundStyle|foregroundColor|padding|background|overlay|cornerRadius|clipShape|shadow|frame)\s*\(/g;
  const firstByStack = new Map();
  let lineStart = 0;
  while (lineStart <= masked.length) {
    const lineEnd = masked.indexOf("\n", lineStart);
    const end = lineEnd < 0 ? masked.length : lineEnd;
    const line = masked.slice(lineStart, end);
    const calls = [];
    for (const match of line.matchAll(visualModifier)) {
      const start = lineStart + match.index;
      const open = masked.indexOf("(", start);
      const callFinish = callEnd(masked, open);
      if (callFinish > end) continue;
      calls.push({ start, expression: normalizedExpression(source.slice(start, callFinish)) });
    }
    if (calls.length >= 3) {
      const expression = calls.map(({ expression: call }) => call).join("");
      const expressionHash = hash(expression);
      if (firstByStack.has(expressionHash)) {
        const rule = ruleByID.get("UI201");
        results.push({
          ruleID: rule.id,
          path: filePath,
          severity: rule.severity,
          category: rule.category,
          message: rule.message,
          replacement: "Shared semantic component",
          expression,
          expressionHash,
          index: calls[0].start,
          ...location(source, calls[0].start),
        });
      } else {
        firstByStack.set(expressionHash, calls[0].start);
      }
    }
    if (lineEnd < 0) break;
    lineStart = lineEnd + 1;
  }
}

export function auditSwiftSource({ filePath, source }) {
  const masked = maskSwiftNonCode(source);
  const findings = [];

  addMatches(findings, { masked, source, filePath, ruleID: "UI001", pattern: /\.font\s*\(\s*\.system\s*\(/g, replacement: "DesignTokens.Typography.<role>" });
  addMatches(findings, { masked, source, filePath, ruleID: "UI002", pattern: /\.font\s*\(\s*\.(?:largeTitle|title\d?|headline|subheadline|body|callout|footnote|caption\d?)\b/g, replacement: "DesignTokens.Typography.<role>" });
  addMatches(findings, { masked, source, filePath, ruleID: "UI003", pattern: /\b(?:Color|UIColor)\s*\((?=\s*(?:red:|white:|hue:|displayP3Red:|#[0-9A-Fa-f]))/g, replacement: "DesignTokens.Colors.<role>" });
  addMatches(findings, { masked, source, filePath, ruleID: "UI003", pattern: /\.(?:foregroundStyle|foregroundColor|background|tint)\s*\(\s*\.(?:red|blue|green|orange|yellow|purple|pink|brown|cyan|indigo|mint|teal|black|white|gray)\b/g, replacement: "DesignTokens.Colors.<role>" });
  addMatches(findings, { masked, source, filePath, ruleID: "UI004", pattern: /\.(?:padding|spacing)\s*\([^)]*?\b-?\d+(?:\.\d+)?\b/g, replacement: "DesignTokens.Spacing.<role>" });
  addMatches(findings, { masked, source, filePath, ruleID: "UI005", pattern: /\b(?:RoundedRectangle|UnevenRoundedRectangle)\s*\(\s*cornerRadius\s*:\s*\d/g, replacement: "DesignTokens.Shape.<role>" });
  addMatches(findings, { masked, source, filePath, ruleID: "UI005", pattern: /\.cornerRadius\s*\(\s*\d/g, replacement: "DesignTokens.Shape.<role>" });
  addMatches(findings, { masked, source, filePath, ruleID: "UI006", pattern: /\.shadow\s*\(/g, replacement: ".beckonShadow(<role>)" });
  addMatches(findings, { masked, source, filePath, ruleID: "UI007", pattern: /\b(?:private|fileprivate)\s+(?:struct|enum|class)\s+\w*(?:ButtonStyle|CardStyle|FormStyle)\b/g, replacement: "DesignSystem shared style" });
  addMatches(findings, { masked, source, filePath, ruleID: "UI008", pattern: /\.minimumScaleFactor\s*\(\s*(?:0?\.[0-7]\d*|0?\.8[0-4]\d*)\s*\)/g, replacement: "Reflow content or use >= 0.85" });
  addMatches(findings, { masked, source, filePath, ruleID: "UI009", pattern: /\.ignoresSafeArea\s*\(\s*\.keyboard\b/g, replacement: "Native keyboard safe-area resizing" });
  addMatches(findings, { masked, source, filePath, ruleID: "UI010", pattern: /\.(?:padding|offset)\s*\([^)]*\bkeyboard\w*/gi, replacement: "Shared Beckon keyboard modifiers" });
  addMatches(findings, { masked, source, filePath, ruleID: "UI011", pattern: /\b(?:keyboardWillChangeFrameNotification|keyboardWillHideNotification|keyboardFrameEndUserInfoKey)\b/g, replacement: "DesignSystem keyboard boundary" });
  addMatches(findings, { masked, source, filePath, ruleID: "UI101", pattern: /\.frame\s*\([^)]*\b(?:width|height)\s*:\s*(?:\d+(?:\.\d+)?|DesignTokens\.)/g, replacement: "Content-sized layout", exception: hasFixedGeometryException });
  addMatches(findings, { masked, source, filePath, ruleID: "UI102", pattern: /\.offset\s*\(/g, replacement: "Alignment or layout container" });
  addMatches(findings, { masked, source, filePath, ruleID: "UI102", pattern: /\.(?:padding|spacing)\s*\([^)]*?\b-\d+(?:\.\d+)?\b/g, replacement: "Non-negative semantic spacing" });
  addDuplicateStacks(findings, { masked, source, filePath });

  findings.sort((left, right) => left.index - right.index || left.ruleID.localeCompare(right.ruleID));
  const occurrences = new Map();
  for (const finding of findings) {
    const key = `${finding.ruleID}\0${finding.expressionHash}`;
    const occurrence = (occurrences.get(key) ?? 0) + 1;
    occurrences.set(key, occurrence);
    finding.occurrence = occurrence;
    finding.fingerprint = fingerprintFinding(finding);
    delete finding.index;
  }
  return findings;
}

function baselineKey(finding) {
  return finding.fingerprint ?? fingerprintFinding(finding);
}

export function compareWithBaseline(findings, baseline, strictPaths = []) {
  const baselineMap = new Map((baseline.findings ?? []).map((finding) => [baselineKey(finding), finding]));
  const currentMap = new Map(findings.map((finding) => [baselineKey(finding), finding]));
  const strict = new Set(strictPaths);
  return {
    newErrors: findings.filter((finding) => finding.severity === "error" && !baselineMap.has(baselineKey(finding))),
    staleEntries: (baseline.findings ?? []).filter((finding) => !currentMap.has(baselineKey(finding))),
    strictFindings: findings.filter((finding) => finding.severity === "error" && strict.has(finding.path)),
  };
}
