#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const PROJECT_ROOT = path.resolve(import.meta.dirname, "..");
const DEFAULT_SOURCE = path.join(
  PROJECT_ROOT,
  "docs/02_architecture/test_resources/T-129_CUSTOMER_TEST_PROFILES.md"
);
const SEED_NAME = "T-129";
const EMAIL_PREFIX = "beckon.customer";
const EMAIL_DOMAIN = "@example.com";
const VALID_BREEDS = new Set([
  "Unspecified",
  "Mixed Breed",
  "Labrador Retriever",
  "Golden Retriever",
  "German Shepherd",
  "French Bulldog",
  "Bulldog",
  "Poodle",
  "Toy Poodle",
  "Standard Poodle",
  "Beagle",
  "Rottweiler",
  "Dachshund",
  "Corgi",
  "Yorkshire Terrier",
  "Boxer",
  "Shih Tzu",
  "Shiba Inu",
  "Siberian Husky",
  "Australian Shepherd",
  "Border Collie",
  "Chihuahua",
  "Pomeranian",
  "Maltese",
  "Boston Terrier",
  "Cavalier King Charles Spaniel",
  "Great Dane",
  "Doberman Pinscher",
  "Miniature Schnauzer",
  "Pit Bull",
  "Bichon Frise",
  "Cocker Spaniel",
  "Domestic Shorthair",
  "Domestic Longhair",
  "Siamese",
  "Persian",
  "Maine Coon",
  "Ragdoll",
  "British Shorthair",
  "Bengal",
  "Sphynx",
  "Scottish Fold",
  "Russian Blue",
]);
const VALID_COAT_TYPES = new Set([
  "not_sure",
  "curly_wavy",
  "wire",
  "double_coat",
  "drop_coat",
  "long_silky",
  "short_smooth",
  "hairless_low_coat",
]);
const VALID_TEMPERAMENTS = new Set([
  "Not Sure",
  "Friendly",
  "Playful",
  "Calm",
  "Gentle",
  "Energetic",
  "Shy",
  "Anxious",
  "Reactive",
  "Independent",
  "Affectionate",
  "Protective",
  "Social",
  "Nervous",
]);
const CAT_BREEDS = new Set([
  "Domestic Shorthair",
  "Domestic Longhair",
  "Siamese",
  "Persian",
  "Maine Coon",
  "Ragdoll",
  "British Shorthair",
  "Bengal",
  "Sphynx",
  "Scottish Fold",
  "Russian Blue",
]);

const args = new Set(process.argv.slice(2));
const execute = args.has("--execute");
const sourcePath = valueAfter("--source") ?? DEFAULT_SOURCE;

function valueAfter(flag) {
  const index = process.argv.indexOf(flag);
  if (index === -1 || index + 1 >= process.argv.length) {
    return undefined;
  }
  return process.argv[index + 1];
}

async function main() {
  const profiles = parseProfiles(sourcePath);
  validateProfiles(profiles);

  const totalPets = profiles.reduce((count, profile) => count + profile.pets.length, 0);
  console.log(`Parsed ${profiles.length} T-129 customer profiles.`);
  console.log(
    `Planned rows: ${profiles.length} auth users, ${profiles.length} profiles, ` +
      `${profiles.length} customer_profiles, ${totalPets} pets.`
  );

  if (!execute) {
    console.log("Dry run only. Re-run with --execute to write Supabase.");
    return;
  }

  const supabaseURL = requiredEnv("SUPABASE_URL").replace(/\/$/, "");
  const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
  const api = new SupabaseAdminREST(supabaseURL, serviceRoleKey);

  const existingUsersByEmail = await api.listUsersByEmail();
  const authUsers = [];
  let createdUsers = 0;
  let updatedUsers = 0;

  for (const profile of profiles) {
    const existing = existingUsersByEmail.get(profile.email.toLowerCase());
    if (existing) {
      const user = await api.updateUser(existing.id, authUserPayload(profile, existing));
      authUsers.push({ profile, user });
      updatedUsers += 1;
    } else {
      const user = await api.createUser(authUserPayload(profile));
      authUsers.push({ profile, user });
      existingUsersByEmail.set(profile.email.toLowerCase(), user);
      createdUsers += 1;
    }
  }

  const userIDs = authUsers.map(({ user }) => user.id);
  await ensureNoRoleConflicts(api, userIDs);

  await api.deleteByColumnIDs("pets", "customer_id", userIDs);

  await api.upsert("profiles", authUsers.map(profileRow), "id");
  await api.upsert("customer_profiles", authUsers.map(customerProfileRow), "user_id");
  await api.insert("pets", authUsers.flatMap(petRows));

  const verification = await verifySeed(api, userIDs);

  console.log(`Auth users: ${createdUsers} created, ${updatedUsers} updated.`);
  console.log(
    `Verified remote rows: profiles=${verification.profiles}, ` +
      `customer_profiles=${verification.customerProfiles}, pets=${verification.pets}.`
  );
}

function requiredEnv(name) {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`${name} is required.`);
  }
  return value;
}

function parseProfiles(filePath) {
  const markdown = fs.readFileSync(filePath, "utf8");
  return markdown
    .split(/\r?\n/)
    .filter((line) => line.startsWith("| BTC-"))
    .map(parseProfileLine);
}

function parseProfileLine(line) {
  const cells = line
    .split("|")
    .slice(1, -1)
    .map((cell) => cell.trim());
  if (cells.length !== 7) {
    throw new Error(`Expected 7 columns for profile row: ${line}`);
  }

  const [seedID, email, password, nicknameContact, addressValue, dogValue, catValue] = cells;
  const contact = parseNicknameContact(nicknameContact);
  const address = parseAddress(addressValue);

  return {
    seedID,
    email,
    password,
    ...contact,
    address,
    pets: [parsePet(dogValue, "Dog"), parsePet(catValue, "Cat")],
  };
}

function parseNicknameContact(value) {
  const parts = value.split(" / ").map((part) => part.trim());
  if (parts.length !== 3) {
    throw new Error(`Invalid Nickname / Contact value: ${value}`);
  }
  return {
    nickname: parts[0],
    contactEmail: parts[1],
    phoneNumber: parts[2],
  };
}

function parseAddress(value) {
  const match = value.match(/^(.+),\s*([^,]+),\s*CA\s+(\d{5}(?:-\d{4})?)$/);
  if (!match) {
    throw new Error(`Invalid CA address: ${value}`);
  }
  return {
    street: match[1],
    city: match[2],
    state: "CA",
    zip: match[3],
  };
}

function parsePet(value, species) {
  const parts = value.split(";").map((part) => part.trim());
  if (parts.length !== 7) {
    throw new Error(`Invalid pet value: ${value}`);
  }

  const [name, breed, coatType, weightValue, birthday, temperament, notesValue] = parts;
  const weightMatch = weightValue.match(/^(\d+(?:\.\d+)?)\s*lb$/);
  if (!weightMatch) {
    throw new Error(`Invalid pet weight: ${weightValue}`);
  }
  const notesMatch = notesValue.match(/^notes:\s*(.+)$/i);
  if (!notesMatch) {
    throw new Error(`Invalid pet notes: ${notesValue}`);
  }
  const weightLbs = Number.parseFloat(weightMatch[1]);

  return {
    name,
    species,
    breed,
    coatType,
    weightLbs,
    birthday,
    temperament,
    groomingNotes: notesMatch[1],
    size: sizeCodeForWeight(weightLbs),
  };
}

function sizeCodeForWeight(weightLbs) {
  if (weightLbs < 10) {
    return "XS";
  }
  if (weightLbs < 20) {
    return "S";
  }
  if (weightLbs < 40) {
    return "M";
  }
  if (weightLbs < 60) {
    return "L";
  }
  if (weightLbs < 80) {
    return "XL";
  }
  if (weightLbs <= 100) {
    return "XXL";
  }
  return "Giant";
}

function validateProfiles(profiles) {
  if (profiles.length !== 50) {
    throw new Error(`Expected 50 customer profiles; found ${profiles.length}.`);
  }
  const emails = new Set();
  const seedIDs = new Set();
  for (const profile of profiles) {
    if (!profile.seedID.match(/^BTC-\d{3}$/)) {
      throw new Error(`Invalid seed ID: ${profile.seedID}`);
    }
    if (!profile.email.startsWith(EMAIL_PREFIX) || !profile.email.endsWith(EMAIL_DOMAIN)) {
      throw new Error(`Unexpected seed email: ${profile.email}`);
    }
    if (emails.has(profile.email)) {
      throw new Error(`Duplicate email: ${profile.email}`);
    }
    if (seedIDs.has(profile.seedID)) {
      throw new Error(`Duplicate seed ID: ${profile.seedID}`);
    }
    if (profile.password.length < 8) {
      throw new Error(`Weak password for ${profile.seedID}`);
    }
    if (!profile.nickname || profile.nickname.length > 80) {
      throw new Error(`Invalid nickname for ${profile.seedID}`);
    }
    if (!profile.contactEmail.match(/^[^@\s]+@[^@\s]+\.[^@\s]+$/)) {
      throw new Error(`Invalid contact email for ${profile.seedID}`);
    }
    if (!profile.phoneNumber.match(/^[0-9+(). -]{7,32}$/)) {
      throw new Error(`Invalid phone number for ${profile.seedID}`);
    }
    validatePets(profile);
    emails.add(profile.email);
    seedIDs.add(profile.seedID);
  }
}

function validatePets(profile) {
  if (profile.pets.length !== 2) {
    throw new Error(`Expected exactly 2 pets for ${profile.seedID}.`);
  }
  const speciesSet = new Set(profile.pets.map((pet) => pet.species));
  if (!speciesSet.has("Dog") || !speciesSet.has("Cat")) {
    throw new Error(`Expected one dog and one cat for ${profile.seedID}.`);
  }
  for (const pet of profile.pets) {
    if (!pet.name || pet.name.length > 80) {
      throw new Error(`Invalid pet name for ${profile.seedID}: ${pet.name}`);
    }
    if (!VALID_BREEDS.has(pet.breed)) {
      throw new Error(`Invalid pet breed for ${profile.seedID}: ${pet.breed}`);
    }
    if (pet.species === "Cat" && !CAT_BREEDS.has(pet.breed)) {
      throw new Error(`Cat pet has non-cat breed for ${profile.seedID}: ${pet.breed}`);
    }
    if (pet.species === "Dog" && CAT_BREEDS.has(pet.breed)) {
      throw new Error(`Dog pet has cat breed for ${profile.seedID}: ${pet.breed}`);
    }
    if (!VALID_COAT_TYPES.has(pet.coatType)) {
      throw new Error(`Invalid pet coat type for ${profile.seedID}: ${pet.coatType}`);
    }
    if (pet.weightLbs < 5 || pet.weightLbs > 101) {
      throw new Error(`Pet weight outside app range for ${profile.seedID}: ${pet.weightLbs}`);
    }
    if (!pet.birthday.match(/^\d{4}-\d{2}-\d{2}$/)) {
      throw new Error(`Invalid pet birthday for ${profile.seedID}: ${pet.birthday}`);
    }
    if (!VALID_TEMPERAMENTS.has(pet.temperament)) {
      throw new Error(`Invalid pet temperament for ${profile.seedID}: ${pet.temperament}`);
    }
    if (!pet.groomingNotes || pet.groomingNotes.length > 2000) {
      throw new Error(`Invalid pet notes for ${profile.seedID}: ${pet.name}`);
    }
  }
}

function authUserPayload(profile, existingUser) {
  return {
    email: profile.email,
    password: profile.password,
    email_confirm: true,
    app_metadata: {
      ...(existingUser?.app_metadata ?? {}),
      role: "customer",
      beckon_seed: SEED_NAME,
      beckon_seed_id: profile.seedID,
    },
    user_metadata: {
      ...(existingUser?.user_metadata ?? {}),
      display_name: profile.nickname,
      contact_email: profile.contactEmail,
      beckon_seed: SEED_NAME,
      beckon_seed_id: profile.seedID,
    },
  };
}

async function ensureNoRoleConflicts(api, userIDs) {
  const existingProfiles = await api.select(
    "profiles",
    `select=id,role,display_name&id=in.(${userIDs.join(",")})`
  );
  const conflicts = existingProfiles.filter((profile) => profile.role !== "customer");
  if (conflicts.length > 0) {
    throw new Error(
      `Refusing to overwrite non-customer profiles: ${conflicts
        .map((profile) => `${profile.id}:${profile.role}`)
        .join(", ")}`
    );
  }
}

function profileRow({ profile, user }) {
  return {
    id: user.id,
    role: "customer",
    display_name: profile.nickname,
  };
}

function customerProfileRow({ profile, user }) {
  return {
    user_id: user.id,
    street_address: profile.address.street,
    city: profile.address.city,
    state: profile.address.state,
    zip_code: profile.address.zip,
    contact_email: profile.contactEmail,
    phone_number: profile.phoneNumber,
  };
}

function petRows({ profile, user }) {
  return profile.pets.map((pet) => ({
    customer_id: user.id,
    name: pet.name,
    species: pet.species,
    breed: pet.breed,
    coat_type: pet.coatType,
    size: pet.size,
    weight_lbs: pet.weightLbs,
    birthday: pet.birthday,
    temperament: pet.temperament,
    medical_notes: null,
    grooming_notes: pet.groomingNotes,
    is_active: true,
    deleted_at: null,
  }));
}

async function verifySeed(api, userIDs) {
  const userFilter = `in.(${userIDs.join(",")})`;
  const [profiles, customerProfiles, pets] = await Promise.all([
    api.select("profiles", `select=id&id=${userFilter}`),
    api.select("customer_profiles", `select=user_id&user_id=${userFilter}`),
    api.select("pets", `select=id&customer_id=${userFilter}&is_active=eq.true`),
  ]);
  return {
    profiles: profiles.length,
    customerProfiles: customerProfiles.length,
    pets: pets.length,
  };
}

class SupabaseAdminREST {
  constructor(supabaseURL, serviceRoleKey) {
    this.supabaseURL = supabaseURL;
    this.serviceRoleKey = serviceRoleKey;
  }

  async listUsersByEmail() {
    const usersByEmail = new Map();
    for (let page = 1; page <= 20; page += 1) {
      const data = await this.auth("GET", `/admin/users?page=${page}&per_page=1000`);
      const users = data.users ?? [];
      for (const user of users) {
        if (typeof user.email === "string") {
          usersByEmail.set(user.email.toLowerCase(), user);
        }
      }
      if (users.length < 1000) {
        break;
      }
    }
    return usersByEmail;
  }

  async createUser(payload) {
    return this.auth("POST", "/admin/users", payload);
  }

  async updateUser(userID, payload) {
    return this.auth("PUT", `/admin/users/${encodeURIComponent(userID)}`, payload);
  }

  async select(table, query) {
    return this.rest("GET", `/${table}?${query}`);
  }

  async insert(table, rows) {
    if (rows.length === 0) {
      return [];
    }
    return this.rest("POST", `/${table}`, rows, {
      Prefer: "return=minimal",
    });
  }

  async upsert(table, rows, onConflict) {
    if (rows.length === 0) {
      return [];
    }
    return this.rest("POST", `/${table}?on_conflict=${encodeURIComponent(onConflict)}`, rows, {
      Prefer: "resolution=merge-duplicates,return=minimal",
    });
  }

  async deleteByColumnIDs(table, column, ids) {
    for (const chunk of chunked(ids, 20)) {
      await this.rest("DELETE", `/${table}?${column}=in.(${chunk.join(",")})`, undefined, {
        Prefer: "return=minimal",
      });
    }
  }

  async auth(method, path, body) {
    return this.request(`${this.supabaseURL}/auth/v1${path}`, method, body, {});
  }

  async rest(method, path, body, extraHeaders = {}) {
    return this.request(`${this.supabaseURL}/rest/v1${path}`, method, body, extraHeaders);
  }

  async request(url, method, body, extraHeaders) {
    const response = await fetch(url, {
      method,
      headers: {
        apikey: this.serviceRoleKey,
        Authorization: `Bearer ${this.serviceRoleKey}`,
        ...(body === undefined ? {} : { "Content-Type": "application/json" }),
        ...extraHeaders,
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });

    if (response.status === 204) {
      return null;
    }

    const text = await response.text();
    const data = text ? JSON.parse(text) : null;
    if (!response.ok) {
      const message = data?.message ?? data?.error_description ?? data?.error ?? text;
      throw new Error(`${method} ${redactedURL(url)} failed (${response.status}): ${message}`);
    }
    return data;
  }
}

function chunked(values, size) {
  const chunks = [];
  for (let index = 0; index < values.length; index += size) {
    chunks.push(values.slice(index, index + size));
  }
  return chunks;
}

function redactedURL(value) {
  return value.replace(/([?&]apikey=)[^&]+/g, "$1<redacted>");
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
