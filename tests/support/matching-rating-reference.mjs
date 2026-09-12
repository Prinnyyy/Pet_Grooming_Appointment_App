// Independent acceptance oracle; never imported by production code.
export const fitScore = (positive, negative) => 50 + 50 * (positive - negative) / (positive + negative + 5);
export function customerWeights(ages) {
  if (ages.some(age => !Number.isFinite(age) || age < 0)) throw new Error("invalid service age");
  const decays = ages.map(age => 2 ** (-age / 180));
  const total = decays.reduce((a, b) => a + b, 0);
  const newest = Math.max(0, ...decays);
  return decays.map(decay => total === 0 ? 0 : newest * decay / total);
}

export function scoreEvidence(target, reviews, distanceMiles) {
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
      const weights = customerWeights(group.map(row => row.age));
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
  const q = 100 * (2.5 + quality.reduce((sum, { row, weight }) => sum + weight * (row.rating - 1) / 4, 0))
    / (5 + quality.reduce((sum, { weight }) => sum + weight, 0));
  const f = fitScore(positive, negative);
  const d = distanceMiles === null ? null : 100 / (1 + distanceMiles / 5);
  return { f, q, d, positive, negative, b: d === null ? null : 0.7 * f + 0.3 * d,
    s: d === null ? null : 0.6 * f + 0.25 * q + 0.15 * d };
}
