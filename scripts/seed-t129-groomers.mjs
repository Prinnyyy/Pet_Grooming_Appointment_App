#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const PROJECT_ROOT = path.resolve(import.meta.dirname, "..");
const DEFAULT_SOURCE = path.join(
  PROJECT_ROOT,
  "docs/02_architecture/test_resources/T-129_GROOMER_TEST_PROFILES.md"
);
const SEED_NAME = "T-129";
const EMAIL_PREFIX = "beckon.groomer";
const EMAIL_DOMAIN = "@example.com";
const SIZE_ORDER = ["XS", "S", "M", "L", "XL", "XXL", "Giant"];
const WEEKDAYS = new Map([
  ["Mon", 1],
  ["Tue", 2],
  ["Wed", 3],
  ["Thu", 4],
  ["Fri", 5],
  ["Sat", 6],
  ["Sun", 7],
]);
const LOCATION_MODES = {
  mobile: ["groomer_comes_to_customer"],
  studio: ["customer_comes_to_groomer"],
  both: ["groomer_comes_to_customer", "customer_comes_to_groomer"],
};
const SERVICE_TITLES = {
  full_groom: "Full Groom",
  bath_and_brush: "Bath & Brush",
  haircut_only: "Haircut Only",
  nail_trim: "Nail Trim",
  de_shedding: "De-shedding",
  custom_request: "Custom Request",
};

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

  const totalServices = profiles.reduce((count, profile) => count + profile.services.length, 0);
  const totalAvailability = profiles.reduce(
    (count, profile) => count + profile.availabilityWindows.length,
    0
  );
  const totalClaims = profiles.reduce((count, profile) => count + profile.fitClaims.length, 0);

  console.log(`Parsed ${profiles.length} T-129 groomer profiles.`);
  console.log(
    `Planned rows: ${profiles.length} auth users, ${profiles.length} profiles, ` +
      `${profiles.length} groomer_profiles, ${totalServices} services, ` +
      `${totalAvailability} availability windows, ${profiles.length} booking preferences, ` +
      `${totalClaims} fit claims.`
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

  await api.deleteByGroomerIDs("groomer_fit_claims", userIDs);
  await api.deleteByGroomerIDs("groomer_availability_windows", userIDs);
  await api.deleteByGroomerIDs("groomer_booking_preferences", userIDs);
  await api.deleteByGroomerIDs("groomer_services", userIDs);

  await api.upsert("profiles", authUsers.map(profileRow), "id");
  await api.upsert("groomer_profiles", authUsers.map(groomerProfileRow), "user_id");
  await api.upsert(
    "groomer_booking_preferences",
    authUsers.map(bookingPreferencesRow),
    "groomer_id"
  );
  await api.insert(
    "groomer_availability_windows",
    authUsers.flatMap(availabilityRows)
  );
  await api.insert("groomer_services", authUsers.flatMap(serviceRows));
  await api.insert("groomer_fit_claims", authUsers.flatMap(fitClaimRows));

  const verification = await verifySeed(api, userIDs);

  console.log(`Auth users: ${createdUsers} created, ${updatedUsers} updated.`);
  console.log(
    `Verified remote rows: profiles=${verification.profiles}, ` +
      `groomer_profiles=${verification.groomerProfiles}, services=${verification.services}, ` +
      `availability=${verification.availability}, preferences=${verification.preferences}, ` +
      `fit_claims=${verification.fitClaims}.`
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
    .filter((line) => line.startsWith("| BTG-"))
    .map(parseProfileLine);
}

function parseProfileLine(line) {
  const cells = line
    .split("|")
    .slice(1, -1)
    .map((cell) => cell.trim());
  if (cells.length !== 12) {
    throw new Error(`Expected 12 columns for profile row: ${line}`);
  }

  const [
    seedID,
    email,
    password,
    displayBusiness,
    bio,
    baseAddress,
    modesRadius,
    yearsExperience,
    sizeExperience,
    fitSignals,
    availability,
    services,
  ] = cells;
  const [displayName, businessName] = splitDisplayBusiness(displayBusiness);
  const address = parseAddress(baseAddress);
  const location = parseModesRadius(modesRadius);
  const availabilityPlan = parseAvailability(availability);
  const sizeClaims = expandSizeExperience(sizeExperience).map((size) => ({
    trait_type: "size_band",
    trait_value: size,
  }));
  const coreClaims = fitSignals.split(";").map((entry) => parseFitSignal(entry.trim()));
  const fitClaims = uniqueClaims([...coreClaims, ...sizeClaims]);

  return {
    seedID,
    email,
    password,
    displayName,
    businessName,
    bio,
    address,
    location,
    yearsExperience: Number.parseInt(yearsExperience, 10),
    sizeExperience,
    fitClaims,
    availabilityWindows: availabilityPlan.windows,
    bookingPreferences: availabilityPlan.preferences,
    services: services.split(";").map((entry) => parseService(entry.trim(), businessName)),
  };
}

function splitDisplayBusiness(value) {
  const parts = value.split(" / ");
  if (parts.length !== 2) {
    throw new Error(`Invalid Display / Business value: ${value}`);
  }
  return parts;
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

function parseModesRadius(value) {
  const match = value.match(/^(mobile|studio|both)\s*\/\s*(\d+)\s*mi$/);
  if (!match) {
    throw new Error(`Invalid modes/radius value: ${value}`);
  }
  return {
    modes: LOCATION_MODES[match[1]],
    radiusMiles: Number.parseInt(match[2], 10),
  };
}

function parseAvailability(value) {
  const [windowPart, maxPart, advancePart] = value.split(";").map((part) => part.trim());
  const maxMatch = maxPart?.match(/^max\/day\s+(\d+)$/);
  const advanceMatch = advancePart?.match(/^advance\s+(\d+)d$/);
  if (!maxMatch || !advanceMatch) {
    throw new Error(`Invalid availability preferences: ${value}`);
  }

  return {
    windows: windowPart.split(",").flatMap((part) => parseAvailabilityWindow(part.trim())),
    preferences: {
      maxAppointmentsPerDay: Number.parseInt(maxMatch[1], 10),
      minimumAdvanceNoticeDays: Number.parseInt(advanceMatch[1], 10),
      autoAcceptBookings: false,
    },
  };
}

function parseAvailabilityWindow(value) {
  const match = value.match(/^([A-Za-z]{3})(?:-([A-Za-z]{3}))?\s+(\d{2}:\d{2})-(\d{2}:\d{2})$/);
  if (!match) {
    throw new Error(`Invalid availability window: ${value}`);
  }
  const startDay = weekdayNumber(match[1]);
  const endDay = match[2] ? weekdayNumber(match[2]) : startDay;
  if (endDay < startDay) {
    throw new Error(`Availability ranges must not wrap weeks: ${value}`);
  }
  return range(startDay, endDay).map((weekday) => ({
    weekday,
    start_time: `${match[3]}:00`,
    end_time: `${match[4]}:00`,
    is_enabled: true,
    timezone: "America/Los_Angeles",
  }));
}

function weekdayNumber(value) {
  const weekday = WEEKDAYS.get(value);
  if (!weekday) {
    throw new Error(`Unknown weekday: ${value}`);
  }
  return weekday;
}

function parseFitSignal(value) {
  const [traitType, traitValue] = value.split(":").map((part) => part.trim());
  if (!traitType || !traitValue) {
    throw new Error(`Invalid fit signal: ${value}`);
  }
  return {
    trait_type: traitType,
    trait_value: traitValue,
  };
}

function expandSizeExperience(value) {
  const [start, end] = value.split("-");
  const startIndex = SIZE_ORDER.indexOf(start);
  const endIndex = SIZE_ORDER.indexOf(end);
  if (startIndex === -1 || endIndex === -1 || endIndex < startIndex) {
    throw new Error(`Invalid size experience: ${value}`);
  }
  return SIZE_ORDER.slice(startIndex, endIndex + 1);
}

function uniqueClaims(claims) {
  const seen = new Set();
  return claims.filter((claim) => {
    const key = `${claim.trait_type}:${claim.trait_value}`;
    if (seen.has(key)) {
      return false;
    }
    seen.add(key);
    return true;
  });
}

function parseService(value, businessName) {
  const match = value.match(/^([a-z_]+)\s+\$(\d+)\/(\d+)m$/);
  if (!match) {
    throw new Error(`Invalid service value: ${value}`);
  }
  const serviceType = match[1];
  const title = SERVICE_TITLES[serviceType];
  if (!title) {
    throw new Error(`Unknown service type: ${serviceType}`);
  }
  return {
    service_type: serviceType,
    title,
    description: `${title} test service for ${businessName}.`,
    base_price: Number.parseInt(match[2], 10),
    duration_minutes: Number.parseInt(match[3], 10),
    accepted_pet_sizes: [],
    is_active: true,
  };
}

function validateProfiles(profiles) {
  if (profiles.length !== 50) {
    throw new Error(`Expected 50 groomer profiles; found ${profiles.length}.`);
  }
  const emails = new Set();
  const seedIDs = new Set();
  for (const profile of profiles) {
    if (!profile.seedID.match(/^BTG-\d{3}$/)) {
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
    if (!profile.services.length) {
      throw new Error(`No services for ${profile.seedID}`);
    }
    if (!profile.availabilityWindows.length) {
      throw new Error(`No availability for ${profile.seedID}`);
    }
    emails.add(profile.email);
    seedIDs.add(profile.seedID);
  }
}

function range(start, end) {
  return Array.from({ length: end - start + 1 }, (_, index) => start + index);
}

function authUserPayload(profile, existingUser) {
  return {
    email: profile.email,
    password: profile.password,
    email_confirm: true,
    app_metadata: {
      ...(existingUser?.app_metadata ?? {}),
      role: "groomer",
      beckon_seed: SEED_NAME,
      beckon_seed_id: profile.seedID,
    },
    user_metadata: {
      ...(existingUser?.user_metadata ?? {}),
      display_name: profile.displayName,
      business_name: profile.businessName,
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
  const conflicts = existingProfiles.filter((profile) => profile.role !== "groomer");
  if (conflicts.length > 0) {
    throw new Error(
      `Refusing to overwrite non-groomer profiles: ${conflicts
        .map((profile) => `${profile.id}:${profile.role}`)
        .join(", ")}`
    );
  }
}

function profileRow({ profile, user }) {
  return {
    id: user.id,
    role: "groomer",
    display_name: profile.displayName,
  };
}

function groomerProfileRow({ profile, user }) {
  return {
    user_id: user.id,
    business_name: profile.businessName,
    bio: profile.bio,
    years_experience: profile.yearsExperience,
    base_street_address: profile.address.street,
    base_city: profile.address.city,
    base_state: profile.address.state,
    base_zip_code: profile.address.zip,
    service_radius_miles: profile.location.radiusMiles,
    service_location_mode: profile.location.modes[0],
    service_location_modes: profile.location.modes,
    is_active: true,
  };
}

function bookingPreferencesRow({ profile, user }) {
  return {
    groomer_id: user.id,
    max_appointments_per_day: profile.bookingPreferences.maxAppointmentsPerDay,
    minimum_advance_notice_days: profile.bookingPreferences.minimumAdvanceNoticeDays,
    auto_accept_bookings: profile.bookingPreferences.autoAcceptBookings,
  };
}

function availabilityRows({ profile, user }) {
  return profile.availabilityWindows.map((window) => ({
    groomer_id: user.id,
    ...window,
  }));
}

function serviceRows({ profile, user }) {
  return profile.services.map((service) => ({
    groomer_id: user.id,
    ...service,
  }));
}

function fitClaimRows({ profile, user }) {
  return profile.fitClaims.map((claim) => ({
    groomer_id: user.id,
    ...claim,
    is_active: true,
  }));
}

async function verifySeed(api, userIDs) {
  const userFilter = `in.(${userIDs.join(",")})`;
  const [
    profiles,
    groomerProfiles,
    services,
    availability,
    preferences,
    fitClaims,
  ] = await Promise.all([
    api.select("profiles", `select=id&id=${userFilter}`),
    api.select("groomer_profiles", `select=user_id&user_id=${userFilter}`),
    api.select("groomer_services", `select=id&groomer_id=${userFilter}`),
    api.select("groomer_availability_windows", `select=id&groomer_id=${userFilter}`),
    api.select("groomer_booking_preferences", `select=groomer_id&groomer_id=${userFilter}`),
    api.select("groomer_fit_claims", `select=id&groomer_id=${userFilter}`),
  ]);
  return {
    profiles: profiles.length,
    groomerProfiles: groomerProfiles.length,
    services: services.length,
    availability: availability.length,
    preferences: preferences.length,
    fitClaims: fitClaims.length,
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

  async deleteByGroomerIDs(table, groomerIDs) {
    for (const chunk of chunked(groomerIDs, 20)) {
      await this.rest("DELETE", `/${table}?groomer_id=in.(${chunk.join(",")})`, undefined, {
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
