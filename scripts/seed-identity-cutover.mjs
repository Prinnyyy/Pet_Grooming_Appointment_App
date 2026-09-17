#!/usr/bin/env node

import {
  parseCustomerProfiles,
  parseGroomerProfiles,
  requiredEnv,
  requiredServerCredential,
} from "./testops-core.mjs";
import {
  SupabaseAuthAdminAPI,
  buildSeedIdentityCutoverPlan,
  executeSeedIdentityCutover,
  executeSeedIdentityRollback,
  identityDigest,
  requireSeedCutoverApproval,
  verifyCompletedSeedCutover,
} from "./seed-identity-cutover-core.mjs";

const args = new Set(process.argv.slice(2));
const execute = args.has("--execute");
const rollback = args.has("--rollback");
const verify = args.has("--verify");

async function main() {
  if (rollback && !execute) {
    throw new Error("--rollback requires --execute.");
  }

  const customerProfiles = parseCustomerProfiles();
  const groomerProfiles = parseGroomerProfiles();

  if (!execute && !verify) {
    console.log("Beckon seed identity cutover dry run");
    console.log(`Target profiles: ${customerProfiles.length} customer, ${groomerProfiles.length} groomer.`);
    console.log("No remote connection or write was performed.");
    return;
  }

  if (execute) {
    requireSeedCutoverApproval();
  }
  const api = new SupabaseAuthAdminAPI(
    requiredEnv("SUPABASE_URL"),
    requiredServerCredential()
  );
  const users = await api.listUsers();
  const plan = buildSeedIdentityCutoverPlan({ users, customerProfiles, groomerProfiles });
  const beforeDigest = identityDigest(plan);

  console.log(`Validated ${plan.length} in-place seed mappings.`);
  console.log(`UUID mapping digest before: ${beforeDigest}`);

  if (verify && !execute) {
    const verification = verifyCompletedSeedCutover(plan);
    console.log(
      `Remote verification passed for ${verification.users} users `
        + `(${verification.customers} customer, ${verification.groomers} groomer).`
    );
    console.log(`UUID mapping digest: ${verification.digest}`);
    console.log("No write was performed.");
    return;
  }

  if (rollback) {
    const result = await executeSeedIdentityRollback(api, plan);
    console.log(`Rolled back ${result.rolledBack} seed identities.`);
    return;
  }

  const result = await executeSeedIdentityCutover(api, plan);
  const updatedUsers = await api.listUsers();
  const completedPlan = buildSeedIdentityCutoverPlan({
    users: updatedUsers,
    customerProfiles,
    groomerProfiles,
  });
  const verification = verifyCompletedSeedCutover(completedPlan);
  if (verification.digest !== beforeDigest) {
    throw new Error("UUID mapping digest changed during seed identity cutover.");
  }

  console.log(`Auth users: ${result.updated} updated, ${result.skipped} already cut over.`);
  console.log(
    `Verified ${verification.users} users (${verification.customers} customer, `
      + `${verification.groomers} groomer) with unchanged UUID mapping.`
  );
  console.log(`UUID mapping digest after: ${verification.digest}`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
