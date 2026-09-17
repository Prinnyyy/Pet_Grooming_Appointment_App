// Independent acceptance oracle; never imported by production code.
export const fitScore = (positive, negative, smoothing = 5) => 50 + 50 * (positive - negative) / (positive + negative + smoothing);
export function customerWeights(ages, halfLifeDays = 180) {
  if (!Number.isFinite(halfLifeDays) || halfLifeDays <= 0) throw new Error("invalid parameter: halfLifeDays");
  if (ages.some(age => !Number.isFinite(age) || age < 0)) throw new Error("invalid service age");
  const decays = ages.map(age => 2 ** (-age / halfLifeDays));
  const total = decays.reduce((a, b) => a + b, 0);
  const newest = Math.max(0, ...decays);
  return decays.map(decay => total === 0 ? 0 : newest * decay / total);
}

export function scoreEvidence(target, reviews, distanceMiles, parameters = {}) {
  const defaults = { halfLifeDays: 180, smoothing: 5, distanceScaleMiles: 5, groomerFitWeight: 0.7, customerFitWeight: 0.6 };
  for (const key of Object.keys(parameters)) if (!Object.hasOwn(defaults, key)) throw new Error(`invalid parameter: ${key}`);
  const p = { ...defaults, ...parameters };
  for (const key of ["halfLifeDays", "smoothing", "distanceScaleMiles"]) {
    if (!Number.isFinite(p[key]) || p[key] <= 0) throw new Error(`invalid parameter: ${key}`);
  }
  for (const [key, maximum] of [["groomerFitWeight", 1], ["customerFitWeight", 0.85]]) {
    if (!Number.isFinite(p[key]) || p[key] < 0 || p[key] > maximum) throw new Error(`invalid parameter: ${key}`);
  }
  if (distanceMiles !== null && (!Number.isFinite(distanceMiles) || distanceMiles < 0)) throw new Error("invalid distance");
  const keys = [...new Set(target.keys)];
  const groups = [...new Set(keys.map(key => key.split(":")[0]))];
  const share = key => 1 / groups.length / keys.filter(candidate => candidate.split(":")[0] === key.split(":")[0]).length;
  const valid = reviews.filter(review => Number.isInteger(review.rating) && review.rating >= 1 && review.rating <= 5
    && Number.isFinite(review.age) && review.age >= 0);
  const fit = target.service === "custom_request" ? [] : valid.filter(review => review.species === target.species
    && review.service === target.service && keys.some(key => ["positive", "negative"].includes(review.answers?.[key])));
  const weighted = rows => {
    const customers = Map.groupBy(rows, row => row.customer);
    return [...customers.values()].flatMap(group => {
      const weights = customerWeights(group.map(row => row.age), p.halfLifeDays);
      return group.map((row, index) => ({ row, weight: weights[index] }));
    });
  };
  let positive = 0, negative = 0;
  for (const { row, weight } of weighted(fit)) {
    for (const key of keys) {
      if (row.answers[key] === "positive") positive += weight * share(key);
      if (row.answers[key] === "negative") negative += weight * share(key);
    }
  }
  const quality = weighted(valid);
  const q = 100 * (p.smoothing / 2 + quality.reduce((sum, { row, weight }) => sum + weight * (row.rating - 1) / 4, 0))
    / (p.smoothing + quality.reduce((sum, { weight }) => sum + weight, 0));
  const f = fitScore(positive, negative, p.smoothing);
  const d = distanceMiles === null ? null : 100 / (1 + distanceMiles / p.distanceScaleMiles);
  return { f, q, d, positive, negative, b: d === null ? null : p.groomerFitWeight * f + (1 - p.groomerFitWeight) * d,
    s: d === null ? null : p.customerFitWeight * f + (0.85 - p.customerFitWeight) * q + 0.15 * d };
}
