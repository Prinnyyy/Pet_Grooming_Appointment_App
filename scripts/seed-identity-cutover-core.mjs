import { createHash } from "node:crypto";

export const SEED_CUTOVER_APPROVAL_ENV = "BECKON_REMOTE_IDENTITY_APPROVED";
export const LEGACY_SEED_PASSWORD = "GroomlyTest!2026";

export function requireSeedCutoverApproval(env = process.env) {
  if (env[SEED_CUTOVER_APPROVAL_ENV] !== "1") {
    throw new Error(`${SEED_CUTOVER_APPROVAL_ENV}=1 is required for remote seed identity writes.`);
  }
}

export function buildSeedIdentityCutoverPlan({
  users,
  customerProfiles,
  groomerProfiles,
  expectedCount = 100,
}) {
  const targets = [...customerProfiles, ...groomerProfiles]
    .map((profile) => ({
      ...profile,
      role: profile.seedID.startsWith("BTC-") ? "customer" : "groomer",
      legacySeedID: legacySeedID(profile.seedID),
      legacyEmail: legacyEmail(profile.email),
    }))
    .sort((left, right) => left.seedID.localeCompare(right.seedID));

  if (targets.length !== expectedCount) {
    throw new Error(`Expected ${expectedCount} target seed profiles; found ${targets.length}.`);
  }

  const usersByLegacySeedID = new Map();
  const usersByTargetSeedID = new Map();
  const usersByEmail = new Map();
  for (const user of users) {
    const email = normalizedEmail(user.email);
    if (email) {
      if (usersByEmail.has(email)) {
        throw new Error(`Duplicate Auth email detected for ${emailDomain(email)}.`);
      }
      usersByEmail.set(email, user);
    }
    const legacyID = metadataValue(user, "groomly_seed_id");
    const targetID = metadataValue(user, "beckon_seed_id");
    addUniqueSeedUser(usersByLegacySeedID, legacyID, user, "legacy");
    addUniqueSeedUser(usersByTargetSeedID, targetID, user, "Beckon");
  }

  for (const target of targets) {
    const collision = usersByEmail.get(normalizedEmail(target.email));
    const intended = usersByLegacySeedID.get(target.legacySeedID)
      ?? usersByTargetSeedID.get(target.seedID);
    if (collision && collision.id !== intended?.id) {
      throw new Error(`Target email collision detected for ${target.seedID}.`);
    }
  }

  const mappedUsers = new Set();
  const plan = targets.map((target) => {
    const user = usersByLegacySeedID.get(target.legacySeedID)
      ?? usersByTargetSeedID.get(target.seedID);
    if (!user) {
      throw new Error(`Missing legacy seed user for ${target.seedID}.`);
    }
    if (mappedUsers.has(user.id)) {
      throw new Error(`Auth user is mapped to more than one seed identity.`);
    }
    mappedUsers.add(user.id);
    validateCurrentIdentity(user, target);

    return {
      userID: user.id,
      role: target.role,
      legacySeedID: target.legacySeedID,
      targetSeedID: target.seedID,
      legacyEmail: target.legacyEmail,
      targetEmail: target.email,
      isAlreadyCutOver: currentSeedID(user) === target.seedID
        && normalizedEmail(user.email) === normalizedEmail(target.email)
        && !hasLegacySeedMetadata(user),
      updatePayload: {
        email: target.email,
        password: target.password,
        email_confirm: true,
        app_metadata: beckonMetadata(user.app_metadata, target),
        user_metadata: beckonMetadata(user.user_metadata, target),
      },
      rollbackPayload: {
        email: user.email,
        password: normalizedEmail(user.email) === normalizedEmail(target.email)
          ? target.password
          : LEGACY_SEED_PASSWORD,
        email_confirm: true,
        app_metadata: preRunMetadata(user.app_metadata),
        user_metadata: preRunMetadata(user.user_metadata),
      },
      legacyRollbackPayload: {
        email: target.legacyEmail,
        password: LEGACY_SEED_PASSWORD,
        email_confirm: true,
        app_metadata: legacyMetadata(user.app_metadata, target),
        user_metadata: legacyMetadata(user.user_metadata, target),
      },
    };
  });

  const identityUsers = users.filter((user) => {
    const seedID = currentSeedID(user);
    return seedID?.match(/^(GTC|GTG|BTC|BTG)-\d{3}$/);
  });
  if (identityUsers.length !== expectedCount || mappedUsers.size !== expectedCount) {
    throw new Error(
      `Expected ${expectedCount} legacy seed users; found ${mappedUsers.size} mapped and ${identityUsers.length} total.`
    );
  }

  return plan;
}

export function identityDigest(plan) {
  return createHash("sha256")
    .update(
      [...plan]
        .sort((left, right) => left.targetSeedID.localeCompare(right.targetSeedID))
        .map((entry) => `${entry.targetSeedID}:${entry.userID}`)
        .join("\n")
    )
    .digest("hex");
}

export async function executeSeedIdentityCutover(api, plan) {
  const updated = [];
  try {
    for (const entry of plan) {
      if (entry.isAlreadyCutOver) continue;
      const user = await api.updateUser(entry.userID, entry.updatePayload);
      if (user?.id !== entry.userID) {
        throw new Error(`Admin API returned an unexpected user identity.`);
      }
      updated.push(entry);
    }
    return { updated: updated.length, skipped: plan.length - updated.length };
  } catch (error) {
    const rollbackFailures = [];
    for (const entry of [...updated].reverse()) {
      try {
        await api.updateUser(entry.userID, entry.rollbackPayload);
      } catch (rollbackError) {
        rollbackFailures.push(safeErrorMessage(rollbackError));
      }
    }
    if (rollbackFailures.length > 0) {
      throw new Error(
        `Seed identity cutover failed after ${updated.length} updates; rollback also failed `
          + `${rollbackFailures.length} time(s): ${rollbackFailures.join("; ")}`
      );
    }
    throw new Error(
      `Seed identity cutover failed and rolled back ${updated.length} updated user(s): `
        + safeErrorMessage(error)
    );
  }
}

export async function executeSeedIdentityRollback(api, plan) {
  let rolledBack = 0;
  for (const entry of [...plan].reverse()) {
    await api.updateUser(entry.userID, entry.legacyRollbackPayload);
    rolledBack += 1;
  }
  return { rolledBack };
}

export function verifyCompletedSeedCutover(plan) {
  const incomplete = plan.filter((entry) => !entry.isAlreadyCutOver);
  if (incomplete.length > 0) {
    throw new Error(`Seed identity verification found ${incomplete.length} incomplete user(s).`);
  }
  return {
    users: plan.length,
    customers: plan.filter((entry) => entry.role === "customer").length,
    groomers: plan.filter((entry) => entry.role === "groomer").length,
    digest: identityDigest(plan),
  };
}

export class SupabaseAuthAdminAPI {
  constructor(supabaseURL, secretKey) {
    this.supabaseURL = supabaseURL.replace(/\/$/, "");
    this.secretKey = secretKey;
  }

  async listUsers() {
    const users = [];
    for (let page = 1; page <= 20; page += 1) {
      const data = await this.request("GET", `/admin/users?page=${page}&per_page=1000`);
      const pageUsers = data?.users ?? [];
      users.push(...pageUsers);
      if (pageUsers.length < 1000) break;
    }
    return users;
  }

  async updateUser(userID, payload) {
    return this.request("PUT", `/admin/users/${encodeURIComponent(userID)}`, payload);
  }

  async request(method, path, body) {
    const response = await fetch(`${this.supabaseURL}/auth/v1${path}`, {
      method,
      headers: {
        apikey: this.secretKey,
        Authorization: `Bearer ${this.secretKey}`,
        ...(body === undefined ? {} : { "Content-Type": "application/json" }),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await response.text();
    const data = text ? JSON.parse(text) : null;
    if (!response.ok) {
      const message = data?.message ?? data?.error_description ?? data?.error ?? text;
      throw new Error(`Auth admin ${method} failed (${response.status}): ${safeErrorMessage(message)}`);
    }
    return data;
  }
}

function addUniqueSeedUser(map, seedID, user, label) {
  if (!seedID) return;
  if (map.has(seedID) && map.get(seedID).id !== user.id) {
    throw new Error(`Duplicate ${label} seed identity detected.`);
  }
  map.set(seedID, user);
}

function validateCurrentIdentity(user, target) {
  const seedID = currentSeedID(user);
  if (seedID !== target.legacySeedID && seedID !== target.seedID) {
    throw new Error(`Unexpected seed identity while mapping ${target.seedID}.`);
  }
  const email = normalizedEmail(user.email);
  if (email !== normalizedEmail(target.legacyEmail) && email !== normalizedEmail(target.email)) {
    throw new Error(`Unexpected seed email while mapping ${target.seedID}.`);
  }
  const role = user.app_metadata?.role;
  if (role && role !== target.role) {
    throw new Error(`Role mismatch while mapping ${target.seedID}.`);
  }
}

function currentSeedID(user) {
  return metadataValue(user, "beckon_seed_id") ?? metadataValue(user, "groomly_seed_id");
}

function metadataValue(user, key) {
  return user.app_metadata?.[key] ?? user.user_metadata?.[key];
}

function hasLegacySeedMetadata(user) {
  return user.app_metadata?.groomly_seed != null
    || user.app_metadata?.groomly_seed_id != null
    || user.user_metadata?.groomly_seed != null
    || user.user_metadata?.groomly_seed_id != null;
}

function beckonMetadata(metadata, target) {
  const next = { ...(metadata ?? {}) };
  next.groomly_seed = null;
  next.groomly_seed_id = null;
  next.beckon_seed = "T-129";
  next.beckon_seed_id = target.seedID;
  return next;
}

function legacyMetadata(metadata, target) {
  const next = { ...(metadata ?? {}) };
  next.beckon_seed = null;
  next.beckon_seed_id = null;
  next.groomly_seed = "T-129";
  next.groomly_seed_id = target.legacySeedID;
  return next;
}

function preRunMetadata(metadata) {
  const next = { ...(metadata ?? {}) };
  for (const key of ["groomly_seed", "groomly_seed_id", "beckon_seed", "beckon_seed_id"]) {
    if (next[key] == null) next[key] = null;
  }
  return next;
}

function legacySeedID(targetSeedID) {
  if (targetSeedID.startsWith("BTC-")) return targetSeedID.replace("BTC-", "GTC-");
  if (targetSeedID.startsWith("BTG-")) return targetSeedID.replace("BTG-", "GTG-");
  throw new Error(`Unsupported Beckon seed ID.`);
}

function legacyEmail(targetEmail) {
  if (targetEmail.startsWith("beckon.customer")) {
    return targetEmail.replace("beckon.customer", "groomly.customer");
  }
  if (targetEmail.startsWith("beckon.groomer")) {
    return targetEmail.replace("beckon.groomer", "groomly.groomer");
  }
  throw new Error(`Unsupported Beckon seed email.`);
}

function normalizedEmail(value) {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function emailDomain(email) {
  return email.split("@")[1] ?? "unknown";
}

function safeErrorMessage(error) {
  return String(error instanceof Error ? error.message : error)
    .replace(/[A-Z0-9._%+-]+@([A-Z0-9.-]+\.[A-Z]{2,})/gi, "[email-domain:$1]")
    .replace(/\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/gi, "[uuid]")
    .replace(/\b(?:sb_secret_|sbp_)[A-Za-z0-9_-]+\b/g, "[secret]");
}
